import Foundation

/// M5-B: Bookmark Store
/// Stores user-added bookmarks for books.
/// Each bookmark is keyed by bookId + chapterURL + progress (rounded to 2 decimal places).
/// Duplicate bookmarks at the same position are prevented.
public struct Bookmark: Codable, Identifiable, Equatable {
    public let id: String
    public let bookId: String
    public let sourceId: String
    public let sourceName: String?
    public let title: String
    public let author: String?
    public let chapterURL: String
    public let chapterTitle: String
    public let progress: Double
    public let snippet: String?
    public let note: String?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        bookId: String,
        sourceId: String,
        sourceName: String? = nil,
        title: String,
        author: String? = nil,
        chapterURL: String,
        chapterTitle: String,
        progress: Double = 0.0,
        snippet: String? = nil,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.bookId = bookId
        self.sourceId = sourceId
        self.sourceName = sourceName
        self.title = title
        self.author = author
        self.chapterURL = chapterURL
        self.chapterTitle = chapterTitle
        self.progress = progress
        self.snippet = snippet
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Unique key used for deduplication: bookId + chapterURL + progress (rounded to 2dp)
    var deduplicationKey: String {
        let roundedProgress = (progress * 100).rounded() / 100
        return "\(bookId)::\(chapterURL)::\(roundedProgress)"
    }
}

public final class BookmarkStore: @unchecked Sendable {
    public static let shared = BookmarkStore()

    private let fileURL: URL
    private let lock = NSLock()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("bookmarks.json")
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    public init(storageURL: URL) {
        fileURL = storageURL
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    // MARK: - Add / Update

    /// Adds a bookmark. Returns early (success) if a bookmark at the same
    /// bookId + chapterURL + ~progress already exists.
    public func addBookmark(_ bookmark: Bookmark) throws {
        lock.lock()
        defer { lock.unlock() }

        var allBookmarks = try loadAllBookmarksLocked()
        let dedupKey = bookmark.deduplicationKey

        // Skip if duplicate at same position
        if allBookmarks.contains(where: { $0.deduplicationKey == dedupKey }) {
            return
        }

        allBookmarks.append(bookmark)
        let data = try encoder.encode(allBookmarks)
        try data.write(to: fileURL)
    }

    /// Convenience: creates bookmark from current reader state.
    public func addBookmarkNow(
        bookId: String,
        sourceId: String,
        sourceName: String?,
        title: String,
        author: String?,
        chapterURL: String,
        chapterTitle: String,
        progress: Double,
        snippet: String? = nil,
        note: String? = nil
    ) throws {
        let bookmark = Bookmark(
            bookId: bookId,
            sourceId: sourceId,
            sourceName: sourceName,
            title: title,
            author: author,
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            progress: progress,
            snippet: snippet,
            note: note
        )
        try addBookmark(bookmark)
    }

    // MARK: - Load

    /// Loads all bookmarks for a specific book.
    public func loadBookmarksForBook(bookId: String) throws -> [Bookmark] {
        let allBookmarks = try loadAll()
        return allBookmarks
            .filter { $0.bookId == bookId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Loads all bookmarks (no filter).
    public func loadAll() throws -> [Bookmark] {
        lock.lock()
        defer { lock.unlock() }
        return try loadAllBookmarksLocked()
    }

    // MARK: - Delete

    /// Deletes a bookmark by its id.
    public func deleteBookmark(id: String) throws {
        lock.lock()
        defer { lock.unlock() }

        var allBookmarks = try loadAllBookmarksLocked()
        allBookmarks.removeAll { $0.id == id }
        let data = try encoder.encode(allBookmarks)
        try data.write(to: fileURL)
    }

    /// Deletes all bookmarks for a specific book.
    public func deleteAllBookmarksForBook(bookId: String) throws {
        lock.lock()
        defer { lock.unlock() }

        var allBookmarks = try loadAllBookmarksLocked()
        allBookmarks.removeAll { $0.bookId == bookId }
        let data = try encoder.encode(allBookmarks)
        try data.write(to: fileURL)
    }

    // MARK: - Helpers

    /// Returns true if a bookmark already exists at the same position (dedup check).
    public func hasBookmarkAt(bookId: String, chapterURL: String, progress: Double) throws -> Bool {
        let allBookmarks = try loadAll()
        let key = "\(bookId)::\(chapterURL)::\((progress * 100).rounded() / 100)"
        return allBookmarks.contains { $0.deduplicationKey == key }
    }

    // MARK: - Private

    private func loadAllBookmarksLocked() throws -> [Bookmark] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([Bookmark].self, from: data)
    }
}