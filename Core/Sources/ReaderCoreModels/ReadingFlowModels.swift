import Foundation
import ReaderCoreFoundation

public struct SearchQuery: Sendable, Equatable, Codable {
    public var keyword: String
    public var page: Int
    public var pageSize: Int?

    public init(keyword: String, page: Int = 1, pageSize: Int? = nil) {
        self.keyword = keyword
        self.page = page
        self.pageSize = pageSize
    }
}

public struct SearchResultItem: Codable, Sendable, Equatable {
    public var title: String
    public var detailURL: String
    public var author: String?
    public var coverURL: String?
    public var intro: String?
    public var unknownFields: [String: JSONValue]

    public init(
        title: String,
        detailURL: String,
        author: String? = nil,
        coverURL: String? = nil,
        intro: String? = nil,
        unknownFields: [String: JSONValue] = [:]
    ) {
        self.title = title
        self.detailURL = detailURL
        self.author = author
        self.coverURL = coverURL
        self.intro = intro
        self.unknownFields = unknownFields
    }
}

public struct TOCItem: Codable, Sendable, Equatable {
    public var chapterTitle: String
    public var chapterURL: String
    public var chapterIndex: Int
    public var isVip: Bool
    public var unknownFields: [String: JSONValue]

    public init(
        chapterTitle: String,
        chapterURL: String,
        chapterIndex: Int,
        isVip: Bool = false,
        unknownFields: [String: JSONValue] = [:]
    ) {
        self.chapterTitle = chapterTitle
        self.chapterURL = chapterURL
        self.chapterIndex = chapterIndex
        self.isVip = isVip
        self.unknownFields = unknownFields
    }
}

public struct ContentPage: Codable, Sendable, Equatable {
    public var title: String
    public var content: String
    public var chapterURL: String
    public var nextChapterURL: String?
    public var unknownFields: [String: JSONValue]

    public init(
        title: String,
        content: String,
        chapterURL: String,
        nextChapterURL: String? = nil,
        unknownFields: [String: JSONValue] = [:]
    ) {
        self.title = title
        self.content = content
        self.chapterURL = chapterURL
        self.nextChapterURL = nextChapterURL
        self.unknownFields = unknownFields
    }
}
