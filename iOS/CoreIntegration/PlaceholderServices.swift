import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

public enum PlaceholderServiceError: Error {
    case realCoreNotAvailable
    case placeholderImplementation
}

public final class PlaceholderSearchService: SearchService {
    public init() {}

    public func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem] {
        throw PlaceholderServiceError.realCoreNotAvailable
    }
}

public final class PlaceholderTOCService: TOCService {
    public init() {}

    public func fetchTOC(source: BookSource, detailURL: String) async throws -> [TOCItem] {
        throw PlaceholderServiceError.realCoreNotAvailable
    }
}

public final class PlaceholderContentService: ContentService {
    public init() {}

    public func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage {
        throw PlaceholderServiceError.realCoreNotAvailable
    }
}
