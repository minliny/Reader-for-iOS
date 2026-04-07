import Foundation
import ReaderCoreProtocols

public struct MinimalCacheContract: Sendable, Equatable {
    public let keyFields: [String]
    public let storeFields: [String]
    public let hitCondition: [String]
    public let stalePolicy: [String]
    public let refreshPolicy: [String]

    public static let currentPhase = MinimalCacheContract(
        keyFields: ["url", "method", "selectedHeaders"],
        storeFields: ["responseBody", "contentType"],
        hitCondition: ["identicalRequest"],
        stalePolicy: ["allow_stale_for_same_request_in_current_phase"],
        refreshPolicy: ["not_implemented"]
    )
}

public final class MinimalCacheHTTPClient: HTTPClient, @unchecked Sendable {
    private struct CacheKey: Hashable {
        var url: String
        var method: String
        var selectedHeaders: [String]
    }

    private struct CachedResponse {
        var responseBody: Data
        var contentType: String?
        var statusCode: Int
    }

    private let upstream: HTTPClient
    private let selectedHeaderNames: Set<String>?
    private var store: [CacheKey: CachedResponse] = [:]
    private let lock = NSLock()

    public init(upstream: HTTPClient, selectedHeaderNames: Set<String>? = nil) {
        self.upstream = upstream
        self.selectedHeaderNames = selectedHeaderNames.map { Set($0.map { $0.lowercased() }) }
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let key = cacheKey(for: request)

        if let cached = cachedResponse(for: key) {
            var headers: [String: String] = [:]
            if let contentType = cached.contentType {
                headers["Content-Type"] = contentType
            }
            return HTTPResponse(statusCode: cached.statusCode, headers: headers, data: cached.responseBody)
        }

        let response = try await upstream.send(request)
        store(response, for: key)
        return response
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        store.removeAll()
    }

    private func cachedResponse(for key: CacheKey) -> CachedResponse? {
        lock.lock()
        defer { lock.unlock() }
        return store[key]
    }

    private func store(_ response: HTTPResponse, for key: CacheKey) {
        lock.lock()
        defer { lock.unlock() }
        store[key] = CachedResponse(
            responseBody: response.data,
            contentType: contentType(from: response.headers),
            statusCode: response.statusCode
        )
    }

    private func cacheKey(for request: HTTPRequest) -> CacheKey {
        let normalizedHeaders = request.headers
            .compactMap { name, value -> String? in
                let normalizedName = name.lowercased()
                if let selectedHeaderNames, !selectedHeaderNames.contains(normalizedName) {
                    return nil
                }
                return "\(normalizedName):\(value)"
            }
            .sorted()

        return CacheKey(
            url: request.url,
            method: request.method.uppercased(),
            selectedHeaders: normalizedHeaders
        )
    }

    private func contentType(from headers: [String: String]) -> String? {
        headers.first { $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame }?.value
    }
}
