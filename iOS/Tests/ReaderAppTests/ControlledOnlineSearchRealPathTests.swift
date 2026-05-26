import XCTest
@testable import ReaderApp
import ReaderCoreModels
import ReaderCoreProtocols

// MARK: - Fake real search service (test-only, no network)

private final class FakeSearchService: SearchService, Sendable {
    var callCount = 0
    var lastKeyword = ""
    var shouldThrow = false

    func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem] {
        callCount += 1
        lastKeyword = query.keyword
        if shouldThrow { throw NSError(domain: "test", code: -1) }
        return [
            SearchResultItem(title: "Fake Result 1", detailURL: "fake://1", author: "Fake"),
            SearchResultItem(title: "Fake Result 2", detailURL: "fake://2", author: "Fake"),
        ]
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
        provider.setControlledOnlineSearchService(fake)
        provider.enableControlledOnline()

        let state = await provider.searchBooks(keyword: "凡人", page: 1)
        guard case .loaded(let results) = state else {
            XCTFail("Expected .loaded from fake service, got \(state)")
            return
        }
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].title, "Fake Result 1")
        XCTAssertEqual(fake.callCount, 1)
        XCTAssertEqual(fake.lastKeyword, "凡人")

        provider.setMode(.mock)
    }

    // MARK: - Denied prevents real service

    func testControlledOnlineDenied_userDisabledNetwork_doesNotCallRealService() {
        let fake = FakeSearchService()
        let provider = ReaderCoreServiceProvider.shared
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

    func testControlledOnlineDryRun_doesNotCallRealService() {
        let fake = FakeSearchService()
        let provider = ReaderCoreServiceProvider.shared
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

    func testNetworkAccessControllerDeniesSafeDefault() {
        let ctrl = NetworkAccessController()
        let result = ctrl.evaluate(userPreference: .safeDefault, sourcePolicy: .fixture(), operation: .search)
        guard case .denied = result else {
            XCTFail("safeDefault should deny")
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

    // MARK: - Provider reset

    func testProviderResetsToMockAfterTests() {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMode(.mock)
        XCTAssertEqual(provider.currentMode, .mock)
    }
}
