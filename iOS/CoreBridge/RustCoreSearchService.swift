// CoreBridge
//
// RustCoreSearchService: implements `SearchService` by dispatching `book.search`
// to the Rust Core via C ABI. Core auto-builds the search request from the
// source's `searchUrl` template + keyword (AnalyzeUrl), emits `host.request`
// (http.execute), the HostRequestRouter executes it via URLSessionHTTPClient,
// Core parses the response using Legado DSL (ruleSearch), and returns `books`.
//
// S6.1: This replaces the old Swift Core path (DefaultSearchService +
// RequestBuilder + SearchParser) with Rust Core dispatch. The old path is
// retained as strangler fallback.

import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreNativeAdapter

public final class RustCoreSearchService: SearchService, @unchecked Sendable {
    private let runtime: ReaderCoreNativeRuntime
    private let router: HostRequestRouter
    private let requestTimeout: TimeInterval

    public init(
        runtime: ReaderCoreNativeRuntime,
        router: HostRequestRouter? = nil,
        requestTimeout: TimeInterval = 15
    ) {
        self.runtime = runtime
        self.router = router ?? RustCoreServiceSupport.makeRouter(runtime: runtime)
        self.requestTimeout = requestTimeout
    }

    public func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem] {
        let sourceId = source.id?.isEmpty == false ? source.id! : UUID().uuidString
        let inlineSource = RustCoreServiceSupport.serializeSource(source)

        // Use auto-build: pass keyword + page; Core expands {{key}}/{{page}}
        // via AnalyzeUrl, builds the request, and emits host.request.
        let params: [String: Any] = [
            "sourceId": sourceId,
            "keyword": query.keyword,
            "page": query.page,
            "source": inlineSource,
        ]
        let requestId: UInt64 = UInt64(Date().timeIntervalSince1970 * 1000) % 1_000_000 + 100_000
        let command: [String: Any] = [
            "protocolVersion": 1,
            "requestId": NSNumber(value: requestId),
            "method": "book.search",
            "params": params,
        ]

        do {
            let json = try JSONSerialization.data(withJSONObject: command)
            try runtime.send(json: json)

            // Expect host.request (http.execute) from Core.
            let hostRequest = try RustCoreServiceSupport.pollEvent(
                runtime: runtime, requestId: requestId, timeout: requestTimeout
            )
            if hostRequest.type == "error" {
                throw ReaderCoreNativeError.coreError(
                    code: hostRequest.coreErrorCode ?? "INTERNAL",
                    message: hostRequest.coreErrorMessage ?? "book.search failed"
                )
            }
            guard hostRequest.type == "host.request" else {
                throw ReaderCoreNativeError.coreError(
                    code: "INTERNAL",
                    message: "expected host.request, got \(hostRequest.type)"
                )
            }
            // Host executes HTTP, sends host.complete/host.error.
            try await router.handleHostRequest(hostRequest)

            // Expect result (with books) or error.
            let result = try RustCoreServiceSupport.pollEvent(
                runtime: runtime, requestId: requestId, timeout: requestTimeout
            )
            if result.type == "error" {
                throw ReaderCoreNativeError.coreError(
                    code: result.coreErrorCode ?? "INTERNAL",
                    message: result.coreErrorMessage ?? "book.search result failed"
                )
            }
            guard result.type == "result" else {
                throw ReaderCoreNativeError.coreError(
                    code: "INTERNAL",
                    message: "expected result, got \(result.type)"
                )
            }
            return Self.parseBooks(result.data)
        } catch let error as ReaderCoreNativeError {
            throw RustCoreServiceSupport.mapCoreError(error)
        } catch {
            throw RustCoreServiceSupport.mapCoreError(error)
        }
    }

    /// Parse Core `result.data.books` → `[SearchResultItem]`.
    private static func parseBooks(_ data: [String: Any]?) -> [SearchResultItem] {
        guard let books = data?["books"] as? [[String: Any]] else { return [] }
        return books.compactMap { book -> SearchResultItem? in
            guard let title = book["title"] as? String else { return nil }
            let detailURL = (book["bookUrl"] as? String) ?? (book["url"] as? String) ?? ""
            return SearchResultItem(
                title: title,
                detailURL: detailURL,
                author: book["author"] as? String,
                coverURL: book["coverUrl"] as? String,
                intro: book["intro"] as? String
            )
        }
    }
}
