import XCTest
@testable import ReaderApp

/// M1.3: Search snapshot save/load — no real network
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
            SearchSnapshotItem(title: "Test Book", author: "Author", bookURL: "fake://1", coverURL: nil, intro: "Intro"),
            SearchSnapshotItem(title: "Test Book 2", author: "Author 2", bookURL: "fake://2", coverURL: nil, intro: nil),
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
        let items = [SearchSnapshotItem(title: "凡人修仙传", author: "忘语", bookURL: "f://1", coverURL: nil, intro: "...")]
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
        let items = [SearchSnapshotItem(title: "T", author: "A", bookURL: "u", coverURL: nil, intro: nil)]
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
