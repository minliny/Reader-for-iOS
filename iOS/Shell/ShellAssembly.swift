import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreServices
#if canImport(ReaderCoreNativeAdapter)
import ReaderCoreNativeAdapter
#endif

@MainActor
public enum ShellAssembly {

    // MARK: - Mock

    public static func makeMockReadingFlowCoordinator() -> ReadingFlowCoordinator {
        let serviceProvider = ReaderCoreServiceProvider.shared

        let coordinator = ReadingFlowCoordinator(
            bookSourceRepository: InMemoryBookSourceRepository(),
            bookSourceDecoder: DefaultBookSourceDecoder(),
            searchService: ProviderBackedSearchService(provider: serviceProvider),
            tocService: ProviderBackedTOCService(provider: serviceProvider),
            contentService: ProviderBackedContentService(provider: serviceProvider),
            errorLogger: InMemoryErrorLogger()
        )

        if let searchService = coordinator.searchService as? ProviderBackedSearchService {
            searchService.onWarning = { [weak coordinator] warning in
                coordinator?.lastWarning = warning
            }
        }
        if let tocService = coordinator.tocService as? ProviderBackedTOCService {
            tocService.onWarning = { [weak coordinator] warning in
                coordinator?.lastWarning = warning
            }
        }
        if let contentService = coordinator.contentService as? ProviderBackedContentService {
            contentService.onWarning = { [weak coordinator] warning in
                coordinator?.lastWarning = warning
            }
        }

        return coordinator
    }

    // MARK: - Real

    @available(*, deprecated, message: "S6.2: use makeRustCoreReadingFlowCoordinator — old Swift Core ReaderCoreServiceFactory path will be removed in S7")
    public static func makeRealReadingFlowCoordinator() -> ReadingFlowCoordinator {
        // Unify with the singleton provider: configureRealMode() flips the
        // provider to .real AND runs the RealNetworkGate. If the gate denies,
        // fall back to mock so the app never silently runs real services.
        // This closes the "dead switch" where the toggle built real services
        // directly while the provider singleton stayed in .mock.
        guard ReaderCoreServiceProvider.shared.configureRealMode() else {
            return makeMockReadingFlowCoordinator()
        }

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

    #if canImport(ReaderCoreNativeAdapter)
    /// S6.1: Build a ReadingFlowCoordinator backed by Rust Core via C ABI.
    /// Returns nil if the Rust Core runtime cannot be booted.
    public static func makeRustCoreReadingFlowCoordinator() -> ReadingFlowCoordinator? {
        if !RustCoreRuntimeHolder.shared.isBooted {
            do {
                try RustCoreRuntimeHolder.shared.boot()
            } catch {
                print("[RustCore] boot failed in ShellAssembly: \(error)")
                return nil
            }
        }
        guard let runtime = RustCoreRuntimeHolder.shared.current else {
            return nil
        }
        return ReadingFlowCoordinator(
            bookSourceRepository: InMemoryBookSourceRepository(),
            bookSourceDecoder: DefaultBookSourceDecoder(),
            searchService: RustCoreSearchService(runtime: runtime),
            tocService: RustCoreTOCService(runtime: runtime),
            contentService: RustCoreContentService(runtime: runtime),
            errorLogger: InMemoryErrorLogger()
        )
    }
    #endif

    /// S6.2: Rust Core is the explicit default business path.
    /// The legacy `useReal` flag is retained only for test injection (tests
    /// that need the old Swift Core factory path call `makeRealReadingFlowCoordinator()`
    /// directly). Production callers should not pass `useReal`.
    public static func makeDefaultReadingFlowCoordinator(useReal: Bool = false) -> ReadingFlowCoordinator {
        if useReal {
            // Legacy escape hatch — only tests preserving the old Swift Core
            // factory path should use this. Production never sets useReal=true.
            return makeRealReadingFlowCoordinator()
        }
        // S6.2: Rust Core is the default. If boot fails, fall back to mock so
        // the app never silently runs without a business path. This fallback
        // is logged and surfaces a visible failure mode (provider getBookDetail
        // etc. will fail-loud when mode != .rustCore).
        #if canImport(ReaderCoreNativeAdapter)
        if let coordinator = makeRustCoreReadingFlowCoordinator() {
            return coordinator
        }
        print("[ShellAssembly] Rust Core boot failed — falling back to mock coordinator")
        #endif
        return makeMockReadingFlowCoordinator()
    }

    // MARK: - Production WebView Adapter

    /// Builds a `ProductionWebViewAdapter` wired with the default security gate,
    /// `DefaultRealNetworkGate`, `RealNetworkPolicyStore.shared`, and the cookie
    /// mirror metadata store. The controlled path produces redacted evidence for
    /// the WebView autorun harness. iOS-only (WebKit + UIKit).
    #if canImport(WebKit) && canImport(UIKit)
    @MainActor
    public static func makeProductionWebViewAdapter() -> ProductionWebViewAdapter {
        ProductionWebViewAdapter()
    }
    #endif
}

public final class ProviderBackedSearchService: SearchService {
    private let provider: ReaderCoreServiceProvider
    public var onWarning: ((String) -> Void)?

    public init(provider: ReaderCoreServiceProvider, onWarning: ((String) -> Void)? = nil) {
        self.provider = provider
        self.onWarning = onWarning
    }

    public func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem] {
        let state = await provider.searchBooks(keyword: query.keyword, page: query.page, source: source)
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

public final class ProviderBackedTOCService: TOCService {
    private let provider: ReaderCoreServiceProvider
    public var onWarning: ((String) -> Void)?

    public init(provider: ReaderCoreServiceProvider, onWarning: ((String) -> Void)? = nil) {
        self.provider = provider
        self.onWarning = onWarning
    }

    public func fetchTOC(source: BookSource, detailURL: String) async throws -> [TOCItem] {
        let state = await provider.getChapterList(bookURL: detailURL, source: source)
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

public final class ProviderBackedContentService: ContentService {
    private let provider: ReaderCoreServiceProvider
    public var onWarning: ((String) -> Void)?

    public init(provider: ReaderCoreServiceProvider, onWarning: ((String) -> Void)? = nil) {
        self.provider = provider
        self.onWarning = onWarning
    }

    public func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage {
        let state = await provider.getChapterContent(chapterURL: chapterURL, source: source)
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
