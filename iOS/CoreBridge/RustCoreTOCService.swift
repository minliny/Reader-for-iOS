// CoreBridge
//
// RustCoreTOCService: implements `TOCService` by dispatching `book.toc` to the
// Rust Core via C ABI. iOS passes a pre-built `tocRequest` (from detailURL);
// Core emits host.request, HostRequestRouter executes via URLSessionHTTPClient,
// Core parses using Legado DSL (ruleToc), returns `toc`.
//
// S6.1: Replaces old DefaultTOCService + TOCParser with Rust Core dispatch.

import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreNativeAdapter

public final class RustCoreTOCService: TOCService, @unchecked Sendable {
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

    public func fetchTOC(source: BookSource, detailURL: String) async throws -> [TOCItem] {
        let sourceId = source.id?.isEmpty == false ? source.id! : UUID().uuidString
        let inlineSource = RustCoreServiceSupport.serializeSource(source)
        let tocRequest = RustCoreServiceSupport.makeRequestParams(url: detailURL)

        let params: [String: Any] = [
            "sourceId": sourceId,
            "bookId": detailURL,
            "tocRequest": tocRequest,
            "source": inlineSource,
        ]
        let requestId: UInt64 = UInt64(Date().timeIntervalSince1970 * 1000) % 1_000_000 + 200_000
        let command: [String: Any] = [
            "protocolVersion": 1,
            "requestId": NSNumber(value: requestId),
            "method": "book.toc",
            "params": params,
        ]

        do {
            let json = try JSONSerialization.data(withJSONObject: command)
            try runtime.send(json: json)

            let hostRequest = try RustCoreServiceSupport.pollEvent(
                runtime: runtime, requestId: requestId, timeout: requestTimeout
            )
            if hostRequest.type == "error" {
                throw ReaderCoreNativeError.coreError(
                    code: hostRequest.coreErrorCode ?? "INTERNAL",
                    message: hostRequest.coreErrorMessage ?? "book.toc failed"
                )
            }
            guard hostRequest.type == "host.request" else {
                throw ReaderCoreNativeError.coreError(
                    code: "INTERNAL",
                    message: "expected host.request, got \(hostRequest.type)"
                )
            }
            try await router.handleHostRequest(hostRequest)

            let result = try RustCoreServiceSupport.pollEvent(
                runtime: runtime, requestId: requestId, timeout: requestTimeout
            )
            if result.type == "error" {
                throw ReaderCoreNativeError.coreError(
                    code: result.coreErrorCode ?? "INTERNAL",
                    message: result.coreErrorMessage ?? "book.toc result failed"
                )
            }
            guard result.type == "result" else {
                throw ReaderCoreNativeError.coreError(
                    code: "INTERNAL",
                    message: "expected result, got \(result.type)"
                )
            }
            return Self.parseTOC(result.data)
        } catch {
            throw RustCoreServiceSupport.mapCoreError(error)
        }
    }

    /// Parse Core `result.data.toc` → `[TOCItem]`.
    private static func parseTOC(_ data: [String: Any]?) -> [TOCItem] {
        guard let entries = data?["toc"] as? [[String: Any]] else { return [] }
        return entries.enumerated().compactMap { idx, entry -> TOCItem? in
            guard let title = entry["title"] as? String ?? entry["chapterName"] as? String else { return nil }
            let url = (entry["url"] as? String) ?? (entry["chapterUrl"] as? String) ?? ""
            return TOCItem(
                chapterTitle: title,
                chapterURL: url,
                chapterIndex: (entry["index"] as? Int) ?? idx
            )
        }
    }
}
