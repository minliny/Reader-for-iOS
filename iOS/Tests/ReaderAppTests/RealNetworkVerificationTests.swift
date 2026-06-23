import XCTest
@testable import ReaderApp
@testable import ReaderShellValidation

/// 真实网络验证 — 星星小说网 controlledOnline 全链路
/// 用户已授权单次验证
@MainActor
final class RealNetworkVerificationTests: XCTestCase {

    func testSearchRealXingxingxsw() async throws {
        let provider = ReaderCoreServiceProvider.shared

        // 1. 创建 real services
        let ready = provider.prepareControlledOnlineAllServices()
        XCTAssertTrue(ready, "prepareControlledOnlineAllServices failed")

        // 2. 切换到 controlledOnline
        provider.enableControlledOnline()
        XCTAssertEqual(provider.currentMode, .controlledOnline)

        // 3. 执行真实搜索
        let state = await provider.searchBooks(keyword: "凡人", page: 1)
        switch state {
        case .loaded(let results):
            XCTAssertFalse(results.isEmpty, "应返回搜索结果")
            print("[VERIFY] Search SUCCESS: \(results.count) results")
            for r in results {
                print("[VERIFY]   - \(r.title) | \(r.author ?? "?") | \(r.detailURL)")
            }
        case .failed(let err):
            XCTFail("Search failed: \(err.message)")
        case .empty:
            print("[VERIFY] Search returned empty")
        default:
            print("[VERIFY] Unexpected state: \(state)")
        }

        // Reset
        provider.setMode(.mock)
    }
}
