import Combine
import Foundation
import ReaderUIContract
import ReaderUIRuntime

/// This switch is intentionally independent from `READER_UI_CONSUMER.json`.
/// The consumer lock remains the authority for production runtime rollout;
/// the replace-rules trio is currently Shadow in production. Explicit
/// `.pilot` construction is retained only for the experimental transaction
/// seam.
public enum ReaderReplaceRulePilotMode: String, Equatable, Sendable {
    case shadow
    case pilot
}

public struct ReaderReplaceRulePilotConfiguration: Equatable, Sendable {
    public let mode: ReaderReplaceRulePilotMode

    public init(mode: ReaderReplaceRulePilotMode = .shadow) {
        self.mode = mode
    }

    public static let live = ReaderReplaceRulePilotConfiguration(mode: .shadow)
}

public enum ReaderReplaceRuleOperationState: Equatable, Sendable {
    case idle
    case loading(coreType: String)
    case succeeded(coreType: String, message: String)
    case failed(coreType: String?, message: String)
}

/// Outcome of executing a single replace-rule Core effect.
public enum ReaderReplaceRuleEffectOutcome: Equatable, Sendable {
    case completed(coreType: String, result: ReaderUIJSONResult = [:])
    case failed(coreType: String, message: String)
    case discarded
}

private enum ReaderReplaceRuleResultIdentityValidator {
    static func validate(
        coreType: String,
        request: ReaderUIJSONPayload,
        result: ReaderUIJSONResult
    ) throws {
        switch coreType {
        case "replace.persist":
            try validatePersist(request: request, result: result)
        case "replace.undo":
            try validateUndo(request: request, result: result)
        default:
            break
        }
    }

    private static func validatePersist(
        request: ReaderUIJSONPayload,
        result: ReaderUIJSONResult
    ) throws {
        let data = try requireObject(result["data"], path: "result.data")
        let rule = try requireObject(data["rule"], path: "result.data.rule")
        let token = try requireObject(result["undoToken"], path: "result.undoToken")
        try validateToken(token)

        guard result["operation"] == .string("create"),
              token["operation"] == result["operation"],
              token["ruleId"] == rule["id"],
              token["before"] == nil,
              token["after"] == .object(rule) else {
            throw mismatch("replace.persist undoToken does not identify the created Core rule")
        }
        if let requestedTransactionID = request["transactionId"],
           token["transactionId"] != requestedTransactionID {
            throw mismatch("replace.persist undoToken transactionId does not match the request")
        }
    }

    private static func validateUndo(
        request: ReaderUIJSONPayload,
        result: ReaderUIJSONResult
    ) throws {
        let token = try requireObject(request["undoToken"], path: "request.undoToken")
        try validateToken(token)

        for key in ["transactionId", "revision", "operation", "ruleId"] {
            guard result[key] == token[key] else {
                throw mismatch("replace.undo result \(key) does not match the replayed Core token")
            }
        }
        guard result["changed"] == .bool(true) else {
            throw mismatch("replace.undo succeeded without consuming the replayed Core token")
        }

        switch token["operation"] {
        case .string("create"):
            guard result["restoredRule"] == nil else {
                throw mismatch("create undo must not restore a previous rule")
            }
        case .string("update"), .string("delete"):
            guard result["restoredRule"] == token["before"] else {
                throw mismatch("replace.undo restoredRule does not match undoToken.before")
            }
        default:
            throw mismatch("replace.undo token operation is unsupported")
        }
    }

    private static func validateToken(_ token: ReaderUIJSONPayload) throws {
        guard let issuedAt = token["issuedAt"]?.intValue,
              let expiresAt = token["expiresAt"]?.intValue,
              expiresAt > issuedAt else {
            throw mismatch("undoToken expiry window is invalid")
        }

        let before = try optionalObject(token["before"], path: "undoToken.before")
        let after = try optionalObject(token["after"], path: "undoToken.after")
        let ruleID = token["ruleId"]
        guard before?["id"] == ruleID || before == nil,
              after?["id"] == ruleID || after == nil else {
            throw mismatch("undoToken before/after rule identity does not match ruleId")
        }

        switch token["operation"] {
        case .string("create") where before == nil && after != nil:
            break
        case .string("update") where before != nil && after != nil && before != after:
            break
        case .string("delete") where before != nil && after == nil:
            break
        default:
            throw mismatch("undoToken before/after states do not match its operation")
        }
    }

    private static func requireObject(
        _ value: ReaderUIJSONValue?,
        path: String
    ) throws -> ReaderUIJSONPayload {
        guard case .object(let object)? = value else {
            throw mismatch("\(path) must be an object")
        }
        return object
    }

    private static func optionalObject(
        _ value: ReaderUIJSONValue?,
        path: String
    ) throws -> ReaderUIJSONPayload? {
        guard let value else { return nil }
        guard case .object(let object) = value else {
            throw mismatch("\(path) must be an object when present")
        }
        return object
    }

    private static func mismatch(_ message: String) -> ReaderUIRuntimeFailure {
        ReaderUIRuntimeFailure(
            code: "REPLACE_RESULT_IDENTITY_MISMATCH",
            message: "[REPLACE_RESULT_IDENTITY_MISMATCH] \(message)"
        )
    }
}

/// Narrow seam for focused Pilot tests. The concrete executor below owns the
/// Core command handles; tests can inject a deterministic fake without booting
/// Core or starting a real replace-rule request.
@MainActor
public protocol ReaderReplaceRuleEffectExecuting: AnyObject {
    func begin(correlationID: String)
    func execute(_ effect: ReaderUIEffect) async -> ReaderReplaceRuleEffectOutcome
    func cancel(correlationID: String)
    func finish(correlationID: String)
}

/// Protocol seam for the three Core replace-rule commands. Production wires
/// this to a Rust Core adapter; tests inject a deterministic fake.
@MainActor
public protocol ReaderReplaceRuleCoreCommandExecuting: AnyObject {
    func executeApply(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
    func executePersist(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
    func executeValidate(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
    func executeUndo(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
    func cancel(correlationID: String)
    func finish(correlationID: String)
}

public extension ReaderReplaceRuleCoreCommandExecuting {
    func executeUndo(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult {
        throw ReaderUIRuntimeFailure(code: "REPLACE_UNDO_EXECUTOR_MISSING", message: "replace.undo executor is unavailable")
    }
    func cancel(correlationID: String) {}
    func finish(correlationID: String) {}
}

/// Concrete executor that maps each typed replace-rule effect to the
/// corresponding Core command via the injected
/// `ReaderReplaceRuleCoreCommandExecuting` seam.
@MainActor
public final class ReaderReplaceRuleEffectExecutor: ReaderReplaceRuleEffectExecuting {
    private let coreCommands: any ReaderReplaceRuleCoreCommandExecuting
    private var activeCorrelations: Set<String> = []
    private var inFlightCancellers: [String: () -> Void] = [:]

    public init(coreCommands: any ReaderReplaceRuleCoreCommandExecuting) {
        self.coreCommands = coreCommands
    }

    public func execute(_ effect: ReaderUIEffect) async -> ReaderReplaceRuleEffectOutcome {
        guard effect.kind == .core,
              let correlationID = effect.correlationId,
              activeCorrelations.contains(correlationID) else {
            return .discarded
        }

        switch effect.type {
        case "replace.apply":
            return await executeCommand(
                coreType: "replace.apply",
                contractEvent: "reader.replace.apply",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeApply(payload: effect.jsonPayload, correlationID: correlationID) }
        case "replace.persist":
            return await executeCommand(
                coreType: "replace.persist",
                contractEvent: "reader.replace.create",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executePersist(payload: effect.jsonPayload, correlationID: correlationID) }
        case "replace.validate":
            return await executeCommand(
                coreType: "replace.validate",
                contractEvent: "reader.replace.validate",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeValidate(payload: effect.jsonPayload, correlationID: correlationID) }
        case "replace.undo":
            return await executeCommand(
                coreType: "replace.undo",
                contractEvent: "reader.replace.undo",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeUndo(payload: effect.jsonPayload, correlationID: correlationID) }
        default:
            return .failed(coreType: effect.type, message: "REPLACE_UNSUPPORTED_EFFECT")
        }
    }

    public func cancel(correlationID: String) {
        inFlightCancellers.removeValue(forKey: correlationID)?()
        coreCommands.cancel(correlationID: correlationID)
        activeCorrelations.remove(correlationID)
    }

    public func finish(correlationID: String) {
        inFlightCancellers[correlationID] = nil
        coreCommands.finish(correlationID: correlationID)
        activeCorrelations.remove(correlationID)
    }

    /// Called by the coordinator before dispatching effects so the executor
    /// admits the correlation as active.
    public func begin(correlationID: String) {
        activeCorrelations.insert(correlationID)
    }

    private func executeCommand(
        coreType: String,
        contractEvent: String,
        correlationID: String,
        effect: ReaderUIEffect,
        operation: () async throws -> ReaderUIJSONResult
    ) async -> ReaderReplaceRuleEffectOutcome {
        do {
            let result = try await operation()
            _ = try validateReaderUITypedResult(
                event: contractEvent,
                effectType: coreType,
                result: result
            )
            try ReaderReplaceRuleResultIdentityValidator.validate(
                coreType: coreType,
                request: effect.jsonPayload,
                result: result
            )
            guard activeCorrelations.contains(correlationID) else {
                return .discarded
            }
            return .completed(coreType: coreType, result: result)
        } catch is CancellationError {
            return .discarded
        } catch {
            return activeCorrelations.contains(correlationID)
                ? .failed(coreType: coreType, message: error.localizedDescription)
                : .discarded
        }
    }
}

/// Executes Reader-UI's replace-rule event sequence only when an explicitly
/// injected pilot configuration opts in. `live` remains Shadow, so merely
/// constructing this coordinator does not grant production runtime authority.
///
/// Each replace-rule event (`reader.replace.apply`, `reader.replace.create`,
/// `reader.replace.validate`) is an independent `emitEffects` action that
/// produces exactly one Core effect (`replace.apply`, `replace.persist`,
/// `replace.validate` respectively). The coordinator tracks the active
/// correlation to enforce stale result guards and fail-closed semantics.
@MainActor
public final class ReaderReplaceRulePilotCoordinator: ObservableObject {
    public let configuration: ReaderReplaceRulePilotConfiguration
    private let runtime: ReaderUIRuntime
    private let executor: (any ReaderReplaceRuleEffectExecuting)?

    @Published public private(set) var activeCorrelationID: String?
    @Published public private(set) var lastFailure: String?
    @Published public private(set) var lastUndoToken: ReaderUIJSONPayload?
    @Published public private(set) var operationState: ReaderReplaceRuleOperationState = .idle

    public init(
        configuration: ReaderReplaceRulePilotConfiguration = .live,
        runtime: ReaderUIRuntime = ReaderUIRuntime(),
        executor: (any ReaderReplaceRuleEffectExecuting)? = nil
    ) {
        self.configuration = configuration
        self.runtime = runtime
        self.executor = executor
    }

    /// Dispatch `reader.replace.apply` through the runtime transaction,
    /// emitting the `replace.apply` Core effect. Returns true when the Pilot
    /// consumed the event (even on failure).
    @discardableResult
    public func applyRules(payload: [String: String], correlationId: String?) -> Bool {
        applyRules(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func applyRules(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> Bool {
        guard configuration.mode == .pilot else { return false }
        guard let executor else {
            failClosed("REPLACE_EXECUTOR_MISSING")
            return true
        }
        let correlationID = correlationId ?? Self.nextCorrelation(prefix: "replace-apply")
        if let activeCorrelationID, activeCorrelationID != correlationID {
            executor.cancel(correlationID: activeCorrelationID)
        }
        executor.begin(correlationID: correlationID)
        do {
            let transition = try runtime.dispatch(
                event: "reader.replace.apply",
                jsonPayload: payload,
                correlationId: correlationID
            )
            // Boundary: reader.replace.apply must emit exactly one Core effect.
            guard transition.effects.count == 1,
                  transition.effects.allSatisfy({ $0.kind == .core }) else {
                failClosedEffectBoundary(correlationID: correlationID)
                return true
            }
            activeCorrelationID = correlationID
            lastFailure = nil
            operationState = .loading(coreType: "replace.apply")
            Task { [weak self] in
                await self?.execute(transition.effects, correlationID: correlationID)
            }
            return true
        } catch {
            failClosedEffectBoundary(correlationID: correlationID, message: error.localizedDescription)
            return true
        }
    }

    /// Dispatch `reader.replace.create` through the runtime transaction,
    /// emitting the `replace.persist` Core effect.
    @discardableResult
    public func createRule(payload: [String: String], correlationId: String?) -> Bool {
        createRule(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func createRule(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> Bool {
        guard configuration.mode == .pilot else { return false }
        guard let executor else {
            failClosed("REPLACE_EXECUTOR_MISSING")
            return true
        }
        let correlationID = correlationId ?? Self.nextCorrelation(prefix: "replace-create")
        executor.begin(correlationID: correlationID)
        do {
            let transition = try runtime.dispatch(
                event: "reader.replace.create",
                jsonPayload: payload,
                correlationId: correlationID
            )
            guard transition.effects.count == 1,
                  transition.effects.allSatisfy({ $0.kind == .core }) else {
                failClosedEffectBoundary(correlationID: correlationID)
                return true
            }
            if activeCorrelationID != correlationID {
                if let previous = activeCorrelationID {
                    executor.cancel(correlationID: previous)
                }
                activeCorrelationID = correlationID
            }
            lastFailure = nil
            operationState = .loading(coreType: "replace.persist")
            Task { [weak self] in
                await self?.execute(transition.effects, correlationID: correlationID)
            }
            return true
        } catch {
            failClosedEffectBoundary(correlationID: correlationID, message: error.localizedDescription)
            return true
        }
    }

    /// Dispatch `reader.replace.validate` through the runtime transaction,
    /// emitting the `replace.validate` Core effect.
    @discardableResult
    public func validateRule(payload: [String: String], correlationId: String?) -> Bool {
        validateRule(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func validateRule(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> Bool {
        guard configuration.mode == .pilot else { return false }
        guard let executor else {
            failClosed("REPLACE_EXECUTOR_MISSING")
            return true
        }
        let correlationID = correlationId ?? Self.nextCorrelation(prefix: "replace-validate")
        executor.begin(correlationID: correlationID)
        do {
            let transition = try runtime.dispatch(
                event: "reader.replace.validate",
                jsonPayload: payload,
                correlationId: correlationID
            )
            guard transition.effects.count == 1,
                  transition.effects.allSatisfy({ $0.kind == .core }) else {
                failClosedEffectBoundary(correlationID: correlationID)
                return true
            }
            if activeCorrelationID != correlationID {
                if let previous = activeCorrelationID {
                    executor.cancel(correlationID: previous)
                }
                activeCorrelationID = correlationID
            }
            lastFailure = nil
            operationState = .loading(coreType: "replace.validate")
            Task { [weak self] in
                await self?.execute(transition.effects, correlationID: correlationID)
            }
            return true
        } catch {
            failClosedEffectBoundary(correlationID: correlationID, message: error.localizedDescription)
            return true
        }
    }

    /// Replay the exact token emitted by the most recent successful
    /// `replace.persist`. The Host never creates, edits, or substitutes token
    /// fields; the generated Reader-UI payload validator checks it again
    /// before the Core effect is admitted.
    @discardableResult
    public func undoLastPersistedRule(correlationId: String? = nil) -> Bool {
        guard configuration.mode == .pilot else { return false }
        guard let executor else {
            failClosed("REPLACE_EXECUTOR_MISSING")
            return true
        }
        guard let lastUndoToken else {
            operationState = .failed(coreType: "replace.undo", message: "REPLACE_UNDO_TOKEN_MISSING")
            lastFailure = "REPLACE_UNDO_TOKEN_MISSING"
            return true
        }
        let correlationID = correlationId ?? Self.nextCorrelation(prefix: "replace-undo")
        if let previous = activeCorrelationID, previous != correlationID {
            executor.cancel(correlationID: previous)
        }
        executor.begin(correlationID: correlationID)
        do {
            let transition = try runtime.dispatch(
                event: "reader.replace.undo",
                jsonPayload: ["undoToken": .object(lastUndoToken)],
                correlationId: correlationID
            )
            guard transition.effects.count == 1,
                  transition.effects.first?.kind == .core,
                  transition.effects.first?.type == "replace.undo" else {
                failClosedEffectBoundary(correlationID: correlationID)
                return true
            }
            activeCorrelationID = correlationID
            lastFailure = nil
            operationState = .loading(coreType: "replace.undo")
            Task { [weak self] in
                await self?.execute(transition.effects, correlationID: correlationID)
            }
            return true
        } catch {
            failClosedEffectBoundary(correlationID: correlationID, message: error.localizedDescription)
            return true
        }
    }

    /// ReaderReducer calls this before its legacy switch. Pilot means the
    /// canonical event is consumed even on failure; Shadow means native code
    /// remains authoritative and this method returns false.
    @discardableResult
    public func handle(_ event: UiEvent) -> Bool {
        guard configuration.mode == .pilot else { return false }
        do {
            let payload = try ReaderUIJSONBridge.payload(from: event.payload)
            switch event.type {
            case .reader_replace_apply:
                return applyRules(jsonPayload: payload, correlationId: event.correlationId)
            case .reader_replace_create:
                return createRule(jsonPayload: payload, correlationId: event.correlationId)
            case .reader_replace_validate:
                return validateRule(jsonPayload: payload, correlationId: event.correlationId)
            case .reader_replace_undo:
                // The event payload may come from a contract-rendered result
                // screen. Admit it only when it exactly matches the retained
                // Core-issued token, so a fixture token cannot replace live
                // transaction state.
                guard case .object(let token)? = payload["undoToken"],
                      token == lastUndoToken else {
                    failClosed("REPLACE_UNDO_TOKEN_MISMATCH")
                    return true
                }
                return undoLastPersistedRule(correlationId: event.correlationId)
            default:
                return false
            }
        } catch {
            failClosed(error.localizedDescription)
            return true
        }
    }

    private func execute(_ effects: [ReaderUIEffect], correlationID: String) async {
        guard let executor else { return }
        for effect in effects {
            let outcome = await executor.execute(effect)
            switch outcome {
            case .discarded:
                // Stale-result guard: a late result for an already-cancelled
                // correlation is silently discarded.
                continue
            case .failed(let coreType, let message):
                lastFailure = message
                operationState = .failed(coreType: coreType, message: message)
                executor.cancel(correlationID: correlationID)
                if activeCorrelationID == correlationID {
                    activeCorrelationID = nil
                }
                return
            case .completed(let coreType, let result):
                if coreType == "replace.persist" {
                    guard case .object(let undoToken)? = result["undoToken"] else {
                        lastFailure = "REPLACE_PERSIST_UNDO_TOKEN_MISSING"
                        operationState = .failed(
                            coreType: coreType,
                            message: "REPLACE_PERSIST_UNDO_TOKEN_MISSING"
                        )
                        executor.cancel(correlationID: correlationID)
                        if activeCorrelationID == correlationID { activeCorrelationID = nil }
                        return
                    }
                    lastUndoToken = undoToken
                } else if coreType == "replace.undo" {
                    lastUndoToken = nil
                }
                operationState = .succeeded(coreType: coreType, message: successMessage(for: coreType))
                executor.finish(correlationID: correlationID)
                if activeCorrelationID == correlationID {
                    activeCorrelationID = nil
                }
                return
            }
        }
    }

    private func failClosed(_ message: String) {
        lastFailure = message
        operationState = .failed(coreType: nil, message: message)
    }

    private func failClosedEffectBoundary(correlationID: String, message: String? = nil) {
        executor?.cancel(correlationID: correlationID)
        if activeCorrelationID == correlationID {
            activeCorrelationID = nil
        }
        lastFailure = message ?? "REPLACE_EFFECT_BOUNDARY_VIOLATION"
        operationState = .failed(
            coreType: nil,
            message: message ?? "REPLACE_EFFECT_BOUNDARY_VIOLATION"
        )
    }

    private func successMessage(for coreType: String) -> String {
        switch coreType {
        case "replace.persist": return "替换规则已保存，可撤销"
        case "replace.undo": return "已撤销上一次规则变更"
        case "replace.apply": return "替换已应用"
        case "replace.validate": return "规则校验完成"
        default: return "操作完成"
        }
    }

    private static func nextCorrelation(prefix: String) -> String {
        "ios:\(prefix):\(UUID().uuidString)"
    }

}
