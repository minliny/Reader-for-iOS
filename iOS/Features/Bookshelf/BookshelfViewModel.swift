import Foundation
import ReaderCoreModels
import ReaderAppSupport
import ReaderAppPersistence
import ReaderShellValidation
#if canImport(ReaderCoreNativeAdapter)
import ReaderCoreNativeAdapter
#endif

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

    public init(store: BookshelfStore = .shared, initialState: BookshelfState? = nil) {
        self.store = store
        if let initialState {
            bookshelfState = initialState
            if case .loaded(let items) = initialState {
                self.items = items
            }
        }
    }

    public func loadItems() async {
        bookshelfState = .loading

        // C2: Try Core `bookshelf.list` first; fall back to BookshelfStore when
        // the Core bridge is unavailable or returns no items.
        if let coreItems = await loadItemsViaCore(), !coreItems.isEmpty {
            items = coreItems.sorted { $0.updatedAt > $1.updatedAt }
            bookshelfState = .loaded(items: items)
            return
        }

        do {
            let loadedItems = try store.loadItems()
            if loadedItems.isEmpty {
                #if DEBUG
                items = DemoBookshelfFixture.items
                bookshelfState = .loaded(items: items)
                #else
                items = []
                bookshelfState = .empty
                #endif
            } else {
                items = loadedItems.sorted { $0.updatedAt > $1.updatedAt }
                bookshelfState = .loaded(items: items)
            }
        } catch {
            bookshelfState = .failed(message: "Failed to load bookshelf: \(error.localizedDescription)")
        }
    }

    public func removeItem(id: String) async {
        // C2: Try Core `bookshelf.remove` first; fall back to BookshelfStore.
        // Core expects `bookId` (the bookURL), not the local UUID id.
        let bookURL = items.first { $0.id == id }?.bookURL
        if let bookURL = bookURL, await removeViaCore(bookURL: bookURL) {
            await loadItems()
            return
        }
        do {
            try store.remove(id: id)
            await loadItems()
        } catch {
            bookshelfState = .failed(message: "Failed to remove item: \(error.localizedDescription)")
        }
    }

    public func addOrUpdateItem(from result: SearchResultItem, sourceID: String, sourceName: String? = nil) async {
        let existingItem = try? store.find(bookURL: result.detailURL, sourceID: sourceID)
        let item = BookshelfItemFactory.makeOrUpdate(
            from: result,
            sourceID: sourceID,
            sourceName: sourceName,
            existing: existingItem
        )
        // C2: Try Core `bookshelf.add` first; fall back to BookshelfStore when
        // the Core bridge is unavailable or the call fails.
        if await addOrUpdateViaCore(item) {
            await loadItems()
            return
        }
        do {
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

    // MARK: - Core Bridge (C2)

    /// Attempt to load bookshelf items from Core via `bookshelf.list`.
    /// Returns parsed `[BookshelfItem]` on success, `nil` when the Core bridge
    /// is unavailable or the call fails (caller should fall back to local store).
    private func loadItemsViaCore() async -> [BookshelfItem]? {
        #if canImport(ReaderCoreNativeAdapter)
        guard let runtime = RustCoreRuntimeHolder.shared.current else { return nil }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let requestId = UInt64.random(in: 1...UInt64.max)
                do {
                    let event = try runtime.request(
                        method: "bookshelf.list",
                        requestId: requestId,
                        params: [:],
                        timeout: 10
                    )
                    guard event.type == "result",
                          let data = event.data,
                          let books = data["books"] as? [[String: Any]] else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let items = books.compactMap { Self.parseBookshelfItem($0) }
                    continuation.resume(returning: items)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
        #else
        return nil
        #endif
    }

    /// Attempt to add (or update) a book on the Core shelf via `bookshelf.add`.
    /// Returns `true` on success, `false` when the Core bridge is unavailable
    /// or the call fails (caller should fall back to local store).
    private func addOrUpdateViaCore(_ item: BookshelfItem) async -> Bool {
        #if canImport(ReaderCoreNativeAdapter)
        guard let runtime = RustCoreRuntimeHolder.shared.current else { return false }
        let params: [String: Any] = [
            "book": [
                "bookId": item.bookURL,
                "title": item.title,
                "author": item.author ?? "",
                "coverUrl": item.coverURL ?? "",
                "intro": "",
                "origin": item.sourceName ?? "",
            ]
        ]
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let requestId = UInt64.random(in: 1...UInt64.max)
                do {
                    let event = try runtime.request(
                        method: "bookshelf.add",
                        requestId: requestId,
                        params: params,
                        timeout: 10
                    )
                    continuation.resume(returning: event.type == "result")
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
        #else
        return false
        #endif
    }

    /// Attempt to remove a book from the Core shelf via `bookshelf.remove`.
    /// Returns `true` on success, `false` when the Core bridge is unavailable
    /// or the call fails (caller should fall back to local store).
    private func removeViaCore(bookURL: String) async -> Bool {
        #if canImport(ReaderCoreNativeAdapter)
        guard let runtime = RustCoreRuntimeHolder.shared.current else { return false }
        let params: [String: Any] = ["bookId": bookURL]
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let requestId = UInt64.random(in: 1...UInt64.max)
                do {
                    let event = try runtime.request(
                        method: "bookshelf.remove",
                        requestId: requestId,
                        params: params,
                        timeout: 10
                    )
                    continuation.resume(returning: event.type == "result")
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
        #else
        return false
        #endif
    }

    /// Parse a Core `bookshelf.list` entry into a `BookshelfItem`.
    /// Field names mirror the `bookshelf.add` / `bookshelf.list` contract:
    /// `bookId` is the key, `title`/`author`/`coverUrl`/`origin` are metadata.
    private static func parseBookshelfItem(_ obj: [String: Any]) -> BookshelfItem? {
        guard let bookId = obj["bookId"] as? String,
              let title = obj["title"] as? String else { return nil }
        return BookshelfItem(
            id: bookId,
            sourceID: (obj["origin"] as? String) ?? "core",
            sourceName: obj["origin"] as? String,
            bookURL: bookId,
            title: title,
            author: obj["author"] as? String,
            coverURL: obj["coverUrl"] as? String
        )
    }
}
