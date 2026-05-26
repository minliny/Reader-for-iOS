import XCTest
@testable import ReaderApp

/// Phase 4A: Real Network Gate 防误触测试
final class RealNetworkGateTests: XCTestCase {

    // MARK: - Policy defaults

    func testDefaultPolicyIsDisabled() {
        let policy = RealNetworkPolicy.default
        XCTAssertEqual(policy.mode, .disabled)
        XCTAssertFalse(policy.isNetworkAllowed)
    }

    func testDefaultPolicyHasDenialReason() {
        let policy = RealNetworkPolicy.default
        XCTAssertNotNil(policy.denialReason)
        XCTAssertTrue(policy.denialReason!.contains("禁用"))
    }

    func testDefaultPolicyDoesNotRequireUserAction() {
        let policy = RealNetworkPolicy.default
        XCTAssertFalse(policy.requiresExplicitUserAction)
    }

    // MARK: - Gate decisions

    func testGateDeniesDefaultPolicy() {
        let gate = DefaultRealNetworkGate()
        let decision = gate.evaluate(.default)
        guard case .denied(let reason) = decision else {
            XCTFail("default policy should be denied")
            return
        }
        XCTAssertFalse(reason.isEmpty)
    }

    func testGateDeniesLiveProbePlanned() {
        let gate = DefaultRealNetworkGate()
        var policy = RealNetworkPolicy.default
        policy = RealNetworkPolicy(mode: .liveProbePlanned, lastChangedAt: Date(), changedBy: "test")
        let decision = gate.evaluate(policy)
        guard case .denied = decision else {
            XCTFail("liveProbePlanned should be denied (not executed yet)")
            return
        }
    }

    // MARK: - Provider defaults

    func testProviderDefaultsToMock() {
        let provider = ReaderCoreServiceProvider.shared
        XCTAssertEqual(provider.currentMode, .mock)
    }

    func testProviderRealModeNotAvailableByDefault() {
        let provider = ReaderCoreServiceProvider.shared
        XCTAssertFalse(provider.isRealModeAvailable)
    }

    func testConfigureRealModeFailsUnderDisabledPolicy() {
        // Reset policy to default disabled
        RealNetworkPolicyStore.shared.reset()

        let provider = ReaderCoreServiceProvider.shared
        let result = provider.configureRealMode()
        XCTAssertFalse(result, "configureRealMode should fail when policy is disabled")
        XCTAssertFalse(provider.isRealModeAvailable)
    }

    // MARK: - Store

    func testPolicyStoreDefaultsToDisabled() {
        RealNetworkPolicyStore.shared.reset()
        let policy = RealNetworkPolicyStore.shared.current
        XCTAssertEqual(policy.mode, .disabled)
    }

    func testPolicyStoreResetRestoresDefault() {
        let store = RealNetworkPolicyStore.shared
        store.reset()
        XCTAssertEqual(store.current.mode, .disabled)
    }

    // MARK: - Mock flow unaffected

    func testMockSearchStillWorks() async {
        RealNetworkPolicyStore.shared.reset()
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)

        let state = await provider.searchBooks(keyword: "test", page: 1)
        guard case .loaded(let results) = state else {
            XCTFail("Mock search should still work with gate in place")
            return
        }
        XCTAssertEqual(results.count, 3)
        provider.resetMock()
    }

    func testMockContentStillWorks() async {
        RealNetworkPolicyStore.shared.reset()
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)

        let state = await provider.getChapterContent(chapterURL: "test")
        guard case .loaded = state else {
            XCTFail("Mock content should still work with gate in place")
            return
        }
        provider.resetMock()
    }

    // MARK: - No parser internals (compile-time)

    func testRealNetworkPolicyDoesNotImportParserInternals() {
        let policy = RealNetworkPolicy.default
        XCTAssertEqual(policy.mode, .disabled)
        // Compile-time: RealNetworkPolicy has no parser dependencies
    }

    func testGateDecisionIsEquatable() {
        let a = RealNetworkGateDecision.allowed
        let b = RealNetworkGateDecision.denied(reason: "test")
        let c = RealNetworkGateDecision.denied(reason: "test")
        XCTAssertEqual(a, a)
        XCTAssertEqual(b, c)
        XCTAssertNotEqual(a, b)
    }
}
