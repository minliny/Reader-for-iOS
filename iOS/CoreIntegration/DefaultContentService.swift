import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreFacade

public final class DefaultContentService: ContentService {
    private let facade: any ContentService

    public init(
        facade: any ContentService
    ) {
        self.facade = facade
    }

    public func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage {
        try await facade.fetchContent(source: source, chapterURL: chapterURL)
    }
}
