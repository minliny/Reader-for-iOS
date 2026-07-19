import CoreFoundation
import Foundation
import ReaderCoreNativeAdapter

// MARK: - Slice 11 source contracts

public struct ReaderCoreSourceImportResult: Equatable, Sendable {
    public let sourceID: String
    public let name: String
    public let imported: Bool
}

public struct ReaderCoreSourceSummary: Equatable, Sendable, Identifiable {
    public var id: String { sourceID }
    public let sourceID: String
    public let name: String
    public let baseURL: String
    public let enabled: Bool
    public let exploreEnabled: Bool
}

public struct ReaderCoreSourceExport: Equatable, Sendable {
    public let json: String
    public let count: Int
    public let format: String
}

public struct ReaderCoreSourceCheckResult: Equatable, Sendable, Identifiable {
    public var id: String { sourceID }
    public let sourceID: String
    public let available: Bool
    public let levelsPassed: [String]
    public let failureReason: String?
    public let durationMilliseconds: Int
}

public struct ReaderCoreSourceDebugReplayInput: Equatable, Sendable {
    public let sourceID: String
    public let searchResponse: String
    public let detailResponse: String
    public let tocResponse: String
    public let contentResponse: String

    public init(
        sourceID: String,
        searchResponse: String = "",
        detailResponse: String = "",
        tocResponse: String = "",
        contentResponse: String = ""
    ) {
        self.sourceID = sourceID
        self.searchResponse = searchResponse
        self.detailResponse = detailResponse
        self.tocResponse = tocResponse
        self.contentResponse = contentResponse
    }
}

public struct ReaderCoreSourceDebugLog: Equatable, Sendable, Identifiable {
    public var id: String { "\(timestampMilliseconds)::\(state)::\(message)" }
    public let state: Int
    public let message: String
    public let timestampMilliseconds: UInt64
    public let step: String?
    public let rule: String?
    public let extractedCount: Int?
    public let errorKind: String?
}

public struct ReaderCoreSourceDebugResult: Equatable, Sendable {
    public let logs: [ReaderCoreSourceDebugLog]
    public let finalState: Int
    public let durationMilliseconds: Int
}

public struct ReaderCoreSourceImageRequest: Equatable, Sendable {
    public let url: String
    public let method: String
    public let headers: [String: String]
    public let body: String?
    public let followsRedirects: Bool?
    public let usesPlatformCookieJar: Bool
    public let sessionID: String?
}

// MARK: - Slice 11 RSS contracts

public struct ReaderCoreRSSSubscription: Equatable, Sendable, Identifiable {
    public var id: String { subscriptionID }
    public let subscriptionID: String
    public let feedURL: String
    public let title: String
    public let siteURL: String?
    public let enabled: Bool
    public let lastFetchAt: Int64?
    public let lastEntryID: String?
    public let unreadCount: Int
}

public struct ReaderCoreRSSItem: Equatable, Sendable, Identifiable {
    public var id: String { "\(subscriptionID)::\(guid)" }
    public let subscriptionID: String
    public let title: String
    public let link: String?
    public let summary: String?
    public let author: String?
    public let publishedAt: String?
    public let guid: String
    public let read: Bool
    public let firstSeenAt: Int64
}

public struct ReaderCoreRSSItemsResult: Equatable, Sendable {
    public let subscription: ReaderCoreRSSSubscription
    public let items: [ReaderCoreRSSItem]
    public let count: Int
    public let unreadCount: Int
}

public struct ReaderCoreRSSRefreshResult: Equatable, Sendable {
    public let subscription: ReaderCoreRSSSubscription
    public let items: [ReaderCoreRSSItem]
    public let count: Int
    public let unreadCount: Int
    public let newCount: Int
    public let fetched: Bool
    public let notModified: Bool
    public let evaluatedAt: Int64
}

public enum ReaderSlice11CoreServiceError: Error, Equatable, LocalizedError, Sendable {
    case failedClosed(code: String, message: String)
    case invalidResult(method: String, message: String)

    public var code: String {
        switch self {
        case .failedClosed(let code, _): return code
        case .invalidResult: return "SLICE11_CORE_INVALID_RESULT"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .failedClosed(let code, let message): return "[\(code)] \(message)"
        case .invalidResult(let method, let message):
            return "[SLICE11_CORE_INVALID_RESULT] \(method): \(message)"
        }
    }
}

private struct ReaderSlice11RawResult: @unchecked Sendable {
    let data: [String: Any]
}

/// Production bridge for the frozen Slice 11 source/RSS commands.
///
/// Boundary rules enforced here:
/// - dynamic source definitions are persisted by Core, never a parallel iOS
///   source repository;
/// - plaintext credentials embedded in source JSON, headers, or URLs are
///   rejected before Core dispatch;
/// - public HTTP(S) RSS is executable, while authenticated RSS fails closed
///   because the frozen subscription DTO has no opaque credential/session ref;
/// - rule-subscription, captcha submission, and challenge-resume entry points
///   expose stable blockers instead of returning synthetic success.
public final class ReaderSlice11CoreService: @unchecked Sendable {
    private let runtime: any RustCoreCommandRuntime
    private let router: (any RustCoreHostRequestRouting)?
    private let requestTimeout: TimeInterval

    public init(
        runtime: any RustCoreCommandRuntime,
        router: (any RustCoreHostRequestRouting)? = nil,
        requestTimeout: TimeInterval = 30
    ) {
        self.runtime = runtime
        self.router = router
        self.requestTimeout = requestTimeout
    }

    public convenience init(runtime: ReaderCoreNativeRuntime, requestTimeout: TimeInterval = 30) {
        self.init(
            runtime: runtime,
            router: RustCoreServiceSupport.makeRouter(runtime: runtime),
            requestTimeout: requestTimeout
        )
    }

    @MainActor
    public static func production(requestTimeout: TimeInterval = 30) throws -> ReaderSlice11CoreService {
        guard ReaderCoreAggregateStorageGate.isReady else {
            let message: String
            switch ReaderCoreAggregateStorageGate.state {
            case .notStarted: message = "Core aggregate storage bootstrap has not started"
            case .restoring: message = "Core aggregate storage restore is still running"
            case .failed(let failure): message = "Core aggregate storage restore failed: \(failure)"
            case .ready: message = "Core aggregate storage is unavailable"
            }
            throw ReaderSlice11CoreServiceError.failedClosed(
                code: "SLICE11_STORAGE_NOT_READY",
                message: message
            )
        }
        guard let runtime = RustCoreRuntimeHolder.shared.current else {
            throw ReaderSlice11CoreServiceError.failedClosed(
                code: "SLICE11_CORE_NOT_BOOTED",
                message: "Reader Core runtime is unavailable"
            )
        }
        return ReaderSlice11CoreService(runtime: runtime, requestTimeout: requestTimeout)
    }

    // MARK: Dynamic source / DSL

    public func importCanonicalSource(
        sourceID: String? = nil,
        name: String,
        baseURL: String = "",
        rules: [String: Any] = [:],
        correlationID: String? = nil
    ) async throws -> ReaderCoreSourceImportResult {
        try Self.requireNonBlank(name, code: "SLICE11_SOURCE_NAME_EMPTY", field: "name")
        if let sourceID {
            try Self.requireNonBlank(sourceID, code: "SLICE11_SOURCE_ID_EMPTY", field: "sourceId")
        }
        if !baseURL.isEmpty {
            try Self.validateRemoteURL(baseURL, context: "source baseUrl")
        }
        try Self.rejectEmbeddedCredentials(rules, path: "rules")
        var params: [String: Any] = [
            "name": name,
            "baseUrl": baseURL,
            "rules": rules,
        ]
        if let sourceID { params["sourceId"] = sourceID }
        let data = try await execute("source.import", params: params, correlationID: correlationID)
        return try Self.parseSourceImport(data, method: "source.import")
    }

    /// Imports exactly one raw Legado BookSource object. Bulk import callers
    /// parse an array and call this once per element (matching the Core contract).
    public func importLegadoSource(
        jsonData: Data,
        sourceID: String? = nil,
        correlationID: String? = nil
    ) async throws -> ReaderCoreSourceImportResult {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: jsonData)
        } catch {
            throw ReaderSlice11CoreServiceError.failedClosed(
                code: "SLICE11_SOURCE_JSON_INVALID",
                message: "BookSource JSON cannot be decoded: \(error.localizedDescription)"
            )
        }
        guard let bookSource = object as? [String: Any] else {
            throw ReaderSlice11CoreServiceError.failedClosed(
                code: "SLICE11_SOURCE_JSON_OBJECT_REQUIRED",
                message: "One import call requires exactly one BookSource object"
            )
        }
        try Self.rejectEmbeddedCredentials(bookSource, path: "bookSource")
        if let rawURL = bookSource["bookSourceUrl"] as? String, !rawURL.isEmpty {
            try Self.validateRemoteURL(rawURL, context: "bookSource.bookSourceUrl")
        }
        var params: [String: Any] = ["bookSource": bookSource]
        if let sourceID {
            try Self.requireNonBlank(sourceID, code: "SLICE11_SOURCE_ID_EMPTY", field: "sourceId")
            params["sourceId"] = sourceID
        }
        let data = try await execute("source.import", params: params, correlationID: correlationID)
        return try Self.parseSourceImport(data, method: "source.import")
    }

    public func listSources(
        enabledOnly: Bool? = nil,
        correlationID: String? = nil
    ) async throws -> [ReaderCoreSourceSummary] {
        var params: [String: Any] = [:]
        if let enabledOnly { params["enabledOnly"] = enabledOnly }
        let data = try await execute("source.list", params: params, correlationID: correlationID)
        guard let rows = data["sources"] as? [[String: Any]] else {
            throw Self.invalidResult("source.list", "sources must be an object array")
        }
        return try rows.map { row in
            ReaderCoreSourceSummary(
                sourceID: try Self.requireString(row["sourceId"], method: "source.list", field: "sourceId"),
                name: try Self.requireString(row["name"], method: "source.list", field: "name"),
                baseURL: try Self.requireString(row["baseUrl"], method: "source.list", field: "baseUrl", allowsEmpty: true),
                enabled: try Self.requireBool(row["enabled"], method: "source.list", field: "enabled"),
                exploreEnabled: try Self.requireBool(row["enabledExplore"], method: "source.list", field: "enabledExplore")
            )
        }
    }

    public func deleteSources(
        sourceIDs: [String],
        correlationID: String? = nil
    ) async throws -> Int {
        try Self.validateNonBlankIDs(sourceIDs, code: "SLICE11_SOURCE_IDS_EMPTY", field: "sourceIds")
        let data = try await execute(
            "source.delete",
            params: ["sourceIds": sourceIDs],
            correlationID: correlationID
        )
        return try Self.requireInteger(data["deleted"], method: "source.delete", field: "deleted")
    }

    /// Export is intentionally plaintext JSON only. The password-bearing
    /// encrypted-json variant is not admitted through this service.
    public func exportSources(
        sourceIDs: [String]? = nil,
        correlationID: String? = nil
    ) async throws -> ReaderCoreSourceExport {
        if let sourceIDs {
            try Self.validateNonBlankIDs(sourceIDs, code: "SLICE11_SOURCE_IDS_EMPTY", field: "sourceIds")
        }
        var params: [String: Any] = ["format": "json"]
        if let sourceIDs { params["sourceIds"] = sourceIDs }
        let data = try await execute("source.export", params: params, correlationID: correlationID)
        let json = try Self.requireString(data["data"], method: "source.export", field: "data", allowsEmpty: true)
        let format = try Self.requireString(data["format"], method: "source.export", field: "format")
        guard format == "json" else {
            throw Self.invalidResult("source.export", "format must be json for the plaintext export path")
        }
        guard let bytes = json.data(using: .utf8) else {
            throw Self.invalidResult("source.export", "data must be UTF-8 JSON")
        }
        let exported: Any
        do {
            exported = try JSONSerialization.jsonObject(with: bytes)
        } catch {
            throw Self.invalidResult("source.export", "data must be a valid JSON array")
        }
        guard let exportedSources = exported as? [Any] else {
            throw Self.invalidResult("source.export", "data must be a JSON array")
        }
        try Self.rejectEmbeddedCredentials(exportedSources, path: "source.export")
        let count = try Self.requireInteger(data["count"], method: "source.export", field: "count")
        guard count >= 0, count == exportedSources.count else {
            throw Self.invalidResult("source.export", "count must match the exported JSON array")
        }
        return ReaderCoreSourceExport(
            json: json,
            count: count,
            format: format
        )
    }

    public func runSourceCheck(
        sourceIDs: [String],
        keyword: String,
        levels: [String] = ["L1", "L2", "L3", "L4", "L5"],
        timeoutMilliseconds: Int = 180_000,
        correlationID: String? = nil
    ) async throws -> [ReaderCoreSourceCheckResult] {
        try Self.validateNonBlankIDs(sourceIDs, code: "SLICE11_SOURCE_IDS_EMPTY", field: "sourceIds")
        try Self.requireNonBlank(keyword, code: "SLICE11_SOURCE_CHECK_KEYWORD_EMPTY", field: "keyword")
        let admitted = Set(["L1", "L2", "L3", "L4", "L5"])
        guard levels.allSatisfy(admitted.contains), timeoutMilliseconds >= 0 else {
            throw ReaderSlice11CoreServiceError.failedClosed(
                code: "SLICE11_SOURCE_CHECK_PARAMS_INVALID",
                message: "source.check.run accepts only L1-L5 levels and a non-negative timeout"
            )
        }
        let data = try await execute(
            "source.check.run",
            params: [
                "sourceIds": sourceIDs,
                "keyword": keyword,
                "levels": levels,
                "timeoutMs": timeoutMilliseconds,
            ],
            correlationID: correlationID
        )
        guard let rows = data["results"] as? [[String: Any]] else {
            throw Self.invalidResult("source.check.run", "results must be an object array")
        }
        return try rows.map { row in
            ReaderCoreSourceCheckResult(
                sourceID: try Self.requireString(row["sourceId"], method: "source.check.run", field: "sourceId"),
                available: try Self.requireBool(row["available"], method: "source.check.run", field: "available"),
                levelsPassed: try Self.requireStringArray(row["levelsPassed"], method: "source.check.run", field: "levelsPassed"),
                failureReason: Self.optionalString(row["failureReason"]),
                durationMilliseconds: try Self.requireInteger(row["durationMs"], method: "source.check.run", field: "durationMs")
            )
        }
    }

    /// `source.debug` is replay-only. At least one caller-owned response body
    /// is required; an empty replay would create misleading "debug" evidence.
    public func debugSourceReplay(
        sourceID: String,
        key: String,
        responses: ReaderCoreSourceDebugReplayInput,
        correlationID: String? = nil
    ) async throws -> ReaderCoreSourceDebugResult {
        try Self.requireNonBlank(sourceID, code: "SLICE11_SOURCE_ID_EMPTY", field: "sourceId")
        guard responses.sourceID == sourceID else {
            throw ReaderSlice11CoreServiceError.failedClosed(
                code: "SLICE11_SOURCE_DEBUG_SCOPE_MISMATCH",
                message: "debug response corpus must match the requested sourceId"
            )
        }
        let bodies = [
            responses.searchResponse,
            responses.detailResponse,
            responses.tocResponse,
            responses.contentResponse,
        ]
        guard bodies.contains(where: { !$0.isEmpty }) else {
            throw ReaderSlice11CoreServiceError.failedClosed(
                code: "SLICE11_SOURCE_DEBUG_CORPUS_MISSING",
                message: "source.debug requires caller-supplied response corpus"
            )
        }
        for (index, body) in bodies.enumerated() {
            try Self.rejectCredentialText(body, path: "source.debug.responses[\(index)]")
        }
        let data = try await execute(
            "source.debug",
            params: [
                "sourceId": sourceID,
                "key": key,
                "responses": [
                    "sourceId": sourceID,
                    "searchResponse": responses.searchResponse,
                    "detailResponse": responses.detailResponse,
                    "tocResponse": responses.tocResponse,
                    "contentResponse": responses.contentResponse,
                ],
            ],
            correlationID: correlationID
        )
        guard let rawLogs = data["logs"] as? [[String: Any]] else {
            throw Self.invalidResult("source.debug", "logs must be an object array")
        }
        let logs = try rawLogs.map { row in
            ReaderCoreSourceDebugLog(
                state: try Self.requireInteger(row["state"], method: "source.debug", field: "state"),
                message: try Self.requireString(row["msg"], method: "source.debug", field: "msg", allowsEmpty: true),
                timestampMilliseconds: try Self.requireUInt64(row["timestampMs"], method: "source.debug", field: "timestampMs"),
                step: Self.optionalString(row["step"]),
                rule: Self.optionalString(row["rule"]),
                extractedCount: Self.optionalInteger(row["extractedCount"]),
                errorKind: Self.optionalString(row["errorKind"])
            )
        }
        return ReaderCoreSourceDebugResult(
            logs: logs,
            finalState: try Self.requireInteger(data["finalState"], method: "source.debug", field: "finalState"),
            durationMilliseconds: try Self.requireInteger(data["durationMs"], method: "source.debug", field: "durationMs")
        )
    }

    public func buildImageRequest(
        sourceID: String,
        imageURL: String,
        correlationID: String? = nil
    ) async throws -> ReaderCoreSourceImageRequest {
        try Self.requireNonBlank(sourceID, code: "SLICE11_SOURCE_ID_EMPTY", field: "sourceId")
        try Self.requireNonBlank(imageURL, code: "SLICE11_IMAGE_URL_EMPTY", field: "imageUrl")
        let data = try await execute(
            "source.imageRequest",
            params: ["sourceId": sourceID, "imageUrl": imageURL],
            correlationID: correlationID
        )
        guard let request = data["request"] as? [String: Any] else {
            throw Self.invalidResult("source.imageRequest", "request must be an object")
        }
        let url = try Self.requireString(request["url"], method: "source.imageRequest", field: "request.url")
        try Self.validateRemoteURL(url, context: "source image request")
        let headers = try Self.stringDictionary(request["headers"], method: "source.imageRequest", field: "request.headers")
        try Self.rejectSensitiveHeaders(headers, path: "source.imageRequest.headers")
        let session = request["session"] as? [String: Any]
        return ReaderCoreSourceImageRequest(
            url: url,
            method: Self.optionalString(request["method"]) ?? "GET",
            headers: headers,
            body: Self.optionalString(request["body"]),
            followsRedirects: Self.optionalBool(request["followRedirects"]),
            usesPlatformCookieJar: Self.optionalBool(request["usePlatformCookieJar"]) ?? false,
            sessionID: Self.optionalString(session?["id"])
        )
    }

    // MARK: Public RSS

    public func addRSSSubscription(
        subscriptionID: String,
        feedURL: String,
        title: String = "",
        siteURL: String? = nil,
        enabled: Bool = true,
        correlationID: String? = nil
    ) async throws -> ReaderCoreRSSSubscription {
        try Self.requireNonBlank(subscriptionID, code: "SLICE11_RSS_ID_EMPTY", field: "subscriptionId")
        try Self.validatePublicRSSURL(feedURL)
        if let siteURL { try Self.validateRemoteURL(siteURL, context: "RSS siteUrl") }
        var params: [String: Any] = [
            "subscriptionId": subscriptionID,
            "feedUrl": feedURL,
            "title": title,
            "enabled": enabled,
        ]
        if let siteURL { params["siteUrl"] = siteURL }
        let data = try await execute("rss.subscription.add", params: params, correlationID: correlationID)
        return try Self.parseRSSSubscriptionEnvelope(data, method: "rss.subscription.add")
    }

    public func listRSSSubscriptions(correlationID: String? = nil) async throws -> [ReaderCoreRSSSubscription] {
        let data = try await execute("rss.subscription.list", params: [:], correlationID: correlationID)
        guard let rows = data["subscriptions"] as? [[String: Any]] else {
            throw Self.invalidResult("rss.subscription.list", "subscriptions must be an object array")
        }
        return try rows.map { try Self.parseRSSSubscription($0, method: "rss.subscription.list") }
    }

    public func updateRSSSubscription(
        subscriptionID: String,
        feedURL: String? = nil,
        title: String? = nil,
        enabled: Bool? = nil,
        correlationID: String? = nil
    ) async throws -> ReaderCoreRSSSubscription {
        try Self.requireNonBlank(subscriptionID, code: "SLICE11_RSS_ID_EMPTY", field: "subscriptionId")
        guard feedURL != nil || title != nil || enabled != nil else {
            throw ReaderSlice11CoreServiceError.failedClosed(
                code: "SLICE11_RSS_UPDATE_EMPTY",
                message: "rss.subscription.update requires at least one changed field"
            )
        }
        var params: [String: Any] = ["subscriptionId": subscriptionID]
        if let feedURL {
            try Self.validatePublicRSSURL(feedURL)
            params["feedUrl"] = feedURL
        }
        if let title { params["title"] = title }
        if let enabled { params["enabled"] = enabled }
        let data = try await execute("rss.subscription.update", params: params, correlationID: correlationID)
        return try Self.parseRSSSubscriptionEnvelope(data, method: "rss.subscription.update")
    }

    public func deleteRSSSubscription(
        subscriptionID: String,
        correlationID: String? = nil
    ) async throws -> Bool {
        try Self.requireNonBlank(subscriptionID, code: "SLICE11_RSS_ID_EMPTY", field: "subscriptionId")
        let data = try await execute(
            "rss.subscription.delete",
            params: ["subscriptionId": subscriptionID],
            correlationID: correlationID
        )
        return try Self.requireBool(data["deleted"], method: "rss.subscription.delete", field: "deleted")
    }

    public func refreshRSSSubscription(
        subscriptionID: String,
        evaluatedAt: Int64 = 0,
        correlationID: String? = nil
    ) async throws -> ReaderCoreRSSRefreshResult {
        try Self.requireNonBlank(subscriptionID, code: "SLICE11_RSS_ID_EMPTY", field: "subscriptionId")
        // The frozen refresh command has no auth/session/header fields. Verify
        // the stored URL is still credential-free before allowing Host HTTP.
        let subscriptions = try await listRSSSubscriptions(correlationID: correlationID)
        guard let subscription = subscriptions.first(where: { $0.subscriptionID == subscriptionID }) else {
            throw ReaderSlice11CoreServiceError.failedClosed(
                code: "SLICE11_RSS_SUBSCRIPTION_MISSING",
                message: "rss.subscription.refresh requires a stored subscription"
            )
        }
        try Self.validatePublicRSSURL(subscription.feedURL)
        let data = try await execute(
            "rss.subscription.refresh",
            params: ["subscriptionId": subscriptionID, "evaluatedAt": evaluatedAt],
            correlationID: correlationID
        )
        let base = try Self.parseRSSItems(data, method: "rss.subscription.refresh")
        return ReaderCoreRSSRefreshResult(
            subscription: base.subscription,
            items: base.items,
            count: base.count,
            unreadCount: base.unreadCount,
            newCount: try Self.requireInteger(data["newCount"], method: "rss.subscription.refresh", field: "newCount"),
            fetched: try Self.requireBool(data["fetched"], method: "rss.subscription.refresh", field: "fetched"),
            notModified: try Self.requireBool(data["notModified"], method: "rss.subscription.refresh", field: "notModified"),
            evaluatedAt: try Self.requireInt64(data["evaluatedAt"], method: "rss.subscription.refresh", field: "evaluatedAt")
        )
    }

    public func listRSSItems(
        subscriptionID: String,
        unreadOnly: Bool = false,
        limit: Int? = nil,
        correlationID: String? = nil
    ) async throws -> ReaderCoreRSSItemsResult {
        try Self.requireNonBlank(subscriptionID, code: "SLICE11_RSS_ID_EMPTY", field: "subscriptionId")
        if let limit, limit < 0 {
            throw ReaderSlice11CoreServiceError.failedClosed(
                code: "SLICE11_RSS_LIMIT_INVALID",
                message: "rss.subscription.items limit must be non-negative"
            )
        }
        var params: [String: Any] = [
            "subscriptionId": subscriptionID,
            "unreadOnly": unreadOnly,
        ]
        if let limit { params["limit"] = limit }
        let data = try await execute("rss.subscription.items", params: params, correlationID: correlationID)
        return try Self.parseRSSItems(data, method: "rss.subscription.items")
    }

    // MARK: Explicit blockers (no frozen executable contract)

    public func requireAuthenticatedRSSContract() throws -> Never {
        throw ReaderSlice11CoreServiceError.failedClosed(
            code: "SLICE11_RSS_AUTH_BINDING_CONTRACT_MISSING",
            message: "RSS subscription DTO has no opaque credential, header, profile, or session binding"
        )
    }

    public func requireRuleSubscriptionContract() throws -> Never {
        throw ReaderSlice11CoreServiceError.failedClosed(
            code: "SLICE11_RULE_SUBSCRIPTION_CONTRACT_MISSING",
            message: "Reader UI routes exist, but Core exposes no rule-subscription CRUD/apply command"
        )
    }

    public func requireCaptchaReturnContract() throws -> Never {
        throw ReaderSlice11CoreServiceError.failedClosed(
            code: "SLICE11_CAPTCHA_RETURN_CONTRACT_MISSING",
            message: "Core exposes CHALLENGE_REQUIRED diagnostics but no captcha/challenge resume command"
        )
    }

    public func requireWebViewLoginReturnContract() throws -> Never {
        throw ReaderSlice11CoreServiceError.failedClosed(
            code: "SLICE11_WEBVIEW_LOGIN_RETURN_CONTRACT_MISSING",
            message: "WebView evaluation is frozen, but login completion/cookie handoff is not"
        )
    }

    // MARK: Request plumbing

    private func execute(
        _ method: String,
        params: [String: Any],
        correlationID: String?
    ) async throws -> [String: Any] {
        let command = try RustCoreRequestScopedCommand<ReaderSlice11RawResult>(
            runtime: runtime,
            router: router,
            requestID: RustCoreServiceSupport.allocateRequestID(),
            correlationID: correlationID,
            method: method,
            params: params,
            timeout: requestTimeout
        ) { data in
            ReaderSlice11RawResult(data: data ?? [:])
        }
        try command.start()
        return try await command.value().data
    }

    // MARK: Parsers

    private static func parseSourceImport(
        _ data: [String: Any],
        method: String
    ) throws -> ReaderCoreSourceImportResult {
        ReaderCoreSourceImportResult(
            sourceID: try requireString(data["sourceId"], method: method, field: "sourceId"),
            name: try requireString(data["name"], method: method, field: "name"),
            imported: try requireBool(data["imported"], method: method, field: "imported")
        )
    }

    private static func parseRSSSubscriptionEnvelope(
        _ data: [String: Any],
        method: String
    ) throws -> ReaderCoreRSSSubscription {
        guard let subscription = data["subscription"] as? [String: Any] else {
            throw invalidResult(method, "subscription must be an object")
        }
        return try parseRSSSubscription(subscription, method: method)
    }

    private static func parseRSSSubscription(
        _ row: [String: Any],
        method: String
    ) throws -> ReaderCoreRSSSubscription {
        let feedURL = try requireString(row["feedUrl"], method: method, field: "feedUrl")
        try validatePublicRSSURL(feedURL)
        return ReaderCoreRSSSubscription(
            subscriptionID: try requireString(row["subscriptionId"], method: method, field: "subscriptionId"),
            feedURL: feedURL,
            title: try requireString(row["title"], method: method, field: "title", allowsEmpty: true),
            siteURL: optionalString(row["siteUrl"]),
            enabled: try requireBool(row["enabled"], method: method, field: "enabled"),
            lastFetchAt: optionalInt64(row["lastFetchAt"]),
            lastEntryID: optionalString(row["lastEntryId"]),
            unreadCount: try requireInteger(row["unreadCount"], method: method, field: "unreadCount")
        )
    }

    private static func parseRSSItems(
        _ data: [String: Any],
        method: String
    ) throws -> ReaderCoreRSSItemsResult {
        guard let subscriptionRow = data["subscription"] as? [String: Any],
              let itemRows = data["items"] as? [[String: Any]] else {
            throw invalidResult(method, "subscription/items have invalid shapes")
        }
        let items = try itemRows.map { row in
            ReaderCoreRSSItem(
                subscriptionID: try requireString(row["subscriptionId"], method: method, field: "items.subscriptionId"),
                title: try requireString(row["title"], method: method, field: "items.title", allowsEmpty: true),
                link: optionalString(row["link"]),
                summary: optionalString(row["description"]),
                author: optionalString(row["author"]),
                publishedAt: optionalString(row["pubDate"]),
                guid: try requireString(row["guid"], method: method, field: "items.guid"),
                read: try requireBool(row["read"], method: method, field: "items.read"),
                firstSeenAt: try requireInt64(row["firstSeenAt"], method: method, field: "items.firstSeenAt")
            )
        }
        return ReaderCoreRSSItemsResult(
            subscription: try parseRSSSubscription(subscriptionRow, method: method),
            items: items,
            count: try requireInteger(data["count"], method: method, field: "count"),
            unreadCount: try requireInteger(data["unreadCount"], method: method, field: "unreadCount")
        )
    }

    // MARK: Input policy

    private static let sensitiveKeyNames: Set<String> = [
        "password", "passwd", "pwd", "token", "accesstoken", "refreshtoken",
        "apikey", "secret", "clientsecret", "authorization", "proxyauthorization",
        "cookie", "credentials", "credential", "username", "userid",
    ]

    private static let sensitiveQueryNames: Set<String> = [
        "token", "access_token", "refresh_token", "api_key", "apikey", "key",
        "secret", "password", "passwd", "signature", "auth", "authorization",
        "cookie", "session",
    ]

    private static let sensitiveHeaderNames: Set<String> = [
        "authorization", "proxy-authorization", "cookie", "set-cookie", "x-api-key",
    ]

    private static func validatePublicRSSURL(_ value: String) throws {
        try validateRemoteURL(value, context: "RSS feedUrl")
    }

    private static func validateRemoteURL(_ value: String, context: String) throws {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              components.host?.isEmpty == false else {
            throw ReaderSlice11CoreServiceError.failedClosed(
                code: "SLICE11_REMOTE_URL_INVALID",
                message: "\(context) must be an absolute HTTP(S) URL"
            )
        }
        let hasSensitiveQuery = components.queryItems?.contains {
            sensitiveQueryNames.contains($0.name.lowercased())
        } ?? false
        guard components.user == nil, components.password == nil, !hasSensitiveQuery else {
            throw ReaderSlice11CoreServiceError.failedClosed(
                code: "SLICE11_EMBEDDED_CREDENTIAL_REJECTED",
                message: "\(context) embeds credentials; secrets must remain Host-owned"
            )
        }
    }

    private static func rejectEmbeddedCredentials(_ value: Any, path: String) throws {
        if let dictionary = value as? [String: Any] {
            for (key, nested) in dictionary {
                let normalized = key.lowercased().filter(\.isLetter)
                if sensitiveKeyNames.contains(normalized), hasNonEmptyValue(nested) {
                    throw ReaderSlice11CoreServiceError.failedClosed(
                        code: "SLICE11_EMBEDDED_CREDENTIAL_REJECTED",
                        message: "\(path).\(key) contains plaintext credential material"
                    )
                }
                if key.lowercased() == "header" || key.lowercased() == "headers" {
                    if let headers = nested as? [String: Any] {
                        let strings = headers.reduce(into: [String: String]()) { result, pair in
                            if let value = pair.value as? String { result[pair.key] = value }
                        }
                        try rejectSensitiveHeaders(strings, path: "\(path).\(key)")
                    } else if let text = nested as? String {
                        try rejectCredentialText(text, path: "\(path).\(key)")
                    }
                }
                if key.lowercased().contains("url"), let text = nested as? String,
                   text.lowercased().hasPrefix("http") {
                    try validateRemoteURL(text, context: "\(path).\(key)")
                }
                try rejectEmbeddedCredentials(nested, path: "\(path).\(key)")
            }
            return
        }
        if let array = value as? [Any] {
            for (index, nested) in array.enumerated() {
                try rejectEmbeddedCredentials(nested, path: "\(path)[\(index)]")
            }
        }
    }

    private static func rejectSensitiveHeaders(_ headers: [String: String], path: String) throws {
        if let name = headers.keys.first(where: { sensitiveHeaderNames.contains($0.lowercased()) }),
           hasNonEmptyValue(headers[name] as Any) {
            throw ReaderSlice11CoreServiceError.failedClosed(
                code: "SLICE11_EMBEDDED_CREDENTIAL_REJECTED",
                message: "\(path).\(name) must be resolved by Host, not persisted in source data"
            )
        }
    }

    private static func rejectCredentialText(_ value: String, path: String) throws {
        let lower = value.lowercased()
        let markers = ["authorization:", "proxy-authorization:", "cookie:", "bearer ", "basic "]
        guard !markers.contains(where: lower.contains) else {
            throw ReaderSlice11CoreServiceError.failedClosed(
                code: "SLICE11_EMBEDDED_CREDENTIAL_REJECTED",
                message: "\(path) contains plaintext authentication material"
            )
        }
        if let data = value.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) {
            try rejectEmbeddedCredentials(object, path: path)
        }
    }

    private static func hasNonEmptyValue(_ value: Any) -> Bool {
        if value is NSNull { return false }
        if let text = value as? String { return !text.isEmpty }
        if let array = value as? [Any] { return !array.isEmpty }
        if let dictionary = value as? [String: Any] { return !dictionary.isEmpty }
        return true
    }

    private static func validateNonBlankIDs(_ values: [String], code: String, field: String) throws {
        guard !values.isEmpty, values.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ReaderSlice11CoreServiceError.failedClosed(code: code, message: "\(field) must contain non-empty ids")
        }
    }

    private static func requireNonBlank(_ value: String, code: String, field: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReaderSlice11CoreServiceError.failedClosed(code: code, message: "\(field) must be non-empty")
        }
    }

    private static func requireString(
        _ raw: Any?,
        method: String,
        field: String,
        allowsEmpty: Bool = false
    ) throws -> String {
        guard let value = raw as? String, allowsEmpty || !value.isEmpty else {
            throw invalidResult(method, "\(field) must be \(allowsEmpty ? "a String" : "a non-empty String")")
        }
        return value
    }

    private static func requireStringArray(_ raw: Any?, method: String, field: String) throws -> [String] {
        guard let value = raw as? [String] else { throw invalidResult(method, "\(field) must be a string array") }
        return value
    }

    private static func stringDictionary(_ raw: Any?, method: String, field: String) throws -> [String: String] {
        if raw == nil { return [:] }
        guard let dictionary = raw as? [String: Any] else {
            throw invalidResult(method, "\(field) must be an object")
        }
        var result: [String: String] = [:]
        for (key, value) in dictionary {
            guard let value = value as? String else {
                throw invalidResult(method, "\(field).\(key) must be a String")
            }
            result[key] = value
        }
        return result
    }

    private static func requireBool(_ raw: Any?, method: String, field: String) throws -> Bool {
        guard let value = raw as? NSNumber,
              CFGetTypeID(value) == CFBooleanGetTypeID() else {
            throw invalidResult(method, "\(field) must be a Bool")
        }
        return value.boolValue
    }

    private static func requireInteger(_ raw: Any?, method: String, field: String) throws -> Int {
        guard let value = raw as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(),
              !CFNumberIsFloatType(value),
              let integer = Int(value.stringValue) else {
            throw invalidResult(method, "\(field) must be an integer")
        }
        return integer
    }

    private static func requireInt64(_ raw: Any?, method: String, field: String) throws -> Int64 {
        guard let value = raw as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(),
              !CFNumberIsFloatType(value),
              let integer = Int64(value.stringValue) else {
            throw invalidResult(method, "\(field) must be an integer")
        }
        return integer
    }

    private static func requireUInt64(_ raw: Any?, method: String, field: String) throws -> UInt64 {
        guard let value = raw as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(),
              !CFNumberIsFloatType(value),
              let integer = UInt64(value.stringValue) else {
            throw invalidResult(method, "\(field) must be a non-negative integer")
        }
        return integer
    }

    private static func optionalString(_ raw: Any?) -> String? {
        guard !(raw is NSNull) else { return nil }
        return raw as? String
    }

    private static func optionalBool(_ raw: Any?) -> Bool? {
        guard let value = raw as? NSNumber,
              CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
        return value.boolValue
    }

    private static func optionalInteger(_ raw: Any?) -> Int? {
        guard let value = raw as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(),
              !CFNumberIsFloatType(value) else { return nil }
        return Int(value.stringValue)
    }

    private static func optionalInt64(_ raw: Any?) -> Int64? {
        guard let value = raw as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(),
              !CFNumberIsFloatType(value) else { return nil }
        return Int64(value.stringValue)
    }

    private static func invalidResult(_ method: String, _ message: String) -> ReaderSlice11CoreServiceError {
        .invalidResult(method: method, message: message)
    }
}
