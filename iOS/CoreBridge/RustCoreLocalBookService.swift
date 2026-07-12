import Foundation
import ReaderCoreFoundation
import ReaderCoreModels
import ReaderCoreNativeAdapter

/// Typed, request-scoped reads for a Core-materialized local book.
///
/// `local_book.toc` and `local_book.chapter.content` are intentionally
/// separate from the remote source services: they do not use Host HTTP and
/// only succeed after `local_book.import` has materialized the book in Core
/// storage. Making those constraints explicit keeps a future book.open Pilot
/// from accidentally treating a legacy `local-book://` renderer URL as a
/// remote source request.
public final class RustCoreLocalBookService: @unchecked Sendable {
    private let runtime: ReaderCoreNativeRuntime
    private let requestTimeout: TimeInterval

    public init(
        runtime: ReaderCoreNativeRuntime,
        requestTimeout: TimeInterval = 15
    ) {
        self.runtime = runtime
        self.requestTimeout = requestTimeout
    }

    public func fetchTOCStage(
        bookID: String,
        correlationID: String? = nil
    ) async throws -> CoreTOCStageResult {
        do {
            return try await startTOCStage(
                bookID: bookID,
                correlationID: correlationID
            ).value()
        } catch {
            throw RustCoreServiceSupport.mapCoreError(error)
        }
    }

    /// Starts storage-backed `local_book.toc`. The returned handle still has a
    /// numeric Core request id and supports correlation cancellation even
    /// though this command has no URLSession work to cancel.
    public func startTOCStage(
        bookID: String,
        correlationID: String? = nil
    ) throws -> RustCoreRequestScopedCommand<CoreTOCStageResult> {
        let normalizedBookID = try Self.requireBookID(bookID)
        let handle = try RustCoreRequestScopedCommand<CoreTOCStageResult>(
            runtime: runtime,
            requestID: RustCoreServiceSupport.allocateRequestID(),
            correlationID: correlationID,
            method: "local_book.toc",
            params: ["bookId": normalizedBookID],
            timeout: requestTimeout,
            resultTransform: Self.parseTOCStage
        )
        try handle.start()
        return handle
    }

    public func fetchContentStage(
        bookID: String,
        chapterIndex: Int,
        chapterURL: String? = nil,
        correlationID: String? = nil
    ) async throws -> CoreChapterContentStageResult {
        do {
            return try await startContentStage(
                bookID: bookID,
                chapterIndex: chapterIndex,
                chapterURL: chapterURL,
                correlationID: correlationID
            ).value()
        } catch {
            throw RustCoreServiceSupport.mapCoreError(error)
        }
    }

    /// Starts storage-backed `local_book.chapter.content`. `chapterURL` is
    /// retained only for the renderer-facing typed result; Core deliberately
    /// accepts the materialized book id plus zero-based index.
    public func startContentStage(
        bookID: String,
        chapterIndex: Int,
        chapterURL: String? = nil,
        correlationID: String? = nil
    ) throws -> RustCoreRequestScopedCommand<CoreChapterContentStageResult> {
        let normalizedBookID = try Self.requireBookID(bookID)
        let index = max(0, chapterIndex)
        let renderedURL = chapterURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? chapterURL!
            : "local://\(normalizedBookID)/chapter/\(index)"
        let context = CoreChapterContentRequestContext(
            bookID: normalizedBookID,
            chapterTitle: "",
            chapterIndex: index,
            chapterURL: renderedURL
        )
        let handle = try RustCoreRequestScopedCommand<CoreChapterContentStageResult>(
            runtime: runtime,
            requestID: RustCoreServiceSupport.allocateRequestID(),
            correlationID: correlationID,
            method: "local_book.chapter.content",
            params: [
                "bookId": normalizedBookID,
                "chapterIndex": index,
            ],
            timeout: requestTimeout,
            resultTransform: { data in
                Self.parseContentStage(data, context: context)
            }
        )
        try handle.start()
        return handle
    }

    static func parseTOCStage(_ data: [String: Any]?) -> CoreTOCStageResult {
        let bookID = data?["bookId"] as? String
        let entries = (data?["toc"] as? [[String: Any]] ?? []).enumerated().compactMap { index, raw -> CoreTOCStageEntry? in
            guard let title = raw["title"] as? String ?? raw["chapterName"] as? String else {
                return nil
            }
            let chapterIndex = CoreReadingStageValue.integer(raw["index"], fallback: index)
            let url = (raw["url"] as? String)
                ?? (raw["chapterUrl"] as? String)
                ?? (bookID.map { "local://\($0)/chapter/\(chapterIndex)" } ?? "")
            let item = TOCItem(
                chapterTitle: title,
                chapterURL: url,
                chapterIndex: max(0, chapterIndex),
                isVip: false
            )
            return CoreTOCStageEntry(item: item, variables: [:])
        }
        return CoreTOCStageResult(
            sourceID: (data?["sourceId"] as? String) ?? "local",
            bookID: bookID,
            entries: entries
        )
    }

    static func parseContentStage(
        _ data: [String: Any]?,
        context: CoreChapterContentRequestContext
    ) -> CoreChapterContentStageResult {
        let returnedBookID = (data?["bookId"] as? String) ?? context.bookID
        let returnedIndex = CoreReadingStageValue.integer(data?["chapterIndex"], fallback: context.chapterIndex)
        let title = (data?["chapterTitle"] as? String) ?? context.chapterTitle
        let content = (data?["content"] as? String) ?? ""
        let sourceID = (data?["sourceId"] as? String) ?? "local"
        let page = ContentPage(
            title: title,
            content: content,
            chapterURL: context.chapterURL,
            nextChapterURL: nil,
            unknownFields: [
                "bookId": .string(returnedBookID),
                "chapterIndex": .number(Double(max(0, returnedIndex))),
                "sourceId": .string(sourceID),
            ]
        )
        return CoreChapterContentStageResult(
            page: page,
            rawContent: .string(content),
            sourceID: sourceID,
            bookID: returnedBookID,
            chapterTitle: title,
            chapterIndex: max(0, returnedIndex),
            chapterURL: context.chapterURL,
            variables: [:]
        )
    }

    private static func requireBookID(_ bookID: String) throws -> String {
        let normalized = bookID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw ReaderCoreNativeError.coreError(
                code: "INVALID_PARAMS",
                message: "local book command requires a non-empty bookId"
            )
        }
        return normalized
    }
}
