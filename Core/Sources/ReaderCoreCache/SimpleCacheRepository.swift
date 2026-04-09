import Foundation
import ReaderCoreProtocols

private actor CacheEntryStore {
    private var entries: [String: CacheEntry] = [:]

    func get(_ key: String) -> CacheEntry? {
        guard let entry = entries[key], !entry.isExpired else {
            if entries[key] != nil {
                entries.removeValue(forKey: key)
            }
            return nil
        }
        return entry
    }

    func set(_ entry: CacheEntry, key: String) {
        entries[key] = entry
    }

    func remove(_ key: String) {
        entries.removeValue(forKey: key)
    }

    func clear(scope: CacheScope?) {
        if let scope = scope {
            entries = entries.filter { !$0.key.hasPrefix("\(scope.rawValue)|") }
        } else {
            entries.removeAll()
        }
    }
}

public final class SimpleCacheRepository: CacheRepository, CacheStore, @unchecked Sendable {
    private let store = CacheEntryStore()

    public init() {}

    private func key(for scope: CacheScope, key: String) -> String {
        "\(scope.rawValue)|\(key)"
    }

    public func get(scope: CacheScope, key: String) async throws -> CacheEntry? {
        await store.get(self.key(for: scope, key: key))
    }

    public func set(_ entry: CacheEntry) async throws {
        await store.set(entry, key: key(for: entry.scope, key: entry.key))
    }

    public func remove(scope: CacheScope, key: String) async throws {
        await store.remove(self.key(for: scope, key: key))
    }

    public func clear(scope: CacheScope?) async throws {
        await store.clear(scope: scope)
    }

    public func getSearchResponse(key: String) async throws -> Data? {
        try await get(scope: .search, key: key)?.payload
    }

    public func setSearchResponse(key: String, payload: Data, ttlSeconds: Int) async throws {
        let entry = CacheEntry(
            key: key,
            scope: .search,
            ttlSeconds: ttlSeconds,
            payload: payload
        )
        try await set(entry)
    }

    public func getTOCResponse(key: String) async throws -> Data? {
        try await get(scope: .toc, key: key)?.payload
    }

    public func setTOCResponse(key: String, payload: Data, ttlSeconds: Int) async throws {
        let entry = CacheEntry(
            key: key,
            scope: .toc,
            ttlSeconds: ttlSeconds,
            payload: payload
        )
        try await set(entry)
    }

    public func getContentResponse(key: String) async throws -> Data? {
        try await get(scope: .content, key: key)?.payload
    }

    public func setContentResponse(key: String, payload: Data, ttlSeconds: Int) async throws {
        let entry = CacheEntry(
            key: key,
            scope: .content,
            ttlSeconds: ttlSeconds,
            payload: payload
        )
        try await set(entry)
    }
}
