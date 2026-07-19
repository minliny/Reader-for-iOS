import CoreFoundation
import Foundation
import ReaderCoreNativeAdapter

// MARK: - Slice 10 business entities

/// Core-owned bookmark entity. The shape intentionally mirrors
/// `reader-contract::BookmarkData`; it does not invent a source id, book id,
/// chapter URL, or percentage that the Core contract does not carry.
public struct ReaderCoreBookmark: Equatable, Sendable, Identifiable {
    public var id: Int64 { time }
    public let time: Int64
    public let bookName: String
    public let bookAuthor: String
    public let chapterIndex: Int
    public let chapterPosition: Int
    public let chapterName: String
    public let bookText: String
    public let content: String

    public var createdAt: Date {
        Date(timeIntervalSince1970: TimeInterval(time) / 1_000)
    }
}

public struct ReaderCoreBookmarkDraft: Equatable, Sendable {
    public let bookName: String
    public let bookAuthor: String
    public let chapterIndex: Int
    public let chapterPosition: Int
    public let chapterName: String
    public let bookText: String
    public let content: String

    public init(
        bookName: String,
        bookAuthor: String = "",
        chapterIndex: Int,
        chapterPosition: Int,
        chapterName: String,
        bookText: String = "",
        content: String = ""
    ) {
        self.bookName = bookName
        self.bookAuthor = bookAuthor
        self.chapterIndex = chapterIndex
        self.chapterPosition = chapterPosition
        self.chapterName = chapterName
        self.bookText = bookText
        self.content = content
    }
}

public struct ReaderCoreReadRecord: Equatable, Sendable, Identifiable {
    public var id: String { "\(deviceID)::\(bookName)" }
    public let deviceID: String
    public let bookName: String
    public let readTime: Int64
    public let lastRead: Int64
}

public struct ReaderCoreContentSearchMatch: Equatable, Sendable, Identifiable {
    public var id: String { "\(sourceID)::\(bookID)::\(chapterIndex)::\(chapterOffset)" }
    public let sourceID: String
    public let bookID: String
    public let bookName: String
    public let chapterIndex: Int
    public let chapterOffset: Int
    public let matchLength: Int
    public let snippetStart: Int
    public let chapterTitle: String
    public let snippet: String
}

public struct ReaderCoreContentEdit: Equatable, Sendable, Identifiable {
    public var id: String { editID.map(String.init) ?? "\(bookID)::\(chapterIndex)" }
    public let editID: Int64?
    public let bookID: String
    public let chapterIndex: Int
    public let editedContent: String
    public let editedAt: Int64
}

public struct ReaderCoreReplaceRule: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let name: String
    public let group: String?
    public let pattern: String
    public let replacement: String
    public let scope: String?
    public let scopeTitle: Bool
    public let scopeContent: Bool
    public let excludeScope: String?
    public let isEnabled: Bool
    public let isRegex: Bool
    public let timeoutMilliseconds: Int64
    public let order: Int
}

public struct ReaderCoreReplaceRuleDraft: Equatable, Sendable {
    public let name: String
    public let group: String?
    public let pattern: String
    public let replacement: String
    public let scope: String?
    public let scopeTitle: Bool
    public let scopeContent: Bool
    public let excludeScope: String?
    public let isEnabled: Bool
    public let isRegex: Bool
    public let timeoutMilliseconds: Int64
    public let order: Int

    public init(
        name: String,
        group: String? = nil,
        pattern: String,
        replacement: String,
        scope: String? = nil,
        scopeTitle: Bool = false,
        scopeContent: Bool = true,
        excludeScope: String? = nil,
        isEnabled: Bool = true,
        isRegex: Bool = true,
        timeoutMilliseconds: Int64 = 3_000,
        order: Int = 0
    ) {
        self.name = name
        self.group = group
        self.pattern = pattern
        self.replacement = replacement
        self.scope = scope
        self.scopeTitle = scopeTitle
        self.scopeContent = scopeContent
        self.excludeScope = excludeScope
        self.isEnabled = isEnabled
        self.isRegex = isRegex
        self.timeoutMilliseconds = timeoutMilliseconds
        self.order = order
    }
}

public struct ReaderCoreTxtTocRule: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let name: String
    public let rule: String
    public let example: String?
    public let serialNumber: Int
    public let isEnabled: Bool
}

public struct ReaderCoreTxtTocRuleDraft: Equatable, Sendable {
    public let name: String
    public let rule: String
    public let example: String?
    public let serialNumber: Int
    public let isEnabled: Bool

    public init(
        name: String,
        rule: String,
        example: String? = nil,
        serialNumber: Int = 0,
        isEnabled: Bool = true
    ) {
        self.name = name
        self.rule = rule
        self.example = example
        self.serialNumber = serialNumber
        self.isEnabled = isEnabled
    }
}

public struct ReaderCoreSourceSwitchCandidate: Equatable, Sendable, Identifiable {
    public var id: String { "\(sourceID)::\(bookURL)" }
    public let sourceID: String
    public let bookURL: String
    public let bookName: String
    public let author: String?
    public let coverURL: String?
}

public struct ReaderCoreChapterReview: Equatable, Sendable, Identifiable {
    public var id: String {
        "\(reviewURL ?? "")::\(author ?? "")::\(postTime ?? "")::\(content ?? "")"
    }
    public let reviewURL: String?
    public let author: String?
    public let content: String?
    public let postTime: String?
    public let rating: String?
}

/// Credential-free subset that iOS can safely persist through Core today.
/// Header/login fields are deliberately absent: credentials and Cookies stay
/// in Host storage until Core exposes an opaque credential-reference field.
public struct ReaderCoreHttpTTSSafeDraft: Equatable, Sendable {
    public let id: Int64
    public let name: String
    public let urlTemplate: String
    public let contentType: String?
    public let concurrentRate: String?
    public let lastUpdateTime: Int64

    public init(
        id: Int64,
        name: String,
        urlTemplate: String,
        contentType: String? = nil,
        concurrentRate: String? = nil,
        lastUpdateTime: Int64 = Int64(Date().timeIntervalSince1970 * 1_000)
    ) {
        self.id = id
        self.name = name
        self.urlTemplate = urlTemplate
        self.contentType = contentType
        self.concurrentRate = concurrentRate
        self.lastUpdateTime = lastUpdateTime
    }
}

public struct ReaderCoreHttpTTSConfigSummary: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let name: String
    public let urlTemplate: String
    public let contentType: String?
    public let concurrentRate: String?
    /// Existing rows created elsewhere may contain Core-stored headers/login
    /// material. iOS reports that fact but never projects the secret values.
    public let requiresHostCredentialMigration: Bool
    public let lastUpdateTime: Int64
}

public struct ReaderCoreHttpTTSRequestDescriptor: Equatable, Sendable {
    public let method: String
    public let url: String
    public let body: String?
    public let contentType: String?
    public let concurrentRate: String?
}

// MARK: - Narrow UI seams

public protocol ReaderSlice10ReadingDataServicing: AnyObject {
    func createBookmark(
        _ draft: ReaderCoreBookmarkDraft,
        correlationID: String?
    ) async throws -> ReaderCoreBookmark

    func listBookmarks(
        bookName: String?,
        bookAuthor: String?,
        correlationID: String?
    ) async throws -> [ReaderCoreBookmark]

    func deleteBookmark(time: Int64, correlationID: String?) async throws -> Bool

    func upsertReadRecord(
        deviceID: String,
        bookName: String,
        readTime: Int64,
        lastRead: Int64,
        correlationID: String?
    ) async throws -> ReaderCoreReadRecord

    func listReadRecords(
        deviceID: String?,
        correlationID: String?
    ) async throws -> [ReaderCoreReadRecord]
}

public protocol ReaderSlice10SearchHistoryServicing: AnyObject {
    func listSearchHistory(limit: Int, correlationID: String?) async throws -> [String]
    func addSearchHistory(_ keyword: String, correlationID: String?) async throws
    func clearSearchHistory(correlationID: String?) async throws -> Int
}

public enum ReaderSlice10CoreServiceError: Error, Equatable, LocalizedError, Sendable {
    case failedClosed(code: String, message: String)
    case invalidResult(method: String, message: String)

    public var code: String {
        switch self {
        case .failedClosed(let code, _): return code
        case .invalidResult: return "SLICE10_CORE_INVALID_RESULT"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .failedClosed(let code, let message): return "[\(code)] \(message)"
        case .invalidResult(let method, let message): return "[SLICE10_CORE_INVALID_RESULT] \(method): \(message)"
        }
    }
}

private struct ReaderSlice10RawResult: @unchecked Sendable {
    let data: [String: Any]
}

/// Request-scoped production bridge for every currently executable Slice 10
/// Core contract. Core remains the sole owner of persisted business entities;
/// this type only validates input, maps typed values, and routes Core-emitted
/// Host work through `HostRequestRouter`.
public final class ReaderSlice10CoreService: ReaderSlice10ReadingDataServicing, ReaderSlice10SearchHistoryServicing, @unchecked Sendable {
    private let runtime: any RustCoreCommandRuntime
    private let router: (any RustCoreHostRequestRouting)?
    private let requestTimeout: TimeInterval

    public init(
        runtime: any RustCoreCommandRuntime,
        router: (any RustCoreHostRequestRouting)? = nil,
        requestTimeout: TimeInterval = 15
    ) {
        self.runtime = runtime
        self.router = router
        self.requestTimeout = requestTimeout
    }

    public convenience init(runtime: ReaderCoreNativeRuntime, requestTimeout: TimeInterval = 15) {
        self.init(
            runtime: runtime,
            router: RustCoreServiceSupport.makeRouter(runtime: runtime),
            requestTimeout: requestTimeout
        )
    }

    @MainActor
    public static func production(requestTimeout: TimeInterval = 15) throws -> ReaderSlice10CoreService {
        guard ReaderCoreAggregateStorageGate.isReady else {
            let message: String
            switch ReaderCoreAggregateStorageGate.state {
            case .notStarted: message = "Core aggregate storage bootstrap has not started"
            case .restoring: message = "Core aggregate storage restore is still running"
            case .failed(let failure): message = "Core aggregate storage restore failed: \(failure)"
            case .ready: message = "Core aggregate storage is unavailable"
            }
            throw ReaderSlice10CoreServiceError.failedClosed(
                code: "SLICE10_STORAGE_NOT_READY",
                message: message
            )
        }
        guard let runtime = RustCoreRuntimeHolder.shared.current else {
            throw ReaderSlice10CoreServiceError.failedClosed(
                code: "SLICE10_CORE_NOT_BOOTED",
                message: "Reader Core runtime is unavailable"
            )
        }
        return ReaderSlice10CoreService(runtime: runtime, requestTimeout: requestTimeout)
    }

    // MARK: Bookmark

    public func createBookmark(
        _ draft: ReaderCoreBookmarkDraft,
        correlationID: String? = nil
    ) async throws -> ReaderCoreBookmark {
        try Self.requireNonBlank(draft.bookName, code: "SLICE10_BOOK_NAME_MISSING", field: "bookName")
        try Self.requireNonNegative(draft.chapterIndex, field: "chapterIndex")
        try Self.requireNonNegative(draft.chapterPosition, field: "chapterPos")
        let data = try await execute(
            "bookmark.create",
            params: bookmarkParams(draft),
            correlationID: correlationID
        )
        return try Self.parseBookmarkEnvelope(data, method: "bookmark.create")
    }

    public func listBookmarks(
        bookName: String? = nil,
        bookAuthor: String? = nil,
        correlationID: String? = nil
    ) async throws -> [ReaderCoreBookmark] {
        var params: [String: Any] = [:]
        // Core filters only when both values are present. Passing one and
        // silently returning everything is error-prone, so reject that shape.
        if bookName != nil || bookAuthor != nil {
            guard let bookName, let bookAuthor else {
                throw ReaderSlice10CoreServiceError.failedClosed(
                    code: "SLICE10_BOOKMARK_FILTER_INCOMPLETE",
                    message: "bookmark.list requires both bookName and bookAuthor for scoped results"
                )
            }
            params["bookName"] = bookName
            params["bookAuthor"] = bookAuthor
        }
        let data = try await execute("bookmark.list", params: params, correlationID: correlationID)
        return try Self.parseArray(data["bookmarks"], method: "bookmark.list", field: "bookmarks", parser: Self.parseBookmark)
    }

    public func updateBookmark(
        time: Int64,
        draft: ReaderCoreBookmarkDraft,
        correlationID: String? = nil
    ) async throws -> ReaderCoreBookmark {
        try Self.requireNonBlank(draft.bookName, code: "SLICE10_BOOK_NAME_MISSING", field: "bookName")
        var params = bookmarkParams(draft)
        params["time"] = time
        let data = try await execute("bookmark.update", params: params, correlationID: correlationID)
        return try Self.parseBookmarkEnvelope(data, method: "bookmark.update")
    }

    public func deleteBookmark(time: Int64, correlationID: String? = nil) async throws -> Bool {
        let data = try await execute("bookmark.delete", params: ["time": time], correlationID: correlationID)
        return try Self.requireBool(data["deleted"], method: "bookmark.delete", field: "deleted")
    }

    // MARK: Read record

    public func upsertReadRecord(
        deviceID: String,
        bookName: String,
        readTime: Int64,
        lastRead: Int64,
        correlationID: String? = nil
    ) async throws -> ReaderCoreReadRecord {
        try Self.requireNonBlank(bookName, code: "SLICE10_BOOK_NAME_MISSING", field: "bookName")
        guard readTime >= 0, lastRead >= 0 else {
            throw ReaderSlice10CoreServiceError.failedClosed(
                code: "SLICE10_READ_RECORD_INVALID",
                message: "readTime and lastRead must be non-negative"
            )
        }
        let data = try await execute(
            "read-record.create",
            params: [
                "deviceId": deviceID,
                "bookName": bookName,
                "readTime": readTime,
                "lastRead": lastRead,
            ],
            correlationID: correlationID
        )
        return try Self.parseReadRecordEnvelope(data, method: "read-record.create")
    }

    public func listReadRecords(
        deviceID: String? = nil,
        correlationID: String? = nil
    ) async throws -> [ReaderCoreReadRecord] {
        let params = deviceID.map { ["deviceId": $0] } ?? [:]
        let data = try await execute("read-record.list", params: params, correlationID: correlationID)
        return try Self.parseArray(data["records"], method: "read-record.list", field: "records", parser: Self.parseReadRecord)
    }

    public func updateReadRecord(
        deviceID: String,
        bookName: String,
        readTime: Int64? = nil,
        lastRead: Int64? = nil,
        correlationID: String? = nil
    ) async throws -> ReaderCoreReadRecord {
        guard readTime != nil || lastRead != nil else {
            throw ReaderSlice10CoreServiceError.failedClosed(
                code: "SLICE10_READ_RECORD_UPDATE_EMPTY",
                message: "read-record.update requires at least one changed field"
            )
        }
        var params: [String: Any] = ["deviceId": deviceID, "bookName": bookName]
        if let readTime { params["readTime"] = readTime }
        if let lastRead { params["lastRead"] = lastRead }
        let data = try await execute("read-record.update", params: params, correlationID: correlationID)
        return try Self.parseReadRecordEnvelope(data, method: "read-record.update")
    }

    public func deleteReadRecord(
        deviceID: String,
        bookName: String,
        correlationID: String? = nil
    ) async throws -> Bool {
        let data = try await execute(
            "read-record.delete",
            params: ["deviceId": deviceID, "bookName": bookName],
            correlationID: correlationID
        )
        return try Self.requireBool(data["deleted"], method: "read-record.delete", field: "deleted")
    }

    // MARK: Search history + cached content search

    public func listSearchHistory(limit: Int = 10, correlationID: String? = nil) async throws -> [String] {
        guard limit > 0 else {
            throw ReaderSlice10CoreServiceError.failedClosed(
                code: "SLICE10_SEARCH_HISTORY_LIMIT_INVALID",
                message: "search.history.list limit must be positive"
            )
        }
        let data = try await execute(
            "search.history.list",
            params: ["limit": limit],
            correlationID: correlationID
        )
        guard let keywords = data["keywords"] as? [String] else {
            throw Self.invalidResult("search.history.list", "keywords must be a string array")
        }
        return keywords
    }

    public func addSearchHistory(_ keyword: String, correlationID: String? = nil) async throws {
        try Self.requireNonBlank(keyword, code: "SLICE10_SEARCH_KEYWORD_EMPTY", field: "keyword")
        _ = try await execute(
            "search.history.add",
            params: ["keyword": keyword.trimmingCharacters(in: .whitespacesAndNewlines)],
            correlationID: correlationID
        )
    }

    public func clearSearchHistory(correlationID: String? = nil) async throws -> Int {
        let data = try await execute("search.history.clear", params: [:], correlationID: correlationID)
        return try Self.requireInteger(data["cleared"], method: "search.history.clear", field: "cleared")
    }

    public func searchCachedContent(
        keyword: String,
        sourceID: String? = nil,
        bookID: String? = nil,
        maximumResults: Int? = nil,
        correlationID: String? = nil
    ) async throws -> [ReaderCoreContentSearchMatch] {
        try Self.requireNonBlank(keyword, code: "SLICE10_CONTENT_SEARCH_EMPTY", field: "keyword")
        var params: [String: Any] = ["keyword": keyword]
        if let sourceID { params["sourceId"] = sourceID }
        if let bookID { params["bookId"] = bookID }
        if let maximumResults {
            guard maximumResults > 0 else {
                throw ReaderSlice10CoreServiceError.failedClosed(
                    code: "SLICE10_CONTENT_SEARCH_LIMIT_INVALID",
                    message: "search.content maxResults must be positive"
                )
            }
            params["maxResults"] = maximumResults
        }
        let data = try await execute("search.content", params: params, correlationID: correlationID)
        return try Self.parseArray(data["results"], method: "search.content", field: "results", parser: Self.parseContentSearchMatch)
    }

    // MARK: Content edit

    public func putContentEdit(
        bookID: String,
        chapterIndex: Int,
        editedContent: String,
        editedAt: Int64 = Int64(Date().timeIntervalSince1970 * 1_000),
        correlationID: String? = nil
    ) async throws -> ReaderCoreContentEdit {
        try Self.requireNonBlank(bookID, code: "SLICE10_CONTENT_EDIT_BOOK_MISSING", field: "bookId")
        try Self.requireNonNegative(chapterIndex, field: "chapterIndex")
        let data = try await execute(
            "content-edit.put",
            params: [
                "bookId": bookID,
                "chapterIndex": chapterIndex,
                "editedContent": editedContent,
                "editedAt": editedAt,
            ],
            correlationID: correlationID
        )
        return try Self.parseContentEditEnvelope(data, method: "content-edit.put", optional: false)!
    }

    public func getContentEdit(
        bookID: String,
        chapterIndex: Int,
        correlationID: String? = nil
    ) async throws -> ReaderCoreContentEdit? {
        let data = try await execute(
            "content-edit.get",
            params: ["bookId": bookID, "chapterIndex": chapterIndex],
            correlationID: correlationID
        )
        return try Self.parseContentEditEnvelope(data, method: "content-edit.get", optional: true)
    }

    public func listContentEdits(bookID: String, correlationID: String? = nil) async throws -> [ReaderCoreContentEdit] {
        let data = try await execute("content-edit.list", params: ["bookId": bookID], correlationID: correlationID)
        return try Self.parseArray(data["edits"], method: "content-edit.list", field: "edits", parser: Self.parseContentEdit)
    }

    public func deleteContentEdit(
        editID: Int64? = nil,
        bookID: String? = nil,
        correlationID: String? = nil
    ) async throws -> Int {
        guard (editID == nil) != (bookID == nil) else {
            throw ReaderSlice10CoreServiceError.failedClosed(
                code: "SLICE10_CONTENT_EDIT_DELETE_SCOPE_INVALID",
                message: "content-edit.delete requires exactly one of editId or bookId"
            )
        }
        var params: [String: Any] = [:]
        if let editID { params["editId"] = editID }
        if let bookID { params["bookId"] = bookID }
        let data = try await execute("content-edit.delete", params: params, correlationID: correlationID)
        return try Self.requireInteger(data["deleted"], method: "content-edit.delete", field: "deleted")
    }

    // MARK: ReplaceRule + TxtTocRule

    public func createReplaceRule(
        _ draft: ReaderCoreReplaceRuleDraft,
        correlationID: String? = nil
    ) async throws -> ReaderCoreReplaceRule {
        try validateReplaceRule(draft)
        let data = try await execute("replace-rule.create", params: replaceRuleParams(draft), correlationID: correlationID)
        return try Self.parseReplaceRuleEnvelope(data, method: "replace-rule.create")
    }

    public func listReplaceRules(enabledOnly: Bool? = nil, correlationID: String? = nil) async throws -> [ReaderCoreReplaceRule] {
        let params = enabledOnly.map { ["enabledOnly": $0] } ?? [:]
        let data = try await execute("replace-rule.list", params: params, correlationID: correlationID)
        return try Self.parseArray(data["rules"], method: "replace-rule.list", field: "rules", parser: Self.parseReplaceRule)
    }

    public func updateReplaceRule(
        id: Int64,
        draft: ReaderCoreReplaceRuleDraft,
        correlationID: String? = nil
    ) async throws -> ReaderCoreReplaceRule {
        try validateReplaceRule(draft)
        var params = replaceRuleParams(draft)
        params["id"] = id
        let data = try await execute("replace-rule.update", params: params, correlationID: correlationID)
        return try Self.parseReplaceRuleEnvelope(data, method: "replace-rule.update")
    }

    public func deleteReplaceRule(id: Int64, correlationID: String? = nil) async throws -> Bool {
        let data = try await execute("replace-rule.delete", params: ["id": id], correlationID: correlationID)
        return try Self.requireBool(data["deleted"], method: "replace-rule.delete", field: "deleted")
    }

    public func createTxtTocRule(
        _ draft: ReaderCoreTxtTocRuleDraft,
        correlationID: String? = nil
    ) async throws -> ReaderCoreTxtTocRule {
        try validateTxtTocRule(draft)
        let data = try await execute("txt-toc-rule.create", params: txtTocRuleParams(draft), correlationID: correlationID)
        return try Self.parseTxtTocRuleEnvelope(data, method: "txt-toc-rule.create")
    }

    public func listTxtTocRules(enabledOnly: Bool? = nil, correlationID: String? = nil) async throws -> [ReaderCoreTxtTocRule] {
        let params = enabledOnly.map { ["enabledOnly": $0] } ?? [:]
        let data = try await execute("txt-toc-rule.list", params: params, correlationID: correlationID)
        return try Self.parseArray(data["rules"], method: "txt-toc-rule.list", field: "rules", parser: Self.parseTxtTocRule)
    }

    public func updateTxtTocRule(
        id: Int64,
        draft: ReaderCoreTxtTocRuleDraft,
        correlationID: String? = nil
    ) async throws -> ReaderCoreTxtTocRule {
        try validateTxtTocRule(draft)
        var params = txtTocRuleParams(draft)
        params["id"] = id
        let data = try await execute("txt-toc-rule.update", params: params, correlationID: correlationID)
        return try Self.parseTxtTocRuleEnvelope(data, method: "txt-toc-rule.update")
    }

    public func deleteTxtTocRule(id: Int64, correlationID: String? = nil) async throws -> Bool {
        let data = try await execute("txt-toc-rule.delete", params: ["id": id], correlationID: correlationID)
        return try Self.requireBool(data["deleted"], method: "txt-toc-rule.delete", field: "deleted")
    }

    // MARK: Dictionary, source switch, cover, reviews

    public func queryDictionary(
        ruleName: String,
        word: String,
        correlationID: String? = nil
    ) async throws -> String {
        try Self.requireNonBlank(ruleName, code: "SLICE10_DICT_RULE_MISSING", field: "ruleName")
        try Self.requireNonBlank(word, code: "SLICE10_DICT_WORD_EMPTY", field: "word")
        let data = try await execute(
            "dict-rule.query",
            params: ["ruleName": ruleName, "word": word],
            correlationID: correlationID
        )
        return try Self.requireString(data["definition"], method: "dict-rule.query", field: "definition", allowEmpty: true)
    }

    /// Candidate discovery only. Source mutation is a separate Reader-UI
    /// compatibility transaction (`source.switch.commit/rollback`) and is not
    /// promoted into this typed-schema path.
    public func discoverSourceSwitchCandidates(
        bookID: String,
        keyword: String? = nil,
        sourceIDs: [String],
        correlationID: String? = nil
    ) async throws -> [ReaderCoreSourceSwitchCandidate] {
        try Self.requireNonBlank(bookID, code: "SLICE10_SOURCE_SWITCH_BOOK_MISSING", field: "bookId")
        guard !sourceIDs.isEmpty else {
            throw ReaderSlice10CoreServiceError.failedClosed(
                code: "SLICE10_SOURCE_SWITCH_SOURCES_EMPTY",
                message: "change.bookSource requires at least one sourceId"
            )
        }
        var params: [String: Any] = ["bookId": bookID, "sourceIds": sourceIDs]
        if let keyword { params["keyword"] = keyword }
        let data = try await execute("change.bookSource", params: params, correlationID: correlationID)
        return try Self.parseArray(data["candidates"], method: "change.bookSource", field: "candidates", parser: Self.parseSourceCandidate)
    }

    public func discoverCoverCandidates(
        bookID: String,
        sourceIDs: [String],
        correlationID: String? = nil
    ) async throws -> [String] {
        let data = try await execute(
            "change.cover",
            params: ["bookId": bookID, "sourceIds": sourceIDs],
            correlationID: correlationID
        )
        return try Self.requireStringArray(data["coverUrls"], method: "change.cover", field: "coverUrls")
    }

    public func searchCoverCandidates(
        bookName: String,
        author: String? = nil,
        sourceIDs: [String],
        correlationID: String? = nil
    ) async throws -> [String] {
        var params: [String: Any] = ["bookName": bookName, "sourceIds": sourceIDs]
        if let author { params["author"] = author }
        let data = try await execute("search.cover", params: params, correlationID: correlationID)
        return try Self.requireStringArray(data["coverUrls"], method: "search.cover", field: "coverUrls")
    }

    public func loadChapterReviews(
        sourceID: String,
        bookID: String,
        chapterURL: String? = nil,
        reviewURL: String? = nil,
        correlationID: String? = nil
    ) async throws -> [ReaderCoreChapterReview] {
        var params: [String: Any] = ["sourceId": sourceID, "bookId": bookID]
        if let chapterURL { params["chapterUrl"] = chapterURL }
        if let reviewURL { params["reviewUrl"] = reviewURL }
        let data = try await execute("book.chapterReview", params: params, correlationID: correlationID)
        return try Self.parseArray(data["reviews"], method: "book.chapterReview", field: "reviews", parser: Self.parseChapterReview)
    }

    // MARK: Credential-free HttpTTS descriptor

    public func putSafeHttpTTS(
        _ draft: ReaderCoreHttpTTSSafeDraft,
        correlationID: String? = nil
    ) async throws -> ReaderCoreHttpTTSConfigSummary {
        try Self.requireNonBlank(draft.name, code: "SLICE10_HTTP_TTS_NAME_EMPTY", field: "name")
        try Self.validateCredentialFreeURLTemplate(draft.urlTemplate)
        var params: [String: Any] = [
            "id": draft.id,
            "name": draft.name,
            "url": draft.urlTemplate,
            "lastUpdateTime": draft.lastUpdateTime,
        ]
        if let contentType = draft.contentType { params["contentType"] = contentType }
        if let concurrentRate = draft.concurrentRate { params["concurrentRate"] = concurrentRate }
        let data = try await execute("http-tts.put", params: params, correlationID: correlationID)
        return try Self.parseHttpTTSEnvelope(data, method: "http-tts.put", optional: false)!
    }

    public func getHttpTTS(id: Int64, correlationID: String? = nil) async throws -> ReaderCoreHttpTTSConfigSummary? {
        let data = try await execute("http-tts.get", params: ["id": id], correlationID: correlationID)
        return try Self.parseHttpTTSEnvelope(data, method: "http-tts.get", optional: true)
    }

    public func listHttpTTS(correlationID: String? = nil) async throws -> [ReaderCoreHttpTTSConfigSummary] {
        let data = try await execute("http-tts.list", params: [:], correlationID: correlationID)
        return try Self.parseArray(data["items"], method: "http-tts.list", field: "items", parser: Self.parseHttpTTS)
    }

    public func deleteHttpTTS(id: Int64, correlationID: String? = nil) async throws -> Bool {
        let data = try await execute("http-tts.delete", params: ["id": id], correlationID: correlationID)
        return try Self.requireBool(data["deleted"], method: "http-tts.delete", field: "deleted")
    }

    public func buildSafeHttpTTSRequest(
        id: Int64,
        text: String,
        correlationID: String? = nil
    ) async throws -> ReaderCoreHttpTTSRequestDescriptor {
        try Self.requireNonBlank(text, code: "SLICE10_HTTP_TTS_TEXT_EMPTY", field: "text")
        let data = try await execute(
            "http-tts.build-request",
            params: ["id": id, "text": text],
            correlationID: correlationID
        )
        guard let rawHeaders = data["headers"] as? [String: Any], rawHeaders.isEmpty
                || data["headers"] == nil else {
            throw ReaderSlice10CoreServiceError.failedClosed(
                code: "SLICE10_HTTP_TTS_CREDENTIAL_BINDING_REQUIRED",
                message: "HttpTTS descriptors with headers are blocked until Host credential references are contracted"
            )
        }
        let method = try Self.requireString(data["method"], method: "http-tts.build-request", field: "method")
        let url = try Self.requireString(data["url"], method: "http-tts.build-request", field: "url")
        try Self.validateCredentialFreeURLTemplate(url)
        return ReaderCoreHttpTTSRequestDescriptor(
            method: method,
            url: url,
            body: Self.optionalString(data["body"]),
            contentType: Self.optionalString(data["contentType"]),
            concurrentRate: Self.optionalString(data["concurrentRate"])
        )
    }

    // MARK: Request plumbing

    private func execute(
        _ method: String,
        params: [String: Any],
        correlationID: String?
    ) async throws -> [String: Any] {
        let command = try RustCoreRequestScopedCommand<ReaderSlice10RawResult>(
            runtime: runtime,
            router: router,
            requestID: RustCoreServiceSupport.allocateRequestID(),
            correlationID: correlationID,
            method: method,
            params: params,
            timeout: requestTimeout
        ) { data in
            ReaderSlice10RawResult(data: data ?? [:])
        }
        try command.start()
        return try await command.value().data
    }

    private func bookmarkParams(_ draft: ReaderCoreBookmarkDraft) -> [String: Any] {
        [
            "bookName": draft.bookName,
            "bookAuthor": draft.bookAuthor,
            "chapterIndex": draft.chapterIndex,
            "chapterPos": draft.chapterPosition,
            "chapterName": draft.chapterName,
            "bookText": draft.bookText,
            "content": draft.content,
        ]
    }

    private func replaceRuleParams(_ draft: ReaderCoreReplaceRuleDraft) -> [String: Any] {
        var value: [String: Any] = [
            "name": draft.name,
            "pattern": draft.pattern,
            "replacement": draft.replacement,
            "scopeTitle": draft.scopeTitle,
            "scopeContent": draft.scopeContent,
            "isEnabled": draft.isEnabled,
            "isRegex": draft.isRegex,
            "timeoutMillisecond": draft.timeoutMilliseconds,
            "order": draft.order,
        ]
        if let group = draft.group { value["group"] = group }
        if let scope = draft.scope { value["scope"] = scope }
        if let excludeScope = draft.excludeScope { value["excludeScope"] = excludeScope }
        return value
    }

    private func txtTocRuleParams(_ draft: ReaderCoreTxtTocRuleDraft) -> [String: Any] {
        var value: [String: Any] = [
            "name": draft.name,
            "rule": draft.rule,
            "serialNumber": draft.serialNumber,
            "enable": draft.isEnabled,
        ]
        if let example = draft.example { value["example"] = example }
        return value
    }

    private func validateReplaceRule(_ draft: ReaderCoreReplaceRuleDraft) throws {
        try Self.requireNonBlank(draft.name, code: "SLICE10_REPLACE_NAME_EMPTY", field: "name")
        try Self.requireNonBlank(draft.pattern, code: "SLICE10_REPLACE_PATTERN_EMPTY", field: "pattern")
        guard draft.timeoutMilliseconds > 0 else {
            throw ReaderSlice10CoreServiceError.failedClosed(
                code: "SLICE10_REPLACE_TIMEOUT_INVALID",
                message: "replace-rule timeoutMillisecond must be positive"
            )
        }
        if draft.isRegex {
            do {
                _ = try NSRegularExpression(pattern: draft.pattern)
            } catch {
                throw ReaderSlice10CoreServiceError.failedClosed(
                    code: "SLICE10_REPLACE_REGEX_INVALID",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func validateTxtTocRule(_ draft: ReaderCoreTxtTocRuleDraft) throws {
        try Self.requireNonBlank(draft.name, code: "SLICE10_TXT_TOC_NAME_EMPTY", field: "name")
        try Self.requireNonBlank(draft.rule, code: "SLICE10_TXT_TOC_RULE_EMPTY", field: "rule")
        do {
            _ = try NSRegularExpression(pattern: draft.rule)
        } catch {
            throw ReaderSlice10CoreServiceError.failedClosed(
                code: "SLICE10_TXT_TOC_REGEX_INVALID",
                message: error.localizedDescription
            )
        }
    }

    // MARK: Parsers

    private static func parseBookmarkEnvelope(_ data: [String: Any], method: String) throws -> ReaderCoreBookmark {
        guard let value = dictionary(data["bookmark"]) else { throw invalidResult(method, "bookmark is missing") }
        return try parseBookmark(value)
    }

    private static func parseBookmark(_ value: [String: Any]) throws -> ReaderCoreBookmark {
        ReaderCoreBookmark(
            time: Int64(try requireInteger(value["time"], method: "bookmark.*", field: "time")),
            bookName: try requireString(value["bookName"], method: "bookmark.*", field: "bookName", allowEmpty: true),
            bookAuthor: try requireString(value["bookAuthor"], method: "bookmark.*", field: "bookAuthor", allowEmpty: true),
            chapterIndex: try requireInteger(value["chapterIndex"], method: "bookmark.*", field: "chapterIndex"),
            chapterPosition: try requireInteger(value["chapterPos"], method: "bookmark.*", field: "chapterPos"),
            chapterName: try requireString(value["chapterName"], method: "bookmark.*", field: "chapterName", allowEmpty: true),
            bookText: try requireString(value["bookText"], method: "bookmark.*", field: "bookText", allowEmpty: true),
            content: try requireString(value["content"], method: "bookmark.*", field: "content", allowEmpty: true)
        )
    }

    private static func parseReadRecordEnvelope(_ data: [String: Any], method: String) throws -> ReaderCoreReadRecord {
        guard let value = dictionary(data["record"]) else { throw invalidResult(method, "record is missing") }
        return try parseReadRecord(value)
    }

    private static func parseReadRecord(_ value: [String: Any]) throws -> ReaderCoreReadRecord {
        ReaderCoreReadRecord(
            deviceID: try requireString(value["deviceId"], method: "read-record.*", field: "deviceId", allowEmpty: true),
            bookName: try requireString(value["bookName"], method: "read-record.*", field: "bookName"),
            readTime: Int64(try requireInteger(value["readTime"], method: "read-record.*", field: "readTime")),
            lastRead: Int64(try requireInteger(value["lastRead"], method: "read-record.*", field: "lastRead"))
        )
    }

    private static func parseContentSearchMatch(_ value: [String: Any]) throws -> ReaderCoreContentSearchMatch {
        ReaderCoreContentSearchMatch(
            sourceID: try requireString(value["sourceId"], method: "search.content", field: "sourceId"),
            bookID: try requireString(value["bookId"], method: "search.content", field: "bookId"),
            bookName: try requireString(value["bookName"], method: "search.content", field: "bookName", allowEmpty: true),
            chapterIndex: try requireInteger(value["chapterIndex"], method: "search.content", field: "chapterIndex"),
            chapterOffset: try requireInteger(value["chapterOffset"], method: "search.content", field: "chapterOffset"),
            matchLength: try requireInteger(value["matchLength"], method: "search.content", field: "matchLength"),
            snippetStart: try requireInteger(value["snippetStart"], method: "search.content", field: "snippetStart"),
            chapterTitle: try requireString(value["chapterTitle"], method: "search.content", field: "chapterTitle", allowEmpty: true),
            snippet: try requireString(value["snippet"], method: "search.content", field: "snippet", allowEmpty: true)
        )
    }

    private static func parseContentEditEnvelope(
        _ data: [String: Any],
        method: String,
        optional: Bool
    ) throws -> ReaderCoreContentEdit? {
        if data["edit"] == nil || data["edit"] is NSNull {
            if optional { return nil }
            throw invalidResult(method, "edit is missing")
        }
        guard let value = dictionary(data["edit"]) else { throw invalidResult(method, "edit is not an object") }
        return try parseContentEdit(value)
    }

    private static func parseContentEdit(_ value: [String: Any]) throws -> ReaderCoreContentEdit {
        ReaderCoreContentEdit(
            editID: optionalInteger(value["editId"]).map(Int64.init),
            bookID: try requireString(value["bookId"], method: "content-edit.*", field: "bookId"),
            chapterIndex: try requireInteger(value["chapterIndex"], method: "content-edit.*", field: "chapterIndex"),
            editedContent: try requireString(value["editedContent"], method: "content-edit.*", field: "editedContent", allowEmpty: true),
            editedAt: Int64(try requireInteger(value["editedAt"], method: "content-edit.*", field: "editedAt"))
        )
    }

    private static func parseReplaceRuleEnvelope(_ data: [String: Any], method: String) throws -> ReaderCoreReplaceRule {
        guard let value = dictionary(data["rule"]) else { throw invalidResult(method, "rule is missing") }
        return try parseReplaceRule(value)
    }

    private static func parseReplaceRule(_ value: [String: Any]) throws -> ReaderCoreReplaceRule {
        ReaderCoreReplaceRule(
            id: Int64(try requireInteger(value["id"], method: "replace-rule.*", field: "id")),
            name: try requireString(value["name"], method: "replace-rule.*", field: "name", allowEmpty: true),
            group: optionalString(value["group"]),
            pattern: try requireString(value["pattern"], method: "replace-rule.*", field: "pattern", allowEmpty: true),
            replacement: try requireString(value["replacement"], method: "replace-rule.*", field: "replacement", allowEmpty: true),
            scope: optionalString(value["scope"]),
            scopeTitle: try requireBool(value["scopeTitle"], method: "replace-rule.*", field: "scopeTitle"),
            scopeContent: try requireBool(value["scopeContent"], method: "replace-rule.*", field: "scopeContent"),
            excludeScope: optionalString(value["excludeScope"]),
            isEnabled: try requireBool(value["isEnabled"], method: "replace-rule.*", field: "isEnabled"),
            isRegex: try requireBool(value["isRegex"], method: "replace-rule.*", field: "isRegex"),
            timeoutMilliseconds: Int64(try requireInteger(value["timeoutMillisecond"], method: "replace-rule.*", field: "timeoutMillisecond")),
            order: try requireInteger(value["order"], method: "replace-rule.*", field: "order")
        )
    }

    private static func parseTxtTocRuleEnvelope(_ data: [String: Any], method: String) throws -> ReaderCoreTxtTocRule {
        guard let value = dictionary(data["rule"]) else { throw invalidResult(method, "rule is missing") }
        return try parseTxtTocRule(value)
    }

    private static func parseTxtTocRule(_ value: [String: Any]) throws -> ReaderCoreTxtTocRule {
        ReaderCoreTxtTocRule(
            id: Int64(try requireInteger(value["id"], method: "txt-toc-rule.*", field: "id")),
            name: try requireString(value["name"], method: "txt-toc-rule.*", field: "name", allowEmpty: true),
            rule: try requireString(value["rule"], method: "txt-toc-rule.*", field: "rule", allowEmpty: true),
            example: optionalString(value["example"]),
            serialNumber: try requireInteger(value["serialNumber"], method: "txt-toc-rule.*", field: "serialNumber"),
            isEnabled: try requireBool(value["enable"], method: "txt-toc-rule.*", field: "enable")
        )
    }

    private static func parseSourceCandidate(_ value: [String: Any]) throws -> ReaderCoreSourceSwitchCandidate {
        ReaderCoreSourceSwitchCandidate(
            sourceID: try requireString(value["sourceId"], method: "change.bookSource", field: "sourceId"),
            bookURL: try requireString(value["bookUrl"], method: "change.bookSource", field: "bookUrl"),
            bookName: try requireString(value["bookName"], method: "change.bookSource", field: "bookName"),
            author: optionalString(value["author"]),
            coverURL: optionalString(value["coverUrl"])
        )
    }

    private static func parseChapterReview(_ value: [String: Any]) throws -> ReaderCoreChapterReview {
        ReaderCoreChapterReview(
            reviewURL: optionalString(value["reviewUrl"]),
            author: optionalString(value["author"]),
            content: optionalString(value["content"]),
            postTime: optionalString(value["postTime"]),
            rating: optionalString(value["rating"])
        )
    }

    private static func parseHttpTTSEnvelope(
        _ data: [String: Any],
        method: String,
        optional: Bool
    ) throws -> ReaderCoreHttpTTSConfigSummary? {
        if data["tts"] == nil || data["tts"] is NSNull {
            if optional { return nil }
            throw invalidResult(method, "tts is missing")
        }
        guard let value = dictionary(data["tts"]) else { throw invalidResult(method, "tts is not an object") }
        return try parseHttpTTS(value)
    }

    private static func parseHttpTTS(_ value: [String: Any]) throws -> ReaderCoreHttpTTSConfigSummary {
        let sensitiveFields = ["header", "loginUrl", "loginUi", "loginCheckJs"]
        let hasSensitiveMaterial = sensitiveFields.contains { key in
            guard let text = optionalString(value[key]) else { return false }
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } || (value["enabledCookieJar"] as? Bool == true)
        return ReaderCoreHttpTTSConfigSummary(
            id: Int64(try requireInteger(value["id"], method: "http-tts.*", field: "id")),
            name: try requireString(value["name"], method: "http-tts.*", field: "name", allowEmpty: true),
            urlTemplate: try requireString(value["url"], method: "http-tts.*", field: "url", allowEmpty: true),
            contentType: optionalString(value["contentType"]),
            concurrentRate: optionalString(value["concurrentRate"]),
            requiresHostCredentialMigration: hasSensitiveMaterial,
            lastUpdateTime: Int64(try requireInteger(value["lastUpdateTime"], method: "http-tts.*", field: "lastUpdateTime"))
        )
    }

    private static func parseArray<T>(
        _ raw: Any?,
        method: String,
        field: String,
        parser: ([String: Any]) throws -> T
    ) throws -> [T] {
        guard let values = raw as? [Any] else { throw invalidResult(method, "\(field) must be an array") }
        return try values.map { rawValue in
            guard let value = dictionary(rawValue) else { throw invalidResult(method, "\(field) contains a non-object") }
            return try parser(value)
        }
    }

    private static func dictionary(_ raw: Any?) -> [String: Any]? {
        if let value = raw as? [String: Any] { return value }
        if let value = raw as? NSDictionary {
            return value.reduce(into: [String: Any]()) { result, pair in
                guard let key = pair.key as? String else { return }
                result[key] = pair.value
            }
        }
        return nil
    }

    private static func requireString(
        _ raw: Any?,
        method: String,
        field: String,
        allowEmpty: Bool = false
    ) throws -> String {
        guard let value = raw as? String, allowEmpty || !value.isEmpty else {
            throw invalidResult(method, "\(field) must be \(allowEmpty ? "a string" : "a non-empty string")")
        }
        return value
    }

    private static func optionalString(_ raw: Any?) -> String? {
        guard let raw, !(raw is NSNull) else { return nil }
        return raw as? String
    }

    private static func requireInteger(_ raw: Any?, method: String, field: String) throws -> Int {
        guard let value = optionalInteger(raw) else { throw invalidResult(method, "\(field) must be an integer") }
        return value
    }

    private static func optionalInteger(_ raw: Any?) -> Int? {
        if let value = raw as? NSNumber,
           CFGetTypeID(value) == CFBooleanGetTypeID() {
            return nil
        }
        if let value = raw as? Int { return value }
        if let value = raw as? Int64 { return Int(exactly: value) }
        if let value = raw as? UInt64 { return Int(exactly: value) }
        if let value = raw as? NSNumber {
            guard CFGetTypeID(value) != CFBooleanGetTypeID() else { return nil }
            let number = value.doubleValue
            guard number.isFinite,
                  number.rounded(.towardZero) == number,
                  number >= Double(Int.min),
                  number <= Double(Int.max) else { return nil }
            return Int(number)
        }
        return nil
    }

    private static func requireBool(_ raw: Any?, method: String, field: String) throws -> Bool {
        guard let value = raw as? NSNumber,
              CFGetTypeID(value) == CFBooleanGetTypeID() else {
            throw invalidResult(method, "\(field) must be a Bool")
        }
        return value.boolValue
    }

    private static func requireStringArray(_ raw: Any?, method: String, field: String) throws -> [String] {
        guard let value = raw as? [String] else { throw invalidResult(method, "\(field) must be a string array") }
        return value
    }

    private static func requireNonBlank(_ value: String, code: String, field: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReaderSlice10CoreServiceError.failedClosed(code: code, message: "\(field) must be non-empty")
        }
    }

    private static func requireNonNegative(_ value: Int, field: String) throws {
        guard value >= 0 else {
            throw ReaderSlice10CoreServiceError.failedClosed(
                code: "SLICE10_NEGATIVE_INDEX",
                message: "\(field) must be non-negative"
            )
        }
    }

    private static func validateCredentialFreeURLTemplate(_ value: String) throws {
        try requireNonBlank(value, code: "SLICE10_HTTP_TTS_URL_EMPTY", field: "url")
        let sample = value.replacingOccurrences(of: "{{text}}", with: "sample")
        guard let components = URLComponents(string: sample),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false else {
            throw ReaderSlice10CoreServiceError.failedClosed(
                code: "SLICE10_HTTP_TTS_URL_UNSAFE",
                message: "HttpTTS requires an absolute HTTPS URL template"
            )
        }
        let sensitiveNames = ["token", "api_key", "apikey", "key", "secret", "password", "signature", "auth"]
        let hasUserInfo = components.user != nil || components.password != nil
        let hasSensitiveQuery = components.queryItems?.contains { item in
            sensitiveNames.contains(item.name.lowercased())
        } ?? false
        guard !hasUserInfo, !hasSensitiveQuery else {
            throw ReaderSlice10CoreServiceError.failedClosed(
                code: "SLICE10_HTTP_TTS_CREDENTIAL_BINDING_REQUIRED",
                message: "Credentials must be stored and resolved by Host, but Core has no opaque credential reference yet"
            )
        }
    }

    private static func invalidResult(_ method: String, _ message: String) -> ReaderSlice10CoreServiceError {
        .invalidResult(method: method, message: message)
    }
}
