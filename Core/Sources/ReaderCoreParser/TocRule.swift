import Foundation
import ReaderCoreModels

/// TOC解析规则结构体
/// 与BookSource中的ruleToc字段格式对齐
public struct TocRule: Codable, Sendable, Equatable {
    /// 章节列表容器选择器
    public let chapterList: String?
    
    /// 章节标题提取规则
    public let chapterName: String
    
    /// 章节URL提取规则
    public let chapterUrl: String
    
    /// 下一页URL提取规则（可选）
    public let nextTocUrl: String?
    
    public init(
        chapterList: String? = nil,
        chapterName: String,
        chapterUrl: String,
        nextTocUrl: String? = nil
    ) {
        self.chapterList = chapterList
        self.chapterName = chapterName
        self.chapterUrl = chapterUrl
        self.nextTocUrl = nextTocUrl
    }
    
    /// 兼容旧格式：单个规则字符串
    public init(ruleString: String) throws {
        let parts = ruleString.split(separator: "|", maxSplits: 1)
        guard parts.count == 2 else {
            throw ParserError.invalidRuleFormat
        }
        
        self.chapterList = nil
        self.chapterName = String(parts[0])
        self.chapterUrl = String(parts[1])
        self.nextTocUrl = nil
    }
}

/// TOC解析错误类型
public enum ParserError: Error, Equatable {
    case invalidRuleFormat
    case ruleExecutionFailed(String)
    case noResultsFound
    case htmlParsingFailed
}

extension ParserError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidRuleFormat:
            return NSLocalizedString("无效的规则格式", comment: "")
        case .ruleExecutionFailed(let message):
            return NSLocalizedString("规则执行失败: \(message)", comment: "")
        case .noResultsFound:
            return NSLocalizedString("未找到匹配结果", comment: "")
        case .htmlParsingFailed:
            return NSLocalizedString("HTML解析失败", comment: "")
        }
    }
}