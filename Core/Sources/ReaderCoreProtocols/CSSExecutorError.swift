import Foundation

/// CSSExecutor错误类型
public enum CSSExecutorError: Error, Equatable, Sendable {
    /// 无效的CSS选择器
    case invalidSelector(String)
    
    /// HTML解析失败
    case htmlParsingFailed
    
    /// 选择器未匹配到任何元素
    case selectorNotFound(String)
    
    /// 不支持的选择器语法
    case unsupportedSelectorSyntax(String)
    
    /// 属性未找到
    case attributeNotFound(String)
}

extension CSSExecutorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidSelector(let selector):
            return NSLocalizedString("无效的CSS选择器: \(selector)", comment: "")
        case .htmlParsingFailed:
            return NSLocalizedString("HTML解析失败", comment: "")
        case .selectorNotFound(let selector):
            return NSLocalizedString("选择器未匹配到任何元素: \(selector)", comment: "")
        case .unsupportedSelectorSyntax(let syntax):
            return NSLocalizedString("不支持的选择器语法: \(syntax)", comment: "")
        case .attributeNotFound(let attr):
            return NSLocalizedString("属性未找到: \(attr)", comment: "")
        }
    }
}
