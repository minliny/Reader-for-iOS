import XCTest
@testable import ReaderApp

/// M2-B: Detail/Content snapshot save/load
final class DetailContentSnapshotM2BTests: XCTestCase {
    var root: URL!

    override func setUp() { root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("m2b_\(UUID().uuidString)") }
    func makeStore() -> SnapshotStore { SnapshotStore(snapshotRoot: root) }

    // MARK: - Detail snapshot

    func testDetailSnapshotSaveAndLoad() {
        let store = makeStore()
        let result = store.saveDetailSnapshot(sourceId: "c001", sourceName: "星星小说网", host: "h", bookURL: "b", title: "凡人修仙传", author: "忘语", intro: "...", coverURL: nil)
        guard case .success = result else { XCTFail("save failed"); return }
        let snap = store.loadDetailSnapshot(candidateId: "c001")
        XCTAssertNotNil(snap)
        XCTAssertEqual(snap?.title, "凡人修仙传")
        XCTAssertEqual(snap?.author, "忘语")
    }

    func testDetailSnapshotLoadMissing() {
        let snap = makeStore().loadDetailSnapshot(candidateId: "nonexistent")
        XCTAssertNil(snap)
    }

    // MARK: - Content snapshot

    func testContentSnapshotSaveAndLoad() {
        let store = makeStore()
        let result = store.saveContentSnapshot(sourceId: "c001", sourceName: "星星小说网", host: "h", chapterURL: "c1", chapterTitle: "第一章", content: "韩立...", nextChapterURL: "c2")
        guard case .success = result else { XCTFail("save failed"); return }
        let snap = store.loadContentSnapshot(candidateId: "c001")
        XCTAssertNotNil(snap)
        XCTAssertEqual(snap?.chapterTitle, "第一章")
        XCTAssertTrue(snap?.content.contains("韩立") == true)
    }

    func testContentSnapshotLoadMissing() {
        XCTAssertNil(makeStore().loadContentSnapshot(candidateId: "nonexistent"))
    }

    // MARK: - Path safety

    func testPathSafety() {
        let store = makeStore()
        XCTAssertTrue(store.validatePathInsideSnapshotRoot("c001/detail.json"))
        XCTAssertFalse(store.validatePathInsideSnapshotRoot("../etc/passwd"))
    }

    // MARK: - Provider defaults

    func testProviderDefaultsToMock() {
        XCTAssertEqual(ReaderCoreServiceProvider.shared.currentMode, .mock)
    }
}
