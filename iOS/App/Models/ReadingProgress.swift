import Foundation

public struct ReadingProgress: Codable, Equatable {
    public let bookID: String
    public let sourceID: String
    public let bookURL: String
    public let chapterURL: String
    public let chapterTitle: String
    public var progressRatio: Double
    public var updatedAt: Date

    public init(
        bookID: String,
        sourceID: String,
        bookURL: String,
        chapterURL: String,
        chapterTitle: String,
        progressRatio: Double = 0.0,
        updatedAt: Date = Date()
    ) {
        self.bookID = bookID
        self.sourceID = sourceID
        self.bookURL = bookURL
        self.chapterURL = chapterURL
        self.chapterTitle = chapterTitle
        self.progressRatio = progressRatio
        self.updatedAt = updatedAt
    }
}