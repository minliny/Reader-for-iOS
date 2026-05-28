import Foundation
import ReaderCoreModels
import ReaderShellValidation

public enum BookDetailState: Equatable {
    case idle
    case loading
    case loaded(detail: SearchResultItem)
    case empty
    case failed(message: String)
    case unsupported(reason: String)
    case partial(detail: SearchResultItem, warnings: [String])

    public static func == (lhs: BookDetailState, rhs: BookDetailState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.loading, .loading):
            return true
        case (.loaded(let a), .loaded(let b)):
            return a.detailURL == b.detailURL
        case (.empty, .empty):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        case (.unsupported(let a), .unsupported(let b)):
            return a == b
        case (.partial(let a, let w1), .partial(let b, let w2)):
            return a.detailURL == b.detailURL && w1 == w2
        default:
            return false
        }
    }
}

@MainActor
public final class BookDetailViewModel: ObservableObject {
    @Published public var detailState: BookDetailState = .idle
    @Published public var chapters: [TOCItem] = []

    private let bookURL: String
    private let provider = ReaderCoreServiceProvider.shared

    public init(bookURL: String) {
        self.bookURL = bookURL
    }

    public var firstChapter: (chapterURL: String, chapterTitle: String)? {
        guard let first = chapters.first else { return nil }
        return (chapterURL: first.chapterURL, chapterTitle: first.chapterTitle)
    }

    public func loadDetail() async {
        detailState = .loading

        async let detailTask: Void = loadDetailOnly()
        async let chaptersTask: Void = loadChapters()
        _ = await (detailTask, chaptersTask)
    }

    private func loadDetailOnly() async {
        do {
            let state = await provider.getBookDetail(bookURL: bookURL)
            switch state {
            case .loaded(let detail):
                detailState = .loaded(detail: detail)

            case .partial(let detail, let warning):
                detailState = .partial(detail: detail, warnings: [warning])

            case .unsupported(let reason):
                detailState = .unsupported(reason: reason)

            case .failed(let error):
                detailState = .failed(message: error.message)

            case .empty:
                detailState = .empty

            case .loading, .idle:
                break
            }
        } catch {
            detailState = .failed(message: "Load detail failed: \(error.localizedDescription)")
        }
    }

    private func loadChapters() async {
        let state = await provider.getChapterList(bookURL: bookURL)
        switch state {
        case .loaded(let items):
            chapters = items
        case .partial(let items, _):
            chapters = items
        default:
            chapters = []
        }
    }
}