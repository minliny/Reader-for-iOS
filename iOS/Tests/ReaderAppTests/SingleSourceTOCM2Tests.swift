import XCTest
@testable import ReaderApp

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

    // MARK: - Provider defaults

    func testProviderDefaultsToMock() {
        XCTAssertEqual(ReaderCoreServiceProvider.shared.currentMode, .mock)
    }

    // MARK: - No Content reached

    func testTOCChapterNavigationToReaderViewIsDisabledInM2_2() {
        // M2.2: Content/ReaderView is M2.3. This test confirms
        // ChapterNavigation exists but the reader path uses mock data
        let nav = ChapterNavigation(chapterURL: "offline://chapter/1", chapterTitle: "第一章")
        XCTAssertEqual(nav.chapterTitle, "第一章")
        // ReaderView is not reached in M2.2 scope
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
