import Foundation
import ReaderCoreModels

public final class RSSSubscriptionStore: @unchecked Sendable {
    public static let shared = RSSSubscriptionStore()

    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()
    private var cache: [RSSSource]?

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
        var sources = try await load()
        if let index = sources.firstIndex(where: { normalizedURL($0.url) == normalizedURL(normalized.url) }) {
            sources[index] = normalized
        } else {
            sources.append(normalized)
        }
        try await save(sources)
    }

    public func delete(url: String) async throws {
        var sources = try await load()
        sources.removeAll { normalizedURL($0.url) == normalizedURL(url) }
        try await save(sources)
    }

    public func clearCache() {
        withLock { cache = nil }
    }

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

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
