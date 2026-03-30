import Foundation
import ReaderCoreProtocols

public final class SimpleCacheRepository: CacheRepository, CacheStore, @unchecked Sendable {
    private var store: [String: CacheEntry] = [:]
    private let lock = NSLock()

    public init() {}

    private func key(for scope: CacheScope, key: String) -> String {
        "\(scope.rawValue)|\(key)"
    }

    public func get(scope: CacheScope, key: String) async throws -> CacheEntry? {
        lock.lock()
        defer { lock.unlock() }

        let k = self.key(for: scope, key: key)
        guard let entry = store[k], !entry.isExpired else {
            if let _ = store[k] {
                store.removeValue(forKey: k)
            }
            return nil
        }
        return entry
    }

    public func set(_ entry: CacheEntry) async throws {
        lock.lock()
        defer { lock.unlock() }

        let k = key(for: entry.scope, key: entry.key)
        store[k] = entry
    }

    public func remove(scope: CacheScope, key: String) async throws {
        lock.lock()
        defer { lock.unlock() }

        let k = self.key(for: scope, key: key)
        store.removeValue(forKey: k)
    }

    public func clear(scope: CacheScope?) async throws {
        lock.lock()
        defer { lock.unlock() }

        if let scope = scope {
            store = store.filter { !$0.key.hasPrefix("\(scope.rawValue)|") }
        } else {
            store.removeAll()
        }
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
