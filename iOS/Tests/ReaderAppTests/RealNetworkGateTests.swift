import XCTest
@testable import ReaderApp
@testable import ReaderShellValidation

/// Phase 4A: Real Network Gate 防误触测试
@MainActor
final class RealNetworkGateTests: XCTestCase {

    // MARK: - Policy defaults

    func testDefaultPolicyIsUnrestricted() {
        let policy = RealNetworkPolicy.default
        XCTAssertEqual(policy.mode, .unrestricted)
        XCTAssertTrue(policy.isNetworkAllowed)
    }

    func testDefaultPolicyHasNoDenialReason() {
        let policy = RealNetworkPolicy.default
        XCTAssertNil(policy.denialReason)
    }

    func testDefaultPolicyDoesNotRequireUserAction() {
        let policy = RealNetworkPolicy.default
        XCTAssertFalse(policy.requiresExplicitUserAction)
    }

    // MARK: - Gate decisions

    func testGateAllowsDefaultPolicy() {
        let gate = DefaultRealNetworkGate()
        let decision = gate.evaluate(.default)
        XCTAssertEqual(decision, .allowed)
    }

    func testGateAllowsLiveProbePlanned() {
        let gate = DefaultRealNetworkGate()
        var policy = RealNetworkPolicy.default
        policy = RealNetworkPolicy(mode: .liveProbePlanned, lastChangedAt: Date(), changedBy: "test")
        let decision = gate.evaluate(policy)
        XCTAssertEqual(decision, .allowed)
    }

    // MARK: - Provider defaults

    func testProviderDefaultsToMock() {
        let provider = ReaderCoreServiceProvider.shared
        XCTAssertEqual(provider.currentMode, .mock)
    }

    func testProviderRealModeAvailableByDefault() {
        let provider = ReaderCoreServiceProvider.shared
        XCTAssertTrue(provider.isRealModeAvailable)
    }

    func testConfigureRealModeSucceedsUnderDefaultPolicy() {
        RealNetworkPolicyStore.shared.reset()

        let provider = ReaderCoreServiceProvider.shared
        let result = provider.configureRealMode()
        XCTAssertTrue(result, "configureRealMode should succeed when network restrictions are lifted")
        XCTAssertTrue(provider.isRealModeAvailable)
    }

    // MARK: - Store

    func testPolicyStoreDefaultsToUnrestricted() {
        RealNetworkPolicyStore.shared.reset()
        let policy = RealNetworkPolicyStore.shared.current
        XCTAssertEqual(policy.mode, .unrestricted)
    }

    func testPolicyStoreResetRestoresDefault() {
        let store = RealNetworkPolicyStore.shared
        store.reset()
        XCTAssertEqual(store.current.mode, .unrestricted)
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
        XCTAssertEqual(policy.mode, .unrestricted)
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
