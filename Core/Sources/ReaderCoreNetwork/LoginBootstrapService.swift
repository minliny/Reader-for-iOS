import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

private actor LoginBootstrapRegistry {
    private var bootstrappedScopes: Set<CookieJarScopeKey> = []

    func contains(_ scopeKey: CookieJarScopeKey) -> Bool {
        bootstrappedScopes.contains(scopeKey)
    }

    func insert(_ scopeKey: CookieJarScopeKey) {
        bootstrappedScopes.insert(scopeKey)
    }
}

private struct HTTPLoginBootstrapRequest: Sendable {
    var preflightRequest: HTTPRequest?
    var submitRequest: HTTPRequest?
    var verificationRequest: HTTPRequest?
    var successMarkers: [String]
    var failureMarkers: [String]

    init(
        preflightRequest: HTTPRequest? = nil,
        submitRequest: HTTPRequest? = nil,
        verificationRequest: HTTPRequest? = nil,
        successMarkers: [String] = [],
        failureMarkers: [String] = []
    ) {
        self.preflightRequest = preflightRequest
        self.submitRequest = submitRequest
        self.verificationRequest = verificationRequest
        self.successMarkers = successMarkers
        self.failureMarkers = failureMarkers
    }
}

public struct LoginBootstrapService: Sendable {
    public typealias RequestSender = @Sendable (HTTPRequest) async throws -> HTTPResponse

    private let httpClient: any HTTPClient
    /// Ephemeral per-service cache:
    /// - Scope: one `LoginBootstrapService` instance (usually one policy layer lifecycle)
    /// - Purpose: skip repeated bootstrap in the same runtime session
    /// - Tradeoff accepted: cache resets when the layer/service is rebuilt; this avoids
    ///   introducing cross-session state coupling while preserving minimal rework boundaries.
    private let registry = LoginBootstrapRegistry()

    public init(httpClient: any HTTPClient) {
        self.httpClient = httpClient
    }

    public func bootstrapIfNeeded(
        for source: BookSource,
        send: RequestSender
    ) async throws {
        guard let scopeKey = scopeKey(for: source, preferredURL: source.loginUrl ?? source.bookSourceUrl) else {
            throw loginRequiredError(
                sourceURL: source.loginUrl ?? source.bookSourceUrl,
                detail: "Login bootstrap requires a scoped host."
            )
        }
        guard await registry.contains(scopeKey) == false else { return }

        if isMalformedLoginDescriptor(in: source) {
            throw loginRequiredError(
                sourceURL: source.loginUrl ?? source.bookSourceUrl,
                detail: "Malformed xReaderLoginFlow descriptor."
            )
        }

        let bootstrap = makeLoginBootstrapRequest(for: source, scopeKey: scopeKey)
        do {
            try await execute(
                bootstrap: bootstrap,
                source: source,
                send: send
            )
            await registry.insert(scopeKey)
        } catch {
            if let scopeManager = httpClient as? CookieScopeManaging {
                await scopeManager.clearCookies(in: scopeKey)
            }
            if let readerError = error as? ReaderError,
               readerError.failure?.type == .LOGIN_REQUIRED {
                throw readerError
            }
            throw loginRequiredError(
                sourceURL: source.loginUrl ?? source.bookSourceUrl,
                detail: errorDetail(from: error)
            )
        }
    }

    private func execute(
        bootstrap: HTTPLoginBootstrapRequest,
        source: BookSource,
        send: RequestSender
    ) async throws {
        var lastResponse: HTTPResponse?
        if let preflightRequest = bootstrap.preflightRequest {
            lastResponse = try await send(preflightRequest)
        }
        if let submitRequest = bootstrap.submitRequest {
            lastResponse = try await send(submitRequest)
        }

        if let verificationRequest = bootstrap.verificationRequest {
            let response = try await send(verificationRequest)
            try validateBootstrap(response, source: source, bootstrap: bootstrap)
            return
        }

        guard let response = lastResponse else {
            throw loginRequiredError(
                sourceURL: source.loginUrl ?? source.bookSourceUrl,
                detail: "Login bootstrap has no executable requests."
            )
        }
        try validateBootstrap(response, source: source, bootstrap: bootstrap)
    }

    private func validateBootstrap(
        _ response: HTTPResponse,
        source: BookSource,
        bootstrap: HTTPLoginBootstrapRequest
    ) throws {
        let body = String(data: response.data, encoding: .utf8)
            ?? String(data: response.data, encoding: .isoLatin1)
            ?? ""

        if let failureMarker = bootstrap.failureMarkers.first(where: { body.contains($0) }) {
            throw loginRequiredError(
                sourceURL: source.loginUrl ?? source.bookSourceUrl,
                detail: "Login bootstrap matched failure marker: \(failureMarker)"
            )
        }

        guard bootstrap.successMarkers.isEmpty || bootstrap.successMarkers.allSatisfy(body.contains) else {
            throw loginRequiredError(
                sourceURL: source.loginUrl ?? source.bookSourceUrl,
                detail: "Login bootstrap completed without all success markers."
            )
        }
    }

    private func makeLoginBootstrapRequest(
        for source: BookSource,
        scopeKey: CookieJarScopeKey
    ) -> HTTPLoginBootstrapRequest {
        var headers = source.header
        if headers["User-Agent"] == nil {
            headers["User-Agent"] = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        }

        let referer = headers["Referer"] ?? source.loginUrl ?? source.bookSourceUrl
        if headers["Referer"] == nil, let referer {
            headers["Referer"] = referer
        }

        let preflightRequest = source.loginUrl.map {
            HTTPRequest(
                url: $0,
                method: "GET",
                headers: headers,
                timeout: 15,
                useCookieJar: true,
                cookieScopeKey: scopeKey
            )
        }

        guard let loginDescriptor = source.loginDescriptor else {
            return HTTPLoginBootstrapRequest(preflightRequest: preflightRequest)
        }

        var submitHeaders = headers
        if submitHeaders["Content-Type"] == nil {
            submitHeaders["Content-Type"] = loginDescriptor.contentType
        }
        let submitRequest = HTTPRequest(
            url: loginDescriptor.actionUrl,
            method: loginDescriptor.method,
            headers: submitHeaders,
            body: formEncodedBody(loginDescriptor.form),
            timeout: 15,
            useCookieJar: true,
            cookieScopeKey: scopeKey
        )

        let verificationRequest = loginDescriptor.successUrl.map {
            HTTPRequest(
                url: $0,
                method: "GET",
                headers: headers,
                timeout: 15,
                useCookieJar: true,
                requiresCookieJar: true,
                cookieScopeKey: scopeKey
            )
        }

        return HTTPLoginBootstrapRequest(
            preflightRequest: preflightRequest,
            submitRequest: submitRequest,
            verificationRequest: verificationRequest,
            successMarkers: loginDescriptor.successMarkers,
            failureMarkers: loginDescriptor.failureMarkers
        )
    }

    private func formEncodedBody(_ form: [String: String]) -> Data? {
        guard !form.isEmpty else { return nil }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let payload = form.keys.sorted().map { key in
            let rawValue = form[key] ?? ""
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encodedValue = rawValue.addingPercentEncoding(withAllowedCharacters: allowed) ?? rawValue
            return "\(encodedKey)=\(encodedValue)"
        }
        .joined(separator: "&")
        return Data(payload.utf8)
    }

    private func scopeKey(for source: BookSource, preferredURL: String? = nil) -> CookieJarScopeKey? {
        guard let urlStr = preferredURL ?? source.bookSourceUrl,
              let url = URL(string: urlStr),
              let host = url.host,
              !host.isEmpty else { return nil }
        let sourceId = source.id ?? source.bookSourceName
        return CookieJarScopeKey(sourceId: sourceId, host: host)
    }

    private func isMalformedLoginDescriptor(in source: BookSource) -> Bool {
        guard case .object(let object)? = source.unknownFields["xReaderLoginFlow"] else {
            return false
        }
        if case .bool(false)? = object["enabled"] {
            return false
        }
        return source.loginDescriptor == nil
    }

    private func errorDetail(from error: Error) -> String {
        if let mappedError = error as? MappedReaderError {
            return mappedError.message
        }
        if let readerError = error as? ReaderError {
            return readerError.message
        }
        return error.localizedDescription
    }

    private func loginRequiredError(sourceURL: String?, detail: String) -> ReaderError {
        ReaderError.network(
            failureType: .LOGIN_REQUIRED,
            stage: Stage.NETWORK.rawValue,
            message: "Login bootstrap failed. \(detail)",
            underlyingError: nil
        )
    }
}
