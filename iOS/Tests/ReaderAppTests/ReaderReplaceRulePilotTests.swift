import XCTest
import ReaderUIContract
import ReaderUIRuntime
@testable import ReaderApp

/// H4-E parity tests for the replace-rules Pilot coordinator.
///
/// Each replace-rules event (`reader.replace.apply`, `reader.replace.create`,
/// `reader.replace.validate`) is an independent `emitEffects` action that must
/// emit exactly one Core effect (`replace.apply`, `replace.persist`,
/// `replace.validate` respectively). The coordinator enforces the effect
/// boundary, stale result guard, and fail-closed semantics.
///
/// Parity coverage maps the W5 replace-rules functional surface to the
/// canonical coordinator dispatch:
/// - CRUD: `reader.replace.create` → `replace.persist`
/// - regex validation: `reader.replace.validate` → `replace.validate`
/// - preview / apply: `reader.replace.apply` → `replace.apply`
/// - enable/disable & sort: replacement invalidates the active correlation
///   (stale-result guard) so a reordered or toggled rule set supersedes the
///   in-flight apply.
/// - undo: effect boundary failure clears the transaction fail-closed.
@MainActor
final class ReaderReplaceRulePilotTests: XCTestCase {

    // MARK: - 1. Live configuration remains Shadow

    func testReplaceRuleLiveConfigurationRemainsShadowWithoutProductionCohort() {
        XCTAssertEqual(ReaderReplaceRulePilotConfiguration.live.mode, .shadow)
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "reader.replace.apply"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "reader.replace.create"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "reader.replace.validate"),
            .shadow
        )
        XCTAssertNil(
            ReaderUIRuntimeShadowConfiguration.live.cohorts
                .first { $0.id == "replace-rules-pilot" }
        )
    }

    // MARK: - 2. CRUD: reader.replace.create dispatches replace.persist Core effect

    func testCreateRuleDispatchesPersistEffect() async throws {
        let executor = FakeReplaceRuleExecutor(outcomes: [
            .completed(coreType: "replace.persist", result: replacePersistResult())
        ])
        let coordinator = makeCoordinator(executor: executor)

        XCTAssertTrue(coordinator.createRule(
            jsonPayload: replaceCreatePayload(),
            correlationId: "replace-create-1"
        ))

        try await eventually { executor.executedTypes.contains("replace.persist") }
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["replace.persist"])
        XCTAssertEqual(executor.begun, ["replace-create-1"])
        XCTAssertTrue(executor.cancelled.isEmpty)
        XCTAssertEqual(executor.finished, ["replace-create-1"])
        XCTAssertNil(coordinator.lastFailure)
        XCTAssertEqual(coordinator.lastUndoToken, replaceUndoToken())
    }

    // MARK: - 3. Preview / apply: reader.replace.apply dispatches replace.apply Core effect

    func testApplyRulesDispatchesApplyEffect() async throws {
        let executor = FakeReplaceRuleExecutor(outcomes: [.completed(coreType: "replace.apply")])
        let coordinator = makeCoordinator(executor: executor)

        XCTAssertTrue(coordinator.applyRules(
            jsonPayload: replaceApplyPayload(text: "rain in chapter 1"),
            correlationId: "replace-apply-1"
        ))

        try await eventually { executor.executedTypes.contains("replace.apply") }
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["replace.apply"])
        XCTAssertEqual(executor.begun, ["replace-apply-1"])
        XCTAssertEqual(executor.finished, ["replace-apply-1"])
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 4. Regex validation: reader.replace.validate dispatches replace.validate Core effect

    func testValidateRuleDispatchesValidateEffect() async throws {
        let executor = FakeReplaceRuleExecutor(outcomes: [.completed(coreType: "replace.validate")])
        let coordinator = makeCoordinator(executor: executor)

        XCTAssertTrue(coordinator.validateRule(
            jsonPayload: replaceValidatePayload(),
            correlationId: "replace-validate-1"
        ))

        try await eventually { executor.executedTypes.contains("replace.validate") }
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["replace.validate"])
        XCTAssertEqual(executor.begun, ["replace-validate-1"])
        XCTAssertEqual(executor.finished, ["replace-validate-1"])
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 5. Enable/disable & sort: stale result guard rejects old correlation

    func testReplaceRulePilotStaleResultGuardRejectsOldCorrelation() async throws {
        let executor = FakeReplaceRuleExecutor(outcomes: [
            .completed(coreType: "replace.apply"),
            .completed(coreType: "replace.apply"),
        ])
        let coordinator = makeCoordinator(executor: executor)

        // Start first apply (e.g. before a rule enable/disable or sort change)
        XCTAssertTrue(coordinator.applyRules(
            jsonPayload: replaceApplyPayload(text: "old text"),
            correlationId: "replace-apply-old-1"
        ))

        // Start second apply before the first completes — replacement
        // invalidates the old correlation, mirroring the enable/disable or
        // sort re-order semantics where the latest intent wins.
        XCTAssertTrue(coordinator.applyRules(
            jsonPayload: replaceApplyPayload(text: "new text"),
            correlationId: "replace-apply-new-1"
        ))

        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(
            executor.cancelled,
            ["replace-apply-old-1"],
            "Old correlation must be cancelled on replacement"
        )
        XCTAssertEqual(executor.executedTypes, ["replace.apply", "replace.apply"])
        XCTAssertEqual(
            executor.finished,
            ["replace-apply-new-1"],
            "Only the latest correlation finishes as success"
        )
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 6. Undo retains and replays only the Core-issued token

    func testPersistRetainsCoreIssuedTokenAndUndoConsumesIt() async throws {
        let executor = FakeReplaceRuleExecutor(outcomes: [
            .completed(coreType: "replace.persist", result: replacePersistResult()),
            .completed(coreType: "replace.undo", result: replaceUndoResult()),
        ])
        let coordinator = makeCoordinator(executor: executor)

        XCTAssertTrue(coordinator.createRule(
            jsonPayload: replaceCreatePayload(),
            correlationId: "replace-create-for-undo"
        ))
        try await eventually { coordinator.lastUndoToken != nil }

        XCTAssertEqual(coordinator.lastUndoToken, replaceUndoToken())
        XCTAssertTrue(coordinator.undoLastPersistedRule(correlationId: "replace-undo-1"))
        try await eventually { coordinator.activeCorrelationID == nil && coordinator.lastUndoToken == nil }

        XCTAssertEqual(executor.executedTypes, ["replace.persist", "replace.undo"])
        XCTAssertEqual(executor.finished, ["replace-create-for-undo", "replace-undo-1"])
        XCTAssertEqual(
            coordinator.operationState,
            .succeeded(coreType: "replace.undo", message: "已撤销上一次规则变更")
        )
        XCTAssertNil(coordinator.lastFailure)
    }

    func testActualExecutorRejectsPersistTokenThatDoesNotIdentifyCreatedRule() async throws {
        var invalidPersist = replacePersistResult()
        var invalidToken = replaceUndoToken()
        invalidToken["ruleId"] = .number(42)
        invalidPersist["undoToken"] = .object(invalidToken)
        let core = FakeReplaceRuleCoreCommands(
            persistResult: invalidPersist,
            undoResult: replaceUndoResult()
        )
        let coordinator = makeCoordinator(coreCommands: core)

        XCTAssertTrue(coordinator.createRule(
            jsonPayload: replaceCreatePayload(),
            correlationId: "replace-create-identity-mismatch"
        ))
        try await eventually { coordinator.lastFailure != nil }

        XCTAssertNil(coordinator.lastUndoToken)
        XCTAssertTrue(coordinator.lastFailure?.contains("REPLACE_RESULT_IDENTITY_MISMATCH") == true)
    }

    func testActualExecutorRejectsUndoResultForAnotherTokenAndRetainsIssuedToken() async throws {
        var mismatchedUndo = replaceUndoResult()
        mismatchedUndo["transactionId"] = .string("another-transaction")
        let core = FakeReplaceRuleCoreCommands(
            persistResult: replacePersistResult(),
            undoResult: mismatchedUndo
        )
        let coordinator = makeCoordinator(coreCommands: core)

        XCTAssertTrue(coordinator.createRule(
            jsonPayload: replaceCreatePayload(),
            correlationId: "replace-create-before-result-mismatch"
        ))
        try await eventually { coordinator.lastUndoToken != nil }
        XCTAssertTrue(coordinator.undoLastPersistedRule(correlationId: "replace-undo-result-mismatch"))
        try await eventually { coordinator.lastFailure != nil }

        XCTAssertEqual(core.undoPayloads, [["undoToken": .object(replaceUndoToken())]])
        XCTAssertEqual(coordinator.lastUndoToken, replaceUndoToken())
        XCTAssertTrue(coordinator.lastFailure?.contains("REPLACE_RESULT_IDENTITY_MISMATCH") == true)
    }

    func testContractUndoEventRejectsFixtureTokenThatDoesNotMatchRetainedCoreToken() async throws {
        let executor = FakeReplaceRuleExecutor(outcomes: [
            .completed(coreType: "replace.persist", result: replacePersistResult())
        ])
        let coordinator = makeCoordinator(executor: executor)
        XCTAssertTrue(coordinator.createRule(
            jsonPayload: replaceCreatePayload(),
            correlationId: "replace-create-before-mismatch"
        ))
        try await eventually { coordinator.lastUndoToken != nil }

        var mismatched = replaceUndoToken()
        mismatched["transactionId"] = .string("fixture-token")
        XCTAssertTrue(coordinator.handle(UiEvent(
            type: .reader_replace_undo,
            payload: ["undoToken": AnyCodable(ReaderUIJSONValue.object(mismatched))],
            correlationId: "replace-fixture-undo"
        )))

        XCTAssertEqual(executor.executedTypes, ["replace.persist"])
        XCTAssertEqual(coordinator.lastFailure, "REPLACE_UNDO_TOKEN_MISMATCH")
        XCTAssertEqual(coordinator.lastUndoToken, replaceUndoToken())
    }

    // MARK: - 7. Effect failure clears transaction fail-closed

    func testReplaceRulePilotEffectBoundaryFailureClearsTransaction() async throws {
        let executor = FakeReplaceRuleExecutor(outcomes: [
            .failed(coreType: "replace.apply", message: "CORE_REPLACE_APPLY_UNDO_FAILURE")
        ])
        let coordinator = makeCoordinator(executor: executor)

        XCTAssertTrue(coordinator.applyRules(
            jsonPayload: replaceApplyPayload(text: "undo text"),
            correlationId: "replace-apply-fail-1"
        ))

        try await eventually { coordinator.lastFailure != nil }
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["replace.apply"])
        XCTAssertEqual(executor.cancelled, ["replace-apply-fail-1"])
        XCTAssertTrue(executor.finished.isEmpty, "A failed effect must not close as success")
        XCTAssertEqual(coordinator.lastFailure, "CORE_REPLACE_APPLY_UNDO_FAILURE")
        XCTAssertNil(
            coordinator.activeCorrelationID,
            "Effect boundary failure must clear the active correlation"
        )
    }

    // MARK: - 8. Shadow mode returns false (rollback seam)

    func testReplaceRulePilotShadowModeReturnsFalse() {
        let coordinator = ReaderReplaceRulePilotCoordinator(
            configuration: ReaderReplaceRulePilotConfiguration(mode: .shadow),
            runtime: ReaderUIRuntime(),
            executor: FakeReplaceRuleExecutor()
        )

        XCTAssertFalse(coordinator.applyRules(
            payload: ["ruleIds": "rule-1"],
            correlationId: "replace-shadow-1"
        ))
        XCTAssertFalse(coordinator.createRule(
            payload: ["ruleId": "rule-1"],
            correlationId: "replace-shadow-2"
        ))
        XCTAssertFalse(coordinator.validateRule(
            payload: ["ruleId": "rule-1"],
            correlationId: "replace-shadow-3"
        ))
        XCTAssertNil(coordinator.activeCorrelationID)
        XCTAssertNil(coordinator.lastFailure, "Shadow mode must not produce a failure")
    }

    // MARK: - 9. Fail-closed when executor is missing in pilot mode

    func testReplaceRulePilotFailsClosedWhenExecutorMissing() {
        let coordinator = ReaderReplaceRulePilotCoordinator(
            configuration: ReaderReplaceRulePilotConfiguration(mode: .pilot),
            runtime: ReaderUIRuntime(),
            executor: nil
        )

        XCTAssertTrue(coordinator.applyRules(
            payload: ["ruleIds": "rule-1"],
            correlationId: "replace-no-exec-1"
        ), "Pilot mode must consume the event even when fail-closed")
        XCTAssertEqual(coordinator.lastFailure, "REPLACE_EXECUTOR_MISSING")
        XCTAssertNil(coordinator.activeCorrelationID)
    }

    // MARK: - Helpers

    private func makeCoordinator(executor: FakeReplaceRuleExecutor) -> ReaderReplaceRulePilotCoordinator {
        ReaderReplaceRulePilotCoordinator(
            configuration: ReaderReplaceRulePilotConfiguration(mode: .pilot),
            runtime: ReaderUIRuntime(),
            executor: executor
        )
    }

    private func makeCoordinator(
        coreCommands: FakeReplaceRuleCoreCommands
    ) -> ReaderReplaceRulePilotCoordinator {
        ReaderReplaceRulePilotCoordinator(
            configuration: ReaderReplaceRulePilotConfiguration(mode: .pilot),
            runtime: ReaderUIRuntime(),
            executor: ReaderReplaceRuleEffectExecutor(coreCommands: coreCommands)
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

    private func replaceApplyPayload(text: String) -> ReaderUIJSONPayload {
        [
            "text": .string(text),
            "bookName": .string("Book"),
            "bookOrigin": .string("source"),
            "target": .string("chapter"),
        ]
    }

    private func replaceCreatePayload() -> ReaderUIJSONPayload {
        [
            "operation": .string("create"),
            "params": .object([
                "id": .number(41),
                "name": .string("rename"),
                "pattern": .string("rain"),
                "replacement": .string("sun"),
                "isRegex": .bool(false),
                "scopeContent": .bool(true),
            ]),
        ]
    }

    private func replaceValidatePayload() -> ReaderUIJSONPayload {
        [
            "pattern": .string("(["),
            "isRegex": .bool(true),
            "scope": .array([.string("chapter"), .string("title")]),
        ]
    }

    private func replaceRuleResult() -> ReaderUIJSONPayload {
        [
            "id": .number(41),
            "name": .string("rename"),
            "pattern": .string("rain"),
            "replacement": .string("sun"),
            "scopeTitle": .bool(false),
            "scopeContent": .bool(true),
            "isEnabled": .bool(true),
            "isRegex": .bool(false),
            "timeoutMillisecond": .number(3_000),
            "order": .number(0),
        ]
    }

    private func replaceUndoToken() -> ReaderUIJSONPayload {
        [
            "schemaVersion": .number(1),
            "transactionId": .string("replace-create-transaction"),
            "revision": .string(String(repeating: "a", count: 64)),
            "operation": .string("create"),
            "ruleId": .number(41),
            "issuedAt": .number(1_900_000_000),
            "expiresAt": .number(1_900_000_300),
            "after": .object(replaceRuleResult()),
        ]
    }

    private func replacePersistResult() -> ReaderUIJSONResult {
        [
            "operation": .string("create"),
            "data": .object(["rule": .object(replaceRuleResult())]),
            "undoToken": .object(replaceUndoToken()),
        ]
    }

    private func replaceUndoResult() -> ReaderUIJSONResult {
        [
            "transactionId": .string("replace-create-transaction"),
            "revision": .string(String(repeating: "a", count: 64)),
            "operation": .string("create"),
            "ruleId": .number(41),
            "changed": .bool(true),
            "undoneAt": .number(1_900_000_010),
        ]
    }
}

@MainActor
private final class FakeReplaceRuleExecutor: ReaderReplaceRuleEffectExecuting {
    var begun: [String] = []
    var executedTypes: [String] = []
    var cancelled: [String] = []
    var finished: [String] = []
    private var outcomes: [ReaderReplaceRuleEffectOutcome]
    private var activeCorrelations: Set<String> = []

    init(outcomes: [ReaderReplaceRuleEffectOutcome] = []) {
        self.outcomes = outcomes
    }

    func begin(correlationID: String) {
        begun.append(correlationID)
        activeCorrelations.insert(correlationID)
    }

    func execute(_ effect: ReaderUIEffect) async -> ReaderReplaceRuleEffectOutcome {
        executedTypes.append(effect.type)
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
private final class FakeReplaceRuleCoreCommands: ReaderReplaceRuleCoreCommandExecuting {
    let persistResult: ReaderUIJSONResult
    let undoResult: ReaderUIJSONResult
    var undoPayloads: [ReaderUIJSONPayload] = []

    init(persistResult: ReaderUIJSONResult, undoResult: ReaderUIJSONResult) {
        self.persistResult = persistResult
        self.undoResult = undoResult
    }

    func executeApply(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        throw ReaderUIRuntimeFailure(code: "UNEXPECTED_TEST_CALL", message: "replace.apply")
    }

    func executePersist(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        persistResult
    }

    func executeValidate(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        throw ReaderUIRuntimeFailure(code: "UNEXPECTED_TEST_CALL", message: "replace.validate")
    }

    func executeUndo(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        undoPayloads.append(payload)
        return undoResult
    }
}
