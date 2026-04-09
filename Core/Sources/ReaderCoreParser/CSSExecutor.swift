import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

/// CSS执行器，用于执行CSS选择器并提取内容
public final class CSSExecutor: @unchecked Sendable {
    private let clock = ContinuousClock()
    private let parser = HTMLParser()
    private let sampleId: String?
    private let debugLog: ((String) -> Void)?
    private let maxLoopIterations: Int
    private let maxTraversalDepth: Int
    
    public init(
        sampleId: String? = nil,
        debugLog: ((String) -> Void)? = nil,
        maxLoopIterations: Int = 100_000,
        maxTraversalDepth: Int = 1_000
    ) {
        self.sampleId = sampleId
        self.debugLog = debugLog
        self.maxLoopIterations = maxLoopIterations
        self.maxTraversalDepth = maxTraversalDepth
    }
    
    /// 执行完整的CSS规则（包含选择器和属性提取）
    public func execute(_ rule: String, from html: String) throws -> [String] {
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        debug("RULE_STEP name=execute_rule rule=\(sanitize(trimmed))")

        let parsedRule = try RuleParser.parse(trimmed)

        switch parsedRule.extractionMode {
        case .text:
            return try extractText(parsedRule.selector, from: html)
        case .html:
            return try extractHTML(parsedRule.selector, from: html)
        case .attribute(let attribute):
            return try extractAttribute(attribute, from: parsedRule.selector, html: html)
        }
    }
    
    /// 执行CSS选择器并返回匹配的节点
    public func select(_ selector: String, from html: String) throws -> [CSSNode] {
        debug("SELECTOR_EXEC start selector=\(sanitize(selector))")
        let parseStart = clock.now
        debug("RULE_STEP name=document_parse_start selector=\(sanitize(selector))")
        let document = try parser.parse(html)
        let parseDurationMs = elapsedMilliseconds(since: parseStart)
        debug("RULE_STEP name=document_parse_end selector=\(sanitize(selector)) duration_ms=\(parseDurationMs) root_children=\(document.children.count)")
        let selectionStart = clock.now
        return try select(selector, from: document)
            .map { node in
                node
            }
            .withSideEffect { nodes in
                debug("SELECTOR_EXEC result_count=\(nodes.count) selector=\(sanitize(selector)) duration_ms=\(elapsedMilliseconds(since: selectionStart))")
            }
    }
    
    /// 执行CSS选择器并返回匹配的节点（从指定节点开始）
    public func select(_ selector: String, from node: CSSNode) throws -> [CSSNode] {
        try SelectorEngine.select(
            selector,
            from: node,
            configuration: SelectorEngine.Configuration(
                activeSampleId: sampleId ?? "unknown",
                maxLoopIterations: maxLoopIterations,
                maxTraversalDepth: maxTraversalDepth,
                debug: { [debugLog] message in
                    debugLog?(message)
                }
            )
        )
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
    
    private func debug(_ message: String) {
        debugLog?(message)
    }

    private func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func elapsedMilliseconds(since start: ContinuousClock.Instant) -> Int {
        let duration = start.duration(to: clock.now)
        let millisecondsFromSeconds = duration.components.seconds * 1_000
        let millisecondsFromAttoseconds = duration.components.attoseconds / 1_000_000_000_000_000
        return Int(millisecondsFromSeconds + millisecondsFromAttoseconds)
    }

}

private extension Array {
    func withSideEffect(_ body: ([Element]) -> Void) -> [Element] {
        body(self)
        return self
    }
}
