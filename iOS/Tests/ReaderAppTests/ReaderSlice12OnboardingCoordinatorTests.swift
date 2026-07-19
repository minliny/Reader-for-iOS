import XCTest
@testable import ReaderShellValidation

final class ReaderSlice12OnboardingCoordinatorTests: XCTestCase {
    @MainActor
    func testOnboardingFailsClosedUntilCoreRestoreIsReady() async {
        let client = FakeSlice12PermissionClient(statuses: [.storage: .authorized])
        let coordinator = ReaderSlice12OnboardingCoordinator(
            permissions: client,
            coreStorageReady: { false }
        )

        await coordinator.start(requiredScopes: [.storage])

        guard case .blocked(let code, _) = coordinator.state else {
            XCTFail("onboarding must block before Core restore")
            return
        }
        XCTAssertEqual(code, "SLICE12_INITIALIZATION_RESULT_NOT_READY")
        let permissionCallCount = await client.callCount()
        XCTAssertEqual(permissionCallCount, 0)
    }

    @MainActor
    func testDeniedPermissionRequiresSettingsRecoveryAndRechecksOnActivation() async {
        let client = FakeSlice12PermissionClient(statuses: [.notification: .notDetermined])
        let coordinator = ReaderSlice12OnboardingCoordinator(
            permissions: client,
            coreStorageReady: { true }
        )

        await coordinator.start(requiredScopes: [.notification])
        XCTAssertEqual(coordinator.state, .education(pending: [.notification]))

        await client.setRequestStatus(.denied, for: .notification)
        await coordinator.request(.notification)
        XCTAssertEqual(coordinator.state, .recovery(scope: .notification, status: .denied))

        await client.setStatus(.authorized, for: .notification)
        await coordinator.applicationDidBecomeActive()
        XCTAssertEqual(coordinator.state, .readyForApplication)
    }

    func testHostPermissionClientPreservesAuthorizedStatusForAppContainerStorage() async throws {
        let status = try await ReaderSlice12HostPermissionClient().check(.storage)
        XCTAssertEqual(status, .authorized)
    }

    @MainActor
    func testActivationBeforeStartCannotBypassTheExplicitPermissionPlan() async {
        let client = FakeSlice12PermissionClient(statuses: [:])
        let coordinator = ReaderSlice12OnboardingCoordinator(
            permissions: client,
            coreStorageReady: { true }
        )

        await coordinator.applicationDidBecomeActive()

        guard case .blocked(let code, _) = coordinator.state else {
            XCTFail("activation before start must fail closed")
            return
        }
        XCTAssertEqual(code, "SLICE12_ONBOARDING_PLAN_NOT_STARTED")
        let permissionCallCount = await client.callCount()
        XCTAssertEqual(permissionCallCount, 0)
    }

    @MainActor
    func testDurableOnboardingCompletionRemainsBlockedWithoutCoreOwner() {
        let coordinator = ReaderSlice12OnboardingCoordinator(
            permissions: FakeSlice12PermissionClient(statuses: [:]),
            coreStorageReady: { true }
        )
        XCTAssertThrowsError(try coordinator.requireDurableCompletionContract()) { error in
            XCTAssertTrue(error.localizedDescription.contains("SLICE12_ONBOARDING_OWNER_CONTRACT_MISSING"))
        }
    }

    @MainActor
    func testOlderStartResultCannotOverwriteNewerPermissionPlan() async throws {
        let client = ControlledSlice12PermissionClient()
        let coordinator = ReaderSlice12OnboardingCoordinator(
            permissions: client,
            coreStorageReady: { true }
        )

        let olderStart = Task {
            await coordinator.start(requiredScopes: [.camera])
        }
        try await waitForPendingCheck(.camera, in: client)

        let newerStart = Task {
            await coordinator.start(requiredScopes: [.notification])
        }
        try await waitForPendingCheck(.notification, in: client)

        await client.resolveFirstPending(.notification, with: .authorized)
        await newerStart.value
        XCTAssertEqual(coordinator.state, .readyForApplication)

        // The first Host operation intentionally ignores cancellation and
        // returns late. Its generation must no longer have write authority.
        await client.resolveFirstPending(.camera, with: .denied)
        await olderStart.value
        XCTAssertEqual(coordinator.state, .readyForApplication)
    }

    @MainActor
    func testOlderActivationRecheckCannotOverwriteLaterRecheck() async throws {
        let client = ControlledSlice12PermissionClient()
        await client.enqueue(.authorized, for: .storage)
        let coordinator = ReaderSlice12OnboardingCoordinator(
            permissions: client,
            coreStorageReady: { true }
        )
        await coordinator.start(requiredScopes: [.storage])
        XCTAssertEqual(coordinator.state, .readyForApplication)

        let olderRecheck = Task {
            await coordinator.applicationDidBecomeActive()
        }
        try await waitForPendingCheck(.storage, in: client)

        await client.enqueue(.authorized, for: .storage)
        let newerRecheck = Task {
            await coordinator.applicationDidBecomeActive()
        }
        await newerRecheck.value
        XCTAssertEqual(coordinator.state, .readyForApplication)

        await client.resolveFirstPending(.storage, with: .denied)
        await olderRecheck.value
        XCTAssertEqual(coordinator.state, .readyForApplication)
    }

    private func waitForPendingCheck(
        _ scope: ReaderSlice12PermissionScope,
        in client: ControlledSlice12PermissionClient
    ) async throws {
        for _ in 0..<10_000 {
            if await client.hasPending(scope) { return }
            await Task.yield()
        }
        throw OnboardingTestError.timedOutWaitingForCheck(scope)
    }
}

private enum OnboardingTestError: Error {
    case timedOutWaitingForCheck(ReaderSlice12PermissionScope)
}

private actor FakeSlice12PermissionClient: ReaderSlice12PermissionClient {
    private var statuses: [ReaderSlice12PermissionScope: ReaderSlice12PermissionStatus]
    private var requestStatuses: [ReaderSlice12PermissionScope: ReaderSlice12PermissionStatus] = [:]
    private var calls = 0

    init(statuses: [ReaderSlice12PermissionScope: ReaderSlice12PermissionStatus]) {
        self.statuses = statuses
    }

    func check(_ scope: ReaderSlice12PermissionScope) async throws -> ReaderSlice12PermissionStatus {
        calls += 1
        return statuses[scope] ?? .unknown
    }

    func request(_ scope: ReaderSlice12PermissionScope) async throws -> ReaderSlice12PermissionStatus {
        calls += 1
        let value = requestStatuses[scope] ?? statuses[scope] ?? .unknown
        statuses[scope] = value
        return value
    }

    func setStatus(_ status: ReaderSlice12PermissionStatus, for scope: ReaderSlice12PermissionScope) {
        statuses[scope] = status
    }

    func setRequestStatus(_ status: ReaderSlice12PermissionStatus, for scope: ReaderSlice12PermissionScope) {
        requestStatuses[scope] = status
    }

    func callCount() -> Int { calls }
}

/// A cancellation-resistant fake: suspended checks only resume when the test
/// explicitly releases them, which reproduces platform APIs that can deliver
/// a value after their surrounding Task was cancelled.
private actor ControlledSlice12PermissionClient: ReaderSlice12PermissionClient {
    private struct PendingCheck {
        let scope: ReaderSlice12PermissionScope
        let continuation: CheckedContinuation<ReaderSlice12PermissionStatus, Never>
    }

    private var queued: [ReaderSlice12PermissionScope: [ReaderSlice12PermissionStatus]] = [:]
    private var pending: [PendingCheck] = []

    func check(_ scope: ReaderSlice12PermissionScope) async throws -> ReaderSlice12PermissionStatus {
        if var values = queued[scope], !values.isEmpty {
            let value = values.removeFirst()
            queued[scope] = values
            return value
        }
        return await withCheckedContinuation { continuation in
            pending.append(PendingCheck(scope: scope, continuation: continuation))
        }
    }

    func request(_ scope: ReaderSlice12PermissionScope) async throws -> ReaderSlice12PermissionStatus {
        try await check(scope)
    }

    func enqueue(
        _ status: ReaderSlice12PermissionStatus,
        for scope: ReaderSlice12PermissionScope
    ) {
        queued[scope, default: []].append(status)
    }

    func hasPending(_ scope: ReaderSlice12PermissionScope) -> Bool {
        pending.contains { $0.scope == scope }
    }

    func resolveFirstPending(
        _ scope: ReaderSlice12PermissionScope,
        with status: ReaderSlice12PermissionStatus
    ) {
        guard let index = pending.firstIndex(where: { $0.scope == scope }) else {
            return
        }
        let continuation = pending.remove(at: index).continuation
        continuation.resume(returning: status)
    }
}
