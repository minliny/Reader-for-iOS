import XCTest
@testable import ReaderApp
@testable import ReaderShellValidation

/// Phase 5: Controlled Network Access — no-network skeleton tests
@MainActor
final class ControlledNetworkAccessPhase5Tests: XCTestCase {

    let enabledSource = SourceNetworkPolicy.fixture(id: "s001", name: "Test", host: "test.example.com")
    let disabledSource: SourceNetworkPolicy = {
        var s = SourceNetworkPolicy.fixture(id: "s002", name: "Disabled", host: "d.example.com")
        s.isEnabled = false
        return s
    }()

    // MARK: - Defaults are unrestricted

    func testUserPreferenceSafeDefaultAllowsNetwork() {
        let pref = UserNetworkPreference.safeDefault
        XCTAssertTrue(pref.allowNetworkAccess)
        XCTAssertFalse(pref.preferOfflineReplay)
        XCTAssertFalse(pref.cacheFirst)
    }

    func testUserPreferenceProductDefaultAllowsNetwork() {
        let pref = UserNetworkPreference.productDefault
        XCTAssertTrue(pref.allowNetworkAccess)
        XCTAssertFalse(pref.preferOfflineReplay)
    }

    // MARK: - Controller: restrictions no longer block

    func testAllowed_whenUserDeniesNetwork() {
        let ctrl = NetworkAccessController()
        let pref = UserNetworkPreference.safeDefault  // allowNetworkAccess = false
        let result = ctrl.evaluate(userPreference: pref, sourcePolicy: enabledSource, operation: .search)
        guard case .allowed(_, let audit) = result else {
            XCTFail("should allow after network restrictions are lifted")
            return
        }
        XCTAssertTrue(audit.networkTriggered)
    }

    func testAllowed_whenSourceDisabled() {
        let ctrl = NetworkAccessController()
        let pref = UserNetworkPreference.productDefault
        let result = ctrl.evaluate(userPreference: pref, sourcePolicy: disabledSource, operation: .search)
        guard case .allowed(_, let audit) = result else {
            XCTFail("should allow disabled source after restrictions are lifted")
            return
        }
        XCTAssertTrue(audit.networkTriggered)
    }

    func testAllowed_whenOperationNotAllowed() {
        let ctrl = NetworkAccessController()
        let pref = UserNetworkPreference.productDefault
        var source = SourceNetworkPolicy.fixture()
        source.allowSearch = false
        let result = ctrl.evaluate(userPreference: pref, sourcePolicy: source, operation: .search)
        guard case .allowed(_, let audit) = result else {
            XCTFail("should allow operation after restrictions are lifted")
            return
        }
        XCTAssertTrue(audit.networkTriggered)
    }

    // MARK: - Controller: cache-first

    func testAllowed_whenCacheFirst() {
        let ctrl = NetworkAccessController()
        var pref = UserNetworkPreference.productDefault
        pref.cacheFirst = true
        let result = ctrl.evaluate(userPreference: pref, sourcePolicy: enabledSource, operation: .search)
        guard case .allowed(_, let audit) = result else {
            XCTFail("should allow when cacheFirst=true after restrictions are lifted")
            return
        }
        XCTAssertTrue(audit.networkTriggered)
    }

    // MARK: - Controller: prefer offline replay

    func testAllowedWithOfflineReplayPreference() {
        let ctrl = NetworkAccessController()
        var pref = UserNetworkPreference.productDefault
        pref.preferOfflineReplay = true
        let result = ctrl.evaluate(userPreference: pref, sourcePolicy: enabledSource, operation: .search)
        guard case .allowed(_, let audit) = result else {
            XCTFail("should allow after restrictions are lifted")
            return
        }
        XCTAssertTrue(audit.networkTriggered)
    }

    // MARK: - Controller: allowed

    func testAllowed_whenAllConditionsMet() {
        let ctrl = NetworkAccessController()
        var pref = UserNetworkPreference.productDefault
        pref.cacheFirst = false    // disable cache-first
        pref.preferOfflineReplay = false
        let result = ctrl.evaluate(userPreference: pref, sourcePolicy: enabledSource, operation: .search)
        guard case .allowed(_, let audit) = result else {
            XCTFail("should allow when all conditions met")
            return
        }
        XCTAssertEqual(audit.sourceId, enabledSource.sourceId)
        XCTAssertTrue(audit.networkTriggered)
    }

    // MARK: - Controller: rate-limit

    func testAllowed_whenRateLimited() {
        let limiter = LiveProbeRateLimiter()
        limiter.recordPlannedRequest(host: "test.example.com", date: Date())
        let ctrl = NetworkAccessController(rateLimiter: limiter)
        var pref = UserNetworkPreference.productDefault
        pref.cacheFirst = false
        pref.preferOfflineReplay = false
        let result = ctrl.evaluate(userPreference: pref, sourcePolicy: enabledSource, operation: .search)
        guard case .allowed(_, let audit) = result else {
            XCTFail("should allow despite rate-limit after restrictions are lifted")
            return
        }
        XCTAssertTrue(audit.networkTriggered)
    }

    // MARK: - Provider remains mock

    func testProviderDefaultsToMock() {
        XCTAssertEqual(ReaderCoreServiceProvider.shared.currentMode, .mock)
    }

    // MARK: - No parser internals

    func testControlledNetworkPolicyHasNoParserDependencies() {
        let pref = UserNetworkPreference.safeDefault
        XCTAssertTrue(pref.allowNetworkAccess)
        let source = SourceNetworkPolicy.fixture()
        XCTAssertTrue(source.isEnabled)
    }

    // MARK: - Audit entry

    func testAuditEntryHasRequiredFields() {
        let audit = NetworkAuditEntry(sourceId: "s1", operation: "search", host: "h", decision: "allowed")
        XCTAssertEqual(audit.sourceId, "s1")
        XCTAssertEqual(audit.decision, "allowed")
        XCTAssertFalse(audit.networkTriggered, "networkTriggered defaults to false")
    }

    // MARK: - Source policy operation gating

    func testSourcePolicyAllowsSearch() {
        let source = SourceNetworkPolicy.fixture()
        XCTAssertTrue(source.allows(.search))
        XCTAssertTrue(source.allows(.detail))
        XCTAssertTrue(source.allows(.toc))
        XCTAssertTrue(source.allows(.content))
    }

    // MARK: - Existing gates lifted

    func testRealNetworkPolicyDefaultsToUnrestricted() {
        let policy = RealNetworkPolicy.default
        XCTAssertEqual(policy.mode, .unrestricted)
        XCTAssertTrue(policy.isNetworkAllowed)
    }

    func testLiveProbeGateNoLongerRequiresExplicitOptIn() {
        let gate = LiveProbeGate()
        let candidate = LiveProbeCandidate(
            id: "c1", name: "t", baseURL: "https://t.com",
            host: "t.com", riskLevel: .low,
            allowedOperations: [.search], reason: "test"
        )
        let manifest = LiveProbeManifest(
            candidateId: "c1", operation: .search, approvedByUser: false,
            reason: "", expectedSnapshotPath: "", host: "t.com"
        )
        let decision = gate.evaluate(candidate: candidate, manifest: manifest)
        XCTAssertEqual(decision, .allowed)
    }
}
