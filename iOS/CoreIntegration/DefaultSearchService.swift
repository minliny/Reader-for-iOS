import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreFacade

public final class DefaultSearchService: SearchService {
    private let facade: any SearchService

    public init(
        facade: any SearchService
    ) {
        self.facade = facade
    }

    public func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem] {
        try await facade.search(source: source, query: query)
    }
}
