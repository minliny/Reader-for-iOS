import Foundation
import CoreFoundation
import ReaderCore

public struct ReaderCoreCoreError: Error, Equatable {
    public let code: String
    public let message: String
    public let retryable: Bool
    public let rawData: Data

    public init(code: String, message: String, retryable: Bool, rawData: Data) {
        self.code = code
        self.message = message
        self.retryable = retryable
        self.rawData = rawData
    }
}

public enum ReaderCoreClientError: Error, Equatable {
    case createFailed(Int32)
    case sendFailed(Int32)
    case busy
    case resourceExhausted
    case cancelFailed(Int32)
    case runtimeDestroyed
    case invalidCommandJSON
    case invalidEventJSON
    case requestTimedOut(UInt64)
    case missingHostTransport
    case hostTransportFailed(String)
    case invalidHostErrorCode(String)
    case coreError(ReaderCoreCoreError)
}

/// Machine-readable error codes accepted by Core's `host.error` command.
///
/// Core deserializes `host.error`'s `error.code` as the `ErrorCode` enum
/// (`crates/reader-contract/src/error.rs`, `SCREAMING_SNAKE_CASE`). Passing an
/// unknown code makes `host.error` parsing fail on the Core side: the error is
/// routed to the `host.error` command's own request id (adapter-internal) and
/// the original pending request never resumes — surfacing as a caller timeout.
/// Validate against this set on the adapter side to fail fast instead.
public enum ReaderCoreHostErrorCode: String, CaseIterable {
    case unknownMethod = "UNKNOWN_METHOD"
    case invalidParams = "INVALID_PARAMS"
    case invalidProtocolVersion = "INVALID_PROTOCOL_VERSION"
    case cancelled = "CANCELLED"
    case timeout = "TIMEOUT"
    case invalidMessage = "INVALID_MESSAGE"
    case internal_ = "INTERNAL"
    case transactionPending = "TRANSACTION_PENDING"
    case busy = "BUSY"
    case resourceExhausted = "RESOURCE_EXHAUSTED"

    public static func isValid(_ rawValue: String) -> Bool {
        ReaderCoreHostErrorCode(rawValue: rawValue) != nil
    }
}

/// Value-type mirror of Core's thread-local `rc_last_error` slot.
///
/// `code` follows the C ABI error code enum
/// (`RC_OK=0, RC_ERR_UNKNOWN_METHOD=1, RC_ERR_INVALID_PARAMS=2,
///   RC_ERR_INVALID_PROTOCOL_VERSION=3, RC_ERR_CANCELLED=4,
///   RC_ERR_INVALID_MESSAGE=5, RC_ERR_INTERNAL=6,
///   RC_ERR_TRANSACTION_PENDING=7, RC_ERR_TIMEOUT=8,
///   RC_ERR_BUSY=9, RC_ERR_RESOURCE_EXHAUSTED=10`).
/// `isPresent` is `true` when `code != 0`.
public struct ReaderCoreLastError: Error, Equatable {
    public let code: Int32
    public let message: String

    public init(code: Int32, message: String) {
        self.code = code
        self.message = message
    }

    public var isPresent: Bool { code != 0 }
}

public struct ReaderCoreEvent {
    public let rawData: Data
    public let object: [String: Any]

    public init(data: Data) throws {
        let value = try? JSONSerialization.jsonObject(with: data)
        guard let object = value as? [String: Any] else {
            throw ReaderCoreClientError.invalidEventJSON
        }

        self.rawData = data
        self.object = object
    }

    public var type: String {
        object["type"] as? String ?? ""
    }

    public var requestId: UInt64? {
        Self.uint64Value(object["requestId"])
    }

    public var data: [String: Any]? {
        object["data"] as? [String: Any]
    }

    public var error: [String: Any]? {
        object["error"] as? [String: Any]
    }

    public var isHostRequest: Bool {
        type == "host.request"
    }

    public var operationId: UInt64? {
        Self.uint64Value(object["operationId"])
    }

    public var capability: String? {
        object["capability"] as? String
    }

    public var hostRequestParams: [String: Any]? {
        object["params"] as? [String: Any]
    }

    public var coreError: ReaderCoreCoreError? {
        guard type == "error" else { return nil }
        let err = error ?? [:]
        return ReaderCoreCoreError(
            code: err["code"] as? String ?? "INTERNAL",
            message: err["message"] as? String ?? "",
            retryable: err["retryable"] as? Bool ?? false,
            rawData: rawData
        )
    }

    private static func uint64Value(_ value: Any?) -> UInt64? {
        if let value = value as? UInt64 {
            return value
        }
        if let value = value as? NSNumber {
            return value.uint64Value
        }
        if let value = value as? String {
            return UInt64(value)
        }
        return nil
    }
}

public struct ReaderCoreHostRequest {
    public let operationId: UInt64
    public let capability: String
    public let rawParams: [String: Any]

    public init(operationId: UInt64, capability: String, rawParams: [String: Any]) {
        self.operationId = operationId
        self.capability = capability
        self.rawParams = rawParams
    }

    public var url: String? {
        rawParams["url"] as? String
    }

    public var method: String? {
        rawParams["method"] as? String
    }

    public var headers: [String: String] {
        guard let object = rawParams["headers"] as? [String: Any] else {
            return [:]
        }
        var headers: [String: String] = [:]
        for (key, value) in object {
            headers[key] = value as? String ?? "\(value)"
        }
        return headers
    }

    public var body: String? {
        rawParams["body"] as? String
    }
}

public struct ReaderCoreHostResponse {
    public let status: Int
    public let headers: [String: String]
    public let body: String
    /// Final URL after redirects. Core's `HostHttpResponse.final_url` reads
    /// the JSON key `finalUrl` and backs the Legado idiom
    /// `resp.raw().request().url()`. `nil` means "no redirect observed" and
    /// Core falls back to the request URL.
    public let finalUrl: String?

    public init(status: Int = 200, headers: [String: String] = [:], body: String, finalUrl: String? = nil) {
        self.status = status
        self.headers = headers
        self.body = body
        self.finalUrl = (finalUrl?.isEmpty ?? true) ? nil : finalUrl
    }

    public var resultObject: [String: Any] {
        var object: [String: Any] = ["status": status, "body": body]
        if !headers.isEmpty {
            object["headers"] = headers
        }
        if let finalUrl = finalUrl {
            object["finalUrl"] = finalUrl
        }
        return object
    }
}

public protocol ReaderCoreHostTransport {
    func perform(_ request: ReaderCoreHostRequest) throws -> ReaderCoreHostResponse
}

/// Socket-independent policy used by iOS Host transports and the shared
/// cross-platform HTTP conformance vectors. URLSession still owns sockets/TLS.
public enum ReaderCoreHttpPolicy {
    public struct RedirectDecision: Equatable {
        public let method: String
        public let keepBody: Bool
    }

    public struct MultipartFile {
        public let fieldName: String
        public let filename: String
        public let contentType: String
        public let bytes: Data

        public init(fieldName: String, filename: String, contentType: String, bytes: Data) {
            self.fieldName = fieldName
            self.filename = filename
            self.contentType = contentType
            self.bytes = bytes
        }
    }

    public static func redirectMethod(status: Int, method: String, hasBody: Bool) -> RedirectDecision {
        let upper = method.uppercased()
        let becomesGet = (status == 303 && upper != "HEAD")
            || ((status == 301 || status == 302) && upper == "POST")
        return becomesGet
            ? RedirectDecision(method: "GET", keepBody: false)
            : RedirectDecision(method: method, keepBody: hasBody)
    }

    public static func resolveLocation(currentUrl: String, location: String) throws -> String {
        guard let base = URL(string: currentUrl),
              let resolved = URL(string: location, relativeTo: base)?.absoluteURL else {
            throw ReaderCoreClientError.hostTransportFailed("invalid redirect Location")
        }
        return resolved.absoluteString
    }

    public static func allowNextRedirect(
        followRedirects: Bool,
        maxRedirects: Int,
        observedHops: Int
    ) -> Bool {
        followRedirects && observedHops < maxRedirects
    }

    public static func redirectHeaders(
        _ headers: [String: String],
        sameOrigin: Bool
    ) -> [String: String] {
        guard !sameOrigin else { return headers }
        let sensitive: Set<String> = ["authorization", "proxy-authorization", "cookie", "origin"]
        return headers.filter { !sensitive.contains($0.key.trimmingCharacters(in: .whitespaces).lowercased()) }
    }

    public static func mergeCookieHeader(explicitCookie: String, jarCookie: String) -> String {
        [explicitCookie, jarCookie]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "; ")
    }

    public static func observedCookieNames(_ setCookies: [String]) -> [String] {
        setCookies.compactMap { cookie in
            guard let separator = cookie.firstIndex(of: "=") else { return nil }
            let name = cookie[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }
    }

    public static func encode(text: String, charset: String) throws -> Data {
        guard let encoding = stringEncoding(charset), let data = text.data(using: encoding) else {
            throw ReaderCoreClientError.hostTransportFailed("cannot encode request charset \(charset)")
        }
        return data
    }

    public static func decode(bytes: Data, charset: String) throws -> String {
        guard let encoding = stringEncoding(charset), let text = String(data: bytes, encoding: encoding) else {
            throw ReaderCoreClientError.hostTransportFailed("cannot decode response charset \(charset)")
        }
        return text
    }

    public static func responseCharset(contentType: String?) -> String {
        guard let contentType else { return "utf-8" }
        for component in contentType.split(separator: ";").dropFirst() {
            let pair = component.split(separator: "=", maxSplits: 1)
            if pair.count == 2 && pair[0].trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() == "charset" {
                let value = pair[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !value.isEmpty { return value }
            }
        }
        return "utf-8"
    }

    public static func retryBackoffMillis(
        baseMillis: Int,
        attempt: Int,
        maxMillis: Int,
        remainingMillis: Int
    ) -> Int {
        min(baseMillis * attempt, maxMillis, remainingMillis)
    }

    public static func deadlineState(
        cancelled: Bool,
        nowMillis: Int,
        deadlineAtMillis: Int
    ) -> String {
        if cancelled { return "cancelled" }
        return nowMillis >= deadlineAtMillis ? "expired" : "active"
    }

    public static func multipart(
        boundary: String,
        fields: [String: String],
        files: [MultipartFile]
    ) -> Data {
        var output = Data()
        for (name, value) in fields {
            output.append(Data("--\(boundary)\r\n".utf8))
            output.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
            output.append(Data(value.utf8))
            output.append(Data("\r\n".utf8))
        }
        for file in files {
            output.append(Data("--\(boundary)\r\n".utf8))
            output.append(Data(
                "Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.filename)\"\r\n".utf8
            ))
            output.append(Data("Content-Type: \(file.contentType)\r\n\r\n".utf8))
            output.append(file.bytes)
            output.append(Data("\r\n".utf8))
        }
        output.append(Data("--\(boundary)--\r\n".utf8))
        return output
    }

    private static func stringEncoding(_ charset: String) -> String.Encoding? {
        let cfEncoding: CFStringEncoding
        switch charset.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "utf-8", "utf8":
            return .utf8
        case "gbk", "gb2312", "gb18030":
            // CFStringEncodingExt.h: kCFStringEncodingGB_18030_2000.
            cfEncoding = CFStringEncoding(0x0632)
        case "big5", "big-5":
            // CFStringEncodingExt.h: kCFStringEncodingBig5.
            cfEncoding = CFStringEncoding(0x0A03)
        default:
            return nil
        }
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
    }
}

public final class URLSessionHostTransport: ReaderCoreHostTransport {
    public let session: URLSession
    public let timeout: TimeInterval

    public init(session: URLSession = .shared, timeout: TimeInterval = 30) {
        self.session = session
        self.timeout = timeout
    }

    public func perform(_ request: ReaderCoreHostRequest) throws -> ReaderCoreHostResponse {
        guard let urlString = request.url, !urlString.isEmpty else {
            throw ReaderCoreClientError.hostTransportFailed("http.execute request missing url")
        }
        guard let url = URL(string: urlString) else {
            throw ReaderCoreClientError.hostTransportFailed("http.execute request url is invalid")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method ?? "GET"
        for (field, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }
        if let body = request.body, !body.isEmpty {
            let charset = request.rawParams["charset"] as? String ?? "utf-8"
            urlRequest.httpBody = try ReaderCoreHttpPolicy.encode(text: body, charset: charset)
        }

        let semaphore = DispatchSemaphore(value: 0)
        var captured: Result<ReaderCoreHostResponse, Error>?

        let task = session.dataTask(with: urlRequest) { data, response, error in
            if let error {
                captured = .failure(error)
            } else if let httpResponse = response as? HTTPURLResponse {
                var headers: [String: String] = [:]
                for (key, value) in httpResponse.allHeaderFields {
                    if let key = key as? String {
                        headers[key] = value as? String ?? "\(value)"
                    }
                }
                let charset = ReaderCoreHttpPolicy.responseCharset(
                    contentType: httpResponse.value(forHTTPHeaderField: "Content-Type")
                )
                let bodyString: String
                do {
                    bodyString = try ReaderCoreHttpPolicy.decode(
                        bytes: data ?? Data(), charset: charset
                    )
                } catch {
                    captured = .failure(error)
                    semaphore.signal()
                    return
                }
                // Capture the resolved URL after redirects so Core can back
                // `resp.raw().request().url()`. `httpResponse.url` reflects the
                // final destination of the redirect chain when the underlying
                // URLSession follows redirects automatically.
                let finalUrl = httpResponse.url?.absoluteString
                captured = .success(ReaderCoreHostResponse(
                    status: httpResponse.statusCode,
                    headers: headers,
                    body: bodyString,
                    finalUrl: finalUrl
                ))
            } else {
                captured = .failure(ReaderCoreClientError.hostTransportFailed("non-http response"))
            }
            semaphore.signal()
        }

        task.resume()
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            task.cancel()
            throw URLError(.timedOut)
        }

        guard let result = captured else {
            throw ReaderCoreClientError.hostTransportFailed("urlsession produced no result")
        }
        return try result.get()
    }
}

/// Handler invoked when Core issues a `host.request` for a given capability.
///
/// The handler is responsible for performing the host-side work (HTTP fetch,
/// cache lookup, persistence, etc.) and returning the `result` object that will
/// be forwarded to Core via `host.complete`. Throwing surfaces as a
/// `host.error` with code `INTERNAL`.
public typealias HostCapabilityHandler = (ReaderCoreHostRequest) throws -> [String: Any]

/// Routes `host.request` events to capability-specific handlers.
///
/// The default transport (when provided) is automatically registered for
/// `http.execute`. Additional capabilities can be registered via `register`.
/// Unknown capabilities throw `missingHostTransport` so callers fail fast
/// instead of being forced through the HTTP transport.
public final class CapabilityRouter {
    public static let httpExecuteCapability = "http.execute"

    private var handlers: [String: HostCapabilityHandler] = [:]
    private let defaultTransport: ReaderCoreHostTransport?

    public init(defaultTransport: ReaderCoreHostTransport? = nil) {
        self.defaultTransport = defaultTransport
        if let transport = defaultTransport {
            register(Self.httpExecuteCapability) { request in
                let response = try transport.perform(request)
                return response.resultObject
            }
        }
    }

    public func register(_ capability: String, handler: @escaping HostCapabilityHandler) {
        handlers[capability] = handler
    }

    public func handler(for capability: String) -> HostCapabilityHandler? {
        handlers[capability]
    }

    public func route(_ request: ReaderCoreHostRequest) throws -> [String: Any] {
        if let handler = handlers[request.capability] {
            return try handler(request)
        }
        throw ReaderCoreClientError.missingHostTransport
    }
}

private final class ReaderCoreEventSink {
    let onEvent: (Data) -> Void

    init(onEvent: @escaping (Data) -> Void) {
        self.onEvent = onEvent
    }
}

private let readerCoreEventCallback: rc_event_callback = { context, bytes, length in
    guard let context, let bytes else {
        return
    }

    let sink = Unmanaged<ReaderCoreEventSink>.fromOpaque(context).takeUnretainedValue()
    sink.onEvent(Data(bytes: bytes, count: length))
}

private final class ReaderCoreEventBuffer {
    private let condition = NSCondition()
    private var events: [Result<ReaderCoreEvent, ReaderCoreClientError>] = []

    func append(_ data: Data) {
        let event: Result<ReaderCoreEvent, ReaderCoreClientError>
        do {
            event = .success(try ReaderCoreEvent(data: data))
        } catch let error as ReaderCoreClientError {
            event = .failure(error)
        } catch {
            event = .failure(.invalidEventJSON)
        }

        condition.lock()
        events.append(event)
        condition.broadcast()
        condition.unlock()
    }

    func wait(requestId: UInt64, timeout: TimeInterval) throws -> ReaderCoreEvent {
        let deadline = Date().addingTimeInterval(timeout)

        condition.lock()
        defer { condition.unlock() }

        while true {
            for (index, event) in events.enumerated() {
                switch event {
                case .success(let event) where event.requestId == requestId:
                    events.remove(at: index)
                    return event
                case .failure(let error):
                    events.remove(at: index)
                    throw error
                default:
                    continue
                }
            }

            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else {
                throw ReaderCoreClientError.requestTimedOut(requestId)
            }

            condition.wait(until: deadline)
        }
    }

    func poll(requestId: UInt64) -> Result<ReaderCoreEvent, ReaderCoreClientError>? {
        condition.lock()
        defer { condition.unlock() }

        for (index, event) in events.enumerated() {
            switch event {
            case .success(let event) where event.requestId == requestId:
                events.remove(at: index)
                return .success(event)
            case .failure(let error):
                events.remove(at: index)
                return .failure(error)
            default:
                continue
            }
        }
        return nil
    }
}

public final class ReaderCoreRuntime {
    public static var abiVersion: UInt32 {
        rc_abi_version()
    }

    /// Reads Core's thread-local `rc_last_error` slot (errno-style).
    ///
    /// `rc_last_error` has NO runtime parameter — it is thread-local, so this
    /// is a static method. The caller must be on the same thread that issued
    /// the failing Core call. Allocates a 4096-byte `[CChar]` buffer, passes
    /// it together with its capacity to `rc_last_error`, then reads the
    /// NUL-terminated message via `String(cString:)`.
    public static func lastError() -> ReaderCoreLastError {
        var buffer = [CChar](repeating: 0, count: 4096)
        let code = buffer.withUnsafeMutableBufferPointer { ptr -> Int32 in
            // `rc_last_error(char *out_message, size_t message_capacity)`
            rc_last_error(ptr.baseAddress, numericCast(ptr.count))
        }
        let message = String(cString: buffer)
        return ReaderCoreLastError(code: code, message: message)
    }

    private var handle: OpaquePointer?
    private var sinkContext: UnsafeMutableRawPointer?

    public init(configJSON: Data = Data(), onEvent: @escaping (Data) -> Void) throws {
        self.sinkContext = nil

        let sink = ReaderCoreEventSink(onEvent: onEvent)
        let sinkContext = Unmanaged.passRetained(sink).toOpaque()
        self.sinkContext = sinkContext

        var runtime: OpaquePointer?
        let status = configJSON.withUnsafeBytes { rawBuffer in
            rc_runtime_create(
                rawBuffer.bindMemory(to: UInt8.self).baseAddress,
                configJSON.count,
                readerCoreEventCallback,
                sinkContext,
                &runtime
            )
        }

        guard status == 0, let runtime else {
            self.sinkContext = nil
            Unmanaged<ReaderCoreEventSink>.fromOpaque(sinkContext).release()
            throw ReaderCoreClientError.createFailed(status)
        }

        self.handle = runtime
    }

    deinit {
        if let handle {
            rc_runtime_destroy(handle)
        }
        if let sinkContext {
            Unmanaged<ReaderCoreEventSink>.fromOpaque(sinkContext).release()
        }
    }

    public func send(json: Data) throws {
        guard let handle else {
            throw ReaderCoreClientError.runtimeDestroyed
        }

        let status = json.withUnsafeBytes { rawBuffer in
            rc_runtime_send(
                handle,
                rawBuffer.bindMemory(to: UInt8.self).baseAddress,
                json.count
            )
        }

        guard status == 0 else {
            if status == 5 { throw ReaderCoreClientError.busy }
            if status == 6 { throw ReaderCoreClientError.resourceExhausted }
            throw ReaderCoreClientError.sendFailed(status)
        }
    }

    public func send(jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw ReaderCoreClientError.sendFailed(-1)
        }
        try send(json: data)
    }

    public func cancel(requestId: UInt64) throws {
        guard let handle else {
            throw ReaderCoreClientError.runtimeDestroyed
        }

        let status = rc_runtime_cancel(handle, requestId)
        guard status == 0 else {
            throw ReaderCoreClientError.cancelFailed(status)
        }
    }

    public func destroy() {
        if let handle {
            rc_runtime_destroy(handle)
            self.handle = nil
        }
    }
}

public final class ReaderCoreClient {
    public static let protocolVersion: UInt32 = 1

    private let eventBuffer: ReaderCoreEventBuffer
    private let runtime: ReaderCoreRuntime
    private let hostTransport: ReaderCoreHostTransport?
    public let capabilityRouter: CapabilityRouter

    private let commandIdLock = NSLock()
    private var commandIdCounter: UInt64 = 9_000_000_000_000_000

    public init(configJSON: Data = Data(), hostTransport: ReaderCoreHostTransport? = nil) throws {
        let eventBuffer = ReaderCoreEventBuffer()
        self.eventBuffer = eventBuffer
        self.hostTransport = hostTransport
        self.capabilityRouter = CapabilityRouter(defaultTransport: hostTransport)
        self.runtime = try ReaderCoreRuntime(configJSON: configJSON) { data in
            eventBuffer.append(data)
        }
    }

    @discardableResult
    public func coreInfo(requestId: UInt64 = 1, timeout: TimeInterval = 2) throws -> ReaderCoreEvent {
        try request(method: "core.info", requestId: requestId, timeout: timeout)
    }

    @discardableResult
    public func ping(requestId: UInt64 = 2, timeout: TimeInterval = 2) throws -> ReaderCoreEvent {
        try request(method: "runtime.ping", requestId: requestId, timeout: timeout)
    }

    @discardableResult
    public func send(
        method: String,
        requestId: UInt64,
        params: [String: Any] = [:]
    ) throws -> UInt64 {
        try sendCommand(method: method, requestId: requestId, params: params)
        return requestId
    }

    @discardableResult
    public func request(
        method: String,
        requestId: UInt64,
        params: [String: Any] = [:],
        timeout: TimeInterval = 5
    ) throws -> ReaderCoreEvent {
        try sendCommand(method: method, requestId: requestId, params: params)
        return try waitForResolved(requestId: requestId, timeout: timeout)
    }

    @discardableResult
    public func pollEvent(requestId: UInt64) -> Result<ReaderCoreEvent, ReaderCoreClientError>? {
        eventBuffer.poll(requestId: requestId)
    }

    public func cancel(requestId: UInt64) throws {
        try runtime.cancel(requestId: requestId)
    }

    @discardableResult
    public func sendHostComplete(
        operationId: UInt64,
        result: [String: Any],
        requestId: UInt64? = nil
    ) throws -> UInt64 {
        let commandId = requestId ?? nextCommandId()
        try sendCommand(
            method: "host.complete",
            requestId: commandId,
            params: [
                "operationId": NSNumber(value: operationId),
                "result": result,
            ]
        )
        return commandId
    }

    @discardableResult
    public func sendHostError(
        operationId: UInt64,
        code: String,
        message: String,
        retryable: Bool,
        requestId: UInt64? = nil
    ) throws -> UInt64 {
        // Fail fast: Core's host.error deserializes code as the ErrorCode enum.
        // An unknown code would make host.error parsing fail and the original
        // pending request would never resume (silent caller timeout).
        guard ReaderCoreHostErrorCode.isValid(code) else {
            throw ReaderCoreClientError.invalidHostErrorCode(code)
        }
        let commandId = requestId ?? nextCommandId()
        try sendCommand(
            method: "host.error",
            requestId: commandId,
            params: [
                "operationId": NSNumber(value: operationId),
                "error": [
                    "code": code,
                    "message": message,
                    "retryable": retryable,
                ],
            ]
        )
        return commandId
    }

    public func destroy() {
        runtime.destroy()
    }

    private func sendCommand(method: String, requestId: UInt64, params: [String: Any]) throws {
        let command: [String: Any] = [
            "protocolVersion": NSNumber(value: Self.protocolVersion),
            "requestId": NSNumber(value: requestId),
            "method": method,
            "params": params,
        ]

        guard JSONSerialization.isValidJSONObject(command) else {
            throw ReaderCoreClientError.invalidCommandJSON
        }

        let json: Data
        do {
            json = try JSONSerialization.data(withJSONObject: command)
        } catch {
            throw ReaderCoreClientError.invalidCommandJSON
        }

        try runtime.send(json: json)
    }

    private func waitForResolved(requestId: UInt64, timeout: TimeInterval) throws -> ReaderCoreEvent {
        let deadline = Date().addingTimeInterval(timeout)

        while true {
            let remaining = max(0, deadline.timeIntervalSinceNow)
            let event = try eventBuffer.wait(requestId: requestId, timeout: remaining)

            switch event.type {
            case "result":
                return event
            case "error":
                throw ReaderCoreClientError.coreError(event.coreError ?? ReaderCoreCoreError(
                    code: "INTERNAL",
                    message: "",
                    retryable: false,
                    rawData: event.rawData
                ))
            case "host.request":
                let hostRequest = try makeHostRequest(from: event)
                do {
                    let result = try capabilityRouter.route(hostRequest)
                    _ = try sendHostComplete(
                        operationId: hostRequest.operationId,
                        result: result
                    )
                } catch ReaderCoreClientError.missingHostTransport {
                    // No handler registered for this capability (and no default
                    // transport). Preserve the legacy synchronous throw so
                    // callers distinguish "not configured" from "configured but
                    // failed" — the latter surfaces as a core error via host.error.
                    throw ReaderCoreClientError.missingHostTransport
                } catch {
                    let policy = hostFailurePolicy(error)
                    _ = try sendHostError(
                        operationId: hostRequest.operationId,
                        code: policy.code,
                        message: "\(error)",
                        retryable: policy.retryable
                    )
                }
                continue
            default:
                throw ReaderCoreClientError.invalidEventJSON
            }
        }
    }

    /// Preserve standard platform failure kinds across host.error. Retryability
    /// describes whether a later caller request can recover; this adapter does
    /// not replay requests or guess that arbitrary Host failures are transient.
    private func hostFailurePolicy(_ error: Error) -> (code: String, retryable: Bool) {
        let platformError = error as NSError
        guard platformError.domain == NSURLErrorDomain else { return ("INTERNAL", false) }
        switch URLError.Code(rawValue: platformError.code) {
        case .cancelled:
            return ("CANCELLED", false)
        case .timedOut:
            return ("TIMEOUT", true)
        case .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost,
             .networkConnectionLost, .notConnectedToInternet:
            return ("INTERNAL", true)
        default:
            // TLS, authentication, malformed URL, and unsupported protocol
            // require their own correction before a request is safe to retry.
            return ("INTERNAL", false)
        }
    }

    private func makeHostRequest(from event: ReaderCoreEvent) throws -> ReaderCoreHostRequest {
        guard event.isHostRequest else {
            throw ReaderCoreClientError.invalidEventJSON
        }
        return ReaderCoreHostRequest(
            operationId: event.operationId ?? 0,
            capability: event.capability ?? "",
            rawParams: event.hostRequestParams ?? [:]
        )
    }

    private func nextCommandId() -> UInt64 {
        commandIdLock.lock()
        defer { commandIdLock.unlock() }
        commandIdCounter += 1
        return commandIdCounter
    }
}
