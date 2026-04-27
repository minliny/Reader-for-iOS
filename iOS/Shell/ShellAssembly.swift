import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

@MainActor
public enum ShellAssembly {

    public static func makeMockReadingFlowCoordinator() -> ReadingFlowCoordinator {
        let mockService = MockReaderCoreService.shared
        let serviceProvider = ReaderCoreServiceProvider.shared

        return ReadingFlowCoordinator(
            bookSourceRepository: InMemoryBookSourceRepository(),
            bookSourceDecoder: DefaultBookSourceDecoder(),
            searchService: MockSearchService(provider: serviceProvider),
            tocService: MockTOCService(provider: serviceProvider),
            contentService: MockContentService(provider: serviceProvider),
            errorLogger: InMemoryErrorLogger()
        )
    }

    public static func makeDefaultReadingFlowCoordinator() -> ReadingFlowCoordinator {
        let coordinator = makeMockReadingFlowCoordinator()
        return coordinator
    }
}

public final class MockSearchService: SearchService {
    private let provider: ReaderCoreServiceProvider

    public init(provider: ReaderCoreServiceProvider) {
        self.provider = provider
    }

    public func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem] {
        let state = await provider.searchBooks(keyword: query.keyword, page: query.page)
        switch state {
        case .loaded(let items):
            return items
        case .empty:
            return []
        case .failed(let error):
            throw error
        case .unsupported(let reason):
            throw AppReaderError(code: .unsupported, message: reason, stage: "SEARCH")
        case .partial(let items, let warning):
            return items
        default:
            throw AppReaderError(code: .unknown, message: "Unexpected state", stage: "SEARCH")
        }
    }
}

public final class MockTOCService: TOCService {
    private let provider: ReaderCoreServiceProvider

    public init(provider: ReaderCoreServiceProvider) {
        self.provider = provider
    }

    public func fetchTOC(source: BookSource, detailURL: String) async throws -> [TOCItem] {
        let state = await provider.getChapterList(bookURL: detailURL)
        switch state {
        case .loaded(let items):
            return items
        case .empty:
            return []
        case .failed(let error):
            throw error
        case .unsupported(let reason):
            throw AppReaderError(code: .unsupported, message: reason, stage: "TOC")
        case .partial(let items, _):
            return items
        default:
            throw AppReaderError(code: .unknown, message: "Unexpected state", stage: "TOC")
        }
    }
}

public final class MockContentService: ContentService {
    private let provider: ReaderCoreServiceProvider

    public init(provider: ReaderCoreServiceProvider) {
        self.provider = provider
    }

    public func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage {
        let state = await provider.getChapterContent(chapterURL: chapterURL)
        switch state {
        case .loaded(let page):
            return page
        case .empty:
            throw AppReaderError(code: .notFound, message: "Content not found", stage: "CONTENT")
        case .failed(let error):
            throw error
        case .unsupported(let reason):
            throw AppReaderError(code: .unsupported, message: reason, stage: "CONTENT")
        case .partial(let page, _):
            return page
        default:
            throw AppReaderError(code: .unknown, message: "Unexpected state", stage: "CONTENT")
        }
    }
}
