import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

public final class DefaultTOCService: TOCService {
    private let httpClient: HTTPClient
    private let requestBuilder: RequestBuilder
    private let tocParser: TOCParser

    public init(
        httpClient: HTTPClient,
        requestBuilder: RequestBuilder,
        tocParser: TOCParser
    ) {
        self.httpClient = httpClient
        self.requestBuilder = requestBuilder
        self.tocParser = tocParser
    }

    public func fetchTOC(source: BookSource, detailURL: String) async throws -> [TOCItem] {
        let request = try requestBuilder.makeTOCRequest(source: source, detailURL: detailURL)
        let response = try await httpClient.send(request)

        guard response.statusCode >= 200 && response.statusCode < 300 else {
            throw ReaderError.network(
                failureType: .TOC_FAILED,
                stage: "TOC",
                message: "HTTP \(response.statusCode)",
                underlyingError: nil
            )
        }

        return try tocParser.parseTOCResponse(response.data, source: source, detailURL: detailURL)
    }
}
