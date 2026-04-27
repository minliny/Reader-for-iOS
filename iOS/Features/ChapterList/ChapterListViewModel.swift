import Foundation
import ReaderCoreModels

public enum ChapterListState: Equatable {
    case idle
    case loading
    case loaded(chapters: [TOCItem])
    case empty
    case failed(message: String)
    case unsupported(reason: String)
    case partial(chapters: [TOCItem], warnings: [String])

    public static func == (lhs: ChapterListState, rhs: ChapterListState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.loading, .loading):
            return true
        case (.loaded(let a), .loaded(let b)):
            return a.count == b.count && a.allSatisfy { item in
                b.contains { $0.chapterURL == item.chapterURL }
            }
        case (.empty, .empty):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        case (.unsupported(let a), .unsupported(let b)):
            return a == b
        case (.partial(let a, let w1), .partial(let b, let w2)):
            return a.count == b.count && a.allSatisfy { item in
                b.contains { $0.chapterURL == item.chapterURL }
            } && w1 == w2
        default:
            return false
        }
    }
}

@MainActor
public final class ChapterListViewModel: ObservableObject {
    @Published public var listState: ChapterListState = .idle
    @Published public var bookTitle: String

    private let bookURL: String
    private let provider = ReaderCoreServiceProvider.shared

    public init(bookURL: String, bookTitle: String) {
        self.bookURL = bookURL
        self.bookTitle = bookTitle
    }

    public func loadChapters() async {
        listState = .loading

        do {
            let state = await provider.getChapterList(bookURL: bookURL)
            switch state {
            case .loaded(let chapters):
                if chapters.isEmpty {
                    listState = .empty
                } else {
                    listState = .loaded(chapters: chapters)
                }

            case .partial(let chapters, let warning):
                listState = .partial(chapters: chapters, warnings: [warning])

            case .unsupported(let reason):
                listState = .unsupported(reason: reason)

            case .failed(let error):
                listState = .failed(message: error.message)

            case .empty:
                listState = .empty

            case .loading, .idle:
                break
            }
        } catch {
            listState = .failed(message: "Load chapters failed: \(error.localizedDescription)")
        }
    }

    public func selectChapter(_ chapter: TOCItem) {
    }
}