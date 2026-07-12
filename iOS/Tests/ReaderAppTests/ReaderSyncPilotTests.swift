import XCTest
import ReaderUIContract
import ReaderUIRuntime
@testable import ReaderApp

/// Experimental parity tests for the future Sync Pilot coordinator.
///
/// Each sync event is an `emitEffects` action that emits one or more Core
/// effects (and optionally a host request). The coordinator enforces the
/// effect boundary, stale result guard, and fail-closed semantics.
///
/// Parity coverage maps the sync functional surface to the canonical
/// coordinator dispatch:
/// - `sync.run` → core: [sync.snapshot, sync.push]
/// - `webdav.config.test` → core: [sync.push] + host: [http.execute]
/// - `sync.start` → core: [sync.snapshot] (staleResultGuard=true)
/// - `sync.progress` → core: [sync.push]
/// - `sync.complete` → core: [sync.push]
/// - `sync.conflict` → core: [sync.conflict.detect] (staleResultGuard=true)
/// - `sync.resolve` → core: [sync.conflict.resolve] (rollback=true)
/// - fail-closed: effect executor failure tears down the transaction without
///   leaving an orphan ledger entry.
@MainActor
final class ReaderSyncPilotTests: XCTestCase {

    // MARK: - 1. Live configuration remains Shadow

    func testSyncLiveConfigurationRemainsShadowUntilProductionGatewayCloses() {
        XCTAssertEqual(ReaderSyncPilotConfiguration.live.mode, .shadow)
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "sync.run"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "webdav.config.test"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "sync.start"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "sync.progress"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "sync.complete"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "sync.conflict"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "sync.resolve"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.cohorts
                .first { $0.id == "sync-pilot" },
            nil
        )
    }

    // MARK: - 2. sync.run dispatches sync.snapshot + sync.push Core effects

    func testSyncRunDispatchesSnapshotAndPushEffects() async throws {
        let executor = FakeSyncExecutor(outcomes: [
            .completed(coreType: "sync.snapshot"),
            .completed(coreType: "sync.push"),
        ])
        let coordinator = makeCoordinator(executor: executor)

        let outcome = coordinator.runSync(
            jsonPayload: syncRunPayload(),
            correlationId: "sync-run-1"
        )

        XCTAssertEqual(outcome, .dispatched)
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["sync.snapshot", "sync.push"])
        XCTAssertEqual(executor.begun, ["sync-run-1"])
        XCTAssertTrue(executor.cancelled.isEmpty)
        XCTAssertEqual(executor.finished, ["sync-run-1"])
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 3. webdav.config.test dispatches sync.push + http.execute hostRequest

    func testWebDAVConfigTestDispatchesPushAndHTTP() async throws {
        let executor = FakeSyncExecutor(outcomes: [
            .completed(coreType: "sync.push"),
            .completed(coreType: "http.execute"),
        ])
        let coordinator = makeCoordinator(executor: executor)

        let outcome = coordinator.testWebDAVConfig(
            jsonPayload: syncPlanPayload(),
            correlationId: "webdav-test-1"
        )

        XCTAssertEqual(outcome, .dispatched)
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["sync.push", "http.execute"])
        XCTAssertEqual(executor.executedKinds, [.core, .host])
        XCTAssertEqual(executor.finished, ["webdav-test-1"])
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 4. sync.start dispatches sync.snapshot + staleResultGuard

    func testSyncStartDispatchesSnapshotEffect() async throws {
        let executor = FakeSyncExecutor(outcomes: [.completed(coreType: "sync.snapshot")])
        let coordinator = makeCoordinator(executor: executor)

        let outcome = coordinator.startSync(
            jsonPayload: syncConflictPayload(),
            correlationId: "sync-start-1"
        )

        XCTAssertEqual(outcome, .dispatched)
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["sync.snapshot"])
        XCTAssertEqual(executor.finished, ["sync-start-1"])
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 5. sync.progress dispatches sync.push

    func testSyncProgressDispatchesPushEffect() async throws {
        let executor = FakeSyncExecutor(outcomes: [.completed(coreType: "sync.push")])
        let coordinator = makeCoordinator(executor: executor)

        let outcome = coordinator.reportSyncProgress(
            jsonPayload: syncPlanPayload(),
            correlationId: "sync-progress-1"
        )

        XCTAssertEqual(outcome, .dispatched)
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["sync.push"])
        XCTAssertEqual(executor.finished, ["sync-progress-1"])
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 6. sync.complete dispatches sync.push

    func testSyncCompleteDispatchesPushEffect() async throws {
        let executor = FakeSyncExecutor(outcomes: [.completed(coreType: "sync.push")])
        let coordinator = makeCoordinator(executor: executor)

        let outcome = coordinator.completeSync(
            jsonPayload: syncPlanPayload(),
            correlationId: "sync-complete-1"
        )

        XCTAssertEqual(outcome, .dispatched)
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["sync.push"])
        XCTAssertEqual(executor.finished, ["sync-complete-1"])
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 7. sync.conflict dispatches sync.conflict.detect

    func testSyncConflictDispatchesConflictDetectEffect() async throws {
        let executor = FakeSyncExecutor(outcomes: [.completed(coreType: "sync.conflict.detect")])
        let coordinator = makeCoordinator(executor: executor)

        let outcome = coordinator.detectSyncConflict(
            jsonPayload: syncConflictPayload(),
            correlationId: "sync-conflict-1"
        )

        XCTAssertEqual(outcome, .dispatched)
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["sync.conflict.detect"])
        XCTAssertEqual(executor.finished, ["sync-conflict-1"])
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 8. sync.resolve dispatches sync.conflict.resolve + rollback path

    func testSyncResolveDispatchesConflictResolveAndRollsBackOnFailure() async throws {
        // Success path
        let successExecutor = FakeSyncExecutor(outcomes: [.completed(coreType: "sync.conflict.resolve")])
        let successCoordinator = makeCoordinator(executor: successExecutor)

        let successOutcome = successCoordinator.resolveSyncConflict(
            jsonPayload: syncResolvePayload(),
            correlationId: "sync-resolve-1"
        )

        XCTAssertEqual(successOutcome, .dispatched)
        try await eventually { successCoordinator.activeCorrelationID == nil }
        XCTAssertEqual(successExecutor.executedTypes, ["sync.conflict.resolve"])
        XCTAssertNil(successCoordinator.lastFailure)

        // Rollback path: executor failure triggers fail-closed teardown
        let failExecutor = FakeSyncExecutor(outcomes: [
            .failed(coreType: "sync.conflict.resolve", message: "CORE_SYNC_CONFLICT_RESOLVE_FAILURE")
        ])
        let failCoordinator = makeCoordinator(executor: failExecutor)

        let failOutcome = failCoordinator.resolveSyncConflict(
            jsonPayload: syncResolvePayload(),
            correlationId: "sync-resolve-fail-1"
        )

        XCTAssertEqual(failOutcome, .dispatched, "Dispatch succeeds even though the effect will fail async")
        try await eventually { failCoordinator.lastFailure != nil }
        try await eventually { failCoordinator.activeCorrelationID == nil }

        XCTAssertEqual(failExecutor.executedTypes, ["sync.conflict.resolve"])
        XCTAssertEqual(failExecutor.cancelled, ["sync-resolve-fail-1"])
        XCTAssertTrue(failExecutor.finished.isEmpty, "A failed effect must not close as success")
        XCTAssertEqual(failCoordinator.lastFailure, "CORE_SYNC_CONFLICT_RESOLVE_FAILURE")
        XCTAssertEqual(failCoordinator.lastOutcome, .failedClosed)
        XCTAssertNil(
            failCoordinator.activeCorrelationID,
            "Rollback must clear the active correlation — no orphan ledger"
        )
    }

    // MARK: - 9. Fail-closed: effect executor failure returns .failedClosed, no orphan ledger

    func testFailClosedWhenEffectExecutorThrowsNoOrphanLedger() async throws {
        // sync.run has 2 effects; fail on the first (sync.snapshot)
        let executor = FakeSyncExecutor(outcomes: [
            .failed(coreType: "sync.snapshot", message: "CORE_SYNC_SNAPSHOT_NETWORK_FAILURE")
        ])
        let coordinator = makeCoordinator(executor: executor)

        let outcome = coordinator.runSync(
            jsonPayload: syncRunPayload(),
            correlationId: "sync-run-fail-1"
        )

        // Dispatch itself succeeds; the failure is observed async
        XCTAssertEqual(outcome, .dispatched)
        try await eventually { coordinator.lastFailure != nil }
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["sync.snapshot"])
        XCTAssertEqual(executor.cancelled, ["sync-run-fail-1"])
        XCTAssertTrue(executor.finished.isEmpty, "Failed effect must not close as success")
        XCTAssertEqual(coordinator.lastFailure, "CORE_SYNC_SNAPSHOT_NETWORK_FAILURE")
        XCTAssertEqual(coordinator.lastOutcome, .failedClosed)
        XCTAssertNil(
            coordinator.activeCorrelationID,
            "Fail-closed must clear active correlation — no orphan ledger"
        )
    }

    // MARK: - 10. Shadow mode returns .shadow (rollback seam)

    func testSyncPilotShadowModeReturnsShadow() {
        let coordinator = ReaderSyncPilotCoordinator(
            configuration: ReaderSyncPilotConfiguration(mode: .shadow),
            runtime: ReaderUIRuntime(),
            executor: FakeSyncExecutor()
        )

        XCTAssertEqual(coordinator.runSync(payload: [:], correlationId: "shadow-1"), .shadow)
        XCTAssertEqual(coordinator.testWebDAVConfig(payload: [:], correlationId: "shadow-2"), .shadow)
        XCTAssertEqual(coordinator.startSync(payload: [:], correlationId: "shadow-3"), .shadow)
        XCTAssertEqual(coordinator.reportSyncProgress(payload: [:], correlationId: "shadow-4"), .shadow)
        XCTAssertEqual(coordinator.completeSync(payload: [:], correlationId: "shadow-5"), .shadow)
        XCTAssertEqual(coordinator.detectSyncConflict(payload: [:], correlationId: "shadow-6"), .shadow)
        XCTAssertEqual(coordinator.resolveSyncConflict(payload: [:], correlationId: "shadow-7"), .shadow)
        XCTAssertNil(coordinator.activeCorrelationID)
        XCTAssertNil(coordinator.lastFailure, "Shadow mode must not produce a failure")
    }

    // MARK: - 11. Fail-closed when executor is missing in pilot mode

    func testSyncPilotFailsClosedWhenExecutorMissing() {
        let coordinator = ReaderSyncPilotCoordinator(
            configuration: ReaderSyncPilotConfiguration(mode: .pilot),
            runtime: ReaderUIRuntime(),
            executor: nil
        )

        XCTAssertEqual(
            coordinator.runSync(payload: [:], correlationId: "sync-no-exec-1"),
            .failedClosed,
            "Pilot mode must return .failedClosed when executor is missing"
        )
        XCTAssertEqual(coordinator.lastFailure, "SYNC_EXECUTOR_MISSING")
        XCTAssertEqual(coordinator.lastOutcome, .failedClosed)
        XCTAssertNil(coordinator.activeCorrelationID, "No orphan ledger when executor is missing")
    }

    // MARK: - 12. Canonical nested sync payloads/results remain lossless

    func testConcreteExecutorPreservesNestedSnapshotConflictsAndRequests() async throws {
        let commands = NestedSyncCoreCommands()
        let executor = ReaderSyncPilotEffectExecutor(coreCommands: commands)
        let runtime = ReaderUIRuntime()
        let correlationID = "sync-json-1"
        let transition = try runtime.dispatch(
            event: "sync.run",
            jsonPayload: syncRunPayload(),
            correlationId: correlationID
        )
        XCTAssertEqual(transition.effects.map(\.type), ["sync.snapshot", "sync.push"])
        XCTAssertTrue(transition.effects.allSatisfy { !$0.legacyPayloadIsComplete })
        executor.begin(correlationID: correlationID)

        var projected: [String: ReaderUIJSONResult] = [:]
        for effect in transition.effects {
            guard case .completedJSON(let coreType, let result) = await executor.execute(effect) else {
                return XCTFail("Expected typed JSON result for \(effect.type)")
            }
            XCTAssertNil(result["legacyExtra"], "Unknown Core fields must be projected away")
            projected[coreType] = result
        }
        executor.finish(correlationID: correlationID)

        guard case .object(let snapshot)? = projected["sync.snapshot"]?["snapshot"],
              case .array(let records)? = snapshot["records"],
              case .object(let firstRecord)? = records.first,
              case .array(let conflicts)? = projected["sync.snapshot"]?["conflicts"],
              case .object(let firstConflict)? = conflicts.first else {
            return XCTFail("Snapshot and conflicts must remain nested JSON")
        }
        XCTAssertEqual(firstRecord["payload"], .object(["chapter": .number(3)]))
        XCTAssertEqual(firstConflict["recordId"], .string("book-1"))

        guard case .array(let requests)? = projected["sync.push"]?["requests"],
              case .object(let request)? = requests.first,
              case .object(let headers)? = request["headers"] else {
            return XCTFail("WebDAV plan requests must remain nested JSON")
        }
        XCTAssertEqual(request["method"], .string("PROPFIND"))
        XCTAssertEqual(headers["Depth"], .string("1"))
        XCTAssertNil(request["transportId"], "Per-request legacy metadata must not cross the typed result boundary")
    }

    // MARK: - Helpers

    private func makeCoordinator(executor: FakeSyncExecutor) -> ReaderSyncPilotCoordinator {
        ReaderSyncPilotCoordinator(
            configuration: ReaderSyncPilotConfiguration(mode: .pilot),
            runtime: ReaderUIRuntime(),
            executor: executor
        )
    }

    private func eventually(
        timeout: TimeInterval = 2,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, !condition() {
            await Task.yield()
        }
        if !condition() {
            throw ReaderUIRuntimeFailure(code: "TEST_TIMEOUT", message: "condition did not become true")
        }
    }

    private func syncPlanPayload() -> ReaderUIJSONPayload {
        [
            "baseUrl": .string("https://dav.test/reader"),
            "requests": .array([]),
        ]
    }

    private func syncRunPayload() -> ReaderUIJSONPayload {
        [
            "local": .object([:]),
            "remote": .object([:]),
            "baseUrl": .string("https://dav.test/reader"),
            "requests": .array([]),
        ]
    }

    private func syncConflictPayload() -> ReaderUIJSONPayload {
        [
            "local": syncSnapshot(id: "local", deviceID: "device-a"),
            "remote": syncSnapshot(id: "remote", deviceID: "device-b"),
            "mergedSnapshotId": .string("merged"),
            "mergedDeviceId": .string("device-a"),
        ]
    }

    private func syncResolvePayload() -> ReaderUIJSONPayload {
        [
            "local": .object([:]),
            "remote": .object([:]),
            "resolutions": .array([]),
        ]
    }

    private func syncSnapshot(id: String, deviceID: String) -> ReaderUIJSONValue {
        .object([
            "snapshotId": .string(id),
            "deviceId": .string(deviceID),
            "createdAt": .number(1),
            "records": .array([]),
        ])
    }
}

@MainActor
private final class FakeSyncExecutor: ReaderSyncEffectExecuting {
    var begun: [String] = []
    var executedTypes: [String] = []
    var executedKinds: [ReaderUIEffectKind] = []
    var cancelled: [String] = []
    var finished: [String] = []
    private var outcomes: [ReaderSyncEffectOutcome]
    private var activeCorrelations: Set<String> = []

    init(outcomes: [ReaderSyncEffectOutcome] = []) {
        self.outcomes = outcomes
    }

    func begin(correlationID: String) {
        begun.append(correlationID)
        activeCorrelations.insert(correlationID)
    }

    func execute(_ effect: ReaderUIEffect) async -> ReaderSyncEffectOutcome {
        executedTypes.append(effect.type)
        executedKinds.append(effect.kind)
        guard let correlationID = effect.correlationId,
              activeCorrelations.contains(correlationID) else {
            return .discarded
        }
        guard !outcomes.isEmpty else {
            return .failed(coreType: effect.type, message: "missing fake outcome")
        }
        return outcomes.removeFirst()
    }

    func cancel(correlationID: String) {
        cancelled.append(correlationID)
        activeCorrelations.remove(correlationID)
    }

    func finish(correlationID: String) {
        finished.append(correlationID)
        activeCorrelations.remove(correlationID)
    }
}

@MainActor
private final class NestedSyncCoreCommands: ReaderSyncCoreCommandExecuting {
    func executeSnapshot(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        guard case .object? = payload["local"],
              case .object? = payload["remote"],
              payload["baseUrl"] == .string("https://dav.test/reader") else {
            throw ReaderUIRuntimeFailure(code: "TEST_PAYLOAD_LOSS", message: "Nested sync input was not preserved")
        }
        return [
            "snapshot": .object([
                "snapshotId": .string("merged"),
                "records": .array([
                    .object([
                        "recordId": .string("book-1"),
                        "payload": .object(["chapter": .number(3)]),
                    ]),
                ]),
            ]),
            "conflicts": .array([
                .object([
                    "recordId": .string("book-1"),
                    "localRevision": .number(2),
                    "remoteRevision": .number(3),
                ]),
            ]),
            "legacyExtra": .string("strip-me"),
        ]
    }

    func executePush(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        guard case .array? = payload["requests"] else {
            throw ReaderUIRuntimeFailure(code: "TEST_PAYLOAD_LOSS", message: "Nested WebDAV requests were not preserved")
        }
        return [
            "requests": .array([
                .object([
                    "url": .string("https://dav.test/reader"),
                    "method": .string("PROPFIND"),
                    "headers": .object(["Depth": .string("1")]),
                    "body": .object(["probe": .bool(true)]),
                    "transportId": .string("strip-me"),
                ]),
            ]),
            "legacyExtra": .string("strip-me"),
        ]
    }

    func executeConflictDetect(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await executeSnapshot(payload: payload, correlationID: correlationID)
    }

    func executeConflictResolve(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        [
            "snapshot": .object([:]),
            "resolvedCount": .number(0),
            "autoResolvedCount": .number(0),
        ]
    }

    func executeHTTP(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        [
            "status": .number(207),
            "headers": .object([:]),
            "bodyBase64": .string(""),
        ]
    }
}
