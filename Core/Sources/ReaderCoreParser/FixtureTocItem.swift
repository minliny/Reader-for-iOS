import Foundation

public struct FixtureTocItem: Sendable, Equatable {
    public let title: String
    public let url: String
    
    public init(title: String, url: String) {
        self.title = title
        self.url = url
    }
    
    public func absoluteURL(baseURL: String?) -> FixtureTocItem {
        guard let baseURL = baseURL else {
            return self
        }
        
        guard let base = URL(string: baseURL),
              let relativeURL = URL(string: url, relativeTo: base),
              let absoluteURL = relativeURL.absoluteString.removingPercentEncoding
        else {
            return self
        }
        
        return FixtureTocItem(title: title, url: absoluteURL)
    }
    
    public func processedTitle() -> String {
        var processed = title
        
        let prefixes = ["正文卷.", "正文.", "VIP卷.", "默认卷.", "卷_", "VIP章节.", "免费章节.", "章节目录.", "最新章节."]
        for prefix in prefixes {
            if processed.hasPrefix(prefix) {
                processed = String(processed.dropFirst(prefix.count))
                break
            }
        }
        
        processed = processed.replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
        processed = processed.replacingOccurrences(of: "（[^）]*）", with: "", options: .regularExpression)
        processed = processed.replacingOccurrences(of: "\\[[^\\]]*\\]", with: "", options: .regularExpression)
        processed = processed.replacingOccurrences(of: "【[^】]*】", with: "", options: .regularExpression)
        
        processed = processed.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return processed.isEmpty ? "未知章节" : processed
    }
}
