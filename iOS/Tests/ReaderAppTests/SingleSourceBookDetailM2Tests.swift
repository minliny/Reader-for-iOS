import XCTest
@testable import ReaderApp
@testable import ReaderShellValidation
import ReaderCoreModels

/// M2.1: Book Detail from search result — no real network
@MainActor
final class SingleSourceBookDetailM2Tests: XCTestCase {

    let sampleResult = SearchResultItem(
        title: "凡人修仙传", detailURL: "https://example.com/book/1",
        author: "忘语", intro: "一个普通的山村少年..."
    )

    // MARK: - Detail from search result

    func testBookDetailViewReceivesSourceName() {
        let view = BookDetailView(result: sampleResult, sourceName: "⭐ 星星小说网")
        XCTAssertEqual(view.sourceName, "⭐ 星星小说网")
    }

    func testBookDetailViewReceivesSourceContext() {
        let source = BookSource(id: "source-x", bookSourceName: "真实书源", bookSourceUrl: "https://source.example")
        let view = BookDetailView(result: sampleResult, sourceName: "真实书源", source: source)
        XCTAssertEqual(view.source?.id, "source-x")
        XCTAssertEqual(view.source?.bookSourceUrl, "https://source.example")
    }

    func testBookDetailViewDefaultSourceNameIsEmpty() {
        let view = BookDetailView(result: sampleResult)
        XCTAssertEqual(view.sourceName, "")
    }

    // MARK: - Detail fields from SearchResultItem

    func testDetailHasTitle() {
        XCTAssertEqual(sampleResult.title, "凡人修仙传")
    }

    func testDetailHasAuthor() {
        XCTAssertEqual(sampleResult.author, "忘语")
    }

    func testDetailHasIntro() {
        XCTAssertNotNil(sampleResult.intro)
    }

    func testLatestChapterLabel() {
        let label = sampleResult.latestChapterLabel
        XCTAssertTrue(label.contains("待接入") || label.contains("最新章节"))
    }

    // MARK: - No real network

    func testProviderDefaultsToMock() {
        XCTAssertEqual(ReaderCoreServiceProvider.shared.currentMode, .mock)
    }

    // MARK: - M1 search still works

    func testSearchStillReturnsResults() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)
        let state = await provider.searchBooks(keyword: "凡人", page: 1)
        guard case .loaded(let results) = state else { XCTFail(); return }
        XCTAssertEqual(results.count, 3)
        provider.resetMock()
    }
}
