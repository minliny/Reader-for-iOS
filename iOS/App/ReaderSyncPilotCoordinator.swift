import Combine
import Foundation
import ReaderCoreNativeAdapter
import ReaderShellValidation
import ReaderUIContract
import ReaderUIRuntime

/// Typed execution mode for the experimental Sync seam. Production derives
/// this from `ReaderUIRuntimeRollout.syncPilotMode`, which remains Shadow until
/// the typed Core/Host transaction is wired end to end.
public enum ReaderSyncPilotMode: String, Equatable, Sendable {
    case shadow
    case pilot
}

public struct ReaderSyncPilotConfiguration: Equatable, Sendable {
    public let mode: ReaderSyncPilotMode

    public init(mode: ReaderSyncPilotMode = .shadow) {
        self.mode = mode
    }

    public static let live = ReaderSyncPilotConfiguration(
        mode: ReaderUIRuntimeRollout.syncPilotMode == .pilot ? .pilot : .shadow
    )
}

/// Outcome of a coordinator dispatch. The coordinator always consumes a Pilot
/// event (even on failure), so `.failedClosed` signals that the transaction
/// was torn down without leaving an orphan ledger entry.
public enum ReaderSyncPilotOutcome: Equatable, Sendable {
    case dispatched
    case failedClosed
    case shadow
}

/// Outcome of executing a single sync Core or Host effect.
public enum ReaderSyncEffectOutcome: Equatable, Sendable {
    case completed(coreType: String)
    case completedJSON(coreType: String, result: ReaderUIJSONResult)
    case failed(coreType: String, message: String)
    case discarded
}

/// Narrow seam for focused Pilot tests. The concrete executor below owns the
/// Core command handles; tests can inject a deterministic fake without booting
/// Core or starting a real sync request.
@MainActor
public protocol ReaderSyncEffectExecuting: AnyObject {
    func begin(correlationID: String)
    func execute(_ effect: ReaderUIEffect) async -> ReaderSyncEffectOutcome
    func cancel(correlationID: String)
    func finish(correlationID: String)
}

/// Protocol seam for the four unique Core sync commands plus the
/// `http.execute` host request used by `webdav.config.test`. Production wires
/// this to a Rust Core adapter; tests inject a deterministic fake.
@MainActor
public protocol ReaderSyncCoreCommandExecuting: AnyObject {
    func executeSnapshot(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
    func executePush(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
    func executeConflictDetect(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
    func executeConflictResolve(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
    func executeHTTP(payload: ReaderUIJSONPayload, correlationID: String) async throws -> ReaderUIJSONResult
    func cancel(correlationID: String)
    func finish(correlationID: String)
}

public extension ReaderSyncCoreCommandExecuting {
    func cancel(correlationID: String) {}
    func finish(correlationID: String) {}
}

/// Concrete executor that maps each typed sync effect to the corresponding Core
/// command or host request via the injected `ReaderSyncCoreCommandExecuting`
/// seam.
@MainActor
public final class ReaderSyncPilotEffectExecutor: ReaderSyncEffectExecuting {
    private let coreCommands: any ReaderSyncCoreCommandExecuting
    private var activeCorrelations: Set<String> = []
    private var executedEffects: [String: Set<String>] = [:]

    public init(coreCommands: any ReaderSyncCoreCommandExecuting) {
        self.coreCommands = coreCommands
    }

    public func execute(_ effect: ReaderUIEffect) async -> ReaderSyncEffectOutcome {
        guard let correlationID = effect.correlationId,
              activeCorrelations.contains(correlationID) else {
            return .discarded
        }
        let effectKey = "\(effect.kind.rawValue):\(effect.type)"
        guard executedEffects[correlationID, default: []].insert(effectKey).inserted else {
            return .failed(coreType: effect.type, message: "SYNC_EFFECT_ALREADY_EXECUTED")
        }

        switch (effect.kind, effect.type) {
        case (.core, "sync.snapshot"):
            return await executeCommand(
                coreType: "sync.snapshot",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeSnapshot(payload: effect.jsonPayload, correlationID: correlationID) }
        case (.core, "sync.push"):
            return await executeCommand(
                coreType: "sync.push",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executePush(payload: effect.jsonPayload, correlationID: correlationID) }
        case (.core, "sync.conflict.detect"):
            return await executeCommand(
                coreType: "sync.conflict.detect",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeConflictDetect(payload: effect.jsonPayload, correlationID: correlationID) }
        case (.core, "sync.conflict.resolve"):
            return await executeCommand(
                coreType: "sync.conflict.resolve",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeConflictResolve(payload: effect.jsonPayload, correlationID: correlationID) }
        case (.host, "http.execute"):
            return await executeCommand(
                coreType: "http.execute",
                correlationID: correlationID,
                effect: effect
            ) { try await self.coreCommands.executeHTTP(payload: effect.jsonPayload, correlationID: correlationID) }
        default:
            return .failed(coreType: effect.type, message: "SYNC_UNSUPPORTED_EFFECT")
        }
    }

    public func cancel(correlationID: String) {
        activeCorrelations.remove(correlationID)
        coreCommands.cancel(correlationID: correlationID)
        executedEffects[correlationID] = nil
    }

    public func finish(correlationID: String) {
        activeCorrelations.remove(correlationID)
        coreCommands.finish(correlationID: correlationID)
        executedEffects[correlationID] = nil
    }

    /// Called by the coordinator before dispatching effects so the executor
    /// admits the correlation as active.
    public func begin(correlationID: String) {
        activeCorrelations.insert(correlationID)
        executedEffects[correlationID] = []
    }

    private func executeCommand(
        coreType: String,
        correlationID: String,
        effect: ReaderUIEffect,
        operation: () async throws -> ReaderUIJSONResult
    ) async -> ReaderSyncEffectOutcome {
        do {
            let rawResult = try await operation()
            guard activeCorrelations.contains(correlationID) else {
                return .discarded
            }
            let event: String
            switch coreType {
            case "sync.snapshot", "sync.push": event = "sync.run"
            case "sync.conflict.detect": event = "sync.conflict"
            case "sync.conflict.resolve": event = "sync.resolve"
            case "http.execute": event = "webdav.config.test"
            default: return .failed(coreType: coreType, message: "SYNC_UNSUPPORTED_EFFECT")
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

private struct ReaderSyncCoreRawResult: @unchecked Sendable {
    let data: [String: Any]
}

public enum ReaderSyncProductionError: Error, Equatable, LocalizedError {
    case duplicateInFlight(String)
    case missingPlannedHTTPRequest(String)
    case invalidPlannedHTTPRequest(String)
    case hostRequestFailed(String)

    public var errorDescription: String? {
        switch self {
        case .duplicateInFlight(let correlationID):
            return "A sync Core command is already in flight for \(correlationID)"
        case .missingPlannedHTTPRequest(let correlationID):
            return "sync.webdav.plan returned no HTTP request for \(correlationID)"
        case .invalidPlannedHTTPRequest(let message):
            return message
        case .hostRequestFailed(let message):
            return message
        }
    }
}

/// Production Core/Host adapter for the seven Sync Pilot events.
///
/// Reader-UI owns the public effect vocabulary. This adapter performs the
/// documented Core mapping without duplicating sync business logic:
/// - `sync.snapshot` / `sync.conflict.detect` -> Core `sync.merge`
/// - `sync.push` -> Core `sync.webdav.plan`
/// - `sync.conflict.resolve` -> Core `sync.conflict.resolve`
/// - `http.execute` -> the existing process-wide `HostAdapter`
///
/// Every Core request uses `RustCoreRequestScopedCommand`, so correlation
/// replacement cancels the numeric Core request and its request-scoped Host
/// transport. Planned WebDAV HTTP descriptors are retained only until the
/// matching Host effect has executed.
@MainActor
public final class ReaderSyncProductionCoreCommandExecutor: ReaderSyncCoreCommandExecuting {
    private let runtimeProvider: @MainActor () throws -> ReaderCoreNativeRuntime
    private let requestTimeout: TimeInterval
    private var inFlight: [String: RustCoreRequestScopedCommand<ReaderSyncCoreRawResult>] = [:]
    private var plannedHTTPRequests: [String: [[String: Any]]] = [:]

    public init(
        requestTimeout: TimeInterval = 15,
        runtimeProvider: @escaping @MainActor () throws -> ReaderCoreNativeRuntime = {
            try RustCoreServiceSupport.requireRuntime()
        }
    ) {
        self.requestTimeout = requestTimeout
        self.runtimeProvider = runtimeProvider
    }

    public func executeSnapshot(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await executeCore(
            uiType: "sync.snapshot",
            method: "sync.merge",
            payload: payload,
            correlationID: correlationID
        )
    }

    public func executePush(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        let raw = try await executeCoreRaw(
            uiType: "sync.push",
            method: "sync.webdav.plan",
            params: Self.webDAVPlanParams(payload),
            correlationID: correlationID
        )
        guard let requests = Self.dictionaryArray(raw["requests"]) else {
            throw ReaderSyncProductionError.missingPlannedHTTPRequest(correlationID)
        }
        plannedHTTPRequests[correlationID] = requests
        return try ReaderUIJSONBridge.result(from: raw)
    }

    public func executeConflictDetect(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await executeCore(
            uiType: "sync.conflict.detect",
            method: "sync.merge",
            payload: payload,
            correlationID: correlationID
        )
    }

    public func executeConflictResolve(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await executeCore(
            uiType: "sync.conflict.resolve",
            method: "sync.conflict.resolve",
            payload: payload,
            correlationID: correlationID
        )
    }

    public func executeHTTP(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        guard var requests = plannedHTTPRequests[correlationID], !requests.isEmpty else {
            throw ReaderSyncProductionError.missingPlannedHTTPRequest(correlationID)
        }
        let planned = requests.removeFirst()
        plannedHTTPRequests[correlationID] = requests
        guard let url = planned["url"] as? String, !url.isEmpty else {
            throw ReaderSyncProductionError.invalidPlannedHTTPRequest(
                "sync.webdav.plan returned an HTTP request without a URL"
            )
        }

        var hostPayload: [String: AnyCodable] = [
            "url": AnyCodable(url),
            "method": Self.anyCodable(planned["method"] ?? "GET"),
            "headers": Self.anyCodable(planned["headers"] ?? [String: Any]()),
        ]
        for key in ["charset", "followRedirects", "maxRedirects"] {
            if let value = planned[key], !(value is NSNull) {
                hostPayload[key] = Self.anyCodable(value)
            }
        }
        if let bytes = Self.byteArray(planned["body"]) {
            hostPayload["body"] = AnyCodable(String(data: Data(bytes), encoding: .utf8) ?? Data(bytes).base64EncodedString())
        } else if let body = planned["body"] as? String {
            hostPayload["body"] = AnyCodable(body)
        }
        let requestID = "sync-http:\(correlationID)"
        let outcome = await HostAdapterHolder.adapter.dispatch(HostRequest(
            type: .http_execute,
            payload: hostPayload,
            correlationId: correlationID,
            requestId: requestID,
            initiator: .reducer
        ))
        guard outcome.succeeded else {
            throw ReaderSyncProductionError.hostRequestFailed(
                "http.execute failed: \(String(describing: outcome.error))"
            )
        }
        return try ReaderUIJSONBridge.payload(from: outcome.result ?? [:])
    }

    public func cancel(correlationID: String) {
        inFlight.removeValue(forKey: correlationID)?.cancel()
        plannedHTTPRequests[correlationID] = nil
        let requestID = "sync-http:\(correlationID)"
        Task { @MainActor in
            _ = await HostAdapterHolder.adapter.dispatch(HostRequest(
                type: .http_cancel,
                payload: ["requestId": AnyCodable(requestID)],
                correlationId: correlationID,
                requestId: requestID,
                initiator: .reducer
            ))
        }
    }

    public func finish(correlationID: String) {
        inFlight[correlationID] = nil
        plannedHTTPRequests[correlationID] = nil
    }

    private func executeCore(
        uiType: String,
        method: String,
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        let raw = try await executeCoreRaw(
            uiType: uiType,
            method: method,
            params: Self.coreParams(payload),
            correlationID: correlationID
        )
        return try ReaderUIJSONBridge.result(from: raw)
    }

    private func executeCoreRaw(
        uiType: String,
        method: String,
        params: [String: Any],
        correlationID: String
    ) async throws -> [String: Any] {
        guard inFlight[correlationID] == nil else {
            throw ReaderSyncProductionError.duplicateInFlight(correlationID)
        }
        let runtime = try runtimeProvider()
        let requestID = RustCoreServiceSupport.allocateRequestID()
        let command = try RustCoreRequestScopedCommand<ReaderSyncCoreRawResult>(
            runtime: runtime,
            router: RustCoreServiceSupport.makeRouter(runtime: runtime),
            requestID: requestID,
            correlationID: correlationID,
            method: method,
            params: params,
            timeout: requestTimeout
        ) { data in
            ReaderSyncCoreRawResult(data: data ?? [:])
        }
        inFlight[correlationID] = command
        do {
            try command.start()
            let result = try await command.value()
            guard inFlight[correlationID] === command else {
                throw CancellationError()
            }
            inFlight[correlationID] = nil
            return result.data
        } catch {
            if inFlight[correlationID] === command {
                inFlight[correlationID] = nil
            }
            throw error
        }
    }

    private static func webDAVPlanParams(_ payload: ReaderUIJSONPayload) -> [String: Any] {
        var params = coreParams(payload)
        if params["baseUrl"] == nil {
            params["baseUrl"] = payload["serverURL"]?.stringValue ?? payload["url"]?.stringValue
        }
        if params["auth"] == nil,
           let username = payload["username"]?.stringValue,
           let password = payload["password"]?.stringValue {
            let token = Data("\(username):\(password)".utf8).base64EncodedString()
            params["auth"] = "Basic \(token)"
        }
        if params["requests"] == nil, params["baseUrl"] != nil {
            params["requests"] = [[
                "method": "PROPFIND",
                "path": "",
                "headers": [[String: String]](),
                "depth": 0,
            ]]
        }
        params["serverURL"] = nil
        params["url"] = nil
        params["username"] = nil
        params["password"] = nil
        return params
    }

    private static func coreParams(_ payload: ReaderUIJSONPayload) -> [String: Any] {
        ReaderUIJSONBridge.foundationObject(from: payload)
    }

    private static func dictionaryArray(_ value: Any?) -> [[String: Any]]? {
        if let dictionaries = value as? [[String: Any]] { return dictionaries }
        if let dictionaries = value as? [NSDictionary] {
            return dictionaries.map { dictionary in
                dictionary.reduce(into: [String: Any]()) { result, pair in
                    guard let key = pair.key as? String else { return }
                    result[key] = pair.value
                }
            }
        }
        return nil
    }

    private static func byteArray(_ value: Any?) -> [UInt8]? {
        if let bytes = value as? [UInt8] { return bytes }
        if let numbers = value as? [NSNumber] { return numbers.map(\.uint8Value) }
        return nil
    }

    private static func anyCodableDictionary(_ dictionary: [String: Any]) -> [String: AnyCodable] {
        dictionary.reduce(into: [:]) { result, pair in
            result[pair.key] = anyCodable(pair.value)
        }
    }

    private static func anyCodable(_ value: Any) -> AnyCodable {
        if let dictionary = value as? [String: Any] {
            return AnyCodable(anyCodableDictionary(dictionary))
        }
        if let array = value as? [Any] {
            return AnyCodable(array.map(anyCodable))
        }
        return AnyCodable(value)
    }

}

/// Executes Reader-UI's sync event sequence only when an explicitly injected
/// pilot configuration opts in. `live` remains Shadow, so merely constructing
/// this coordinator does not grant production runtime authority.
///
/// Each sync event is an `emitEffects` action:
/// - `sync.run` → core: [sync.snapshot, sync.push]
/// - `webdav.config.test` → core: [sync.push] + host: [http.execute]
/// - `sync.start` → core: [sync.snapshot] (staleResultGuard=true)
/// - `sync.progress` → core: [sync.push]
/// - `sync.complete` → core: [sync.push]
/// - `sync.conflict` → core: [sync.conflict.detect] (staleResultGuard=true)
/// - `sync.resolve` → core: [sync.conflict.resolve] (rollback=true)
///
/// The coordinator tracks the active correlation to enforce stale result
/// guards and fail-closed semantics. On any effect boundary violation or
/// executor failure, the coordinator tears down the transaction and returns
/// `.failedClosed` — no orphan ledger entry is left behind.
@MainActor
public final class ReaderSyncPilotCoordinator: ObservableObject {
    public let configuration: ReaderSyncPilotConfiguration
    private let runtime: ReaderUIRuntime
    private let executor: (any ReaderSyncEffectExecuting)?
    private var executionTasks: [String: Task<Void, Never>] = [:]
    private var consumedCorrelationIDs: Set<String> = []

    @Published public private(set) var activeCorrelationID: String?
    @Published public private(set) var lastFailure: String?
    @Published public private(set) var lastOutcome: ReaderSyncPilotOutcome?
    @Published public private(set) var lastResults: [String: ReaderUIJSONResult] = [:]

    public init(
        configuration: ReaderSyncPilotConfiguration = .live,
        runtime: ReaderUIRuntime = ReaderUIRuntime(),
        executor: (any ReaderSyncEffectExecuting)? = nil
    ) {
        self.configuration = configuration
        self.runtime = runtime
        self.executor = executor
    }

    // MARK: - Dispatch methods for each sync event

    /// Dispatch `sync.run` through the runtime transaction, emitting the
    /// `sync.snapshot` and `sync.push` Core effects.
    @discardableResult
    public func runSync(payload: [String: String], correlationId: String?) -> ReaderSyncPilotOutcome {
        runSync(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func runSync(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> ReaderSyncPilotOutcome {
        dispatch(event: "sync.run", prefix: "sync-run", payload: payload, correlationId: correlationId)
    }

    /// Dispatch `webdav.config.test` through the runtime transaction, emitting
    /// the `sync.push` Core effect and the `http.execute` host request.
    @discardableResult
    public func testWebDAVConfig(payload: [String: String], correlationId: String?) -> ReaderSyncPilotOutcome {
        testWebDAVConfig(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func testWebDAVConfig(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> ReaderSyncPilotOutcome {
        dispatch(event: "webdav.config.test", prefix: "webdav-test", payload: payload, correlationId: correlationId)
    }

    /// Dispatch `sync.start` through the runtime transaction, emitting the
    /// `sync.snapshot` Core effect. staleResultGuard=true.
    @discardableResult
    public func startSync(payload: [String: String], correlationId: String?) -> ReaderSyncPilotOutcome {
        startSync(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func startSync(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> ReaderSyncPilotOutcome {
        dispatch(event: "sync.start", prefix: "sync-start", payload: payload, correlationId: correlationId)
    }

    /// Dispatch `sync.progress` through the runtime transaction, emitting the
    /// `sync.push` Core effect.
    @discardableResult
    public func reportSyncProgress(payload: [String: String], correlationId: String?) -> ReaderSyncPilotOutcome {
        reportSyncProgress(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func reportSyncProgress(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> ReaderSyncPilotOutcome {
        dispatch(event: "sync.progress", prefix: "sync-progress", payload: payload, correlationId: correlationId)
    }

    /// Dispatch `sync.complete` through the runtime transaction, emitting the
    /// `sync.push` Core effect.
    @discardableResult
    public func completeSync(payload: [String: String], correlationId: String?) -> ReaderSyncPilotOutcome {
        completeSync(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func completeSync(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> ReaderSyncPilotOutcome {
        dispatch(event: "sync.complete", prefix: "sync-complete", payload: payload, correlationId: correlationId)
    }

    /// Dispatch `sync.conflict` through the runtime transaction, emitting the
    /// `sync.conflict.detect` Core effect. staleResultGuard=true.
    @discardableResult
    public func detectSyncConflict(payload: [String: String], correlationId: String?) -> ReaderSyncPilotOutcome {
        detectSyncConflict(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func detectSyncConflict(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> ReaderSyncPilotOutcome {
        dispatch(event: "sync.conflict", prefix: "sync-conflict", payload: payload, correlationId: correlationId)
    }

    /// Dispatch `sync.resolve` through the runtime transaction, emitting the
    /// `sync.conflict.resolve` Core effect. rollback=true.
    @discardableResult
    public func resolveSyncConflict(payload: [String: String], correlationId: String?) -> ReaderSyncPilotOutcome {
        resolveSyncConflict(jsonPayload: .readerUIStrings(payload), correlationId: correlationId)
    }

    @discardableResult
    public func resolveSyncConflict(jsonPayload payload: ReaderUIJSONPayload, correlationId: String?) -> ReaderSyncPilotOutcome {
        dispatch(event: "sync.resolve", prefix: "sync-resolve", payload: payload, correlationId: correlationId)
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
        let outcome: ReaderSyncPilotOutcome
        switch event.type {
        case .sync_run:
            outcome = runSync(jsonPayload: payload, correlationId: event.correlationId)
        case .webdav_config_test:
            outcome = testWebDAVConfig(jsonPayload: payload, correlationId: event.correlationId)
        case .sync_start:
            outcome = startSync(jsonPayload: payload, correlationId: event.correlationId)
        case .sync_progress:
            outcome = reportSyncProgress(jsonPayload: payload, correlationId: event.correlationId)
        case .sync_complete:
            outcome = completeSync(jsonPayload: payload, correlationId: event.correlationId)
        case .sync_conflict:
            outcome = detectSyncConflict(jsonPayload: payload, correlationId: event.correlationId)
        case .sync_resolve:
            outcome = resolveSyncConflict(jsonPayload: payload, correlationId: event.correlationId)
        default:
            return false
        }
        return outcome != .shadow
    }

    /// Dispatch a sync event and await the aggregate effect outcome. This is
    /// the synchronous path used by callers that need the result before
    /// deciding whether to fall back to local storage.
    public func dispatchAndAwait(
        event: String,
        payload: [String: String],
        correlationId: String
    ) async -> ReaderSyncEffectOutcome {
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
    ) async -> ReaderSyncEffectOutcome {
        guard configuration.mode == .pilot else { return .discarded }
        guard let executor else {
            return .failed(coreType: event, message: "SYNC_EXECUTOR_MISSING")
        }
        guard !correlationId.isEmpty,
              !consumedCorrelationIDs.contains(correlationId) else {
            return .failed(coreType: event, message: "SYNC_DUPLICATE_CORRELATION")
        }
        cancelActiveCorrelation(replacingWith: correlationId)
        consumedCorrelationIDs.insert(correlationId)
        executor.begin(correlationID: correlationId)
        do {
            let transition = try runtime.dispatch(
                event: event,
                jsonPayload: payload,
                correlationId: correlationId
            )
            guard validateBoundary(event: event, effects: transition.effects) else {
                executor.cancel(correlationID: correlationId)
                lastFailure = "SYNC_EFFECT_BOUNDARY_VIOLATION"
                lastOutcome = .failedClosed
                return .failed(coreType: event, message: "SYNC_EFFECT_BOUNDARY_VIOLATION")
            }
            activeCorrelationID = correlationId
            lastFailure = nil
            lastOutcome = .dispatched
            var lastOutcome: ReaderSyncEffectOutcome = .discarded
            for effect in transition.effects {
                let effectOutcome = await executor.execute(effect)
                switch effectOutcome {
                case .completed:
                    lastOutcome = effectOutcome
                case .completedJSON(let coreType, let result):
                    lastResults[coreType] = result
                    lastOutcome = effectOutcome
                case .failed(_, let message):
                    executor.cancel(correlationID: correlationId)
                    if activeCorrelationID == correlationId { activeCorrelationID = nil }
                    lastFailure = message
                    self.lastOutcome = .failedClosed
                    return effectOutcome
                case .discarded:
                    executor.cancel(correlationID: correlationId)
                    if activeCorrelationID == correlationId { activeCorrelationID = nil }
                    return .discarded
                }
            }
            if case .completed = lastOutcome {
                executor.finish(correlationID: correlationId)
            } else if case .completedJSON = lastOutcome {
                executor.finish(correlationID: correlationId)
            }
            if activeCorrelationID == correlationId { activeCorrelationID = nil }
            return lastOutcome
        } catch {
            executor.cancel(correlationID: correlationId)
            if activeCorrelationID == correlationId { activeCorrelationID = nil }
            lastFailure = error.localizedDescription
            lastOutcome = .failedClosed
            return .failed(coreType: event, message: error.localizedDescription)
        }
    }

    // MARK: - Private dispatch core

    /// Expected Core effect sequence for each sync event.
    private static let expectedCoreSequences: [String: [String]] = [
        "sync.run": ["sync.snapshot", "sync.push"],
        "webdav.config.test": ["sync.push"],
        "sync.start": ["sync.snapshot"],
        "sync.progress": ["sync.push"],
        "sync.complete": ["sync.push"],
        "sync.conflict": ["sync.conflict.detect"],
        "sync.resolve": ["sync.conflict.resolve"],
    ]

    /// Expected host request type for sync events that have one.
    private static let expectedHostRequests: [String: String] = [
        "webdav.config.test": "http.execute",
    ]

    private func dispatch(
        event: String,
        prefix: String,
        payload: ReaderUIJSONPayload,
        correlationId: String?
    ) -> ReaderSyncPilotOutcome {
        guard configuration.mode == .pilot else {
            lastOutcome = .shadow
            return .shadow
        }
        guard let executor else {
            failClosed("SYNC_EXECUTOR_MISSING")
            lastOutcome = .failedClosed
            return .failedClosed
        }
        let correlationID = correlationId ?? Self.nextCorrelation(prefix: prefix)
        guard !correlationID.isEmpty,
              !consumedCorrelationIDs.contains(correlationID) else {
            failClosed("SYNC_DUPLICATE_CORRELATION")
            lastOutcome = .failedClosed
            return .failedClosed
        }
        cancelActiveCorrelation(replacingWith: correlationID)
        consumedCorrelationIDs.insert(correlationID)
        executor.begin(correlationID: correlationID)
        do {
            let transition = try runtime.dispatch(
                event: event,
                jsonPayload: payload,
                correlationId: correlationID
            )
            // Boundary: the transition effects must match the expected Core
            // sequence and optional host request for this event.
            guard validateBoundary(event: event, effects: transition.effects) else {
                failClosedEffectBoundary(correlationID: correlationID)
                lastOutcome = .failedClosed
                return .failedClosed
            }
            activeCorrelationID = correlationID
            lastFailure = nil
            lastResults = [:]
            lastOutcome = .dispatched
            let task = Task { [weak self] in
                guard let self else { return }
                await self.execute(transition.effects, correlationID: correlationID)
            }
            executionTasks[correlationID] = task
            return .dispatched
        } catch {
            failClosedEffectBoundary(correlationID: correlationID, message: error.localizedDescription)
            lastOutcome = .failedClosed
            return .failedClosed
        }
    }

    /// Execute all effects for a correlation in sequence. The transaction is
    /// finished only after every effect completes; any failure tears down the
    /// transaction via fail-closed.
    private func execute(_ effects: [ReaderUIEffect], correlationID: String) async {
        guard let executor else { return }
        defer { executionTasks[correlationID] = nil }
        for effect in effects {
            let outcome = await executor.execute(effect)
            switch outcome {
            case .discarded:
                // Stale-result guard: a late result for an already-cancelled
                // correlation is silently discarded.
                if activeCorrelationID == correlationID {
                    lastFailure = "SYNC_ACTIVE_EFFECT_DISCARDED"
                    executor.cancel(correlationID: correlationID)
                    activeCorrelationID = nil
                    lastOutcome = .failedClosed
                }
                return
            case .failed(_, let message):
                lastFailure = message
                executor.cancel(correlationID: correlationID)
                if activeCorrelationID == correlationID {
                    activeCorrelationID = nil
                }
                lastOutcome = .failedClosed
                return
            case .completed:
                // Continue to the next effect; finish only after all complete.
                continue
            case .completedJSON(let coreType, let result):
                lastResults[coreType] = result
                continue
            }
        }
        // All effects completed successfully.
        executor.finish(correlationID: correlationID)
        if activeCorrelationID == correlationID {
            activeCorrelationID = nil
        }
    }

    private func cancelActiveCorrelation(replacingWith correlationID: String) {
        guard let activeCorrelationID, activeCorrelationID != correlationID else { return }
        executionTasks.removeValue(forKey: activeCorrelationID)?.cancel()
        executor?.cancel(correlationID: activeCorrelationID)
        self.activeCorrelationID = nil
    }

    /// Validate that the transition effects match the expected Core sequence
    /// and optional host request for the given event. Core effects come first
    /// (in the order of the coreSequence), then the host effect if present.
    private func validateBoundary(event: String, effects: [ReaderUIEffect]) -> Bool {
        guard let expectedCore = Self.expectedCoreSequences[event] else {
            return false
        }
        let expectedHost = Self.expectedHostRequests[event]
        let expectedCount = expectedCore.count + (expectedHost != nil ? 1 : 0)
        guard effects.count == expectedCount else {
            return false
        }
        for (index, coreType) in expectedCore.enumerated() {
            guard effects[index].kind == .core, effects[index].type == coreType else {
                return false
            }
        }
        if let expectedHost {
            let hostIndex = expectedCore.count
            guard effects[hostIndex].kind == .host, effects[hostIndex].type == expectedHost else {
                return false
            }
        }
        return true
    }

    private func failClosed(_ message: String) {
        lastFailure = message
    }

    private func failClosedEffectBoundary(correlationID: String, message: String? = nil) {
        executionTasks.removeValue(forKey: correlationID)?.cancel()
        executor?.cancel(correlationID: correlationID)
        if activeCorrelationID == correlationID {
            activeCorrelationID = nil
        }
        lastFailure = message ?? "SYNC_EFFECT_BOUNDARY_VIOLATION"
    }

    private static func nextCorrelation(prefix: String) -> String {
        "ios:\(prefix):\(UUID().uuidString)"
    }

}
