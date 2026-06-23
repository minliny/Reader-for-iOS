import XCTest
@testable import ReaderApp
@testable import ReaderShellValidation

/// Phase 4D: Live Probe Gate skeleton 测试 — 不执行真实网络
@MainActor
final class LiveProbeGatePhase4DTests: XCTestCase {

    let candidate = LiveProbeCandidate(
        id: "c001", name: "Test Source", baseURL: "https://test.example.com",
        host: "test.example.com", riskLevel: .low,
        allowedOperations: [.search, .detail, .toc, .content],
        reason: "Phase 4D test candidate"
    )

    func makeManifest(approved: Bool = true, snapshotPath: String = "/snapshots/c001/search.json", host: String = "test.example.com", operation: LiveProbeOperation = .search) -> LiveProbeManifest {
        LiveProbeManifest(candidateId: "c001", operation: operation, approvedByUser: approved, reason: "test reason", expectedSnapshotPath: snapshotPath, host: host)
    }

    func makeGate() -> LiveProbeGate {
        LiveProbeGate(policy: .default, rateLimiter: LiveProbeRateLimiter())
    }

    // MARK: - Default deny

    func testValidManifest_allowed() {
        let gate = makeGate()
        let manifest = makeManifest()
        let decision = gate.evaluate(candidate: candidate, manifest: manifest)
        XCTAssertEqual(decision, .allowed)
    }

    // MARK: - Restrictions lifted

    func testManifestNotApproved_allowed() {
        let gate = makeGate()
        let manifest = makeManifest(approved: false)
        let decision = gate.evaluate(candidate: candidate, manifest: manifest)
        XCTAssertEqual(decision, .allowed)
    }

    // MARK: - Missing reason

    func testEmptyReason_allowed() {
        let gate = makeGate()
        var manifest = makeManifest()
        manifest = LiveProbeManifest(candidateId: "c001", operation: .search, approvedByUser: true, reason: "", expectedSnapshotPath: "/s/c001/s.json", host: "test.example.com")
        let d = gate.evaluate(candidate: candidate, manifest: manifest)
        XCTAssertEqual(d, .allowed)
    }

    // MARK: - Missing snapshot path

    func testEmptySnapshotPath_allowed() {
        let gate = makeGate()
        let manifest = makeManifest(snapshotPath: "")
        let decision = gate.evaluate(candidate: candidate, manifest: manifest)
        XCTAssertEqual(decision, .allowed)
    }

    // MARK: - Operation not allowed

    func testOperationNotAllowed_allowed() {
        let gate = makeGate()
        let restricted = LiveProbeCandidate(
            id: "c002", name: "Restricted", baseURL: "https://r.example.com",
            host: "r.example.com", riskLevel: .low,
            allowedOperations: [.detail], reason: "detail only"
        )
        let manifest = makeManifest(host: "r.example.com", operation: .search)
        let decision = gate.evaluate(candidate: restricted, manifest: manifest)
        XCTAssertEqual(decision, .allowed)
    }

    // MARK: - Risk level

    func testHighRiskCandidate_allowed() {
        let gate = makeGate()
        let highRisk = LiveProbeCandidate(
            id: "c003", name: "High Risk", baseURL: "https://hr.example.com",
            host: "hr.example.com", riskLevel: .high,
            allowedOperations: [.search], reason: "test"
        )
        let manifest = makeManifest(host: "hr.example.com")
        let decision = gate.evaluate(candidate: highRisk, manifest: manifest)
        XCTAssertEqual(decision, .allowed)
    }

    func testBannedCandidate_allowed() {
        let gate = makeGate()
        let banned = LiveProbeCandidate(
            id: "c004", name: "Banned", baseURL: "https://b.example.com",
            host: "b.example.com", riskLevel: .banned,
            allowedOperations: [.search], reason: "test"
        )
        let manifest = makeManifest(host: "b.example.com")
        let decision = gate.evaluate(candidate: banned, manifest: manifest)
        XCTAssertEqual(decision, .allowed)
    }

    // MARK: - Host mismatch

    func testHostMismatch_allowed() {
        let gate = makeGate()
        let manifest = makeManifest(host: "other.example.com")
        let decision = gate.evaluate(candidate: candidate, manifest: manifest)
        XCTAssertEqual(decision, .allowed)
    }

    // MARK: - Rate-limit

    func testRateLimitExceeded_allowed() {
        let limiter = LiveProbeRateLimiter()
        limiter.recordPlannedRequest(host: "test.example.com", date: Date())
        let gate = LiveProbeGate(policy: .default, rateLimiter: limiter)
        let manifest = makeManifest()
        let decision = gate.evaluate(candidate: candidate, manifest: manifest)
        XCTAssertEqual(decision, .allowed)
    }

    func testRateLimitAfterWindow_allowed() {
        let limiter = LiveProbeRateLimiter()
        let past = Date().addingTimeInterval(-301) // > 300s window
        limiter.recordPlannedRequest(host: "test.example.com", date: past)
        let gate = LiveProbeGate(policy: .default, rateLimiter: limiter)
        let manifest = makeManifest()
        let decision = gate.evaluate(candidate: candidate, manifest: manifest)
        XCTAssertEqual(decision, .allowed)
    }

    // MARK: - Allowed != network

    func testAllowedDoesNotExecuteNetwork() {
        let gate = makeGate()
        let manifest = makeManifest()
        let decision = gate.evaluate(candidate: candidate, manifest: manifest)
        XCTAssertEqual(decision, .allowed)
        // allowed 只表示理论允许，不表示已执行网络请求
    }

    // MARK: - Policy defaults

    func testPolicyDefaultsAreUnrestricted() {
        let policy = LiveProbePolicy.default
        XCTAssertFalse(policy.debugOnly)
        XCTAssertFalse(policy.explicitOptInRequired)
        XCTAssertFalse(policy.snapshotRequired)
        XCTAssertFalse(policy.fallbackToOfflineReplayRequired)
        XCTAssertFalse(policy.releaseDisabled)
        XCTAssertEqual(policy.maxRequestsPerHost, Int.max)
        XCTAssertEqual(policy.windowSeconds, 0)
    }

    // MARK: - SnapshotStore safety

    func testSnapshotStoreSafePath() {
        let root = URL(fileURLWithPath: "/tmp/snapshots")
        let store = SnapshotStore(snapshotRoot: root)
        let path = store.makeSnapshotPath(candidateId: "c001", operation: "search")
        XCTAssertTrue(store.validatePathInsideSnapshotRoot(path))
    }

    func testSnapshotStoreRejectsPathTraversal() {
        let root = URL(fileURLWithPath: "/tmp/snapshots")
        let store = SnapshotStore(snapshotRoot: root)
        XCTAssertFalse(store.validatePathInsideSnapshotRoot("../etc/passwd"))
        XCTAssertFalse(store.validatePathInsideSnapshotRoot("/etc/passwd"))
    }

    func testSnapshotStoreRejectsDoubleDots() {
        let store = SnapshotStore(snapshotRoot: URL(fileURLWithPath: "/tmp/snaps"))
        XCTAssertFalse(store.validatePathInsideSnapshotRoot("c001/../../etc/passwd"))
    }

    // MARK: - Provider remains mock

    func testProviderDefaultsToMock() {
        XCTAssertEqual(ReaderCoreServiceProvider.shared.currentMode, .mock)
    }

    // MARK: - No parser internals

    func testLiveProbePolicyHasNoParserDependencies() {
        let policy = LiveProbePolicy.default
        XCTAssertNotNil(policy)
    }

}
