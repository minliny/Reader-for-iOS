import Combine
import Foundation
import ReaderUIContract
import ReaderUIRuntime

/// This switch is intentionally independent from `READER_UI_CONSUMER.json`.
/// The consumer lock remains the authority for production runtime rollout;
/// the source-switch events are currently Shadow in production. Explicit
/// `.pilot` construction is retained only for the experimental transaction
/// seam.
public enum ReaderSourceSwitchPilotMode: String, Equatable, Sendable {
    case shadow
    case pilot
}

public struct ReaderSourceSwitchPilotConfiguration: Equatable, Sendable {
    public let mode: ReaderSourceSwitchPilotMode

    public init(mode: ReaderSourceSwitchPilotMode = .shadow) {
        self.mode = mode
    }

    public static let live = ReaderSourceSwitchPilotConfiguration(mode: .shadow)
}

/// Outcome of executing a single source-switch Core effect.
public enum ReaderSourceSwitchEffectOutcome: Equatable, Sendable {
    case completed(coreType: String)
    case failed(coreType: String, message: String)
    case discarded
}

/// Narrow seam for focused Pilot tests. The concrete executor below owns the
/// Core command handles; tests can inject a deterministic fake without booting
/// Core or starting a real source-switch request.
@MainActor
public protocol ReaderSourceSwitchEffectExecuting: AnyObject {
    func begin(correlationID: String)
    func execute(_ effect: ReaderUIEffect) async -> ReaderSourceSwitchEffectOutcome
    func cancel(correlationID: String)
    func finish(correlationID: String)
}

/// Protocol seam for the two Core source-switch commands. Production wires this
/// to a Rust Core adapter; tests inject a deterministic fake.
@MainActor
public protocol ReaderSourceSwitchCoreCommandExecuting: AnyObject {
    func executeCommit(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
    func executeRollback(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
    func cancel(correlationID: String)
    func finish(correlationID: String)
}

public extension ReaderSourceSwitchCoreCommandExecuting {
    func cancel(correlationID: String) {}
    func finish(correlationID: String) {}
}

/// Concrete executor that maps each typed source-switch effect to the
/// corresponding Core command via the injected `ReaderSourceSwitchCoreCommandExecuting` seam.
@MainActor
public final class ReaderSourceSwitchEffectExecutor: ReaderSourceSwitchEffectExecuting {
    private let coreCommands: any ReaderSourceSwitchCoreCommandExecuting
    private var activeCorrelations: Set<String> = []
    private var inFlightCancellers: [String: () -> Void] = [:]

    public init(coreCommands: any ReaderSourceSwitchCoreCommandExecuting) {
        self.coreCommands = coreCommands
    }

    public func execute(_ effect: ReaderUIEffect) async -> ReaderSourceSwitchEffectOutcome {
        guard effect.kind == .core,
              let correlationID = effect.correlationId,
              activeCorrelations.contains(correlationID) else {
            return .discarded
        }

        switch effect.type {
        case "source.switch.commit":
            return await executeCommand(
                coreType: "source.switch.commit",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeCommit(payload: effect.jsonPayload, correlationID: correlationID) }
        case "source.switch.rollback":
            return await executeCommand(
                coreType: "source.switch.rollback",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeRollback(payload: effect.jsonPayload, correlationID: correlationID) }
        default:
            return .failed(coreType: effect.type, message: "SOURCE_SWITCH_UNSUPPORTED_EFFECT")
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
        correlationID: String,
        effect: ReaderUIEffect,
        operation: () async throws -> ReaderUIJSONResult
    ) async -> ReaderSourceSwitchEffectOutcome {
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

/// Executes Reader-UI's source-switch event sequence only when an explicitly
/// injected pilot configuration opts in. `live` remains Shadow, so merely
/// constructing this coordinator does not grant production runtime authority.
///
/// The overlay cohort events (`source.switch.open`, `source.switch.cancel`,
/// `reader.sourceSwitch.open`, `reader.sourceSwitch.close`) are route/overlay
/// actions with no Core effects. The effect cohort events
/// (`source.switch.confirm`, `source.switch.rollback`) are independent
/// `emitEffects` actions that each produce exactly one Core effect
/// (`source.switch.commit`, `source.switch.rollback` respectively). The
/// coordinator tracks the active correlation to enforce stale result guards
/// and fail-closed semantics.
@MainActor
public final class ReaderSourceSwitchPilotCoordinator: ObservableObject {
    public let configuration: ReaderSourceSwitchPilotConfiguration
    private let runtime: ReaderUIRuntime
    private let executor: (any ReaderSourceSwitchEffectExecuting)?

    @Published public private(set) var activeCorrelationID: String?
    @Published public private(set) var lastFailure: String?
    /// Source id captured at `source.switch.open` time. On fail-closed the
    /// coordinator exposes this so the host can restore the old book source.
    @Published public private(set) var previousSourceId: String?
    @Published public private(set) var restoredSourceId: String?

    public init(
        configuration: ReaderSourceSwitchPilotConfiguration = .live,
        runtime: ReaderUIRuntime = ReaderUIRuntime(),
        executor: (any ReaderSourceSwitchEffectExecuting)? = nil
    ) {
        self.configuration = configuration
        self.runtime = runtime
        self.executor = executor
    }

    /// Dispatch `source.switch.open` through the runtime transaction. This is
    /// an overlay/route event (pushRoute) with no Core effects.
    @discardableResult
    public func openSourceSwitch(payload: [String: String], correlationId: String?) -> Bool {
        openSourceSwitch(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func openSourceSwitch(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> Bool {
        guard configuration.mode == .pilot else { return false }
        let correlationID = correlationId ?? Self.nextCorrelation(prefix: "source-switch-open")
        do {
            let transition = try runtime.dispatch(
                event: "source.switch.open",
                jsonPayload: payload,
                correlationId: correlationID
            )
            // Boundary: overlay events must emit no Core/Host effects.
            guard transition.effects.isEmpty else {
                failClosed("SOURCE_SWITCH_OVERLAY_EFFECT_BOUNDARY_VIOLATION")
                return true
            }
            lastFailure = nil
            return true
        } catch {
            failClosed(error.localizedDescription)
            return true
        }
    }

    /// Dispatch `source.switch.cancel` through the runtime transaction. This is
    /// an overlay/route event (popRoute) with no Core effects.
    @discardableResult
    public func cancelSourceSwitch(correlationId: String?) -> Bool {
        guard configuration.mode == .pilot else { return false }
        let correlationID = correlationId ?? Self.nextCorrelation(prefix: "source-switch-cancel")
        do {
            let transition = try runtime.dispatch(
                event: "source.switch.cancel",
                jsonPayload: [:],
                correlationId: correlationID
            )
            guard transition.effects.isEmpty else {
                failClosed("SOURCE_SWITCH_OVERLAY_EFFECT_BOUNDARY_VIOLATION")
                return true
            }
            return true
        } catch {
            failClosed(error.localizedDescription)
            return true
        }
    }

    /// Dispatch `source.switch.confirm` through the runtime transaction,
    /// emitting the `source.switch.commit` Core effect.
    @discardableResult
    public func confirmSourceSwitch(payload: [String: String], correlationId: String?) -> Bool {
        confirmSourceSwitch(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func confirmSourceSwitch(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> Bool {
        guard configuration.mode == .pilot else { return false }
        guard let executor else {
            failClosed("SOURCE_SWITCH_EXECUTOR_MISSING")
            return true
        }
        let correlationID = correlationId ?? Self.nextCorrelation(prefix: "source-switch-confirm")
        if let activeCorrelationID, activeCorrelationID != correlationID {
            executor.cancel(correlationID: activeCorrelationID)
        }
        executor.begin(correlationID: correlationID)
        if case .object(let from)? = payload["from"],
           let sourceID = from["sourceId"]?.stringValue,
           !sourceID.isEmpty {
            previousSourceId = sourceID
        }
        do {
            let transition = try runtime.dispatch(
                event: "source.switch.confirm",
                jsonPayload: payload,
                correlationId: correlationID
            )
            // Boundary: effectful events must emit exactly one Core effect.
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

    /// Dispatch `source.switch.rollback` through the runtime transaction,
    /// emitting the `source.switch.rollback` Core effect.
    @discardableResult
    public func rollbackSourceSwitch(correlationId: String?) -> Bool {
        rollbackSourceSwitch(jsonPayload: [:], correlationId: correlationId)
    }

    @discardableResult
    public func rollbackSourceSwitch(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> Bool {
        guard configuration.mode == .pilot else { return false }
        guard let executor else {
            failClosed("SOURCE_SWITCH_EXECUTOR_MISSING")
            return true
        }
        let correlationID = correlationId ?? activeCorrelationID ?? Self.nextCorrelation(prefix: "source-switch-rollback")
        executor.begin(correlationID: correlationID)
        do {
            let transition = try runtime.dispatch(
                event: "source.switch.rollback",
                jsonPayload: payload,
                correlationId: correlationID
            )
            guard transition.effects.count == 1,
                  transition.effects.allSatisfy({ $0.kind == .core }) else {
                failClosedEffectBoundary(correlationID: correlationID)
                return true
            }
            Task { [weak self] in
                await self?.execute(transition.effects, correlationID: correlationID)
            }
            if activeCorrelationID == correlationID {
                activeCorrelationID = nil
            }
            // Rollback restores the old source; clear the previous tracking.
            previousSourceId = nil
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
            case .source_switch_open:
                return openSourceSwitch(jsonPayload: payload, correlationId: event.correlationId)
            case .source_switch_cancel:
                return cancelSourceSwitch(correlationId: event.correlationId)
            case .source_switch_confirm:
                return confirmSourceSwitch(jsonPayload: payload, correlationId: event.correlationId)
            case .source_switch_rollback:
                return rollbackSourceSwitch(jsonPayload: payload, correlationId: event.correlationId)
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
                // Fail-closed: restore the old book source so the host can
                // project the pre-switch state.
                restoredSourceId = previousSourceId
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
        // Fail-closed: restore the old book source on effect boundary violation.
        restoredSourceId = previousSourceId
        lastFailure = message ?? "SOURCE_SWITCH_EFFECT_BOUNDARY_VIOLATION"
    }

    private static func nextCorrelation(prefix: String) -> String {
        "ios:\(prefix):\(UUID().uuidString)"
    }

}
