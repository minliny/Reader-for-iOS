import CoreFoundation
import Foundation
import os
import ReaderCoreBridge

enum URLSessionNetwork {
    private static let httpBodyLimit = 8 * 1_024 * 1_024

    struct Response: Sendable {
        let data: Data
        let response: HTTPURLResponse
        let redirects: [HTTPURLResponse]
        let redirectReceipts: [M2HostHttpRedirect]
    }

    static func request(_ params: M2HostHttpRequest) throws -> URLRequest {
        let url = try hostHTTPURL(params.url)
        let seconds = timeoutSeconds(params.timeoutMs)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: seconds)
        request.httpMethod = params.method ?? "GET"
        for (header, value) in params.headers ?? [:] {
            request.setValue(try hostHeaderValue(value), forHTTPHeaderField: header)
        }
        if let body = params.body, !body.isEmpty || !["GET", "HEAD"].contains(request.httpMethod ?? "") {
            let charset = params.charset ?? "UTF-8"
            do {
                request.httpBody = try CoreFileABI.encodeText(body, charset: charset, maximumBytes: httpBodyLimit)
            } catch {
                throw NetworkHostFailure(code: .invalidResponse, phase: .request, message: "Core refused request body encoding for \(charset)")
            }
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("text/plain; charset=\(charset)", forHTTPHeaderField: "Content-Type")
            }
        }
        return request
    }

    static func execute(_ request: URLRequest, params: M2HostHttpRequest,
                        jar: HTTPCookieStorage?, bodyLimit: Int = httpBodyLimit) async throws -> Response {
        let timeout = request.timeoutInterval
        let attempts = min(8, max(1, params.retry?.maxAttempts ?? 1))
        let start = ContinuousClock.now
        for attempt in 1...attempts {
            try Task.checkCancellation()
            let remaining = timeout - start.duration(to: .now).timeInterval
            guard remaining > 0 else {
                throw NetworkHostFailure(code: .timeout, phase: .transport, message: "HTTP deadline exceeded", retryable: true)
            }
            do {
                let result = try await read(request, timeout: remaining, jar: jar, followRedirects: params.followRedirects ?? true,
                                            maxRedirects: params.maxRedirects ?? 10, bodyLimit: bodyLimit)
                if attempt == attempts || !NetworkHostFailure.status(result.response.statusCode).retryable {
                    return result
                }
            } catch {
                let failure = NetworkHostFailure.classified(error)
                guard attempt < attempts, failure.retryable else { throw failure }
            }
            let backoff = max(0, min(60_000, params.retry?.backoffMillis ?? 0))
            try await Task.sleep(for: .milliseconds(backoff))
        }
        throw NetworkHostFailure(code: .internal, phase: .runtime, message: "HTTP attempt missing")
    }

    private static func read(_ request: URLRequest, timeout: TimeInterval, jar: HTTPCookieStorage?,
                             followRedirects: Bool, maxRedirects: Int64, bodyLimit: Int) async throws -> Response {
        let policy = HostRedirectPolicy(follow: followRedirects, max: maxRedirects)
        let collector = HostResponseCollector(limit: bodyLimit, redirects: policy)
        let transport = session(timeout: timeout, jar: jar, delegate: collector)
        defer { transport.invalidateAndCancel() }
        let (data, response) = try await collector.read(request, session: transport)
        let redirects = policy.observations()
        return Response(data: data, response: response, redirects: redirects.responses, redirectReceipts: redirects.receipts)
    }

    static func session(timeout: TimeInterval, jar: HTTPCookieStorage?,
                        delegate: (any URLSessionDelegate)? = nil) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.urlCache = nil
        configuration.httpCookieStorage = jar
        configuration.httpShouldSetCookies = jar != nil
        configuration.httpCookieAcceptPolicy = .always
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    static func receipt(_ payload: Response, params: M2HostHttpRequest) -> M2HostHttpResponse {
        let response = payload.response
        let encodingName = response.textEncodingName ?? params.charset
        let decoded = decode(payload.data, charset: encodingName)
        let cookies = cookies(from: [response]).map {
            M2HostHttpCookie(name: $0.name, value: $0.value, domain: $0.domain, path: $0.path,
                             expiresAt: $0.expiresDate?.ISO8601Format(), httpOnly: $0.isHTTPOnly,
                             secure: $0.isSecure, sameSite: $0.sameSitePolicy?.rawValue)
        }
        return .init(
            body: decoded ?? "", status: Int64(response.statusCode), headers: headers(response),
            finalUrl: response.url?.absoluteString, charsetHint: encodingName,
            bodyBase64: decoded == nil || params.responseAsset == true ? payload.data.base64EncodedString() : nil,
            session: params.session, redirects: payload.redirectReceipts, cookies: cookies
        )
    }

    static func cookies(from responses: [HTTPURLResponse]) -> [HTTPCookie] {
        responses.flatMap { response -> [HTTPCookie] in
            guard let url = response.url else { return [] }
            let headers = response.allHeaderFields.reduce(into: [String: String]()) { fields, field in
                if let key = field.key as? String, let value = field.value as? String { fields[key] = value }
            }
            return HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
        }
    }

    static func headers(_ response: HTTPURLResponse) -> [String: ReaderM1JSONValue] {
        response.allHeaderFields.reduce(into: [:]) { headers, entry in
            if let key = entry.key as? String, let value = entry.value as? String {
                headers[key] = .string(value)
            }
        }
    }

    static func timeoutSeconds(_ milliseconds: Int64?) -> TimeInterval {
        TimeInterval(max(1, min(120_000, milliseconds ?? 30_000))) / 1_000
    }

    private static func decode(_ bytes: Data, charset name: String?) -> String? {
        if let name {
            let encoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
            if encoding != kCFStringEncodingInvalidId {
                let stringEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
                if let value = String(data: bytes, encoding: stringEncoding) { return value }
            }
        }
        return String(data: bytes, encoding: .utf8)
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let value = components
        return Double(value.seconds) + Double(value.attoseconds) / 1e18
    }
}

// URLSession calls the delegate off the actor. All mutable redirect observations
// are accessed under the lock. The policy configuration never changes.
final class HostRedirectPolicy: NSObject, URLSessionTaskDelegate {
    struct Observations: Sendable {
        var responses: [HTTPURLResponse] = []
        var receipts: [M2HostHttpRedirect] = []
        var limitExceeded = false
    }

    private let observed = OSAllocatedUnfairLock(initialState: Observations())
    private let follow: Bool
    private let max: Int64

    init(follow: Bool, max: Int64) {
        self.follow = follow
        self.max = max
    }

    func observations() -> Observations { observed.withLock { $0 } }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        guard follow, let from = response.url, let to = request.url,
              (try? hostHTTPURL(to.absoluteString)) != nil else {
            completionHandler(nil)
            return
        }
        guard observed.withLock({ state in
            guard state.receipts.count < max else {
                state.limitExceeded = true
                return false
            }
            state.responses.append(response)
            state.receipts.append(.init(status: Int64(response.statusCode), fromUrl: from.absoluteString,
                                        toUrl: to.absoluteString, headers: URLSessionNetwork.headers(response)))
            return true
        }) else {
            completionHandler(nil)
            return
        }
        var redirected = request
        if origin(from) != origin(to) {
            for name in ["Authorization", "Cookie", "Proxy-Authorization"] {
                redirected.setValue(nil, forHTTPHeaderField: name)
            }
        }
        completionHandler(redirected)
    }

    private func origin(_ url: URL) -> String {
        let scheme = url.scheme?.lowercased() ?? ""
        let port = url.port ?? (scheme == "https" ? 443 : 80)
        return "\(scheme)://\(url.host()?.lowercased() ?? ""):\(port)"
    }
}
