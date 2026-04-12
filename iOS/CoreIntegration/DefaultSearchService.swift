import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

public final class DefaultSearchService: SearchService {
    private let httpClient: HTTPClient
    private let requestBuilder: RequestBuilder
    private let searchParser: SearchParser

    public init(
        httpClient: HTTPClient,
        requestBuilder: RequestBuilder,
        searchParser: SearchParser
    ) {
        self.httpClient = httpClient
        self.requestBuilder = requestBuilder
        self.searchParser = searchParser
    }

    public func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem] {
        let request = try requestBuilder.makeSearchRequest(source: source, query: query)
        let response = try await httpClient.send(request)

        guard response.statusCode >= 200 && response.statusCode < 300 else {
            throw ReaderError.network(
                failureType: .SEARCH_FAILED,
                stage: "SEARCH",
                message: "HTTP \(response.statusCode)",
                underlyingError: nil
            )
        }

        return try searchParser.parseSearchResponse(response.data, source: source, query: query)
    }
}
