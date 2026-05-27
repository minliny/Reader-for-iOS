import XCTest
@testable import ReaderApp
import ReaderCoreModels

/// M1.4: Search UI 展示 controlledOnline results — no real network
@MainActor
final class SearchControlledResultsUITests: XCTestCase {

    // MARK: - Source list includes M1 candidate

    func testLoadSourcesIncludesM1Candidate() async {
        let vm = SearchViewModel()
        await vm.loadSources()
        let m1 = vm.sources.first { $0.id == "candidate-xingxingxsw" }
        XCTAssertNotNil(m1, "M1 candidate should be in source list")
        XCTAssertEqual(m1?.bookSourceName, "⭐ 星星小说网")
    }

    func testM1CandidateSelectedByDefault() async {
        let vm = SearchViewModel()
        await vm.loadSources()
        XCTAssertNotNil(vm.selectedSource)
        XCTAssertEqual(vm.selectedSource?.id, "candidate-xingxingxsw")
    }

    // MARK: - ControlledOnline results flow through

    func testControlledOnlineShowsFakeResults() async {
        let fake = FakeSearchService()
        let provider = ReaderCoreServiceProvider.shared
        provider.setControlledOnlineSearchService(fake)
        provider.enableControlledOnline()

        let state = await provider.searchBooks(keyword: "凡人", page: 1)
        guard case .loaded(let results) = state else {
            XCTFail("Expected loaded, got \(state)")
            return
        }
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].title, "Fake Result 1")

        provider.setMode(.mock)
    }

    // MARK: - Snapshot-loaded results

    func testSnapshotLoadedResultsDisplayable() {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("snap_test_\(UUID().uuidString)")
        let store = SnapshotStore(snapshotRoot: root)
        let items = [SearchSnapshotItem(title: "快照测试书", author: "作者", bookURL: "s://1", coverURL: nil, intro: "简介")]
        _ = store.saveSearchSnapshot(sourceId: "c001", sourceName: "星星小说网", host: "h", keyword: "测试", results: items, networkTriggered: true)
        let snap = store.loadSearchSnapshot(candidateId: "c001")
        XCTAssertNotNil(snap)
        XCTAssertEqual(snap?.results[0].title, "快照测试书")
    }

    // MARK: - Denied fallback

    func testDeniedFallsBackToOfflineReplay() async {
        // safeDefault denies network → controlledOnlineDryRun uses offline replay
        let provider = ReaderCoreServiceProvider.shared
        provider.enableControlledOnlineDryRun()
        let state = await provider.searchBooks(keyword: "x", page: 1)
        guard case .loaded = state else {
            XCTFail("Expected offline replay fallback, got \(state)")
            return
        }
        provider.setMode(.mock)
    }

    // MARK: - Provider defaults

    func testProviderDefaultsToMock() {
        XCTAssertEqual(ReaderCoreServiceProvider.shared.currentMode, .mock)
    }

    // MARK: - Results have expected fields

    func testResultItemsHaveTitleAuthorSource() async {
        let fake = FakeSearchService()
        let provider = ReaderCoreServiceProvider.shared
        provider.setControlledOnlineSearchService(fake)
        provider.enableControlledOnline()

        let state = await provider.searchBooks(keyword: "x", page: 1)
        guard case .loaded(let results) = state else { XCTFail(); return }
        XCTAssertFalse(results[0].title.isEmpty)
        XCTAssertEqual(results[0].author, "Fake")

        provider.setMode(.mock)
    }
}
