import Combine
import Foundation
import ReaderUIContract
import ReaderUIRuntime

/// This switch is intentionally independent from `READER_UI_CONSUMER.json`.
/// The consumer lock remains the authority for production runtime rollout;
/// the import trio is currently Shadow in production. Explicit `.pilot`
/// construction is retained only for the experimental transaction seam.
public enum ReaderImportPilotMode: String, Equatable, Sendable {
    case shadow
    case pilot
}

public struct ReaderImportPilotConfiguration: Equatable, Sendable {
    public let mode: ReaderImportPilotMode

    public init(mode: ReaderImportPilotMode = .shadow) {
        self.mode = mode
    }

    public static let live = ReaderImportPilotConfiguration(mode: .shadow)
}

/// Outcome of executing a single import Core effect.
public enum ReaderImportEffectOutcome: Equatable, Sendable {
    case completed(coreType: String)
    case completedJSON(coreType: String, result: ReaderUIJSONResult)
    case failed(coreType: String, message: String)
    case discarded
}

/// Narrow seam for focused Pilot tests. The concrete executor below owns the
/// Core command handles; tests can inject a deterministic fake without booting
/// Core or starting a real import request.
@MainActor
public protocol ReaderImportEffectExecuting: AnyObject {
    func begin(correlationID: String)
    func execute(_ effect: ReaderUIEffect) async -> ReaderImportEffectOutcome
    func cancel(correlationID: String)
    func finish(correlationID: String)
}

/// Protocol seam for the three Core import commands. Production wires this to
/// a Rust Core adapter; tests inject a deterministic fake.
@MainActor
public protocol ReaderImportCoreCommandExecuting: AnyObject {
    func executeParse(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
    func executePersist(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
    func executeRollback(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
}

/// Concrete executor that maps each typed import effect to the corresponding
/// Core command via the injected `ReaderImportCoreCommandExecuting` seam.
@MainActor
public final class ReaderImportEffectExecutor: ReaderImportEffectExecuting {
    private let coreCommands: any ReaderImportCoreCommandExecuting
    private var activeCorrelations: Set<String> = []
    private var inFlightCancellers: [String: () -> Void] = [:]

    public init(coreCommands: any ReaderImportCoreCommandExecuting) {
        self.coreCommands = coreCommands
    }

    public func execute(_ effect: ReaderUIEffect) async -> ReaderImportEffectOutcome {
        guard effect.kind == .core,
              let correlationID = effect.correlationId,
              activeCorrelations.contains(correlationID) else {
            return .discarded
        }

        switch effect.type {
        case "import.parse":
            return await executeCommand(
                coreType: "import.parse",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeParse(payload: effect.jsonPayload, correlationID: correlationID) }
        case "import.persist":
            return await executeCommand(
                coreType: "import.persist",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executePersist(payload: effect.jsonPayload, correlationID: correlationID) }
        case "import.rollback":
            return await executeCommand(
                coreType: "import.rollback",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeRollback(payload: effect.jsonPayload, correlationID: correlationID) }
        default:
            return .failed(coreType: effect.type, message: "IMPORT_UNSUPPORTED_EFFECT")
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
    ) async -> ReaderImportEffectOutcome {
        do {
            let rawResult = try await operation()
            guard activeCorrelations.contains(correlationID) else {
                return .discarded
            }
            let event: String
            switch coreType {
            case "import.parse": event = "import.start"
            case "import.persist": event = "import.apply"
            case "import.rollback": event = "import.cancel"
            default: return .failed(coreType: coreType, message: "IMPORT_UNSUPPORTED_EFFECT")
            }
            let result = try ReaderUIJSONBridge.projectTypedResult(
                event: event,
                effectType: coreType,
                rawResult: rawResult
            )
            return .completedJSON(coreType: coreType, result: result)
        } catch is CancellationError {
            return .discarded
        } catch {
            return activeCorrelations.contains(correlationID)
                ? .failed(coreType: coreType, message: error.localizedDescription)
                : .discarded
        }
    }
}

/// Executes Reader-UI's import event sequence only when an explicitly injected
/// pilot configuration opts in. `live` remains Shadow, so merely constructing
/// this coordinator does not grant production runtime authority.
///
/// Each import event (`import.start`, `import.apply`, `import.cancel`) is an
/// independent `emitEffects` action that produces exactly one Core effect
/// (`import.parse`, `import.persist`, `import.rollback` respectively). The
/// coordinator tracks the active correlation to enforce stale result guards
/// and fail-closed semantics.
@MainActor
public final class ReaderImportPilotCoordinator: ObservableObject {
    public let configuration: ReaderImportPilotConfiguration
    private let runtime: ReaderUIRuntime
    private let executor: (any ReaderImportEffectExecuting)?

    @Published public private(set) var activeCorrelationID: String?
    @Published public private(set) var lastFailure: String?
    @Published public private(set) var lastResult: ReaderUIJSONResult?

    public init(
        configuration: ReaderImportPilotConfiguration = .live,
        runtime: ReaderUIRuntime = ReaderUIRuntime(),
        executor: (any ReaderImportEffectExecuting)? = nil
    ) {
        self.configuration = configuration
        self.runtime = runtime
        self.executor = executor
    }

    /// Dispatch `import.start` through the runtime transaction, emitting the
    /// `import.parse` Core effect. Returns true when the Pilot consumed the
    /// event (even on failure).
    @discardableResult
    public func beginImport(payload: [String: String], correlationId: String?) -> Bool {
        beginImport(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func beginImport(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> Bool {
        guard configuration.mode == .pilot else { return false }
        guard let executor else {
            failClosed("IMPORT_EXECUTOR_MISSING")
            return true
        }
        let correlationID = correlationId ?? Self.nextCorrelation(prefix: "import-start")
        if let activeCorrelationID, activeCorrelationID != correlationID {
            executor.cancel(correlationID: activeCorrelationID)
        }
        executor.begin(correlationID: correlationID)
        do {
            let transition = try runtime.dispatch(
                event: "import.start",
                jsonPayload: payload,
                correlationId: correlationID
            )
            // Boundary: import.start must emit exactly one Core effect.
            guard transition.effects.count == 1,
                  transition.effects.allSatisfy({ $0.kind == .core }) else {
                failClosedEffectBoundary(correlationID: correlationID)
                return true
            }
            activeCorrelationID = correlationID
            lastFailure = nil
            lastResult = nil
            Task { [weak self] in
                await self?.execute(transition.effects, correlationID: correlationID)
            }
            return true
        } catch {
            failClosedEffectBoundary(correlationID: correlationID, message: error.localizedDescription)
            return true
        }
    }

    /// Dispatch `import.apply` through the runtime transaction, emitting the
    /// `import.persist` Core effect.
    @discardableResult
    public func applyImport(payload: [String: String], correlationId: String?) -> Bool {
        applyImport(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func applyImport(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> Bool {
        guard configuration.mode == .pilot else { return false }
        guard let executor else {
            failClosed("IMPORT_EXECUTOR_MISSING")
            return true
        }
        let correlationID = correlationId ?? Self.nextCorrelation(prefix: "import-apply")
        executor.begin(correlationID: correlationID)
        do {
            let transition = try runtime.dispatch(
                event: "import.apply",
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
            lastResult = nil
            Task { [weak self] in
                await self?.execute(transition.effects, correlationID: correlationID)
            }
            return true
        } catch {
            failClosedEffectBoundary(correlationID: correlationID, message: error.localizedDescription)
            return true
        }
    }

    /// Dispatch `import.cancel` through the runtime transaction, emitting the
    /// `import.rollback` Core effect.
    @discardableResult
    public func cancelImport(correlationId: String?) -> Bool {
        cancelImport(jsonPayload: [:], correlationId: correlationId)
    }

    @discardableResult
    public func cancelImport(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> Bool {
        guard configuration.mode == .pilot else { return false }
        guard let executor else {
            failClosed("IMPORT_EXECUTOR_MISSING")
            return true
        }
        let correlationID = correlationId ?? activeCorrelationID ?? Self.nextCorrelation(prefix: "import-cancel")
        executor.begin(correlationID: correlationID)
        do {
            let transition = try runtime.dispatch(
                event: "import.cancel",
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
        switch event.type {
        case .import_start:
            do {
                return beginImport(jsonPayload: try ReaderUIJSONBridge.payload(from: event.payload), correlationId: event.correlationId)
            } catch {
                failClosed(error.localizedDescription)
                return true
            }
        case .import_apply:
            do {
                return applyImport(jsonPayload: try ReaderUIJSONBridge.payload(from: event.payload), correlationId: event.correlationId)
            } catch {
                failClosed(error.localizedDescription)
                return true
            }
        case .import_cancel:
            do {
                return cancelImport(jsonPayload: try ReaderUIJSONBridge.payload(from: event.payload), correlationId: event.correlationId)
            } catch {
                failClosed(error.localizedDescription)
                return true
            }
        default:
            return false
        }
    }

    private func execute(_ effects: [ReaderUIEffect], correlationID: String) async {
        guard let executor else { return }
        for effect in effects {
            let outcome = await executor.execute(effect)
            switch outcome {
            case .discarded:
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
            case .completedJSON(_, let result):
                lastResult = result
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
        lastFailure = message ?? "IMPORT_EFFECT_BOUNDARY_VIOLATION"
    }

    private static func nextCorrelation(prefix: String) -> String {
        "ios:\(prefix):\(UUID().uuidString)"
    }

}
