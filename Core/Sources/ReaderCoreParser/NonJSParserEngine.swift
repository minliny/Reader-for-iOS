import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

public final class NonJSParserEngine: SearchParser, TOCParser, ContentParser {
    private let scheduler: RuleScheduler
    private let jsGate: JSRenderingGate

    public convenience init(scheduler: RuleScheduler = NonJSRuleScheduler()) {
        self.init(scheduler: scheduler, jsGate: NullJSRenderingGate.shared)
    }

    public init(scheduler: RuleScheduler = NonJSRuleScheduler(), jsGate: JSRenderingGate) {
        self.scheduler = scheduler
        self.jsGate    = jsGate
    }

    public func parseSearchResponse(_ data: Data, source: BookSource, query: SearchQuery) throws -> [SearchResultItem] {
        let rule = source.ruleSearch ?? ""
        let (effectiveData, effectiveRule) = applyJSPreprocessing(data: data, rule: rule)
        let lines = try scheduler.evaluate(rule: effectiveRule, data: effectiveData, flow: .search, source: source)
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
        let rule = source.ruleToc ?? ""
        let (effectiveData, effectiveRule) = applyJSPreprocessing(data: data, rule: rule)
        let lines = try scheduler.evaluate(rule: effectiveRule, data: effectiveData, flow: .toc, source: source)
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
        let rule = source.ruleContent ?? ""
        let (effectiveData, effectiveRule) = applyJSPreprocessing(data: data, rule: rule)
        let lines = try scheduler.evaluate(rule: effectiveRule, data: effectiveData, flow: .content, source: source)
        let content = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if content.isEmpty {
            throw flowError(type: .CONTENT_FAILED, reason: "content_body_empty", flow: .content, message: "Content parsing produced empty body.")
        }
        return ContentPage(title: "正文", content: content, chapterURL: chapterURL)
    }
}

// MARK: - @js: Preprocessor

private extension NonJSParserEngine {

    /// If `rule` starts with `"@js:"`, run the embedded JS snippet against the raw HTML
    /// and return the post-execution HTML paired with the remaining rule suffix.
    ///
    /// Rule format:  `@js:<jsCode>|<remainingRule>`
    ///
    /// - The JS snippet is everything between `"@js:"` and the first `"|"`.
    /// - The remaining rule is everything after that `"|"` and is forwarded to the scheduler.
    /// - If there is no `"|"`, the remaining rule is the original rule (scheduler decides what to do).
    /// - If the gate returns empty HTML, the original data is used as fallback.
    func applyJSPreprocessing(data: Data, rule: String) -> (data: Data, rule: String) {
        guard rule.hasPrefix("@js:") else { return (data, rule) }

        let body = String(rule.dropFirst(4))           // everything after "@js:"
        let pipeRange = body.range(of: "|")

        let jsCode: String
        let remainingRule: String

        if let r = pipeRange {
            jsCode        = String(body[body.startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            remainingRule = String(body[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            jsCode        = body.trimmingCharacters(in: .whitespacesAndNewlines)
            remainingRule = rule   // pass original rule; scheduler will handle or reject
        }

        let rawHTML       = String(data: data, encoding: .utf8) ?? ""
        let processedHTML = jsGate.execute(html: rawHTML, evalScript: jsCode.isEmpty ? nil : jsCode)

        // If the gate produced empty HTML (unlikely but guard against it), fall back.
        guard !processedHTML.isEmpty else { return (data, remainingRule) }

        let processedData = processedHTML.data(using: .utf8) ?? data
        return (processedData, remainingRule)
    }
}

// MARK: - Error helper

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
