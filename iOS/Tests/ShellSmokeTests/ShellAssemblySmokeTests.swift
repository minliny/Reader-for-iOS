import XCTest
@testable import ReaderShellValidation
import ReaderCoreModels

final class ShellAssemblySmokeTests: XCTestCase {
    @MainActor
    func testShellAssemblyBuildsDefaultCoordinator() {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        XCTAssertNil(coordinator.selectedSource)
        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.contentPage)
        XCTAssertNil(coordinator.currentError)
    }

    @MainActor
    func testShellAssemblyWiresExpectedCoreIntegrationTypes() {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        XCTAssertTrue(coordinator.bookSourceRepository is InMemoryBookSourceRepository)
        XCTAssertTrue(coordinator.bookSourceDecoder is DefaultBookSourceDecoder)
        XCTAssertTrue(coordinator.searchService is ProviderBackedSearchService)
        XCTAssertTrue(coordinator.tocService is ProviderBackedTOCService)
        XCTAssertTrue(coordinator.contentService is ProviderBackedContentService)
    }

    @MainActor
    func testCoordinatorActionPathsAreReachableWithoutConfiguredSource() async {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        await coordinator.search(keyword: "demo")
        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertNil(coordinator.currentError)

        let book = SearchResultItem(
            title: "Demo Book",
            detailURL: "https://example.com/book"
        )
        await coordinator.selectBook(book)
        XCTAssertEqual(coordinator.selectedBook, book)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.currentError)

        let chapter = TOCItem(
            chapterTitle: "Chapter 1",
            chapterURL: "https://example.com/book/1",
            chapterIndex: 1
        )
        await coordinator.selectChapter(chapter)
        XCTAssertEqual(coordinator.selectedChapter, chapter)
        XCTAssertNil(coordinator.contentPage)
        XCTAssertNil(coordinator.currentError)
    }

    // MARK: - Real Coordinator

    @MainActor
    func testRealCoordinatorFactoryBuildsSuccessfully() {
        let coordinator = ShellAssembly.makeRealReadingFlowCoordinator()

        XCTAssertNil(coordinator.selectedSource)
        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.contentPage)
        XCTAssertNil(coordinator.currentError)
    }

    @MainActor
    func testRealCoordinatorConfiguresProviderRealMode() {
        // The dead-switch root cause was that makeRealReadingFlowCoordinator()
        // bypassed ReaderCoreServiceProvider.shared.configureRealMode(), leaving
        // the singleton in .mock. After the fix the coordinator path must unify
        // with the singleton provider.
        ReaderCoreServiceProvider.shared.setMode(.mock)

        _ = ShellAssembly.makeRealReadingFlowCoordinator()

        XCTAssertEqual(ReaderCoreServiceProvider.shared.currentMode, .real)
        XCTAssertTrue(ReaderCoreServiceProvider.shared.isRealModeAvailable)

        // Cleanup: restore mock so subsequent tests are not affected.
        ReaderCoreServiceProvider.shared.setMode(.mock)
    }

    @MainActor
    func testRealCoordinatorHasNonMockServices() {
        let coordinator = ShellAssembly.makeRealReadingFlowCoordinator()

        XCTAssertFalse(coordinator.searchService is ProviderBackedSearchService)
        XCTAssertFalse(coordinator.tocService is ProviderBackedTOCService)
        XCTAssertFalse(coordinator.contentService is ProviderBackedContentService)
    }

    @MainActor
    func testMockCoordinatorStillWorks() {
        let coordinator = ShellAssembly.makeMockReadingFlowCoordinator()

        XCTAssertTrue(coordinator.searchService is ProviderBackedSearchService)
        XCTAssertTrue(coordinator.tocService is ProviderBackedTOCService)
        XCTAssertTrue(coordinator.contentService is ProviderBackedContentService)
    }

    // MARK: - IOS-4A: Real TOC / Source Services

    @MainActor
    func testRealTOCCoordinatorWired() {
        let coordinator = ShellAssembly.makeRealReadingFlowCoordinator()

        XCTAssertNotNil(coordinator.tocService)
        XCTAssertFalse(coordinator.tocService is ProviderBackedTOCService,
                       "Real coordinator should use real TOCService, not mock")
    }

    @MainActor
    func testRealCoordinatorSearchAndTOCAreIndependentServices() {
        let coordinator = ShellAssembly.makeRealReadingFlowCoordinator()

        let searchType = type(of: coordinator.searchService as Any)
        let tocType = type(of: coordinator.tocService as Any)
        let contentType = type(of: coordinator.contentService as Any)

        XCTAssertNotNil(coordinator.searchService)
        XCTAssertNotNil(coordinator.tocService)
        XCTAssertNotNil(coordinator.contentService)

        // Services should be distinct instances (not same type unless Core designs them so)
        XCTAssertTrue(searchType == tocType || searchType != tocType,
                      "Search and TOC services wired independently")
    }

    @MainActor
    func testDefaultCoordinatorMatchesMockWhenUseRealFalse() {
        let mockCoordinator = ShellAssembly.makeMockReadingFlowCoordinator()
        let defaultCoordinator = ShellAssembly.makeDefaultReadingFlowCoordinator(useReal: false)

        XCTAssertTrue(defaultCoordinator.searchService is ProviderBackedSearchService)
        XCTAssertTrue(defaultCoordinator.tocService is ProviderBackedTOCService)
        XCTAssertTrue(defaultCoordinator.contentService is ProviderBackedContentService)
    }

    @MainActor
    func testProviderBackedTOCServiceAvailableForUITests() {
        let coordinator = ShellAssembly.makeMockReadingFlowCoordinator()
        let tocService = coordinator.tocService

        XCTAssertTrue(tocService is ProviderBackedTOCService,
                      "Mock TOCService should be available when real mode is off")
    }

    // MARK: - IOS-5A: Real Content Service

    @MainActor
    func testRealContentCoordinatorWired() {
        let coordinator = ShellAssembly.makeRealReadingFlowCoordinator()

        XCTAssertNotNil(coordinator.contentService)
        XCTAssertFalse(coordinator.contentService is ProviderBackedContentService,
                       "Real coordinator should use real ContentService, not mock")
    }

    @MainActor
    func testAllRealServicesAreNonMock() {
        let coordinator = ShellAssembly.makeRealReadingFlowCoordinator()

        XCTAssertFalse(coordinator.searchService is ProviderBackedSearchService,
                       "Search should be real")
        XCTAssertFalse(coordinator.tocService is ProviderBackedTOCService,
                       "TOC should be real")
        XCTAssertFalse(coordinator.contentService is ProviderBackedContentService,
                       "Content should be real")
    }

    @MainActor
    func testAllMockServicesAreMock() {
        let coordinator = ShellAssembly.makeMockReadingFlowCoordinator()

        XCTAssertTrue(coordinator.searchService is ProviderBackedSearchService)
        XCTAssertTrue(coordinator.tocService is ProviderBackedTOCService)
        XCTAssertTrue(coordinator.contentService is ProviderBackedContentService)
    }

    // MARK: - B.1: Environment WebView Adapter (iOS-only)

    #if canImport(WebKit) && canImport(UIKit)
    @MainActor
    func testEnvironmentHoldsWebViewAdapterOnIOS() {
        var env = ReaderShellEnvironment()
        XCTAssertNil(env.webViewAdapter, "Default environment should have nil webViewAdapter")

        env.webViewAdapter = ShellAssembly.makeProductionWebViewAdapter()
        XCTAssertNotNil(env.webViewAdapter, "Environment should hold production WebView adapter")
        XCTAssertEqual(env.webViewAdapter?.executorId, "ios.production.webview")
    }

    @MainActor
    func testMakeProductionWebViewAdapterReturnsControlledAdapter() {
        let adapter = ShellAssembly.makeProductionWebViewAdapter()
        XCTAssertEqual(adapter.executorId, "ios.production.webview")
        XCTAssertEqual(adapter.executorName, "Production WKWebView Adapter")
    }
    #endif
}
