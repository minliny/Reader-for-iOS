import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreFacade

public final class DefaultTOCService: TOCService {
    private let facade: any TOCService

    public init(
        facade: any TOCService
    ) {
        self.facade = facade
    }

    public func fetchTOC(source: BookSource, detailURL: String) async throws -> [TOCItem] {
        try await facade.fetchTOC(source: source, detailURL: detailURL)
    }
}
