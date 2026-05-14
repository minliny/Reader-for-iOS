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
        XCTAssertTrue(coordinator.searchService is MockSearchService)
        XCTAssertTrue(coordinator.tocService is MockTOCService)
        XCTAssertTrue(coordinator.contentService is MockContentService)
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
    func testRealCoordinatorHasNonMockServices() {
        let coordinator = ShellAssembly.makeRealReadingFlowCoordinator()

        XCTAssertFalse(coordinator.searchService is MockSearchService)
        XCTAssertFalse(coordinator.tocService is MockTOCService)
        XCTAssertFalse(coordinator.contentService is MockContentService)
    }

    @MainActor
    func testMockCoordinatorStillWorks() {
        let coordinator = ShellAssembly.makeMockReadingFlowCoordinator()

        XCTAssertTrue(coordinator.searchService is MockSearchService)
        XCTAssertTrue(coordinator.tocService is MockTOCService)
        XCTAssertTrue(coordinator.contentService is MockContentService)
    }
}
