import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

public final class NonJSParserEngine: SearchParser, TOCParser, ContentParser {
    private let scheduler: RuleScheduler

    public init(scheduler: RuleScheduler = NonJSRuleScheduler()) {
        self.scheduler = scheduler
    }

    public func parseSearchResponse(_ data: Data, source: BookSource, query: SearchQuery) throws -> [SearchResultItem] {
        let lines = try scheduler.evaluate(rule: source.ruleSearch ?? "", data: data, flow: .search, source: source)
        let items = lines.enumerated().map { idx, line in
            let parts = line.split(separator: "|", maxSplits: 2).map(String.init)
            let title = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "item-\(idx)"
            let detailURL = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : title
            let author = parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespacesAndNewlines) : nil
            return SearchResultItem(title: title, detailURL: detailURL, author: author)
        }
        if items.isEmpty {
            throw flowError(type: .SEARCH_FAILED, reason: "empty_search_result", flow: .search, message: "Search parsing produced empty result.")
        }
        return items
    }

    public func parseTOCResponse(_ data: Data, source: BookSource, detailURL: String) throws -> [TOCItem] {
        let lines = try scheduler.evaluate(rule: source.ruleToc ?? "", data: data, flow: .toc, source: source)
        let items = lines.enumerated().map { idx, line in
            let parts = line.split(separator: "|", maxSplits: 1).map(String.init)
            let title = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "chapter-\(idx)"
            let chapterURL = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : title
            return TOCItem(chapterTitle: title, chapterURL: chapterURL, chapterIndex: idx)
        }
        if items.isEmpty {
            throw flowError(type: .TOC_FAILED, reason: "chapter_list_empty", flow: .toc, message: "TOC parsing produced empty chapter list.")
        }
        return items
    }

    public func parseContentResponse(_ data: Data, source: BookSource, chapterURL: String) throws -> ContentPage {
        let lines = try scheduler.evaluate(rule: source.ruleContent ?? "", data: data, flow: .content, source: source)
        let content = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if content.isEmpty {
            throw flowError(type: .CONTENT_FAILED, reason: "content_body_empty", flow: .content, message: "Content parsing produced empty body.")
        }
        return ContentPage(title: "正文", content: content, chapterURL: chapterURL)
    }
}

private extension NonJSParserEngine {
    func flowError(type: FailureType, reason: String, flow: ParseFlow, message: String) -> ReaderError {
        ReaderError(
            code: .parsingFailed,
            message: message,
            failure: FailureRecord(type: type, reason: reason),
            context: [
                "flow": flow.rawValue,
                "engine": "non_js"
            ]
        )
    }
}
