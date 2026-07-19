import CoreFoundation
import Foundation
import ReaderCoreNativeAdapter

/// Request-scoped Core adapter for the persistence half of a page transaction.
/// Core/reader-storage is the canonical owner; this service neither writes the
/// legacy iOS progress file nor projects the visible page.
public final class RustCoreReaderProgressService: @unchecked Sendable {
    private let runtime: any RustCoreCommandRuntime
    private let router: (any RustCoreHostRequestRouting)?
    private let requestTimeout: TimeInterval

    public init(
        runtime: any RustCoreCommandRuntime,
        router: (any RustCoreHostRequestRouting)? = nil,
        requestTimeout: TimeInterval = 15
    ) {
        self.runtime = runtime
        self.router = router
        self.requestTimeout = requestTimeout
    }

    public convenience init(
        runtime: ReaderCoreNativeRuntime,
        requestTimeout: TimeInterval = 15
    ) {
        self.init(
            runtime: runtime,
            router: RustCoreServiceSupport.makeRouter(runtime: runtime),
            requestTimeout: requestTimeout
        )
    }

    public func updateStage(
        _ request: CoreReaderProgressStageRequest,
        correlationID: String
    ) async throws -> CoreReaderProgressStageResult {
        do {
            return try await startUpdateStage(request, correlationID: correlationID).value()
        } catch {
            throw RustCoreServiceSupport.mapCoreError(error)
        }
    }

    public func startUpdateStage(
        _ request: CoreReaderProgressStageRequest,
        correlationID: String
    ) throws -> RustCoreRequestScopedCommand<CoreReaderProgressStageResult> {
        try Self.validate(request)
        guard !correlationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Self.invalidRequest("reading.progress.update requires a correlation id")
        }

        var params: [String: Any] = [
            "sourceId": request.sourceID,
            "bookId": request.bookID,
            "updatedAt": request.updatedAt,
            "chapterIndex": request.chapterIndex,
            "chapterOffset": request.chapterOffset,
            "chapterProgress": request.chapterProgress,
            "locationRevision": request.locationRevision,
        ]
        if let deviceID = request.deviceID {
            params["deviceId"] = deviceID
        }

        let handle = try RustCoreRequestScopedCommand<CoreReaderProgressStageResult>(
            runtime: runtime,
            router: router,
            requestID: RustCoreServiceSupport.allocateRequestID(),
            correlationID: correlationID,
            method: "reading.progress.update",
            params: params,
            timeout: requestTimeout,
            resultTransform: { data in
                let result = try Self.parseResult(data)
                guard Self.matches(result, request: request) else {
                    throw Self.invalidResult("result identity does not match the correlation-scoped request")
                }
                return result
            }
        )
        try handle.start()
        return handle
    }

    static func parseResult(_ data: [String: Any]?) throws -> CoreReaderProgressStageResult {
        guard let data else { throw invalidResult("result is required") }
        let allowedKeys: Set<String> = [
            "sourceId", "bookId", "deviceId", "updatedAt", "chapterIndex",
            "chapterOffset", "chapterProgress", "locationRevision", "stored",
        ]
        guard Set(data.keys).isSubset(of: allowedKeys) else {
            throw invalidResult("result contains unknown fields")
        }
        guard let sourceID = nonBlankString(data["sourceId"]),
              let bookID = nonBlankString(data["bookId"]),
              let updatedAt = unixSeconds(data["updatedAt"]),
              let chapterIndex = nonNegativeInteger(data["chapterIndex"]),
              let chapterOffset = nonNegativeInteger(data["chapterOffset"]),
              let chapterProgress = progress(data["chapterProgress"]),
              let locationRevision = nonBlankString(data["locationRevision"]),
              strictBool(data["stored"]) == true else {
            throw invalidResult("result is incomplete, invalid, or was not stored")
        }

        let deviceID: String?
        if data["deviceId"] == nil || data["deviceId"] is NSNull {
            deviceID = nil
        } else {
            guard let value = nonBlankString(data["deviceId"]) else {
                throw invalidResult("deviceId must be a non-empty string when present")
            }
            deviceID = value
        }

        return CoreReaderProgressStageResult(
            sourceID: sourceID,
            bookID: bookID,
            deviceID: deviceID,
            updatedAt: updatedAt,
            chapterIndex: chapterIndex,
            chapterOffset: chapterOffset,
            chapterProgress: chapterProgress,
            locationRevision: locationRevision,
            stored: true
        )
    }

    private static func validate(_ request: CoreReaderProgressStageRequest) throws {
        guard !request.sourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !request.bookID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              request.deviceID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != true,
              request.updatedAt > 0,
              request.updatedAt < 10_000_000_000,
              request.chapterIndex >= 0,
              request.chapterOffset >= 0,
              request.chapterProgress.isFinite,
              (0 ... 1).contains(request.chapterProgress),
              !request.locationRevision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw invalidRequest("correlation-scoped progress identity is incomplete or invalid")
        }
    }

    private static func matches(
        _ result: CoreReaderProgressStageResult,
        request: CoreReaderProgressStageRequest
    ) -> Bool {
        result.sourceID == request.sourceID
            && result.bookID == request.bookID
            && result.deviceID == request.deviceID
            && result.updatedAt == request.updatedAt
            && result.chapterIndex == request.chapterIndex
            && result.chapterOffset == request.chapterOffset
            && result.chapterProgress == request.chapterProgress
            && result.locationRevision == request.locationRevision
            && result.stored
    }

    private static func nonNegativeInteger(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        guard double.isFinite,
              double >= 0,
              double.rounded(.towardZero) == double,
              double <= Double(Int.max) else { return nil }
        return Int(double)
    }

    private static func unixSeconds(_ value: Any?) -> Int64? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        guard double.isFinite,
              double > 0,
              double.rounded(.towardZero) == double,
              double < 10_000_000_000 else { return nil }
        return Int64(double)
    }

    private static func progress(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        guard double.isFinite, (0 ... 1).contains(double) else { return nil }
        return double
    }

    private static func strictBool(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }

    private static func nonBlankString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func invalidRequest(_ message: String) -> ReaderCoreNativeError {
        .coreError(code: "INVALID_PARAMS", message: message)
    }

    private static func invalidResult(_ message: String) -> ReaderCoreNativeError {
        .coreError(code: "INVALID_PROGRESS_RESULT", message: "reading.progress.update \(message)")
    }
}
