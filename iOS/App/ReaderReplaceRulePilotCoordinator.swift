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

/// Outcome of executing a single replace-rule Core effect.
public enum ReaderReplaceRuleEffectOutcome: Equatable, Sendable {
    case completed(coreType: String)
    case failed(coreType: String, message: String)
    case discarded
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
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeApply(payload: effect.jsonPayload, correlationID: correlationID) }
        case "replace.persist":
            return await executeCommand(
                coreType: "replace.persist",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executePersist(payload: effect.jsonPayload, correlationID: correlationID) }
        case "replace.validate":
            return await executeCommand(
                coreType: "replace.validate",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeValidate(payload: effect.jsonPayload, correlationID: correlationID) }
        default:
            return .failed(coreType: effect.type, message: "REPLACE_UNSUPPORTED_EFFECT")
        }
    }

    public func cancel(correlationID: String) {
        inFlightCancellers.removeValue(forKey: correlationID)?()
        activeCorrelations.remove(correlationID)
    }

    public func finish(correlationID: String) {
        inFlightCancellers[correlationID] = nil
        activeCorrelations.remove(correlationID)
    }

    /// Called by the coordinator before dispatching effects so the executor
    /// admits the correlation as active.
    public func begin(correlationID: String) {
        activeCorrelations.insert(correlationID)
    }

    private func executeCommand(
        coreType: String,
        correlationID: String,
        effect: ReaderUIEffect,
        operation: () async throws -> ReaderUIJSONResult
    ) async -> ReaderReplaceRuleEffectOutcome {
        do {
            let _ = try await operation()
            guard activeCorrelations.contains(correlationID) else {
                return .discarded
            }
            return .completed(coreType: coreType)
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
            case .failed(_, let message):
                lastFailure = message
                executor.cancel(correlationID: correlationID)
                if activeCorrelationID == correlationID {
                    activeCorrelationID = nil
                }
                return
            case .completed:
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
    }

    private func failClosedEffectBoundary(correlationID: String, message: String? = nil) {
        executor?.cancel(correlationID: correlationID)
        if activeCorrelationID == correlationID {
            activeCorrelationID = nil
        }
        lastFailure = message ?? "REPLACE_EFFECT_BOUNDARY_VIOLATION"
    }

    private static func nextCorrelation(prefix: String) -> String {
        "ios:\(prefix):\(UUID().uuidString)"
    }

}
