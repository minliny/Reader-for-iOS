import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

public struct NetworkPolicyLayer: Sendable {
    private let httpClient: any HTTPClient
    private let requestBuilder: any RequestBuilder

    public init(
        httpClient: any HTTPClient,
        requestBuilder: any RequestBuilder = BookSourceRequestBuilder()
    ) {
        self.httpClient = httpClient
        self.requestBuilder = requestBuilder
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
        try await send(requestBuilder.makeSearchRequest(source: source, query: query))
    }

    public func performTOC(source: BookSource, detailURL: String) async throws -> HTTPResponse {
        try await send(requestBuilder.makeTOCRequest(source: source, detailURL: detailURL))
    }

    public func performContent(source: BookSource, chapterURL: String) async throws -> HTTPResponse {
        try await send(requestBuilder.makeContentRequest(source: source, chapterURL: chapterURL))
    }

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
        if let mappedError = error as? MappedReaderError {
            return mappedError
        }
        if let readerError = error as? ReaderError {
            return readerError
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return ErrorMapper.readerError(for: .timeout)
            default:
                return ErrorMapper.readerError(for: .networkError(urlError.localizedDescription))
            }
        }
        return ErrorMapper.readerError(for: .networkError(error.localizedDescription))
    }
}
