import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

public struct NetworkPolicyLayer: Sendable {
    private let httpClient: any HTTPClient
    private let requestBuilder: any RequestBuilder
    private let loginBootstrapService: LoginBootstrapService

    public init(
        httpClient: any HTTPClient,
        requestBuilder: any RequestBuilder = BookSourceRequestBuilder(),
        loginBootstrapService: LoginBootstrapService? = nil
    ) {
        self.httpClient = httpClient
        self.requestBuilder = requestBuilder
        self.loginBootstrapService = loginBootstrapService ?? LoginBootstrapService(httpClient: httpClient)
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        do {
            let response = try await httpClient.send(request)
            return try evaluate(response)
        } catch {
            throw normalize(error)
        }
    }

    public func performSearch(source: BookSource, query: SearchQuery) async throws -> HTTPResponse {
        try await bootstrapLoginIfNeeded(for: source)
        var request = try requestBuilder.makeSearchRequest(source: source, query: query)
        request.cookieScopeKey = scopeKey(for: source)
        return try await send(request)
    }

    public func performTOC(source: BookSource, detailURL: String) async throws -> HTTPResponse {
        try await bootstrapLoginIfNeeded(for: source)
        var request = try requestBuilder.makeTOCRequest(source: source, detailURL: detailURL)
        request.cookieScopeKey = scopeKey(for: source)
        return try await send(request)
    }

    public func performContent(source: BookSource, chapterURL: String) async throws -> HTTPResponse {
        try await bootstrapLoginIfNeeded(for: source)
        var request = try requestBuilder.makeContentRequest(source: source, chapterURL: chapterURL)
        request.cookieScopeKey = scopeKey(for: source)
        return try await send(request)
    }

    private func bootstrapLoginIfNeeded(for source: BookSource) async throws {
        guard source.requiresLogin else { return }
        try await loginBootstrapService.bootstrapIfNeeded(
            for: source
        ) { request in
            try await send(request)
        }
    }

    // MARK: - Scope key derivation

    /// Derives a `CookieJarScopeKey` from a `BookSource`.
    /// Returns `nil` when the source has no usable host (no-cookie sources fall
    /// back to the legacy unscoped jar path in URLSessionHTTPClient).
    private func scopeKey(for source: BookSource, preferredURL: String? = nil) -> CookieJarScopeKey? {
        guard let urlStr = preferredURL ?? source.bookSourceUrl,
              let url = URL(string: urlStr),
              let host = url.host,
              !host.isEmpty
        else { return nil }
        let sourceId = source.id ?? source.bookSourceName
        return CookieJarScopeKey(sourceId: sourceId, host: host)
    }

    // MARK: - Response evaluation

    private func evaluate(_ response: HTTPResponse) throws -> HTTPResponse {
        if response.statusCode == 404 {
            throw ReaderError(
                code: .networkFailed,
                message: "HTTP 404 content fetch failed.",
                failure: FailureRecord(
                    type: .CONTENT_FAILED,
                    reason: "error_mapping",
                    detail: "HTTP 404 content fetch failed."
                ),
                context: ["contract": "error_mapping"]
            )
        }
        if response.statusCode >= 400 {
            throw ErrorMapper.readerError(for: .httpStatus(response.statusCode))
        }
        if response.data.isEmpty {
            throw ErrorMapper.readerError(for: .emptyResponse)
        }
        return response
    }

    private func normalize(_ error: Error) -> Error {
        if let mappedError = error as? MappedReaderError { return mappedError }
        if let readerError  = error as? ReaderError      { return readerError  }
        if let urlError     = error as? URLError {
            switch urlError.code {
            case .timedOut: return ErrorMapper.readerError(for: .timeout)
            default:        return ErrorMapper.readerError(for: .networkError(urlError.localizedDescription))
            }
        }
        return ErrorMapper.readerError(for: .networkError(error.localizedDescription))
    }

}
