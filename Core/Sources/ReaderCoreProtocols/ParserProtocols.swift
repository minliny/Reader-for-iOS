import Foundation
import ReaderCoreModels

public enum ParseFlow: String, Sendable, Codable {
    case search
    case toc
    case content
}

public struct ParseRuleSet: Sendable, Equatable {
    public var searchRule: String?
    public var bookInfoRule: String?
    public var tocRule: String?
    public var contentRule: String?

    public init(searchRule: String? = nil, bookInfoRule: String? = nil, tocRule: String? = nil, contentRule: String? = nil) {
        self.searchRule = searchRule
        self.bookInfoRule = bookInfoRule
        self.tocRule = tocRule
        self.contentRule = contentRule
    }
}

public protocol RuleScheduler: Sendable {
    func evaluate(rule: String, data: Data, flow: ParseFlow, source: BookSource) throws -> [String]
}

public protocol SearchParser: Sendable {
    func parseSearchResponse(_ data: Data, source: BookSource, query: SearchQuery) throws -> [SearchResultItem]
}

public protocol TOCParser: Sendable {
    func parseTOCResponse(_ data: Data, source: BookSource, detailURL: String) throws -> [TOCItem]
}

public protocol ContentParser: Sendable {
    func parseContentResponse(_ data: Data, source: BookSource, chapterURL: String) throws -> ContentPage
}
