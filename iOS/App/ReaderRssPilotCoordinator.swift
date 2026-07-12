import Combine
import Foundation
import ReaderUIContract
import ReaderUIRuntime

/// This switch is intentionally independent from `READER_UI_CONSUMER.json`.
/// The consumer lock remains the authority for production runtime rollout;
/// the RSS septet is currently Shadow in production. Explicit `.pilot`
/// construction is retained only for the experimental transaction seam.
public enum ReaderRssPilotMode: String, Equatable, Sendable {
    case shadow
    case pilot
}

public struct ReaderRssPilotConfiguration: Equatable, Sendable {
    public let mode: ReaderRssPilotMode

    public init(mode: ReaderRssPilotMode = .shadow) {
        self.mode = mode
    }

    public static let live = ReaderRssPilotConfiguration(mode: .shadow)
}

/// Outcome of a coordinator dispatch. The coordinator always consumes a Pilot
/// event (even on failure), so `.failedClosed` signals that the transaction
/// was torn down without leaving an orphan ledger entry.
public enum ReaderRssPilotOutcome: Equatable, Sendable {
    case dispatched
    case failedClosed
    case shadow
}

/// Outcome of executing a single RSS Core effect.
public enum ReaderRssEffectOutcome: Equatable, Sendable {
    case completed(coreType: String)
    case failed(coreType: String, message: String)
    case discarded
}

/// Narrow seam for focused Pilot tests. The concrete executor below owns the
/// Core command handles; tests can inject a deterministic fake without booting
/// Core or starting a real RSS request.
@MainActor
public protocol ReaderRssEffectExecuting: AnyObject {
    func begin(correlationID: String)
    func execute(_ effect: ReaderUIEffect) async -> ReaderRssEffectOutcome
    func cancel(correlationID: String)
    func finish(correlationID: String)
}

/// Protocol seam for the six unique Core RSS commands. Production wires this
/// to a Rust Core adapter; tests inject a deterministic fake. Note that
/// `rss.subscription.add` and `rss.subscription.edit` both map to
/// `rss.subscription.persist`.
@MainActor
public protocol ReaderRssCoreCommandExecuting: AnyObject {
    func executeFeedRefresh(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
    func executeSubscriptionPersist(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
    func executeSubscriptionRemove(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
    func executeEntryRead(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
    func executeFavoritePersist(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
    func executeFavoriteRemove(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
}

/// Concrete executor that maps each typed RSS effect to the corresponding Core
/// command via the injected `ReaderRssCoreCommandExecuting` seam.
@MainActor
public final class ReaderRssPilotEffectExecutor: ReaderRssEffectExecuting {
    private let coreCommands: any ReaderRssCoreCommandExecuting
    private var activeCorrelations: Set<String> = []

    public init(coreCommands: any ReaderRssCoreCommandExecuting) {
        self.coreCommands = coreCommands
    }

    public func execute(_ effect: ReaderUIEffect) async -> ReaderRssEffectOutcome {
        guard effect.kind == .core,
              let correlationID = effect.correlationId,
              activeCorrelations.contains(correlationID) else {
            return .discarded
        }

        switch effect.type {
        case "rss.feed.refresh":
            return await executeCommand(
                coreType: "rss.feed.refresh",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeFeedRefresh(payload: effect.jsonPayload, correlationID: correlationID) }
        case "rss.subscription.persist":
            return await executeCommand(
                coreType: "rss.subscription.persist",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeSubscriptionPersist(payload: effect.jsonPayload, correlationID: correlationID) }
        case "rss.subscription.remove":
            return await executeCommand(
                coreType: "rss.subscription.remove",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeSubscriptionRemove(payload: effect.jsonPayload, correlationID: correlationID) }
        case "rss.entry.read":
            return await executeCommand(
                coreType: "rss.entry.read",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeEntryRead(payload: effect.jsonPayload, correlationID: correlationID) }
        case "rss.favorite.persist":
            return await executeCommand(
                coreType: "rss.favorite.persist",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeFavoritePersist(payload: effect.jsonPayload, correlationID: correlationID) }
        case "rss.favorite.remove":
            return await executeCommand(
                coreType: "rss.favorite.remove",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeFavoriteRemove(payload: effect.jsonPayload, correlationID: correlationID) }
        default:
            return .failed(coreType: effect.type, message: "RSS_UNSUPPORTED_EFFECT")
        }
    }

    public func cancel(correlationID: String) {
        activeCorrelations.remove(correlationID)
    }

    public func finish(correlationID: String) {
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
    ) async -> ReaderRssEffectOutcome {
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

/// Executes Reader-UI's RSS event sequence only when an explicitly injected
/// pilot configuration opts in. `live` remains Shadow, so merely constructing
/// this coordinator does not grant production runtime authority.
///
/// Each RSS event is an independent `emitEffects` action that produces exactly
/// one Core effect:
/// - `rss.refresh` → `rss.feed.refresh` (staleResultGuard=true)
/// - `rss.subscription.add` → `rss.subscription.persist` (rollback=true)
/// - `rss.subscription.delete` → `rss.subscription.remove` (rollback=true)
/// - `rss.subscription.edit` → `rss.subscription.persist`
/// - `rss.entry.open` → `rss.entry.read`
/// - `rss.favorite.add` → `rss.favorite.persist`
/// - `rss.favorite.remove` → `rss.favorite.remove`
///
/// The coordinator tracks the active correlation to enforce stale result
/// guards and fail-closed semantics. On any effect boundary violation or
/// executor failure, the coordinator tears down the transaction and returns
/// `.failedClosed` — no orphan ledger entry is left behind.
@MainActor
public final class ReaderRssPilotCoordinator: ObservableObject {
    public let configuration: ReaderRssPilotConfiguration
    private let runtime: ReaderUIRuntime
    private let executor: (any ReaderRssEffectExecuting)?

    @Published public private(set) var activeCorrelationID: String?
    @Published public private(set) var lastFailure: String?
    @Published public private(set) var lastOutcome: ReaderRssPilotOutcome?

    public init(
        configuration: ReaderRssPilotConfiguration = .live,
        runtime: ReaderUIRuntime = ReaderUIRuntime(),
        executor: (any ReaderRssEffectExecuting)? = nil
    ) {
        self.configuration = configuration
        self.runtime = runtime
        self.executor = executor
    }

    // MARK: - Dispatch methods for each RSS event

    /// Dispatch `rss.refresh` through the runtime transaction, emitting the
    /// `rss.feed.refresh` Core effect. staleResultGuard=true: a late result
    /// for a superseded correlation is discarded.
    @discardableResult
    public func refreshFeed(payload: [String: String], correlationId: String?) -> ReaderRssPilotOutcome {
        refreshFeed(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func refreshFeed(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> ReaderRssPilotOutcome {
        dispatch(event: "rss.refresh", prefix: "rss-refresh", jsonPayload: payload, correlationId: correlationId)
    }

    /// Dispatch `rss.subscription.add` through the runtime transaction,
    /// emitting the `rss.subscription.persist` Core effect. rollback=true.
    @discardableResult
    public func addSubscription(payload: [String: String], correlationId: String?) -> ReaderRssPilotOutcome {
        addSubscription(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func addSubscription(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> ReaderRssPilotOutcome {
        dispatch(event: "rss.subscription.add", prefix: "rss-sub-add", jsonPayload: payload, correlationId: correlationId)
    }

    /// Dispatch `rss.subscription.delete` through the runtime transaction,
    /// emitting the `rss.subscription.remove` Core effect. rollback=true.
    @discardableResult
    public func deleteSubscription(payload: [String: String], correlationId: String?) -> ReaderRssPilotOutcome {
        deleteSubscription(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func deleteSubscription(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> ReaderRssPilotOutcome {
        dispatch(event: "rss.subscription.delete", prefix: "rss-sub-del", jsonPayload: payload, correlationId: correlationId)
    }

    /// Dispatch `rss.subscription.edit` through the runtime transaction,
    /// emitting the `rss.subscription.persist` Core effect.
    @discardableResult
    public func editSubscription(payload: [String: String], correlationId: String?) -> ReaderRssPilotOutcome {
        editSubscription(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func editSubscription(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> ReaderRssPilotOutcome {
        dispatch(event: "rss.subscription.edit", prefix: "rss-sub-edit", jsonPayload: payload, correlationId: correlationId)
    }

    /// Dispatch `rss.entry.open` through the runtime transaction, emitting the
    /// `rss.entry.read` Core effect.
    @discardableResult
    public func openEntry(payload: [String: String], correlationId: String?) -> ReaderRssPilotOutcome {
        openEntry(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func openEntry(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> ReaderRssPilotOutcome {
        dispatch(event: "rss.entry.open", prefix: "rss-entry-open", jsonPayload: payload, correlationId: correlationId)
    }

    /// Dispatch `rss.favorite.add` through the runtime transaction, emitting
    /// the `rss.favorite.persist` Core effect.
    @discardableResult
    public func addFavorite(payload: [String: String], correlationId: String?) -> ReaderRssPilotOutcome {
        addFavorite(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func addFavorite(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> ReaderRssPilotOutcome {
        dispatch(event: "rss.favorite.add", prefix: "rss-fav-add", jsonPayload: payload, correlationId: correlationId)
    }

    /// Dispatch `rss.favorite.remove` through the runtime transaction,
    /// emitting the `rss.favorite.remove` Core effect.
    @discardableResult
    public func removeFavorite(payload: [String: String], correlationId: String?) -> ReaderRssPilotOutcome {
        removeFavorite(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func removeFavorite(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> ReaderRssPilotOutcome {
        dispatch(event: "rss.favorite.remove", prefix: "rss-fav-rm", jsonPayload: payload, correlationId: correlationId)
    }

    /// ReaderReducer calls this before its legacy switch. Pilot means the
    /// canonical event is consumed even on failure; Shadow means native code
    /// remains authoritative and this method returns false.
    @discardableResult
    public func handle(_ event: UiEvent) -> Bool {
        guard configuration.mode == .pilot else { return false }
        let payload: ReaderUIJSONPayload
        do {
            payload = try ReaderUIJSONBridge.payload(from: event.payload)
        } catch {
            failClosed(error.localizedDescription)
            lastOutcome = .failedClosed
            return true
        }
        let outcome: ReaderRssPilotOutcome
        switch event.type {
        case .rss_refresh:
            outcome = refreshFeed(jsonPayload: payload, correlationId: event.correlationId)
        case .rss_subscription_add:
            outcome = addSubscription(jsonPayload: payload, correlationId: event.correlationId)
        case .rss_subscription_delete:
            outcome = deleteSubscription(jsonPayload: payload, correlationId: event.correlationId)
        case .rss_subscription_edit:
            outcome = editSubscription(jsonPayload: payload, correlationId: event.correlationId)
        case .rss_entry_open:
            outcome = openEntry(jsonPayload: payload, correlationId: event.correlationId)
        case .rss_favorite_add:
            outcome = addFavorite(jsonPayload: payload, correlationId: event.correlationId)
        case .rss_favorite_remove:
            outcome = removeFavorite(jsonPayload: payload, correlationId: event.correlationId)
        default:
            return false
        }
        return outcome != .shadow
    }

    /// Dispatch an RSS event and await the Core effect outcome. This is the
    /// synchronous path used by `RSSSubscriptionStore` for persistence
    /// operations that need the result before deciding whether to fall back
    /// to local file storage.
    public func dispatchAndAwait(
        event: String,
        payload: [String: String],
        correlationId: String
    ) async -> ReaderRssEffectOutcome {
        await dispatchAndAwait(
            event: event,
            jsonPayload: .readerUIStrings(payload),
            correlationId: correlationId
        )
    }

    public func dispatchAndAwait(
        event: String,
        jsonPayload payload: ReaderUIJSONPayload,
        correlationId: String
    ) async -> ReaderRssEffectOutcome {
        guard configuration.mode == .pilot else { return .discarded }
        guard let executor else {
            return .failed(coreType: event, message: "RSS_EXECUTOR_MISSING")
        }
        executor.begin(correlationID: correlationId)
        do {
            let transition = try runtime.dispatch(
                event: event,
                jsonPayload: payload,
                correlationId: correlationId
            )
            guard transition.effects.count == 1,
                  transition.effects.allSatisfy({ $0.kind == .core }) else {
                executor.cancel(correlationID: correlationId)
                return .failed(coreType: event, message: "RSS_EFFECT_BOUNDARY_VIOLATION")
            }
            let effectOutcome = await executor.execute(transition.effects[0])
            switch effectOutcome {
            case .completed:
                executor.finish(correlationID: correlationId)
            case .failed:
                executor.cancel(correlationID: correlationId)
            case .discarded:
                break
            }
            return effectOutcome
        } catch {
            executor.cancel(correlationID: correlationId)
            return .failed(coreType: event, message: error.localizedDescription)
        }
    }

    // MARK: - Private dispatch core

    private func dispatch(
        event: String,
        prefix: String,
        jsonPayload payload: ReaderUIJSONPayload,
        correlationId: String?
    ) -> ReaderRssPilotOutcome {
        guard configuration.mode == .pilot else {
            lastOutcome = .shadow
            return .shadow
        }
        guard let executor else {
            failClosed("RSS_EXECUTOR_MISSING")
            lastOutcome = .failedClosed
            return .failedClosed
        }
        let correlationID = correlationId ?? Self.nextCorrelation(prefix: prefix)
        if let activeCorrelationID, activeCorrelationID != correlationID {
            executor.cancel(correlationID: activeCorrelationID)
        }
        executor.begin(correlationID: correlationID)
        do {
            let transition = try runtime.dispatch(
                event: event,
                jsonPayload: payload,
                correlationId: correlationID
            )
            // Boundary: each RSS event must emit exactly one Core effect.
            guard transition.effects.count == 1,
                  transition.effects.allSatisfy({ $0.kind == .core }) else {
                failClosedEffectBoundary(correlationID: correlationID)
                lastOutcome = .failedClosed
                return .failedClosed
            }
            activeCorrelationID = correlationID
            lastFailure = nil
            lastOutcome = .dispatched
            Task { [weak self] in
                await self?.execute(transition.effects, correlationID: correlationID)
            }
            return .dispatched
        } catch {
            failClosedEffectBoundary(correlationID: correlationID, message: error.localizedDescription)
            lastOutcome = .failedClosed
            return .failedClosed
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
                lastOutcome = .failedClosed
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
        lastFailure = message ?? "RSS_EFFECT_BOUNDARY_VIOLATION"
    }

    private static func nextCorrelation(prefix: String) -> String {
        "ios:\(prefix):\(UUID().uuidString)"
    }

}
