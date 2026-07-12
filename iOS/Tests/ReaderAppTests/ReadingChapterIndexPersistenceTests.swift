import Foundation
import XCTest
import ReaderAppPersistence
import ReaderAppSupport
import ReaderCoreModels
@testable import ReaderApp
@testable import ReaderShellValidation

final class ReadingChapterIndexPersistenceTests: XCTestCase {
    func testLegacyReadingProgressWithoutChapterIndexFallsBackToZero() throws {
        let current = ReadingProgress(
            bookID: "book-1",
            sourceID: "source-1",
            bookURL: "https://example.test/book/1",
            chapterURL: "https://example.test/chapter/1",
            chapterTitle: "第一章",
            chapterIndex: 9,
            progressRatio: 0.4,
            updatedAt: Date(timeIntervalSinceReferenceDate: 1234)
        )
        let legacyData = try removingKey("chapterIndex", from: JSONEncoder().encode(current))

        let decoded = try JSONDecoder().decode(ReadingProgress.self, from: legacyData)

        XCTAssertEqual(decoded.chapterIndex, 0)
        XCTAssertEqual(decoded.chapterURL, current.chapterURL)
        XCTAssertEqual(decoded.progressRatio, current.progressRatio)
    }

    func testReadingProgressRoundTripPersistsChapterIndex() throws {
        let progress = ReadingProgress(
            bookID: "book-1",
            sourceID: "source-1",
            bookURL: "https://example.test/book/1",
            chapterURL: "https://example.test/chapter/8",
            chapterTitle: "第八章",
            chapterIndex: 7,
            progressRatio: 0.4,
            updatedAt: Date(timeIntervalSinceReferenceDate: 1234)
        )

        let decoded = try JSONDecoder().decode(
            ReadingProgress.self,
            from: JSONEncoder().encode(progress)
        )

        XCTAssertEqual(decoded, progress)
        XCTAssertEqual(decoded.chapterIndex, 7)
    }

    func testLegacyStoreRecordRewritesExplicitZeroIndexOnItsNextSave() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("reader-progress-migration-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storageURL = directory.appendingPathComponent("reading-progress.json")
        let store = ReadingProgressStore(storageURL: storageURL)
        let current = ReadingProgress(
            bookID: "book-1",
            sourceID: "source-1",
            bookURL: "https://example.test/book/1",
            chapterURL: "https://example.test/chapter/1",
            chapterTitle: "第一章",
            chapterIndex: 9,
            progressRatio: 0.4,
            updatedAt: Date(timeIntervalSinceReferenceDate: 1234)
        )

        let legacyRecord = try XCTUnwrap(
            JSONSerialization.jsonObject(with: removingKey("chapterIndex", from: JSONEncoder().encode(current)))
                as? [String: Any]
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacyMap = try JSONSerialization.data(withJSONObject: ["book-1": legacyRecord])
        try legacyMap.write(to: storageURL)

        let migrated = try XCTUnwrap(store.loadProgress(bookID: "book-1"))
        XCTAssertEqual(migrated.chapterIndex, 0)
        try store.saveProgress(migrated)

        let persisted = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: storageURL)) as? [String: [String: Any]]
        )
        XCTAssertEqual(persisted["book-1"]?["chapterIndex"] as? Int, 0)
    }

    func testLegacyBookshelfItemWithoutChapterIndexExposesZeroFallback() throws {
        let item = BookshelfItem(
            id: "shelf-1",
            sourceID: "source-1",
            bookURL: "https://example.test/book/1",
            title: "Book",
            lastReadChapterTitle: "第八章",
            lastReadChapterURL: "https://example.test/chapter/8",
            lastReadChapterIndex: 7
        )
        let legacyData = try removingKey("lastReadChapterIndex", from: JSONEncoder().encode(item))

        let decoded = try JSONDecoder().decode(BookshelfItem.self, from: legacyData)

        XCTAssertNil(decoded.lastReadChapterIndex)
        XCTAssertEqual(decoded.resolvedLastReadChapterIndex, 0)
    }

    func testBookshelfStoreUpdatePersistsKnownChapterIndex() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("reader-chapter-index-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BookshelfStore(storageURL: directory.appendingPathComponent("bookshelf.json"))
        try store.saveItems([
            BookshelfItem(
                id: "shelf-1",
                sourceID: "source-1",
                bookURL: "https://example.test/book/1",
                title: "Book"
            ),
        ])

        try store.updateProgress(
            bookID: "shelf-1",
            progress: 0.4,
            chapterTitle: "第八章",
            chapterURL: "https://example.test/chapter/8",
            chapterIndex: 7
        )

        let saved = try XCTUnwrap(store.loadItems().first)
        XCTAssertEqual(saved.lastReadChapterIndex, 7)
        XCTAssertEqual(saved.resolvedLastReadChapterIndex, 7)
    }

    func testLocalBookshelfFactoryPersistsFirstCoreChapterIndex() {
        let chapters = [
            TOCItem(chapterTitle: "第六章", chapterURL: "local-book://chapter/6", chapterIndex: 5),
        ]
        let localBook = LocalBook(
            id: "core-local-1",
            title: "Local",
            filePath: "/tmp/local.txt"
        )

        let item = BookshelfItemFactory.makeOrUpdate(
            from: localBook,
            firstChapterTitle: "第六章",
            firstChapterURL: "local-book://chapter/6",
            localChapterList: chapters
        )

        XCTAssertEqual(item.lastReadChapterIndex, 5)
        XCTAssertEqual(item.resolvedLastReadChapterIndex, 5)
    }

    @MainActor
    func testReaderContextAndViewModelKeepCoreChapterIndexInsteadOfTOCArrayOffset() {
        let context = ReaderContext(
            bookID: "book-1",
            chapterURL: "local-book://chapter/8",
            chapterTitle: "第八章",
            chapterIndex: 7,
            sourceID: "local-book",
            source: .actionToImmersive
        )
        let chapters = [
            TOCItem(chapterTitle: "第六章", chapterURL: "local-book://chapter/6", chapterIndex: 5),
            TOCItem(chapterTitle: "第八章", chapterURL: "local-book://chapter/8", chapterIndex: 7),
        ]
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("reader-context-index-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let viewModel = ReaderViewModel(
            chapterURL: context.chapterURL,
            chapterTitle: context.chapterTitle,
            chapterList: chapters,
            currentChapterIndex: context.chapterIndex,
            bookID: context.bookID,
            sourceID: context.sourceID,
            progressStore: ReadingProgressStore(storageURL: root.appendingPathComponent("progress.json")),
            settingsStore: ReaderSettingsStore(storageURL: root.appendingPathComponent("settings.json")),
            cacheStore: ChapterCacheStore(storageURL: root.appendingPathComponent("cache.json")),
            bookshelfStore: BookshelfStore(storageURL: root.appendingPathComponent("bookshelf.json")),
            snapshotStore: SnapshotStore(snapshotRoot: root.appendingPathComponent("snapshots", isDirectory: true))
        )

        XCTAssertEqual(context.chapterIndex, 7)
        XCTAssertEqual(viewModel.currentChapterIndex, 7)
        XCTAssertTrue(viewModel.canGoPreviousChapter)
        XCTAssertFalse(viewModel.canGoNextChapter)
    }

    private func removingKey(_ key: String, from data: Data) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: key)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
