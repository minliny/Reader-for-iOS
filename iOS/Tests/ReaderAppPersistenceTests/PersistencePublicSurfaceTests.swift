import Foundation
import XCTest
import ReaderAppSupport
import ReaderAppPersistence
import ReaderCoreModels

final class PersistencePublicSurfaceTests: XCTestCase {

    // MARK: - ReaderSettingsStore

    func testReaderSettingsLoadDefaultWhenFileMissing() throws {
        let tempURL = makeTempFileURL(name: "test_settings_default.json")
        let store = ReaderSettingsStore(storageURL: tempURL)

        let settings = try store.loadSettings()
        XCTAssertEqual(settings, ReaderDisplaySettings.default)
    }

    func testReaderSettingsSaveAndLoadRoundtrip() throws {
        let tempURL = makeTempFileURL(name: "test_settings_roundtrip.json")
        let store = ReaderSettingsStore(storageURL: tempURL)

        var settings = ReaderDisplaySettings.default
        settings.fontSize = 24
        try store.saveSettings(settings)

        let loaded = try store.loadSettings()
        XCTAssertEqual(loaded.fontSize, 24)
    }

    func testReaderSettingsResetToDefaults() throws {
        let tempURL = makeTempFileURL(name: "test_settings_reset.json")
        let store = ReaderSettingsStore(storageURL: tempURL)

        var settings = ReaderDisplaySettings.default
        settings.fontSize = 30
        try store.saveSettings(settings)

        try store.resetToDefaults()

        let loaded = try store.loadSettings()
        XCTAssertEqual(loaded, ReaderDisplaySettings.default)
    }

    // MARK: - ReadingProgressStore

    func testReadingProgressSaveAndLoadRoundtrip() throws {
        let tempURL = makeTempFileURL(name: "test_progress.json")
        let store = ReadingProgressStore(storageURL: tempURL)

        let progress = ReadingProgress(
            bookID: "book-1",
            sourceID: "source-a",
            bookURL: "https://example.com/book/1",
            chapterURL: "https://example.com/book/1/chapter/3",
            chapterTitle: "Chapter Three",
            progressRatio: 0.5
        )

        try store.saveProgress(progress)
        let loaded = try store.loadProgress(bookID: "book-1")
        XCTAssertEqual(loaded?.chapterTitle, "Chapter Three")
        XCTAssertEqual(loaded?.progressRatio, 0.5)
    }

    func testReadingProgressRemoveDeletesEntry() throws {
        let tempURL = makeTempFileURL(name: "test_progress_remove.json")
        let store = ReadingProgressStore(storageURL: tempURL)

        let progress = ReadingProgress(
            bookID: "book-2", sourceID: "s", bookURL: "b", chapterURL: "c",
            chapterTitle: "t", progressRatio: 0.0
        )
        try store.saveProgress(progress)
        try store.removeProgress(bookID: "book-2")
        XCTAssertNil(try store.loadProgress(bookID: "book-2"))
    }

    func testReadingProgressMissingReturnsNil() throws {
        let tempURL = makeTempFileURL(name: "test_progress_missing.json")
        let store = ReadingProgressStore(storageURL: tempURL)
        XCTAssertNil(try store.loadProgress(bookID: "nonexistent"))
    }

    func testReadingProgressUpdateExisting() throws {
        let tempURL = makeTempFileURL(name: "test_progress_update.json")
        let store = ReadingProgressStore(storageURL: tempURL)

        var progress = ReadingProgress(
            bookID: "book-3", sourceID: "s", bookURL: "b", chapterURL: "c",
            chapterTitle: "t", progressRatio: 0.3
        )
        try store.saveProgress(progress)

        progress.progressRatio = 0.9
        try store.saveProgress(progress)

        let reloaded = try store.loadProgress(bookID: "book-3")
        XCTAssertEqual(reloaded?.progressRatio, 0.9)
    }

    // MARK: - ChapterCacheStore

    func testChapterCacheSaveAndLoadRoundtrip() throws {
        let tempURL = makeTempFileURL(name: "test_cache.json")
        let store = ChapterCacheStore(storageURL: tempURL)

        let entry = ChapterCacheEntry(
            sourceID: "source-a",
            bookURL: "https://example.com/book/2",
            chapterURL: "https://example.com/book/2/chapter/5",
            chapterTitle: "Chapter Five",
            status: .cached
        )

        try store.saveEntry(entry)
        let loaded = try store.loadEntry(chapterURL: entry.chapterURL, sourceID: "source-a")
        XCTAssertEqual(loaded?.chapterTitle, "Chapter Five")
        XCTAssertEqual(loaded?.status, .cached)
    }
    
    func testChapterCacheWithContent() throws {
        let tempURL = makeTempFileURL(name: "test_cache_content.json")
        let store = ChapterCacheStore(storageURL: tempURL)

        let entry = ChapterCacheEntry(
            sourceID: "source-a",
            bookURL: "https://example.com/book/3",
            chapterURL: "https://example.com/book/3/chapter/7",
            chapterTitle: "Chapter Seven",
            status: .cached,
            contentHTML: "<p>Test content</p>",
            contentMarkdown: "Test content"
        )

        try store.saveEntry(entry)
        let loaded = try store.loadEntry(chapterURL: entry.chapterURL, sourceID: "source-a")
        XCTAssertEqual(loaded?.contentHTML, "<p>Test content</p>")
        XCTAssertEqual(loaded?.contentMarkdown, "Test content")
    }

    func testChapterCacheRemoveDeletesEntry() throws {
        let tempURL = makeTempFileURL(name: "test_cache_remove.json")
        let store = ChapterCacheStore(storageURL: tempURL)

        let entry = ChapterCacheEntry(
            sourceID: "s", bookURL: "b", chapterURL: "c",
            chapterTitle: "t", status: .notCached
        )
        try store.saveEntry(entry)
        try store.removeEntry(chapterURL: "c", sourceID: "s")
        XCTAssertNil(try store.loadEntry(chapterURL: "c", sourceID: "s"))
    }

    func testChapterCacheMissingReturnsNil() throws {
        let tempURL = makeTempFileURL(name: "test_cache_missing.json")
        let store = ChapterCacheStore(storageURL: tempURL)
        XCTAssertNil(try store.loadEntry(chapterURL: "/nope", sourceID: "none"))
    }

    func testChapterCacheUpdateStatus() throws {
        let tempURL = makeTempFileURL(name: "test_cache_update.json")
        let store = ChapterCacheStore(storageURL: tempURL)

        var entry = ChapterCacheEntry(
            sourceID: "s", bookURL: "b", chapterURL: "c",
            chapterTitle: "t", status: .notCached
        )
        try store.saveEntry(entry)

        entry.status = .failed
        try store.saveEntry(entry)

        let reloaded = try store.loadEntry(chapterURL: "c", sourceID: "s")
        XCTAssertEqual(reloaded?.status, .failed)
    }

    // MARK: - BookshelfStore

    func testBookshelfAddOrUpdateAndFind() throws {
        let tempURL = makeTempFileURL(name: "test_bookshelf.json")
        let store = BookshelfStore(storageURL: tempURL)

        let item = BookshelfItem(
            id: "shelf-1",
            sourceID: "source-a",
            bookURL: "https://example.com/book/3",
            title: "Test Book",
            author: "Author Name"
        )
        try store.addOrUpdate(item)
        let found = try store.find(bookURL: item.bookURL, sourceID: "source-a")
        XCTAssertEqual(found?.title, "Test Book")
        XCTAssertEqual(found?.author, "Author Name")
    }

    func testBookshelfAddOrUpdateMergesByURL() throws {
        let tempURL = makeTempFileURL(name: "test_bookshelf_update.json")
        let store = BookshelfStore(storageURL: tempURL)

        let item = BookshelfItem(
            id: "shelf-1", sourceID: "s", bookURL: "b", title: "Old"
        )
        try store.addOrUpdate(item)

        let updated = BookshelfItem(
            id: "shelf-1", sourceID: "s", bookURL: "b", title: "New"
        )
        try store.addOrUpdate(updated)

        let found = try store.find(bookURL: "b", sourceID: "s")
        XCTAssertEqual(found?.title, "New")
    }

    func testBookshelfRemoveById() throws {
        let tempURL = makeTempFileURL(name: "test_bookshelf_remove.json")
        let store = BookshelfStore(storageURL: tempURL)

        let item = BookshelfItem(
            id: "shelf-1", sourceID: "s", bookURL: "b", title: "t"
        )
        try store.addOrUpdate(item)
        try store.remove(id: "shelf-1")
        XCTAssertNil(try store.find(bookURL: "b", sourceID: "s"))
    }

    func testBookshelfFindMissingReturnsNil() throws {
        let tempURL = makeTempFileURL(name: "test_bookshelf_missing.json")
        let store = BookshelfStore(storageURL: tempURL)
        XCTAssertNil(try store.find(bookURL: "/nope", sourceID: "none"))
    }

    func testBookshelfUpdateProgress() throws {
        let tempURL = makeTempFileURL(name: "test_bookshelf_progress.json")
        let store = BookshelfStore(storageURL: tempURL)

        let item = BookshelfItem(
            id: "shelf-2", sourceID: "s", bookURL: "b", title: "t"
        )
        try store.addOrUpdate(item)
        try store.updateProgress(
            bookID: "shelf-2", progress: 0.75,
            chapterTitle: "Ch7", chapterURL: "/ch/7"
        )

        let found = try store.find(bookURL: "b", sourceID: "s")
        XCTAssertEqual(found?.readingProgress, 0.75)
        XCTAssertEqual(found?.lastReadChapterTitle, "Ch7")
        XCTAssertEqual(found?.lastReadChapterURL, "/ch/7")
    }

    // MARK: - BookSourceStore

    func testBookSourceLoadEmptyWhenFileMissing() async throws {
        let tempURL = makeTempFileURL(name: "test_sources_empty.json")
        let store = BookSourceStore(storageURL: tempURL)
        let sources = try await store.load()
        XCTAssertTrue(sources.isEmpty)
    }

    func testBookSourceAddAndLoad() async throws {
        let tempURL = makeTempFileURL(name: "test_sources_add.json")
        let store = BookSourceStore(storageURL: tempURL)

        let source = BookSource(bookSourceName: "Test Source")
        try await store.add(source)

        let sources = try await store.load()
        XCTAssertFalse(sources.isEmpty)
        XCTAssertNotNil(sources.first?.id)
    }

    func testBookSourceUpdate() async throws {
        let tempURL = makeTempFileURL(name: "test_sources_update.json")
        let store = BookSourceStore(storageURL: tempURL)

        try await store.add(BookSource(bookSourceName: "Original"))
        let sources = try await store.load()
        var first = sources.first!
        first.bookSourceName = "Modified"
        try await store.update(first)

        let reloaded = try await store.load()
        XCTAssertEqual(reloaded.first?.bookSourceName, "Modified")
    }

    func testBookSourceToggleEnabled() async throws {
        let tempURL = makeTempFileURL(name: "test_sources_toggle.json")
        let store = BookSourceStore(storageURL: tempURL)

        try await store.add(BookSource(bookSourceName: "Toggle Me"))
        let sources = try await store.load()
        let sourceID = sources.first!.id!

        try await store.toggleEnabled(id: sourceID)
        let toggled = try await store.load()
        XCTAssertEqual(toggled.first?.enabled, false)
    }

    func testBookSourceDelete() async throws {
        let tempURL = makeTempFileURL(name: "test_sources_delete.json")
        let store = BookSourceStore(storageURL: tempURL)

        try await store.add(BookSource(bookSourceName: "Delete Me"))
        let sources = try await store.load()
        try await store.delete(id: sources.first!.id!)

        let afterDelete = try await store.load()
        XCTAssertTrue(afterDelete.isEmpty)
    }

    // MARK: - Helpers

    private func makeTempFileURL(name: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PersistenceTests", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }
}
