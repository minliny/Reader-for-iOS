import Foundation
import ReaderCoreProtocols

/// Optional extension implemented by HTTP clients that can bind a contract
/// request id to the concrete transport task and cancel that task later.
/// `HTTPClient.send(_:)` remains unchanged for Core and service call sites.
public protocol RequestScopedHTTPClient: HTTPClient {
    func send(_ request: HTTPRequest, requestId: String) async throws -> HTTPResponse
    @discardableResult func cancel(requestId: String) -> Bool
}

/// Optional Host-contract extension. Core's `http.execute` carries a redirect
/// cap that is not part of Reader-Core's generic `HTTPRequest`; the router uses
/// this seam when the concrete transport supports it.
public protocol HostConfiguredHTTPClient: RequestScopedHTTPClient {
    func send(
        _ request: HTTPRequest,
        requestId: String?,
        maxRedirects: Int?
    ) async throws -> HTTPResponse
}

/// Host HTTP client backed by `URLSession`.
///
/// Implements the three host-side HTTP capabilities required by S4 host proof:
/// - **Cookie jar**: reads cookies from a `ScopedCookieJar` (partitioned by
///   `CookieJarScopeKey`) into the request `Cookie` header and writes
///   `Set-Cookie` response headers back into the jar. When a jar is injected,
///   `URLSession`'s own cookie storage is disabled so isolation is governed
///   entirely by the jar's scope keys (no cross-source / cross-host leakage).
/// - **Redirect**: a `URLSessionTaskDelegate` records the final URL (via
///   `HTTPURLResponse.url`) and honors per-request `followRedirects`
///   (intercept by cancelling the redirect).
/// - **URLAuthenticationChallenge**: basic/digest challenges fall through to
///   `.performDefaultHandling` (no crash); when the request carries an
///   `Authorization: Basic` header, the decoded credentials are supplied as a
///   `URLCredential` so `URLSession` can answer a 401 challenge.
public final class URLSessionHTTPClient: HostConfiguredHTTPClient, Sendable {
    private let session: URLSession
    private let sessionDelegate: HTTPSessionDelegate
    private let cookieJar: ScopedCookieJar?
    private let followRedirectsDefault: Bool
    private let taskRegistry = URLSessionTaskRegistry()

    public init(
        configuration: URLSessionConfiguration? = nil,
        cookieJar: ScopedCookieJar? = nil,
        followRedirectsDefault: Bool = true
    ) {
        self.cookieJar = cookieJar
        self.followRedirectsDefault = followRedirectsDefault

        let config = configuration ?? URLSessionConfiguration.default
        // When an external scoped jar is in play, disable URLSession's automatic
        // cookie handling so scope isolation is governed by the jar, not the
        // shared HTTPCookieStorage. Otherwise accept cookies normally.
        if cookieJar != nil {
            config.httpShouldSetCookies = false
            config.httpCookieStorage = nil
            config.httpCookieAcceptPolicy = .never
        } else {
            config.httpShouldSetCookies = true
            config.httpCookieAcceptPolicy = .always
        }

        let delegate = HTTPSessionDelegate()
        self.sessionDelegate = delegate
        self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        try await send(request, requestId: nil, maxRedirects: nil)
    }

    public func send(_ request: HTTPRequest, requestId: String) async throws -> HTTPResponse {
        try await send(request, requestId: Optional(requestId), maxRedirects: nil)
    }

    @discardableResult
    public func cancel(requestId: String) -> Bool {
        taskRegistry.cancel(requestId: requestId)
    }

    public func send(
        _ request: HTTPRequest,
        requestId: String?,
        maxRedirects: Int?
    ) async throws -> HTTPResponse {
        guard let url = URL(string: request.url),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host?.isEmpty == false else {
            throw HTTPClientError.invalidURL(request.url)
        }
        if request.requiresCookieJar && (!request.useCookieJar || cookieJar == nil) {
            throw HTTPClientError.transport("request requires an unavailable scoped cookie jar")
        }

        var urlRequest = URLRequest(url: url, timeoutInterval: request.timeout)
        urlRequest.httpMethod = request.method
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        urlRequest.httpBody = request.body

        // Cookie jar read: stamp the request with cookies for this scope.
        if request.useCookieJar, let jar = cookieJar {
            let scopeKey = request.cookieScopeKey ?? .default
            let domain = url.host ?? ""
            let path = url.path.isEmpty ? "/" : url.path
            let cookies = await jar.getCookies(for: domain, path: path, scopeKey: scopeKey)
                .filter { !($0.secure && scheme != "https") }
            if !cookies.isEmpty {
                let cookieHeader = cookies
                    .map { "\($0.name)=\($0.value)" }
                    .joined(separator: "; ")
                urlRequest.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            }
        }

        let followRedirects = request.followRedirects ?? followRedirectsDefault

        // Use the delegate-based dataTask so redirect policy/count can be
        // registered per task before it starts.
        let registryToken = UUID()
        let payload: RawResponse = try await withCheckedThrowingContinuation { cont in
            let task = session.dataTask(with: urlRequest) { data, response, error in
                if let requestId {
                    self.taskRegistry.remove(requestId: requestId, token: registryToken)
                }
                if let error = error {
                    cont.resume(throwing: HTTPClientError.transport(error.localizedDescription))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    cont.resume(throwing: HTTPClientError.invalidResponse)
                    return
                }
                let setCookies = Self.setCookieValues(from: httpResponse)
                cont.resume(returning: RawResponse(
                    response: httpResponse,
                    data: data ?? Data(),
                    setCookies: setCookies
                ))
            }
            self.sessionDelegate.register(
                taskIdentifier: task.taskIdentifier,
                followRedirects: followRedirects,
                maxRedirects: maxRedirects
            )
            if let requestId {
                self.taskRegistry.register(task, requestId: requestId, token: registryToken)
            }
            task.resume()
        }

        // Cookie jar write: persist Set-Cookie values into the request scope.
        if request.useCookieJar, let jar = cookieJar, !payload.setCookies.isEmpty {
            let scopeKey = request.cookieScopeKey ?? .default
            let responseURL = payload.response.url ?? url
            let domain = responseURL.host ?? url.host ?? ""
            let fallbackPath = responseURL.path.isEmpty ? "/" : responseURL.path
            for setCookie in payload.setCookies {
                await jar.setCookies(
                    from: setCookie,
                    domain: domain,
                    fallbackPath: fallbackPath,
                    scopeKey: scopeKey
                )
            }
        }

        var headers: [String: String] = [:]
        for (key, value) in payload.response.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                headers[key] = value
            }
        }

        #if READER_IOS_SHELL_CI
        return HTTPResponse(
            statusCode: payload.response.statusCode,
            headers: headers,
            data: payload.data
        )
        #else
        // finalUrl: HTTPURLResponse.url reflects the final URL after redirects.
        let finalUrl: String? = payload.response.url?.absoluteString
        return HTTPResponse(
            statusCode: payload.response.statusCode,
            headers: headers,
            data: payload.data,
            finalUrl: finalUrl
        )
        #endif
    }

    // MARK: - Set-Cookie extraction

    /// Extract all `Set-Cookie` header values from a response.
    ///
    /// `allHeaderFields` may collapse multiple `Set-Cookie` headers into a
    /// single comma-joined value (HTTP/1.1), so callers should pass each value
    /// to `ScopedCookieJar.setCookies(from:domain:...)` for robust parsing.
    private static func setCookieValues(from response: HTTPURLResponse) -> [String] {
        var values: [String] = []
        if let direct = response.value(forHTTPHeaderField: "Set-Cookie") {
            values.append(direct)
        }
        for (key, value) in response.allHeaderFields {
            guard let key = key as? String, let value = value as? String else { continue }
            if key.lowercased() == "set-cookie", !values.contains(value) {
                values.append(value)
            }
        }
        return values
    }
}

/// Lock-protected transport-task registry. Registration uses a unique token so
/// completion of an older task cannot remove a newer task that reused the same
/// contract request id.
private final class URLSessionTaskRegistry: @unchecked Sendable {
    private struct Entry {
        let token: UUID
        let task: URLSessionTask
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]

    func register(_ task: URLSessionTask, requestId: String, token: UUID) {
        let previous: URLSessionTask?
        lock.lock()
        previous = entries.updateValue(Entry(token: token, task: task), forKey: requestId)?.task
        lock.unlock()
        // Reusing an id means the newest request owns the cancellation slot.
        // Stop the displaced task so it cannot continue without an addressable
        // request id.
        previous?.cancel()
    }

    func remove(requestId: String, token: UUID) {
        lock.lock()
        defer { lock.unlock() }
        guard entries[requestId]?.token == token else { return }
        entries.removeValue(forKey: requestId)
    }

    @discardableResult
    func cancel(requestId: String) -> Bool {
        let task: URLSessionTask?
        lock.lock()
        task = entries.removeValue(forKey: requestId)?.task
        lock.unlock()
        task?.cancel()
        return task != nil
    }
}

// MARK: - Raw response payload

private struct RawResponse {
    let response: HTTPURLResponse
    let data: Data
    let setCookies: [String]
}

// MARK: - Redirect policy (per-task, via taskDescription)

// MARK: - Session delegate (redirect + auth challenge)

private final class HTTPSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private struct RedirectState {
        let follows: Bool
        let maximum: Int?
        var count: Int
    }

    private let redirectLock = NSLock()
    private var redirectStates: [Int: RedirectState] = [:]

    func register(taskIdentifier: Int, followRedirects: Bool, maxRedirects: Int?) {
        redirectLock.lock()
        redirectStates[taskIdentifier] = RedirectState(
            follows: followRedirects,
            maximum: maxRedirects,
            count: 0
        )
        redirectLock.unlock()
    }

    func remove(taskIdentifier: Int) {
        redirectLock.lock()
        redirectStates.removeValue(forKey: taskIdentifier)
        redirectLock.unlock()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        let shouldFollow: Bool = {
            redirectLock.lock()
            defer { redirectLock.unlock() }
            guard var state = redirectStates[task.taskIdentifier], state.follows else {
                return false
            }
            if let maximum = state.maximum, state.count >= maximum {
                return false
            }
            state.count += 1
            redirectStates[task.taskIdentifier] = state
            return true
        }()
        completionHandler(shouldFollow ? newRequest : nil)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        remove(taskIdentifier: task.taskIdentifier)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest:
            // If the original request carried an `Authorization: Basic ...`
            // header, surface those credentials to answer the challenge.
            if let credential = Self.basicCredential(from: task.currentRequest) {
                completionHandler(.useCredential, credential)
            } else {
                // No credentials on the request; defer to URLSession's default
                // handling rather than crashing.
                completionHandler(.performDefaultHandling, nil)
            }
        default:
            // Server trust, client cert, etc.: default handling (no crash).
            completionHandler(.performDefaultHandling, nil)
        }
    }

    private static func basicCredential(from request: URLRequest?) -> URLCredential? {
        guard let request = request,
              let header = request.value(forHTTPHeaderField: "Authorization")
                ?? request.value(forHTTPHeaderField: "authorization"),
              header.lowercased().hasPrefix("basic ") else {
            return nil
        }
        let encoded = String(header.dropFirst("basic ".count))
        guard let data = Data(base64Encoded: encoded),
              let decoded = String(data: data, encoding: .utf8) else {
            return nil
        }
        let parts = decoded.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        return URLCredential(
            user: String(parts[0]),
            password: String(parts[1]),
            persistence: .forSession
        )
    }
}

public enum HTTPClientError: Error, LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .invalidResponse: return "Invalid HTTP response"
        case .transport(let message): return "HTTP transport error: \(message)"
        }
    }
}
