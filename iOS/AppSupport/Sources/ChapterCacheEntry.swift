import Foundation

public enum ChapterCacheStatus: String, Codable {
    case notCached
    case cached
    case failed
}

public struct ChapterCacheEntry: Codable, Equatable {
    public let sourceID: String
    public let bookURL: String
    public let chapterURL: String
    public let chapterTitle: String
    public let cachedAt: Date
    public var status: ChapterCacheStatus

    public init(
        sourceID: String,
        bookURL: String,
        chapterURL: String,
        chapterTitle: String,
        cachedAt: Date = Date(),
        status: ChapterCacheStatus = .notCached
    ) {
        self.sourceID = sourceID
        self.bookURL = bookURL
        self.chapterURL = chapterURL
        self.chapterTitle = chapterTitle
        self.cachedAt = cachedAt
        self.status = status
    }
}