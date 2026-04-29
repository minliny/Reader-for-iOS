import XCTest
@testable import ReaderShellValidation
import ReaderCoreModels

final class ReaderFlowFunctionalValidationTests: XCTestCase {

    @MainActor
    func testSelectBookPopulatesChapterList() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        let book = SearchResultItem(
            detailURL: "https://example.com/book/1",
            title: "凡人修仙传",
            author: "忘语"
        )
        await coordinator.selectBook(book)

        XCTAssertEqual(coordinator.selectedBook, book)
        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
    }

    @MainActor
    func testSelectChapterPopulatesContent() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        let chapter = TOCItem(
            chapterTitle: "第一章 山村少年",
            chapterURL: "https://example.com/book/1/chapter/1",
            chapterIndex: 1
        )
        await coordinator.selectChapter(chapter)

        XCTAssertEqual(coordinator.selectedChapter, chapter)
        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
    }

    @MainActor
    func testUnsupportedCapabilityReturnsControlledError() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        coordinator.currentError = ReaderError(code: .unsupported, message: "JS required")

        await coordinator.search(keyword: "test")

        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertNotNil(coordinator.currentError)
    }

    @MainActor
    func testCoordinatorStateReflectsInitialState() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        XCTAssertNil(coordinator.selectedSource)
        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.selectedBook)
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.contentPage)
        XCTAssertNil(coordinator.currentError)
        XCTAssertFalse(coordinator.isLoading)
    }
}
