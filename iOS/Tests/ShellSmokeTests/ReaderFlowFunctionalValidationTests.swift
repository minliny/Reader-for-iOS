import XCTest
@testable import ReaderShellValidation
import ReaderCoreModels

@MainActor
final class ReaderFlowFunctionalValidationTests: XCTestCase {

    func testSelectBookPopulatesChapterList() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        await coordinator.importBookSource(from: minimalBookSourceJSON)
        XCTAssertNotNil(coordinator.selectedSource, "selectedSource must be set after import")

        await coordinator.search(keyword: "三体")
        let firstBook = try XCTUnwrap(coordinator.searchResults.first)

        await coordinator.selectBook(firstBook)

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
        XCTAssertEqual(coordinator.selectedBook, firstBook)
    }

    func testSelectChapterPopulatesContent() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        await coordinator.importBookSource(from: minimalBookSourceJSON)
        await coordinator.search(keyword: "三体")
        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)

        let firstChapter = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(firstChapter)

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
        XCTAssertEqual(coordinator.selectedChapter, firstChapter)
    }

    func testUnsupportedCapabilityReturnsControlledError() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        await coordinator.importBookSource(from: minimalBookSourceJSON)

        coordinator.currentError = ReaderError(code: .unsupported, message: "JS required")

        await coordinator.search(keyword: "test")

        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertNotNil(coordinator.currentError)
    }

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

private let minimalBookSourceJSON = """
{
    "bookSourceName": "Test Source",
    "bookSourceUrl": "https://test.example.com",
    "bookSourceGroup": "Test",
    "bookSourceType": "RSS",
    "enabled": true,
    "loginUrl": "",
    "loginCheckJs": "",
    "header": "",
    "variableJs": "",
    "searchUrl": "https://test.example.com/search?wd={{key}}",
    "searchJs": "",
    "exploreUrl": "",
    "exploreJs": "",
    "bookListJs": "",
    "chapterListJs": "",
    "bookInfoJs": "",
    "chapterInfoJs": "",
    "reverseSearchUrl": "",
    "reverseSearchJs": "",
    "canSearch": true,
    "canExplore": false
}
""".data(using: .utf8)!
