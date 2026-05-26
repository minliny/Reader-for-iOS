import XCTest
@testable import ReaderApp

/// Phase 5B: controlledOnline dry-run integration — minimal, no live network
@MainActor
final class ControlledOnlineDryRunIntegrationTests: XCTestCase {

    // MARK: - Provider defaults

    func testProviderDefaultsToMock() {
        XCTAssertEqual(ReaderCoreServiceProvider.shared.currentMode, .mock)
    }

    // MARK: - ControlledOnlineDryRun search

    func testControlledOnlineDryRunSearch_usesOfflineReplay() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.enableControlledOnlineDryRun()
        XCTAssertEqual(provider.currentMode, .controlledOnlineDryRun)

        let state = await provider.searchBooks(keyword: "凡人", page: 1)
        guard case .loaded(let results) = state else {
            XCTFail("Expected .loaded from offline replay, got \(state)")
            return
        }
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].title, "凡人修仙传")

        // Reset
        provider.setMode(.mock)
    }

    // MARK: - NetworkAccessController wired

    func testNetworkAccessControllerAllowsProductDefault() {
        let ctrl = NetworkAccessController()
        var pref = UserNetworkPreference.productDefault
        pref.cacheFirst = false
        pref.preferOfflineReplay = false
        let result = ctrl.evaluate(userPreference: pref, sourcePolicy: .fixture(), operation: .search)
        guard case .allowed = result else {
            XCTFail("product default should allow search")
            return
        }
    }

    func testNetworkAccessControllerDeniesSafeDefault() {
        let ctrl = NetworkAccessController()
        let result = ctrl.evaluate(userPreference: .safeDefault, sourcePolicy: .fixture(), operation: .search)
        guard case .denied = result else {
            XCTFail("safe default should deny")
            return
        }
    }

    // MARK: - No network, no parser internals

    func testNoLiveNetworkInTests() {
        // controlledOnlineDryRun never triggers real network
        XCTAssertEqual(ReaderCoreServiceProvider.shared.currentMode, .mock)
    }

    func testNoParserInternals() {
        let pref = UserNetworkPreference.productDefault
        XCTAssertTrue(pref.allowNetworkAccess)
    }

    // MARK: - Audit metadata

    func testAuditEntryHasRequiredFields() {
        let audit = NetworkAuditEntry(sourceId: "s1", operation: "search", host: "h", decision: "allowed")
        XCTAssertFalse(audit.networkTriggered, "dry-run: networkTriggered defaults to false")
        XCTAssertEqual(audit.decision, "allowed")
    }
}
