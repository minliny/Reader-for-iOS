import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

/// TOC解析器协议
public protocol TocParser: Sendable {
    /// 解析HTML获取TOC章节列表
    /// - Parameters:
    ///   - html: 要解析的HTML内容
    ///   - rule: TOC解析规则
    ///   - baseURL: 基础URL（用于相对路径转换）
    /// - Returns: TOC章节列表
    /// - Throws: 解析错误
    func parse(
        html: String,
        rule: TocRule,
        baseURL: String?
    ) throws -> [TocItem]
    
    /// 仅解析章节标题
    /// - Parameters:
    ///   - html: 要解析的HTML内容
    ///   - titleRule: 标题提取规则
    /// - Returns: 章节标题列表
    /// - Throws: 解析错误
    func parseTitles(
        html: String,
        titleRule: String
    ) throws -> [String]
    
    /// 解析章节标题和URL
    /// - Parameters:
    ///   - html: 要解析的HTML内容
    ///   - titleRule: 标题提取规则
    ///   - urlRule: URL提取规则
    ///   - baseURL: 基础URL（用于相对路径转换）
    /// - Returns: TOC章节列表
    /// - Throws: 解析错误
    func parseTitlesAndURLs(
        html: String,
        titleRule: String,
        urlRule: String,
        baseURL: String?
    ) throws -> [TocItem]
}

/// 默认TOC解析器实现
public final class DefaultTocParser: TocParser {
    private let scheduler: RuleScheduler
    
    public init(scheduler: RuleScheduler = NonJSRuleScheduler()) {
        self.scheduler = scheduler
    }
    
    public func parse(
        html: String,
        rule: TocRule,
        baseURL: String? = nil
    ) throws -> [TocItem] {
        let htmlData = Data(html.utf8)
        
        // 如果有章节列表容器规则，先缩小范围
        let targetHtml: String
        if let chapterListRule = rule.chapterList {
            let results = try scheduler.evaluate(
                rule: chapterListRule,
                data: htmlData,
                flow: .toc,
                source: BookSource.empty
            )
            targetHtml = results.first ?? html
        } else {
            targetHtml = html
        }
        
        // 解析标题
        let titles = try scheduler.evaluate(
            rule: rule.chapterName,
            data: Data(targetHtml.utf8),
            flow: .toc,
            source: BookSource.empty
        )
        
        // 解析URL
        let urls = try scheduler.evaluate(
            rule: rule.chapterUrl,
            data: Data(targetHtml.utf8),
            flow: .toc,
            source: BookSource.empty
        )
        
        // 生成TocItem
        var items: [TocItem] = []
        let maxCount = max(titles.count, urls.count)
        
        for index in 0..<maxCount {
            let title = index < titles.count ? titles[index] : "未知章节\(index + 1)"
            let url = index < urls.count ? urls[index] : "#"
            
            var item = TocItem(title: title, url: url, index: index)
            
            // 相对URL转绝对URL
            item = item.absoluteURL(baseURL: baseURL)
            
            // 标题后处理
            let processedTitle = item.processedTitle()
            if processedTitle != item.chapterTitle {
                item = TocItem(
                    title: processedTitle,
                    url: item.chapterURL,
                    index: item.chapterIndex
                )
            }
            
            items.append(item)
        }
        
        return items
    }
    
    public func parseTitles(
        html: String,
        titleRule: String
    ) throws -> [String] {
        let data = Data(html.utf8)
        let results = try scheduler.evaluate(
            rule: titleRule,
            data: data,
            flow: .toc,
            source: BookSource.empty
        )
        
        // 标题后处理
        return results.map { title in
            let tempItem = TocItem(title: title, url: "#", index: 0)
            return tempItem.processedTitle()
        }
    }
    
    public func parseTitlesAndURLs(
        html: String,
        titleRule: String,
        urlRule: String,
        baseURL: String? = nil
    ) throws -> [TocItem] {
        let rule = TocRule(
            chapterName: titleRule,
            chapterUrl: urlRule
        )
        
        return try parse(html: html, rule: rule, baseURL: baseURL)
    }
}

extension BookSource {
    /// 空书源（仅用于RuleScheduler调用）
    static var empty: BookSource {
        BookSource(
            bookSourceName: "",
            bookSourceUrl: ""
        )
    }
}