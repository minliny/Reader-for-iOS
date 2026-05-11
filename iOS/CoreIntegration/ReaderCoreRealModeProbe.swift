import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderIOSPlatformAdapters

/// Compile-time probe for Reader-Core public API surface.
/// This file does NOT call network, parse real book sources, or depend on parser internals.
/// It only verifies that the public facade types are visible and constructible from Reader-iOS.
public enum ReaderCoreRealModeProbe {

    // MARK: - Models visibility

    public static func probeModels() {
        let _ = BookSource(bookSourceName: "probe")
        let _ = SearchQuery(keyword: "probe", page: 1)
        let _ = SearchResultItem(title: "probe", detailURL: "https://example.com")
        let _ = TOCItem(chapterTitle: "probe", chapterURL: "https://example.com", chapterIndex: 0)
        let _ = ContentPage(title: "probe", content: "probe", chapterURL: "https://example.com")
        let _ = CompatibilityMark(level: .A, status: .pass)
        let _ = ReaderError(code: .unknown, message: "probe")
        let _ = FailureRecord(type: .SEARCH_FAILED, reason: "probe")
    }

    // MARK: - Protocol visibility (facade contracts)

    public static func probeProtocols() {
        let _: any BookSourceRepository = ProbeInMemoryBookSourceRepository()
        let _: any BookSourceDecoder = DefaultBookSourceDecoder()
    }

    // MARK: - Network protocol visibility

    public static func probeNetworkProtocols() {
        let _: any HTTPClient = ProbeHTTPClient()
        let _: any RequestBuilder = DefaultBookSourceRequestBuilder()
    }

    // MARK: - Cache protocol visibility

    public static func probeCacheProtocols() {
        let _: any CacheStore = InMemoryCacheStore()
        let _: any CacheRepository = InMemoryCacheRepository()
    }

    // MARK: - Platform adapter protocol visibility

    public static func probePlatformAdapters() {
        let _: any HTTPClientProtocol = IOSHTTPAdapter()
        let _: any LocalStorageProtocol = IOSStorageAdapter()
        let _: any SnapshotStoreProtocol = IOSSnapshotStore()
        let _: any AppLoggerProtocol = IOSLoggerAdapter()
    }

    // MARK: - Error mapping visibility

    public static func probeErrorMapping() {
        let _ = MappedReaderError(code: .UNKNOWN, stage: .network_transport, message: "probe")
        let _ = ReaderErrorContext(sampleId: "probe")
    }
}

// MARK: - Stub implementations for compile probe only

final class ProbeInMemoryBookSourceRepository: BookSourceRepository, @unchecked Sendable {
    private var sources: [String: BookSource] = [:]
    private let lock = NSLock()

    func save(_ source: BookSource) async throws {
        lock.lock(); defer { lock.unlock() }
        sources[source.id ?? UUID().uuidString] = source
    }

    func allSources() async throws -> [BookSource] {
        lock.lock(); defer { lock.unlock() }
        return Array(sources.values)
    }

    func source(id: String) async throws -> BookSource? {
        lock.lock(); defer { lock.unlock() }
        return sources[id]
    }
}

final class DefaultBookSourceRequestBuilder: RequestBuilder, Sendable {
    func makeSearchRequest(source: BookSource, query: SearchQuery) throws -> HTTPRequest {
        HTTPRequest(url: source.searchUrl ?? "")
    }

    func makeTOCRequest(source: BookSource, detailURL: String) throws -> HTTPRequest {
        HTTPRequest(url: detailURL)
    }

    func makeContentRequest(source: BookSource, chapterURL: String) throws -> HTTPRequest {
        HTTPRequest(url: chapterURL)
    }
}

final class ProbeHTTPClient: HTTPClient, Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        HTTPResponse(statusCode: 200, headers: [:], data: Data())
    }
}

final class InMemoryCacheStore: CacheStore, @unchecked Sendable {
    private var entries: [String: CacheEntry] = [:]
    private let lock = NSLock()

    func get(scope: CacheScope, key: String) async throws -> CacheEntry? {
        lock.lock(); defer { lock.unlock() }
        return entries["\(scope.rawValue)_\(key)"]
    }

    func set(_ entry: CacheEntry) async throws {
        lock.lock(); defer { lock.unlock() }
        entries["\(entry.scope.rawValue)_\(entry.key)"] = entry
    }

    func remove(scope: CacheScope, key: String) async throws {
        lock.lock(); defer { lock.unlock() }
        entries.removeValue(forKey: "\(scope.rawValue)_\(key)")
    }

    func clear(scope: CacheScope?) async throws {
        lock.lock(); defer { lock.unlock() }
        if let scope = scope {
            let prefix = "\(scope.rawValue)_"
            entries = entries.filter { !$0.key.hasPrefix(prefix) }
        } else {
            entries.removeAll()
        }
    }
}

final class InMemoryCacheRepository: CacheRepository, @unchecked Sendable {
    private var data: [String: Data] = [:]
    private let lock = NSLock()

    func getSearchResponse(key: String) async throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        return data["search_\(key)"]
    }

    func setSearchResponse(key: String, payload: Data, ttlSeconds: Int) async throws {
        lock.lock(); defer { lock.unlock() }
        data["search_\(key)"] = payload
    }

    func getTOCResponse(key: String) async throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        return data["toc_\(key)"]
    }

    func setTOCResponse(key: String, payload: Data, ttlSeconds: Int) async throws {
        lock.lock(); defer { lock.unlock() }
        data["toc_\(key)"] = payload
    }

    func getContentResponse(key: String) async throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        return data["content_\(key)"]
    }

    func setContentResponse(key: String, payload: Data, ttlSeconds: Int) async throws {
        lock.lock(); defer { lock.unlock() }
        data["content_\(key)"] = payload
    }

    func clear(scope: CacheScope?) async throws {
        lock.lock(); defer { lock.unlock() }
        if let scope = scope {
            let prefix = "\(scope.rawValue)_"
            data = data.filter { !$0.key.hasPrefix(prefix) }
        } else {
            data.removeAll()
        }
    }
}
