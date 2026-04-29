import XCTest
@testable import ReaderShellValidation
import ReaderCoreModels

@MainActor
final class ReaderFlowHardeningTests: XCTestCase {

    func testRepeatedSearchClearsStaleState() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        await coordinator.importBookSource(from: minimalBookSourceJSON)
        XCTAssertNotNil(coordinator.selectedSource)

        await coordinator.search(keyword: "三体")

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)

        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)
        let firstChapter = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(firstChapter)

        XCTAssertNotNil(coordinator.selectedBook)
        XCTAssertNotNil(coordinator.selectedChapter)
        XCTAssertNotNil(coordinator.contentPage)

        await coordinator.importBookSource(from: anotherBookSourceJSON)

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
        XCTAssertNotNil(coordinator.selectedSource)
        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertNil(coordinator.selectedBook)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.contentPage)
    }

    func testSwitchingBooksReplacesTOCAndClearsSelectedChapterAndContent() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        await coordinator.importBookSource(from: minimalBookSourceJSON)

        await coordinator.search(keyword: "三体")

        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        let secondBook = try XCTUnwrap(coordinator.searchResults.dropFirst().first)

        await coordinator.selectBook(firstBook)
        let firstChapter = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(firstChapter)

        await coordinator.selectBook(secondBook)

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
        XCTAssertEqual(coordinator.selectedBook, secondBook)
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.contentPage)
    }

    func testSwitchingChaptersReplacesContentAndClearsError() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        await coordinator.importBookSource(from: minimalBookSourceJSON)

        await coordinator.search(keyword: "三体")
        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)

        let chapters = coordinator.tocItems
        guard chapters.count >= 2 else { return }

        let chapterA = chapters[0]
        let chapterB = chapters[1]

        await coordinator.selectChapter(chapterA)
        let firstContent = coordinator.contentPage

        coordinator.currentError = ReaderError(code: .unknown, message: "stale")
        await coordinator.selectChapter(chapterB)

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
        XCTAssertEqual(coordinator.selectedChapter, chapterB)
        XCTAssertNotEqual(firstContent?.chapterURL, coordinator.contentPage?.chapterURL)
    }

    func testImportingNewSourceReplacesSelectedSourceAndClearsReaderState() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        await coordinator.importBookSource(from: minimalBookSourceJSON)
        await coordinator.search(keyword: "三体")
        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)
        let firstChapter = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(firstChapter)

        await coordinator.importBookSource(from: anotherBookSourceJSON)

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
        XCTAssertNotNil(coordinator.selectedSource)
        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertNil(coordinator.selectedBook)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.contentPage)
    }

    func testCoordinatorStateReflectsEmptyLoadedAndErrorTransitions() async throws {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        XCTAssertNil(coordinator.selectedSource)
        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.contentPage)
        XCTAssertNil(coordinator.currentError)

        await coordinator.importBookSource(from: minimalBookSourceJSON)
        XCTAssertNotNil(coordinator.selectedSource)
        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.currentError)

        await coordinator.search(keyword: "三体")
        XCTAssertFalse(coordinator.searchResults.isEmpty)
        XCTAssertNil(coordinator.selectedBook)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.currentError)

        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)
        XCTAssertEqual(coordinator.selectedBook, firstBook)
        XCTAssertFalse(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.currentError)

        let firstChapter = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(firstChapter)
        XCTAssertEqual(coordinator.selectedChapter, firstChapter)
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

private let anotherBookSourceJSON = """
{
    "bookSourceName": "Another Source",
    "bookSourceUrl": "https://another.example.com",
    "bookSourceGroup": "Test",
    "bookSourceType": "RSS",
    "enabled": true,
    "loginUrl": "",
    "loginCheckJs": "",
    "header": "",
    "variableJs": "",
    "searchUrl": "https://another.example.com/search?wd={{key}}",
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
