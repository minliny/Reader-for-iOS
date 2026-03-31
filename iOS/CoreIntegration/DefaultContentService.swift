import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreNetwork
import ReaderCoreParser

public final class DefaultContentService: ContentService {
    private let httpClient: HTTPClient
    private let requestBuilder: RequestBuilder
    private let contentParser: ContentParser

    public init(
        httpClient: HTTPClient,
        requestBuilder: RequestBuilder,
        contentParser: ContentParser
    ) {
        self.httpClient = httpClient
        self.requestBuilder = requestBuilder
        self.contentParser = contentParser
    }

    public func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage {
        let request = try requestBuilder.makeContentRequest(source: source, chapterURL: chapterURL)
        let response = try await httpClient.send(request)

        guard response.statusCode >= 200 && response.statusCode < 300 else {
            throw ReaderError.network(
                failureType: .NETWORK_ERROR,
                stage: "CONTENT",
                message: "HTTP \(response.statusCode)",
                underlyingError: nil
            )
        }

        let html = String(data: response.data, encoding: .utf8) ?? ""
        return try contentParser.parse(html: html, source: source, chapterURL: chapterURL)
    }
}
