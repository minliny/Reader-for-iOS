import Foundation

public struct ReadingProgress: Codable, Equatable, Sendable {
    public let bookID: String
    public let sourceID: String
    public let bookURL: String
    public let chapterURL: String
    public let chapterTitle: String
    /// Zero-based chapter index used by the shared `book.open` transaction.
    /// Older persisted records decode this as `0`.
    public var chapterIndex: Int
    public var progressRatio: Double
    public var updatedAt: Date

    public init(
        bookID: String,
        sourceID: String,
        bookURL: String,
        chapterURL: String,
        chapterTitle: String,
        chapterIndex: Int = 0,
        progressRatio: Double = 0.0,
        updatedAt: Date = Date()
    ) {
        self.bookID = bookID
        self.sourceID = sourceID
        self.bookURL = bookURL
        self.chapterURL = chapterURL
        self.chapterTitle = chapterTitle
        self.chapterIndex = max(0, chapterIndex)
        self.progressRatio = progressRatio
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case bookID
        case sourceID
        case bookURL
        case chapterURL
        case chapterTitle
        case chapterIndex
        case progressRatio
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bookID = try container.decode(String.self, forKey: .bookID)
        sourceID = try container.decode(String.self, forKey: .sourceID)
        bookURL = try container.decode(String.self, forKey: .bookURL)
        chapterURL = try container.decode(String.self, forKey: .chapterURL)
        chapterTitle = try container.decode(String.self, forKey: .chapterTitle)
        chapterIndex = max(0, try container.decodeIfPresent(Int.self, forKey: .chapterIndex) ?? 0)
        progressRatio = try container.decode(Double.self, forKey: .progressRatio)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bookID, forKey: .bookID)
        try container.encode(sourceID, forKey: .sourceID)
        try container.encode(bookURL, forKey: .bookURL)
        try container.encode(chapterURL, forKey: .chapterURL)
        try container.encode(chapterTitle, forKey: .chapterTitle)
        try container.encode(chapterIndex, forKey: .chapterIndex)
        try container.encode(progressRatio, forKey: .progressRatio)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
