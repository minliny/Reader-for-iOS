import Foundation
import ReaderAppSupport
import ReaderAppPersistence

func main() -> Int32 {
    var failures = 0

    func assertEqual<T: Equatable>(_ got: T, _ expected: T, _ label: String) {
        if got != expected {
            fputs("FAIL: \(label) — expected \(expected), got \(got)\n", stderr)
            failures += 1
        } else {
            fputs("PASS: \(label)\n", stderr)
        }
    }

    func assertNil<T>(_ got: T?, _ label: String) {
        if got != nil {
            fputs("FAIL: \(label) — expected nil, got \(got!)\n", stderr)
            failures += 1
        } else {
            fputs("PASS: \(label)\n", stderr)
        }
    }

    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("PersistenceTestRunner-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    // MARK: - ReaderSettingsStore

    do {
        let fileURL = tempDir.appendingPathComponent("test_settings.json")
        let store = ReaderSettingsStore(storageURL: fileURL)

        // 1. loadSettings returns default when file missing
        let defaultSettings = try store.loadSettings()
        assertEqual(defaultSettings, ReaderDisplaySettings.default, "loadSettings returns default when file missing")

        // 2. saveSettings then loadSettings returns saved value
        var settings = ReaderDisplaySettings.default
        settings.fontSize = 24
        try store.saveSettings(settings)
        let loaded = try store.loadSettings()
        assertEqual(loaded.fontSize, 24, "saveSettings then loadSettings returns saved fontSize")

        // 3. resetToDefaults restores default values
        try store.resetToDefaults()
        let reset = try store.loadSettings()
        assertEqual(reset, ReaderDisplaySettings.default, "resetToDefaults restores default values")
    } catch {
        fputs("FAIL: ReaderSettingsStore — error: \(error)\n", stderr)
        failures += 1
    }

    // MARK: - ReaderDisplaySettings Codable round-trip
    do {
        var original = ReaderDisplaySettings.default
        original.fontSize = 18
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ReaderDisplaySettings.self, from: data)
        assertEqual(decoded.fontSize, 18, "ReaderDisplaySettings Codable round-trip fontSize")
    } catch {
        fputs("FAIL: ReaderDisplaySettings Codable — error: \(error)\n", stderr)
        failures += 1
    }

    // MARK: - ReadingProgressStore

    do {
        let fileURL = tempDir.appendingPathComponent("test_progress.json")
        let store = ReadingProgressStore(storageURL: fileURL)

        let progress = ReadingProgress(
            bookID: "book-1",
            sourceID: "source-a",
            bookURL: "https://example.com/book/1",
            chapterURL: "https://example.com/book/1/chapter/3",
            chapterTitle: "Chapter Three",
            progressRatio: 0.5
        )

        // 1. saveProgress then loadProgress returns saved value
        try store.saveProgress(progress)
        let loaded = try store.loadProgress(bookID: "book-1")
        assertEqual(loaded?.chapterTitle, "Chapter Three", "saveProgress then loadProgress returns chapterTitle")
        assertEqual(loaded?.progressRatio, 0.5, "saveProgress then loadProgress returns progressRatio")

        // 2. removeProgress deletes saved value
        try store.removeProgress(bookID: "book-1")
        let afterRemove = try store.loadProgress(bookID: "book-1")
        if afterRemove != nil {
            fputs("FAIL: removeProgress deletes saved value — expected nil\n", stderr)
            failures += 1
        } else {
            fputs("PASS: removeProgress deletes saved value\n", stderr)
        }

        // 3. missing progress returns nil
        let missing = try store.loadProgress(bookID: "nonexistent")
        if missing != nil {
            fputs("FAIL: missing progress returns nil — expected nil\n", stderr)
            failures += 1
        } else {
            fputs("PASS: missing progress returns nil\n", stderr)
        }

        // 4. update existing progress
        var updatedProgress = progress
        updatedProgress.progressRatio = 0.75
        try store.saveProgress(updatedProgress)
        let reloaded = try store.loadProgress(bookID: "book-1")
        assertEqual(reloaded?.progressRatio, 0.75, "update existing progressRatio to 0.75")
    } catch {
        fputs("FAIL: ReadingProgressStore — error: \(error)\n", stderr)
        failures += 1
    }

    // MARK: - ReadingProgress Codable round-trip
    do {
        let original = ReadingProgress(
            bookID: "b1", sourceID: "s1", bookURL: "b", chapterURL: "c",
            chapterTitle: "t", progressRatio: 0.3
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ReadingProgress.self, from: data)
        assertEqual(decoded.bookID, "b1", "ReadingProgress Codable round-trip bookID")
        assertEqual(decoded.progressRatio, 0.3, "ReadingProgress Codable round-trip progressRatio")
    } catch {
        fputs("FAIL: ReadingProgress Codable — error: \(error)\n", stderr)
        failures += 1
    }

    // MARK: - ChapterCacheStore

    do {
        let fileURL = tempDir.appendingPathComponent("test_cache.json")
        let store = ChapterCacheStore(storageURL: fileURL)

        let entry = ChapterCacheEntry(
            sourceID: "source-a",
            bookURL: "https://example.com/book/2",
            chapterURL: "https://example.com/book/2/chapter/5",
            chapterTitle: "Chapter Five",
            status: .cached
        )

        // 1. saveEntry then loadEntry returns saved value
        try store.saveEntry(entry)
        let loaded = try store.loadEntry(chapterURL: entry.chapterURL, sourceID: "source-a")
        assertEqual(loaded?.chapterTitle, "Chapter Five", "saveEntry then loadEntry returns chapterTitle")
        assertEqual(loaded?.status, .cached, "saveEntry then loadEntry returns status .cached")

        // 2. removeEntry deletes saved value
        try store.removeEntry(chapterURL: entry.chapterURL, sourceID: "source-a")
        let afterRemove = try store.loadEntry(chapterURL: entry.chapterURL, sourceID: "source-a")
        if afterRemove != nil {
            fputs("FAIL: removeEntry deletes saved value — expected nil\n", stderr)
            failures += 1
        } else {
            fputs("PASS: removeEntry deletes saved value\n", stderr)
        }

        // 3. missing entry returns nil
        let missing = try store.loadEntry(chapterURL: "/nonexistent", sourceID: "none")
        if missing != nil {
            fputs("FAIL: missing entry returns nil — expected nil\n", stderr)
            failures += 1
        } else {
            fputs("PASS: missing entry returns nil\n", stderr)
        }

        // 4. update entry status
        var updated = entry
        updated.status = .failed
        try store.saveEntry(updated)
        let reloaded = try store.loadEntry(chapterURL: entry.chapterURL, sourceID: "source-a")
        assertEqual(reloaded?.status, .failed, "update entry status to .failed")
    } catch {
        fputs("FAIL: ChapterCacheStore — error: \(error)\n", stderr)
        failures += 1
    }

    // MARK: - ChapterCacheEntry Codable round-trip
    do {
        let original = ChapterCacheEntry(
            sourceID: "s1", bookURL: "b", chapterURL: "c",
            chapterTitle: "t", status: .cached
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChapterCacheEntry.self, from: data)
        assertEqual(decoded.sourceID, "s1", "ChapterCacheEntry Codable round-trip sourceID")
        assertEqual(decoded.status, .cached, "ChapterCacheEntry Codable round-trip status")
    } catch {
        fputs("FAIL: ChapterCacheEntry Codable — error: \(error)\n", stderr)
        failures += 1
    }

    // MARK: - BookshelfStore

    do {
        let fileURL = tempDir.appendingPathComponent("test_bookshelf.json")
        let store = BookshelfStore(storageURL: fileURL)

        let item = BookshelfItem(
            id: "shelf-1",
            sourceID: "source-a",
            bookURL: "https://example.com/book/3",
            title: "Test Book",
            author: "Author Name"
        )

        // 1. addOrUpdate then find returns saved item
        try store.addOrUpdate(item)
        let found = try store.find(bookURL: item.bookURL, sourceID: "source-a")
        assertEqual(found?.title, "Test Book", "addOrUpdate then find returns title")
        assertEqual(found?.author, "Author Name", "addOrUpdate then find returns author")

        // 2. addOrUpdate with same bookURL/sourceID updates existing
        let updated = BookshelfItem(
            id: "shelf-1",
            sourceID: "source-a",
            bookURL: item.bookURL,
            title: "Updated Title",
            author: "New Author"
        )
        try store.addOrUpdate(updated)
        let refound = try store.find(bookURL: item.bookURL, sourceID: "source-a")
        assertEqual(refound?.title, "Updated Title", "addOrUpdate updates title for same bookURL/sourceID")
        assertEqual(refound?.author, "New Author", "addOrUpdate updates author for same bookURL/sourceID")

        // 3. remove deletes by id
        try store.remove(id: "shelf-1")
        let afterRemove = try store.find(bookURL: item.bookURL, sourceID: "source-a")
        if afterRemove != nil {
            fputs("FAIL: remove deletes saved item — expected nil\n", stderr)
            failures += 1
        } else {
            fputs("PASS: remove deletes saved item\n", stderr)
        }

        // 4. find missing returns nil
        let missing = try store.find(bookURL: "/nonexistent", sourceID: "none")
        if missing != nil {
            fputs("FAIL: find missing returns nil — expected nil\n", stderr)
            failures += 1
        } else {
            fputs("PASS: find missing returns nil\n", stderr)
        }

        // 5. updateProgress updates readingProgress and chapter info
        let item2 = BookshelfItem(
            id: "shelf-2",
            sourceID: "source-b",
            bookURL: "https://example.com/book/4",
            title: "Book Four"
        )
        try store.addOrUpdate(item2)
        try store.updateProgress(
            bookID: "shelf-2",
            progress: 0.66,
            chapterTitle: "Chapter 6",
            chapterURL: "/book/4/chapter/6"
        )
        let withProgress = try store.find(bookURL: item2.bookURL, sourceID: "source-b")
        assertEqual(withProgress?.readingProgress, 0.66, "updateProgress sets readingProgress to 0.66")
        assertEqual(withProgress?.lastReadChapterTitle, "Chapter 6", "updateProgress sets lastReadChapterTitle")
        assertEqual(withProgress?.lastReadChapterURL, "/book/4/chapter/6", "updateProgress sets lastReadChapterURL")
    } catch {
        fputs("FAIL: BookshelfStore — error: \(error)\n", stderr)
        failures += 1
    }

    // MARK: - BookshelfItem Codable round-trip
    do {
        let original = BookshelfItem(
            id: "codable-1",
            sourceID: "s1",
            bookURL: "b",
            title: "Codable Book",
            author: "Author",
            readingProgress: 0.42
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BookshelfItem.self, from: data)
        assertEqual(decoded.id, "codable-1", "BookshelfItem Codable round-trip id")
        assertEqual(decoded.title, "Codable Book", "BookshelfItem Codable round-trip title")
        assertEqual(decoded.readingProgress, 0.42, "BookshelfItem Codable round-trip readingProgress")
    } catch {
        fputs("FAIL: BookshelfItem Codable — error: \(error)\n", stderr)
        failures += 1
    }

    if failures > 0 {
        fputs("\n\(failures) test(s) FAILED\n", stderr)
        return 1
    }
    fputs("\nAll persistence surface tests PASSED\n", stderr)
    return 0
}

exit(main())
