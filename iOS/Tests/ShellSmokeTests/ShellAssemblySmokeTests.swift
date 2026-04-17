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
        XCTAssertNotNil(coordinator.readingFlowFacade)
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
}
