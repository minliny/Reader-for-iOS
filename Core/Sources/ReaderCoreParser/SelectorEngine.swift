import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

enum SelectorEngine {
    struct Configuration {
        let activeSampleId: String
        let maxLoopIterations: Int
        let maxTraversalDepth: Int
        let debug: (String) -> Void
    }

    static func select(
        _ selector: String,
        from node: CSSNode,
        configuration: Configuration
    ) throws -> [CSSNode] {
        let trimmedSelector = selector.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmedSelector.components(separatedBy: ">").map { $0.trimmingCharacters(in: .whitespaces) }
        var currentNodes = [node]
        var iterationCount = 0

        if parts.count == 1, let part = parts.first, !part.isEmpty {
            return try collectDescendantMatches(
                part,
                from: node,
                depth: 1,
                iterationCount: &iterationCount,
                configuration: configuration
            )
        }

        for (partIndex, part) in parts.enumerated() {
            if part.isEmpty { continue }
            let depth = partIndex + 1
            configuration.debug("RULE_STEP name=selector_part part=\(sanitize(part)) depth=\(depth)")
            configuration.debug("NODE_TRAVERSE depth=\(depth) current_nodes=\(currentNodes.count)")

            if depth > configuration.maxTraversalDepth {
                configuration.debug("LOOP_GUARD_TRIGGERED sample=\(configuration.activeSampleId) location=SelectorEngine.select.depth")
                throw CSSExecutorError.htmlParsingFailed
            }

            var nextNodes: [CSSNode] = []
            nextNodes.reserveCapacity(currentNodes.count)

            for currentNode in currentNodes {
                iterationCount += 1
                if shouldLogIteration(iterationCount) {
                    configuration.debug("LOOP_ITERATION count=\(iterationCount)")
                    configuration.debug("NODE_TRAVERSE start node=\(nodeLabel(currentNode))")
                }
                if iterationCount > configuration.maxLoopIterations {
                    configuration.debug("LOOP_GUARD_TRIGGERED sample=\(configuration.activeSampleId) location=SelectorEngine.select.loop")
                    throw CSSExecutorError.htmlParsingFailed
                }

                let matches = applySelectorPart(part, to: currentNode)
                nextNodes.append(contentsOf: matches)
                if shouldLogIteration(iterationCount) {
                    configuration.debug("NODE_TRAVERSE depth=\(depth) match_count=\(matches.count) child_count=\(currentNode.children.count)")
                }
            }
            currentNodes = nextNodes
        }

        return currentNodes
    }

    // MARK: - 选择器支持范围（显式契约）
    //
    // 当前只支持以下三种 simple selector：
    //   - tag 选择器（如 "div"、"a"、"li"）
    //   - .class 选择器（如 ".chapter"）
    //   - #id 选择器（如 "#content"）
    //
    // 以下选择器当前 **不支持**，且不会抛出错误，而是静默返回空数组：
    //   - compound selector（如 "div.foo"、"a.active"）
    //   - attribute selector（如 "a[href]"、"input[type=text]"）
    //   - pseudo-class（如 "li:nth-child(2)"、"a:first-child"）
    //   - 组合选择器（如 "div, span"）
    //
    // 这是当前阶段的有意边界，不是临时遗漏。
    private static func applySelectorPart(_ part: String, to node: CSSNode) -> [CSSNode] {
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

    private static func collectDescendantMatches(
        _ part: String,
        from root: CSSNode,
        depth: Int,
        iterationCount: inout Int,
        configuration: Configuration
    ) throws -> [CSSNode] {
        configuration.debug("RULE_STEP name=selector_part part=\(sanitize(part)) depth=\(depth)")
        configuration.debug("NODE_TRAVERSE depth=\(depth) current_nodes=1")

        var matches: [CSSNode] = []
        var queue: [(node: CSSNode, depth: Int)] = [(root, depth)]

        while !queue.isEmpty {
            iterationCount += 1
            if shouldLogIteration(iterationCount) {
                configuration.debug("LOOP_ITERATION count=\(iterationCount)")
            }
            if iterationCount > configuration.maxLoopIterations {
                configuration.debug("LOOP_GUARD_TRIGGERED sample=\(configuration.activeSampleId) location=SelectorEngine.select.loop")
                throw CSSExecutorError.htmlParsingFailed
            }

            let current = queue.removeFirst()
            if current.depth > configuration.maxTraversalDepth {
                configuration.debug("LOOP_GUARD_TRIGGERED sample=\(configuration.activeSampleId) location=SelectorEngine.select.depth")
                throw CSSExecutorError.htmlParsingFailed
            }

            if shouldLogIteration(iterationCount) {
                configuration.debug("NODE_TRAVERSE start node=\(nodeLabel(current.node))")
            }

            let directMatches = applySelectorPart(part, to: current.node)
            matches.append(contentsOf: directMatches)

            if shouldLogIteration(iterationCount) {
                configuration.debug("NODE_TRAVERSE depth=\(current.depth) match_count=\(directMatches.count) child_count=\(current.node.children.count)")
            }

            for child in current.node.children where child.type == .element || child.type == .document {
                queue.append((child, current.depth + 1))
            }
        }

        return matches
    }

    private static func shouldLogIteration(_ count: Int) -> Bool {
        count <= 10 || count % 100 == 0
    }

    private static func nodeLabel(_ node: CSSNode) -> String {
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

    private static func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
