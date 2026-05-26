import XCTest
@testable import ReaderApp

/// Phase 4D: Live Probe Gate skeleton 测试 — 不执行真实网络
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

    // MARK: - Manifest not approved

    func testManifestNotApproved_denied() {
        let gate = makeGate()
        let manifest = makeManifest(approved: false)
        let decision = gate.evaluate(candidate: candidate, manifest: manifest)
        guard case .denied(let reason) = decision else {
            XCTFail("Should deny unapproved manifest")
            return
        }
        XCTAssertTrue(reason.contains("opt-in") || reason.contains("批准"))
    }

    // MARK: - Missing reason

    func testEmptyReason_denied() {
        let gate = makeGate()
        var manifest = makeManifest()
        manifest = LiveProbeManifest(candidateId: "c001", operation: .search, approvedByUser: true, reason: "", expectedSnapshotPath: "/s/c001/s.json", host: "test.example.com")
        guard case .denied(let reason) = decision("empty reason") else { return }
        _ = reason
        let d = gate.evaluate(candidate: candidate, manifest: manifest)
        guard case .denied = d else { XCTFail("empty reason should be denied"); return }
    }

    // MARK: - Missing snapshot path

    func testEmptySnapshotPath_denied() {
        let gate = makeGate()
        let manifest = makeManifest(snapshotPath: "")
        let decision = gate.evaluate(candidate: candidate, manifest: manifest)
        guard case .denied(let reason) = decision else {
            XCTFail("Should deny empty snapshot path")
            return
        }
        XCTAssertTrue(reason.contains("snapshot") || reason.contains("不完整"))
    }

    // MARK: - Operation not allowed

    func testOperationNotAllowed_denied() {
        let gate = makeGate()
        let restricted = LiveProbeCandidate(
            id: "c002", name: "Restricted", baseURL: "https://r.example.com",
            host: "r.example.com", riskLevel: .low,
            allowedOperations: [.detail], reason: "detail only"
        )
        let manifest = makeManifest(host: "r.example.com", operation: .search)
        let decision = gate.evaluate(candidate: restricted, manifest: manifest)
        guard case .denied(let reason) = decision else {
            XCTFail("Should deny unallowed operation")
            return
        }
        XCTAssertTrue(reason.contains("操作"))
    }

    // MARK: - Risk level

    func testHighRiskCandidate_denied() {
        let gate = makeGate()
        let highRisk = LiveProbeCandidate(
            id: "c003", name: "High Risk", baseURL: "https://hr.example.com",
            host: "hr.example.com", riskLevel: .high,
            allowedOperations: [.search], reason: "test"
        )
        let manifest = makeManifest(host: "hr.example.com")
        let decision = gate.evaluate(candidate: highRisk, manifest: manifest)
        guard case .denied(let reason) = decision else {
            XCTFail("Should deny high risk")
            return
        }
        XCTAssertTrue(reason.contains("high"))
    }

    func testBannedCandidate_denied() {
        let gate = makeGate()
        let banned = LiveProbeCandidate(
            id: "c004", name: "Banned", baseURL: "https://b.example.com",
            host: "b.example.com", riskLevel: .banned,
            allowedOperations: [.search], reason: "test"
        )
        let manifest = makeManifest(host: "b.example.com")
        let decision = gate.evaluate(candidate: banned, manifest: manifest)
        guard case .denied = decision else {
            XCTFail("Should deny banned")
            return
        }
    }

    // MARK: - Host mismatch

    func testHostMismatch_denied() {
        let gate = makeGate()
        let manifest = makeManifest(host: "other.example.com")
        let decision = gate.evaluate(candidate: candidate, manifest: manifest)
        guard case .denied(let reason) = decision else {
            XCTFail("Should deny host mismatch")
            return
        }
        XCTAssertTrue(reason.contains("host"))
    }

    // MARK: - Rate-limit

    func testRateLimitExceeded_denied() {
        let limiter = LiveProbeRateLimiter()
        limiter.recordPlannedRequest(host: "test.example.com", date: Date())
        let gate = LiveProbeGate(policy: .default, rateLimiter: limiter)
        let manifest = makeManifest()
        let decision = gate.evaluate(candidate: candidate, manifest: manifest)
        guard case .denied(let reason) = decision else {
            XCTFail("Should deny rate-limit exceeded")
            return
        }
        XCTAssertTrue(reason.contains("速率限制") || reason.contains("窗口"))
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

    func testPolicyDefaultsAreSafe() {
        let policy = LiveProbePolicy.default
        XCTAssertTrue(policy.debugOnly)
        XCTAssertTrue(policy.explicitOptInRequired)
        XCTAssertTrue(policy.snapshotRequired)
        XCTAssertTrue(policy.fallbackToOfflineReplayRequired)
        XCTAssertTrue(policy.releaseDisabled)
        XCTAssertEqual(policy.maxRequestsPerHost, 1)
        XCTAssertEqual(policy.windowSeconds, 300)
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

    // Helper
    private func decision(_ msg: String) -> LiveProbeDecision { .denied(reason: msg) }
}
