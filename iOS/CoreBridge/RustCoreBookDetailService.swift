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
        try await fetchDetailStage(source: source, book: book).book
    }

    /// Fetch the complete typed detail-stage result used by `book.open`.
    ///
    /// The legacy `fetchDetail` API remains renderer-compatible, while this
    /// envelope also retains root `tocUrl` and Legado variables for the next
    /// Core stage.
    public func fetchDetailStage(
        source: BookSource,
        book: SearchResultItem
    ) async throws -> CoreBookDetailStageResult {
        do {
            return try await startDetailStage(source: source, book: book).value()
        } catch {
            throw RustCoreServiceSupport.mapCoreError(error)
        }
    }

    /// Starts `book.detail` and returns a request-scoped Core/Host handle.
    /// The caller owns the numeric Core id, awaits `value()`, or cancels it on
    /// a book-open correlation replacement. The legacy fetch API above simply
    /// awaits this same handle.
    public func startDetailStage(
        source: BookSource,
        book: SearchResultItem,
        correlationID: String? = nil
    ) throws -> RustCoreRequestScopedCommand<CoreBookDetailStageResult> {
        let sourceId = source.id?.isEmpty == false ? source.id! : UUID().uuidString
        let inlineSource = RustCoreServiceSupport.serializeSource(source, sourceID: sourceId)
        let params = Self.makeDetailParams(
            sourceID: sourceId,
            bookID: book.detailURL,
            bookURL: book.detailURL,
            title: book.title,
            author: book.author,
            coverURL: book.coverURL,
            intro: book.intro,
            inlineSource: inlineSource
        )
        let handle = try RustCoreRequestScopedCommand<CoreBookDetailStageResult>(
            runtime: runtime,
            router: router,
            requestID: RustCoreServiceSupport.allocateRequestID(),
            correlationID: correlationID,
            method: "book.detail",
            params: params,
            timeout: requestTimeout,
            resultTransform: { data in
                Self.parseBookDetailStage(data, fallback: book)
            }
        )
        try handle.start()
        return handle
    }

    /// Starts `book.detail` using only a persisted Core source id plus a base
    /// book identity. Core resolves the source from its own storage when the
    /// optional inline `source` object is absent. This is the appropriate path
    /// for a bookshelf entry: the UI must not manufacture a `BookSource` just
    /// to satisfy an older bridge overload.
    public func startDetailStage(
        sourceID: String,
        bookID: String,
        bookURL: String,
        title: String,
        author: String? = nil,
        coverURL: String? = nil,
        correlationID: String? = nil
    ) throws -> RustCoreRequestScopedCommand<CoreBookDetailStageResult> {
        let normalizedSourceID = try Self.requireIdentity(sourceID, field: "sourceId")
        let normalizedBookID = try Self.requireIdentity(bookID, field: "bookId")
        let normalizedBookURL = try Self.requireIdentity(bookURL, field: "bookUrl")
        let fallback = SearchResultItem(
            title: title,
            detailURL: normalizedBookURL,
            author: author,
            coverURL: coverURL
        )
        let params = Self.makeDetailParams(
            sourceID: normalizedSourceID,
            bookID: normalizedBookID,
            bookURL: normalizedBookURL,
            title: title,
            author: author,
            coverURL: coverURL,
            inlineSource: nil
        )
        let handle = try RustCoreRequestScopedCommand<CoreBookDetailStageResult>(
            runtime: runtime,
            router: router,
            requestID: RustCoreServiceSupport.allocateRequestID(),
            correlationID: correlationID,
            method: "book.detail",
            params: params,
            timeout: requestTimeout,
            resultTransform: { data in
                Self.parseBookDetailStage(data, fallback: fallback)
            }
        )
        try handle.start()
        return handle
    }

    /// Parse Core `result.data` without collapsing root transaction context.
    /// Internal visibility keeps this deterministic parser directly testable.
    static func parseBookDetailStage(
        _ data: [String: Any]?,
        fallback: SearchResultItem
    ) -> CoreBookDetailStageResult {
        let rawBook = data?["book"] as? [String: Any] ?? [:]
        let sourceID = data?["sourceId"] as? String
        // Core's stable identity is `book.bookId`. Keep it separately from
        // `SearchResultItem.detailURL`, which remains the renderer/navigation
        // URL captured before detail parsing.
        let bookID = (rawBook["bookId"] as? String)
            ?? (rawBook["id"] as? String)
            ?? fallback.detailURL
        let tocURL = (data?["tocUrl"] as? String) ?? (data?["tocURL"] as? String)
        let variables = CoreReadingStageValue.stringMap(data?["variables"])

        var unknownFields = fallback.unknownFields
        if !bookID.isEmpty {
            unknownFields["bookId"] = .string(bookID)
        }
        if let sourceID, !sourceID.isEmpty {
            unknownFields["sourceId"] = .string(sourceID)
        }
        if let tocURL, !tocURL.isEmpty {
            unknownFields["tocUrl"] = .string(tocURL)
        }
        if !variables.isEmpty {
            unknownFields["variables"] = CoreReadingStageValue.jsonObject(variables)
        }

        let enriched = SearchResultItem(
            title: (rawBook["title"] as? String) ?? fallback.title,
            detailURL: (rawBook["bookUrl"] as? String) ?? fallback.detailURL,
            author: (rawBook["author"] as? String) ?? fallback.author,
            coverURL: (rawBook["coverUrl"] as? String) ?? fallback.coverURL,
            intro: (rawBook["intro"] as? String) ?? fallback.intro,
            nextPageUrl: fallback.nextPageUrl,
            unknownFields: unknownFields
        )
        return CoreBookDetailStageResult(
            sourceID: sourceID,
            bookID: bookID,
            book: enriched,
            tocURL: tocURL,
            variables: variables
        )
    }

    /// Build the wire shape shared by inline-source and persisted-source
    /// detail reads. `bookUrl` belongs at the parameter root because Core uses
    /// it to create the Host HTTP request; the nested domain `Book` accepts
    /// `bookId`, not `bookUrl`.
    static func makeDetailParams(
        sourceID: String,
        bookID: String,
        bookURL: String,
        title: String,
        author: String? = nil,
        coverURL: String? = nil,
        intro: String? = nil,
        inlineSource: [String: Any]? = nil
    ) -> [String: Any] {
        var book: [String: Any] = [
            "bookId": bookID,
            "title": title,
            "author": author ?? "",
            "coverUrl": coverURL ?? "",
        ]
        if let intro { book["intro"] = intro }
        var params: [String: Any] = [
            "sourceId": sourceID,
            "book": book,
            "bookUrl": bookURL,
        ]
        if let inlineSource { params["source"] = inlineSource }
        return params
    }

    private static func requireIdentity(_ value: String, field: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw ReaderCoreNativeError.coreError(
                code: "INVALID_PARAMS",
                message: "book.detail requires non-empty \(field)"
            )
        }
        return normalized
    }
}
