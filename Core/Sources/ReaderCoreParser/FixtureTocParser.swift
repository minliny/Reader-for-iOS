import Foundation
import ReaderCoreProtocols

protocol FixtureTocRuleExecuting: Sendable {
    func execute(_ rule: String, from html: String) throws -> [String]
}

extension CSSExecutor: FixtureTocRuleExecuting {}

public final class FixtureTocParser: Sendable {
    private let minimumChapterCount = 2
    private let cssExecutor: any FixtureTocRuleExecuting
    private let sampleId: String?
    private let tocLog: ((String) -> Void)?
    
    public init() {
        self.cssExecutor = CSSExecutor()
        self.sampleId = nil
        self.tocLog = nil
    }

    init(
        cssExecutor: any FixtureTocRuleExecuting,
        sampleId: String? = nil,
        tocLog: ((String) -> Void)? = nil
    ) {
        self.cssExecutor = cssExecutor
        self.sampleId = sampleId
        self.tocLog = tocLog
    }

    init(sampleId: String, tocLog: @escaping (String) -> Void) {
        self.cssExecutor = CSSExecutor(sampleId: sampleId, debugLog: tocLog)
        self.sampleId = sampleId
        self.tocLog = tocLog
    }
    
    public func parse(
        html: String,
        titleRule: String,
        urlRule: String,
        baseURL: String?,
        sampleId: String? = nil
    ) throws -> [FixtureTocItem] {
        let activeSampleId = sampleId ?? self.sampleId ?? "unknown"
        debug("TOC_START sample=\(activeSampleId)")
        defer { debug("TOC_END sample=\(activeSampleId)") }

        debug("RULE_STEP name=title_rule_execute sample=\(activeSampleId)")
        let titles = try executeFixtureRule(titleRule, from: html)
        debug("RULE_STEP name=url_rule_execute sample=\(activeSampleId)")
        let urls = try executeFixtureRule(urlRule, from: html)
        
        // Fixture contract is result-driven: any empty side, count mismatch,
        // or incidental singleton match is treated as miss instead of a TOC.
        guard !titles.isEmpty,
              !urls.isEmpty,
              titles.count == urls.count,
              titles.count >= minimumChapterCount
        else {
            return []
        }
        
        var items: [FixtureTocItem] = []
        
        var iteration = 0
        for (title, url) in zip(titles, urls) {
            iteration += 1
            debug("RULE_STEP name=zip sample=\(activeSampleId)")
            debug("LOOP_ITERATION count=\(iteration)")
            var item = FixtureTocItem(title: title, url: url)
            item = item.absoluteURL(baseURL: baseURL)
            
            let processedTitle = item.processedTitle()
            if processedTitle != item.title {
                item = FixtureTocItem(title: processedTitle, url: item.url)
            }
            
            items.append(item)
        }
        
        return items
    }

    private func executeFixtureRule(_ rule: String, from html: String) throws -> [String] {
        do {
            return try cssExecutor.execute(rule, from: html)
        } catch let error as CSSExecutorError {
            // Compatibility fallback only: contract should not rely on this branch.
            // In current real executor, selector miss is usually surfaced as an empty result.
            if case .selectorNotFound = error {
                return []
            }
            throw error
        }
    }

    private func debug(_ message: String) {
        tocLog?(message)
    }
}
