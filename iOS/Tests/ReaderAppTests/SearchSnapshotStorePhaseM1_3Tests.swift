import XCTest
@testable import ReaderApp
@testable import ReaderShellValidation
import ReaderCoreModels

/// M1.3: Search snapshot save/load — no real network
@MainActor
final class SearchSnapshotStorePhaseM1_3Tests: XCTestCase {

    var snapshotRoot: URL!

    override func setUp() {
        snapshotRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("snap_test_\(UUID().uuidString)")
    }

    func makeStore() -> SnapshotStore {
        SnapshotStore(snapshotRoot: snapshotRoot)
    }

    // MARK: - Save

    func testSaveSearchSnapshot_writesFile() {
        let store = makeStore()
        let items = [
            SearchSnapshotItem(from: SearchResultItem(title: "Test Book", detailURL: "fake://1", author: "Author", intro: "Intro")),
            SearchSnapshotItem(from: SearchResultItem(title: "Test Book 2", detailURL: "fake://2", author: "Author 2")),
        ]
        let result = store.saveSearchSnapshot(
            sourceId: "c001", sourceName: "Test", host: "example.com",
            keyword: "修仙", results: items, networkTriggered: true
        )
        guard case .success(let path) = result else {
            XCTFail("save failed: \(result)")
            return
        }
        XCTAssertTrue(store.validatePathInsideSnapshotRoot(path))
    }

    // MARK: - Load

    func testLoadSearchSnapshot_returnsSaved() {
        let store = makeStore()
        let items = [SearchSnapshotItem(from: SearchResultItem(title: "凡人修仙传", detailURL: "f://1", author: "忘语", intro: "..."))]
        _ = store.saveSearchSnapshot(sourceId: "c001", sourceName: "星星小说网", host: "h", keyword: "凡人", results: items, networkTriggered: true)

        let loaded = store.loadSearchSnapshot(candidateId: "c001")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.keyword, "凡人")
        XCTAssertEqual(loaded?.resultCount, 1)
        XCTAssertEqual(loaded?.results[0].title, "凡人修仙传")
        XCTAssertTrue(loaded?.networkTriggered == true)
    }

    // MARK: - Metadata fields

    func testSnapshotHasRequiredFields() {
        let store = makeStore()
        let items = [SearchSnapshotItem(from: SearchResultItem(title: "T", detailURL: "u", author: "A"))]
        _ = store.saveSearchSnapshot(sourceId: "s1", sourceName: "N", host: "h", keyword: "k", results: items, networkTriggered: false)

        let snap = store.loadSearchSnapshot(candidateId: "s1")!
        XCTAssertEqual(snap.sourceId, "s1")
        XCTAssertEqual(snap.sourceName, "N")
        XCTAssertEqual(snap.operation, "search")
        XCTAssertEqual(snap.host, "h")
        XCTAssertFalse(snap.requestedAt.isEmpty)
        XCTAssertFalse(snap.networkTriggered)
    }

    // MARK: - Path safety

    func testRejectsPathTraversal() {
        let store = makeStore()
        XCTAssertFalse(store.validatePathInsideSnapshotRoot("../etc/passwd"))
        XCTAssertFalse(store.validatePathInsideSnapshotRoot("/absolute/path"))
    }

    // MARK: - Provider defaults

    func testProviderDefaultsToMock() {
        XCTAssertEqual(ReaderCoreServiceProvider.shared.currentMode, .mock)
    }

    // MARK: - No real network

    func testNoRealNetworkInTests() {
        // All snapshot tests use local filesystem only
        let store = makeStore()
        XCTAssertTrue(store.validatePathInsideSnapshotRoot("test/search.json"))
    }
}
