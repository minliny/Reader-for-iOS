import CoreFoundation
import Foundation
import ReaderCoreModels
import ReaderCoreNativeAdapter

/// RSS subscription persistence store.
///
/// H4-G note: The 7 RSS events (`rss.refresh`, `rss.subscription.add`,
/// `rss.subscription.delete`, `rss.subscription.edit`, `rss.entry.open`,
/// `rss.favorite.add`, `rss.favorite.remove`) are now canonical via
/// `ReaderRssPilotCoordinator` at the UI event layer (ReaderApp target).
/// Core is the production persistence owner: the pilot coordinator's
/// `ReaderRssCoreCommandExecuting` executor calls the same Core methods this
/// store uses for `load`/`addOrUpdate`/`delete`. File persistence is retained
/// only behind the explicit custom-URL test/legacy compatibility initializer.
/// The store cannot import `ReaderRssPilotCoordinator` directly because
/// `ReaderAppPersistence` does not depend on `ReaderApp`/`ReaderUIRuntime`.
public final class RSSSubscriptionStore: @unchecked Sendable {
    public static let shared = RSSSubscriptionStore()

    private typealias CoreRequest = @Sendable (
        _ method: String,
        _ params: [String: Any]
    ) async throws -> [String: Any]

    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()
    private let allowsLocalCompatibilityWrites: Bool
    private let coreRequest: CoreRequest
    private var cache: [RSSSource]?

    /// Timeout for Core bridge calls (rss.subscription.* may involve storage I/O).
    private static let coreTimeout: TimeInterval = 30

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.allowsLocalCompatibilityWrites = false
        self.coreRequest = Self.makeCoreRequest(runtimeProvider: {
            await Self.currentCoreRuntime()
        })
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ReaderApp", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("rss_subscriptions.json")
        configureCoders()
    }

    /// Test/legacy migration seam. Production uses `.shared`, which requires
    /// Core for reads and mutations and never creates a second RSS owner.
    public init(
        storageURL: URL,
        fileManager: FileManager = .default,
        allowsLocalCompatibilityWrites: Bool = true,
        coreRuntimeProvider: (@Sendable () async -> ReaderCoreNativeRuntime?)? = nil
    ) {
        self.fileManager = fileManager
        self.fileURL = storageURL
        self.allowsLocalCompatibilityWrites = allowsLocalCompatibilityWrites
        // A custom URL is an explicit local compatibility/test seam and must
        // not silently bind to whichever process-global Core runtime happens
        // to have been booted by another feature or test. Callers that want a
        // custom location plus Core must inject that dependency explicitly.
        self.coreRequest = Self.makeCoreRequest(runtimeProvider: coreRuntimeProvider ?? { nil })
        configureCoders()
    }

    /// Deterministic Core seam for persistence contract tests. Keeping it
    /// internal avoids making an untyped transport shape part of the app API.
    init(
        storageURL: URL,
        fileManager: FileManager = .default,
        allowsLocalCompatibilityWrites: Bool = false,
        coreRequest: @escaping @Sendable (String, [String: Any]) async throws -> [String: Any]
    ) {
        self.fileManager = fileManager
        self.fileURL = storageURL
        self.allowsLocalCompatibilityWrites = allowsLocalCompatibilityWrites
        self.coreRequest = coreRequest
        configureCoders()
    }

    public func load() async throws -> [RSSSource] {
        if let cached = withLock({ cache }) {
            return cached
        }

        do {
            let sources = try await tryCoreSubscriptionList()
            withLock { cache = sources }
            return sources
        } catch {
            guard allowsLocalCompatibilityWrites else { throw error }
        }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let sources = try decoder.decode([RSSSource].self, from: data)
            .sorted(by: sortSources)
        withLock { cache = sources }
        return sources
    }

    public func save(_ sources: [RSSSource]) async throws {
        guard allowsLocalCompatibilityWrites else {
            throw CoreBridgeError.localCompatibilityWriteForbidden
        }
        let sorted = sources.sorted(by: sortSources)
        withLock { cache = sorted }

        try ensureParentDirectoryExists()
        let data = try encoder.encode(sorted)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func addOrUpdate(_ source: RSSSource) async throws {
        let normalized = normalizedSource(source)
        try validateCredentialFreePersistence(normalized)

        do {
            _ = try await tryCoreSubscriptionPersist(normalized)
            clearCache()
            return
        } catch {
            guard allowsLocalCompatibilityWrites else { throw error }
        }

        var sources = try await load()
        if let index = sources.firstIndex(where: { normalizedURL($0.url) == normalizedURL(normalized.url) }) {
            sources[index] = normalized
        } else {
            sources.append(normalized)
        }
        try await save(sources)
    }

    public func delete(url: String) async throws {
        try await delete(RSSSource(url: url))
    }

    /// Delete a Core-owned subscription. `subscriptionId` is opaque and is
    /// resolved from the source metadata or the last/listed Core snapshot;
    /// the feed URL is never sent as a substitute identifier.
    public func delete(_ source: RSSSource) async throws {
        let normalized = normalizedSource(source)
        try validateCredentialFreePersistence(normalized)
        do {
            _ = try await tryCoreSubscriptionDelete(normalized)
            clearCache()
            return
        } catch {
            guard allowsLocalCompatibilityWrites else { throw error }
        }

        var sources = try await load()
        sources.removeAll { normalizedURL($0.url) == normalizedURL(normalized.url) }
        try await save(sources)
    }

    /// Trigger Core's stored-subscription refresh without reconstructing the
    /// subscription identity from its URL. Item parsing remains owned by Core;
    /// this store only invalidates its subscription snapshot afterward.
    public func refresh(_ source: RSSSource, evaluatedAt: Int64 = 0) async throws {
        let normalized = normalizedSource(source)
        try validateCredentialFreePersistence(normalized)
        _ = try await tryCoreSubscriptionRefresh(normalized, evaluatedAt: evaluatedAt)
        clearCache()
    }

    public func clearCache() {
        withLock { cache = nil }
    }

    // MARK: - Core Bridge

    private static func currentCoreRuntime() async -> ReaderCoreNativeRuntime? {
        await MainActor.run { RustCoreRuntimeHolder.shared.current }
    }

    private static func makeCoreRequest(
        runtimeProvider: @escaping @Sendable () async -> ReaderCoreNativeRuntime?
    ) -> CoreRequest {
        { method, params in
            guard let runtime = await runtimeProvider() else {
                throw CoreBridgeError.runtimeNotBooted
            }
            let event = try runtime.request(
                method: method,
                requestId: Self.nextRequestId(),
                params: params,
                timeout: Self.coreTimeout
            )
            guard let data = event.data else {
                throw CoreBridgeError.unexpectedResponse
            }
            return data
        }
    }

    /// Core `rss.subscription.list`. Local fallback exists only on the
    /// explicit test/legacy compatibility initializer.
    private func tryCoreSubscriptionList() async throws -> [RSSSource] {
        let data = try await coreRequest("rss.subscription.list", [:])
        guard let subscriptions = data["subscriptions"] as? [[String: Any]] else {
            throw CoreBridgeError.unexpectedResponse
        }
        return try parseCoreSubscriptions(subscriptions)
    }

    /// Strict decoder kept internal for deterministic contract tests. A
    /// malformed Core row invalidates the whole snapshot; silently dropping
    /// it would make the Host present a partial subscription owner view.
    func parseCoreSubscriptions(_ subscriptions: [[String: Any]]) throws -> [RSSSource] {
        try subscriptions.map { sub -> RSSSource in
            guard let subscriptionID = sub["subscriptionId"] as? String,
                  !subscriptionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let feedUrl = sub["feedUrl"] as? String,
                  !feedUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let title = sub["title"] as? String,
                  let enabled = Self.strictBool(sub["enabled"]),
                  let unreadCount = Self.strictInt64(sub["unreadCount"]),
                  unreadCount >= 0 else {
                throw CoreBridgeError.unexpectedResponse
            }
            var source = RSSSource(url: feedUrl)
            source.unknownFields[Self.coreSubscriptionIDField] = .string(subscriptionID)
            if !title.isEmpty {
                source.name = title
            }
            source.enabled = enabled
            if let siteURL = sub["siteUrl"], !(siteURL is NSNull), !(siteURL is String) {
                throw CoreBridgeError.unexpectedResponse
            }
            if let lastEntryID = sub["lastEntryId"], !(lastEntryID is NSNull), !(lastEntryID is String) {
                throw CoreBridgeError.unexpectedResponse
            }
            if let rawFetchedAt = sub["lastFetchAt"], !(rawFetchedAt is NSNull) {
                guard let fetchedAt = Self.strictInt64(rawFetchedAt) else {
                    throw CoreBridgeError.unexpectedResponse
                }
                source.lastFetchedAt = Date(timeIntervalSince1970: Double(fetchedAt) / 1_000)
            }
            try validateCredentialFreePersistence(source)
            return source
        }.sorted(by: sortSources)
    }

    /// Choose add vs update from the Core-owned opaque identity. A source that
    /// came from `list` keeps the exact ID; a source reconstructed by the UI is
    /// matched back to the Core snapshot by URL before any mutation is sent.
    private func tryCoreSubscriptionPersist(_ source: RSSSource) async throws -> Bool {
        guard isCanonicalPublicSubscription(source) else {
            throw CoreBridgeError.extendedRSSContractMissing
        }
        if let subscriptionID = try await resolveCoreSubscriptionID(for: source) {
            _ = try await coreRequest("rss.subscription.update", [
                "subscriptionId": subscriptionID,
                "feedUrl": source.url,
                "title": source.name ?? "",
                "enabled": source.enabled,
            ])
        } else {
            _ = try await coreRequest("rss.subscription.add", [
                "subscriptionId": "ios-\(UUID().uuidString.lowercased())",
                "feedUrl": source.url,
                "title": source.name ?? "",
                "enabled": source.enabled,
            ])
        }
        return true
    }

    /// Core `rss.subscription.delete`.
    private func tryCoreSubscriptionDelete(_ source: RSSSource) async throws -> Bool {
        guard let subscriptionID = try await resolveCoreSubscriptionID(for: source) else {
            throw CoreBridgeError.subscriptionIdentityMissing
        }
        _ = try await coreRequest(
            "rss.subscription.delete",
            ["subscriptionId": subscriptionID]
        )
        return true
    }

    /// Core `rss.subscription.refresh`.
    private func tryCoreSubscriptionRefresh(
        _ source: RSSSource,
        evaluatedAt: Int64
    ) async throws -> Bool {
        guard let subscriptionID = try await resolveCoreSubscriptionID(for: source) else {
            throw CoreBridgeError.subscriptionIdentityMissing
        }
        _ = try await coreRequest("rss.subscription.refresh", [
            "subscriptionId": subscriptionID,
            "evaluatedAt": evaluatedAt,
        ])
        return true
    }

    private func resolveCoreSubscriptionID(for source: RSSSource) async throws -> String? {
        if let subscriptionID = coreSubscriptionID(from: source) {
            return subscriptionID
        }
        let sources: [RSSSource]
        if let cached = withLock({ cache }) {
            sources = cached
        } else {
            sources = try await tryCoreSubscriptionList()
            withLock { cache = sources }
        }
        return sources.first {
            normalizedURL($0.url) == normalizedURL(source.url)
        }.flatMap(coreSubscriptionID)
    }

    func coreSubscriptionID(from source: RSSSource) -> String? {
        guard case .string(let subscriptionID)? = source.unknownFields[Self.coreSubscriptionIDField],
              !subscriptionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return subscriptionID
    }

    private static var requestCounter: UInt64 = 200_000
    private static let counterLock = NSLock()

    private static func nextRequestId() -> UInt64 {
        counterLock.lock()
        defer { counterLock.unlock() }
        requestCounter += 1
        return requestCounter
    }

    private static func strictBool(_ raw: Any?) -> Bool? {
        guard let number = raw as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }

    private static func strictInt64(_ raw: Any?) -> Int64? {
        guard let number = raw as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              !CFNumberIsFloatType(number) else { return nil }
        return Int64(number.stringValue)
    }

    // MARK: - Private helpers

    private static let coreSubscriptionIDField = "subscriptionId"

    private func configureCoders() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    private func ensureParentDirectoryExists() throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func normalizedSource(_ source: RSSSource) -> RSSSource {
        var normalized = source
        normalized.url = source.url.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.name = source.name?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        return normalized
    }

    private func normalizedURL(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func validateCredentialFreePersistence(_ source: RSSSource) throws {
        guard let components = URLComponents(string: source.url),
              let scheme = components.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              components.host?.isEmpty == false else {
            throw CoreBridgeError.invalidPublicFeedURL
        }
        let sensitiveNames = Set([
            "token", "access_token", "refresh_token", "api_key", "apikey", "key",
            "secret", "password", "passwd", "signature", "auth", "authorization",
            "cookie", "session",
        ])
        let sensitiveQuery = components.queryItems?.contains {
            sensitiveNames.contains($0.name.lowercased())
        } ?? false
        guard components.user == nil, components.password == nil, !sensitiveQuery else {
            throw CoreBridgeError.embeddedCredentialRejected
        }
        if let header = source.header?.lowercased(),
           ["authorization:", "proxy-authorization:", "cookie:", "bearer ", "basic "]
            .contains(where: header.contains) {
            throw CoreBridgeError.embeddedCredentialRejected
        }
    }

    private func isCanonicalPublicSubscription(_ source: RSSSource) -> Bool {
        let extendedValues: [String?] = [
            source.header, source.loginUrl, source.loginUi, source.loginCheckJs,
            source.jsLib, source.ruleArticles, source.ruleNextPage, source.ruleTitle,
            source.rulePubDate, source.ruleDescription, source.ruleImage,
            source.ruleLink, source.ruleContent, source.injectJs,
        ]
        return extendedValues.allSatisfy { $0?.isEmpty != false }
            && source.enabledCookieJar != true
    }

    private func sortSources(_ lhs: RSSSource, _ rhs: RSSSource) -> Bool {
        switch (lhs.customOrder, rhs.customOrder) {
        case let (left?, right?) where left != right:
            return left < right
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        default:
            return normalizedURL(lhs.url) < normalizedURL(rhs.url)
        }
    }
}

private enum CoreBridgeError: Error, LocalizedError {
    case runtimeNotBooted
    case unexpectedResponse
    case extendedRSSContractMissing
    case invalidPublicFeedURL
    case embeddedCredentialRejected
    case localCompatibilityWriteForbidden
    case subscriptionIdentityMissing

    var errorDescription: String? {
        switch self {
        case .runtimeNotBooted:
            return "[SLICE11_CORE_NOT_BOOTED] RSS persistence requires the Core runtime"
        case .unexpectedResponse:
            return "[SLICE11_CORE_INVALID_RESULT] RSS Core response has an invalid shape"
        case .extendedRSSContractMissing:
            return "[SLICE11_RSS_AUTH_BINDING_CONTRACT_MISSING] extended/authenticated RSS is not admitted"
        case .invalidPublicFeedURL:
            return "[SLICE11_REMOTE_URL_INVALID] RSS feed URL must be absolute HTTP(S)"
        case .embeddedCredentialRejected:
            return "[SLICE11_EMBEDDED_CREDENTIAL_REJECTED] RSS credentials must remain Host-owned"
        case .localCompatibilityWriteForbidden:
            return "[SLICE11_RSS_LOCAL_OWNER_FORBIDDEN] production RSS cannot write a parallel local store"
        case .subscriptionIdentityMissing:
            return "[SLICE11_RSS_ID_MISSING] Core-owned RSS mutation requires its opaque subscriptionId"
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
