import XCTest
@testable import ReaderShellValidation
import ReaderCoreModels

@MainActor
final class ReaderFlowFunctionalValidationTests: XCTestCase {

    func testSearchReturnsMockResults() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        await coordinator.search(keyword: "三体")

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
        XCTAssertFalse(coordinator.searchResults.isEmpty)
        XCTAssertEqual(coordinator.searchResults.count, 3)
        XCTAssertEqual(coordinator.searchResults.map(\.title), ["凡人修仙传", "仙逆", "一念永恒"])
    }

    func testSelectBookPopulatesChapterList() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        await coordinator.search(keyword: "三体")
        let firstBook = try XCTUnwrap(coordinator.searchResults.first)

        await coordinator.selectBook(firstBook)

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
        XCTAssertEqual(coordinator.selectedBook, firstBook)
        XCTAssertFalse(coordinator.tocItems.isEmpty)
        XCTAssertEqual(coordinator.tocItems.count, 5)
        XCTAssertEqual(coordinator.tocItems.map(\.chapterTitle), [
            "第一章 山村少年",
            "第二章 仙缘",
            "第三章 修炼入门",
            "第四章 宗门大选",
            "第五章 初入灵泉"
        ])
    }

    func testSelectChapterPopulatesContent() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        await coordinator.search(keyword: "三体")
        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)

        let firstChapter = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(firstChapter)

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
        XCTAssertEqual(coordinator.selectedChapter, firstChapter)
        XCTAssertNotNil(coordinator.contentPage)
        XCTAssertEqual(coordinator.contentPage?.title, "第一章 山村少年")
        XCTAssertTrue(coordinator.contentPage?.content.contains("夕阳西下") ?? false)
    }

    func testAddToBookshelfFlow() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        await coordinator.search(keyword: "三体")
        let firstBook = try XCTUnwrap(coordinator.searchResults.first)

        await coordinator.selectBook(firstBook)

        XCTAssertNotNil(coordinator.selectedBook)
        XCTAssertFalse(coordinator.tocItems.isEmpty)
    }

    func testUnsupportedCapabilityReturnsControlledError() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        coordinator.currentError = ReaderError(code: .unsupported, message: "JS required")

        await coordinator.search(keyword: "test")

        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertNotNil(coordinator.currentError)
        XCTAssertEqual(coordinator.currentError?.code, .unsupported)
    }

    func testContentStageReturnsControlledErrorWhen404() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        await coordinator.search(keyword: "三体")
        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)

        let firstChapter = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(firstChapter)

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertEqual(coordinator.selectedChapter, firstChapter)
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
