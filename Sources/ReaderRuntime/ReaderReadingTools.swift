import Foundation

/// Half-open offsets into Core's Unicode scalar body, never UIKit UTF-16.
public struct ReaderScalarRange: Codable, Hashable, Sendable {
    public let lowerBound: UInt64
    public let upperBound: UInt64
    public init(lowerBound: UInt64, upperBound: UInt64) {
        self.lowerBound = lowerBound; self.upperBound = upperBound
    }
}

public struct ReaderContentSearchHit: Codable, Hashable, Sendable, Identifiable {
    public let positionScope: ReaderContentPositionScope?
    public let sourceId: String
    public let bookId: String
    public let bookName: String
    public let chapterIndex: Int32
    public let chapterOffset: UInt64
    public let matchLength: UInt64
    public let snippetStart: UInt64
    public let chapterTitle: String
    public let snippet: String
    public var id: String { "\(sourceId)|\(bookId)|\(chapterIndex)|\(chapterOffset)" }

    public func scalarRange(for book: ReaderBook, content: ReaderChapterContent) throws -> ReaderScalarRange {
        guard sourceId == book.sourceId, bookId == book.bookId,
              let scope = positionScope, scope == (try ReaderContentPositionScope(book: book, content: content)),
              chapterIndex >= 0, UInt32(chapterIndex) == content.chapterIndex,
              chapterOffset <= content.scalarCount,
              matchLength <= content.scalarCount - chapterOffset else { throw ReaderLibraryError.invalidPosition }
        return ReaderScalarRange(lowerBound: chapterOffset, upperBound: chapterOffset + matchLength)
    }
}

public struct ReaderContentSearchPage: Codable, Hashable, Sendable {
    public let results: [ReaderContentSearchHit]
    public let hasMore: Bool
    public let nextCursor: String?
    private enum CodingKeys: String, CodingKey { case results, hasMore, nextCursor }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        results = try values.decode([ReaderContentSearchHit].self, forKey: .results)
        hasMore = try values.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        nextCursor = try values.decodeIfPresent(String.self, forKey: .nextCursor)
    }
}

public struct ReaderHighlight: Codable, Hashable, Sendable, Identifiable {
    public let positionScope: ReaderContentPositionScope?
    public let time: Int64
    public let bookUrl: String
    public let chapterUrl: String
    public let bookName: String
    public let bookAuthor: String
    public let chapterIndex: Int32
    public let chapterPos: Int32
    public let chapterPosEnd: Int32
    public let layoutTitleLength: Int32
    public let chapterName: String
    public let bookText: String
    public let style: String
    public let note: String
    public var id: Int64 { time }

    public func scalarRange(for book: ReaderBook, content: ReaderChapterContent) throws -> ReaderScalarRange {
        guard let scope = positionScope, scope == (try ReaderContentPositionScope(book: book, content: content)),
              bookUrl == book.bookId, chapterIndex >= 0, UInt32(chapterIndex) == content.chapterIndex,
              chapterPos >= 0, chapterPosEnd >= chapterPos,
              UInt64(chapterPosEnd) <= content.scalarCount else { throw ReaderLibraryError.invalidPosition }
        return ReaderScalarRange(lowerBound: UInt64(chapterPos), upperBound: UInt64(chapterPosEnd))
    }
}

public struct ReaderReadingRecord: Codable, Hashable, Sendable, Identifiable {
    public let deviceId: String
    public let bookName: String
    public let author: String
    public let readTime: Int64
    public let lastRead: Int64
    public var id: String { "\(deviceId)|\(bookName)" }
}
public struct ReaderReadingBookSummary: Codable, Hashable, Sendable, Identifiable {
    public let bookName: String
    public let authors: [String]
    public let readTime: Int64
    public let lastRead: Int64
    public var id: String { bookName }
}
public enum ReaderReadingRecordSort: String, Codable, Sendable { case bookName, readTime, lastRead }
public struct ReaderReadingSummary: Codable, Hashable, Sendable {
    public let books: [ReaderReadingBookSummary]
    public let totalReadTime: Int64
}

/// Full rule value for create/edit; omitted optional fields remain omitted in the Core request.
public struct ReaderReplaceRuleDraft: Codable, Hashable, Sendable {
    public var name: String
    public var group: String?
    public var pattern: String
    public var replacement: String
    public var scope: String?
    public var scopeTitle: Bool
    public var scopeSource: Bool
    public var scopeContent: Bool
    public var excludeScope: String?
    public var isEnabled: Bool
    public var isRegex: Bool
    public var timeoutMillisecond: Int64
    public var order: Int32
    public init(name: String = "", group: String? = nil, pattern: String, replacement: String = "",
                scope: String? = nil, scopeTitle: Bool = false, scopeSource: Bool = false,
                scopeContent: Bool = true, excludeScope: String? = nil, isEnabled: Bool = true,
                isRegex: Bool = true, timeoutMillisecond: Int64 = 3000, order: Int32 = 0) {
        self.name = name; self.group = group; self.pattern = pattern; self.replacement = replacement
        self.scope = scope; self.scopeTitle = scopeTitle; self.scopeSource = scopeSource
        self.scopeContent = scopeContent; self.excludeScope = excludeScope; self.isEnabled = isEnabled
        self.isRegex = isRegex; self.timeoutMillisecond = timeoutMillisecond; self.order = order
    }
}
public struct ReaderReplaceRule: Codable, Hashable, Sendable, Identifiable {
    public let id: Int64
    public let name: String
    public let group: String?
    public let pattern: String
    public let replacement: String
    public let scope: String?
    public let scopeTitle: Bool
    public let scopeSource: Bool
    public let scopeContent: Bool
    public let excludeScope: String?
    public let isEnabled: Bool
    public let isRegex: Bool
    public let timeoutMillisecond: Int64
    public let order: Int32
    public var draft: ReaderReplaceRuleDraft {
        ReaderReplaceRuleDraft(name: name, group: group, pattern: pattern, replacement: replacement,
                               scope: scope, scopeTitle: scopeTitle, scopeSource: scopeSource,
                               scopeContent: scopeContent, excludeScope: excludeScope,
                               isEnabled: isEnabled, isRegex: isRegex,
                               timeoutMillisecond: timeoutMillisecond, order: order)
    }
}
public struct ReaderTXTTOCRuleDraft: Codable, Hashable, Sendable {
    public var name: String
    public var rule: String
    public var example: String?
    public var serialNumber: Int32
    public var enable: Bool
    public init(name: String = "", rule: String, example: String? = nil, serialNumber: Int32 = -1, enable: Bool = true) {
        self.name = name; self.rule = rule; self.example = example; self.serialNumber = serialNumber; self.enable = enable
    }
}
public struct ReaderTXTTOCRule: Codable, Hashable, Sendable, Identifiable {
    public let id: Int64
    public let name: String
    public let rule: String
    public let example: String?
    public let serialNumber: Int32
    public let enable: Bool
    public var draft: ReaderTXTTOCRuleDraft {
        ReaderTXTTOCRuleDraft(name: name, rule: rule, example: example, serialNumber: serialNumber, enable: enable)
    }
}
public enum ReaderTXTTOCDraftStatus: String, Codable, Hashable, Sendable {
    case selected, shadowed, disabled, invalidRegex, emptyPattern, noMatch, insufficientMatches
}
public struct ReaderTXTTOCPreviewSelectedRule: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable { case draft, saved }
    public let kind: Kind
    /// A new draft has no saved ID. Core never exposes its predicted ordering ID.
    public let ruleId: Int64?
}
public struct ReaderTXTTOCPreviewChapter: Codable, Hashable, Sendable, Identifiable {
    public let index: UInt32
    public let title: String
    public let startScalar: UInt64
    public let endScalar: UInt64
    public var id: UInt32 { index }
}
/// Read-only Core snapshot. None of these fingerprints acknowledges a save,
/// reserves an ID, or promises that a later rule transaction uses this snapshot.
public struct ReaderTXTTOCRulePreview: Codable, Hashable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let sourceSha256: String
    public let draftSha256: String
    public let savedRulesSha256: String
    public let effectiveRulesSha256: String
    public let draftStatus: ReaderTXTTOCDraftStatus
    public let draftMatchCount: UInt64
    public let regexError: String?
    public let draftSelected: Bool
    public let selectedRule: ReaderTXTTOCPreviewSelectedRule?
    public let automaticFallback: Bool
    public let chapterCount: UInt32
    public let chapters: [ReaderTXTTOCPreviewChapter]
    public let truncated: Bool
}
public struct ReaderDictionaryRule: Codable, Hashable, Sendable, Identifiable {
    public var name: String
    public var urlRule: String
    public var showRule: String
    public var enabled: Bool
    public var sortNumber: Int32
    public var id: String { name }
    public init(name: String, urlRule: String = "", showRule: String = "", enabled: Bool = true, sortNumber: Int32 = 0) {
        self.name = name; self.urlRule = urlRule; self.showRule = showRule; self.enabled = enabled; self.sortNumber = sortNumber
    }
}
public enum ReaderReplaceTarget: String, Codable, Sendable { case chapter, title }
public struct ReaderReplaceValidationIssue: Codable, Hashable, Sendable {
    public let code: String
    public let message: String
    public let scope: String?
}
public struct ReaderReplaceValidation: Codable, Hashable, Sendable {
    public let valid: Bool
    public let issues: [ReaderReplaceValidationIssue]
}
public struct ReaderReplaceApplication: Codable, Hashable, Sendable {
    public let text: String
    public let changed: Bool
    public let target: ReaderReplaceTarget
    public let storedRuleCount: UInt64
    public let enabledRuleCount: UInt64
}
public struct ReaderReplacePreview: Codable, Hashable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: UInt32
    public let chapterTitle: String
    public let before: String
    public let after: String
    public let changed: Bool
    public let truncated: Bool
    public let storedRuleCount: UInt64
    public let enabledRuleCount: UInt64
}

public struct ReaderRuleBundleCounts: Codable, Hashable, Sendable {
    public let replaceRules: UInt32
    public let dictRules: UInt32
    public let txtTocRules: UInt32
    public let ruleSubscriptions: UInt32
}
public struct ReaderRuleBundle: Codable, Hashable, Sendable {
    public let schemaVersion: UInt32
    public let json: String
    public let counts: ReaderRuleBundleCounts
}
public struct ReaderRuleBundleImport: Codable, Hashable, Sendable {
    public let schemaVersion: UInt32
    public let counts: ReaderRuleBundleCounts
    public let replaceExisting: Bool
}

/// These rules derive display hierarchy only; they do not re-split imported chapters.
public struct ReaderDirectoryHierarchyRule: Codable, Hashable, Sendable {
    public enum Boundary: String, Codable, Sendable { case title, head, tail, any }
    public var pattern: String
    public var level: UInt32
    public var boundary: Boundary
    public init(pattern: String, level: UInt32, boundary: Boundary) {
        self.pattern = pattern; self.level = level; self.boundary = boundary
    }
}
public struct ReaderDirectoryRuleNode: Codable, Hashable, Sendable, Identifiable {
    public let nodeId: String
    public let parentId: String?
    public let depth: UInt32
    public let title: String
    public let kind: String
    public let chapterIndex: UInt32?
    public let chapterOffsetScalar: UInt64?
    public let hasChildren: Bool
    public let expanded: Bool
    public var id: String { nodeId }
}
public struct ReaderDirectoryRulesResult: Codable, Hashable, Sendable {
    public let status: String
    public let sourceId: String?
    public let bookId: String?
    public let reason: String?
    public let structureRevision: String?
    public let navigationRevision: String?
    public let nodeCount: UInt32?
    public let readableChapterCount: UInt32?
    public let unmappedCount: UInt32?
    public let nodes: [ReaderDirectoryRuleNode]?
    public let rules: [ReaderDirectoryHierarchyRule]?
}

/// Separate capability protocol keeps V1-only mocks honest and source compatible.
public protocol ReaderReadingToolsServing: ReaderLibraryServing {
    func searchContent(for book: ReaderBook, keyword: String, limit: UInt32, offset: UInt32) async throws -> ReaderContentSearchPage
    func highlights(for book: ReaderBook, query: String?) async throws -> [ReaderHighlight]
    func createHighlight(for book: ReaderBook, content: ReaderChapterContent, range: ReaderScalarRange,
                         style: String, note: String, operationID: String) async throws -> ReaderHighlight
    func updateHighlight(_ highlight: ReaderHighlight, note: String, style: String, operationID: String) async throws -> ReaderHighlight
    func deleteHighlight(_ highlight: ReaderHighlight, operationID: String) async throws -> Bool
    func readingRecords(deviceID: String?) async throws -> [ReaderReadingRecord]
    func readReadingTimeHead() async throws -> ReaderReadingTimeHead?
    func readingSummary(query: String?, sortBy: ReaderReadingRecordSort) async throws -> ReaderReadingSummary
    func accumulateReadingTime(for book: ReaderBook, deviceID: String, elapsedMillis: Int64, readAt: Int64,
                               sequence: UInt64, operationID: String) async throws -> ReaderReadingRecord
    func deleteReadingRecords(bookName: String, operationID: String) async throws -> UInt64
    func replaceRules(enabledOnly: Bool) async throws -> [ReaderReplaceRule]
    func validateReplaceRule(_ draft: ReaderReplaceRuleDraft) async throws -> ReaderReplaceValidation
    func processText(_ text: String, for book: ReaderBook, target: ReaderReplaceTarget) async throws -> ReaderReplaceApplication
    func previewReplacement(for book: ReaderBook, chapterIndex: UInt32, maxScalars: UInt32) async throws -> ReaderReplacePreview
    func createReplaceRule(_ draft: ReaderReplaceRuleDraft, operationID: String) async throws -> ReaderReplaceRule
    func updateReplaceRule(id: Int64, draft: ReaderReplaceRuleDraft, operationID: String) async throws -> ReaderReplaceRule
    func deleteReplaceRule(id: Int64, operationID: String) async throws -> Bool
    func txtTOCRules(enabledOnly: Bool) async throws -> [ReaderTXTTOCRule]
    func previewTXTTOCRule(for book: ReaderBook, draft: ReaderTXTTOCRuleDraft,
                           editingRuleID: Int64?, limit: UInt32) async throws -> ReaderTXTTOCRulePreview
    func createTXTTOCRule(_ draft: ReaderTXTTOCRuleDraft, operationID: String) async throws -> ReaderTXTTOCRule
    func updateTXTTOCRule(id: Int64, draft: ReaderTXTTOCRuleDraft, operationID: String) async throws -> ReaderTXTTOCRule
    func deleteTXTTOCRule(id: Int64, operationID: String) async throws -> Bool
    func dictionaryRules() async throws -> [ReaderDictionaryRule]
    func putDictionaryRule(_ rule: ReaderDictionaryRule, operationID: String) async throws -> ReaderDictionaryRule
    func deleteDictionaryRule(name: String, operationID: String) async throws -> Bool
    func queryDictionary(ruleName: String, word: String) async throws -> String
    func exportRuleBundle() async throws -> ReaderRuleBundle
    func importRuleBundle(json: String, replaceExisting: Bool, operationID: String) async throws -> ReaderRuleBundleImport
    func directoryRules(for book: ReaderBook) async throws -> ReaderDirectoryRulesResult
    func prepareDirectoryRules(for book: ReaderBook, operationID: String) async throws -> ReaderDirectoryRulesResult
    func previewDirectoryRules(for book: ReaderBook, rules: [ReaderDirectoryHierarchyRule]) async throws -> ReaderDirectoryRulesResult
    func applyDirectoryRules(for book: ReaderBook, rules: [ReaderDirectoryHierarchyRule], operationID: String) async throws -> ReaderDirectoryRulesResult
}
public extension ReaderReadingToolsServing {
    func searchContent(for book: ReaderBook, keyword: String) async throws -> ReaderContentSearchPage {
        try await searchContent(for: book, keyword: keyword, limit: 100, offset: 0)
    }
    func highlights(for book: ReaderBook) async throws -> [ReaderHighlight] { try await highlights(for: book, query: nil) }
    func readingSummary() async throws -> ReaderReadingSummary { try await readingSummary(query: nil, sortBy: .lastRead) }
    func replaceRules() async throws -> [ReaderReplaceRule] { try await replaceRules(enabledOnly: false) }
    func txtTOCRules() async throws -> [ReaderTXTTOCRule] { try await txtTOCRules(enabledOnly: false) }
    func previewTXTTOCRule(for book: ReaderBook, draft: ReaderTXTTOCRuleDraft,
                           editingRuleID: Int64?, limit: UInt32) async throws -> ReaderTXTTOCRulePreview {
        throw ReaderLibraryError.invalidResponse("TXT draft preview unavailable")
    }
}

extension ReaderLibraryService: ReaderReadingToolsServing {
    /// Search only Core-materialized bodies; no HTTP fetch or Host text scanner.
    public func searchContent(for book: ReaderBook, keyword: String, limit: UInt32, offset: UInt32) async throws -> ReaderContentSearchPage {
        let page = try decode(ReaderContentSearchPage.self, await coreRead("search.content", [
            "sourceId": book.sourceId, "bookId": book.bookId, "keyword": keyword, "maxResults": limit, "offset": offset
        ], timeout: 120))
        guard page.results.allSatisfy({ $0.sourceId == book.sourceId && $0.bookId == book.bookId && $0.chapterIndex >= 0 }) else {
            throw ReaderLibraryError.invalidResponse("content search identity")
        }
        return page
    }

    public func highlights(for book: ReaderBook, query: String?) async throws -> [ReaderHighlight] {
        struct Result: Decodable { let highlights: [ReaderHighlight] }
        var params: [String: Any] = ["bookUrl": book.bookId]
        if let query { params["query"] = query }
        let result = try decode(Result.self, await coreRead("book-highlight.list", params))
        // Preserve unscoped legacy marks for inspection, but scalarRange refuses
        // to turn them into a current-book jump without authoritative scope.
        return result.highlights.filter { value in
            guard let scope = value.positionScope else { return true }
            return scope.sourceId == book.sourceId && scope.bookId == book.bookId
        }
    }

    public func createHighlight(for book: ReaderBook, content: ReaderChapterContent, range: ReaderScalarRange,
                                style: String, note: String, operationID: String) async throws -> ReaderHighlight {
        let scope = try ReaderContentPositionScope(book: book, content: content)
        guard range.lowerBound < range.upperBound, range.upperBound <= content.scalarCount,
              let begin = Int32(exactly: range.lowerBound), let end = Int32(exactly: range.upperBound),
              let chapter = Int32(exactly: content.chapterIndex) else { throw ReaderLibraryError.invalidPosition }
        let scalars = content.content.unicodeScalars
        let start = scalars.index(scalars.startIndex, offsetBy: Int(range.lowerBound))
        let stop = scalars.index(scalars.startIndex, offsetBy: Int(range.upperBound))
        var params: [String: Any] = ["positionScope": try toolsObject(scope), "bookUrl": book.bookId,
                                   "bookName": book.title, "bookAuthor": book.author,
                                   "chapterIndex": chapter, "chapterPos": begin, "chapterPosEnd": end,
                                   "chapterName": content.chapterTitle, "bookText": String(scalars[start..<stop]),
                                   "style": style, "note": note]
        if let original = try existingCoreParameters(operationID: operationID, method: "book-highlight.create") {
            guard let url = original["chapterUrl"] as? String else { throw ReaderLibraryError.operationPending(operationID) }
            params["chapterUrl"] = url
        } else {
            guard let chapter = try await chapters(for: book).first(where: { $0.index == content.chapterIndex }), !chapter.url.isEmpty else {
                throw ReaderLibraryError.invalidPosition
            }
            params["chapterUrl"] = chapter.url
        }
        struct Result: Decodable { let highlight: ReaderHighlight }
        let result = try decode(Result.self, await coreMutation("book-highlight.create", params,
                                                               operationID: operationID, scope: "highlights:" + book.id))
        _ = try result.highlight.scalarRange(for: book, content: content)
        guard result.highlight.chapterPos == begin, result.highlight.chapterPosEnd == end else {
            throw ReaderLibraryError.invalidResponse("highlight range receipt")
        }
        try await finishCoreOperation(operationID)
        return result.highlight
    }

    public func updateHighlight(_ highlight: ReaderHighlight, note: String, style: String, operationID: String) async throws -> ReaderHighlight {
        struct Result: Decodable { let highlight: ReaderHighlight }
        let result = try decode(Result.self, await coreMutation("book-highlight.update", ["time": highlight.time, "note": note, "style": style],
                                                               operationID: operationID, scope: toolsHighlightScope(highlight)))
        // The original note/style ACK can carry a Core-remapped anchor after
        // processing changes. Its immutable mark and book identity must match;
        // jumping still requires scalarRange against the current body version.
        guard result.highlight.time == highlight.time, result.highlight.bookUrl == highlight.bookUrl else {
            throw ReaderLibraryError.invalidResponse("highlight update identity")
        }
        try await finishCoreOperation(operationID)
        return result.highlight
    }

    private func toolsHighlightScope(_ highlight: ReaderHighlight) -> String {
        guard let scope = highlight.positionScope else { return "highlights:legacy:" + highlight.bookUrl }
        return "highlights:" + scope.sourceId + "|" + scope.bookId
    }

    public func deleteHighlight(_ highlight: ReaderHighlight, operationID: String) async throws -> Bool {
        struct Result: Decodable { let time: Int64; let deleted: Bool }
        let result = try decode(Result.self, await coreMutation("book-highlight.delete", ["time": highlight.time],
                                                               operationID: operationID, scope: toolsHighlightScope(highlight)))
        guard result.time == highlight.time else { throw ReaderLibraryError.invalidResponse("highlight delete identity") }
        try await finishCoreOperation(operationID)
        return result.deleted
    }

    public func readingRecords(deviceID: String?) async throws -> [ReaderReadingRecord] {
        struct Result: Decodable { let records: [ReaderReadingRecord] }
        return try decode(Result.self, await coreRead("read-record.list", deviceID.map { ["deviceId": $0] } ?? [:])).records
    }
    public func readingSummary(query: String?, sortBy: ReaderReadingRecordSort) async throws -> ReaderReadingSummary {
        var params: [String: Any] = ["sortBy": sortBy.rawValue]
        if let query { params["query"] = query }
        return try decode(ReaderReadingSummary.self, await coreRead("read-record.summary", params))
    }
    public func accumulateReadingTime(for book: ReaderBook, deviceID: String, elapsedMillis: Int64, readAt: Int64,
                                      sequence: UInt64, operationID: String) async throws -> ReaderReadingRecord {
        struct Result: Decodable { let record: ReaderReadingRecord }
        let result = try decode(Result.self, await coreMutation("read-record.accumulate", [
            "deviceId": deviceID, "bookName": book.title, "author": book.author,
            "elapsedMillis": elapsedMillis, "readAt": readAt, "operationId": deviceID + "/" + String(sequence), "sequence": sequence
        ], operationID: operationID, scope: "reading-time"))
        guard result.record.deviceId == deviceID, result.record.bookName == book.title else {
            throw ReaderLibraryError.invalidResponse("reading time receipt identity")
        }
        try await finishCoreOperation(operationID)
        return result.record
    }
    public func deleteReadingRecords(bookName: String, operationID: String) async throws -> UInt64 {
        struct Result: Decodable { let bookName: String; let deletedCount: UInt64 }
        let result = try decode(Result.self, await coreMutation("read-record.deleteByBook", ["bookName": bookName],
                                                               operationID: operationID, scope: "reading-time"))
        guard result.bookName == bookName else { throw ReaderLibraryError.invalidResponse("reading records delete identity") }
        try await finishCoreOperation(operationID)
        return result.deletedCount
    }

    public func validateReplaceRule(_ draft: ReaderReplaceRuleDraft) async throws -> ReaderReplaceValidation {
        var scopes: [String] = []
        if draft.scopeContent { scopes.append("chapter") }
        if draft.scopeTitle { scopes.append("title") }
        if draft.scopeSource { scopes.append("source") }
        return try decode(ReaderReplaceValidation.self, await coreRead("replace.validate", [
            "pattern": draft.pattern, "isRegex": draft.isRegex, "scope": scopes
        ]))
    }
    /// Pure projection using stored rules; it does not persist text or modify the original book.
    public func processText(_ text: String, for book: ReaderBook, target: ReaderReplaceTarget) async throws -> ReaderReplaceApplication {
        try decode(ReaderReplaceApplication.self, await coreRead("replace.apply", [
            "text": text, "bookName": book.title, "bookOrigin": book.sourceId, "target": target.rawValue
        ]))
    }
    /// Previews currently stored rules, not an unsaved draft rule.
    public func previewReplacement(for book: ReaderBook, chapterIndex: UInt32, maxScalars: UInt32) async throws -> ReaderReplacePreview {
        let result = try decode(ReaderReplacePreview.self, await coreRead("replace.preview", [
            "sourceId": book.sourceId, "bookId": book.bookId, "chapterIndex": chapterIndex, "maxScalars": maxScalars
        ]))
        guard result.sourceId == book.sourceId, result.bookId == book.bookId, result.chapterIndex == chapterIndex else {
            throw ReaderLibraryError.invalidResponse("replacement preview identity")
        }
        return result
    }

    public func replaceRules(enabledOnly: Bool) async throws -> [ReaderReplaceRule] {
        struct Result: Decodable { let rules: [ReaderReplaceRule] }
        return try decode(Result.self, await coreRead("replace-rule.list", ["enabledOnly": enabledOnly])).rules
    }
    public func createReplaceRule(_ draft: ReaderReplaceRuleDraft, operationID: String) async throws -> ReaderReplaceRule {
        struct Result: Decodable { let rule: ReaderReplaceRule }
        let result = try decode(Result.self, await toolsPersistReplace("create", parameters: try toolsObject(draft), operationID: operationID))
        try await finishCoreOperation(operationID)
        return result.rule
    }
    public func updateReplaceRule(id: Int64, draft: ReaderReplaceRuleDraft, operationID: String) async throws -> ReaderReplaceRule {
        struct Result: Decodable { let rule: ReaderReplaceRule }
        var params = try toolsObject(draft); params["id"] = id
        let result = try decode(Result.self, await toolsPersistReplace("update", parameters: params, operationID: operationID))
        guard result.rule.id == id else { throw ReaderLibraryError.invalidResponse("replace rule update identity") }
        try await finishCoreOperation(operationID)
        return result.rule
    }
    public func deleteReplaceRule(id: Int64, operationID: String) async throws -> Bool {
        struct Result: Decodable { let id: Int64; let deleted: Bool }
        let result = try decode(Result.self, await toolsPersistReplace("delete", parameters: ["id": id], operationID: operationID))
        guard result.id == id else { throw ReaderLibraryError.invalidResponse("replace delete identity") }
        try await finishCoreOperation(operationID)
        return result.deleted
    }
    private func toolsPersistReplace(_ operation: String, parameters: [String: Any], operationID: String) async throws -> Data {
        let result = try object(await rulesMutation("replace.persist", ["operation": operation, "params": parameters,
            "transactionId": operationID], operationID: operationID))
        guard result["operation"] as? String == operation, let data = result["data"] as? [String: Any],
              let token = result["undoToken"] as? [String: Any], token["transactionId"] as? String == operationID else {
            throw ReaderLibraryError.operationPending(operationID)
        }
        return try JSONSerialization.data(withJSONObject: data)
    }
    public func txtTOCRules(enabledOnly: Bool) async throws -> [ReaderTXTTOCRule] {
        struct Result: Decodable { let rules: [ReaderTXTTOCRule] }
        return try decode(Result.self, await coreRead("txt-toc-rule.list", ["enabledOnly": enabledOnly])).rules
    }
    public func previewTXTTOCRule(for book: ReaderBook, draft: ReaderTXTTOCRuleDraft,
                                  editingRuleID: Int64?, limit: UInt32) async throws -> ReaderTXTTOCRulePreview {
        guard book.sourceId == "local" else { throw ReaderLibraryError.unsupportedFile }
        guard (1...64).contains(limit) else { throw ReaderLibraryError.invalidResponse("TXT preview limit") }
        // This existing authorization verifies the content-addressed regular
        // sandbox original and its SHA. Never accept a caller-supplied path.
        let original = try retainedSourceURL(for: book)
        let sourceSHA = String(book.bookId.dropFirst("local:".count))
        var parameters: [String: Any] = ["bookId": book.bookId, "filePath": original.path,
                                       "draft": try toolsObject(draft), "limit": limit]
        if let editingRuleID { parameters["editingRuleId"] = editingRuleID }
        let result = try decode(ReaderTXTTOCRulePreview.self,
                                await coreRead("txt-toc-rule.preview", parameters, timeout: 120))
        try Task.checkCancellation()
        let digests = [result.sourceSha256, result.draftSha256, result.savedRulesSha256, result.effectiveRulesSha256]
        guard result.sourceId == book.sourceId, result.bookId == book.bookId, result.sourceSha256 == sourceSHA,
              digests.allSatisfy({ value in value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) } }),
              result.chapters.count == Int(min(limit, result.chapterCount)),
              result.truncated == (result.chapterCount > limit),
              result.chapters.enumerated().allSatisfy({ $0.element.index == UInt32($0.offset) && $0.element.startScalar <= $0.element.endScalar }),
              zip(result.chapters, result.chapters.dropFirst()).allSatisfy({ $0.0.endScalar <= $0.1.startScalar }),
              result.automaticFallback == (result.selectedRule == nil),
              result.draftSelected == (result.selectedRule?.kind == .draft),
              result.draftSelected == (result.draftStatus == .selected) else {
            throw ReaderLibraryError.invalidResponse("TXT draft preview identity or range")
        }
        if let selected = result.selectedRule {
            switch selected.kind {
            case .draft:
                guard selected.ruleId == editingRuleID else { throw ReaderLibraryError.invalidResponse("TXT draft preview saved identity") }
            case .saved:
                guard selected.ruleId != nil, selected.ruleId != editingRuleID else {
                    throw ReaderLibraryError.invalidResponse("TXT draft preview priority identity")
                }
            }
        }
        guard try retainedSourceURL(for: book) == original else { throw ReaderLibraryError.invalidResponse("TXT preview original changed") }
        return result
    }
    public func createTXTTOCRule(_ draft: ReaderTXTTOCRuleDraft, operationID: String) async throws -> ReaderTXTTOCRule {
        struct Result: Decodable { let rule: ReaderTXTTOCRule }
        let result = try decode(Result.self, await rulesMutation("txt-toc-rule.create", try toolsObject(draft), operationID: operationID))
        try await finishCoreOperation(operationID)
        return result.rule
    }
    public func updateTXTTOCRule(id: Int64, draft: ReaderTXTTOCRuleDraft, operationID: String) async throws -> ReaderTXTTOCRule {
        struct Result: Decodable { let rule: ReaderTXTTOCRule }
        var params = try toolsObject(draft); params["id"] = id
        let result = try decode(Result.self, await rulesMutation("txt-toc-rule.update", params, operationID: operationID))
        guard result.rule.id == id else { throw ReaderLibraryError.invalidResponse("TXT rule update identity") }
        try await finishCoreOperation(operationID)
        return result.rule
    }
    public func deleteTXTTOCRule(id: Int64, operationID: String) async throws -> Bool {
        try await toolsDeleteRule("txt-toc-rule.delete", id: id, operationID: operationID)
    }
    private func toolsDeleteRule(_ method: String, id: Int64, operationID: String) async throws -> Bool {
        struct Result: Decodable { let id: Int64; let deleted: Bool }
        let result = try decode(Result.self, await rulesMutation(method, ["id": id], operationID: operationID))
        guard result.id == id else { throw ReaderLibraryError.invalidResponse("rule delete identity") }
        try await finishCoreOperation(operationID)
        return result.deleted
    }
    public func dictionaryRules() async throws -> [ReaderDictionaryRule] {
        struct Result: Decodable { let rules: [ReaderDictionaryRule] }
        return try decode(Result.self, await coreRead("dict-rule.list", [:])).rules
    }
    public func putDictionaryRule(_ rule: ReaderDictionaryRule, operationID: String) async throws -> ReaderDictionaryRule {
        struct Result: Decodable { let rule: ReaderDictionaryRule }
        let result = try decode(Result.self, await rulesMutation("dict-rule.put", try toolsObject(rule), operationID: operationID))
        guard result.rule.name == rule.name else { throw ReaderLibraryError.invalidResponse("dictionary rule identity") }
        try await finishCoreOperation(operationID)
        return result.rule
    }
    public func deleteDictionaryRule(name: String, operationID: String) async throws -> Bool {
        struct Result: Decodable { let name: String; let deleted: Bool }
        let result = try decode(Result.self, await rulesMutation("dict-rule.delete", ["name": name], operationID: operationID))
        guard result.name == name else { throw ReaderLibraryError.invalidResponse("dictionary delete identity") }
        try await finishCoreOperation(operationID)
        return result.deleted
    }
    public func queryDictionary(ruleName: String, word: String) async throws -> String {
        struct Result: Decodable { let definition: String }
        return try decode(Result.self, await coreRead("dict-rule.query", ["ruleName": ruleName, "word": word])).definition
    }
    public func exportRuleBundle() async throws -> ReaderRuleBundle {
        try decode(ReaderRuleBundle.self, await coreRead("rule-bundle.export", [:]))
    }
    public func importRuleBundle(json: String, replaceExisting: Bool, operationID: String) async throws -> ReaderRuleBundleImport {
        let result = try decode(ReaderRuleBundleImport.self, await rulesMutation("rule-bundle.import", [
            "json": json, "replaceExisting": replaceExisting
        ], operationID: operationID))
        guard result.schemaVersion == 1, result.replaceExisting == replaceExisting else {
            throw ReaderLibraryError.invalidResponse("rule bundle import receipt")
        }
        try await finishCoreOperation(operationID)
        return result
    }

    public func directoryRules(for book: ReaderBook) async throws -> ReaderDirectoryRulesResult {
        try toolsValidateDirectory(try decode(ReaderDirectoryRulesResult.self,
                                              await coreRead("reading.directory.rules.get.v2", toolsDirectoryParams(book))), for: book)
    }
    public func prepareDirectoryRules(for book: ReaderBook, operationID: String) async throws -> ReaderDirectoryRulesResult {
        // prepare publishes derived display caches. Its ACK is a write receipt,
        // not a get/preview result reconstructed after a timeout.
        let result = try toolsValidateDirectory(try decode(ReaderDirectoryRulesResult.self,
            await coreMutation("reading.directory.rules.prepare.v2", toolsDirectoryParams(book), operationID: operationID,
                               scope: "directory-preparation:" + book.id)), for: book)
        try await finishCoreOperation(operationID)
        return result
    }
    public func previewDirectoryRules(for book: ReaderBook, rules: [ReaderDirectoryHierarchyRule]) async throws -> ReaderDirectoryRulesResult {
        var params = try toolsDirectoryParams(book); params["rules"] = try toolsArray(rules)
        return try toolsValidateDirectory(try decode(ReaderDirectoryRulesResult.self,
            await coreRead("reading.directory.rules.preview.v2", params, timeout: 120)), for: book)
    }
    public func applyDirectoryRules(for book: ReaderBook, rules: [ReaderDirectoryHierarchyRule], operationID: String) async throws -> ReaderDirectoryRulesResult {
        var params = try toolsDirectoryParams(book); params["rules"] = try toolsArray(rules)
        let result = try toolsValidateDirectory(try decode(ReaderDirectoryRulesResult.self,
            await rulesMutation("reading.directory.rules.apply.v2", params, operationID: operationID)), for: book)
        try await finishCoreOperation(operationID)
        return result
    }
    private func toolsDirectoryParams(_ book: ReaderBook) throws -> [String: Any] {
        guard book.sourceId == "local" else { throw ReaderLibraryError.unsupportedFile }
        return ["sourceId": book.sourceId, "bookId": book.bookId]
    }
    private func toolsValidateDirectory(_ result: ReaderDirectoryRulesResult, for book: ReaderBook) throws -> ReaderDirectoryRulesResult {
        guard ["ready", "unavailable"].contains(result.status),
              result.sourceId == nil || result.sourceId == book.sourceId,
              result.bookId == nil || result.bookId == book.bookId else { throw ReaderLibraryError.invalidResponse("directory rules identity") }
        return result
    }
}

private func toolsObject<T: Encodable>(_ value: T) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any] else {
        throw ReaderLibraryError.invalidResponse("tool request object")
    }
    return object
}
private func toolsArray<T: Encodable>(_ value: T) throws -> [Any] {
    guard let array = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [Any] else {
        throw ReaderLibraryError.invalidResponse("tool request array")
    }
    return array
}
