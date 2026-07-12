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
import ReaderCoreFoundation
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
        try await fetchContentStage(
            source: source,
            context: CoreChapterContentRequestContext(
                bookID: chapterURL,
                chapterTitle: "",
                chapterIndex: 0,
                chapterURL: chapterURL
            )
        ).page
    }

    /// Fetch content while retaining the selected TOC identity and variables.
    public func fetchContentStage(
        source: BookSource,
        context: CoreChapterContentRequestContext
    ) async throws -> CoreChapterContentStageResult {
        do {
            return try await startContentStage(
                source: source,
                context: context
            ).value()
        } catch {
            throw RustCoreServiceSupport.mapCoreError(error)
        }
    }

    /// Starts `chapter.content` with the exact selected TOC identity and a
    /// cancellable Core/Host handle. `context` is deliberately captured by the
    /// parser so a late result cannot invent a title/index/url after selection.
    public func startContentStage(
        source: BookSource,
        context: CoreChapterContentRequestContext,
        correlationID: String? = nil
    ) throws -> RustCoreRequestScopedCommand<CoreChapterContentStageResult> {
        let sourceId = source.id?.isEmpty == false ? source.id! : UUID().uuidString
        let inlineSource = RustCoreServiceSupport.serializeSource(source, sourceID: sourceId)
        let params = Self.makeContentParams(
            sourceID: sourceId,
            context: context,
            inlineSource: inlineSource
        )
        let handle = try RustCoreRequestScopedCommand<CoreChapterContentStageResult>(
            runtime: runtime,
            router: router,
            requestID: RustCoreServiceSupport.allocateRequestID(),
            correlationID: correlationID,
            method: "chapter.content",
            params: params,
            timeout: requestTimeout,
            resultTransform: { data in
                Self.parseContentStage(
                    data,
                    sourceID: sourceId,
                    context: context
                )
            }
        )
        try handle.start()
        return handle
    }

    /// Starts `chapter.content` through the persisted Core source. The
    /// bookshelf Pilot carries only source/book identity and the typed TOC
    /// selection, never a UI-fabricated `BookSource` payload.
    public func startContentStage(
        sourceID: String,
        context: CoreChapterContentRequestContext,
        correlationID: String? = nil
    ) throws -> RustCoreRequestScopedCommand<CoreChapterContentStageResult> {
        let params = Self.makeContentParams(
            sourceID: sourceID,
            context: context,
            inlineSource: nil
        )
        let handle = try RustCoreRequestScopedCommand<CoreChapterContentStageResult>(
            runtime: runtime,
            router: router,
            requestID: RustCoreServiceSupport.allocateRequestID(),
            correlationID: correlationID,
            method: "chapter.content",
            params: params,
            timeout: requestTimeout,
            resultTransform: { data in
                Self.parseContentStage(
                    data,
                    sourceID: sourceID,
                    context: context
                )
            }
        )
        try handle.start()
        return handle
    }

    static func makeContentParams(
        sourceID: String,
        context: CoreChapterContentRequestContext,
        inlineSource: [String: Any]?
    ) -> [String: Any] {
        var params: [String: Any] = [
            "sourceId": sourceID,
            "bookId": context.bookID,
            "chapterTitle": context.chapterTitle,
            "chapterIndex": context.chapterIndex,
            "chapterUrl": context.chapterURL,
            "chapterRequest": RustCoreServiceSupport.makeRequestParams(url: context.chapterURL),
            "variables": context.variables,
        ]
        if let inlineSource { params["source"] = inlineSource }
        return params
    }

    /// Parse Core `result.data.content` while retaining request identity fields
    /// that the remote result intentionally does not echo.
    static func parseContentStage(
        _ data: [String: Any]?,
        sourceID: String?,
        context: CoreChapterContentRequestContext
    ) -> CoreChapterContentStageResult {
        let returnedSourceID = (data?["sourceId"] as? String) ?? sourceID
        let returnedBookID = (data?["bookId"] as? String) ?? context.bookID
        let title = (data?["chapterTitle"] as? String)
            ?? (data?["title"] as? String)
            ?? context.chapterTitle
        let rawContent = CoreReadingStageValue.jsonValue(data?["content"])
        let content = CoreReadingStageValue.rendererText(data?["content"])
        let nextChapterURL = data?["nextContentUrl"] as? String ?? data?["nextChapterUrl"] as? String
        var unknownFields: [String: JSONValue] = [
            "bookId": .string(returnedBookID),
            "chapterIndex": .number(Double(context.chapterIndex)),
        ]
        if let returnedSourceID, !returnedSourceID.isEmpty {
            unknownFields["sourceId"] = .string(returnedSourceID)
        }
        if !context.variables.isEmpty {
            unknownFields["variables"] = CoreReadingStageValue.jsonObject(context.variables)
        }
        let page = ContentPage(
            title: title,
            content: content,
            chapterURL: context.chapterURL,
            nextChapterURL: nextChapterURL,
            unknownFields: unknownFields
        )
        return CoreChapterContentStageResult(
            page: page,
            rawContent: rawContent,
            sourceID: returnedSourceID,
            bookID: returnedBookID,
            chapterTitle: title,
            chapterIndex: context.chapterIndex,
            chapterURL: context.chapterURL,
            variables: context.variables
        )
    }
}
