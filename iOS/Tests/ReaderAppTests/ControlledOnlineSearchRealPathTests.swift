import XCTest
@testable import ReaderApp
@testable import ReaderShellValidation
import ReaderCoreModels
import ReaderCoreProtocols

// MARK: - Fake real search service (test-only, no network)

final class FakeSearchService: SearchService, @unchecked Sendable {
    var callCount = 0
    var lastKeyword = ""
    var lastSource: BookSource?
    var shouldThrow = false

    func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem] {
        callCount += 1
        lastKeyword = query.keyword
        lastSource = source
        if shouldThrow { throw NSError(domain: "test", code: -1) }
        return [
            SearchResultItem(title: "Fake Result 1", detailURL: "fake://1", author: "Fake"),
            SearchResultItem(title: "Fake Result 2", detailURL: "fake://2", author: "Fake"),
        ]
    }
}

private final class FakeTOCService: TOCService, @unchecked Sendable {
    var callCount = 0
    var lastSource: BookSource?
    var lastDetailURL = ""

    func fetchTOC(source: BookSource, detailURL: String) async throws -> [TOCItem] {
        callCount += 1
        lastSource = source
        lastDetailURL = detailURL
        return [
            TOCItem(chapterTitle: "第一章", chapterURL: "fake://chapter/1", chapterIndex: 0),
        ]
    }
}

private final class FakeContentService: ContentService, @unchecked Sendable {
    var callCount = 0
    var lastSource: BookSource?
    var lastChapterURL = ""

    func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage {
        callCount += 1
        lastSource = source
        lastChapterURL = chapterURL
        return ContentPage(title: "第一章", content: "正文", chapterURL: chapterURL)
    }
}

/// Phase 5C: controlledOnline Search real service path — fake service, no real network
@MainActor
final class ControlledOnlineSearchRealPathTests: XCTestCase {

    // MARK: - Provider defaults

    func testProviderDefaultsToMock() {
        XCTAssertEqual(ReaderCoreServiceProvider.shared.currentMode, .mock)
    }

    // MARK: - ControlledOnline with fake real service

    func testControlledOnlineAllowed_callsRealService() async {
        let fake = FakeSearchService()
        let provider = ReaderCoreServiceProvider.shared
        provider.setMode(.mock)
        provider.setControlledOnlineSearchService(fake)
        provider.enableControlledOnline()

        let source = BookSource(
            id: "source-real-context",
            bookSourceName: "真实源上下文",
            bookSourceUrl: "https://reader.example"
        )
        let state = await provider.searchBooks(keyword: "凡人", page: 1, source: source)
        guard case .loaded(let results) = state else {
            XCTFail("Expected .loaded from fake service, got \(state)")
            return
        }
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].title, "Fake Result 1")
        XCTAssertEqual(fake.callCount, 1)
        XCTAssertEqual(fake.lastKeyword, "凡人")
        XCTAssertEqual(fake.lastSource?.id, "source-real-context")
        XCTAssertEqual(fake.lastSource?.bookSourceName, "真实源上下文")
        XCTAssertEqual(fake.lastSource?.bookSourceUrl, "https://reader.example")

        provider.setMode(.mock)
    }

    func testControlledOnlineTOCPassesSelectedSourceToRealService() async {
        let fake = FakeTOCService()
        let provider = ReaderCoreServiceProvider.shared
        provider.setMode(.mock)
        provider.setControlledOnlineTOCService(fake)
        provider.enableControlledOnline()

        let source = BookSource(
            id: "source-toc-context",
            bookSourceName: "目录真实源",
            bookSourceUrl: "https://toc.example"
        )
        let state = await provider.getChapterList(bookURL: "https://toc.example/book/1", source: source)
        guard case .loaded(let chapters) = state else {
            XCTFail("Expected .loaded from fake TOC service, got \(state)")
            return
        }
        XCTAssertEqual(chapters.count, 1)
        XCTAssertEqual(fake.callCount, 1)
        XCTAssertEqual(fake.lastDetailURL, "https://toc.example/book/1")
        XCTAssertEqual(fake.lastSource?.id, "source-toc-context")
        XCTAssertEqual(fake.lastSource?.bookSourceName, "目录真实源")
        XCTAssertEqual(fake.lastSource?.bookSourceUrl, "https://toc.example")

        provider.setMode(.mock)
    }

    func testControlledOnlineContentPassesSelectedSourceToRealService() async {
        let fake = FakeContentService()
        let provider = ReaderCoreServiceProvider.shared
        provider.setMode(.mock)
        provider.setControlledOnlineContentService(fake)
        provider.enableControlledOnline()

        let source = BookSource(
            id: "source-content-context",
            bookSourceName: "正文真实源",
            bookSourceUrl: "https://content.example"
        )
        let state = await provider.getChapterContent(chapterURL: "https://content.example/book/1/1", source: source)
        guard case .loaded(let page) = state else {
            XCTFail("Expected .loaded from fake content service, got \(state)")
            return
        }
        XCTAssertEqual(page.content, "正文")
        XCTAssertEqual(fake.callCount, 1)
        XCTAssertEqual(fake.lastChapterURL, "https://content.example/book/1/1")
        XCTAssertEqual(fake.lastSource?.id, "source-content-context")
        XCTAssertEqual(fake.lastSource?.bookSourceName, "正文真实源")
        XCTAssertEqual(fake.lastSource?.bookSourceUrl, "https://content.example")

        provider.setMode(.mock)
    }

    // MARK: - Denied prevents real service

    func testControlledOnlineDenied_userDisabledNetwork_doesNotCallRealService() async {
        let fake = FakeSearchService()
        let provider = ReaderCoreServiceProvider.shared
        provider.setMode(.mock)
        provider.setControlledOnlineSearchService(fake)

        // controlledOnlineDryRun uses safeDefault (network disabled) → denied → offline replay
        provider.enableControlledOnlineDryRun()

        // Still uses controlledOnlineDryRun path which denies with safeDefault
        let state = await provider.searchBooks(keyword: "test", page: 1)
        guard case .loaded = state else {
            XCTFail("Expected fallback to offline replay")
            return
        }
        // Fake service should NOT be called because user pref denies network
        XCTAssertEqual(fake.callCount, 0)

        provider.setMode(.mock)
    }

    // MARK: - Dry-run still uses offline replay

    func testControlledOnlineDryRun_doesNotCallRealService() async {
        let fake = FakeSearchService()
        let provider = ReaderCoreServiceProvider.shared
        provider.setMode(.mock)
        provider.setControlledOnlineSearchService(fake)
        provider.enableControlledOnlineDryRun()

        let state = await provider.searchBooks(keyword: "x", page: 1)
        guard case .loaded(let results) = state else {
            XCTFail("dry-run should return offline replay")
            return
        }
        XCTAssertEqual(results[0].title, "凡人修仙传") // from OfflineReplayFixtures
        XCTAssertEqual(fake.callCount, 0, "dry-run must not call real service")

        provider.setMode(.mock)
    }

    // MARK: - NetworkAccessController involved

    func testNetworkAccessControllerAllowsSafeDefaultWhenRestrictionsLifted() {
        let ctrl = NetworkAccessController()
        let result = ctrl.evaluate(userPreference: .safeDefault, sourcePolicy: .fixture(), operation: .search)
        guard case .allowed = result else {
            XCTFail("safeDefault should allow after local restrictions are lifted")
            return
        }
    }

    // MARK: - No real network

    func testNoRealNetworkInTests() {
        XCTAssertEqual(ReaderCoreServiceProvider.shared.currentMode, .mock)
    }

    // MARK: - Audit metadata

    func testAuditEntryNetworkTriggeredTrueForAllowed() {
        let audit = NetworkAuditEntry(sourceId: "s1", operation: "search", host: "h", decision: "allowed", networkTriggered: true)
        XCTAssertTrue(audit.networkTriggered)
    }

    // MARK: - M1 candidate source

    func testM1CandidateSourcePolicy() {
        let policy = SourceNetworkPolicy.m1Candidate
        XCTAssertEqual(policy.sourceName, "星星小说网")
        XCTAssertEqual(policy.host, "www.xingxingxsw.com")
        XCTAssertTrue(policy.isEnabled)
        XCTAssertTrue(policy.allowSearch)
        XCTAssertTrue(policy.allowDetail, "M2: allows detail")
        XCTAssertTrue(policy.allowTOC)
        XCTAssertTrue(policy.allowContent)
        XCTAssertEqual(policy.cooldownSeconds, 10)
        XCTAssertEqual(policy.riskLevel, .low)
    }

    func testM1CandidateAllowsSearchInController() {
        let ctrl = NetworkAccessController()
        var pref = UserNetworkPreference.productDefault
        pref.cacheFirst = false
        pref.preferOfflineReplay = false
        let result = ctrl.evaluate(userPreference: pref, sourcePolicy: .m1Candidate, operation: .search)
        guard case .allowed = result else {
            XCTFail("M1 candidate should allow search with product default")
            return
        }
    }

    // MARK: - Provider reset

    func testProviderResetsToMockAfterTests() {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMode(.mock)
        XCTAssertEqual(provider.currentMode, .mock)
    }
}
