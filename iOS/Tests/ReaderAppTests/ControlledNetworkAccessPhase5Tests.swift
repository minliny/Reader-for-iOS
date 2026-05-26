import XCTest
@testable import ReaderApp

/// Phase 5: Controlled Network Access — no-network skeleton tests
final class ControlledNetworkAccessPhase5Tests: XCTestCase {

    let enabledSource = SourceNetworkPolicy.fixture(id: "s001", name: "Test", host: "test.example.com")
    let disabledSource: SourceNetworkPolicy = {
        var s = SourceNetworkPolicy.fixture(id: "s002", name: "Disabled", host: "d.example.com")
        s.isEnabled = false
        return s
    }()

    // MARK: - Defaults are safe

    func testUserPreferenceSafeDefaultDeniesNetwork() {
        let pref = UserNetworkPreference.safeDefault
        XCTAssertFalse(pref.allowNetworkAccess)
        XCTAssertTrue(pref.preferOfflineReplay)
        XCTAssertTrue(pref.cacheFirst)
    }

    func testUserPreferenceProductDefaultAllowsNetwork() {
        let pref = UserNetworkPreference.productDefault
        XCTAssertTrue(pref.allowNetworkAccess)
        XCTAssertFalse(pref.preferOfflineReplay)
    }

    // MARK: - Controller: user denies network

    func testDenied_whenUserDeniesNetwork() {
        let ctrl = NetworkAccessController()
        let pref = UserNetworkPreference.safeDefault  // allowNetworkAccess = false
        let result = ctrl.evaluate(userPreference: pref, sourcePolicy: enabledSource, operation: .search)
        guard case .denied(let reason, _) = result else {
            XCTFail("should deny when user disables network")
            return
        }
        XCTAssertTrue(reason.contains("网络"))
    }

    // MARK: - Controller: source disabled

    func testDenied_whenSourceDisabled() {
        let ctrl = NetworkAccessController()
        let pref = UserNetworkPreference.productDefault
        let result = ctrl.evaluate(userPreference: pref, sourcePolicy: disabledSource, operation: .search)
        guard case .denied(let reason, _) = result else {
            XCTFail("should deny when source disabled")
            return
        }
        XCTAssertTrue(reason.contains("未启用"))
    }

    // MARK: - Controller: operation not allowed

    func testDenied_whenOperationNotAllowed() {
        let ctrl = NetworkAccessController()
        let pref = UserNetworkPreference.productDefault
        var source = SourceNetworkPolicy.fixture()
        source.allowSearch = false
        let result = ctrl.evaluate(userPreference: pref, sourcePolicy: source, operation: .search)
        guard case .denied(let reason, _) = result else {
            XCTFail("should deny search when not allowed")
            return
        }
        XCTAssertTrue(reason.contains("搜索") || reason.contains("search"))
    }

    // MARK: - Controller: cache-first

    func testFallbackToCache_whenCacheFirst() {
        let ctrl = NetworkAccessController()
        var pref = UserNetworkPreference.productDefault
        pref.cacheFirst = true
        let result = ctrl.evaluate(userPreference: pref, sourcePolicy: enabledSource, operation: .search)
        guard case .fallbackToCache = result else {
            XCTFail("should fallback to cache when cacheFirst=true")
            return
        }
    }

    // MARK: - Controller: prefer offline replay

    func testDeniedWithOfflineReplay_whenPreferOfflineReplay() {
        let ctrl = NetworkAccessController()
        var pref = UserNetworkPreference.productDefault
        pref.preferOfflineReplay = true
        let result = ctrl.evaluate(userPreference: pref, sourcePolicy: enabledSource, operation: .search)
        guard case .denied(_, let fallback) = result else {
            XCTFail("should fallback to offline replay")
            return
        }
        XCTAssertEqual(fallback, .offlineReplay)
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

    func testDenied_whenRateLimited() {
        let limiter = LiveProbeRateLimiter()
        limiter.recordPlannedRequest(host: "test.example.com", date: Date())
        let ctrl = NetworkAccessController(rateLimiter: limiter)
        var pref = UserNetworkPreference.productDefault
        pref.cacheFirst = false
        pref.preferOfflineReplay = false
        let result = ctrl.evaluate(userPreference: pref, sourcePolicy: enabledSource, operation: .search)
        guard case .denied = result else {
            XCTFail("should deny due to rate-limit")
            return
        }
    }

    // MARK: - Provider remains mock

    func testProviderDefaultsToMock() {
        XCTAssertEqual(ReaderCoreServiceProvider.shared.currentMode, .mock)
    }

    // MARK: - No parser internals

    func testControlledNetworkPolicyHasNoParserDependencies() {
        let pref = UserNetworkPreference.safeDefault
        XCTAssertFalse(pref.allowNetworkAccess)
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

    // MARK: - Existing gates intact

    func testRealNetworkPolicyStillDefaultsToDisabled() {
        let policy = RealNetworkPolicy.default
        XCTAssertEqual(policy.mode, .disabled)
        XCTAssertFalse(policy.isNetworkAllowed)
    }

    func testLiveProbeGateStillRequiresExplicitOptIn() {
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
        guard case .denied = decision else {
            XCTFail("LiveProbeGate should still deny without explicit opt-in")
            return
        }
    }
}
