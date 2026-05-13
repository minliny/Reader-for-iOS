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

    public static func == (lhs: ReaderState, rhs: ReaderState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading, .loading): return true
        case (.loaded(let a), .loaded(let b)): return a.chapterURL == b.chapterURL
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

    private var bookID: String?
    private var sourceID: String?

    public init(
        chapterURL: String,
        chapterTitle: String,
        chapterList: [TOCItem] = [],
        currentChapterIndex: Int = 0,
        bookID: String? = nil,
        sourceID: String? = nil,
        provider: ReaderCoreServiceProvider = .shared,
        progressStore: ReadingProgressStore = .shared,
        settingsStore: ReaderSettingsStore = .shared,
        cacheStore: ChapterCacheStore = .shared,
        bookshelfStore: BookshelfStore = .shared
    ) {
        self.chapterURL = chapterURL
        self.chapterTitle = chapterTitle
        self.chapterList = chapterList
        self.currentChapterIndex = currentChapterIndex
        self.totalChapterCount = max(chapterList.count, 1)
        self.bookID = bookID
        self.sourceID = sourceID
        self.provider = provider
        self.progressStore = progressStore
        self.settingsStore = settingsStore
        self.cacheStore = cacheStore
        self.bookshelfStore = bookshelfStore
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

    // MARK: - Content Loading

    public func loadContent() async {
        readerState = .loading

        if let cached = try? cacheStore.loadEntry(chapterURL: chapterURL, sourceID: sourceID ?? "unknown") {
            if cached.status == .cached {
                // Cache hit — still go through mock for content, but mark as fast path
            }
        }

        let state = await provider.getChapterContent(chapterURL: chapterURL)
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

    // MARK: - Chapter Cache

    private func cacheChapterContent(_ content: ContentPage) async {
        let entry = ChapterCacheEntry(
            sourceID: sourceID ?? "unknown",
            bookURL: extractBookURL(from: chapterURL),
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            status: .cached
        )
        try? cacheStore.saveEntry(entry)
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
