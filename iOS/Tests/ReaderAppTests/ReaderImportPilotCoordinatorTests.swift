import XCTest
import ReaderUIContract
import ReaderUIRuntime
@testable import ReaderApp

/// H4-C parity tests for the import Pilot coordinator.
///
/// Each import event (`import.start`, `import.apply`, `import.cancel`) is an
/// independent `emitEffects` action that must emit exactly one Core effect
/// (`import.parse`, `import.persist`, `import.rollback` respectively). The
/// coordinator enforces the effect boundary, stale result guard, and
/// fail-closed semantics.
@MainActor
final class ReaderImportPilotCoordinatorTests: XCTestCase {

    // MARK: - 1. Live configuration remains Shadow

    func testImportLiveConfigurationRemainsShadowWithoutProductionCohort() {
        XCTAssertEqual(ReaderImportPilotConfiguration.live.mode, .shadow)
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "import.start"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "import.apply"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "import.cancel"),
            .shadow
        )
        XCTAssertNil(
            ReaderUIRuntimeShadowConfiguration.live.cohorts
                .first { $0.id == "import-pilot" }
        )
    }

    // MARK: - 2. import.start dispatches import.parse Core effect

    func testImportStartPilotDispatchesParseEffect() async throws {
        let executor = FakeImportExecutor(outcomes: [.completed(coreType: "import.parse")])
        let coordinator = makeCoordinator(executor: executor)

        XCTAssertTrue(coordinator.beginImport(
            jsonPayload: importStartPayload(subscriptionID: "feed-a"),
            correlationId: "import-start-1"
        ))

        try await eventually { coordinator.activeCorrelationID == "import-start-1" || executor.executedTypes.contains("import.parse") }
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["import.parse"])
        XCTAssertEqual(executor.begun, ["import-start-1"])
        XCTAssertTrue(executor.cancelled.isEmpty)
        XCTAssertEqual(executor.finished, ["import-start-1"])
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 3. import.apply dispatches import.persist Core effect

    func testImportApplyPilotDispatchesPersistEffect() async throws {
        let executor = FakeImportExecutor(outcomes: [.completed(coreType: "import.persist")])
        let coordinator = makeCoordinator(executor: executor)

        XCTAssertTrue(coordinator.applyImport(
            jsonPayload: importApplyPayload(subscriptionID: "feed-a"),
            correlationId: "import-apply-1"
        ))

        try await eventually { executor.executedTypes.contains("import.persist") }
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["import.persist"])
        XCTAssertEqual(executor.begun, ["import-apply-1"])
        XCTAssertEqual(executor.finished, ["import-apply-1"])
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 4. import.cancel dispatches import.rollback Core effect

    func testImportCancelPilotDispatchesRollbackEffect() async throws {
        let executor = FakeImportExecutor(outcomes: [.completed(coreType: "import.rollback")])
        let coordinator = makeCoordinator(executor: executor)

        XCTAssertTrue(coordinator.cancelImport(
            jsonPayload: importCancelPayload(subscriptionID: "feed-a"),
            correlationId: "import-cancel-1"
        ))

        try await eventually { executor.executedTypes.contains("import.rollback") }

        XCTAssertEqual(executor.executedTypes, ["import.rollback"])
        XCTAssertEqual(executor.begun, ["import-cancel-1"])
        XCTAssertEqual(executor.finished, ["import-cancel-1"])
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 5. Effect boundary failure clears transaction

    func testImportPilotEffectBoundaryFailureClearsTransaction() async throws {
        let executor = FakeImportExecutor(outcomes: [
            .failed(coreType: "import.parse", message: "CORE_IMPORT_PARSE_NETWORK_FAILURE")
        ])
        let coordinator = makeCoordinator(executor: executor)

        XCTAssertTrue(coordinator.beginImport(
            jsonPayload: importStartPayload(subscriptionID: "feed-broken"),
            correlationId: "import-fail-1"
        ))

        try await eventually { coordinator.lastFailure != nil }
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["import.parse"])
        XCTAssertEqual(executor.cancelled, ["import-fail-1"])
        XCTAssertTrue(executor.finished.isEmpty, "A failed effect must not close as success")
        XCTAssertEqual(coordinator.lastFailure, "CORE_IMPORT_PARSE_NETWORK_FAILURE")
        XCTAssertNil(coordinator.activeCorrelationID, "Effect boundary failure must clear the active correlation")
    }

    // MARK: - 6. Stale result guard rejects old correlation

    func testImportPilotStaleResultGuardRejectsOldCorrelation() async throws {
        let executor = FakeImportExecutor(outcomes: [
            .completed(coreType: "import.parse"),
            .completed(coreType: "import.parse"),
        ])
        let coordinator = makeCoordinator(executor: executor)

        // Start first import
        XCTAssertTrue(coordinator.beginImport(
            jsonPayload: importStartPayload(subscriptionID: "feed-old"),
            correlationId: "import-old-1"
        ))

        // Start second import before first completes — replacement invalidates old correlation
        XCTAssertTrue(coordinator.beginImport(
            jsonPayload: importStartPayload(subscriptionID: "feed-new"),
            correlationId: "import-new-1"
        ))

        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.cancelled, ["import-old-1"], "Old correlation must be cancelled on replacement")
        XCTAssertEqual(executor.executedTypes, ["import.parse", "import.parse"])
        XCTAssertEqual(executor.finished, ["import-new-1"], "Only the latest correlation finishes as success")
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 7. Canonical W1 JSON survives the Core boundary

    func testConcreteExecutorPreservesParsePersistAndRollbackJSONResults() async throws {
        let commands = NestedImportCoreCommands()
        let executor = ReaderImportEffectExecutor(coreCommands: commands)
        let runtime = ReaderUIRuntime()
        let cases: [(String, ReaderUIJSONPayload, String)] = [
            ("import.start", importStartPayload(subscriptionID: "feed-a"), "import.parse"),
            ("import.apply", importApplyPayload(subscriptionID: "feed-a"), "import.persist"),
            ("import.cancel", importCancelPayload(subscriptionID: "feed-a"), "import.rollback"),
        ]
        var projected: [String: ReaderUIJSONResult] = [:]

        for (index, item) in cases.enumerated() {
            let correlationID = "import-json-\(index)"
            let transition = try runtime.dispatch(
                event: item.0,
                jsonPayload: item.1,
                correlationId: correlationID
            )
            let effect = try XCTUnwrap(transition.effects.first)
            XCTAssertEqual(effect.type, item.2)
            XCTAssertFalse(effect.legacyPayloadIsComplete, "Nested canonical payload must not be treated as a scalar wire payload")
            executor.begin(correlationID: correlationID)
            guard case .completedJSON(let coreType, let result) = await executor.execute(effect) else {
                return XCTFail("Expected a typed JSON result for \(item.2)")
            }
            XCTAssertEqual(coreType, item.2)
            XCTAssertNil(result["legacyExtra"], "Unknown Core fields must not escape the typed boundary")
            projected[item.2] = result
            executor.finish(correlationID: correlationID)
        }

        XCTAssertEqual(projected["import.parse"]?["kind"], .string("rssSource"))
        guard case .object(let preview)? = projected["import.parse"]?["preview"] else {
            return XCTFail("Parse preview must remain a nested object")
        }
        XCTAssertEqual(preview["subscriptionId"], .string("feed-a"))
        XCTAssertNil(preview["legacyNested"])

        guard case .object(let rollbackToken)? = projected["import.persist"]?["rollbackToken"],
              case .object(let token)? = rollbackToken["token"],
              case .object(let journal)? = token["journal"] else {
            return XCTFail("Persist result must preserve the canonical rollback token")
        }
        XCTAssertEqual(rollbackToken["kind"], .string("rssSource"))
        XCTAssertEqual(journal["transactionId"], .string("tx-feed-a"))

        guard case .object(let rollbackData)? = projected["import.rollback"]?["data"] else {
            return XCTFail("Rollback result must preserve its nested data")
        }
        XCTAssertEqual(rollbackData["restored"], .bool(true))
        XCTAssertEqual(rollbackData["subscriptionId"], .string("feed-a"))
    }

    // MARK: - Helpers

    private func makeCoordinator(executor: FakeImportExecutor) -> ReaderImportPilotCoordinator {
        ReaderImportPilotCoordinator(
            configuration: ReaderImportPilotConfiguration(mode: .pilot),
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

    private func importStartPayload(subscriptionID: String) -> ReaderUIJSONPayload {
        [
            "kind": .string("rssSource"),
            "input": .object([
                "subscriptionId": .string(subscriptionID),
                "feedUrl": .string("https://feeds.test/\(subscriptionID).xml"),
                "title": .string("Feed \(subscriptionID)"),
                "siteUrl": .null,
                "enabled": .bool(true),
            ]),
        ]
    }

    private func importApplyPayload(subscriptionID: String) -> ReaderUIJSONPayload {
        [
            "transactionId": .string("tx-\(subscriptionID)"),
            "parsed": .object([
                "kind": .string("rssSource"),
                "preview": .object([
                    "subscriptionId": .string(subscriptionID),
                    "feedUrl": .string("https://feeds.test/\(subscriptionID).xml"),
                    "title": .string("Feed \(subscriptionID)"),
                    "siteUrl": .null,
                    "enabled": .bool(true),
                ]),
            ]),
        ]
    }

    private func importCancelPayload(subscriptionID: String) -> ReaderUIJSONPayload {
        let transactionID = "tx-\(subscriptionID)"
        return [
            "rollbackToken": .object([
                "kind": .string("rssSource"),
                "token": .object([
                    "transactionId": .string(transactionID),
                    "journal": .object([
                        "transactionId": .string(transactionID),
                        "subscriptionId": .string(subscriptionID),
                        "previousSubscription": .null,
                        "previousEntryCache": .null,
                        "previousMarker": .null,
                        "committedSubscription": .object([
                            "subscriptionId": .string(subscriptionID),
                            "feedUrl": .string("https://feeds.test/\(subscriptionID).xml"),
                            "title": .string("Feed \(subscriptionID)"),
                            "siteUrl": .null,
                            "enabled": .bool(true),
                            "unreadCount": .number(0),
                            "lastFetchAt": .null,
                            "lastEntryId": .null,
                        ]),
                        "committedEntryCache": .object([
                            "key": .string("reader.rss.subscription.v1.entries:\(subscriptionID)"),
                            "payload": .string("{}"),
                        ]),
                        "committedMarker": .object([
                            "key": .string("reader.ui.import.v1.marker:rssSource:\(subscriptionID)"),
                            "payload": .string("marker"),
                        ]),
                    ]),
                ]),
            ]),
        ]
    }
}

@MainActor
private final class FakeImportExecutor: ReaderImportEffectExecuting {
    var begun: [String] = []
    var executedTypes: [String] = []
    var cancelled: [String] = []
    var finished: [String] = []
    private var outcomes: [ReaderImportEffectOutcome]
    private var activeCorrelations: Set<String> = []

    init(outcomes: [ReaderImportEffectOutcome] = []) {
        self.outcomes = outcomes
    }

    func begin(correlationID: String) {
        begun.append(correlationID)
        activeCorrelations.insert(correlationID)
    }

    func execute(_ effect: ReaderUIEffect) async -> ReaderImportEffectOutcome {
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
private final class NestedImportCoreCommands: ReaderImportCoreCommandExecuting {
    func executeParse(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        guard case .object(let input)? = payload["input"],
              input["subscriptionId"] == .string("feed-a") else {
            throw ReaderUIRuntimeFailure(code: "TEST_PAYLOAD_LOSS", message: "Nested import input was not preserved")
        }
        return [
            "kind": .string("rssSource"),
            "preview": .object([
                "subscriptionId": .string("feed-a"),
                "feedUrl": .string("https://feeds.test/feed-a.xml"),
                "title": .string("Feed feed-a"),
                "siteUrl": .null,
                "enabled": .bool(true),
                "legacyNested": .string("strip-me"),
            ]),
            "legacyExtra": .string("strip-me"),
        ]
    }

    func executePersist(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        guard case .object(let parsed)? = payload["parsed"],
              case .object(let preview)? = parsed["preview"],
              preview["subscriptionId"] == .string("feed-a") else {
            throw ReaderUIRuntimeFailure(code: "TEST_PAYLOAD_LOSS", message: "Nested parsed data was not preserved")
        }
        return [
            "persisted": .object([
                "kind": .string("rssSource"),
                "data": .object([
                    "subscriptionId": .string("feed-a"),
                    "feedUrl": .string("https://feeds.test/feed-a.xml"),
                    "title": .string("Feed feed-a"),
                    "enabled": .bool(true),
                ]),
            ]),
            "rollbackToken": .object([
                "kind": .string("rssSource"),
                "token": .object([
                    "transactionId": .string("tx-feed-a"),
                    "journal": .object([
                        "transactionId": .string("tx-feed-a"),
                        "subscriptionId": .string("feed-a"),
                        "previousSubscription": .null,
                        "previousEntryCache": .null,
                        "previousMarker": .null,
                        "committedSubscription": .object([
                            "subscriptionId": .string("feed-a"),
                            "feedUrl": .string("https://feeds.test/feed-a.xml"),
                            "title": .string("Feed feed-a"),
                            "enabled": .bool(true),
                            "unreadCount": .number(0),
                        ]),
                        "committedEntryCache": .object([
                            "key": .string("entries"),
                            "payload": .string("{}"),
                        ]),
                        "committedMarker": .object([
                            "key": .string("marker"),
                            "payload": .string("hash"),
                        ]),
                    ]),
                ]),
            ]),
            "legacyExtra": .string("strip-me"),
        ]
    }

    func executeRollback(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        guard case .object(let rollbackToken)? = payload["rollbackToken"],
              case .object(let token)? = rollbackToken["token"],
              token["transactionId"] == .string("tx-feed-a") else {
            throw ReaderUIRuntimeFailure(code: "TEST_PAYLOAD_LOSS", message: "Rollback token was not preserved")
        }
        return [
            "kind": .string("rssSource"),
            "data": .object([
                "subscriptionId": .string("feed-a"),
                "restored": .bool(true),
            ]),
            "legacyExtra": .string("strip-me"),
        ]
    }
}
