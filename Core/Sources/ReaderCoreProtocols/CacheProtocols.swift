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
