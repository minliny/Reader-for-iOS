import Foundation

/// M5-A: Reading History Store
/// Records reading events: when user opens a book, switches chapters, etc.
/// Not a sync/backup system — purely local append-log per book.
public struct ReadingHistoryEvent: Codable, Identifiable, Equatable {
    public let id: String
    public let bookId: String
    public let sourceId: String
    public let sourceName: String?
    public let title: String
    public let author: String?
    public let chapterURL: String
    public let chapterTitle: String
    public let progress: Double
    public let openedAt: Date
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
        openedAt: Date = Date(),
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
        self.openedAt = openedAt
        self.updatedAt = updatedAt
    }
}

public final class ReadingHistoryStore: @unchecked Sendable {
    public static let shared = ReadingHistoryStore()

    private let fileURL: URL
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("reading_history.json")
    }

    public init(storageURL: URL) {
        fileURL = storageURL
    }

    // MARK: - Save / Update

    /// Saves or updates the most recent reading event for a book.
    /// Multiple opens of the same book update the same record (keyed by bookId).
    public func saveHistoryEvent(_ event: ReadingHistoryEvent) throws {
        lock.lock()
        defer { lock.unlock() }

        var allEvents = try loadAllEventsLocked()
        // Replace existing event for same bookId if present
        if let index = allEvents.firstIndex(where: { $0.bookId == event.bookId }) {
            allEvents[index] = event
        } else {
            allEvents.append(event)
        }
        let data = try encoder.encode(allEvents)
        try data.write(to: fileURL)
    }

    /// Convenience: records that user opened a book/chapter.
    public func recordOpen(
        bookId: String,
        sourceId: String,
        sourceName: String?,
        title: String,
        author: String?,
        chapterURL: String,
        chapterTitle: String,
        progress: Double
    ) throws {
        let event = ReadingHistoryEvent(
            bookId: bookId,
            sourceId: sourceId,
            sourceName: sourceName,
            title: title,
            author: author,
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            progress: progress
        )
        try saveHistoryEvent(event)
    }

    // MARK: - Load

    /// Loads the most recent history event for a specific book.
    public func loadHistoryForBook(bookId: String) throws -> ReadingHistoryEvent? {
        let allEvents = try loadAll()
        return allEvents.first { $0.bookId == bookId }
    }

    /// Loads recent N history events, most recent first.
    public func loadRecentHistory(limit: Int = 20) throws -> [ReadingHistoryEvent] {
        let allEvents = try loadAll()
        return Array(allEvents.sorted { $0.openedAt > $1.openedAt }.prefix(limit))
    }

    /// Loads all history events for all books.
    public func loadAll() throws -> [ReadingHistoryEvent] {
        lock.lock()
        defer { lock.unlock() }
        return try loadAllEventsLocked()
    }

    // MARK: - Remove

    /// Removes all history for a book.
    public func removeHistoryForBook(bookId: String) throws {
        lock.lock()
        defer { lock.unlock() }

        var allEvents = try loadAllEventsLocked()
        allEvents.removeAll { $0.bookId == bookId }
        let data = try encoder.encode(allEvents)
        try data.write(to: fileURL)
    }

    // MARK: - Private

    private func loadAllEventsLocked() throws -> [ReadingHistoryEvent] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([ReadingHistoryEvent].self, from: data)
    }
}