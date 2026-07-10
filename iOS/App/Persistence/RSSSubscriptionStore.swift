import Foundation
import ReaderCoreModels
import ReaderCoreNativeAdapter

public final class RSSSubscriptionStore: @unchecked Sendable {
    public static let shared = RSSSubscriptionStore()

    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()
    private var cache: [RSSSource]?

    /// Timeout for Core bridge calls (rss.subscription.* may involve storage I/O).
    private static let coreTimeout: TimeInterval = 30

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ReaderApp", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("rss_subscriptions.json")
        configureCoders()
    }

    public init(storageURL: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.fileURL = storageURL
        configureCoders()
    }

    public func load() async throws -> [RSSSource] {
        if let cached = withLock({ cache }) {
            return cached
        }

        // Core bridge: try rss.subscription.list first; fall back to local file.
        if let sources = try? await tryCoreSubscriptionList() {
            withLock { cache = sources }
            return sources
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
        let sorted = sources.sorted(by: sortSources)
        withLock { cache = sorted }

        try ensureParentDirectoryExists()
        let data = try encoder.encode(sorted)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func addOrUpdate(_ source: RSSSource) async throws {
        let normalized = normalizedSource(source)

        // Core bridge: try rss.subscription.add first; fall back to local file.
        if try await tryCoreSubscriptionAdd(normalized) {
            clearCache()
            return
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
        // Core bridge: try rss.subscription.delete first; fall back to local file.
        if try await tryCoreSubscriptionDelete(url) {
            clearCache()
            return
        }

        var sources = try await load()
        sources.removeAll { normalizedURL($0.url) == normalizedURL(url) }
        try await save(sources)
    }

    public func clearCache() {
        withLock { cache = nil }
    }

    // MARK: - Core Bridge

    /// Get the shared ReaderCoreNativeRuntime if booted. Returns nil when the
    /// Core bridge is unavailable (e.g. unit tests, shell CI without native .so).
    private func coreRuntime() async -> ReaderCoreNativeRuntime? {
        await MainActor.run { RustCoreRuntimeHolder.shared.current }
    }

    /// Try Core `rss.subscription.list`. Returns `[RSSSource]` on success,
    /// throws on failure (caller catches and falls back to local file).
    private func tryCoreSubscriptionList() async throws -> [RSSSource] {
        guard let runtime = await coreRuntime() else {
            throw CoreBridgeError.runtimeNotBooted
        }
        let requestId = Self.nextRequestId()
        let event = try runtime.request(
            method: "rss.subscription.list",
            requestId: requestId,
            params: [:],
            timeout: Self.coreTimeout
        )
        guard let subscriptions = event.data?["subscriptions"] as? [[String: Any]] else {
            throw CoreBridgeError.unexpectedResponse
        }
        return subscriptions.compactMap { sub -> RSSSource? in
            guard let feedUrl = sub["feedUrl"] as? String, !feedUrl.isEmpty else { return nil }
            var source = RSSSource(url: feedUrl)
            if let title = sub["title"] as? String, !title.isEmpty {
                source.name = title
            }
            return source
        }.sorted(by: sortSources)
    }

    /// Try Core `rss.subscription.add`. Returns true on success, throws on
    /// failure (caller catches and falls back to local file).
    private func tryCoreSubscriptionAdd(_ source: RSSSource) async throws -> Bool {
        guard let runtime = await coreRuntime() else {
            throw CoreBridgeError.runtimeNotBooted
        }
        let params: [String: Any] = [
            "feedUrl": source.url,
            "title": source.name ?? "",
        ]
        let requestId = Self.nextRequestId()
        _ = try runtime.request(
            method: "rss.subscription.add",
            requestId: requestId,
            params: params,
            timeout: Self.coreTimeout
        )
        return true
    }

    /// Try Core `rss.subscription.delete`. Returns true on success, throws on
    /// failure (caller catches and falls back to local file).
    private func tryCoreSubscriptionDelete(_ url: String) async throws -> Bool {
        guard let runtime = await coreRuntime() else {
            throw CoreBridgeError.runtimeNotBooted
        }
        let params: [String: Any] = ["feedUrl": url]
        let requestId = Self.nextRequestId()
        _ = try runtime.request(
            method: "rss.subscription.delete",
            requestId: requestId,
            params: params,
            timeout: Self.coreTimeout
        )
        return true
    }

    private static var requestCounter: UInt64 = 200_000
    private static let counterLock = NSLock()

    private static func nextRequestId() -> UInt64 {
        counterLock.lock()
        defer { counterLock.unlock() }
        requestCounter += 1
        return requestCounter
    }

    // MARK: - Private helpers

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

private enum CoreBridgeError: Error {
    case runtimeNotBooted
    case unexpectedResponse
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
