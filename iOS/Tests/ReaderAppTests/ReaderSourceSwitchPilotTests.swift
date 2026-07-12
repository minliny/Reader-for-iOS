import XCTest
import ReaderUIContract
import ReaderUIRuntime
@testable import ReaderApp

/// H4-D parity tests for the source switch Pilot coordinator.
///
/// The source switch pilot has two cohorts:
/// - overlay cohort (effectPolicy: "none"): source.switch.open,
///   source.switch.cancel, reader.sourceSwitch.open, reader.sourceSwitch.close
/// - effect cohort (effectPolicy: "exactly-once"): source.switch.confirm,
///   source.switch.rollback
///
/// Each effectful event (`source.switch.confirm`, `source.switch.rollback`) is
/// an independent `emitEffects` action that must emit exactly one Core effect
/// (`source.switch.commit`, `source.switch.rollback` respectively). The
/// coordinator enforces the effect boundary, stale result guard, and
/// fail-closed semantics with old-source rollback.
@MainActor
final class ReaderSourceSwitchPilotTests: XCTestCase {

    // MARK: - 1. Live configuration remains Shadow

    func testSourceSwitchLiveConfigurationRemainsShadowWithoutProductionCohorts() {
        XCTAssertEqual(ReaderSourceSwitchPilotConfiguration.live.mode, .shadow)
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "source.switch.open"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "source.switch.cancel"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "source.switch.confirm"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "source.switch.rollback"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "reader.sourceSwitch.open"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "reader.sourceSwitch.close"),
            .shadow
        )
        XCTAssertNil(
            ReaderUIRuntimeShadowConfiguration.live.cohorts
                .first { $0.id == "source-switch-overlay-pilot" }
        )
        XCTAssertNil(
            ReaderUIRuntimeShadowConfiguration.live.cohorts
                .first { $0.id == "source-switch-effect-pilot" }
        )
    }

    // MARK: - 2. source.switch.confirm dispatches source.switch.commit Core effect

    func testSourceSwitchConfirmPilotDispatchesCommitEffect() async throws {
        let executor = FakeSourceSwitchExecutor(outcomes: [.completed(coreType: "source.switch.commit")])
        let coordinator = makeCoordinator(executor: executor)

        XCTAssertTrue(coordinator.confirmSourceSwitch(
            jsonPayload: sourceSwitchConfirmPayload(targetSourceID: "source-new-1"),
            correlationId: "source-switch-confirm-1"
        ))

        try await eventually { executor.executedTypes.contains("source.switch.commit") }
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["source.switch.commit"])
        XCTAssertEqual(executor.begun, ["source-switch-confirm-1"])
        XCTAssertTrue(executor.cancelled.isEmpty)
        XCTAssertEqual(executor.finished, ["source-switch-confirm-1"])
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 3. source.switch.rollback dispatches source.switch.rollback Core effect

    func testSourceSwitchRollbackPilotDispatchesRollbackEffect() async throws {
        let executor = FakeSourceSwitchExecutor(outcomes: [.completed(coreType: "source.switch.rollback")])
        let coordinator = makeCoordinator(executor: executor)

        XCTAssertTrue(coordinator.rollbackSourceSwitch(
            jsonPayload: sourceSwitchRollbackPayload(),
            correlationId: "source-switch-rollback-1"
        ))

        try await eventually { executor.executedTypes.contains("source.switch.rollback") }

        XCTAssertEqual(executor.executedTypes, ["source.switch.rollback"])
        XCTAssertEqual(executor.begun, ["source-switch-rollback-1"])
        XCTAssertEqual(executor.finished, ["source-switch-rollback-1"])
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 4. Stale result guard rejects old correlation

    func testSourceSwitchPilotStaleResultGuardRejectsOldCorrelation() async throws {
        let executor = FakeSourceSwitchExecutor(outcomes: [
            .completed(coreType: "source.switch.commit"),
            .completed(coreType: "source.switch.commit"),
        ])
        let coordinator = makeCoordinator(executor: executor)

        // Start first confirm
        XCTAssertTrue(coordinator.confirmSourceSwitch(
            jsonPayload: sourceSwitchConfirmPayload(targetSourceID: "source-a"),
            correlationId: "source-switch-old-1"
        ))

        // Start second confirm before first completes — replacement invalidates old correlation
        XCTAssertTrue(coordinator.confirmSourceSwitch(
            jsonPayload: sourceSwitchConfirmPayload(targetSourceID: "source-b"),
            correlationId: "source-switch-new-1"
        ))

        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.cancelled, ["source-switch-old-1"], "Old correlation must be cancelled on replacement")
        XCTAssertEqual(executor.executedTypes, ["source.switch.commit", "source.switch.commit"])
        XCTAssertEqual(executor.finished, ["source-switch-new-1"], "Only the latest correlation finishes as success")
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 5. Rollback restores old source on failure

    func testSourceSwitchPilotRollbackRestoresOldSource() async throws {
        let executor = FakeSourceSwitchExecutor(outcomes: [
            .failed(coreType: "source.switch.commit", message: "CORE_SOURCE_SWITCH_COMMIT_NETWORK_FAILURE")
        ])
        let coordinator = makeCoordinator(executor: executor)

        // Open source switch with a previous source id captured
        XCTAssertTrue(coordinator.openSourceSwitch(
            jsonPayload: ["bookId": .string("book-old")],
            correlationId: "source-switch-open-1"
        ))

        // Confirm fails — fail-closed must restore the old source
        XCTAssertTrue(coordinator.confirmSourceSwitch(
            jsonPayload: sourceSwitchConfirmPayload(targetSourceID: "source-new-1"),
            correlationId: "source-switch-confirm-fail-1"
        ))

        try await eventually { coordinator.lastFailure != nil }
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["source.switch.commit"])
        XCTAssertEqual(executor.cancelled, ["source-switch-confirm-fail-1"])
        XCTAssertTrue(executor.finished.isEmpty, "A failed effect must not close as success")
        XCTAssertEqual(coordinator.lastFailure, "CORE_SOURCE_SWITCH_COMMIT_NETWORK_FAILURE")
        XCTAssertEqual(
            coordinator.restoredSourceId,
            "source-old-1",
            "Fail-closed must restore the previous source id"
        )
        XCTAssertNil(coordinator.activeCorrelationID, "Effect failure must clear the active correlation")
    }

    // MARK: - 6. Overlay pilot events have no Core effects

    func testSourceSwitchOverlayPilotHasNoCoreEffects() {
        let coordinator = makeCoordinator(executor: nil)

        // source.switch.open is a pushRoute action with no Core effects
        XCTAssertTrue(coordinator.openSourceSwitch(
            jsonPayload: ["bookId": .string("bk-001")],
            correlationId: "source-switch-overlay-open-1"
        ))
        XCTAssertNil(coordinator.lastFailure, "Overlay open must not produce a failure")

        // source.switch.cancel is a popRoute action with no Core effects
        XCTAssertTrue(coordinator.cancelSourceSwitch(
            correlationId: "source-switch-overlay-cancel-1"
        ))
        XCTAssertNil(coordinator.lastFailure, "Overlay cancel must not produce a failure")

        XCTAssertEqual(coordinator.configuration.mode, .pilot)
        XCTAssertEqual(ReaderSourceSwitchPilotConfiguration.live.mode, .shadow)
    }

    // MARK: - Helpers

    private func makeCoordinator(executor: FakeSourceSwitchExecutor?) -> ReaderSourceSwitchPilotCoordinator {
        ReaderSourceSwitchPilotCoordinator(
            configuration: ReaderSourceSwitchPilotConfiguration(mode: .pilot),
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

    private func sourceSwitchConfirmPayload(targetSourceID: String) -> ReaderUIJSONPayload {
        [
            "from": .object([
                "sourceId": .string("source-old-1"),
                "bookId": .string("book-old"),
            ]),
            "target": .object([
                "sourceId": .string(targetSourceID),
                "bookId": .string("book-new"),
                "title": .string("New source"),
                "author": .string("Author"),
                "coverUrl": .null,
            ]),
            "newToc": .array([
                .object([
                    "chapterId": .string("c1"),
                    "chapterTitle": .string("Chapter 1"),
                    "chapterUrl": .string("https://example.test/c1"),
                    "order": .number(0),
                ]),
            ]),
            "currentChapterTitle": .string("Chapter 1"),
            "currentChapterIndex": .number(0),
            "updatedAt": .number(300),
        ]
    }

    private func sourceSwitchRollbackPayload() -> ReaderUIJSONPayload {
        [
            "rollbackToken": .object([
                "oldBook": .object([
                    "bookId": .string("book-old"),
                    "sourceId": .string("source-old-1"),
                    "title": .string("Old"),
                    "addedAt": .number(10),
                ]),
                "committedBook": .object([
                    "bookId": .string("book-new"),
                    "sourceId": .string("source-new-1"),
                    "title": .string("New"),
                    "addedAt": .number(10),
                ]),
                "oldProgress": .null,
                "oldProgressHistory": .array([]),
                "committedProgressHistory": .array([]),
                "replacedTargetBook": .null,
            ]),
        ]
    }
}

@MainActor
private final class FakeSourceSwitchExecutor: ReaderSourceSwitchEffectExecuting {
    var begun: [String] = []
    var executedTypes: [String] = []
    var cancelled: [String] = []
    var finished: [String] = []
    private var outcomes: [ReaderSourceSwitchEffectOutcome]
    private var activeCorrelations: Set<String> = []

    init(outcomes: [ReaderSourceSwitchEffectOutcome] = []) {
        self.outcomes = outcomes
    }

    func begin(correlationID: String) {
        begun.append(correlationID)
        activeCorrelations.insert(correlationID)
    }

    func execute(_ effect: ReaderUIEffect) async -> ReaderSourceSwitchEffectOutcome {
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
