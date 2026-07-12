import Foundation
import CoreFoundation
import ReaderCoreNativeAdapter

/// Request-scoped Core adapter for the final, layout-dependent stage of a
/// book-open transaction. It has no Host request path, but uses the same
/// numeric Core id and cancellation semantics as the detail/TOC/content
/// stages so replacement cannot let an old layout resolve into a new reader.
public final class RustCoreReaderLocationService: @unchecked Sendable {
    private let runtime: ReaderCoreNativeRuntime
    private let requestTimeout: TimeInterval

    public init(
        runtime: ReaderCoreNativeRuntime,
        requestTimeout: TimeInterval = 15
    ) {
        self.runtime = runtime
        self.requestTimeout = requestTimeout
    }

    public func resolveStage(
        _ request: CoreReaderLocationStageRequest,
        correlationID: String? = nil
    ) async throws -> CoreReaderLocationStageResult {
        do {
            return try await startResolveStage(request, correlationID: correlationID).value()
        } catch {
            throw RustCoreServiceSupport.mapCoreError(error)
        }
    }

    public func startResolveStage(
        _ request: CoreReaderLocationStageRequest,
        correlationID: String? = nil
    ) throws -> RustCoreRequestScopedCommand<CoreReaderLocationStageResult> {
        guard !request.bookID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReaderCoreNativeError.coreError(
                code: "INVALID_PARAMS",
                message: "reader.location.resolve requires a non-empty bookId"
            )
        }
        var params: [String: Any] = [
            "bookId": request.bookID,
            "chapterIndex": request.chapterIndex,
            "anchor": [
                "chapterOffset": request.chapterOffset,
                "chapterProgress": request.chapterProgress,
            ],
            "layout": Self.layoutParams(request.layout),
        ]
        if let sourceID = request.sourceID {
            params["sourceId"] = sourceID
        }
        if let chapterTitle = request.chapterTitle {
            params["chapterTitle"] = chapterTitle
        }

        let handle = try RustCoreRequestScopedCommand<CoreReaderLocationStageResult>(
            runtime: runtime,
            requestID: RustCoreServiceSupport.allocateRequestID(),
            correlationID: correlationID,
            method: "reader.location.resolve",
            params: params,
            timeout: requestTimeout,
            resultTransform: Self.parseResult
        )
        try handle.start()
        return handle
    }

    static func layoutParams(_ layout: CoreReaderLocationLayout) -> [String: Any] {
        var result: [String: Any] = [
            "viewportWidth": layout.viewportWidth,
            "viewportHeight": layout.viewportHeight,
            "fontScale": layout.fontScale,
        ]
        if let lineHeight = layout.lineHeight { result["lineHeight"] = lineHeight }
        if let pageIndex = layout.pageIndex { result["pageIndex"] = pageIndex }
        if let pageCount = layout.pageCount { result["pageCount"] = pageCount }
        return result
    }

    static func parseResult(_ data: [String: Any]?) throws -> CoreReaderLocationStageResult {
        guard strictBool(data?["resolved"]) == true else {
            throw invalidLocationResult("resolved must be explicit true")
        }
        guard let canonical = data?["canonicalLocation"] as? [String: Any] else {
            throw invalidLocationResult("canonicalLocation is required")
        }
        guard let bookID = nonBlankString(canonical["bookId"]),
              let chapterIndex = nonNegativeInteger(canonical["chapterIndex"]),
              let chapterOffset = nonNegativeInteger(canonical["chapterOffset"]),
              let chapterProgress = progress(canonical["chapterProgress"]),
              let locationRevision = nonBlankString(canonical["locationRevision"]),
              let resolverVersion = nonBlankString(data?["resolverVersion"]) else {
            throw invalidLocationResult("canonicalLocation is incomplete or invalid")
        }
        guard let reflow = data?["reflow"] as? [String: Any],
              let primaryAnchor = nonBlankString(reflow["primaryAnchor"]),
              let fallbackAnchor = nonBlankString(reflow["fallbackAnchor"]),
              let layoutIndependent = strictBool(reflow["layoutIndependent"]) else {
            throw invalidLocationResult("reflow is incomplete or invalid")
        }
        return CoreReaderLocationStageResult(
            bookID: bookID,
            chapterIndex: chapterIndex,
            chapterOffset: chapterOffset,
            chapterProgress: chapterProgress,
            locationRevision: locationRevision,
            resolverVersion: resolverVersion,
            primaryAnchor: primaryAnchor,
            fallbackAnchor: fallbackAnchor,
            layoutIndependent: layoutIndependent
        )
    }

    /// Core location payloads are a trust boundary. Do not use Swift's broad
    /// `as? Int` / `as? Bool` bridging here: it can coerce JSON numbers into
    /// Bool or truncate a fractional number. A malformed result must fail the
    /// transaction instead of acquiring a synthetic zero anchor.
    private static func nonNegativeInteger(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
            let double = number.doubleValue
            guard double.isFinite,
                  double >= 0,
                  double.rounded(.towardZero) == double,
                  double <= Double(Int.max) else {
                return nil
            }
            return Int(double)
        }
        return nil
    }

    private static func progress(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else {
            return nil
        }
        let double = number.doubleValue
        guard double.isFinite, (0 ... 1).contains(double) else { return nil }
        return double
    }

    private static func strictBool(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else {
            return nil
        }
        return number.boolValue
    }

    private static func nonBlankString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func invalidLocationResult(_ message: String) -> ReaderCoreNativeError {
        .coreError(
            code: "INVALID_LOCATION_RESULT",
            message: "reader.location.resolve \(message)"
        )
    }
}
