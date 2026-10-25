import Foundation
import CryptoKit
import Security
import WebKit
import CoreFoundation
#if canImport(ReaderCoreClient)
import ReaderCoreClient
#endif

/// Platform sockets, TLS and cookie storage. Core remains the request/rule owner.
/// Each source has a private native cookie jar; credentials never enter Core DB.
final class ReaderIOSHostTransport: ReaderCoreHostTransport, @unchecked Sendable {
    typealias HTTPRunner = ([String: Any], HTTPCookieStorage, Bool) throws -> [String: Any]
    private let lock = NSLock()
    private let cookieStore: ReaderSourceCookieStore
    private let httpRunner: HTTPRunner?
    private let webOwnerID = UUID()
    private var bindings: [UInt64: String] = [:]
    private var jobs: [UInt64: [UUID: ReaderHTTPJob]] = [:]
    private var cookieOperations: [UInt64: [UUID: ReaderSourceCookieOperation]] = [:]
    private var cancelled = Set<UInt64>()
    private var retiring = Set<UInt64>()
    private var activeHandlers: [UInt64: Int] = [:]
    private var packageSequence: UInt64 = 0
    init(namespace: String = "reader", cookieStore: ReaderSourceCookieStore? = nil, httpRunner: HTTPRunner? = nil) {
        let namespace = Self.hash(namespace)
        self.cookieStore = cookieStore ?? ReaderSourceCookieStore.shared(namespace: namespace,
            load: { try Self.loadCookies(namespace: namespace, sourceID: $0) },
            save: { try Self.saveCookies(namespace: namespace, sourceID: $0, cookies: $1) })
        self.httpRunner = httpRunner
    }
    func configure(_ client: ReaderCoreClient) {
        for capability in ["http.execute", "cookie.get", "cookie.set", "time.now"] {
            client.capabilityRouter.register(capability) { [weak self] request in
                guard let self else { throw ReaderHostFailure("CANCELLED", "来源会话已关闭") }
                return try self.performObject(request, requestID: 0)
            }
        }
    }
    func bind(requestID: UInt64, sourceID: String?) {
        lock.lock(); bindings[requestID] = sourceID; lock.unlock()
    }
    func finish(requestID: UInt64) {
        lock.withLock { clear(requestID) }
    }
    func retireRead(requestID: UInt64) {
        lock.withLock { retiring.insert(requestID) }
        cancel(requestID: requestID)
        lock.withLock { clearRetiredIfIdle(requestID) }
    }
    private func clear(_ id: UInt64) {
        bindings[id] = nil; cancelled.remove(id); jobs[id] = nil; cookieOperations[id] = nil
        retiring.remove(id); activeHandlers[id] = nil
    }
    private func clearRetiredIfIdle(_ id: UInt64) {
        if retiring.contains(id), activeHandlers[id, default: 0] == 0, jobs[id]?.isEmpty ?? true { clear(id) }
    }
    private func reservePackageRequest() -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        packageSequence += 1
        return UInt64.max - packageSequence
    }
    func fetchPackage(at url: URL) async throws -> ReaderCoreHostResponse {
        let id = reservePackageRequest()
        bind(requestID: id, sourceID: "source-package:" + (url.host ?? ""))
        defer { finish(requestID: id) }
        let request = ReaderHostRequestBox(request: ReaderCoreHostRequest(operationId: id, capability: "http.execute", rawParams: ["url": url.absoluteString, "timeoutMs": 30000]))
        let result: [String: Any] = try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    continuation.resume(with: Result { try self.performObject(request.request, requestID: id) })
                }
            }
        }, onCancel: { self.cancel(requestID: id) })
        try Task.checkCancellation()
        return ReaderCoreHostResponse(status: result["status"] as? Int ?? 0, headers: result["headers"] as? [String: String] ?? [:], body: result["body"] as? String ?? "", finalUrl: result["finalUrl"] as? String)
    }
    func fetchImage(parameters: [String: Any], sourceID: String) async throws -> Data {
        let id = reservePackageRequest()
        bind(requestID: id, sourceID: sourceID)
        defer { finish(requestID: id) }
        let result: [String: Any] = try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    continuation.resume(with: Result { try self.executeHTTP(parameters: parameters, sourceID: sourceID, requestID: id, binary: true) })
                }
            }
        }, onCancel: { self.cancel(requestID: id) })
        try Task.checkCancellation()
        guard let status = result["status"] as? Int, (200..<300).contains(status), let bytes = result["bodyBytes"] as? Data else { throw ReaderHostFailure("INTERNAL", "封面暂时无法加载") }
        return bytes
    }
    func cancel(requestID: UInt64) {
        lock.lock()
        cancelled.insert(requestID)
        let active = Array(jobs[requestID]?.values ?? [:].values)
        let operations = Array(cookieOperations[requestID]?.values ?? [:].values)
        lock.unlock()
        // Never hold transport.lock while taking an operation lock. Commit uses
        // store -> operation -> transport, with cancellation checked at admission.
        operations.forEach { $0.cancel() }
        active.forEach { $0.cancel() }
        let ownerID = webOwnerID
        Task { @MainActor in ReaderSourceWebBridge.shared.cancel(ownerID: ownerID, requestID: requestID) }
    }
    private func wasCancelled(_ requestID: UInt64) -> Bool { lock.withLock { cancelled.contains(requestID) } }
    private static func hash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private func key(_ params: [String: Any], requestID: UInt64) -> String {
        lock.lock(); let bound = bindings[requestID]; lock.unlock()
        return bound ?? (params["session"] as? [String: Any])?["id"] as? String
            ?? params["sessionId"] as? String ?? params["profileId"] as? String
            ?? (URL(string: params["url"] as? String ?? "")?.host ?? "unbound")
    }
    func cookies(sourceID: String) throws -> [HTTPCookie] { try cookieStore.snapshot(sourceID: sourceID) }
    func commitCookieChanges(sourceID: String, originalCookies: [HTTPCookie], updatedCookies: [HTTPCookie]) throws {
        let operation = try cookieStore.begin(sourceID: sourceID, originalCookies: originalCookies)
        operation.replaceCookies(updatedCookies)
        // The login owner authorizes this original source write before calling.
        try cookieStore.complete(operation, result: .success(()))
    }
    private static func loadCookies(namespace: String, sourceID: String) throws -> [HTTPCookie] {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "io.reader.minliny.source-cookies." + namespace,
            kSecAttrAccount as String: Self.hash(sourceID), kSecReturnData as String: true]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let data = result as? Data,
              let records = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]] else {
            throw ReaderHostFailure("INTERNAL", "无法读取来源登录状态")
        }
        return try records.map { record in
            let properties = Dictionary(uniqueKeysWithValues: record.map { (HTTPCookiePropertyKey($0.key), $0.value) })
            guard let cookie = HTTPCookie(properties: properties) else { throw ReaderHostFailure("INTERNAL", "来源登录状态无法读取") }
            return cookie
        }
    }
    private static func saveCookies(namespace: String, sourceID: String, cookies: [HTTPCookie]) throws {
        let records = try cookies.map { cookie -> [String: Any] in
            guard let props = cookie.properties else { throw ReaderHostFailure("INTERNAL", "无法保存来源登录状态") }
            return Dictionary(uniqueKeysWithValues: props.map { key, value in
                (key.rawValue, (value as? URL).map { $0.absoluteString as Any } ?? value)
            })
        }
        let data = try PropertyListSerialization.data(fromPropertyList: records, format: .binary, options: 0)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "io.reader.minliny.source-cookies." + namespace,
            kSecAttrAccount as String: Self.hash(sourceID)]
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query; insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw ReaderHostFailure("INTERNAL", "无法保存来源登录状态") }
        } else if status != errSecSuccess { throw ReaderHostFailure("INTERNAL", "无法保存来源登录状态") }
    }
    private func beginCookieOperation(sourceID: String, requestID: UInt64) throws -> (UUID, ReaderSourceCookieOperation) {
        let operation = try cookieStore.begin(sourceID: sourceID)
        let identity = UUID()
        let stopped = lock.withLock {
            cookieOperations[requestID, default: [:]][identity] = operation
            return cancelled.contains(requestID) || retiring.contains(requestID)
        }
        if stopped { operation.cancel() }
        return (identity, operation)
    }
    private func completeCookieOperation<T>(_ operation: ReaderSourceCookieOperation, requestID: UInt64,
                                            result: Result<T, Error>) throws -> T {
        try cookieStore.complete(operation, result: result) {
            self.lock.withLock { !self.cancelled.contains(requestID) && !self.retiring.contains(requestID) }
        }
    }
    private func executeHTTP(parameters: [String: Any], sourceID: String, requestID: UInt64, binary: Bool = false) throws -> [String: Any] {
        let (identity, operation) = try beginCookieOperation(sourceID: sourceID, requestID: requestID)
        defer { lock.withLock { cookieOperations[requestID]?[identity] = nil; jobs[requestID]?[identity] = nil } }
        let job = try ReaderHTTPJob(params: parameters, jar: operation.jar, binary: binary)
        let stopped = lock.withLock {
            jobs[requestID, default: [:]][identity] = job
            return cancelled.contains(requestID) || retiring.contains(requestID)
        }
        let result: Result<[String: Any], Error> = Result {
            if stopped { throw URLError(.cancelled) }
            return try httpRunner?(parameters, operation.jar, binary) ?? job.run()
        }
        // Finalize on non-cancel failures too: a received Set-Cookie is valid
        // independently of body decoding or a later transport failure.
        return try completeCookieOperation(operation, requestID: requestID, result: result)
    }
    func perform(_ request: ReaderCoreHostRequest) throws -> ReaderCoreHostResponse {
        let object = try performObject(request, requestID: 0)
        return ReaderCoreHostResponse(status: object["status"] as? Int ?? 200,
            headers: object["headers"] as? [String: String] ?? [:], body: object["body"] as? String ?? "",
            finalUrl: object["finalUrl"] as? String)
    }
    func beginHostRequest(requestID: UInt64, cancellableRead: Bool = false) -> Bool {
        // Reserve before dispatching platform work. A read may be cancelled
        // while its queued closure has not yet registered an HTTP task.
        lock.withLock {
            // Retirement may already have cleared this read's idle transport
            // state before its queued Task starts. Its own cancellation still
            // forbids admission. Accepted mutation Host work keeps its original
            // lifetime even when the observing Task has been cancelled.
            guard !cancellableRead || !Task.isCancelled else { return false }
            guard !retiring.contains(requestID), !cancelled.contains(requestID) else { return false }
            activeHandlers[requestID, default: 0] += 1
            return true
        }
    }
    func endHostRequest(requestID: UInt64) {
        lock.withLock {
            activeHandlers[requestID, default: 1] -= 1
            if activeHandlers[requestID] == 0 { activeHandlers[requestID] = nil }
            clearRetiredIfIdle(requestID)
        }
    }
    func handle(_ event: ReaderCoreEvent, client: ReaderCoreClient, cancellableRead: Bool) async throws {
        guard let operationID = event.operationId, let capability = event.capability else {
            throw ReaderHostFailure("INVALID_PARAMS", "Host 请求缺少身份")
        }
        let requestID = event.requestId ?? 0
        let accepted = beginHostRequest(requestID: requestID, cancellableRead: cancellableRead)
        guard accepted else { throw URLError(.cancelled) }
        defer { endHostRequest(requestID: requestID) }
        let request = ReaderCoreHostRequest(operationId: operationID, capability: capability, rawParams: event.hostRequestParams ?? [:])
        do {
            let result: [String: Any]
            if capability == "webview.evaluateJavaScript" {
                guard !wasCancelled(requestID) else { throw URLError(.cancelled) }
                let source = key(request.rawParams, requestID: requestID)
                let (identity, operation) = try beginCookieOperation(sourceID: source, requestID: requestID)
                defer { lock.withLock { cookieOperations[requestID]?[identity] = nil } }
                let evaluated: Result<[String: Any], Error>
                do {
                    let value = try await ReaderSourceWebBridge.shared.evaluate(request.rawParams, ownerID: webOwnerID,
                        requestID: requestID, operationID: operationID, cookies: operation.originalCookies,
                        shouldCancel: { self.wasCancelled(requestID) }) { cookies in operation.replaceCookies(cookies) }
                    evaluated = .success(value)
                } catch {
                    evaluated = .failure(error)
                }
                // Recheck the request owner after allCookies() returns. WebKit
                // removes its run before that await, but the transport retains
                // this operation so cancellation in that window still wins.
                result = try completeCookieOperation(operation, requestID: requestID, result: evaluated)
            } else {
                let box = ReaderHostRequestBox(request: request)
                result = try await withCheckedThrowingContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        continuation.resume(with: Result { try self.performObject(box.request, requestID: requestID) })
                    }
                }
            }
            try client.sendHostComplete(operationId: operationID, result: result)
        } catch {
            let failure = error as? ReaderHostFailure
            let urlError = error as? URLError
            let policy = ReaderHTTPJob.failurePolicy(error)
            let code = failure?.code ?? policy.code
            try client.sendHostError(operationId: operationID, code: code,
                message: failure?.message ?? (urlError == nil ? "来源请求未完成" : "网络请求未完成"), retryable: failure == nil && policy.retryable)
        }
    }
    private func performObject(_ request: ReaderCoreHostRequest, requestID: UInt64) throws -> [String: Any] {
        let params = request.rawParams, source = key(request.rawParams, requestID: requestID)
        switch request.capability {
        case "http.execute":
            return try executeHTTP(parameters: params, sourceID: source, requestID: requestID)
        case "cookie.get":
            let cookies = try cookieStore.cookies(sourceID: source, for: (params["url"] as? String).flatMap(URL.init(string:)))
            return ["cookies": cookies.filter { cookie in
                (params["name"] as? String).map { $0 == cookie.name } ?? true
            }.filter { cookie in (params["domain"] as? String).map { $0 == cookie.domain } ?? true }.map(Self.cookieRecord)]
        case "cookie.set":
            guard let record = params["cookie"] as? [String: Any], let name = record["name"] as? String else { throw ReaderHostFailure("INVALID_PARAMS", "Cookie 参数不完整") }
            let url = (params["url"] as? String).flatMap(URL.init(string:))
            guard let domain = record["domain"] as? String ?? url?.host else { throw ReaderHostFailure("INVALID_PARAMS", "Cookie 缺少来源") }
            var properties: [HTTPCookiePropertyKey: Any] = [.name: name, .value: record["value"] as? String ?? "", .domain: domain, .path: record["path"] as? String ?? "/"]
            if record["secure"] as? Bool == true { properties[.secure] = "TRUE" }
            if record["httpOnly"] as? Bool == true { properties[HTTPCookiePropertyKey("HttpOnly")] = "TRUE" }
            if let expiry = record["expiresAt"] as? String {
                let formatter = ISO8601DateFormatter()
                var date = formatter.date(from: expiry)
                if date == nil { formatter.formatOptions.insert(.withFractionalSeconds); date = formatter.date(from: expiry) }
                guard let date else { throw ReaderHostFailure("INVALID_PARAMS", "Cookie 到期时间格式无效") }
                properties[.expires] = date
            }
            if let sameSite = record["sameSite"] as? String { properties[HTTPCookiePropertyKey("SameSite")] = sameSite }
            guard let cookie = HTTPCookie(properties: properties) else { throw ReaderHostFailure("INVALID_PARAMS", "Cookie 格式无效") }
            let (identity, operation) = try beginCookieOperation(sourceID: source, requestID: requestID)
            defer { lock.withLock { cookieOperations[requestID]?[identity] = nil } }
            operation.jar.setCookie(cookie)
            try completeCookieOperation(operation, requestID: requestID, result: .success(()))
            return ["stored": true]
        case "time.now": return ["unixMillis": Int64(Date().timeIntervalSince1970 * 1000), "iso8601": ISO8601DateFormatter().string(from: Date()), "timezone": TimeZone.current.identifier]
        default: throw ReaderHostFailure("UNKNOWN_METHOD", "此来源需要尚未支持的平台能力")
        }
    }
    private static func cookieRecord(_ cookie: HTTPCookie) -> [String: Any] {
        var result: [String: Any] = ["name": cookie.name, "value": cookie.value, "domain": cookie.domain, "path": cookie.path, "secure": cookie.isSecure, "httpOnly": cookie.isHTTPOnly]
        if let date = cookie.expiresDate { result["expiresAt"] = ISO8601DateFormatter().string(from: date) }
        return result
    }
}

private struct ReaderHostFailure: Error { let code: String; let message: String; init(_ code: String, _ message: String) { self.code = code; self.message = message } }
private struct ReaderHostRequestBox: @unchecked Sendable { let request: ReaderCoreHostRequest }

private final class ReaderHTTPJob: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let params: [String: Any]
    private let jar: HTTPCookieStorage
    private let lock = NSLock()
    private let cancellationSignal = DispatchSemaphore(value: 0)
    private let done = DispatchSemaphore(value: 0)
    private var task: URLSessionDataTask?
    private var stopped = false
    private var bytes = Data()
    private var response: HTTPURLResponse?
    private var failure: Error?
    private var redirects: [[String: Any]] = []
    private var currentHop: URLRequest?
    private let limit: Int
    private let binary: Bool
    init(params: [String: Any], jar: HTTPCookieStorage, binary: Bool = false) throws {
        self.params = params; self.jar = jar
        self.binary = binary; self.limit = (binary ? 8 : 32) * 1024 * 1024
        guard let url = (params["url"] as? String).flatMap(URL.init(string:)), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { throw ReaderHostFailure("INVALID_PARAMS", "仅支持 HTTP/HTTPS 来源地址") }
    }
    func cancel() { lock.lock(); stopped = true; let active = task; lock.unlock(); active?.cancel(); cancellationSignal.signal() }
    func run() throws -> [String: Any] {
        let timeout = max(0.1, min(Double(params["timeoutMs"] as? Int ?? 30000) / 1000, 300))
        let deadline = Date().addingTimeInterval(timeout)
        let retry = params["retry"] as? [String: Any] ?? [:]
        let attempts = max(1, min(retry["maxAttempts"] as? Int ?? 1, 4))
        for attempt in 1...attempts {
            lock.lock(); let cancelled = stopped; lock.unlock()
            if cancelled { throw URLError(.cancelled) }
            if Date() >= deadline { throw URLError(.timedOut) }
            bytes = Data(); response = nil; failure = nil; redirects = []
            var request = URLRequest(url: URL(string: params["url"] as! String)!, timeoutInterval: deadline.timeIntervalSinceNow)
            request.httpMethod = params["method"] as? String ?? "GET"
            request.allHTTPHeaderFields = params["headers"] as? [String: String] ?? [:]
            request.httpShouldHandleCookies = params["usePlatformCookieJar"] as? Bool ?? true
            if let body = params["body"] as? String {
                request.httpBody = try ReaderCoreHttpPolicy.encode(text: body, charset: params["charset"] as? String ?? "utf-8")
            } else if let body = params["body"] as? [String: Any] {
                let pairs = body["fields"] as? [[String]] ?? []
                guard pairs.allSatisfy({ $0.count == 2 }) else { throw ReaderHostFailure("INVALID_PARAMS", "表单字段不完整") }
                if let files = body["files"] as? [[String: Any]] {
                    let boundary = "Reader-" + UUID().uuidString
                    var parts: [ReaderCoreHttpPolicy.MultipartFile] = []
                    for file in files {
                        guard file["filePath"] == nil, let data = file["data"] as? [UInt8] else { throw ReaderHostFailure("INVALID_PARAMS", "上传文件需由应用文件入口提供字节") }
                        parts.append(.init(fieldName: file["fieldName"] as? String ?? "file", filename: file["filename"] as? String ?? "file", contentType: file["contentType"] as? String ?? "application/octet-stream", bytes: Data(data)))
                    }
                    // Reuse the pinned Core multipart serializer, retaining
                    // the protocol's ordered, possibly repeated field names.
                    var serialized = Data()
                    let closing = Data("--\(boundary)--\r\n".utf8)
                    for pair in pairs {
                        let field = ReaderCoreHttpPolicy.multipart(boundary: boundary, fields: [pair[0]: pair[1]], files: [])
                        serialized.append(field.dropLast(closing.count))
                    }
                    serialized.append(ReaderCoreHttpPolicy.multipart(boundary: boundary, fields: [:], files: parts))
                    request.httpBody = serialized
                    request.setValue("multipart/form-data; boundary=" + boundary, forHTTPHeaderField: "Content-Type")
                } else {
                    let charset = params["charset"] as? String ?? "utf-8"
                    let encoded = try pairs.map { try Self.formComponent($0[0], charset: charset) + "=" + Self.formComponent($0[1], charset: charset) }.joined(separator: "&")
                    request.httpBody = Data(encoded.utf8)
                    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                }
            }
            if request.httpShouldHandleCookies, let url = request.url {
                let fromJar = HTTPCookie.requestHeaderFields(with: jar.cookies(for: url) ?? [])["Cookie"] ?? ""
                let merged = ReaderCoreHttpPolicy.mergeCookieHeader(explicitCookie: request.value(forHTTPHeaderField: "Cookie") ?? "", jarCookie: fromJar)
                if !merged.isEmpty { request.setValue(merged, forHTTPHeaderField: "Cookie") }
            }
            currentHop = request
            let config = URLSessionConfiguration.ephemeral
            config.httpCookieStorage = jar; config.httpShouldSetCookies = request.httpShouldHandleCookies
            config.timeoutIntervalForResource = max(0.1, deadline.timeIntervalSinceNow)
            let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            let active = session.dataTask(with: request)
            lock.lock(); task = active; let stop = stopped; lock.unlock()
            if stop { active.cancel() } else { active.resume() }
            if done.wait(timeout: .now() + max(0, deadline.timeIntervalSinceNow)) == .timedOut {
                active.cancel(); session.invalidateAndCancel(); throw URLError(.timedOut)
            }
            session.finishTasksAndInvalidate()
            if let error = failure {
                guard attempt < attempts, Self.failurePolicy(error).retryable else { throw error }
                let delay = ReaderCoreHttpPolicy.retryBackoffMillis(baseMillis: max(0, min(retry["backoffMillis"] as? Int ?? 150, 2000)), attempt: attempt, maxMillis: 2000, remainingMillis: max(0, Int(deadline.timeIntervalSinceNow * 1000)))
                if delay > 0, cancellationSignal.wait(timeout: .now() + Double(delay) / 1000) == .success { throw URLError(.cancelled) }
                continue
            }
            guard let response else { throw URLError(.badServerResponse) }
            let headers = response.allHeaderFields.reduce(into: [String: String]()) { $0[String(describing: $1.key)] = String(describing: $1.value) }
            if binary { return ["status": response.statusCode, "headers": headers, "bodyBytes": bytes, "finalUrl": response.url?.absoluteString ?? request.url!.absoluteString] }
            let contentType = response.value(forHTTPHeaderField: "Content-Type")
            let charset = (contentType?.lowercased().contains("charset") ?? false)
                ? ReaderCoreHttpPolicy.responseCharset(contentType: contentType)
                : (params["charset"] as? String ?? "utf-8")
            let mime = response.mimeType?.lowercased() ?? ""
            let isBinary = mime.hasPrefix("image/") || mime.hasPrefix("audio/") || mime.hasPrefix("video/") || ["application/octet-stream", "application/zip", "application/pdf"].contains(mime)
            if isBinary {
                var result: [String: Any] = ["status": response.statusCode, "headers": headers, "body": "", "bodyBase64": bytes.base64EncodedString(), "finalUrl": response.url?.absoluteString ?? request.url!.absoluteString]
                if let session = params["session"] { result["session"] = session }
                if !redirects.isEmpty { result["redirects"] = redirects }
                return result
            }
            let body = try ReaderCoreHttpPolicy.decode(bytes: bytes, charset: charset)
            var result: [String: Any] = ["status": response.statusCode, "headers": headers, "body": body, "charsetHint": charset, "finalUrl": response.url?.absoluteString ?? request.url!.absoluteString]
            if !redirects.isEmpty { result["redirects"] = redirects }
            if let session = params["session"] { result["session"] = session }
            return result
        }
        throw URLError(.timedOut)
    }
    private static func formComponent(_ text: String, charset: String) throws -> String {
        // Core's fixed charset support validates lossless encoding. The system
        // percent encoder then operates in that encoding, before ASCII framing.
        _ = try ReaderCoreHttpPolicy.encode(text: text, charset: charset)
        let encoding = CFStringConvertIANACharSetNameToEncoding(charset as CFString)
        guard encoding != kCFStringEncodingInvalidId,
              let escaped = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, text as CFString,
                nil, "!*'();:@&=+$,/?%#[]" as CFString, encoding) as String? else {
            throw ReaderHostFailure("INVALID_PARAMS", "不支持该表单编码")
        }
        return escaped.replacingOccurrences(of: "%20", with: "+")
    }
    static func failurePolicy(_ error: Error) -> (code: String, retryable: Bool) {
        let platform = error as NSError
        guard platform.domain == NSURLErrorDomain else { return ("INTERNAL", false) }
        switch URLError.Code(rawValue: platform.code) {
        case .cancelled: return ("CANCELLED", false)
        case .timedOut: return ("TIMEOUT", true)
        case .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
            return ("INTERNAL", true)
        default: return ("INTERNAL", false)
        }
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse, response.expectedContentLength <= Int64(limit) else { failure = ReaderHostFailure("RESOURCE_EXHAUSTED", "来源响应超过大小限制"); completionHandler(.cancel); return }
        self.response = http; completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard bytes.count <= limit - data.count else { failure = ReaderHostFailure("RESOURCE_EXHAUSTED", "来源响应超过大小限制"); dataTask.cancel(); return }
        bytes.append(data)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) { if failure == nil { failure = error }; done.signal() }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard ReaderCoreHttpPolicy.allowNextRedirect(followRedirects: params["followRedirects"] as? Bool ?? true, maxRedirects: min(params["maxRedirects"] as? Int ?? 10, 20), observedHops: redirects.count), let from = response.url, let to = request.url, ["http", "https"].contains(to.scheme?.lowercased() ?? "") else { completionHandler(nil); return }
        let sameOrigin = from.scheme == to.scheme && from.host == to.host && from.port == to.port
        var next = request
        next.allHTTPHeaderFields = ReaderCoreHttpPolicy.redirectHeaders(request.allHTTPHeaderFields ?? [:], sameOrigin: sameOrigin)
        let previous = currentHop ?? task.currentRequest ?? task.originalRequest
        let decision = ReaderCoreHttpPolicy.redirectMethod(status: response.statusCode, method: previous?.httpMethod ?? "GET", hasBody: previous?.httpBody != nil)
        next.httpMethod = decision.method
        if decision.keepBody { next.httpBody = previous?.httpBody }
        else { next.httpBody = nil; next.setValue(nil, forHTTPHeaderField: "Content-Type"); next.setValue(nil, forHTTPHeaderField: "Content-Length") }
        currentHop = next
        redirects.append(["status": response.statusCode, "fromUrl": from.absoluteString, "toUrl": to.absoluteString])
        completionHandler(next)
    }
}

/// WebKit owns JavaScript and page navigation; no Host HTML/rule interpreter.
@MainActor final class ReaderSourceWebBridge: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    static let shared = ReaderSourceWebBridge()
    private struct RunKey: Hashable { let ownerID: UUID; let operationID: UInt64 }
    private struct Run {
        let parentID: UInt64
        let view: WKWebView
        let continuation: CheckedContinuation<[String: Any], Error>
        let params: [String: Any]
        let timer: Task<Void, Never>
        let cookieSink: ([HTTPCookie]) -> Void
        var navigationGeneration: UInt64 = 0
        var evaluation: Task<Void, Never>?
    }
    private var runs: [RunKey: Run] = [:]
    func cancel(ownerID: UUID, requestID: UInt64) {
        for id in runs.filter({ $0.key.ownerID == ownerID && $0.value.parentID == requestID }).map(\.key) {
            finish(id, .failure(URLError(.cancelled)))
        }
    }
    func evaluate(_ params: [String: Any], ownerID: UUID, requestID: UInt64, operationID: UInt64? = nil, cookies: [HTTPCookie], shouldCancel: @escaping () -> Bool = { Task.isCancelled }, cookieSink: @escaping ([HTTPCookie]) -> Void = { _ in }) async throws -> [String: Any] {
        let id = RunKey(ownerID: ownerID, operationID: operationID ?? requestID)
        guard !shouldCancel() else { throw URLError(.cancelled) }
        guard runs[id] == nil else { throw ReaderHostFailure("BUSY", "网页来源操作正在进行") }
        let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
        if let matcher = params["resourceUrlMatcherJavaScript"] as? String {
            // These are actual WebKit PerformanceResourceTiming observations.
            // The Core-authored predicate only filters observed resource URLs.
            let script = """
            (()=>{const matches=(\(matcher));let sent=false;
            const observe=e=>{if(!sent&&e.entryType==='resource'&&matches(e.name)===true){sent=true;window.webkit.messageHandlers.readerSourceResource.postMessage(e.name);}};
            new PerformanceObserver(l=>l.getEntries().forEach(observe)).observe({type:'resource',buffered:true});
            })();
            """
            config.userContentController.add(self, contentWorld: .defaultClient, name: "readerSourceResource")
            config.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false, in: .defaultClient))
        }
        let view = WKWebView(frame: .zero, configuration: config)
        return try await withCheckedThrowingContinuation { continuation in
            let timeout = max(100, min(params["timeoutMillis"] as? Int ?? 30000, 120000))
            let timer = Task { try? await Task.sleep(nanoseconds: UInt64(timeout) * 1_000_000); if !Task.isCancelled { self.finish(id, .failure(URLError(.timedOut))) } }
            // Register before the first cookie await so cancellation can always
            // find its exact Host operation, including parallel child requests.
            runs[id] = Run(parentID: requestID, view: view, continuation: continuation, params: params, timer: timer, cookieSink: cookieSink)
            view.navigationDelegate = self
            Task { @MainActor in
                for cookie in cookies {
                    guard self.runs[id]?.view === view else { return }
                    await config.websiteDataStore.httpCookieStore.setCookie(cookie)
                    if shouldCancel() { self.finish(id, .failure(URLError(.cancelled))); return }
                }
                guard self.runs[id]?.view === view else { return }
                if shouldCancel() { self.finish(id, .failure(URLError(.cancelled))); return }
                let document = params["document"] as? [String: Any] ?? [:]
                if document["kind"] as? String == "html", let body = document["body"] as? String {
                    view.loadHTMLString(body, baseURL: (document["baseUrl"] as? String).flatMap(URL.init(string:)))
                } else if let url = (document["url"] as? String).flatMap(URL.init(string:)), ["http", "https"].contains(url.scheme ?? "") {
                    var request = URLRequest(url: url); request.allHTTPHeaderFields = params["headers"] as? [String: String]; view.load(request)
                } else { self.finish(id, .failure(ReaderHostFailure("INVALID_PARAMS", "网页来源地址无效"))) }
            }
        }
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard let id = runs.first(where: { $0.value.view === webView })?.key else { return }
        runs[id]?.evaluation?.cancel()
        runs[id]?.evaluation = nil
        runs[id]?.navigationGeneration += 1
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let (id, run) = runs.first(where: { $0.value.view === webView }) else { return }
        runs[id]?.evaluation?.cancel()
        let generation = run.navigationGeneration
        let evaluation = Task { @MainActor in
            let delay = max(0, min(run.params["settleDelayMillis"] as? Int ?? 0, 600000))
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000) }
            guard !Task.isCancelled, self.runs[id]?.view === webView, self.runs[id]?.navigationGeneration == generation else { return }
            do {
                let value = try await webView.callAsyncJavaScript("return await (0, eval)(program);", arguments: ["program": run.params["javaScript"] as? String ?? "null"], in: nil, contentWorld: .page)
                guard !Task.isCancelled, self.runs[id]?.view === webView, self.runs[id]?.navigationGeneration == generation else { return }
                // A resource-matching request completes exclusively from a real
                // resource observation, including resources initiated by this JS.
                if run.params["resourceUrlMatcherJavaScript"] != nil { return }
                var result: [String: Any] = ["value": value ?? NSNull()]
                if let url = webView.url { result["finalUrl"] = url.absoluteString }
                if let title = webView.title, !title.isEmpty { result["title"] = title }
                self.finish(id, .success(result))
            } catch {
                guard !Task.isCancelled, self.runs[id]?.navigationGeneration == generation else { return }
                self.finish(id, .failure(error))
            }
        }
        runs[id]?.evaluation = evaluation
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(webView, error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(webView, error) }
    private func fail(_ view: WKWebView, _ error: Error) { if let id = runs.first(where: { $0.value.view === view })?.key { finish(id, .failure(error)) } }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "readerSourceResource", let url = message.body as? String,
              url.count <= 64 * 1024, let parsed = URL(string: url), ["http", "https"].contains(parsed.scheme ?? ""),
              let (id, run) = runs.first(where: { $0.value.view.configuration.userContentController === userContentController }),
              run.params["resourceUrlMatcherJavaScript"] != nil else { return }
        var result: [String: Any] = ["value": url, "resourceUrl": url]
        if let finalURL = run.view.url { result["finalUrl"] = finalURL.absoluteString }
        if let title = run.view.title, !title.isEmpty { result["title"] = title }
        finish(id, .success(result))
    }
    private func finish(_ id: RunKey, _ result: Result<[String: Any], Error>) {
        guard let run = runs.removeValue(forKey: id) else { return }
        run.timer.cancel(); run.evaluation?.cancel(); run.view.navigationDelegate = nil; run.view.stopLoading()
        run.view.configuration.userContentController.removeScriptMessageHandler(forName: "readerSourceResource", contentWorld: .defaultClient)
        let commitCookies = Self.shouldCommitCookies(for: result)
        Task { @MainActor in
            let cookies = await run.view.configuration.websiteDataStore.httpCookieStore.allCookies()
            if commitCookies { run.cookieSink(cookies) }
            run.continuation.resume(with: result)
        }
    }

    nonisolated static func shouldCommitCookies(for result: Result<[String: Any], Error>) -> Bool {
        guard case .failure(let error) = result else { return true }
        return !ReaderSourceCookieStore.isCancellation(error)
    }
}
