import Foundation
import ReaderCoreModels
import ReaderAppSupport
import ReaderAppPersistence
import ReaderShellValidation

public enum BookshelfState: Equatable {
    case idle
    case loading
    case loaded(items: [BookshelfItem])
    case empty
    case failed(message: String)

    public static func == (lhs: BookshelfState, rhs: BookshelfState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.loading, .loading):
            return true
        case (.loaded(let a), .loaded(let b)):
            return a.count == b.count && a.allSatisfy { item in
                b.contains { $0.id == item.id }
            }
        case (.empty, .empty):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

@MainActor
public final class BookshelfViewModel: ObservableObject {
    @Published public var bookshelfState: BookshelfState = .idle
    @Published public var items: [BookshelfItem] = []

    private let store: BookshelfStore

    public init(store: BookshelfStore = .shared) {
        self.store = store
    }

    public func loadItems() async {
        bookshelfState = .loading

        do {
            let loadedItems = try store.loadItems()
            if loadedItems.isEmpty {
                items = []
                bookshelfState = .empty
            } else {
                items = loadedItems.sorted { $0.updatedAt > $1.updatedAt }
                bookshelfState = .loaded(items: items)
            }
        } catch {
            bookshelfState = .failed(message: "Failed to load bookshelf: \(error.localizedDescription)")
        }
    }

    public func removeItem(id: String) async {
        do {
            try store.remove(id: id)
            await loadItems()
        } catch {
            bookshelfState = .failed(message: "Failed to remove item: \(error.localizedDescription)")
        }
    }

    public func addOrUpdateItem(from result: SearchResultItem, sourceID: String, sourceName: String? = nil) async {
        do {
            let existingItem = try store.find(bookURL: result.detailURL, sourceID: sourceID)
            let item = BookshelfItemFactory.makeOrUpdate(
                from: result,
                sourceID: sourceID,
                sourceName: sourceName,
                existing: existingItem
            )
            try store.addOrUpdate(item)
            await loadItems()
        } catch {
            bookshelfState = .failed(message: "Failed to add to bookshelf: \(error.localizedDescription)")
        }
    }

    public func addOrUpdateLocalBook(_ book: LocalBook) async {
        do {
            let existingItem = try store.find(bookURL: book.filePath, sourceID: "local-book")
            let item = BookshelfItemFactory.makeOrUpdate(from: book, existing: existingItem)
            try store.addOrUpdate(item)
            await loadItems()
        } catch {
            bookshelfState = .failed(message: "Failed to add local book: \(error.localizedDescription)")
        }
    }

    public func addOrUpdateLocalBook(_ summary: CoreLocalBookImportSummary) async {
        do {
            let existingItem = try store.find(bookURL: summary.book.filePath, sourceID: "local-book")
            let item = BookshelfItemFactory.makeOrUpdate(
                from: summary.book,
                firstChapterTitle: summary.firstChapterTitle,
                firstChapterURL: summary.firstChapterURL,
                localChapterList: summary.cachedTOCItems,
                existing: existingItem
            )
            try store.addOrUpdate(item)
            await loadItems()
        } catch {
            bookshelfState = .failed(message: "Failed to add local book: \(error.localizedDescription)")
        }
    }

    public func isInBookshelf(bookURL: String, sourceID: String) -> Bool {
        return (try? store.find(bookURL: bookURL, sourceID: sourceID)) != nil
    }
}
