import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

/// CSS执行器，用于执行CSS选择器并提取内容
public final class CSSExecutor: @unchecked Sendable {
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
        let parseStart = DispatchTime.now()
        debug("RULE_STEP name=document_parse_start selector=\(sanitize(selector))")
        let document = try parser.parse(html)
        let parseDurationMs = elapsedMilliseconds(since: parseStart)
        debug("RULE_STEP name=document_parse_end selector=\(sanitize(selector)) duration_ms=\(parseDurationMs) root_children=\(document.children.count)")
        let selectionStart = DispatchTime.now()
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
        let trimmedSelector = selector.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmedSelector.components(separatedBy: ">").map { $0.trimmingCharacters(in: .whitespaces) }
        var currentNodes = [node]
        var iterationCount = 0
        let activeSampleId = sampleId ?? "unknown"

        if parts.count == 1, let part = parts.first, !part.isEmpty {
            return try collectDescendantMatches(
                part,
                from: node,
                depth: 1,
                iterationCount: &iterationCount,
                activeSampleId: activeSampleId
            )
        }
        
        for (partIndex, part) in parts.enumerated() {
            if part.isEmpty { continue }
            let depth = partIndex + 1
            debug("RULE_STEP name=selector_part part=\(sanitize(part)) depth=\(depth)")
            debug("NODE_TRAVERSE depth=\(depth) current_nodes=\(currentNodes.count)")

            if depth > maxTraversalDepth {
                debug("LOOP_GUARD_TRIGGERED sample=\(activeSampleId) location=CSSExecutor.select.depth")
                throw CSSExecutorError.htmlParsingFailed
            }

            var nextNodes: [CSSNode] = []
            nextNodes.reserveCapacity(currentNodes.count)

            for currentNode in currentNodes {
                iterationCount += 1
                if shouldLogIteration(iterationCount) {
                    debug("LOOP_ITERATION count=\(iterationCount)")
                    debug("NODE_TRAVERSE start node=\(nodeLabel(currentNode))")
                }
                if iterationCount > maxLoopIterations {
                    debug("LOOP_GUARD_TRIGGERED sample=\(activeSampleId) location=CSSExecutor.select.loop")
                    throw CSSExecutorError.htmlParsingFailed
                }
                let matches = applySelectorPart(part, to: currentNode)
                nextNodes.append(contentsOf: matches)
                if shouldLogIteration(iterationCount) {
                    debug("NODE_TRAVERSE depth=\(depth) match_count=\(matches.count) child_count=\(currentNode.children.count)")
                }
            }
            currentNodes = nextNodes
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

    private func collectDescendantMatches(
        _ part: String,
        from root: CSSNode,
        depth: Int,
        iterationCount: inout Int,
        activeSampleId: String
    ) throws -> [CSSNode] {
        debug("RULE_STEP name=selector_part part=\(sanitize(part)) depth=\(depth)")
        debug("NODE_TRAVERSE depth=\(depth) current_nodes=1")

        var matches: [CSSNode] = []
        var queue: [(node: CSSNode, depth: Int)] = [(root, depth)]

        while !queue.isEmpty {
            iterationCount += 1
            if shouldLogIteration(iterationCount) {
                debug("LOOP_ITERATION count=\(iterationCount)")
            }
            if iterationCount > maxLoopIterations {
                debug("LOOP_GUARD_TRIGGERED sample=\(activeSampleId) location=CSSExecutor.select.loop")
                throw CSSExecutorError.htmlParsingFailed
            }

            let current = queue.removeFirst()
            if current.depth > maxTraversalDepth {
                debug("LOOP_GUARD_TRIGGERED sample=\(activeSampleId) location=CSSExecutor.select.depth")
                throw CSSExecutorError.htmlParsingFailed
            }

            if shouldLogIteration(iterationCount) {
                debug("NODE_TRAVERSE start node=\(nodeLabel(current.node))")
            }

            let directMatches = applySelectorPart(part, to: current.node)
            matches.append(contentsOf: directMatches)

            if shouldLogIteration(iterationCount) {
                debug("NODE_TRAVERSE depth=\(current.depth) match_count=\(directMatches.count) child_count=\(current.node.children.count)")
            }

            for child in current.node.children where child.type == .element || child.type == .document {
                queue.append((child, current.depth + 1))
            }
        }

        return matches
    }

    private func debug(_ message: String) {
        debugLog?(message)
    }

    private func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func elapsedMilliseconds(since start: DispatchTime) -> Int {
        Int(DispatchTime.now().uptimeNanoseconds &- start.uptimeNanoseconds) / 1_000_000
    }

    private func shouldLogIteration(_ count: Int) -> Bool {
        count <= 10 || count % 100 == 0
    }

    private func nodeLabel(_ node: CSSNode) -> String {
        switch node.type {
        case .element:
            return node.tagName ?? "element"
        case .text:
            return "#text"
        case .comment:
            return "#comment"
        case .document:
            return "#document"
        }
    }
}

private extension Array {
    func withSideEffect(_ body: ([Element]) -> Void) -> [Element] {
        body(self)
        return self
    }
}
