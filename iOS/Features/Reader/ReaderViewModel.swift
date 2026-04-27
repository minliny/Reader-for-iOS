import Foundation
import ReaderCoreModels

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
    @Published public var fontSize: Int = 16
    @Published public var backgroundMode: BackgroundMode = .light

    public let chapterURL: String
    public let chapterTitle: String

    private let provider = ReaderCoreServiceProvider.shared

    public init(chapterURL: String, chapterTitle: String) {
        self.chapterURL = chapterURL
        self.chapterTitle = chapterTitle
    }

    public func loadContent() async {
        readerState = .loading

        do {
            let state = await provider.getChapterContent(chapterURL: chapterURL)
            switch state {
            case .loaded(let content):
                readerState = .loaded(content: content)

            case .partial(let content, let warning):
                readerState = .partial(content: content, warnings: [warning])

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

    public func increaseFontSize() {
        if fontSize < 32 {
            fontSize += 2
        }
    }

    public func decreaseFontSize() {
        if fontSize > 12 {
            fontSize -= 2
        }
    }
}

public enum BackgroundMode: String, CaseIterable {
    case light
    case sepia
    case dark

    public var backgroundColor: String {
        switch self {
        case .light: return "#FFFFFF"
        case .sepia: return "#F4ECD8"
        case .dark: return "#1C1C1E"
        }
    }

    public var textColor: String {
        switch self {
        case .light: return "#000000"
        case .sepia: return "#5C4B37"
        case .dark: return "#FFFFFF"
        }
    }
}