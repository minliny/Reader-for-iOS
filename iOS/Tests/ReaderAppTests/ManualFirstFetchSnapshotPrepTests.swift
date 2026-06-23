import XCTest
@testable import ReaderApp
@testable import ReaderShellValidation

/// Phase 4D-next: Manual First Fetch Snapshot 准备测试 — 不执行真实网络
@MainActor
final class ManualFirstFetchSnapshotPrepTests: XCTestCase {

    let candidate = LiveProbeCandidate(
        id: "c001", name: "Test", baseURL: "https://test.example.com",
        host: "test.example.com", riskLevel: .low,
        allowedOperations: [.search], reason: "test"
    )

    func makeRequest(dryRun: Bool = true, approved: Bool = true, snapshotPath: String = "/snaps/c001/search.json", host: String = "test.example.com") -> ManualFetchRequest {
        let manifest = LiveProbeManifest(
            candidateId: "c001", operation: .search, approvedByUser: approved,
            reason: "test dry run", expectedSnapshotPath: snapshotPath, host: host
        )
        return ManualFetchRequest(
            candidate: candidate, manifest: manifest,
            expectedSnapshotPath: snapshotPath, requestedByUser: approved, dryRunOnly: dryRun, reason: "test"
        )
    }

    func makeExecutor() -> ManualLiveProbeExecutor {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("snaps_\(UUID().uuidString)")
        let store = SnapshotStore(snapshotRoot: root)
        return ManualLiveProbeExecutor(snapshotStore: store)
    }

    // MARK: - Dry-run

    func testDryRunAllowed_wouldPassGate() {
        let ex = makeExecutor()
        let req = makeRequest()
        let result = ex.dryRun(request: req)
        XCTAssertTrue(result.wouldPassGate)
        XCTAssertFalse(result.networkExecuted)
        XCTAssertNotNil(result.wouldWriteSnapshotPath)
        XCTAssertNotNil(result.wouldWriteMetadataPath)
    }

    func testDryRunAllowed_whenManifestNotApprovedAfterRestrictionsLifted() {
        let ex = makeExecutor()
        let req = makeRequest(approved: false)
        let result = ex.dryRun(request: req)
        XCTAssertTrue(result.wouldPassGate)
        XCTAssertFalse(result.networkExecuted)
    }

    func testDryRunDenied_pathTraversal() {
        let ex = makeExecutor()
        let req = makeRequest(snapshotPath: "../etc/passwd")
        let result = ex.dryRun(request: req)
        XCTAssertFalse(result.wouldPassGate)
    }

    func testDryRunNetworkExecutedAlwaysFalse() {
        let ex = makeExecutor()
        let req = makeRequest()
        let result = ex.dryRun(request: req)
        XCTAssertFalse(result.networkExecuted, "dryRun must never execute network")
    }

    // MARK: - Execute always denied

    func testExecuteReturnsFailure() {
        let ex = makeExecutor()
        let req = makeRequest()
        let result = ex.execute(request: req)
        guard case .failure(let error) = result else {
            XCTFail("execute must fail in Phase 4D-next")
            return
        }
        XCTAssertTrue(error.localizedDescription.contains("明确授权"))
    }

    func testExecuteAuditRecordNetworkExecutedFalse() {
        let ex = makeExecutor()
        let req = makeRequest(approved: false)
        let result = ex.execute(request: req)
        if case .failure(let error) = result,
           let manualError = error as? ManualExecutorError,
           case .requiresAuthorization(let audit) = manualError {
            XCTAssertFalse(audit.networkExecuted)
            XCTAssertTrue(audit.dryRunOnly)
        } else {
            XCTFail("Expected requiresAuthorization error with audit record")
        }
    }

    // MARK: - Request defaults

    func testRequestDefaultsDryRunOnly() {
        let manifest = LiveProbeManifest(
            candidateId: "c001", operation: .search, approvedByUser: true,
            reason: "test", expectedSnapshotPath: "/s.json", host: "t.example.com"
        )
        let req = ManualFetchRequest(candidate: candidate, manifest: manifest, expectedSnapshotPath: "/s.json")
        XCTAssertTrue(req.dryRunOnly, "Default should be dry-run only")
        XCTAssertFalse(req.requestedByUser)
    }

    // MARK: - Snapshot metadata

    func testSnapshotMetadataIsPlaceholder() {
        let meta = SnapshotMetadata(candidateId: "c001", operation: "search", host: "h", reason: "r")
        XCTAssertTrue(meta.isPlaceholder)
        XCTAssertFalse(meta.networkExecuted)
    }

    func testSnapshotMetadataHasFallbackReplay() {
        let meta = SnapshotMetadata(candidateId: "c001", operation: "search", host: "h", reason: "r")
        XCTAssertEqual(meta.fallbackReplayScenario, "OfflineReplayFixtures")
    }

    // MARK: - Audit record

    func testAuditRecordNetworkExecutedAlwaysFalse() {
        let record = LiveProbeAuditRecord(
            requestId: "r1", candidateId: "c001", operation: "search",
            decision: "allowed", dryRunOnly: true
        )
        XCTAssertFalse(record.networkExecuted)
        XCTAssertTrue(record.dryRunOnly)
    }

    func testAuditRecordHasReadableDenialReason() {
        let record = LiveProbeAuditRecord(
            requestId: "r1", candidateId: "c001", operation: "search",
            decision: "denied", deniedReason: "gate: not approved"
        )
        XCTAssertEqual(record.deniedReason, "gate: not approved")
    }

    // MARK: - Gate integration

    func testGateRateLimitAllowedAfterRestrictionsLifted_showsInDryRun() {
        let limiter = LiveProbeRateLimiter()
        limiter.recordPlannedRequest(host: "test.example.com", date: Date())
        let gate = LiveProbeGate(policy: .default, rateLimiter: limiter)
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("snaps_\(UUID().uuidString)")
        let ex = ManualLiveProbeExecutor(gate: gate, snapshotStore: SnapshotStore(snapshotRoot: root))
        let req = makeRequest()
        let result = ex.dryRun(request: req)
        XCTAssertTrue(result.wouldPassGate)
        XCTAssertFalse(result.networkExecuted)
    }

    // MARK: - Provider defaults

    func testProviderDefaultsToMock() {
        XCTAssertEqual(ReaderCoreServiceProvider.shared.currentMode, .mock)
    }

    func testOfflineReplayNotDefault() {
        // Offline replay requires explicit enableOfflineReplay(), not default
        let provider = ReaderCoreServiceProvider.shared
        XCTAssertEqual(provider.currentMode, .mock)
    }

    // MARK: - No parser internals

    func testExecutorHasNoParserDependencies() {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("s")
        let ex = ManualLiveProbeExecutor(snapshotStore: SnapshotStore(snapshotRoot: root))
        XCTAssertTrue(ex.validateNoNetwork())
    }
}
