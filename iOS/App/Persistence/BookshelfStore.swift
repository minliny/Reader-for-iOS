import Foundation
import ReaderAppSupport

public final class BookshelfStore: @unchecked Sendable {
    public static let shared = BookshelfStore()

    private let fileURL: URL
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("bookshelf.json")
    }

    public init(storageURL: URL) {
        fileURL = storageURL
    }

    public func loadItems() throws -> [BookshelfItem] {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([BookshelfItem].self, from: data)
    }

    public func saveItems(_ items: [BookshelfItem]) throws {
        lock.lock()
        defer { lock.unlock() }

        let data = try encoder.encode(items)
        try data.write(to: fileURL)
    }

    public func addOrUpdate(_ item: BookshelfItem) throws {
        var items = (try? loadItems()) ?? []
        if let index = items.firstIndex(where: { $0.bookURL == item.bookURL && $0.sourceID == item.sourceID }) {
            items[index] = item
        } else {
            items.append(item)
        }
        try saveItems(items)
    }

    public func remove(id: String) throws {
        var items = (try? loadItems()) ?? []
        items.removeAll { $0.id == id }
        try saveItems(items)
    }

    public func updateProgress(bookID: String, progress: Double, chapterTitle: String?, chapterURL: String?) throws {
        var items = (try? loadItems()) ?? []
        if let index = items.firstIndex(where: { $0.id == bookID }) {
            items[index].readingProgress = progress
            items[index].updatedAt = Date()
            if let title = chapterTitle {
                items[index].lastReadChapterTitle = title
            }
            if let url = chapterURL {
                items[index].lastReadChapterURL = url
            }
            try saveItems(items)
        }
    }

    public func find(bookURL: String, sourceID: String) throws -> BookshelfItem? {
        let items = (try? loadItems()) ?? []
        return items.first { $0.bookURL == bookURL && $0.sourceID == sourceID }
    }
}