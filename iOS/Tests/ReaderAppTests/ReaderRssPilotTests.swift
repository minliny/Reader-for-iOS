import XCTest
import ReaderUIContract
import ReaderUIRuntime
@testable import ReaderApp

/// H4-G parity tests for the RSS Pilot coordinator.
///
/// Each RSS event is an independent `emitEffects` action that must emit exactly
/// one Core effect. The coordinator enforces the effect boundary, stale result
/// guard, and fail-closed semantics.
///
/// Parity coverage maps the RSS functional surface to the canonical coordinator
/// dispatch:
/// - `rss.refresh` → `rss.feed.refresh` (staleResultGuard=true)
/// - `rss.subscription.add` → `rss.subscription.persist` (rollback=true)
/// - `rss.subscription.delete` → `rss.subscription.remove` (rollback=true)
/// - `rss.subscription.edit` → `rss.subscription.persist`
/// - `rss.entry.open` → `rss.entry.read`
/// - `rss.favorite.add` → `rss.favorite.persist`
/// - `rss.favorite.remove` → `rss.favorite.remove`
/// - fail-closed: effect executor failure tears down the transaction without
///   leaving an orphan ledger entry.
@MainActor
final class ReaderRssPilotTests: XCTestCase {

    // MARK: - 1. Live configuration remains Shadow

    func testRssLiveConfigurationRemainsShadowWithoutProductionCohort() {
        XCTAssertEqual(ReaderRssPilotConfiguration.live.mode, .shadow)
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "rss.refresh"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "rss.subscription.add"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "rss.subscription.delete"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "rss.subscription.edit"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "rss.entry.open"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "rss.favorite.add"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "rss.favorite.remove"),
            .shadow
        )
        XCTAssertNil(
            ReaderUIRuntimeShadowConfiguration.live.cohorts
                .first { $0.id == "rss-pilot" }
        )
    }

    // MARK: - 2. rss.refresh dispatches rss.feed.refresh Core effect

    func testRefreshFeedDispatchesFeedRefreshEffect() async throws {
        let executor = FakeRssExecutor(outcomes: [.completed(coreType: "rss.feed.refresh")])
        let coordinator = makeCoordinator(executor: executor)

        let outcome = coordinator.refreshFeed(
            jsonPayload: rssRefreshPayload(),
            correlationId: "rss-refresh-1"
        )

        XCTAssertEqual(outcome, .dispatched)
        try await eventually { executor.executedTypes.contains("rss.feed.refresh") }
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["rss.feed.refresh"])
        XCTAssertEqual(executor.begun, ["rss-refresh-1"])
        XCTAssertTrue(executor.cancelled.isEmpty)
        XCTAssertEqual(executor.finished, ["rss-refresh-1"])
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 3. rss.subscription.add dispatches rss.subscription.persist + rollback path

    func testAddSubscriptionDispatchesPersistAndRollsBackOnFailure() async throws {
        // Success path
        let successExecutor = FakeRssExecutor(outcomes: [.completed(coreType: "rss.subscription.persist")])
        let successCoordinator = makeCoordinator(executor: successExecutor)

        let successOutcome = successCoordinator.addSubscription(
            jsonPayload: rssSubscriptionPayload(operation: "create"),
            correlationId: "rss-sub-add-1"
        )

        XCTAssertEqual(successOutcome, .dispatched)
        try await eventually { successCoordinator.activeCorrelationID == nil }
        XCTAssertEqual(successExecutor.executedTypes, ["rss.subscription.persist"])
        XCTAssertNil(successCoordinator.lastFailure)

        // Rollback path: executor failure triggers fail-closed teardown
        let failExecutor = FakeRssExecutor(outcomes: [
            .failed(coreType: "rss.subscription.persist", message: "CORE_RSS_SUBSCRIPTION_PERSIST_FAILURE")
        ])
        let failCoordinator = makeCoordinator(executor: failExecutor)

        let failOutcome = failCoordinator.addSubscription(
            jsonPayload: rssSubscriptionPayload(operation: "create"),
            correlationId: "rss-sub-add-fail-1"
        )

        XCTAssertEqual(failOutcome, .dispatched, "Dispatch succeeds even though the effect will fail async")
        try await eventually { failCoordinator.lastFailure != nil }
        try await eventually { failCoordinator.activeCorrelationID == nil }

        XCTAssertEqual(failExecutor.executedTypes, ["rss.subscription.persist"])
        XCTAssertEqual(failExecutor.cancelled, ["rss-sub-add-fail-1"])
        XCTAssertTrue(failExecutor.finished.isEmpty, "A failed effect must not close as success")
        XCTAssertEqual(failCoordinator.lastFailure, "CORE_RSS_SUBSCRIPTION_PERSIST_FAILURE")
        XCTAssertEqual(failCoordinator.lastOutcome, .failedClosed)
        XCTAssertNil(
            failCoordinator.activeCorrelationID,
            "Rollback must clear the active correlation — no orphan ledger"
        )
    }

    // MARK: - 4. rss.subscription.delete dispatches rss.subscription.remove + rollback path

    func testDeleteSubscriptionDispatchesRemoveAndRollsBackOnFailure() async throws {
        // Success path
        let successExecutor = FakeRssExecutor(outcomes: [.completed(coreType: "rss.subscription.remove")])
        let successCoordinator = makeCoordinator(executor: successExecutor)

        let successOutcome = successCoordinator.deleteSubscription(
            jsonPayload: rssDeletePayload(),
            correlationId: "rss-sub-del-1"
        )

        XCTAssertEqual(successOutcome, .dispatched)
        try await eventually { successCoordinator.activeCorrelationID == nil }
        XCTAssertEqual(successExecutor.executedTypes, ["rss.subscription.remove"])
        XCTAssertNil(successCoordinator.lastFailure)

        // Rollback path: executor failure triggers fail-closed teardown
        let failExecutor = FakeRssExecutor(outcomes: [
            .failed(coreType: "rss.subscription.remove", message: "CORE_RSS_SUBSCRIPTION_REMOVE_FAILURE")
        ])
        let failCoordinator = makeCoordinator(executor: failExecutor)

        let failOutcome = failCoordinator.deleteSubscription(
            jsonPayload: rssDeletePayload(),
            correlationId: "rss-sub-del-fail-1"
        )

        XCTAssertEqual(failOutcome, .dispatched)
        try await eventually { failCoordinator.lastFailure != nil }
        try await eventually { failCoordinator.activeCorrelationID == nil }

        XCTAssertEqual(failExecutor.cancelled, ["rss-sub-del-fail-1"])
        XCTAssertTrue(failExecutor.finished.isEmpty)
        XCTAssertEqual(failCoordinator.lastFailure, "CORE_RSS_SUBSCRIPTION_REMOVE_FAILURE")
        XCTAssertEqual(failCoordinator.lastOutcome, .failedClosed)
        XCTAssertNil(failCoordinator.activeCorrelationID)
    }

    // MARK: - 5. rss.subscription.edit dispatches rss.subscription.persist

    func testEditSubscriptionDispatchesPersistEffect() async throws {
        let executor = FakeRssExecutor(outcomes: [.completed(coreType: "rss.subscription.persist")])
        let coordinator = makeCoordinator(executor: executor)

        let outcome = coordinator.editSubscription(
            jsonPayload: rssSubscriptionPayload(operation: "update"),
            correlationId: "rss-sub-edit-1"
        )

        XCTAssertEqual(outcome, .dispatched)
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["rss.subscription.persist"])
        XCTAssertEqual(executor.finished, ["rss-sub-edit-1"])
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 6. rss.entry.open dispatches rss.entry.read

    func testOpenEntryDispatchesEntryReadEffect() async throws {
        let executor = FakeRssExecutor(outcomes: [.completed(coreType: "rss.entry.read")])
        let coordinator = makeCoordinator(executor: executor)

        let outcome = coordinator.openEntry(
            jsonPayload: rssEntryPayload(),
            correlationId: "rss-entry-open-1"
        )

        XCTAssertEqual(outcome, .dispatched)
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["rss.entry.read"])
        XCTAssertEqual(executor.finished, ["rss-entry-open-1"])
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 7. rss.favorite.add dispatches rss.favorite.persist

    func testAddFavoriteDispatchesFavoritePersistEffect() async throws {
        let executor = FakeRssExecutor(outcomes: [.completed(coreType: "rss.favorite.persist")])
        let coordinator = makeCoordinator(executor: executor)

        let outcome = coordinator.addFavorite(
            jsonPayload: rssFavoriteAddPayload(),
            correlationId: "rss-fav-add-1"
        )

        XCTAssertEqual(outcome, .dispatched)
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["rss.favorite.persist"])
        XCTAssertEqual(executor.finished, ["rss-fav-add-1"])
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 8. rss.favorite.remove dispatches rss.favorite.remove

    func testRemoveFavoriteDispatchesFavoriteRemoveEffect() async throws {
        let executor = FakeRssExecutor(outcomes: [.completed(coreType: "rss.favorite.remove")])
        let coordinator = makeCoordinator(executor: executor)

        let outcome = coordinator.removeFavorite(
            jsonPayload: rssFavoriteRemovePayload(),
            correlationId: "rss-fav-rm-1"
        )

        XCTAssertEqual(outcome, .dispatched)
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["rss.favorite.remove"])
        XCTAssertEqual(executor.finished, ["rss-fav-rm-1"])
        XCTAssertNil(coordinator.lastFailure)
    }

    // MARK: - 9. Fail-closed: effect executor failure returns .failedClosed, no orphan ledger

    func testFailClosedWhenEffectExecutorThrowsNoOrphanLedger() async throws {
        let executor = FakeRssExecutor(outcomes: [
            .failed(coreType: "rss.feed.refresh", message: "CORE_RSS_FEED_REFRESH_NETWORK_FAILURE")
        ])
        let coordinator = makeCoordinator(executor: executor)

        let outcome = coordinator.refreshFeed(
            jsonPayload: rssRefreshPayload(),
            correlationId: "rss-refresh-fail-1"
        )

        // Dispatch itself succeeds; the failure is observed async
        XCTAssertEqual(outcome, .dispatched)
        try await eventually { coordinator.lastFailure != nil }
        try await eventually { coordinator.activeCorrelationID == nil }

        XCTAssertEqual(executor.executedTypes, ["rss.feed.refresh"])
        XCTAssertEqual(executor.cancelled, ["rss-refresh-fail-1"])
        XCTAssertTrue(executor.finished.isEmpty, "Failed effect must not close as success")
        XCTAssertEqual(coordinator.lastFailure, "CORE_RSS_FEED_REFRESH_NETWORK_FAILURE")
        XCTAssertEqual(coordinator.lastOutcome, .failedClosed)
        XCTAssertNil(
            coordinator.activeCorrelationID,
            "Fail-closed must clear active correlation — no orphan ledger"
        )
    }

    // MARK: - 10. Shadow mode returns .shadow (rollback seam)

    func testRssPilotShadowModeReturnsShadow() {
        let coordinator = ReaderRssPilotCoordinator(
            configuration: ReaderRssPilotConfiguration(mode: .shadow),
            runtime: ReaderUIRuntime(),
            executor: FakeRssExecutor()
        )

        XCTAssertEqual(coordinator.refreshFeed(payload: [:], correlationId: "shadow-1"), .shadow)
        XCTAssertEqual(coordinator.addSubscription(payload: [:], correlationId: "shadow-2"), .shadow)
        XCTAssertEqual(coordinator.deleteSubscription(payload: [:], correlationId: "shadow-3"), .shadow)
        XCTAssertEqual(coordinator.editSubscription(payload: [:], correlationId: "shadow-4"), .shadow)
        XCTAssertEqual(coordinator.openEntry(payload: [:], correlationId: "shadow-5"), .shadow)
        XCTAssertEqual(coordinator.addFavorite(payload: [:], correlationId: "shadow-6"), .shadow)
        XCTAssertEqual(coordinator.removeFavorite(payload: [:], correlationId: "shadow-7"), .shadow)
        XCTAssertNil(coordinator.activeCorrelationID)
        XCTAssertNil(coordinator.lastFailure, "Shadow mode must not produce a failure")
    }

    // MARK: - 11. Fail-closed when executor is missing in pilot mode

    func testRssPilotFailsClosedWhenExecutorMissing() {
        let coordinator = ReaderRssPilotCoordinator(
            configuration: ReaderRssPilotConfiguration(mode: .pilot),
            runtime: ReaderUIRuntime(),
            executor: nil
        )

        XCTAssertEqual(
            coordinator.refreshFeed(payload: [:], correlationId: "rss-no-exec-1"),
            .failedClosed,
            "Pilot mode must return .failedClosed when executor is missing"
        )
        XCTAssertEqual(coordinator.lastFailure, "RSS_EXECUTOR_MISSING")
        XCTAssertEqual(coordinator.lastOutcome, .failedClosed)
        XCTAssertNil(coordinator.activeCorrelationID, "No orphan ledger when executor is missing")
    }

    // MARK: - Helpers

    private func makeCoordinator(executor: FakeRssExecutor) -> ReaderRssPilotCoordinator {
        ReaderRssPilotCoordinator(
            configuration: ReaderRssPilotConfiguration(mode: .pilot),
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

    private func rssRefreshPayload() -> ReaderUIJSONPayload {
        [
            "subscriptionId": .string("feed-a"),
            "evaluatedAt": .number(300),
        ]
    }

    private func rssSubscriptionPayload(operation: String) -> ReaderUIJSONPayload {
        var params: ReaderUIJSONPayload = [
            "subscriptionId": .string("feed-a"),
            "feedUrl": .string("https://feed.test/rss.xml"),
            "title": .string(operation == "create" ? "Feed" : "Renamed"),
            "enabled": .bool(operation == "create"),
        ]
        if operation == "create" {
            params["siteUrl"] = .null
        }
        return [
            "operation": .string(operation),
            "params": .object(params),
        ]
    }

    private func rssDeletePayload() -> ReaderUIJSONPayload {
        ["subscriptionId": .string("feed-a")]
    }

    private func rssEntryPayload() -> ReaderUIJSONPayload {
        [
            "subscriptionId": .string("feed-a"),
            "guid": .string("entry-1"),
            "read": .bool(true),
        ]
    }

    private func rssFavoriteAddPayload() -> ReaderUIJSONPayload {
        [
            "subscriptionId": .string("feed-a"),
            "guid": .string("entry-1"),
            "addedAt": .number(300),
        ]
    }

    private func rssFavoriteRemovePayload() -> ReaderUIJSONPayload {
        [
            "subscriptionId": .string("feed-a"),
            "guid": .string("entry-1"),
        ]
    }
}

@MainActor
private final class FakeRssExecutor: ReaderRssEffectExecuting {
    var begun: [String] = []
    var executedTypes: [String] = []
    var cancelled: [String] = []
    var finished: [String] = []
    private var outcomes: [ReaderRssEffectOutcome]
    private var activeCorrelations: Set<String> = []

    init(outcomes: [ReaderRssEffectOutcome] = []) {
        self.outcomes = outcomes
    }

    func begin(correlationID: String) {
        begun.append(correlationID)
        activeCorrelations.insert(correlationID)
    }

    func execute(_ effect: ReaderUIEffect) async -> ReaderRssEffectOutcome {
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
