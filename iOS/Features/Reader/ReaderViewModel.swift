import Foundation
import ReaderCoreModels
import ReaderAppSupport
import ReaderAppPersistence
import ReaderShellValidation
#if canImport(ReaderCoreNativeAdapter)
import ReaderCoreNativeAdapter
#endif

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
    @Published public var isLocalBook: Bool = false
    @Published public private(set) var readingDataFailureCode: String?
    @Published public private(set) var readingDataFailureMessage: String?
    @Published public private(set) var settingsPersistenceFailure: String?

    public private(set) var chapterURL: String
    public private(set) var chapterList: [TOCItem]

    public var canGoPreviousChapter: Bool {
        guard let currentOffset = currentChapterListOffset else { return false }
        return currentOffset > 0
    }

    public var canGoNextChapter: Bool {
        guard let currentOffset = currentChapterListOffset else { return false }
        return currentOffset < chapterList.count - 1
    }

    private let provider: ReaderCoreServiceProvider
    private let progressStore: ReadingProgressStore
    private let settingsStore: ReaderSettingsStore
    private let cacheStore: ChapterCacheStore
    private let bookshelfStore: BookshelfStore
    private let snapshotStore: SnapshotStore
    private let bookName: String?
    private let bookAuthor: String?
    private let readingDataService: (any ReaderSlice10ReadingDataServicing)?

    private var bookID: String?
    private var sourceID: String?
    private let source: BookSource?
    private var settingsPersistenceAdmitted = false

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
        bookName: String? = nil,
        bookAuthor: String? = nil,
        provider: ReaderCoreServiceProvider = .shared,
        progressStore: ReadingProgressStore = .shared,
        settingsStore: ReaderSettingsStore = .shared,
        cacheStore: ChapterCacheStore = .shared,
        bookshelfStore: BookshelfStore = .shared,
        snapshotStore: SnapshotStore? = nil,
        readingDataService: (any ReaderSlice10ReadingDataServicing)? = nil
    ) {
        self.chapterURL = chapterURL
        self.chapterTitle = chapterTitle
        self.chapterList = chapterList
        // The renderer receives a Core chapter identity, not a transient array
        // offset. An explicit valid Core index is the entry intent; callers
        // that only know a URL retain the old URL-derived fallback.
        let requestedIndex = max(0, currentChapterIndex)
        self.currentChapterIndex = chapterList.contains(where: { $0.chapterIndex == requestedIndex })
            ? requestedIndex
            : (chapterList.first(where: { $0.chapterURL == chapterURL })?.chapterIndex ?? requestedIndex)
        self.totalChapterCount = max(chapterList.count, 1)
        self.bookID = bookID
        self.sourceID = sourceID
        self.source = source
        self.bookName = bookName
        self.bookAuthor = bookAuthor
        self.readingDataService = readingDataService
        self.isLocalBook = (sourceID == "local-book") || chapterURL.hasPrefix("local-book://")
        self.provider = provider
        self.progressStore = progressStore
        self.settingsStore = settingsStore
        self.cacheStore = cacheStore
        self.bookshelfStore = bookshelfStore
        let snapRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ReaderApp/Snapshots", isDirectory: true)
        self.snapshotStore = snapshotStore ?? SnapshotStore(snapshotRoot: snapRoot)
        loadSettings()
        restoreReadingProgress()
    }

    // MARK: - Settings

    private func loadSettings() {
        do {
            let saved = try settingsStore.loadSettings()
            displaySettings = saved
            settingsPersistenceAdmitted = true
            settingsPersistenceFailure = nil
        } catch {
            // Preserve the original document. In particular, a future schema
            // must not be replaced by defaults during ReaderView.onDisappear.
            settingsPersistenceAdmitted = false
            settingsPersistenceFailure = error.localizedDescription
        }
    }

    @discardableResult
    public func saveSettings() -> Bool {
        guard settingsPersistenceAdmitted else { return false }
        do {
            try settingsStore.saveSettings(displaySettings)
            settingsPersistenceFailure = nil
            return true
        } catch {
            settingsPersistenceFailure = error.localizedDescription
            return false
        }
    }

    // MARK: - Content Loading (M3: cache-first)

    public func loadContent() async {
        readerState = .loading

        // Demo routes must stay anchored to the canonical frontend fixture.
        // A stale simulator snapshot for `frontend-demo` should not turn the
        // audit surface into an empty paper background.
        if loadFrontendDemoContentIfNeeded() {
            return
        }

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

        // B.3: Local books must not fall back to network providers.
        // If the snapshot cache missed for a local-book source, the chapter
        // data is gone — the user must re-import the book.
        if isLocalBook {
            readerState = .failed(message: "本地章节缓存缺失，请重新导入该书")
            return
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

    @discardableResult
    public func loadFrontendDemoContentIfNeeded() -> Bool {
        guard isFrontendDemoChapter else { return false }
        readerState = .loaded(content: frontendDemoContentPage())
        return true
    }

    // MARK: - Chapter Navigation

    public func goPreviousChapter() {
        guard let currentOffset = currentChapterListOffset, currentOffset > 0 else { return }
        navigateToChapter(at: currentOffset - 1)
    }

    public func goNextChapter() {
        guard let currentOffset = currentChapterListOffset,
              currentOffset < chapterList.count - 1 else { return }
        navigateToChapter(at: currentOffset + 1)
    }

    public func goToChapter(at index: Int) {
        navigateToChapter(at: index)
    }

    private func navigateToChapter(at index: Int) {
        guard index >= 0, index < chapterList.count else { return }
        let chapter = chapterList[index]
        chapterURL = chapter.chapterURL
        chapterTitle = chapter.chapterTitle
        currentChapterIndex = chapter.chapterIndex
        readingProgress = 0.0
        Task { await loadContent() }
    }

    // MARK: - Reading History (M5-A)

    /// Updates Core's aggregate read record. `read-record.*` is not a
    /// chapter-history locator contract, so iOS does not persist chapter URL or
    /// progress in a second local model.
    public func recordHistoryEvent() {
        guard let bookName, !bookName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            failReadingData(
                code: "SLICE10_READ_RECORD_BOOK_NAME_MISSING",
                message: "Core read-record requires the book title; chapterTitle is not a valid substitute"
            )
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                let service = try self.resolveReadingDataService()
                let records = try await service.listReadRecords(
                    deviceID: "",
                    correlationID: "read-record-list:\(UUID().uuidString)"
                )
                let accumulated = records.first(where: { $0.bookName == bookName })?.readTime ?? 0
                _ = try await service.upsertReadRecord(
                    deviceID: "",
                    bookName: bookName,
                    readTime: accumulated,
                    lastRead: Int64(Date().timeIntervalSince1970 * 1_000),
                    correlationID: "read-record-upsert:\(UUID().uuidString)"
                )
                self.clearReadingDataFailure()
            } catch is CancellationError {
                return
            } catch {
                self.failReadingData(error)
            }
        }
    }

    // MARK: - Bookmark (M5-B)

    /// Adds a bookmark at the current reading position.
    public func addBookmark(
        chapterPosition: Int? = nil,
        snippet: String? = nil,
        note: String? = nil
    ) {
        guard let bookName, !bookName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            failReadingData(
                code: "SLICE10_BOOKMARK_BOOK_NAME_MISSING",
                message: "Core bookmark requires the book title"
            )
            return
        }
        guard let chapterPosition, chapterPosition >= 0 else {
            failReadingData(
                code: "SLICE10_BOOKMARK_POSITION_UNRESOLVED",
                message: "A percentage cannot be converted into Core chapterPos; an exact locator is required"
            )
            return
        }
        let draft = ReaderCoreBookmarkDraft(
            bookName: bookName,
            bookAuthor: bookAuthor ?? "",
            chapterIndex: currentChapterIndex,
            chapterPosition: chapterPosition,
            chapterName: chapterTitle,
            bookText: snippet ?? "",
            content: note ?? ""
        )
        Task { [weak self] in
            guard let self else { return }
            do {
                let service = try self.resolveReadingDataService()
                _ = try await service.createBookmark(
                    draft,
                    correlationID: "bookmark-create:\(UUID().uuidString)"
                )
                self.clearReadingDataFailure()
            } catch is CancellationError {
                return
            } catch {
                self.failReadingData(error)
            }
        }
    }

    private func resolveReadingDataService() throws -> any ReaderSlice10ReadingDataServicing {
        if let readingDataService { return readingDataService }
        return try ReaderSlice10CoreService.production()
    }

    private func failReadingData(_ error: Error) {
        if let failure = error as? ReaderSlice10CoreServiceError {
            failReadingData(code: failure.code, message: failure.localizedDescription)
        } else {
            failReadingData(code: "SLICE10_READING_DATA_FAILED", message: error.localizedDescription)
        }
    }

    private func failReadingData(code: String, message: String) {
        readingDataFailureCode = code
        readingDataFailureMessage = message
    }

    private func clearReadingDataFailure() {
        readingDataFailureCode = nil
        readingDataFailureMessage = nil
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
            if let currentTOCEntry = chapterList.first(where: { $0.chapterURL == saved.chapterURL }) {
                currentChapterIndex = currentTOCEntry.chapterIndex
            } else if chapterList.isEmpty {
                currentChapterIndex = saved.chapterIndex
            } else if chapterList.contains(where: { $0.chapterIndex == saved.chapterIndex }) {
                currentChapterIndex = saved.chapterIndex
            } else {
                // Legacy/non-matching data has an explicit first-chapter
                // fallback instead of silently treating a Core index as an
                // array offset.
                currentChapterIndex = chapterList.first?.chapterIndex ?? 0
            }
        }
    }

    private func saveReadingProgress() async {
        guard let bookID = bookID, let sourceID = sourceID else { return }

        let progress = ReaderAppSupport.ReadingProgress(
            bookID: bookID,
            sourceID: sourceID,
            bookURL: extractBookURL(from: chapterURL),
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            chapterIndex: currentChapterIndex,
            progressRatio: readingProgress
        )

        // C1: Try Core `reading.progress.update` first; fall back to the local
        // file-backed ReadingProgressStore when the Core bridge is unavailable
        // (e.g. shell CI where RustCore runtime is not booted).
        let coreSent = await pushProgressViaCore(progress)
        if !coreSent {
            try? progressStore.saveProgress(progress)
        }

        try? bookshelfStore.updateProgress(
            bookID: bookID,
            progress: readingProgress,
            chapterTitle: chapterTitle,
            chapterURL: chapterURL,
            chapterIndex: currentChapterIndex
        )
    }

    // MARK: - Core Bridge (C1)

    /// Attempt to push reading progress to Core via `reading.progress.update`.
    /// Returns `true` on success, `false` when the Core bridge is unavailable
    /// or the call fails (caller should fall back to local store).
    private func pushProgressViaCore(
        _ progress: ReaderAppSupport.ReadingProgress
    ) async -> Bool {
        #if canImport(ReaderCoreNativeAdapter)
        guard let runtime = RustCoreRuntimeHolder.shared.current else { return false }

        let params: [String: Any] = [
            "bookId": progress.bookID,
            "sourceId": progress.sourceID,
            "updatedAt": Int64(Date().timeIntervalSince1970),
            "chapterIndex": progress.chapterIndex,
            // The legacy scrolling path has no canonical scalar offset. Zero
            // is the explicit Core-compatible fallback; page Pilot uses the
            // strict correlation-scoped service with the resolved offset.
            "chapterOffset": 0,
            "chapterProgress": progress.progressRatio,
        ]

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let requestId = UInt64.random(in: 1...UInt64.max)
                do {
                    let event = try runtime.request(
                        method: "reading.progress.update",
                        requestId: requestId,
                        params: params,
                        timeout: 10
                    )
                    continuation.resume(returning:
                        event.type == "result"
                            && (event.data?["stored"] as? Bool) == true
                    )
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
        #else
        return false
        #endif
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

    private var isFrontendDemoChapter: Bool {
        chapterURL.hasPrefix("demo://") || sourceID == DemoBookshelfFixture.sourceID
    }

    private func frontendDemoContentPage() -> ContentPage {
        ContentPage(
            title: chapterTitle.isEmpty ? DemoReaderFixture.chapterTitle : chapterTitle,
            content: DemoReaderFixture.readingText.joined(separator: "\n\n"),
            chapterURL: chapterURL,
            nextChapterURL: nextChapterURLAfterCurrent()
        )
    }

    private func nextChapterURLAfterCurrent() -> String? {
        guard let index = currentChapterListOffset else { return nil }
        let nextIndex = index + 1
        guard chapterList.indices.contains(nextIndex) else { return nil }
        return chapterList[nextIndex].chapterURL
    }

    /// `currentChapterIndex` is the Core zero-based identity persisted for
    /// continue-reading. Navigation still needs a renderer list offset, so it
    /// resolves that offset only at the UI boundary.
    private var currentChapterListOffset: Int? {
        chapterList.firstIndex(where: { $0.chapterIndex == currentChapterIndex })
            ?? chapterList.firstIndex(where: { $0.chapterURL == chapterURL })
    }

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
