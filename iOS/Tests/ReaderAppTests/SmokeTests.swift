import XCTest
@testable import ReaderApp
import ReaderAppSupport
import ReaderAppPersistence
import ReaderCoreModels

// MARK: - ReaderViewModel Tests

@MainActor
final class ReaderViewModelTests: XCTestCase {

    // MARK: - Initial State

    func testInitialStateIsIdle() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.readerState, .idle)
        XCTAssertEqual(vm.currentChapterIndex, 0)
        XCTAssertEqual(vm.totalChapterCount, 1)
        XCTAssertEqual(vm.readingProgress, 0.0)
        XCTAssertFalse(vm.canGoPreviousChapter)
        XCTAssertFalse(vm.canGoNextChapter)
    }

    func testInitialStateWithChapterList() {
        let chapters = makeChapterList(count: 5)
        let vm = makeViewModel(chapterList: chapters, currentChapterIndex: 2)
        XCTAssertEqual(vm.totalChapterCount, 5)
        XCTAssertEqual(vm.currentChapterIndex, 2)
        XCTAssertTrue(vm.canGoPreviousChapter)
        XCTAssertTrue(vm.canGoNextChapter)
    }

    // MARK: - Navigation Boundaries

    func testCannotGoPreviousAtFirstChapter() {
        let chapters = makeChapterList(count: 3)
        let vm = makeViewModel(chapterList: chapters, currentChapterIndex: 0)
        XCTAssertFalse(vm.canGoPreviousChapter)
        XCTAssertTrue(vm.canGoNextChapter)
    }

    func testCannotGoNextAtLastChapter() {
        let chapters = makeChapterList(count: 3)
        let vm = makeViewModel(chapterList: chapters, currentChapterIndex: 2)
        XCTAssertTrue(vm.canGoPreviousChapter)
        XCTAssertFalse(vm.canGoNextChapter)
    }

    func testCannotGoNextWithEmptyChapterList() {
        let vm = makeViewModel(chapterList: [], currentChapterIndex: 0)
        XCTAssertFalse(vm.canGoPreviousChapter)
        XCTAssertFalse(vm.canGoNextChapter)
    }

    func testSingleChapterCannotNavigate() {
        let chapters = makeChapterList(count: 1)
        let vm = makeViewModel(chapterList: chapters, currentChapterIndex: 0)
        XCTAssertFalse(vm.canGoPreviousChapter)
        XCTAssertFalse(vm.canGoNextChapter)
    }

    // MARK: - Navigation Actions

    func testGoNextChapterUpdatesState() {
        let chapters = makeChapterList(count: 3)
        let vm = makeViewModel(chapterList: chapters, currentChapterIndex: 0)
        vm.goNextChapter()
        XCTAssertEqual(vm.currentChapterIndex, 1)
        XCTAssertEqual(vm.chapterTitle, chapters[1].chapterTitle)
        XCTAssertEqual(vm.chapterURL, chapters[1].chapterURL)
    }

    func testGoPreviousChapterUpdatesState() {
        let chapters = makeChapterList(count: 3)
        let vm = makeViewModel(chapterList: chapters, currentChapterIndex: 2)
        vm.goPreviousChapter()
        XCTAssertEqual(vm.currentChapterIndex, 1)
        XCTAssertEqual(vm.chapterTitle, chapters[1].chapterTitle)
    }

    func testGoNextAtLastChapterDoesNothing() {
        let chapters = makeChapterList(count: 2)
        let vm = makeViewModel(chapterList: chapters, currentChapterIndex: 1)
        vm.goNextChapter()
        XCTAssertEqual(vm.currentChapterIndex, 1) // unchanged
    }

    func testGoPreviousAtFirstChapterDoesNothing() {
        let chapters = makeChapterList(count: 2)
        let vm = makeViewModel(chapterList: chapters, currentChapterIndex: 0)
        vm.goPreviousChapter()
        XCTAssertEqual(vm.currentChapterIndex, 0) // unchanged
    }

    // MARK: - Progress Update

    func testUpdateProgressClampsToValidRange() {
        let vm = makeViewModel()
        vm.updateProgress(ratio: 0.5)
        XCTAssertEqual(vm.readingProgress, 0.5)
        vm.updateProgress(ratio: 1.5)
        XCTAssertEqual(vm.readingProgress, 1.0)
        vm.updateProgress(ratio: -0.5)
        XCTAssertEqual(vm.readingProgress, 0.0)
    }

    // MARK: - Settings Load / Save

    func testSettingsSaveAndLoadPersistence() throws {
        let tempURL = makeTempFileURL(name: "test_vm_settings.json")
        let settingsStore = ReaderSettingsStore(storageURL: tempURL)
        let progressStore = ReadingProgressStore(storageURL: makeTempFileURL(name: "test_vm_progress.json"))
        let cacheStore = ChapterCacheStore(storageURL: makeTempFileURL(name: "test_vm_cache.json"))
        let bookshelfStore = BookshelfStore(storageURL: makeTempFileURL(name: "test_vm_bookshelf.json"))

        let vm = ReaderViewModel(
            chapterURL: "https://example.com/book/1/chapter/1",
            chapterTitle: "Test Chapter",
            settingsStore: settingsStore,
            progressStore: progressStore,
            cacheStore: cacheStore,
            bookshelfStore: bookshelfStore
        )

        XCTAssertEqual(vm.displaySettings, ReaderDisplaySettings.default)

        vm.displaySettings.fontSize = 24
        vm.saveSettings()

        let loaded = try settingsStore.loadSettings()
        XCTAssertEqual(loaded.fontSize, 24)
    }

    func testDefaultsUsedWhenNoSavedSettings() {
        let tempURL = makeTempFileURL(name: "test_vm_defaults.json")
        let store = ReaderSettingsStore(storageURL: tempURL)
        let vm = ReaderViewModel(
            chapterURL: "https://example.com/book/1/chapter/1",
            chapterTitle: "Test Chapter",
            settingsStore: store
        )
        XCTAssertEqual(vm.displaySettings.fontSize, ReaderDisplaySettings.default.fontSize)
    }

    // MARK: - Font Size Quick Actions

    func testIncreaseFontSizeWithinBounds() {
        let vm = makeViewModel()
        let initial = vm.displaySettings.fontSize
        vm.increaseFontSize()
        XCTAssertEqual(vm.displaySettings.fontSize, initial + 2)
    }

    func testDecreaseFontSizeWithinBounds() {
        let vm = makeViewModel()
        let initial = vm.displaySettings.fontSize
        vm.decreaseFontSize()
        XCTAssertEqual(vm.displaySettings.fontSize, initial - 2)
    }

    func testFontSizeMaxClamped() {
        let vm = makeViewModel()
        vm.displaySettings.fontSize = 32
        vm.increaseFontSize()
        XCTAssertEqual(vm.displaySettings.fontSize, 32)
    }

    func testFontSizeMinClamped() {
        let vm = makeViewModel()
        vm.displaySettings.fontSize = 12
        vm.decreaseFontSize()
        XCTAssertEqual(vm.displaySettings.fontSize, 12)
    }

    // MARK: - Progress Restore

    func testProgressRestoredWhenBookIDMatches() throws {
        let progressURL = makeTempFileURL(name: "test_vm_progress_restore.json")
        let progressStore = ReadingProgressStore(storageURL: progressURL)
        let settingsStore = ReaderSettingsStore(storageURL: makeTempFileURL(name: "test_vm_settings2.json"))
        let cacheStore = ChapterCacheStore(storageURL: makeTempFileURL(name: "test_vm_cache2.json"))
        let bookshelfStore = BookshelfStore(storageURL: makeTempFileURL(name: "test_vm_bs2.json"))

        try progressStore.saveProgress(ReadingProgress(
            bookID: "book-42", sourceID: "source-x",
            bookURL: "https://example.com/book/42",
            chapterURL: "https://example.com/book/42/chapter/3",
            chapterTitle: "Chapter 3",
            progressRatio: 0.7
        ))

        let vm = ReaderViewModel(
            chapterURL: "https://example.com/book/42/chapter/3",
            chapterTitle: "Chapter 3",
            bookID: "book-42",
            sourceID: "source-x",
            progressStore: progressStore,
            settingsStore: settingsStore,
            cacheStore: cacheStore,
            bookshelfStore: bookshelfStore
        )

        XCTAssertEqual(vm.readingProgress, 0.7)
    }

    func testProgressNotRestoredWhenBookIDMissing() {
        let progressURL = makeTempFileURL(name: "test_vm_progress_no_bookid.json")
        let progressStore = ReadingProgressStore(storageURL: progressURL)
        let settingsStore = ReaderSettingsStore(storageURL: makeTempFileURL(name: "test_vm_settings3.json"))
        let cacheStore = ChapterCacheStore(storageURL: makeTempFileURL(name: "test_vm_cache3.json"))
        let bookshelfStore = BookshelfStore(storageURL: makeTempFileURL(name: "test_vm_bs3.json"))

        try? progressStore.saveProgress(ReadingProgress(
            bookID: "book-99", sourceID: "s",
            bookURL: "b", chapterURL: "c",
            chapterTitle: "t", progressRatio: 0.9
        ))

        let vm = ReaderViewModel(
            chapterURL: "https://example.com/book/1/chapter/1",
            chapterTitle: "Chapter 1",
            bookID: nil,
            sourceID: nil,
            progressStore: progressStore,
            settingsStore: settingsStore,
            cacheStore: cacheStore,
            bookshelfStore: bookshelfStore
        )

        XCTAssertEqual(vm.readingProgress, 0.0)
    }

    // MARK: - Helpers

    private func makeViewModel(
        chapterList: [TOCItem] = [],
        currentChapterIndex: Int = 0,
        bookID: String? = nil,
        sourceID: String? = nil
    ) -> ReaderViewModel {
        ReaderViewModel(
            chapterURL: "https://example.com/book/1/chapter/1",
            chapterTitle: "Chapter 1",
            chapterList: chapterList,
            currentChapterIndex: currentChapterIndex,
            bookID: bookID,
            sourceID: sourceID,
            progressStore: ReadingProgressStore(storageURL: makeTempFileURL(name: UUID().uuidString)),
            settingsStore: ReaderSettingsStore(storageURL: makeTempFileURL(name: UUID().uuidString)),
            cacheStore: ChapterCacheStore(storageURL: makeTempFileURL(name: UUID().uuidString)),
            bookshelfStore: BookshelfStore(storageURL: makeTempFileURL(name: UUID().uuidString))
        )
    }

    private func makeChapterList(count: Int) -> [TOCItem] {
        (0..<count).map { i in
            TOCItem(
                chapterTitle: "Chapter \(i + 1)",
                chapterURL: "https://example.com/book/1/chapter/\(i + 1)",
                chapterIndex: i
            )
        }
    }

    private func makeTempFileURL(name: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReaderAppTests", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }
}
