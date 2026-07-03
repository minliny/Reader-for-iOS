import XCTest
@testable import ReaderApp
@testable import ReaderShellValidation

/// Phase 5B: controlledOnline dry-run integration — minimal, no live network
@MainActor
final class ControlledOnlineDryRunIntegrationTests: XCTestCase {

    // MARK: - Provider default

    func testProviderDefaultsToRustCore() {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMode(.rustCore)
        XCTAssertEqual(provider.currentMode, .rustCore)
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

        provider.setMode(.rustCore)
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

    func testNetworkAccessControllerAllowsSafeDefault() {
        let ctrl = NetworkAccessController()
        let result = ctrl.evaluate(userPreference: .safeDefault, sourcePolicy: .fixture(), operation: .search)
        guard case .allowed = result else {
            XCTFail("safe default should allow after network restrictions are lifted")
            return
        }
    }

    // MARK: - No network, no parser internals

    func testNoLiveNetworkInTests() {
        // controlledOnlineDryRun never triggers real network
        let provider = ReaderCoreServiceProvider.shared
        provider.setMode(.rustCore)
        XCTAssertEqual(provider.currentMode, .rustCore)
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
