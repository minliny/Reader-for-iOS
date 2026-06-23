import XCTest
@testable import ReaderApp
@testable import ReaderShellValidation
import ReaderCoreModels

/// M2.2: Single source TOC — no real network
@MainActor
final class SingleSourceTOCM2Tests: XCTestCase {

    // MARK: - TOC from provider

    func testTOCReturnsFiveChapters() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)
        let state = await provider.getChapterList(bookURL: "https://example.com/book/1")
        guard case .loaded(let chapters) = state else {
            XCTFail("Expected loaded chapters, got \(state)")
            return
        }
        XCTAssertEqual(chapters.count, 5)
        provider.resetMock()
    }

    func testTOCChapterHasTitle() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)
        let state = await provider.getChapterList(bookURL: "test")
        guard case .loaded(let chapters) = state else { XCTFail(); return }
        XCTAssertEqual(chapters[0].chapterTitle, "第一章 山村少年")
        provider.resetMock()
    }

    // MARK: - TOC snapshot save/load

    func testTOCSnapshotSaveAndLoad() {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("toc_\(UUID().uuidString)")
        let store = SnapshotStore(snapshotRoot: root)
        let items = [
            TOCSnapshotItem(chapterTitle: "第一章", chapterURL: "u1", index: 0),
            TOCSnapshotItem(chapterTitle: "第二章", chapterURL: "u2", index: 1),
        ]
        let result = store.saveTOCSnapshot(sourceId: "c001", sourceName: "星星小说网", host: "h", bookURL: "b", chapters: items)
        guard case .success = result else { XCTFail("save failed"); return }
        let loaded = store.loadTOCSnapshot(candidateId: "c001")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.chapterCount, 2)
        XCTAssertEqual(loaded?.chapters[0].chapterTitle, "第一章")
    }

    // MARK: - ChapterListView init

    func testChapterListViewAcceptsSourceName() {
        let view = ChapterListView(bookURL: "u", bookTitle: "t", sourceName: "⭐ 星星小说网")
        XCTAssertEqual(view.sourceName, "⭐ 星星小说网")
    }

    func testChapterListViewAcceptsSourceContext() {
        let source = BookSource(id: "toc-source", bookSourceName: "目录书源", bookSourceUrl: "https://toc.example")
        let view = ChapterListView(bookURL: "u", bookTitle: "t", sourceName: "目录书源", source: source)
        XCTAssertEqual(view.source?.id, "toc-source")
        XCTAssertEqual(view.source?.bookSourceName, "目录书源")
    }

    // MARK: - Provider defaults

    func testProviderDefaultsToMock() {
        XCTAssertEqual(ReaderCoreServiceProvider.shared.currentMode, .mock)
    }

    // MARK: - No Content reached

    func testTOCChapterNavigationCarriesReaderContextIndex() {
        let nav = ChapterNavigation(chapterURL: "offline://chapter/2", chapterTitle: "第二章", chapterIndex: 1)
        XCTAssertEqual(nav.chapterTitle, "第二章")
        XCTAssertEqual(nav.chapterIndex, 1)
    }

    func testChapterListViewModelExposesChaptersForReaderNavigation() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)
        let source = BookSource(id: "toc-source", bookSourceName: "目录书源", bookSourceUrl: "https://toc.example")
        let viewModel = ChapterListViewModel(bookURL: "https://toc.example/book/1", bookTitle: "凡人修仙传", source: source)

        await viewModel.loadChapters()

        XCTAssertEqual(viewModel.bookURL, "https://toc.example/book/1")
        XCTAssertEqual(viewModel.chaptersForReader.count, 5)
        XCTAssertEqual(viewModel.chaptersForReader.first?.chapterTitle, "第一章 山村少年")
        provider.resetMock()
    }

    // MARK: - M1 search still works

    func testM1SearchStillWorks() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)
        let state = await provider.searchBooks(keyword: "x", page: 1)
        guard case .loaded = state else { XCTFail(); return }
        provider.resetMock()
    }
}
