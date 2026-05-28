import Foundation

/// M6 fix: Normalizes a BookSource JSON before decoding.
/// Converts object-shaped rule fields (ruleSearch, ruleToc, ruleContent, etc.)
/// to JSON-string form so ReaderCoreModels.BookSource can decode them.
public struct BookSourceImportNormalizer {

    public init() {}

    /// Normalizes raw BookSource JSON data and returns a new Data that
    /// BookSource can decode without throwing about wrong types.
    ///
    /// Handles two forms for each rule field:
    /// - String: passed through unchanged
    /// - Object/Dictionary: re-encoded as a compact JSON string
    ///
    /// Does NOT make network requests.
    public func normalize(_ input: Data) throws -> Data {
        let jsonObject = try JSONSerialization.jsonObject(with: input, options: [])
        guard var dict = jsonObject as? [String: Any] else {
            throw BookSourceImportNormalizeError.notAnObject
        }

        // Fields that Legado can express as either String or Object
        let ruleFields = ["ruleSearch", "ruleToc", "ruleContent", "ruleBookInfo", "ruleExplore"]

        for field in ruleFields {
            if let value = dict[field] {
                if value is String {
                    // Already string, pass through
                } else if let objectValue = value as? [String: Any] {
                    // Object → re-encode as JSON string
                    let stringValue: String
                    if objectValue.isEmpty {
                        stringValue = "{}"
                    } else {
                        let compactData = try JSONSerialization.data(withJSONObject: objectValue, options: [])
                        guard let s = String(data: compactData, encoding: .utf8) else {
                            throw BookSourceImportNormalizeError.encodingFailed(field: field)
                        }
                        stringValue = s
                    }
                    dict[field] = stringValue
                }
                // null/nil → leave as-is (will be nil after decode)
            }
        }

        // Header can be either String or Object (sometimes a JSON string, sometimes a dict)
        if let headerValue = dict["header"] {
            if let headerDict = headerValue as? [String: Any] {
                let compactData = try JSONSerialization.data(withJSONObject: headerDict, options: [])
                if let s = String(data: compactData, encoding: .utf8) {
                    dict["header"] = s
                }
            }
        }

        return try JSONSerialization.data(withJSONObject: dict, options: [])
    }
}

public enum BookSourceImportNormalizeError: Error, LocalizedError {
    case notAnObject
    case encodingFailed(field: String)

    public var errorDescription: String? {
        switch self {
        case .notAnObject:
            return "Book source JSON must be an object/dictionary"
        case .encodingFailed(let field):
            return "Failed to encode '\(field)' field as JSON string"
        }
    }
}