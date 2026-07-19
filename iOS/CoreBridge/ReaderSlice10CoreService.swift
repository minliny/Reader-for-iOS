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

/// Exact wire values accepted by Core's `cache.clear` command.
public enum ReaderCoreCacheClearScope: String, Equatable, Sendable {
    case all
    case cache
    case book
}

public enum ReaderCoreCacheChapterState: String, Equatable, Sendable {
    case missing
    case queued
    case inProgress
    case cached
    case completed
    case failed
    case cancelled
}

public struct ReaderCoreCacheChapterStatus: Equatable, Sendable, Identifiable {
    public var id: Int { chapterIndex }
    public let chapterIndex: Int
    public let title: String
    public let url: String
    public let state: ReaderCoreCacheChapterState
    public let cachedBytes: Int64
    public let attempts: Int
    public let maxAttempts: Int
    public let lastError: String?
}

public struct ReaderCoreCacheGlobalStats: Equatable, Sendable {
    public let entryCount: Int
    public let totalContentBytes: Int64
    public let oldestCachedAt: Int64?
    public let newestCachedAt: Int64?
    public let queueEntryCount: Int
    public let queuedCount: Int
    public let inProgressCount: Int
    public let completedCount: Int
    public let failedCount: Int
    public let cancelledCount: Int
}

public struct ReaderCoreBookCacheStatus: Equatable, Sendable {
    public let sourceID: String
    public let bookID: String
    public let tocAvailable: Bool
    public let chapterCount: Int
    public let chapters: [ReaderCoreCacheChapterStatus]
    public let cachedCount: Int
    public let queuedCount: Int
    public let inProgressCount: Int
    public let completedCount: Int
    public let failedCount: Int
    public let cancelledCount: Int
    public let missingCount: Int
    public let globalStats: ReaderCoreCacheGlobalStats
}

public struct ReaderCoreBookPrefetchResult: Equatable, Sendable {
    public let sourceID: String
    public let bookID: String
    public let chapterRange: [Int]
    public let chapterCount: Int
    public let prefetchedCount: Int
    public let queuedIndexes: [Int]
    public let alreadyQueuedIndexes: [Int]
    public let skippedCachedIndexes: [Int]
}

public struct ReaderCoreCacheClearResult: Equatable, Sendable {
    public let scope: ReaderCoreCacheClearScope
    public let cacheEntriesRemoved: Int
    public let chapterEntriesRemoved: Int
    public let queueEntriesRemoved: Int
    public let removedContentBytes: Int64
}

public enum ReaderCoreReplaceUndoOperation: String, Equatable, Sendable {
    case create
    case update
    case delete
}

/// Core-issued token retained losslessly as typed fields. Host code may store
/// and replay it but must never manufacture or alter any field.
public struct ReaderCoreReplaceUndoToken: Equatable, Sendable {
    public let schemaVersion: Int
    public let transactionID: String
    public let revision: String
    public let operation: ReaderCoreReplaceUndoOperation
    public let ruleID: Int64
    public let issuedAt: Int64
    public let expiresAt: Int64
    public let before: ReaderCoreReplaceRule?
    public let after: ReaderCoreReplaceRule?

    public init(coreObject: [String: Any]) throws {
        self = try ReaderSlice10CoreService.parseReplaceUndoToken(coreObject)
    }

    fileprivate init(
        schemaVersion: Int,
        transactionID: String,
        revision: String,
        operation: ReaderCoreReplaceUndoOperation,
        ruleID: Int64,
        issuedAt: Int64,
        expiresAt: Int64,
        before: ReaderCoreReplaceRule?,
        after: ReaderCoreReplaceRule?
    ) {
        self.schemaVersion = schemaVersion
        self.transactionID = transactionID
        self.revision = revision
        self.operation = operation
        self.ruleID = ruleID
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.before = before
        self.after = after
    }

    fileprivate var coreObject: [String: Any] {
        var value: [String: Any] = [
            "schemaVersion": schemaVersion,
            "transactionId": transactionID,
            "revision": revision,
            "operation": operation.rawValue,
            "ruleId": ruleID,
            "issuedAt": issuedAt,
            "expiresAt": expiresAt,
        ]
        if let before { value["before"] = ReaderSlice10CoreService.replaceRuleObject(before) }
        if let after { value["after"] = ReaderSlice10CoreService.replaceRuleObject(after) }
        return value
    }
}

public struct ReaderCoreReplaceUndoResult: Equatable, Sendable {
    public let transactionID: String
    public let revision: String
    public let operation: ReaderCoreReplaceUndoOperation
    public let ruleID: Int64
    public let changed: Bool
    public let undoneAt: Int64
    public let restoredRule: ReaderCoreReplaceRule?
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

/// Narrow Host-to-Core seam for cache operations and replacement undo. Core
/// remains the sole owner of validation, persistence, and mutation semantics;
/// iOS only preserves the exact command parameters and result JSON.
public protocol ReaderSlice10CacheAndReplaceUndoServicing: AnyObject {
    func loadBookCacheStatus(
        sourceID: String,
        bookID: String,
        correlationID: String?
    ) async throws -> ReaderCoreBookCacheStatus

    func prefetchBookCache(
        sourceID: String,
        bookID: String,
        chapterRange: [Int],
        priority: Int?,
        requestedAt: Int64?,
        correlationID: String?
    ) async throws -> ReaderCoreBookPrefetchResult

    func clearCache(
        scope: ReaderCoreCacheClearScope,
        sourceID: String?,
        bookID: String?,
        correlationID: String?
    ) async throws -> ReaderCoreCacheClearResult

    func undoReplace(
        undoToken: ReaderCoreReplaceUndoToken,
        correlationID: String?
    ) async throws -> ReaderCoreReplaceUndoResult
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
public final class ReaderSlice10CoreService:
    ReaderSlice10ReadingDataServicing,
    ReaderSlice10SearchHistoryServicing,
    ReaderSlice10CacheAndReplaceUndoServicing,
    @unchecked Sendable
{
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

    // MARK: Offline cache + replacement undo

    public func loadBookCacheStatus(
        sourceID: String,
        bookID: String,
        correlationID: String? = nil
    ) async throws -> ReaderCoreBookCacheStatus {
        try Self.requireNonBlank(sourceID, code: "SLICE10_CACHE_SOURCE_MISSING", field: "sourceId")
        try Self.requireNonBlank(bookID, code: "SLICE10_CACHE_BOOK_MISSING", field: "bookId")
        let data = try await execute(
            "cache.book.status",
            params: ["sourceId": sourceID, "bookId": bookID],
            correlationID: correlationID,
            requireResultData: true
        )
        let result = try Self.parseBookCacheStatus(data)
        guard result.sourceID == sourceID, result.bookID == bookID else {
            throw Self.invalidResult("cache.book.status", "sourceId/bookId do not match the requested live book")
        }
        return result
    }

    public func prefetchBookCache(
        sourceID: String,
        bookID: String,
        chapterRange: [Int],
        priority: Int? = nil,
        requestedAt: Int64? = nil,
        correlationID: String? = nil
    ) async throws -> ReaderCoreBookPrefetchResult {
        try Self.requireNonBlank(sourceID, code: "SLICE10_CACHE_SOURCE_MISSING", field: "sourceId")
        try Self.requireNonBlank(bookID, code: "SLICE10_CACHE_BOOK_MISSING", field: "bookId")
        guard chapterRange.count == 2,
              chapterRange[0] >= 0,
              chapterRange[1] > chapterRange[0] else {
            throw ReaderSlice10CoreServiceError.failedClosed(
                code: "SLICE10_CACHE_RANGE_INVALID",
                message: "chapterRange must be [startInclusive, endExclusive] with end > start"
            )
        }
        if let priority, !(Int(Int32.min)...Int(Int32.max)).contains(priority) {
            throw ReaderSlice10CoreServiceError.failedClosed(
                code: "SLICE10_CACHE_PRIORITY_INVALID",
                message: "priority must fit Core's signed 32-bit range"
            )
        }
        if let requestedAt, requestedAt < 0 {
            throw ReaderSlice10CoreServiceError.failedClosed(
                code: "SLICE10_CACHE_REQUESTED_AT_INVALID",
                message: "requestedAt must be non-negative"
            )
        }
        var params: [String: Any] = [
            "sourceId": sourceID,
            "bookId": bookID,
            "chapterRange": chapterRange,
        ]
        if let priority { params["priority"] = priority }
        if let requestedAt { params["requestedAt"] = requestedAt }
        let data = try await execute(
            "cache.book.prefetch",
            params: params,
            correlationID: correlationID,
            requireResultData: true
        )
        let result = try Self.parseBookPrefetchResult(data)
        guard result.sourceID == sourceID,
              result.bookID == bookID,
              result.chapterRange == chapterRange else {
            throw Self.invalidResult("cache.book.prefetch", "Core result does not echo the requested live book and chapterRange")
        }
        return result
    }

    public func clearCache(
        scope: ReaderCoreCacheClearScope,
        sourceID: String? = nil,
        bookID: String? = nil,
        correlationID: String? = nil
    ) async throws -> ReaderCoreCacheClearResult {
        switch scope {
        case .all, .cache:
            guard sourceID == nil, bookID == nil else {
                throw ReaderSlice10CoreServiceError.failedClosed(
                    code: "SLICE10_CACHE_CLEAR_SELECTOR_INVALID",
                    message: "scope \(scope.rawValue) does not accept sourceId/bookId"
                )
            }
        case .book:
            guard let sourceID, let bookID else {
                throw ReaderSlice10CoreServiceError.failedClosed(
                    code: "SLICE10_CACHE_CLEAR_SELECTOR_MISSING",
                    message: "scope book requires live sourceId and bookId"
                )
            }
            try Self.requireNonBlank(sourceID, code: "SLICE10_CACHE_SOURCE_MISSING", field: "sourceId")
            try Self.requireNonBlank(bookID, code: "SLICE10_CACHE_BOOK_MISSING", field: "bookId")
        }
        var params: [String: Any] = ["scope": scope.rawValue]
        if let sourceID { params["sourceId"] = sourceID }
        if let bookID { params["bookId"] = bookID }
        let data = try await execute(
            "cache.clear",
            params: params,
            correlationID: correlationID,
            requireResultData: true
        )
        let result = try Self.parseCacheClearResult(data)
        guard result.scope == scope else {
            throw Self.invalidResult("cache.clear", "scope does not match the requested clear operation")
        }
        return result
    }

    public func undoReplace(
        undoToken: ReaderCoreReplaceUndoToken,
        correlationID: String? = nil
    ) async throws -> ReaderCoreReplaceUndoResult {
        let data = try await execute(
            "replace.undo",
            params: ["undoToken": undoToken.coreObject],
            correlationID: correlationID,
            requireResultData: true
        )
        let result = try Self.parseReplaceUndoResult(data)
        guard result.transactionID == undoToken.transactionID,
              result.revision == undoToken.revision,
              result.operation == undoToken.operation,
              result.ruleID == undoToken.ruleID else {
            throw Self.invalidResult("replace.undo", "Core result identity does not match the issued undoToken")
        }
        return result
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
        correlationID: String?,
        requireResultData: Bool = false
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
            if requireResultData {
                guard let data else {
                    throw Self.invalidResult(method, "result data is missing")
                }
                return ReaderSlice10RawResult(data: data)
            }
            return ReaderSlice10RawResult(data: data ?? [:])
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

    private static func parseBookCacheStatus(_ data: [String: Any]) throws -> ReaderCoreBookCacheStatus {
        let method = "cache.book.status"
        try requireExactKeys(
            data,
            required: [
                "sourceId", "bookId", "tocAvailable", "chapterCount", "chapters",
                "cachedCount", "queuedCount", "inProgressCount", "completedCount",
                "failedCount", "cancelledCount", "missingCount", "globalStats",
            ],
            method: method,
            path: "result"
        )
        guard let rawGlobalStats = dictionary(data["globalStats"]) else {
            throw invalidResult(method, "globalStats must be an object")
        }
        return ReaderCoreBookCacheStatus(
            sourceID: try requireNonBlankResultString(data["sourceId"], method: method, field: "sourceId"),
            bookID: try requireNonBlankResultString(data["bookId"], method: method, field: "bookId"),
            tocAvailable: try requireBool(data["tocAvailable"], method: method, field: "tocAvailable"),
            chapterCount: try requireNonNegativeInteger(data["chapterCount"], method: method, field: "chapterCount"),
            chapters: try parseArray(data["chapters"], method: method, field: "chapters", parser: parseCacheChapterStatus),
            cachedCount: try requireNonNegativeInteger(data["cachedCount"], method: method, field: "cachedCount"),
            queuedCount: try requireNonNegativeInteger(data["queuedCount"], method: method, field: "queuedCount"),
            inProgressCount: try requireNonNegativeInteger(data["inProgressCount"], method: method, field: "inProgressCount"),
            completedCount: try requireNonNegativeInteger(data["completedCount"], method: method, field: "completedCount"),
            failedCount: try requireNonNegativeInteger(data["failedCount"], method: method, field: "failedCount"),
            cancelledCount: try requireNonNegativeInteger(data["cancelledCount"], method: method, field: "cancelledCount"),
            missingCount: try requireNonNegativeInteger(data["missingCount"], method: method, field: "missingCount"),
            globalStats: try parseCacheGlobalStats(rawGlobalStats)
        )
    }

    private static func parseCacheChapterStatus(_ value: [String: Any]) throws -> ReaderCoreCacheChapterStatus {
        let method = "cache.book.status"
        try requireExactKeys(
            value,
            required: ["chapterIndex", "title", "url", "state", "cachedBytes", "attempts", "maxAttempts"],
            optional: ["lastError"],
            method: method,
            path: "chapters[]"
        )
        let stateValue = try requireString(value["state"], method: method, field: "chapters[].state")
        guard let state = ReaderCoreCacheChapterState(rawValue: stateValue) else {
            throw invalidResult(method, "chapters[].state is unsupported")
        }
        return ReaderCoreCacheChapterStatus(
            chapterIndex: try requireNonNegativeInteger(value["chapterIndex"], method: method, field: "chapters[].chapterIndex"),
            title: try requireString(value["title"], method: method, field: "chapters[].title", allowEmpty: true),
            url: try requireString(value["url"], method: method, field: "chapters[].url", allowEmpty: true),
            state: state,
            cachedBytes: try requireNonNegativeInt64(value["cachedBytes"], method: method, field: "chapters[].cachedBytes"),
            attempts: try requireNonNegativeInteger(value["attempts"], method: method, field: "chapters[].attempts"),
            maxAttempts: try requireNonNegativeInteger(value["maxAttempts"], method: method, field: "chapters[].maxAttempts"),
            lastError: try optionalStrictString(value, key: "lastError", method: method, path: "chapters[]")
        )
    }

    private static func parseCacheGlobalStats(_ value: [String: Any]) throws -> ReaderCoreCacheGlobalStats {
        let method = "cache.book.status"
        try requireExactKeys(
            value,
            required: [
                "entryCount", "totalContentBytes", "queueEntryCount", "queuedCount",
                "inProgressCount", "completedCount", "failedCount", "cancelledCount",
            ],
            optional: ["oldestCachedAt", "newestCachedAt"],
            method: method,
            path: "globalStats"
        )
        return ReaderCoreCacheGlobalStats(
            entryCount: try requireNonNegativeInteger(value["entryCount"], method: method, field: "globalStats.entryCount"),
            totalContentBytes: try requireNonNegativeInt64(value["totalContentBytes"], method: method, field: "globalStats.totalContentBytes"),
            oldestCachedAt: try optionalStrictInt64(value, key: "oldestCachedAt", method: method, path: "globalStats"),
            newestCachedAt: try optionalStrictInt64(value, key: "newestCachedAt", method: method, path: "globalStats"),
            queueEntryCount: try requireNonNegativeInteger(value["queueEntryCount"], method: method, field: "globalStats.queueEntryCount"),
            queuedCount: try requireNonNegativeInteger(value["queuedCount"], method: method, field: "globalStats.queuedCount"),
            inProgressCount: try requireNonNegativeInteger(value["inProgressCount"], method: method, field: "globalStats.inProgressCount"),
            completedCount: try requireNonNegativeInteger(value["completedCount"], method: method, field: "globalStats.completedCount"),
            failedCount: try requireNonNegativeInteger(value["failedCount"], method: method, field: "globalStats.failedCount"),
            cancelledCount: try requireNonNegativeInteger(value["cancelledCount"], method: method, field: "globalStats.cancelledCount")
        )
    }

    private static func parseBookPrefetchResult(_ data: [String: Any]) throws -> ReaderCoreBookPrefetchResult {
        let method = "cache.book.prefetch"
        try requireExactKeys(
            data,
            required: [
                "sourceId", "bookId", "chapterRange", "chapterCount", "prefetchedCount",
                "queuedIndexes", "alreadyQueuedIndexes", "skippedCachedIndexes",
            ],
            method: method,
            path: "result"
        )
        let range = try requireNonNegativeIntegerArray(data["chapterRange"], method: method, field: "chapterRange")
        guard range.count == 2, range[1] > range[0] else {
            throw invalidResult(method, "chapterRange must contain exactly two increasing indexes")
        }
        return ReaderCoreBookPrefetchResult(
            sourceID: try requireNonBlankResultString(data["sourceId"], method: method, field: "sourceId"),
            bookID: try requireNonBlankResultString(data["bookId"], method: method, field: "bookId"),
            chapterRange: range,
            chapterCount: try requireNonNegativeInteger(data["chapterCount"], method: method, field: "chapterCount"),
            prefetchedCount: try requireNonNegativeInteger(data["prefetchedCount"], method: method, field: "prefetchedCount"),
            queuedIndexes: try requireNonNegativeIntegerArray(data["queuedIndexes"], method: method, field: "queuedIndexes"),
            alreadyQueuedIndexes: try requireNonNegativeIntegerArray(data["alreadyQueuedIndexes"], method: method, field: "alreadyQueuedIndexes"),
            skippedCachedIndexes: try requireNonNegativeIntegerArray(data["skippedCachedIndexes"], method: method, field: "skippedCachedIndexes")
        )
    }

    private static func parseCacheClearResult(_ data: [String: Any]) throws -> ReaderCoreCacheClearResult {
        let method = "cache.clear"
        try requireExactKeys(
            data,
            required: [
                "scope", "cacheEntriesRemoved", "chapterEntriesRemoved",
                "queueEntriesRemoved", "removedContentBytes",
            ],
            method: method,
            path: "result"
        )
        let rawScope = try requireString(data["scope"], method: method, field: "scope")
        guard let scope = ReaderCoreCacheClearScope(rawValue: rawScope) else {
            throw invalidResult(method, "scope is unsupported")
        }
        return ReaderCoreCacheClearResult(
            scope: scope,
            cacheEntriesRemoved: try requireNonNegativeInteger(data["cacheEntriesRemoved"], method: method, field: "cacheEntriesRemoved"),
            chapterEntriesRemoved: try requireNonNegativeInteger(data["chapterEntriesRemoved"], method: method, field: "chapterEntriesRemoved"),
            queueEntriesRemoved: try requireNonNegativeInteger(data["queueEntriesRemoved"], method: method, field: "queueEntriesRemoved"),
            removedContentBytes: try requireNonNegativeInt64(data["removedContentBytes"], method: method, field: "removedContentBytes")
        )
    }

    fileprivate static func parseReplaceUndoToken(_ data: [String: Any]) throws -> ReaderCoreReplaceUndoToken {
        let method = "replace.undo"
        try requireExactKeys(
            data,
            required: [
                "schemaVersion", "transactionId", "revision", "operation",
                "ruleId", "issuedAt", "expiresAt",
            ],
            optional: ["before", "after"],
            method: method,
            path: "undoToken"
        )
        let schemaVersion = try requireInteger(data["schemaVersion"], method: method, field: "undoToken.schemaVersion")
        guard schemaVersion == 1 else { throw invalidResult(method, "undoToken.schemaVersion must be 1") }
        let transactionID = try requireNonBlankResultString(data["transactionId"], method: method, field: "undoToken.transactionId")
        let revision = try requireString(data["revision"], method: method, field: "undoToken.revision")
        guard revision.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
            throw invalidResult(method, "undoToken.revision must be a lowercase SHA-256 hex value")
        }
        let rawOperation = try requireString(data["operation"], method: method, field: "undoToken.operation")
        guard let operation = ReaderCoreReplaceUndoOperation(rawValue: rawOperation) else {
            throw invalidResult(method, "undoToken.operation is unsupported")
        }
        let ruleID = try requireInt64(data["ruleId"], method: method, field: "undoToken.ruleId")
        let issuedAt = try requireInt64(data["issuedAt"], method: method, field: "undoToken.issuedAt")
        let expiresAt = try requireInt64(data["expiresAt"], method: method, field: "undoToken.expiresAt")
        guard expiresAt > issuedAt else { throw invalidResult(method, "undoToken.expiresAt must be later than issuedAt") }
        let before = try optionalReplaceUndoRule(data, key: "before")
        let after = try optionalReplaceUndoRule(data, key: "after")
        switch operation {
        case .create where before != nil || after == nil:
            throw invalidResult(method, "create undoToken requires after and omits before")
        case .update where before == nil || after == nil:
            throw invalidResult(method, "update undoToken requires before and after")
        case .delete where before == nil || after != nil:
            throw invalidResult(method, "delete undoToken requires before and omits after")
        default:
            break
        }
        guard before?.id == ruleID || before == nil,
              after?.id == ruleID || after == nil else {
            throw invalidResult(method, "undoToken before/after rule id must match ruleId")
        }
        return ReaderCoreReplaceUndoToken(
            schemaVersion: schemaVersion,
            transactionID: transactionID,
            revision: revision,
            operation: operation,
            ruleID: ruleID,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            before: before,
            after: after
        )
    }

    private static func parseReplaceUndoResult(_ data: [String: Any]) throws -> ReaderCoreReplaceUndoResult {
        let method = "replace.undo"
        try requireExactKeys(
            data,
            required: ["transactionId", "revision", "operation", "ruleId", "changed", "undoneAt"],
            optional: ["restoredRule"],
            method: method,
            path: "result"
        )
        let revision = try requireString(data["revision"], method: method, field: "revision")
        guard revision.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
            throw invalidResult(method, "revision must be a lowercase SHA-256 hex value")
        }
        let rawOperation = try requireString(data["operation"], method: method, field: "operation")
        guard let operation = ReaderCoreReplaceUndoOperation(rawValue: rawOperation) else {
            throw invalidResult(method, "operation is unsupported")
        }
        let restoredRule = try optionalReplaceUndoRule(data, key: "restoredRule", path: "result")
        return ReaderCoreReplaceUndoResult(
            transactionID: try requireNonBlankResultString(data["transactionId"], method: method, field: "transactionId"),
            revision: revision,
            operation: operation,
            ruleID: try requireInt64(data["ruleId"], method: method, field: "ruleId"),
            changed: try requireBool(data["changed"], method: method, field: "changed"),
            undoneAt: try requireInt64(data["undoneAt"], method: method, field: "undoneAt"),
            restoredRule: restoredRule
        )
    }

    private static func optionalReplaceUndoRule(
        _ data: [String: Any],
        key: String,
        path: String = "undoToken"
    ) throws -> ReaderCoreReplaceRule? {
        guard data.keys.contains(key) else { return nil }
        guard let value = dictionary(data[key]) else {
            throw invalidResult("replace.undo", "\(path).\(key) must be an object when present")
        }
        try requireExactKeys(
            value,
            required: [
                "id", "name", "pattern", "replacement", "scopeTitle", "scopeContent",
                "isEnabled", "isRegex", "timeoutMillisecond", "order",
            ],
            optional: ["group", "scope", "excludeScope"],
            method: "replace.undo",
            path: "\(path).\(key)"
        )
        return try parseReplaceRule(value)
    }

    fileprivate static func replaceRuleObject(_ rule: ReaderCoreReplaceRule) -> [String: Any] {
        var value: [String: Any] = [
            "id": rule.id,
            "name": rule.name,
            "pattern": rule.pattern,
            "replacement": rule.replacement,
            "scopeTitle": rule.scopeTitle,
            "scopeContent": rule.scopeContent,
            "isEnabled": rule.isEnabled,
            "isRegex": rule.isRegex,
            "timeoutMillisecond": rule.timeoutMilliseconds,
            "order": rule.order,
        ]
        if let group = rule.group { value["group"] = group }
        if let scope = rule.scope { value["scope"] = scope }
        if let excludeScope = rule.excludeScope { value["excludeScope"] = excludeScope }
        return value
    }

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

    private static func requireExactKeys(
        _ value: [String: Any],
        required: Set<String>,
        optional: Set<String> = [],
        method: String,
        path: String
    ) throws {
        let actual = Set(value.keys)
        let missing = required.subtracting(actual).sorted()
        guard missing.isEmpty else {
            throw invalidResult(method, "\(path) is missing required fields: \(missing.joined(separator: ", "))")
        }
        let unknown = actual.subtracting(required.union(optional)).sorted()
        guard unknown.isEmpty else {
            throw invalidResult(method, "\(path) contains unknown fields: \(unknown.joined(separator: ", "))")
        }
    }

    private static func requireNonBlankResultString(
        _ raw: Any?,
        method: String,
        field: String
    ) throws -> String {
        let value = try requireString(raw, method: method, field: field)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw invalidResult(method, "\(field) must be non-blank")
        }
        return value
    }

    private static func requireNonNegativeInteger(
        _ raw: Any?,
        method: String,
        field: String
    ) throws -> Int {
        let value = try requireInteger(raw, method: method, field: field)
        guard value >= 0 else { throw invalidResult(method, "\(field) must be non-negative") }
        return value
    }

    private static func requireInt64(_ raw: Any?, method: String, field: String) throws -> Int64 {
        guard let value = optionalInt64(raw) else { throw invalidResult(method, "\(field) must be an integer") }
        return value
    }

    private static func requireNonNegativeInt64(_ raw: Any?, method: String, field: String) throws -> Int64 {
        let value = try requireInt64(raw, method: method, field: field)
        guard value >= 0 else { throw invalidResult(method, "\(field) must be non-negative") }
        return value
    }

    private static func optionalInt64(_ raw: Any?) -> Int64? {
        guard let raw, !(raw is NSNull) else { return nil }
        if let value = raw as? NSNumber,
           CFGetTypeID(value) == CFBooleanGetTypeID() {
            return nil
        }
        if let value = raw as? Int64 { return value }
        if let value = raw as? Int { return Int64(value) }
        if let value = raw as? UInt64 { return Int64(exactly: value) }
        if let value = raw as? NSNumber {
            let number = value.doubleValue
            guard number.isFinite,
                  number.rounded(.towardZero) == number,
                  number >= Double(Int64.min),
                  number <= Double(Int64.max) else { return nil }
            return Int64(number)
        }
        return nil
    }

    private static func requireNonNegativeIntegerArray(
        _ raw: Any?,
        method: String,
        field: String
    ) throws -> [Int] {
        guard let values = raw as? [Any] else { throw invalidResult(method, "\(field) must be an array") }
        return try values.enumerated().map { index, value in
            try requireNonNegativeInteger(value, method: method, field: "\(field)[\(index)]")
        }
    }

    private static func optionalStrictString(
        _ value: [String: Any],
        key: String,
        method: String,
        path: String
    ) throws -> String? {
        guard value.keys.contains(key) else { return nil }
        return try requireString(value[key], method: method, field: "\(path).\(key)", allowEmpty: true)
    }

    private static func optionalStrictInt64(
        _ value: [String: Any],
        key: String,
        method: String,
        path: String
    ) throws -> Int64? {
        guard value.keys.contains(key) else { return nil }
        return try requireInt64(value[key], method: method, field: "\(path).\(key)")
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
