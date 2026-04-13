import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import ReaderCoreProtocols
import ReaderCoreModels

private actor RedirectResponseStore {
    private var responses: [HTTPURLResponse] = []

    func append(_ response: HTTPURLResponse) {
        responses.append(response)
    }

    func snapshot() -> [HTTPURLResponse] {
        responses
    }
}

private final class RedirectCaptureDelegate: NSObject, URLSessionTaskDelegate {
    private let followRedirects: Bool
    private let store = RedirectResponseStore()

    init(followRedirects: Bool) {
        self.followRedirects = followRedirects
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        Task {
            await store.append(response)
        }
        completionHandler(followRedirects ? request : nil)
    }

    func redirectResponses() async -> [HTTPURLResponse] {
        await store.snapshot()
    }
}

public final class URLSessionHTTPClient: HTTPAdapterProtocol, CookieScopeManaging, @unchecked Sendable {
    private let session: URLSession
    private let cookieJar: CookieJar?
    private let defaultHeaders: [String: String]
    private let followRedirects: Bool

    public init(
        configuration: URLSessionConfiguration = .default,
        cookieJar: CookieJar? = nil,
        defaultHeaders: [String: String] = [:],
        followRedirects: Bool = true
    ) {
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        self.session = URLSession(configuration: configuration)
        self.cookieJar = cookieJar
        self.defaultHeaders = defaultHeaders
        self.followRedirects = followRedirects
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let url = validatedURL(from: request.url) else {
            throw ReaderError.config(
                failureType: .RULE_INVALID,
                stage: Stage.NETWORK.rawValue,
                ruleField: "url",
                message: "Invalid URL: \(request.url)",
                underlyingError: nil
            )
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.timeoutInterval = request.timeout
        urlRequest.httpBody = request.body

        for (key, value) in defaultHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        try validateRequiredHeaders(request.requiredHeaders, in: urlRequest, sourceURL: request.url)

        // Cookie injection — scoped path takes priority over legacy unscoped path.
        let existingCookieHeader = urlRequest.value(forHTTPHeaderField: "Cookie")
        if request.useCookieJar, let jar = cookieJar {
            let cookies = await resolvedCookies(
                jar: jar,
                domain: url.host ?? "",
                path: url.path,
                scopeKey: request.cookieScopeKey
            )
            let cookieValue = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")

            if request.requiresCookieJar && cookieValue.isEmpty && isEmptyHeader(existingCookieHeader) {
                throw cookieRequiredError(sourceURL: request.url)
            }
            if !cookieValue.isEmpty {
                let mergedCookieHeader = [existingCookieHeader, cookieValue]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: existingCookieHeader == nil ? "" : "; ")
                urlRequest.setValue(mergedCookieHeader, forHTTPHeaderField: "Cookie")
            }
        } else if request.requiresCookieJar && isEmptyHeader(existingCookieHeader) {
            throw cookieRequiredError(sourceURL: request.url)
        }

        do {
            let redirectDelegate = RedirectCaptureDelegate(followRedirects: followRedirects)
            let (data, response) = try await session.data(for: urlRequest, delegate: redirectDelegate)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ReaderError.network(
                    failureType: .CONTENT_FAILED,
                    stage: Stage.NETWORK.rawValue,
                    message: "Non-HTTP response received",
                    underlyingError: nil
                )
            }

            var responseHeaders: [String: String] = [:]
            for (key, value) in httpResponse.allHeaderFields {
                if let k = key as? String, let v = value as? String {
                    responseHeaders[k] = v
                }
            }

            // Cookie storage — mirror the scoped/unscoped decision.
            if request.useCookieJar, let jar = cookieJar {
                for redirectResponse in await redirectDelegate.redirectResponses() {
                    let host = redirectResponse.url?.host ?? url.host ?? ""
                    await storeCookies(
                        from: redirectResponse, jar: jar,
                        scopeKey: request.cookieScopeKey, fallbackHost: host
                    )
                }
                let finalHost = httpResponse.url?.host ?? url.host ?? ""
                await storeCookies(
                    from: httpResponse, jar: jar,
                    scopeKey: request.cookieScopeKey, fallbackHost: finalHost
                )
            }

            return HTTPResponse(
                statusCode: httpResponse.statusCode,
                headers: responseHeaders,
                data: data
            )
        } catch let error as URLError {
            switch error.code {
            case .timedOut: throw ErrorMapper.readerError(for: .timeout)
            default:        throw ErrorMapper.readerError(for: .networkError(error.localizedDescription))
            }
        } catch {
            throw ErrorMapper.readerError(for: .networkError(error.localizedDescription))
        }
    }

    // MARK: - Cookie helpers

    /// Reads cookies from the jar, using the scoped API when `scopeKey` is non-nil.
    private func resolvedCookies(
        jar: CookieJar,
        domain: String,
        path: String,
        scopeKey: CookieJarScopeKey?
    ) async -> [Cookie] {
        if let key = scopeKey, let scopedJar = jar as? ScopedCookieJar {
            return await scopedJar.getCookies(for: domain, path: path, scopeKey: key)
        }
        return await jar.getCookies(for: domain, path: path)
    }

    /// Stores `Set-Cookie` headers from `response` into the jar, using the scoped
    /// API when `scopeKey` is non-nil.
    private func storeCookies(
        from response: HTTPURLResponse,
        jar: CookieJar,
        scopeKey: CookieJarScopeKey?,
        fallbackHost: String
    ) async {
        for header in setCookieHeaders(from: response) {
            if let key = scopeKey, let scopedJar = jar as? ScopedCookieJar {
                await scopedJar.setCookies(from: header, domain: fallbackHost, scopeKey: key)
            } else {
                await jar.setCookies(from: header, domain: fallbackHost)
            }
        }
    }

    private func setCookieHeaders(from response: HTTPURLResponse) -> [String] {
        response.allHeaderFields.compactMap { key, value -> [String]? in
            guard let headerName = key as? String,
                  headerName.caseInsensitiveCompare("Set-Cookie") == .orderedSame
            else { return nil }
            if let stringValue  = value as? String   { return [stringValue] }
            if let stringValues = value as? [String] { return stringValues  }
            return nil
        }
        .flatMap { $0 }
    }

    public func clearCookies(in scopeKey: CookieJarScopeKey) async {
        guard let scopedJar = cookieJar as? ScopedCookieJar else {
            return
        }
        await scopedJar.clear(scopeKey: scopeKey)
    }

    // MARK: - Request validation helpers

    private func validateRequiredHeaders(
        _ requiredHeaders: [String],
        in request: URLRequest,
        sourceURL: String
    ) throws {
        for headerName in requiredHeaders {
            let normalized = headerName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            guard let value = request.value(forHTTPHeaderField: normalized),
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                throw MappedReaderError(
                    code: .HEADER_REQUIRED,
                    stage: .request_build,
                    message: "Required header '\(normalized)' is missing from the request.",
                    context: ReaderErrorContext(sourceURL: sourceURL, details: ["headerName": normalized])
                )
            }
        }
    }

    private func isEmptyHeader(_ value: String?) -> Bool {
        guard let value else { return true }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func cookieRequiredError(sourceURL: String) -> MappedReaderError {
        MappedReaderError(
            code: .COOKIE_REQUIRED,
            stage: .request_build,
            message: "Cookie jar is required but no cookies were present for this request.",
            context: ReaderErrorContext(sourceURL: sourceURL)
        )
    }

    private func validatedURL(from rawURL: String) -> URL? {
        guard let url = URL(string: rawURL),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host,
              !host.isEmpty,
              scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }
}
