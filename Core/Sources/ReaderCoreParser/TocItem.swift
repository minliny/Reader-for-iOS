import Foundation
import ReaderCoreFoundation
import ReaderCoreModels

/// TOC章节项结构体
public struct TocItem: Codable, Sendable, Equatable, Identifiable {
    /// 章节ID（自动生成）
    public var id: String { chapterURL }
    
    /// 章节标题
    public let chapterTitle: String
    
    /// 章节URL
    public let chapterURL: String
    
    /// 章节索引
    public let chapterIndex: Int
    
    /// 是否为VIP章节
    public let isVip: Bool
    
    /// 未知字段（用于兼容扩展）
    public let unknownFields: [String: JSONValue]
    
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
    
    /// 简化初始化方法
    public init(
        title: String,
        url: String,
        index: Int
    ) {
        self.chapterTitle = title
        self.chapterURL = url
        self.chapterIndex = index
        self.isVip = false
        self.unknownFields = [:]
    }
    
    /// 相对URL转换为绝对URL
    public func absoluteURL(baseURL: String? = nil) -> TocItem {
        let trimmedURL = chapterURL.trimmingCharacters(in: .whitespacesAndNewlines)

        // Only explicit relative paths should be resolved against a provided base URL.
        guard let baseURL,
              shouldResolveRelativeURL(trimmedURL),
              let base = URL(string: baseURL),
              let relativeURL = URL(string: chapterURL, relativeTo: base),
              let absoluteURL = relativeURL.absoluteString.removingPercentEncoding
        else {
            return self
        }
        
        return TocItem(
            chapterTitle: chapterTitle,
            chapterURL: absoluteURL,
            chapterIndex: chapterIndex,
            isVip: isVip,
            unknownFields: unknownFields
        )
    }

    private func shouldResolveRelativeURL(_ rawURL: String) -> Bool {
        guard !rawURL.isEmpty, rawURL != "#" else {
            return false
        }

        if let components = URLComponents(string: rawURL),
           components.scheme != nil || components.host != nil {
            return false
        }

        return rawURL.hasPrefix("/") ||
            rawURL.hasPrefix("./") ||
            rawURL.hasPrefix("../") ||
            rawURL.hasPrefix("?") ||
            rawURL.contains("/") ||
            rawURL.contains(".")
    }
    
    /// 标题后处理
    public func processedTitle() -> String {
        var processed = chapterTitle
        
        // 移除常见的标题前缀
        let prefixes = ["正文卷.", "正文.", "VIP卷.", "默认卷.", "卷_", "VIP章节.", "免费章节.", "章节目录.", "最新章节."]
        for prefix in prefixes {
            if processed.hasPrefix(prefix) {
                processed = String(processed.dropFirst(prefix.count))
                break
            }
        }
        
        // 移除括号内的内容
        processed = processed.replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
        processed = processed.replacingOccurrences(of: "（[^）]*）", with: "", options: .regularExpression)
        processed = processed.replacingOccurrences(of: "\\[[^\\]]*\\]", with: "", options: .regularExpression)
        processed = processed.replacingOccurrences(of: "【[^】]*】", with: "", options: .regularExpression)
        
        // 去除多余空格
        processed = processed.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return processed.isEmpty ? "未知章节" : processed
    }
}
