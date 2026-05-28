import XCTest
import ReaderAppSupport
import ReaderAppPersistence
import ReaderCoreModels

/// M3: Reading cache (content snapshot) and progress smoke tests
/// These tests cover M3 core capabilities without depending on ReaderAppTests target
/// (ReaderAppSupport has an Xcode 26.5 module resolution issue when built standalone)
@MainActor
final class ReadingCacheAndProgressM3SmokeTests: XCTestCase {

    var snapshotRoot: URL!
    var store: SnapshotStore!
    var progressStore: ReadingProgressStore!
    var bookshelfStore: BookshelfStore!

    override func setUp() {
        super.setUp()
        snapshotRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("m3_\(UUID().uuidString)")
        store = SnapshotStore(snapshotRoot: snapshotRoot)
        progressStore = ReadingProgressStore(storageURL: snapshotRoot.appendingPathComponent("progress.json"))
        bookshelfStore = BookshelfStore(storageURL: snapshotRoot.appendingPathComponent("bookshelf.json"))
    }

    // MARK: - M3-A: Content Cache

    func testContentCacheSaveAndLoad() {
        let result = store.saveChapterContentSnapshot(
            sourceId: "c001",
            sourceName: "星星小说网",
            host: "www.qianfanxs.com",
            chapterURL: "offline://chapter/1",
            chapterTitle: "第一章 山村少年",
            content: "韩立走在山间小路上...",
            nextChapterURL: "offline://chapter/2"
        )
        guard case .success = result else { XCTFail("save failed"); return }

        let snap = store.loadChapterContentSnapshot(sourceId: "c001", chapterURL: "offline://chapter/1")
        XCTAssertNotNil(snap)
        XCTAssertEqual(snap?.chapterTitle, "第一章 山村少年")
        XCTAssertTrue(snap?.content.contains("韩立") == true)
        XCTAssertEqual(snap?.nextChapterURL, "offline://chapter/2")
    }

    func testContentCacheLoadMissing() {
        let snap = store.loadChapterContentSnapshot(sourceId: "c001", chapterURL: "offline://nonexistent")
        XCTAssertNil(snap)
    }

    func testContentCachePerChapterIsolation() {
        _ = store.saveChapterContentSnapshot(
            sourceId: "c001", sourceName: "", host: "",
            chapterURL: "offline://chapter/1",
            chapterTitle: "第一章",
            content: "第一章内容",
            nextChapterURL: "offline://chapter/2"
        )
        _ = store.saveChapterContentSnapshot(
            sourceId: "c001", sourceName: "", host: "",
            chapterURL: "offline://chapter/2",
            chapterTitle: "第二章",
            content: "第二章内容",
            nextChapterURL: nil
        )

        let snap1 = store.loadChapterContentSnapshot(sourceId: "c001", chapterURL: "offline://chapter/1")
        let snap2 = store.loadChapterContentSnapshot(sourceId: "c001", chapterURL: "offline://chapter/2")
        XCTAssertEqual(snap1?.content, "第一章内容")
        XCTAssertEqual(snap2?.content, "第二章内容")
    }

    func testContentCacheSourceIsolation() {
        _ = store.saveChapterContentSnapshot(
            sourceId: "sourceA", sourceName: "", host: "",
            chapterURL: "ch1", chapterTitle: "A 第一章",
            content: "A内容", nextChapterURL: nil
        )
        _ = store.saveChapterContentSnapshot(
            sourceId: "sourceB", sourceName: "", host: "",
            chapterURL: "ch1", chapterTitle: "B 第一章",
            content: "B内容", nextChapterURL: nil
        )
        let snapA = store.loadChapterContentSnapshot(sourceId: "sourceA", chapterURL: "ch1")
        let snapB = store.loadChapterContentSnapshot(sourceId: "sourceB", chapterURL: "ch1")
        XCTAssertEqual(snapA?.content, "A内容")
        XCTAssertEqual(snapB?.content, "B内容")
    }

    // MARK: - M3-B: Reading Progress

    func testReadingProgressSaveAndLoad() {
        let progress = ReadingProgress(
            bookID: "book-001",
            sourceID: "c001",
            bookURL: "offline://book/fanren",
            chapterURL: "offline://chapter/1",
            chapterTitle: "第一章 山村少年",
            progressRatio: 0.35
        )
        try? progressStore.saveProgress(progress)

        let loaded = try? progressStore.loadProgress(bookID: "book-001")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.chapterTitle, "第一章 山村少年")
        XCTAssertEqual(loaded?.progressRatio, 0.35, accuracy: 0.001)
        XCTAssertEqual(loaded?.chapterURL, "offline://chapter/1")
    }

    func testReadingProgressOverwrite() {
        let p1 = ReadingProgress(
            bookID: "book-001", sourceID: "c001", bookURL: "b",
            chapterURL: "ch1", chapterTitle: "第一章", progressRatio: 0.1
        )
        try? progressStore.saveProgress(p1)

        let p2 = ReadingProgress(
            bookID: "book-001", sourceID: "c001", bookURL: "b",
            chapterURL: "ch2", chapterTitle: "第二章", progressRatio: 0.8
        )
        try? progressStore.saveProgress(p2)

        let loaded = try? progressStore.loadProgress(bookID: "book-001")
        XCTAssertEqual(loaded?.chapterURL, "ch2")
        XCTAssertEqual(loaded?.progressRatio, 0.8, accuracy: 0.001)
    }

    // MARK: - M3-B: BookshelfStore Progress Update

    func testBookshelfUpdateProgress() {
        let item = BookshelfItem(
            sourceID: "c001",
            sourceName: "星星小说网",
            bookURL: "offline://book/fanren",
            title: "凡人修仙传",
            author: "忘语"
        )
        try? bookshelfStore.addOrUpdate(item)

        try? bookshelfStore.updateProgress(
            bookID: item.id,
            progress: 0.5,
            chapterTitle: "第三章 修炼入门",
            chapterURL: "offline://chapter/3"
        )

        let loaded = (try? bookshelfStore.loadItems()) ?? []
        let found = loaded.first { $0.id == item.id }
        XCTAssertEqual(found?.readingProgress, 0.5, accuracy: 0.001)
        XCTAssertEqual(found?.lastReadChapterTitle, "第三章 修炼入门")
        XCTAssertEqual(found?.lastReadChapterURL, "offline://chapter/3")
    }

    // MARK: - M3-A: Path Safety

    func testChapterContentPathSafety() {
        XCTAssertFalse(store.validatePathInsideSnapshotRoot("../etc/passwd"))
        XCTAssertTrue(store.validatePathInsideSnapshotRoot("c001/chapter/offline_chapter_1"))
    }
}