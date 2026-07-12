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
        // S6.2: default coordinator now routes through Rust Core
        // (RustCore*Service when ReaderCoreNativeAdapter is available;
        // falls back to ProviderBacked*Service only if boot fails).
        // Smoke verifies non-nil rather than specific service type.
        XCTAssertNotNil(coordinator.searchService)
        XCTAssertNotNil(coordinator.tocService)
        XCTAssertNotNil(coordinator.contentService)
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

    // MARK: - Mock Coordinator

    @MainActor
    func testMockCoordinatorStillWorks() {
        let coordinator = ShellAssembly.makeMockReadingFlowCoordinator()

        XCTAssertTrue(coordinator.searchService is ProviderBackedSearchService)
        XCTAssertTrue(coordinator.tocService is ProviderBackedTOCService)
        XCTAssertTrue(coordinator.contentService is ProviderBackedContentService)
    }

    // MARK: - Default Coordinator

    @MainActor
    func testDefaultCoordinatorBuildsValidServicesWhenUseRealFalse() {
        // S6.2: makeDefaultReadingFlowCoordinator(useReal: false) now routes
        // through Rust Core (RustCore*Service), falling back to ProviderBacked*
        // only if boot fails. Mock coordinator still wires ProviderBacked*.
        let mockCoordinator = ShellAssembly.makeMockReadingFlowCoordinator()
        let defaultCoordinator = ShellAssembly.makeDefaultReadingFlowCoordinator(useReal: false)

        XCTAssertNotNil(defaultCoordinator.searchService)
        XCTAssertNotNil(defaultCoordinator.tocService)
        XCTAssertNotNil(defaultCoordinator.contentService)
        XCTAssertNotNil(mockCoordinator.searchService)
    }

    @MainActor
    func testProviderBackedTOCServiceAvailableForUITests() {
        let coordinator = ShellAssembly.makeMockReadingFlowCoordinator()
        let tocService = coordinator.tocService

        XCTAssertTrue(tocService is ProviderBackedTOCService,
                      "Mock TOCService should be available when real mode is off")
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
