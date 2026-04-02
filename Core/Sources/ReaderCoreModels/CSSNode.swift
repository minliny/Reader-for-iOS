import Foundation

/// CSS节点，用于表示HTML文档中的元素
public struct CSSNode: Sendable, Equatable {
    /// 节点类型
    public enum NodeType: Sendable, Equatable {
        case element
        case text
        case comment
        case document
    }
    
    /// 节点类型
    public let type: NodeType
    
    /// 标签名（仅element类型有效）
    public let tagName: String?
    
    /// 文本内容（仅text类型有效）
    public let textContent: String?
    
    /// 属性字典
    public let attributes: [String: String]
    
    /// 子节点
    public let children: [CSSNode]
    
    /// 父节点（值类型节点不保留父引用，避免递归存储）
    public var parent: CSSNode? { nil }
    
    /// 初始化方法
    public init(
        type: NodeType,
        tagName: String? = nil,
        textContent: String? = nil,
        attributes: [String: String] = [:],
        children: [CSSNode] = []
    ) {
        self.type = type
        self.tagName = tagName
        self.textContent = textContent
        self.attributes = attributes
        self.children = children
        
    }
    
    /// 获取innerHTML
    public var innerHTML: String {
        var result = ""
        for child in children {
            result += child.outerHTML
        }
        return result
    }
    
    /// 获取outerHTML
    public var outerHTML: String {
        switch type {
        case .element:
            guard let tagName = tagName else { return "" }
            var attrs = ""
            for (key, value) in attributes {
                attrs += " \(key)=\"\(value)\""
            }
            return "<\(tagName)\(attrs)>\(innerHTML)</\(tagName)>"
        case .text:
            return textContent ?? ""
        case .comment:
            return "<!--\(textContent ?? "")-->"
        case .document:
            return innerHTML
        }
    }
    
    /// 获取innerText（递归合并所有文本节点）
    public var innerText: String {
        switch type {
        case .element:
            var result = ""
            for child in children {
                result += child.innerText
            }
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        case .text:
            return textContent ?? ""
        case .comment:
            return ""
        case .document:
            var result = ""
            for child in children {
                result += child.innerText
            }
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    /// 获取属性值
    public func attribute(_ name: String) -> String? {
        return attributes[name.lowercased()]
    }
    
    /// 获取href属性
    public var href: String? {
        return attribute("href")
    }
    
    /// 获取src属性
    public var src: String? {
        return attribute("src")
    }
    
    /// 获取alt属性
    public var alt: String? {
        return attribute("alt")
    }
    
    /// 获取class属性
    public var className: String? {
        return attribute("class")
    }
    
    /// 获取id属性
    public var id: String? {
        return attribute("id")
    }
    
    /// 检查是否包含指定class
    public func hasClass(_ className: String) -> Bool {
        guard let classNames = self.className else { return false }
        let classes = classNames.split(separator: " ").map(String.init)
        return classes.contains(className)
    }
}
