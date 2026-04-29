import XCTest
@testable import ReaderShellValidation
import ReaderCoreModels

@MainActor
final class ReaderFlowHardeningTests: XCTestCase {

    func testSelectBookResetsTOCAndChapterState() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        let chapter = TOCItem(
            chapterTitle: "第一章",
            chapterURL: "https://example.com/book/1",
            chapterIndex: 1
        )
        await coordinator.selectChapter(chapter)
        XCTAssertNotNil(coordinator.selectedChapter)

        let book = SearchResultItem(
            title: "Test Book",
            detailURL: "https://example.com/book"
        )
        await coordinator.selectBook(book)

        XCTAssertEqual(coordinator.selectedBook, book)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.contentPage)
    }

    func testSelectChapterResetsContentState() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        coordinator.contentPage = ContentPage(
            title: "Old Chapter",
            content: "Old content",
            chapterURL: "https://example.com/old"
        )

        let chapter = TOCItem(
            chapterTitle: "第一章",
            chapterURL: "https://example.com/new",
            chapterIndex: 1
        )
        await coordinator.selectChapter(chapter)

        XCTAssertEqual(coordinator.selectedChapter, chapter)
        XCTAssertNil(coordinator.contentPage)
    }

    func testSearchWithoutSourceReturnsEmptyWithoutError() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        await coordinator.search(keyword: "test")

        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertNil(coordinator.currentError)
        XCTAssertFalse(coordinator.isLoading)
    }

    func testCoordinatorStateReflectsEmptyToLoadedTransition() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        XCTAssertNil(coordinator.selectedSource)
        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.contentPage)
        XCTAssertNil(coordinator.currentError)
        XCTAssertFalse(coordinator.isLoading)

        let book = SearchResultItem(
            title: "Test Book",
            detailURL: "https://example.com/book"
        )
        await coordinator.selectBook(book)

        XCTAssertEqual(coordinator.selectedBook, book)
        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
    }

    func testSearchAfterErrorClearsError() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        coordinator.currentError = ReaderError(code: .unknown, message: "Previous error")

        await coordinator.search(keyword: "test")

        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertNil(coordinator.currentError)
    }
}
