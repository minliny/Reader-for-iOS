import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreServices

@MainActor
public enum ShellAssembly {

    // MARK: - Mock

    public static func makeMockReadingFlowCoordinator() -> ReadingFlowCoordinator {
        let serviceProvider = ReaderCoreServiceProvider.shared

        let coordinator = ReadingFlowCoordinator(
            bookSourceRepository: InMemoryBookSourceRepository(),
            bookSourceDecoder: DefaultBookSourceDecoder(),
            searchService: MockSearchService(provider: serviceProvider),
            tocService: MockTOCService(provider: serviceProvider),
            contentService: MockContentService(provider: serviceProvider),
            errorLogger: InMemoryErrorLogger()
        )

        if let searchService = coordinator.searchService as? MockSearchService {
            searchService.onWarning = { [weak coordinator] warning in
                coordinator?.lastWarning = warning
            }
        }
        if let tocService = coordinator.tocService as? MockTOCService {
            tocService.onWarning = { [weak coordinator] warning in
                coordinator?.lastWarning = warning
            }
        }
        if let contentService = coordinator.contentService as? MockContentService {
            contentService.onWarning = { [weak coordinator] warning in
                coordinator?.lastWarning = warning
            }
        }

        return coordinator
    }

    // MARK: - Real

    public static func makeRealReadingFlowCoordinator() -> ReadingFlowCoordinator {
        let httpClient = URLSessionHTTPClient()
        let factory = ReaderCoreServiceFactory(httpClient: httpClient)
        let realSearchService = factory.makeSearchService()
        let realTOCService = factory.makeTOCService()
        let realContentService = factory.makeContentService()

        return ReadingFlowCoordinator(
            bookSourceRepository: InMemoryBookSourceRepository(),
            bookSourceDecoder: DefaultBookSourceDecoder(),
            searchService: realSearchService,
            tocService: realTOCService,
            contentService: realContentService,
            errorLogger: InMemoryErrorLogger()
        )
    }

    // MARK: - Default

    public static func makeDefaultReadingFlowCoordinator(useReal: Bool = false) -> ReadingFlowCoordinator {
        if useReal {
            return makeRealReadingFlowCoordinator()
        }
        return makeMockReadingFlowCoordinator()
    }
}

public final class MockSearchService: SearchService {
    private let provider: ReaderCoreServiceProvider
    public var onWarning: ((String) -> Void)?

    public init(provider: ReaderCoreServiceProvider, onWarning: ((String) -> Void)? = nil) {
        self.provider = provider
        self.onWarning = onWarning
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
            onWarning?(warning)
            return items
        default:
            throw AppReaderError(code: .unknown, message: "Unexpected state", stage: "SEARCH")
        }
    }
}

public final class MockTOCService: TOCService {
    private let provider: ReaderCoreServiceProvider
    public var onWarning: ((String) -> Void)?

    public init(provider: ReaderCoreServiceProvider, onWarning: ((String) -> Void)? = nil) {
        self.provider = provider
        self.onWarning = onWarning
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
        case .partial(let items, let warning):
            onWarning?(warning)
            return items
        default:
            throw AppReaderError(code: .unknown, message: "Unexpected state", stage: "TOC")
        }
    }
}

public final class MockContentService: ContentService {
    private let provider: ReaderCoreServiceProvider
    public var onWarning: ((String) -> Void)?

    public init(provider: ReaderCoreServiceProvider, onWarning: ((String) -> Void)? = nil) {
        self.provider = provider
        self.onWarning = onWarning
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
        case .partial(let page, let warning):
            onWarning?(warning)
            return page
        default:
            throw AppReaderError(code: .unknown, message: "Unexpected state", stage: "CONTENT")
        }
    }
}
