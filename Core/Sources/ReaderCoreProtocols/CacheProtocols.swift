import Foundation
import ReaderCoreModels

public enum CacheScope: String, Codable, Sendable {
    case search
    case toc
    case content
}

public struct CacheEntry: Codable, Sendable, Equatable {
    public var key: String
    public var scope: CacheScope
    public var createdAt: Date
    public var ttlSeconds: Int
    public var payload: Data

    public init(key: String, scope: CacheScope, createdAt: Date = Date(), ttlSeconds: Int, payload: Data) {
        self.key = key
        self.scope = scope
        self.createdAt = createdAt
        self.ttlSeconds = ttlSeconds
        self.payload = payload
    }

    public var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > TimeInterval(ttlSeconds)
    }
}

public protocol CacheStore: Sendable {
    func get(scope: CacheScope, key: String) async throws -> CacheEntry?
    func set(_ entry: CacheEntry) async throws
    func remove(scope: CacheScope, key: String) async throws
    func clear(scope: CacheScope?) async throws
}

public protocol CacheRepository: Sendable {
    func getSearchResponse(key: String) async throws -> Data?
    func setSearchResponse(key: String, payload: Data, ttlSeconds: Int) async throws
    func getTOCResponse(key: String) async throws -> Data?
    func setTOCResponse(key: String, payload: Data, ttlSeconds: Int) async throws
    func getContentResponse(key: String) async throws -> Data?
    func setContentResponse(key: String, payload: Data, ttlSeconds: Int) async throws
    func clear(scope: CacheScope?) async throws
}

// MARK: - HTTP Response Cache Contract

/// Key for an in-memory HTTP response cache entry.
/// `method` is always uppercased; `varyHeaders` enables Vary-header differentiation.
public struct ResponseCacheKey: Sendable, Codable {
    public var method: String
    public var normalizedURL: String
    public var varyHeaders: [String: String]

    public init(
        method: String,
        normalizedURL: String,
        varyHeaders: [String: String] = [:]
    ) {
        self.method = method.uppercased()
        self.normalizedURL = normalizedURL
        self.varyHeaders = varyHeaders
    }
}

extension ResponseCacheKey {
    private enum CodingKeys: String, CodingKey {
        case method
        case normalizedURL
        case varyHeaders
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let method = try container.decode(String.self, forKey: .method)
        let normalizedURL = try container.decode(String.self, forKey: .normalizedURL)
        let varyHeaders = try container.decode([String: String].self, forKey: .varyHeaders)
        self.init(method: method, normalizedURL: normalizedURL, varyHeaders: varyHeaders)
    }
}

extension ResponseCacheKey: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(method)
        hasher.combine(normalizedURL)
        for (k, v) in varyHeaders.sorted(by: { $0.key < $1.key }) {
            hasher.combine(k)
            hasher.combine(v)
        }
    }

    public static func == (lhs: ResponseCacheKey, rhs: ResponseCacheKey) -> Bool {
        lhs.method == rhs.method
            && lhs.normalizedURL == rhs.normalizedURL
            && lhs.varyHeaders == rhs.varyHeaders
    }
}

/// A cached HTTP response with TTL metadata.
public struct CachedHTTPResponse: Sendable, Codable, Equatable {
    public var statusCode: Int
    public var headers: [String: String]
    public var body: Data
    public var createdAt: Date
    public var ttl: TimeInterval

    public init(
        statusCode: Int,
        headers: [String: String],
        body: Data,
        createdAt: Date = Date(),
        ttl: TimeInterval
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.createdAt = createdAt
        self.ttl = ttl
    }

    public func isExpired(now: Date = Date()) -> Bool {
        now.timeIntervalSince(createdAt) > ttl
    }
}

/// Minimum cache protocol for HTTP response caching.
/// Implementations must be actor-isolated or otherwise Sendable-safe.
public protocol ResponseCache: Sendable {
    func get(_ key: ResponseCacheKey, now: Date) async -> CachedHTTPResponse?
    func put(_ response: CachedHTTPResponse, for key: ResponseCacheKey) async
    func remove(_ key: ResponseCacheKey) async
    func removeAll() async
    func purgeExpired(now: Date) async
}
