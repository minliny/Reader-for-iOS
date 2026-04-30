import Foundation
import ReaderCoreModels
import ReaderAppSupport
import ReaderAppPersistence

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
        case (.idle, .idle):
            return true
        case (.loading, .loading):
            return true
        case (.loaded(let a), .loaded(let b)):
            return a.chapterURL == b.chapterURL
        case (.empty, .empty):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        case (.unsupported(let a), .unsupported(let b)):
            return a == b
        case (.partial(let a, let w1), .partial(let b, let w2)):
            return a.chapterURL == b.chapterURL && w1 == w2
        default:
            return false
        }
    }
}

@MainActor
public final class ReaderViewModel: ObservableObject {
    @Published public var readerState: ReaderState = .idle
    @Published public var displaySettings = ReaderDisplaySettings.default

    public let chapterURL: String
    public let chapterTitle: String

    private let provider = ReaderCoreServiceProvider.shared
    private let bookshelfStore = BookshelfStore.shared
    private let settingsStore = ReaderSettingsStore.shared

    public init(chapterURL: String, chapterTitle: String) {
        self.chapterURL = chapterURL
        self.chapterTitle = chapterTitle
        loadSettings()
    }

    private func loadSettings() {
        if let savedSettings = try? settingsStore.loadSettings() {
            displaySettings = savedSettings
        }
    }

    public func saveSettings() {
        try? settingsStore.saveSettings(displaySettings)
    }

    public func loadContent() async {
        readerState = .loading

        do {
            let state = await provider.getChapterContent(chapterURL: chapterURL)
            switch state {
            case .loaded(let content):
                readerState = .loaded(content: content)
                await saveReadingProgress()

            case .partial(let content, let warning):
                readerState = .partial(content: content, warnings: [warning])
                await saveReadingProgress()

            case .unsupported(let reason):
                readerState = .unsupported(reason: reason)

            case .failed(let error):
                readerState = .failed(message: error.message)

            case .empty:
                readerState = .empty

            case .loading, .idle:
                break
            }
        } catch {
            readerState = .failed(message: "Load content failed: \(error.localizedDescription)")
        }
    }

    private func saveReadingProgress() async {
        let bookURL = extractBookURL(from: chapterURL)
        let sourceIdentity = SourceIdentity(
            id: bookURL,
            name: nil,
            baseURL: nil
        )

        if let existingItem = try? bookshelfStore.find(bookURL: bookURL, sourceID: sourceIdentity.id) {
            try? bookshelfStore.updateProgress(
                bookID: existingItem.id,
                progress: 0.0,
                chapterTitle: chapterTitle,
                chapterURL: chapterURL
            )
        }
    }

    private func extractBookURL(from chapterURL: String) -> String {
        if let range = chapterURL.range(of: "/chapter/") {
            return String(chapterURL[..<range.lowerBound])
        }
        return chapterURL
    }

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
}