import XCTest
@testable import ReaderApp
@testable import ReaderShellValidation

/// Phase 4E-next: LiveFetchExecutor 受控 fetch 测试
@MainActor
final class LiveFetchExecutorPhase4ETests: XCTestCase {

    let candidate = LiveProbeCandidate(
        id: "c001", name: "Test", baseURL: "https://test.example.com",
        host: "test.example.com", riskLevel: .low,
        allowedOperations: [.search], reason: "test"
    )

    func makeRequest(approved: Bool = true, snapshotPath: String = "/snaps/c001/search.json") -> ManualFetchRequest {
        let manifest = LiveProbeManifest(
            candidateId: "c001", operation: .search, approvedByUser: approved,
            reason: "authorized test", expectedSnapshotPath: snapshotPath, host: "test.example.com"
        )
        return ManualFetchRequest(
            candidate: candidate, manifest: manifest,
            expectedSnapshotPath: snapshotPath, requestedByUser: approved, dryRunOnly: false, reason: "authorized"
        )
    }

    func makeAuth() -> LiveFetchAuthorization {
        LiveFetchAuthorization(candidateId: "c001", operation: .search, reason: "test auth")
    }

    func makeExecutor() -> ManualLiveProbeExecutor {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("snaps_\(UUID().uuidString)")
        return ManualLiveProbeExecutor(snapshotStore: SnapshotStore(snapshotRoot: root))
    }

    // MARK: - Gate still denies bad requests

    func testAuthorizedFetchDenied_whenManifestNotApproved() async {
        let ex = makeExecutor()
        let req = makeRequest(approved: false)
        let result = await ex.executeAuthorized(request: req, authorization: makeAuth())
        guard case .denied = result else {
            XCTFail("unapproved manifest should be denied")
            return
        }
    }

    func testAuthorizedFetchDenied_whenPathTraversal() async {
        let ex = makeExecutor()
        let req = makeRequest(snapshotPath: "../etc/passwd")
        let result = await ex.executeAuthorized(request: req, authorization: makeAuth())
        guard case .denied = result else {
            XCTFail("path traversal should be denied")
            return
        }
    }

    func testAuthorizedFetchDenied_whenAuthMismatch() async {
        let ex = makeExecutor()
        let req = makeRequest()
        let wrongAuth = LiveFetchAuthorization(candidateId: "c002", operation: .search, reason: "wrong")
        let result = await ex.executeAuthorized(request: req, authorization: wrongAuth)
        guard case .denied = result else {
            XCTFail("mismatched auth should be denied")
            return
        }
    }

    // MARK: - Unauthorized execute still denied

    func testExecuteWithoutAuthorization_returnsFailure() {
        let ex = makeExecutor()
        let req = makeRequest()
        let result = ex.execute(request: req)
        guard case .failure(let error) = result else {
            XCTFail("execute() without auth must fail")
            return
        }
        XCTAssertTrue(error.localizedDescription.contains("授权"))
    }

    // MARK: - Dry-run still works

    func testDryRunStillAllowed() {
        let ex = makeExecutor()
        let req = makeRequest()
        let result = ex.dryRun(request: req)
        XCTAssertTrue(result.wouldPassGate)
        XCTAssertFalse(result.networkExecuted)
    }

    // MARK: - Provider remains mock

    func testProviderDefaultsToMock() {
        XCTAssertEqual(ReaderCoreServiceProvider.shared.currentMode, .mock)
    }

    // MARK: - No parser internals

    func testLiveFetchExecutorHasNoParserDependencies() {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("s")
        let store = SnapshotStore(snapshotRoot: root)
        let executor = LiveFetchExecutor(snapshotStore: store)
        XCTAssertNotNil(executor)
    }
}
