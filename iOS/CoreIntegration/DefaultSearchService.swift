import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreNetwork
import ReaderCoreParser

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
                failureType: .NETWORK_ERROR,
                stage: "SEARCH",
                message: "HTTP \(response.statusCode)",
                underlyingError: nil
            )
        }

        let html = String(data: response.data, encoding: .utf8) ?? ""
        return try searchParser.parse(html: html, source: source)
    }
}
