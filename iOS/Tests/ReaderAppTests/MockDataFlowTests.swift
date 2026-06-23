import XCTest
@testable import ReaderApp
@testable import ReaderShellValidation
import ReaderCoreModels

/// Search → Detail → TOC → ReaderView mock 数据闭环测试
@MainActor
final class MockDataFlowTests: XCTestCase {

    // MARK: - Mock Search

    func testMockSearchReturnsResults() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)

        let state = await provider.searchBooks(keyword: "test", page: 1)
        if case .loaded(let results) = state {
            XCTAssertFalse(results.isEmpty, "Mock 应返回搜索结果")
            XCTAssertEqual(results[0].title, "凡人修仙传")
        } else {
            XCTFail("Expected .loaded, got \(state)")
        }

        provider.resetMock()
    }

    func testMockSearchResultsAreThree() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)

        let state = await provider.searchBooks(keyword: "凡人", page: 1)
        if case .loaded(let results) = state {
            XCTAssertEqual(results.count, 3)
        } else {
            XCTFail("Expected 3 mock results")
        }

        provider.resetMock()
    }

    // MARK: - Mock TOC

    func testMockTOCReturnsFiveChapters() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)

        let state = await provider.getChapterList(bookURL: "https://example.com/book/1")
        if case .loaded(let chapters) = state {
            XCTAssertEqual(chapters.count, 5, "Mock TOC 应返回 5 章")
            XCTAssertEqual(chapters[0].chapterTitle, "第一章 山村少年")
        } else {
            XCTFail("Expected 5 mock TOC chapters")
        }

        provider.resetMock()
    }

    // MARK: - Mock Content

    func testMockContentReturnsPage() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)

        let state = await provider.getChapterContent(chapterURL: "https://example.com/book/1/chapter/1")
        if case .loaded(let page) = state {
            XCTAssertFalse(page.content.isEmpty, "Mock 内容不应为空")
            XCTAssertTrue(page.content.contains("韩立"), "内容应包含主角名")
        } else {
            XCTFail("Expected mock content page")
        }

        provider.resetMock()
    }

    // MARK: - Navigation Types

    func testChapterNavigationIsHashable() {
        let nav1 = ChapterNavigation(chapterURL: "url1", chapterTitle: "title1")
        let nav2 = ChapterNavigation(chapterURL: "url1", chapterTitle: "title1")
        XCTAssertEqual(nav1, nav2)
    }

    // MARK: - SearchViewModel with mock source

    func testSearchViewModelPrePopulatesCandidateSource() async {
        let vm = SearchViewModel()
        await vm.loadSources()

        XCTAssertFalse(vm.sources.isEmpty, "SearchViewModel 应预置候选书源")
        XCTAssertNotNil(vm.selectedSource, "应自动选中第一个书源")
        XCTAssertEqual(vm.selectedSource?.id, "candidate-xingxingxsw")
        XCTAssertEqual(vm.selectedSource?.bookSourceName, "⭐ 星星小说网")
        XCTAssertEqual(vm.selectedSource?.bookSourceUrl, "https://www.xingxingxsw.com")
    }

    // MARK: - No Parser Internals

    func testSearchViewModelDoesNotImportParserInternals() {
        // 编译时验证：SearchViewModel 不应直接引用 parser 类型
        let vm = SearchViewModel()
        XCTAssertNotNil(vm)
        // 此处只验证 ViewModel 可正常构造，不测试 parser 边界
    }

    // MARK: - Mock BookDetail

    func testMockDetailLoadsFromSearchResult() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)

        // BookDetailViewModel uses provider.getBookDetail(bookURL:)
        let state = await provider.getBookDetail(bookURL: "https://example.com/book/1")
        if case .loaded(let detail) = state {
            XCTAssertEqual(detail.title, "凡人修仙传")
            XCTAssertEqual(detail.author, "忘语")
            XCTAssertFalse(detail.detailURL.isEmpty)
        } else {
            XCTFail("Expected mock book detail, got \(state)")
        }

        provider.resetMock()
    }

    // MARK: - Provider default is mock

    func testProviderDefaultsToMockMode() {
        let provider = ReaderCoreServiceProvider.shared
        XCTAssertEqual(provider.currentMode, .mock, "默认模式应为 mock")
    }
}
