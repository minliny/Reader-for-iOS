import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

/// CSS执行器，用于执行CSS选择器并提取内容
public final class CSSExecutor: Sendable {
    private let parser = HTMLParser()
    
    public init() {}
    
    /// 执行完整的CSS规则（包含选择器和属性提取）
    public func execute(_ rule: String, from html: String) throws -> [String] {
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.hasSuffix("@text") {
            let selector = String(trimmed.dropLast(5)).trimmingCharacters(in: .whitespaces)
            return try extractText(selector, from: html)
        } else if trimmed.hasSuffix("@html") {
            let selector = String(trimmed.dropLast(5)).trimmingCharacters(in: .whitespaces)
            return try extractHTML(selector, from: html)
        } else if trimmed.hasSuffix("@href") {
            let selector = String(trimmed.dropLast(5)).trimmingCharacters(in: .whitespaces)
            return try extractHref(selector, from: html)
        } else if trimmed.hasSuffix("@src") {
            let selector = String(trimmed.dropLast(4)).trimmingCharacters(in: .whitespaces)
            return try extractSrc(selector, from: html)
        } else if trimmed.hasSuffix("@alt") {
            let selector = String(trimmed.dropLast(4)).trimmingCharacters(in: .whitespaces)
            return try extractAlt(selector, from: html)
        }
        
        return try extractText(trimmed, from: html)
    }
    
    /// 执行CSS选择器并返回匹配的节点
    public func select(_ selector: String, from html: String) throws -> [CSSNode] {
        let document = try parser.parse(html)
        return try select(selector, from: document)
    }
    
    /// 执行CSS选择器并返回匹配的节点（从指定节点开始）
    public func select(_ selector: String, from node: CSSNode) throws -> [CSSNode] {
        let parts = selector.components(separatedBy: ">").map { $0.trimmingCharacters(in: .whitespaces) }
        var currentNodes = [node]
        
        for part in parts {
            if part.isEmpty { continue }
            currentNodes = currentNodes.flatMap { applySelectorPart(part, to: $0) }
        }
        
        return currentNodes
    }
    
    /// 提取文本内容
    public func extractText(_ selector: String, from html: String) throws -> [String] {
        let nodes = try select(selector, from: html)
        return nodes.map { $0.innerText }
    }
    
    /// 提取HTML内容
    public func extractHTML(_ selector: String, from html: String) throws -> [String] {
        let nodes = try select(selector, from: html)
        return nodes.map { $0.innerHTML }
    }
    
    /// 提取属性值
    public func extractAttribute(_ attribute: String, from selector: String, html: String) throws -> [String] {
        let nodes = try select(selector, from: html)
        return nodes.compactMap { $0.attribute(attribute) }
    }
    
    /// 提取href属性
    public func extractHref(_ selector: String, from html: String) throws -> [String] {
        return try extractAttribute("href", from: selector, html: html)
    }
    
    /// 提取src属性
    public func extractSrc(_ selector: String, from html: String) throws -> [String] {
        return try extractAttribute("src", from: selector, html: html)
    }
    
    /// 提取alt属性
    public func extractAlt(_ selector: String, from html: String) throws -> [String] {
        return try extractAttribute("alt", from: selector, html: html)
    }
    
    private func applySelectorPart(_ part: String, to node: CSSNode) -> [CSSNode] {
        if part.hasPrefix(".") {
            let className = String(part.dropFirst())
            return node.children.filter { child in
                child.type == .element && child.hasClass(className)
            }
        } else if part.hasPrefix("#") {
            let id = String(part.dropFirst())
            return node.children.filter { child in
                child.type == .element && child.id == id
            }
        } else {
            let tagName = part.lowercased()
            return node.children.filter { child in
                child.type == .element && child.tagName == tagName
            }
        }
    }
}
