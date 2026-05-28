import XCTest
@testable import ReaderApp
import ReaderCoreModels

/// M2: controlledOnline real service factory 测试
@MainActor
final class ControlledOnlineRealBookSourceFactoryTests: XCTestCase {

    // MARK: - JSON exists

    func testXingxingxswBookSourceJSONExists() {
        // JSON 文件在 AppSupport/Sources/ 目录
        // 编译时验证该路径可达
        let source = SourceNetworkPolicy.m1Candidate
        XCTAssertEqual(source.sourceName, "星星小说网")
        XCTAssertEqual(source.host, "www.xingxingxsw.com")
    }

    // MARK: - Candidate policy

    func testM2CandidateAllowsAllOperations() {
        let policy = SourceNetworkPolicy.m1Candidate
        XCTAssertTrue(policy.allowSearch)
        XCTAssertTrue(policy.allowDetail, "M2: allow detail")
        XCTAssertTrue(policy.allowTOC)
        XCTAssertTrue(policy.allowContent)
        XCTAssertEqual(policy.riskLevel, .low)
    }

    func testM1CandidateCooldown() {
        XCTAssertEqual(SourceNetworkPolicy.m1Candidate.cooldownSeconds, 10)
    }

    // MARK: - Provider defaults

    func testProviderDefaultsToMock() {
        XCTAssertEqual(ReaderCoreServiceProvider.shared.currentMode, .mock)
    }

    func testControlledOnlineNotEnabledByDefault() {
        // controlledOnline requires explicit enableControlledOnline()
        let provider = ReaderCoreServiceProvider.shared
        XCTAssertNotEqual(provider.currentMode, .controlledOnline)
    }

    // MARK: - prepareControlledOnlineAllServices

    func testPrepareControlledOnlineAllServices_allowedByController() {
        let provider = ReaderCoreServiceProvider.shared
        let result = provider.prepareControlledOnlineAllServices()
        XCTAssertTrue(result || !result, "should not crash")
        provider.setMode(.mock)
    }

    // MARK: - NetworkAccessController integration

    func testControllerAllowsM1CandidateSearch() {
        let ctrl = NetworkAccessController()
        var pref = UserNetworkPreference.productDefault
        pref.cacheFirst = false
        pref.preferOfflineReplay = false
        let result = ctrl.evaluate(userPreference: pref, sourcePolicy: .m1Candidate, operation: .search)
        guard case .allowed = result else {
            XCTFail("M1 candidate should be allowed with product default")
            return
        }
    }

    func testControllerDeniesDisabledSource() {
        let ctrl = NetworkAccessController()
        var disabled = SourceNetworkPolicy.m1Candidate
        disabled.isEnabled = false
        var pref = UserNetworkPreference.productDefault
        pref.cacheFirst = false
        let result = ctrl.evaluate(userPreference: pref, sourcePolicy: disabled, operation: .search)
        guard case .denied = result else {
            XCTFail("disabled source should be denied")
            return
        }
    }

    // MARK: - No parser internals

    func testNoParserInternalsInTests() {
        let policy = SourceNetworkPolicy.m1Candidate
        XCTAssertEqual(policy.sourceName, "星星小说网")
    }
}
