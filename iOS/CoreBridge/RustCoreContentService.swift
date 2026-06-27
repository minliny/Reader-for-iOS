// CoreBridge
//
// RustCoreContentService: implements `ContentService` by dispatching
// `chapter.content` to the Rust Core via C ABI. iOS passes a pre-built
// `contentRequest` (from chapterURL); Core emits host.request, HostRequestRouter
// executes via URLSessionHTTPClient, Core parses using Legado DSL (ruleContent),
// returns `content`.
//
// S6.1: Replaces old DefaultContentService + ContentParser with Rust Core dispatch.

import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreNativeAdapter

public final class RustCoreContentService: ContentService, @unchecked Sendable {
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

    public func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage {
        let sourceId = source.id?.isEmpty == false ? source.id! : UUID().uuidString
        let inlineSource = RustCoreServiceSupport.serializeSource(source)
        let contentRequest = RustCoreServiceSupport.makeRequestParams(url: chapterURL)

        let params: [String: Any] = [
            "sourceId": sourceId,
            "bookId": chapterURL,
            "chapterUrl": chapterURL,
            "contentRequest": contentRequest,
            "source": inlineSource,
        ]
        let requestId: UInt64 = UInt64(Date().timeIntervalSince1970 * 1000) % 1_000_000 + 300_000
        let command: [String: Any] = [
            "protocolVersion": 1,
            "requestId": NSNumber(value: requestId),
            "method": "chapter.content",
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
                    message: hostRequest.coreErrorMessage ?? "chapter.content failed"
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
                    message: result.coreErrorMessage ?? "chapter.content result failed"
                )
            }
            guard result.type == "result" else {
                throw ReaderCoreNativeError.coreError(
                    code: "INTERNAL",
                    message: "expected result, got \(result.type)"
                )
            }
            return Self.parseContent(result.data, chapterURL: chapterURL)
        } catch {
            throw RustCoreServiceSupport.mapCoreError(error)
        }
    }

    /// Parse Core `result.data.content` → `ContentPage`.
    private static func parseContent(_ data: [String: Any]?, chapterURL: String) -> ContentPage {
        let title = (data?["title"] as? String) ?? ""
        let content = (data?["content"] as? String) ?? ""
        let nextChapterURL = data?["nextContentUrl"] as? String ?? data?["nextChapterUrl"] as? String
        return ContentPage(
            title: title,
            content: content,
            chapterURL: chapterURL,
            nextChapterURL: nextChapterURL
        )
    }
}
