import Foundation
import ReaderCoreProtocols

// MARK: - InMemoryResponseCache
// Actor-isolated in-memory implementation of ResponseCache.
//
// Design constraints:
//   - No disk IO.
//   - No platform-specific cache API (no NSCache, no URLCache).
//   - get() auto-evicts expired entries on access.
//   - purgeExpired() sweeps the full dictionary.

public actor InMemoryResponseCache: ResponseCache {

    private var storage: [ResponseCacheKey: CachedHTTPResponse] = [:]

    public init() {}

    // MARK: - ResponseCache conformance

    /// Returns a cached response if present and not expired; nil otherwise.
    /// Expired entries are removed on access.
    public func get(_ key: ResponseCacheKey, now: Date) async -> CachedHTTPResponse? {
        guard let response = storage[key] else { return nil }
        if response.isExpired(now: now) {
            storage.removeValue(forKey: key)
            return nil
        }
        return response
    }

    /// Stores a response under the given key, overwriting any existing entry.
    public func put(_ response: CachedHTTPResponse, for key: ResponseCacheKey) async {
        storage[key] = response
    }

    /// Removes the entry for the given key. No-op if key is not present.
    public func remove(_ key: ResponseCacheKey) async {
        storage.removeValue(forKey: key)
    }

    /// Removes all cached entries.
    public func removeAll() async {
        storage.removeAll()
    }

    /// Removes all entries whose TTL has elapsed as of `now`.
    public func purgeExpired(now: Date) async {
        storage = storage.filter { !$0.value.isExpired(now: now) }
    }
}
