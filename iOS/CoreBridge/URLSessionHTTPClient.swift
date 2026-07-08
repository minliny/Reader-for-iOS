import Foundation
import ReaderCoreProtocols

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
public final class URLSessionHTTPClient: HTTPClient, Sendable {
    private let session: URLSession
    private let cookieJar: ScopedCookieJar?
    private let followRedirectsDefault: Bool

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
        self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let url = URL(string: request.url) else {
            throw HTTPClientError.invalidURL(request.url)
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
            if !cookies.isEmpty {
                let cookieHeader = cookies
                    .map { "\($0.name)=\($0.value)" }
                    .joined(separator: "; ")
                urlRequest.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            }
        }

        let followRedirects = request.followRedirects ?? followRedirectsDefault

        // Use the delegate-based dataTask so we can stamp the task with a
        // per-request redirect policy (taskDescription), which the delegate
        // reads in `willPerformHTTPRedirection`.
        let payload: RawResponse = try await withCheckedThrowingContinuation { cont in
            let task = session.dataTask(with: urlRequest) { data, response, error in
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
            task.taskDescription = followRedirects
                ? HTTPRedirectPolicy.follow.rawValue
                : HTTPRedirectPolicy.cancel.rawValue
            task.resume()
        }

        // Cookie jar write: persist Set-Cookie values into the request scope.
        if request.useCookieJar, let jar = cookieJar, !payload.setCookies.isEmpty {
            let scopeKey = request.cookieScopeKey ?? .default
            let domain = url.host ?? ""
            let fallbackPath = url.path.isEmpty ? "/" : url.path
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

// MARK: - Raw response payload

private struct RawResponse {
    let response: HTTPURLResponse
    let data: Data
    let setCookies: [String]
}

// MARK: - Redirect policy (per-task, via taskDescription)

private enum HTTPRedirectPolicy: String {
    case follow = "follow"
    case cancel = "no-follow"
}

// MARK: - Session delegate (redirect + auth challenge)

private final class HTTPSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        if task.taskDescription == HTTPRedirectPolicy.cancel.rawValue {
            // Per-request opt-out: do not follow the redirect.
            completionHandler(nil)
        } else {
            completionHandler(newRequest)
        }
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
