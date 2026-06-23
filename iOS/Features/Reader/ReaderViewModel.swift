import Foundation
import ReaderCoreModels
import ReaderAppSupport
import ReaderAppPersistence
import ReaderShellValidation

public enum ReaderState: Equatable {
    case idle
    case loading
    case loaded(content: ContentPage)
    case empty
    case failed(message: String)
    case unsupported(reason: String)
    case partial(content: ContentPage, warnings: [String])
    case cached(content: ContentPage)  // M3: loaded from local cache, no network

    public static func == (lhs: ReaderState, rhs: ReaderState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading, .loading): return true
        case (.loaded(let a), .loaded(let b)): return a.chapterURL == b.chapterURL
        case (.cached(let a), .cached(let b)): return a.chapterURL == b.chapterURL
        case (.empty, .empty): return true
        case (.failed(let a), .failed(let b)): return a == b
        case (.unsupported(let a), .unsupported(let b)): return a == b
        case (.partial(let a, let w1), .partial(let b, let w2)):
            return a.chapterURL == b.chapterURL && w1 == w2
        default: return false
        }
    }
}

@MainActor
public final class ReaderViewModel: ObservableObject {
    @Published public var readerState: ReaderState = .idle
    @Published public var displaySettings = ReaderDisplaySettings.default
    @Published public var readingProgress: Double = 0.0
    @Published public var currentChapterIndex: Int = 0
    @Published public var totalChapterCount: Int = 0
    @Published public var chapterTitle: String

    public private(set) var chapterURL: String
    public private(set) var chapterList: [TOCItem]

    public var canGoPreviousChapter: Bool {
        guard !chapterList.isEmpty else { return false }
        return currentChapterIndex > 0
    }

    public var canGoNextChapter: Bool {
        guard !chapterList.isEmpty else { return false }
        return currentChapterIndex < chapterList.count - 1
    }

    private let provider: ReaderCoreServiceProvider
    private let progressStore: ReadingProgressStore
    private let settingsStore: ReaderSettingsStore
    private let cacheStore: ChapterCacheStore
    private let bookshelfStore: BookshelfStore
    private let snapshotStore: SnapshotStore
    private let historyStore: ReadingHistoryStore
    private let bookmarkStore: BookmarkStore

    private var bookID: String?
    private var sourceID: String?
    private let source: BookSource?

    public var currentBookID: String? { bookID }
    public var currentSourceID: String? { sourceID }

    public init(
        chapterURL: String,
        chapterTitle: String,
        chapterList: [TOCItem] = [],
        currentChapterIndex: Int = 0,
        bookID: String? = nil,
        sourceID: String? = nil,
        source: BookSource? = nil,
        provider: ReaderCoreServiceProvider = .shared,
        progressStore: ReadingProgressStore = .shared,
        settingsStore: ReaderSettingsStore = .shared,
        cacheStore: ChapterCacheStore = .shared,
        bookshelfStore: BookshelfStore = .shared,
        snapshotStore: SnapshotStore? = nil,
        historyStore: ReadingHistoryStore = .shared,
        bookmarkStore: BookmarkStore = .shared
    ) {
        self.chapterURL = chapterURL
        self.chapterTitle = chapterTitle
        self.chapterList = chapterList
        self.currentChapterIndex = currentChapterIndex
        self.totalChapterCount = max(chapterList.count, 1)
        self.bookID = bookID
        self.sourceID = sourceID
        self.source = source
        self.provider = provider
        self.progressStore = progressStore
        self.settingsStore = settingsStore
        self.cacheStore = cacheStore
        self.bookshelfStore = bookshelfStore
        let snapRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ReaderApp/Snapshots", isDirectory: true)
        self.snapshotStore = snapshotStore ?? SnapshotStore(snapshotRoot: snapRoot)
        self.historyStore = historyStore
        self.bookmarkStore = bookmarkStore
        loadSettings()
        restoreReadingProgress()
    }

    // MARK: - Settings

    private func loadSettings() {
        if let saved = try? settingsStore.loadSettings() {
            displaySettings = saved
        }
    }

    public func saveSettings() {
        try? settingsStore.saveSettings(displaySettings)
    }

    // MARK: - Content Loading (M3: cache-first)

    public func loadContent() async {
        readerState = .loading

        // M3: Try reading cache first (offline-capable)
        if let sid = sourceID, !sid.isEmpty {
            if let cached = snapshotStore.loadChapterContentSnapshot(sourceId: sid, chapterURL: chapterURL) {
                let page = ContentPage(
                    title: cached.chapterTitle,
                    content: cached.content,
                    chapterURL: cached.chapterURL,
                    nextChapterURL: cached.nextChapterURL
                )
                readerState = .cached(content: page)
                // Restore scroll progress silently
                if let bookID = bookID,
                   let saved = try? progressStore.loadProgress(bookID: bookID),
                   saved.chapterURL == chapterURL {
                    readingProgress = saved.progressRatio
                }
                return
            }
        }

        // Network / provider fallback
        let state = await provider.getChapterContent(chapterURL: chapterURL, source: source)
        switch state {
        case .loaded(let content):
            readerState = .loaded(content: content)
            await saveReadingProgress()
            await cacheChapterContent(content)

        case .partial(let content, let warning):
            readerState = .partial(content: content, warnings: [warning])
            await saveReadingProgress()
            await cacheChapterContent(content)

        case .unsupported(let reason):
            readerState = .unsupported(reason: reason)

        case .failed(let error):
            readerState = .failed(message: error.message)

        case .empty:
            readerState = .empty

        case .loading, .idle:
            break
        }
    }

    public func reload() async {
        await loadContent()
    }

    // MARK: - Chapter Navigation

    public func goPreviousChapter() {
        guard canGoPreviousChapter else { return }
        let newIndex = currentChapterIndex - 1
        navigateToChapter(at: newIndex)
    }

    public func goNextChapter() {
        guard canGoNextChapter else { return }
        let newIndex = currentChapterIndex + 1
        navigateToChapter(at: newIndex)
    }

    private func navigateToChapter(at index: Int) {
        guard index >= 0, index < chapterList.count else { return }
        let chapter = chapterList[index]
        chapterURL = chapter.chapterURL
        chapterTitle = chapter.chapterTitle
        currentChapterIndex = index
        readingProgress = 0.0
        Task { await loadContent() }
    }

    // MARK: - Reading History (M5-A)

    /// Records the current chapter as a reading history event.
    public func recordHistoryEvent() {
        guard let bid = bookID, let sid = sourceID else { return }
        try? historyStore.recordOpen(
            bookId: bid,
            sourceId: sid,
            sourceName: nil,
            title: chapterTitle,
            author: nil,
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            progress: readingProgress
        )
    }

    // MARK: - Bookmark (M5-B)

    /// Adds a bookmark at the current reading position.
    public func addBookmark(snippet: String? = nil, note: String? = nil) {
        guard let bid = bookID, let sid = sourceID else { return }
        try? bookmarkStore.addBookmarkNow(
            bookId: bid,
            sourceId: sid,
            sourceName: nil,
            title: chapterTitle,
            author: nil,
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            progress: readingProgress,
            snippet: snippet,
            note: note
        )
    }

    // MARK: - Progress

    public func updateProgress(ratio: Double) {
        let clamped = min(max(ratio, 0.0), 1.0)
        readingProgress = clamped
    }

    private func restoreReadingProgress() {
        guard let bookID = bookID else { return }
        guard let saved = try? progressStore.loadProgress(bookID: bookID) else { return }
        if saved.chapterURL == chapterURL {
            readingProgress = saved.progressRatio
        }
    }

    private func saveReadingProgress() async {
        guard let bookID = bookID, let sourceID = sourceID else { return }

        let progress = ReadingProgress(
            bookID: bookID,
            sourceID: sourceID,
            bookURL: extractBookURL(from: chapterURL),
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            progressRatio: readingProgress
        )
        try? progressStore.saveProgress(progress)

        try? bookshelfStore.updateProgress(
            bookID: bookID,
            progress: readingProgress,
            chapterTitle: chapterTitle,
            chapterURL: chapterURL
        )
    }

    // MARK: - Chapter Cache (M3: SnapshotStore + ChapterCacheStore)

    private func cacheChapterContent(_ content: ContentPage) async {
        guard let sid = sourceID, !sid.isEmpty else { return }

        // ChapterCacheStore: metadata only
        let entry = ChapterCacheEntry(
            sourceID: sid,
            bookURL: extractBookURL(from: chapterURL),
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            status: .cached
        )
        try? cacheStore.saveEntry(entry)

        // SnapshotStore: actual content text (M3 new)
        _ = snapshotStore.saveChapterContentSnapshot(
            sourceId: sid,
            sourceName: "",
            host: "",
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            content: content.content,
            nextChapterURL: content.nextChapterURL
        )
    }

    // MARK: - Font Size Quick Actions

    public func increaseFontSize() {
        if displaySettings.fontSize < 32 {
            displaySettings.fontSize += 2
        }
    }

    public func decreaseFontSize() {
        if displaySettings.fontSize > 12 {
            displaySettings.fontSize -= 2
        }
    }

    // MARK: - Helpers

    private func extractBookURL(from chapterURL: String) -> String {
        if let range = chapterURL.range(of: "/chapter/") {
            return String(chapterURL[..<range.lowerBound])
        }
        return chapterURL
    }
}

#if DEBUG
extension ReaderViewModel {
    /// Debug-only fixture init — pre-loaded content, no network, no Reader-Core runtime
    public convenience init(
        chapterURL: String,
        chapterTitle: String,
        fixtureContent: String
    ) {
        self.init(chapterURL: chapterURL, chapterTitle: chapterTitle)
        let page = ContentPage(
            title: chapterTitle,
            content: fixtureContent,
            chapterURL: chapterURL
        )
        self.readerState = .loaded(content: page)
    }
}
#endif
