import Foundation
import ReaderCoreProtocols

enum RuleParser {
    enum ExtractionMode {
        case text
        case html
        case attribute(String)
    }

    struct ParsedRule {
        let selector: String
        let extractionMode: ExtractionMode
    }

    static func parse(_ rule: String) throws -> ParsedRule {
        guard let atIndex = rule.lastIndex(of: "@") else {
            return ParsedRule(selector: rule, extractionMode: .text)
        }

        let selector = String(rule[..<atIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let extractor = String(rule[rule.index(after: atIndex)...]).lowercased()

        switch extractor {
        case "text":
            return ParsedRule(selector: selector, extractionMode: .text)
        case "html":
            return ParsedRule(selector: selector, extractionMode: .html)
        case "href", "alt", "src":
            return ParsedRule(selector: selector, extractionMode: .attribute(extractor))
        default:
            throw CSSExecutorError.unsupportedSelectorSyntax("@\(extractor)")
        }
    }
}
