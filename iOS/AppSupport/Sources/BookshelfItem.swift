import Foundation
import ReaderCoreModels

public struct BookshelfItem: Codable, Identifiable, Equatable {
    public let id: String
    public let sourceID: String
    public let sourceName: String?
    public let bookURL: String
    public let title: String
    public let author: String?
    public let coverURL: String?
    public let latestChapter: String?
    public let addedAt: Date
    public var updatedAt: Date
    public var lastReadChapterTitle: String?
    public var lastReadChapterURL: String?
    /// Persisted zero-based chapter index. `nil` identifies legacy records;
    /// callers use `resolvedLastReadChapterIndex` for the explicit v1 fallback.
    public var lastReadChapterIndex: Int?
    public var readingProgress: Double
    public var localChapterList: [TOCItem]?

    public var resolvedLastReadChapterIndex: Int {
        max(0, lastReadChapterIndex ?? 0)
    }

    public init(
        id: String = UUID().uuidString,
        sourceID: String,
        sourceName: String? = nil,
        bookURL: String,
        title: String,
        author: String? = nil,
        coverURL: String? = nil,
        latestChapter: String? = nil,
        addedAt: Date = Date(),
        updatedAt: Date = Date(),
        lastReadChapterTitle: String? = nil,
        lastReadChapterURL: String? = nil,
        lastReadChapterIndex: Int? = nil,
        readingProgress: Double = 0.0,
        localChapterList: [TOCItem]? = nil
    ) {
        self.id = id
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.bookURL = bookURL
        self.title = title
        self.author = author
        self.coverURL = coverURL
        self.latestChapter = latestChapter
        self.addedAt = addedAt
        self.updatedAt = updatedAt
        self.lastReadChapterTitle = lastReadChapterTitle
        self.lastReadChapterURL = lastReadChapterURL
        self.lastReadChapterIndex = lastReadChapterIndex.map { max(0, $0) }
        self.readingProgress = readingProgress
        self.localChapterList = localChapterList
    }
}
