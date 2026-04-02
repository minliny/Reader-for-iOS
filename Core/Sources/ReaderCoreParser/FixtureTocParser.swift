import Foundation
import ReaderCoreProtocols

protocol FixtureTocRuleExecuting: Sendable {
    func execute(_ rule: String, from html: String) throws -> [String]
}

extension CSSExecutor: FixtureTocRuleExecuting {}

public final class FixtureTocParser: Sendable {
    private let cssExecutor: any FixtureTocRuleExecuting
    
    public init() {
        self.cssExecutor = CSSExecutor()
    }

    init(cssExecutor: any FixtureTocRuleExecuting) {
        self.cssExecutor = cssExecutor
    }
    
    public func parse(
        html: String,
        titleRule: String,
        urlRule: String,
        baseURL: String?
    ) throws -> [FixtureTocItem] {
        let titles = try executeFixtureRule(titleRule, from: html)
        let urls = try executeFixtureRule(urlRule, from: html)
        
        // Fixture contract is result-driven: any empty side or count mismatch is treated as miss.
        guard !titles.isEmpty, !urls.isEmpty, titles.count == urls.count else {
            return []
        }
        
        var items: [FixtureTocItem] = []
        
        for (title, url) in zip(titles, urls) {
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
}
