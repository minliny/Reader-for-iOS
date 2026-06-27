// CoreBridge
//
// RustCoreBookDetailService: dispatches `book.detail` to Rust Core via C ABI.
// Core auto-builds the detail request from the source's `ruleBookInfo` +
// the book's bookUrl, emits `host.request` (http.execute), the HostRequestRouter
// executes it via URLSessionHTTPClient, Core parses the response using Legado
// DSL (ruleBookInfo), and returns the enriched book metadata.
//
// S6.2: This closes the gap where ReaderCoreServiceProvider.getBookDetail had
// no rustCore branch and fell through to mock (returning a title-only shell).

import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreNativeAdapter

public final class RustCoreBookDetailService: @unchecked Sendable {
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

    /// Fetch book detail (enriched metadata) via Rust Core `book.detail`.
    /// - Parameters:
    ///   - source: The BookSource providing ruleBookInfo.
    ///   - book: The SearchResultItem from search (must have detailURL == bookUrl).
    /// - Returns: Enriched SearchResultItem with intro/coverUrl/author/etc.
    public func fetchDetail(source: BookSource, book: SearchResultItem) async throws -> SearchResultItem {
        let sourceId = source.id?.isEmpty == false ? source.id! : UUID().uuidString
        let inlineSource = RustCoreServiceSupport.serializeSource(source)

        let params: [String: Any] = [
            "sourceId": sourceId,
            "book": [
                "bookUrl": book.detailURL,
                "title": book.title,
                "author": book.author ?? "",
                "coverUrl": book.coverURL ?? "",
                "intro": book.intro ?? "",
            ],
            "source": inlineSource,
        ]
        let requestId: UInt64 = UInt64(Date().timeIntervalSince1970 * 1000) % 1_000_000 + 200_000
        let command: [String: Any] = [
            "protocolVersion": 1,
            "requestId": NSNumber(value: requestId),
            "method": "book.detail",
            "params": params,
        ]

        do {
            let json = try JSONSerialization.data(withJSONObject: command)
            try runtime.send(json: json)

            // Expect host.request (http.execute) from Core for ruleBookInfo URL.
            let hostRequest = try RustCoreServiceSupport.pollEvent(
                runtime: runtime, requestId: requestId, timeout: requestTimeout
            )
            if hostRequest.type == "error" {
                throw ReaderCoreNativeError.coreError(
                    code: hostRequest.coreErrorCode ?? "INTERNAL",
                    message: hostRequest.coreErrorMessage ?? "book.detail failed"
                )
            }
            guard hostRequest.type == "host.request" else {
                throw ReaderCoreNativeError.coreError(
                    code: "INTERNAL",
                    message: "expected host.request, got \(hostRequest.type)"
                )
            }
            try await router.handleHostRequest(hostRequest)

            // Expect result (with enriched book) or error.
            let result = try RustCoreServiceSupport.pollEvent(
                runtime: runtime, requestId: requestId, timeout: requestTimeout
            )
            if result.type == "error" {
                throw ReaderCoreNativeError.coreError(
                    code: result.coreErrorCode ?? "INTERNAL",
                    message: result.coreErrorMessage ?? "book.detail result failed"
                )
            }
            guard result.type == "result" else {
                throw ReaderCoreNativeError.coreError(
                    code: "INTERNAL",
                    message: "expected result, got \(result.type)"
                )
            }
            return Self.parseBookDetail(result.data, fallback: book)
        } catch let error as ReaderCoreNativeError {
            throw RustCoreServiceSupport.mapCoreError(error)
        } catch {
            throw RustCoreServiceSupport.mapCoreError(error)
        }
    }

    /// Parse Core `result.data.book` -> enriched `SearchResultItem`.
    /// Falls back to the original `book` for fields Core didn't return.
    private static func parseBookDetail(_ data: [String: Any]?, fallback: SearchResultItem) -> SearchResultItem {
        guard let book = data?["book"] as? [String: Any] else {
            return fallback
        }
        return SearchResultItem(
            title: (book["title"] as? String) ?? fallback.title,
            detailURL: (book["bookUrl"] as? String) ?? fallback.detailURL,
            author: (book["author"] as? String) ?? fallback.author,
            coverURL: (book["coverUrl"] as? String) ?? fallback.coverURL,
            intro: (book["intro"] as? String) ?? fallback.intro
        )
    }
}
