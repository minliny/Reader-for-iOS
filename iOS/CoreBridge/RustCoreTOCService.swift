// CoreBridge
//
// RustCoreTOCService: implements `TOCService` by dispatching `book.toc` to the
// Rust Core via C ABI. iOS passes a pre-built `tocRequest` (from detailURL);
// Core emits host.request, HostRequestRouter executes via URLSessionHTTPClient,
// Core parses using Legado DSL (ruleToc), returns `toc`.
//
// S6.1: Replaces old DefaultTOCService + TOCParser with Rust Core dispatch.

import Foundation
import ReaderCoreFoundation
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
        try await fetchTOCStage(
            source: source,
            bookID: detailURL,
            tocURL: detailURL
        ).items
    }

    /// Fetch the complete typed TOC-stage result for a selected detail result.
    /// Root detail variables are forwarded to Core and each returned entry keeps
    /// its own variables for the subsequent content request.
    public func fetchTOCStage(
        source: BookSource,
        bookID: String,
        tocURL: String,
        variables: [String: String] = [:]
    ) async throws -> CoreTOCStageResult {
        do {
            return try await startTOCStage(
                source: source,
                bookID: bookID,
                tocURL: tocURL,
                variables: variables
            ).value()
        } catch {
            throw RustCoreServiceSupport.mapCoreError(error)
        }
    }

    /// Starts `book.toc` as a cancellable request-scoped command. Per-entry
    /// variables remain in its typed result until the content stage consumes
    /// the selected entry.
    public func startTOCStage(
        source: BookSource,
        bookID: String,
        tocURL: String,
        variables: [String: String] = [:],
        correlationID: String? = nil
    ) throws -> RustCoreRequestScopedCommand<CoreTOCStageResult> {
        let sourceId = source.id?.isEmpty == false ? source.id! : UUID().uuidString
        let inlineSource = RustCoreServiceSupport.serializeSource(source, sourceID: sourceId)
        let params = Self.makeTOCParams(
            sourceID: sourceId,
            bookID: bookID,
            tocURL: tocURL,
            variables: variables,
            inlineSource: inlineSource
        )
        let handle = try RustCoreRequestScopedCommand<CoreTOCStageResult>(
            runtime: runtime,
            router: router,
            requestID: RustCoreServiceSupport.allocateRequestID(),
            correlationID: correlationID,
            method: "book.toc",
            params: params,
            timeout: requestTimeout,
            resultTransform: Self.parseTOCStage
        )
        try handle.start()
        return handle
    }

    /// Starts `book.toc` via Core's persisted source lookup. This intentionally
    /// omits the optional inline source object for a bookshelf-originated
    /// transaction; callers must not synthesize source rules in the UI layer.
    public func startTOCStage(
        sourceID: String,
        bookID: String,
        tocURL: String,
        variables: [String: String] = [:],
        correlationID: String? = nil
    ) throws -> RustCoreRequestScopedCommand<CoreTOCStageResult> {
        let params = Self.makeTOCParams(
            sourceID: sourceID,
            bookID: bookID,
            tocURL: tocURL,
            variables: variables,
            inlineSource: nil
        )
        let handle = try RustCoreRequestScopedCommand<CoreTOCStageResult>(
            runtime: runtime,
            router: router,
            requestID: RustCoreServiceSupport.allocateRequestID(),
            correlationID: correlationID,
            method: "book.toc",
            params: params,
            timeout: requestTimeout,
            resultTransform: Self.parseTOCStage
        )
        try handle.start()
        return handle
    }

    static func makeTOCParams(
        sourceID: String,
        bookID: String,
        tocURL: String,
        variables: [String: String],
        inlineSource: [String: Any]?
    ) -> [String: Any] {
        var params: [String: Any] = [
            "sourceId": sourceID,
            "bookId": bookID,
            "tocUrl": tocURL,
            "tocRequest": RustCoreServiceSupport.makeRequestParams(url: tocURL),
            "variables": variables,
        ]
        if let inlineSource { params["source"] = inlineSource }
        return params
    }

    /// Parse Core `result.data.toc` without dropping per-entry variables.
    static func parseTOCStage(_ data: [String: Any]?) -> CoreTOCStageResult {
        guard let entries = data?["toc"] as? [[String: Any]] else {
            return CoreTOCStageResult(
                sourceID: data?["sourceId"] as? String,
                bookID: data?["bookId"] as? String,
                entries: []
            )
        }
        let parsed = entries.enumerated().compactMap { idx, entry -> CoreTOCStageEntry? in
            guard let title = entry["title"] as? String ?? entry["chapterName"] as? String else { return nil }
            let url = (entry["url"] as? String) ?? (entry["chapterUrl"] as? String) ?? ""
            let variables = CoreReadingStageValue.stringMap(entry["variables"])
            var unknownFields: [String: JSONValue] = [:]
            if !variables.isEmpty {
                unknownFields["variables"] = CoreReadingStageValue.jsonObject(variables)
            }
            let item = TOCItem(
                chapterTitle: title,
                chapterURL: url,
                chapterIndex: CoreReadingStageValue.integer(entry["index"], fallback: idx),
                isVip: (entry["isVip"] as? Bool) ?? false,
                unknownFields: unknownFields
            )
            return CoreTOCStageEntry(item: item, variables: variables)
        }
        return CoreTOCStageResult(
            sourceID: data?["sourceId"] as? String,
            bookID: data?["bookId"] as? String,
            entries: parsed
        )
    }
}
