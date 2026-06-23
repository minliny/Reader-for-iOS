import XCTest
@testable import ReaderApp
import ReaderAppPersistence
@testable import ReaderShellValidation
import ReaderCoreModels
import ReaderCoreProtocols

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
        let items = [SearchSnapshotItem(from: SearchResultItem(title: "快照测试书", detailURL: "s://1", author: "作者", intro: "简介"))]
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

    // MARK: - Multi-source search

    func testSearchViewModelAggregatesAllEnabledSourcesAndBindsResultSources() async throws {
        let sourceA = BookSource(id: "source-a", bookSourceName: "源 A", bookSourceUrl: "https://a.example")
        let sourceB = BookSource(id: "source-b", bookSourceName: "源 B", bookSourceUrl: "https://b.example")
        let store = BookSourceStore(storageURL: tempBookSourceStoreURL())
        try await store.save([sourceA, sourceB])

        let fake = MultiSourceFakeSearchService(resultsBySourceId: [
            "source-a": [
                SearchResultItem(title: "重复书", detailURL: "https://a.example/book/same", author: "作者"),
                SearchResultItem(title: "A 独有", detailURL: "https://a.example/book/a", author: "作者 A")
            ],
            "source-b": [
                SearchResultItem(title: "重复书", detailURL: "https://b.example/book/same", author: "作者"),
                SearchResultItem(title: "B 独有", detailURL: "https://b.example/book/b", author: "作者 B")
            ]
        ], delaysBySourceId: [
            "source-a": 80_000_000,
            "source-b": 10_000_000
        ])
        let provider = ReaderCoreServiceProvider.shared
        provider.setMode(.mock)
        provider.setControlledOnlineSearchService(fake)
        provider.enableControlledOnline()

        let vm = SearchViewModel(store: store, provider: provider)
        await vm.loadSources()
        vm.selectAllEnabledSources()
        vm.keyword = "重复"
        await vm.search()

        guard case .success(let results) = vm.searchState else {
            XCTFail("Expected aggregated success, got \(vm.searchState)")
            provider.setMode(.mock)
            return
        }
        XCTAssertEqual(Set(fake.callSourceIds), Set(["source-a", "source-b"]))
        XCTAssertGreaterThanOrEqual(fake.maxInFlight, 2)
        XCTAssertEqual(results.map(\.title), ["重复书", "A 独有", "B 独有"])
        XCTAssertEqual(vm.source(for: results[0])?.id, "source-a")
        XCTAssertEqual(vm.source(for: results[2])?.id, "source-b")

        provider.setMode(.mock)
    }

    func testSearchViewModelReturnsPartialWhenOneEnabledSourceFails() async throws {
        let good = BookSource(id: "good-source", bookSourceName: "可用源", bookSourceUrl: "https://good.example")
        let bad = BookSource(id: "bad-source", bookSourceName: "失败源", bookSourceUrl: "https://bad.example")
        let store = BookSourceStore(storageURL: tempBookSourceStoreURL())
        try await store.save([good, bad])

        let fake = MultiSourceFakeSearchService(
            resultsBySourceId: [
                "good-source": [
                    SearchResultItem(title: "可用结果", detailURL: "https://good.example/book/1", author: "作者")
                ]
            ],
            failingSourceIds: ["bad-source"]
        )
        let provider = ReaderCoreServiceProvider.shared
        provider.setMode(.mock)
        provider.setControlledOnlineSearchService(fake)
        provider.enableControlledOnline()

        let vm = SearchViewModel(store: store, provider: provider)
        await vm.loadSources()
        vm.selectAllEnabledSources()
        vm.keyword = "测试"
        await vm.search()

        guard case .partial(let results, let warnings) = vm.searchState else {
            XCTFail("Expected partial results, got \(vm.searchState)")
            provider.setMode(.mock)
            return
        }
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "可用结果")
        XCTAssertTrue(warnings.joined(separator: "\n").contains("失败源"))
        XCTAssertEqual(vm.source(for: results[0])?.id, "good-source")

        provider.setMode(.mock)
    }

    private func tempBookSourceStoreURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("readerapp_multi_source_\(UUID().uuidString).json")
    }
}

private final class MultiSourceFakeSearchService: SearchService, @unchecked Sendable {
    private let resultsBySourceId: [String: [SearchResultItem]]
    private let failingSourceIds: Set<String>
    private let delaysBySourceId: [String: UInt64]
    private let lock = NSLock()
    private var recordedCallSourceIds: [String] = []
    private var inFlightCount = 0
    private var recordedMaxInFlight = 0

    var callSourceIds: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recordedCallSourceIds
    }

    var maxInFlight: Int {
        lock.lock()
        defer { lock.unlock() }
        return recordedMaxInFlight
    }

    init(
        resultsBySourceId: [String: [SearchResultItem]],
        failingSourceIds: Set<String> = [],
        delaysBySourceId: [String: UInt64] = [:]
    ) {
        self.resultsBySourceId = resultsBySourceId
        self.failingSourceIds = failingSourceIds
        self.delaysBySourceId = delaysBySourceId
    }

    func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem] {
        let sourceId = source.id ?? source.bookSourceName
        recordStart(sourceId)
        defer { recordFinish() }

        if let delay = delaysBySourceId[sourceId], delay > 0 {
            try? await Task.sleep(nanoseconds: delay)
        }

        if failingSourceIds.contains(sourceId) {
            throw NSError(domain: "multi-source-test", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "source failed"
            ])
        }
        return resultsBySourceId[sourceId] ?? []
    }

    private func recordStart(_ sourceId: String) {
        lock.lock()
        defer { lock.unlock() }
        recordedCallSourceIds.append(sourceId)
        inFlightCount += 1
        recordedMaxInFlight = max(recordedMaxInFlight, inFlightCount)
    }

    private func recordFinish() {
        lock.lock()
        defer { lock.unlock() }
        inFlightCount -= 1
    }
}
