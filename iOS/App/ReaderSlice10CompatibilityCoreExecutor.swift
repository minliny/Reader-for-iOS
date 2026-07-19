import Foundation
import ReaderCoreNativeAdapter
import ReaderShellValidation
import ReaderUIRuntime

private struct ReaderSlice10CompatibilityRawResult: @unchecked Sendable {
    let data: [String: Any]
}

public enum ReaderSlice10CompatibilityExecutorError: Error, Equatable, LocalizedError {
    case duplicateInFlight(String)

    public var errorDescription: String? {
        switch self {
        case .duplicateInFlight(let correlationID):
            return "[SLICE10_COMPAT_DUPLICATE_IN_FLIGHT] Core command is already running for \(correlationID)"
        }
    }
}

/// Concrete request-scoped adapter for Reader-UI's compatibility-only Slice
/// 10 commands. It deliberately does not change the consumer lock: production
/// `.live` remains Shadow, but an explicitly admitted Pilot now has a real Core
/// executor instead of a fake-only protocol seam.
///
/// Contract maturity boundary:
/// - replace.apply / replace.persist / replace.validate / replace.undo
/// - source.switch.commit / source.switch.rollback
/// live in `reader-contract/src/reader_ui.rs`, not the canonical command JSON
/// schema. They are executable compatibility contracts and must not be
/// reported as fully frozen V1 commands.
@MainActor
public final class ReaderSlice10CompatibilityCoreExecutor:
    ReaderReplaceRuleCoreCommandExecuting,
    ReaderSourceSwitchCoreCommandExecuting
{
    private let runtime: any RustCoreCommandRuntime
    private let router: (any RustCoreHostRequestRouting)?
    private let requestTimeout: TimeInterval
    private var inFlight: [String: RustCoreRequestScopedCommand<ReaderSlice10CompatibilityRawResult>] = [:]

    public init(
        runtime: any RustCoreCommandRuntime,
        router: (any RustCoreHostRequestRouting)? = nil,
        requestTimeout: TimeInterval = 15
    ) {
        self.runtime = runtime
        self.router = router
        self.requestTimeout = requestTimeout
    }

    public convenience init(runtime: ReaderCoreNativeRuntime, requestTimeout: TimeInterval = 15) {
        self.init(
            runtime: runtime,
            router: RustCoreServiceSupport.makeRouter(runtime: runtime),
            requestTimeout: requestTimeout
        )
    }

    public func executeApply(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await execute(method: "replace.apply", payload: payload, correlationID: correlationID)
    }

    public func executePersist(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await execute(method: "replace.persist", payload: payload, correlationID: correlationID)
    }

    public func executeValidate(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await execute(method: "replace.validate", payload: payload, correlationID: correlationID)
    }

    public func executeUndo(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await execute(method: "replace.undo", payload: payload, correlationID: correlationID)
    }

    public func executeCommit(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await execute(method: "source.switch.commit", payload: payload, correlationID: correlationID)
    }

    public func executeRollback(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await execute(method: "source.switch.rollback", payload: payload, correlationID: correlationID)
    }

    public func cancel(correlationID: String) {
        inFlight.removeValue(forKey: correlationID)?.cancel()
    }

    public func finish(correlationID: String) {
        inFlight[correlationID] = nil
    }

    private func execute(
        method: String,
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        guard inFlight[correlationID] == nil else {
            throw ReaderSlice10CompatibilityExecutorError.duplicateInFlight(correlationID)
        }
        let command = try RustCoreRequestScopedCommand<ReaderSlice10CompatibilityRawResult>(
            runtime: runtime,
            router: router,
            requestID: RustCoreServiceSupport.allocateRequestID(),
            correlationID: correlationID,
            method: method,
            params: ReaderUIJSONBridge.foundationObject(from: payload),
            timeout: requestTimeout
        ) { data in
            ReaderSlice10CompatibilityRawResult(data: data ?? [:])
        }
        inFlight[correlationID] = command
        do {
            try command.start()
            let result = try await command.value()
            guard inFlight[correlationID] === command else { throw CancellationError() }
            inFlight[correlationID] = nil
            return try ReaderUIJSONBridge.result(from: result.data)
        } catch {
            if inFlight[correlationID] === command {
                inFlight[correlationID] = nil
            }
            throw error
        }
    }
}
