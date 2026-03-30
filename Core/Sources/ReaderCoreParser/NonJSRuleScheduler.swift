import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

public final class NonJSRuleScheduler: RuleScheduler {
    public init() {}

    public func evaluate(rule: String, data: Data, flow: ParseFlow, source: BookSource) throws -> [String] {
        let trimmedRule = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedRule.isEmpty {
            throw makeError(flow: flow, type: .FIELD_MISSING, reason: "rule_missing", message: "Rule is required for \(flow.rawValue).")
        }

        let stages = parseStages(trimmedRule)
        var current = [String(data: data, encoding: .utf8) ?? ""]
        var hasNonJSStage = false
        var sawJSStage = false

        for stage in stages {
            switch stage.kind {
            case .regex:
                hasNonJSStage = true
                current = try applyRegex(stage.payload, on: current, flow: flow)
            case .jsonpath:
                hasNonJSStage = true
                current = try applyJSONPath(stage.payload, on: current, flow: flow)
            case .css:
                hasNonJSStage = true
                current = try applyCSS(stage.payload, on: current, flow: flow)
            case .xpath:
                hasNonJSStage = true
                current = try applyXPath(stage.payload, on: current, flow: flow)
            case .replace:
                hasNonJSStage = true
                current = try applyReplace(stage.payload, on: current, flow: flow)
            case .js:
                sawJSStage = true
                continue
            case .unsupported:
                throw makeError(flow: flow, type: .RULE_UNSUPPORTED, reason: "rule_kind_unsupported", message: "Unsupported rule kind: \(stage.raw)")
            }
        }

        if !hasNonJSStage || (sawJSStage && current.isEmpty) {
            throw makeError(flow: flow, type: .JS_DEGRADED, reason: "js_rule_skipped_in_non_js_mode", message: "JS-related rule detected and skipped in non-JS mode.")
        }

        if hasSourceJSHints(source) && current.isEmpty {
            throw makeError(flow: flow, type: .JS_DEGRADED, reason: "js_field_detected_without_non_js_output", message: "JS-only source hints detected without non-JS output.")
        }

        return current.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

private enum RuleKind {
    case css
    case xpath
    case jsonpath
    case regex
    case replace
    case js
    case unsupported
}

private struct RuleStage {
    let kind: RuleKind
    let payload: String
    let raw: String
}

private extension NonJSRuleScheduler {
    func parseStages(_ rule: String) -> [RuleStage] {
        let parts = rule.split(separator: "|").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return parts.map { part in
            if part.lowercased().hasPrefix("css:") {
                return RuleStage(kind: .css, payload: String(part.dropFirst(4)), raw: part)
            }
            if part.lowercased().hasPrefix("xpath:") {
                return RuleStage(kind: .xpath, payload: String(part.dropFirst(6)), raw: part)
            }
            if part.lowercased().hasPrefix("jsonpath:") {
                return RuleStage(kind: .jsonpath, payload: String(part.dropFirst(9)), raw: part)
            }
            if part.lowercased().hasPrefix("regex:") {
                return RuleStage(kind: .regex, payload: String(part.dropFirst(6)), raw: part)
            }
            if part.lowercased().hasPrefix("replace:") {
                return RuleStage(kind: .replace, payload: String(part.dropFirst(8)), raw: part)
            }
            if part.lowercased().hasPrefix("js:") || part.lowercased().contains("javascript") {
                return RuleStage(kind: .js, payload: part, raw: part)
            }
            return RuleStage(kind: .unsupported, payload: part, raw: part)
        }
    }

    func applyRegex(_ pattern: String, on inputs: [String], flow: ParseFlow) throws -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            throw makeError(flow: flow, type: .RULE_INVALID, reason: "invalid_regex_expression", message: "Invalid regex pattern.")
        }
        var output: [String] = []
        for input in inputs {
            let range = NSRange(input.startIndex..<input.endIndex, in: input)
            for match in regex.matches(in: input, options: [], range: range) {
                if match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: input) {
                    output.append(String(input[r]))
                } else if let r = Range(match.range(at: 0), in: input) {
                    output.append(String(input[r]))
                }
            }
        }
        return output
    }

    func applyReplace(_ payload: String, on inputs: [String], flow: ParseFlow) throws -> [String] {
        let pair = payload.components(separatedBy: "=>")
        if pair.count != 2 {
            throw makeError(flow: flow, type: .RULE_INVALID, reason: "invalid_replace_rule", message: "Replace rule should be from=>to.")
        }
        let from = pair[0]
        let to = pair[1]
        return inputs.map { $0.replacingOccurrences(of: from, with: to) }
    }

    func applyCSS(_ selector: String, on inputs: [String], flow: ParseFlow) throws -> [String] {
        let trimmed = selector.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw makeError(flow: flow, type: .RULE_INVALID, reason: "invalid_css_selector", message: "CSS selector is empty.")
        }
        var output: [String] = []
        for input in inputs {
            output.append(contentsOf: extractBySimpleCSS(selector: trimmed, html: input))
        }
        return output
    }

    func applyXPath(_ expr: String, on inputs: [String], flow: ParseFlow) throws -> [String] {
        let trimmed = expr.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw makeError(flow: flow, type: .RULE_INVALID, reason: "invalid_xpath_expression", message: "XPath expression is empty.")
        }
        var output: [String] = []
        for input in inputs {
            output.append(contentsOf: extractBySimpleXPath(expression: trimmed, html: input))
        }
        return output
    }

    func applyJSONPath(_ path: String, on inputs: [String], flow: ParseFlow) throws -> [String] {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.hasPrefix("$.") {
            throw makeError(flow: flow, type: .RULE_INVALID, reason: "invalid_jsonpath_expression", message: "JSONPath must start with $.")
        }
        var output: [String] = []
        for input in inputs {
            guard let data = input.data(using: .utf8) else {
                continue
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) else {
                throw makeError(flow: flow, type: .JSON_INVALID, reason: "malformed_json_payload", message: "Input is not valid JSON for JSONPath.")
            }
            let values = evaluateSimpleJSONPath(trimmed, json: json)
            output.append(contentsOf: values)
        }
        return output
    }

    func evaluateSimpleJSONPath(_ path: String, json: Any) -> [String] {
        let tokens = tokenizeJSONPath(path)
        var current: [Any] = [json]
        for token in tokens {
            var next: [Any] = []
            for node in current {
                if case .key(let key) = token, let dict = node as? [String: Any], let value = dict[key] {
                    next.append(value)
                } else if case .index(let idx) = token, let array = node as? [Any], array.indices.contains(idx) {
                    next.append(array[idx])
                }
            }
            current = next
        }
        return current.compactMap { anyToString($0) }
    }

    func tokenizeJSONPath(_ path: String) -> [JSONPathToken] {
        let body = String(path.dropFirst(2))
        var tokens: [JSONPathToken] = []
        for segment in body.split(separator: ".") {
            let s = String(segment)
            if let l = s.firstIndex(of: "["), let r = s.firstIndex(of: "]"), l < r {
                let key = String(s[..<l])
                if !key.isEmpty {
                    tokens.append(.key(key))
                }
                let idxText = String(s[s.index(after: l)..<r])
                if let idx = Int(idxText) {
                    tokens.append(.index(idx))
                }
            } else {
                tokens.append(.key(s))
            }
        }
        return tokens
    }

    func extractBySimpleCSS(selector: String, html: String) -> [String] {
        if selector.hasPrefix(".") {
            let cls = NSRegularExpression.escapedPattern(for: String(selector.dropFirst()))
            let pattern = "<([a-zA-Z0-9]+)[^>]*class=[\"'][^\"']*\\b\(cls)\\b[^\"']*[\"'][^>]*>([\\s\\S]*?)</\\1>"
            return regexGroupMatches(pattern: pattern, in: html, group: 2).map(stripHTMLTags)
        }
        if selector.hasPrefix("#") {
            let id = NSRegularExpression.escapedPattern(for: String(selector.dropFirst()))
            let pattern = "<([a-zA-Z0-9]+)[^>]*id=[\"']\(id)[\"'][^>]*>([\\s\\S]*?)</\\1>"
            return regexGroupMatches(pattern: pattern, in: html, group: 2).map(stripHTMLTags)
        }
        let tag = NSRegularExpression.escapedPattern(for: selector)
        let pattern = "<\(tag)[^>]*>([\\s\\S]*?)</\(tag)>"
        return regexGroupMatches(pattern: pattern, in: html, group: 1).map(stripHTMLTags)
    }

    func extractBySimpleXPath(expression: String, html: String) -> [String] {
        if expression.hasPrefix("//"), expression.hasSuffix("/text()") {
            let tag = String(expression.dropFirst(2).dropLast(7))
            let escapedTag = NSRegularExpression.escapedPattern(for: tag)
            let pattern = "<\(escapedTag)[^>]*>([\\s\\S]*?)</\(escapedTag)>"
            return regexGroupMatches(pattern: pattern, in: html, group: 1).map(stripHTMLTags)
        }
        if expression.hasPrefix("//"), expression.contains("/@") {
            let parts = expression.dropFirst(2).split(separator: "/@")
            if parts.count == 2 {
                let tag = NSRegularExpression.escapedPattern(for: String(parts[0]))
                let attr = NSRegularExpression.escapedPattern(for: String(parts[1]))
                let pattern = "<\(tag)[^>]*\(attr)=[\"']([^\"']+)[\"'][^>]*>"
                return regexGroupMatches(pattern: pattern, in: html, group: 1)
            }
        }
        return []
    }

    func regexGroupMatches(pattern: String, in text: String, group: Int) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard match.numberOfRanges > group, let r = Range(match.range(at: group), in: text) else {
                return nil
            }
            return String(text[r])
        }
    }

    func stripHTMLTags(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func hasSourceJSHints(_ source: BookSource) -> Bool {
        let jsKeys = ["loginCheckJs", "coverDecodeJs", "js", "javaScript"]
        let hasUnknownJS = source.unknownFields.keys.contains { key in
            jsKeys.contains { key.lowercased().contains($0.lowercased()) }
        }
        let hasRuleJS = [source.ruleSearch, source.ruleBookInfo, source.ruleToc, source.ruleContent]
            .compactMap { $0?.lowercased() }
            .contains { $0.contains("js:") || $0.contains("javascript") }
        return hasUnknownJS || hasRuleJS
    }

    func makeError(flow: ParseFlow, type: FailureType, reason: String, message: String) -> ReaderError {
        ReaderError(
            code: .parsingFailed,
            message: message,
            failure: FailureRecord(type: type, reason: reason),
            context: [
                "flow": flow.rawValue,
                "engine": "non_js"
            ]
        )
    }

    enum JSONPathToken {
        case key(String)
        case index(Int)
    }

    func anyToString(_ value: Any) -> String? {
        if let str = value as? String {
            return str
        }
        if let num = value as? NSNumber {
            return num.stringValue
        }
        if JSONSerialization.isValidJSONObject(value), let data = try? JSONSerialization.data(withJSONObject: value), let text = String(data: data, encoding: .utf8) {
            return text
        }
        return nil
    }
}
