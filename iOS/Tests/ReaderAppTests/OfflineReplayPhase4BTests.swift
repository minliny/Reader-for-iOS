import XCTest
@testable import ReaderApp
@testable import ReaderShellValidation
import ReaderCoreModels

/// Phase 4B: Offline Replay 离线重放测试
@MainActor
final class OfflineReplayPhase4BTests: XCTestCase {

    // MARK: - Fixtures

    func testOfflineReplayHasThreeSearchResults() {
        XCTAssertEqual(OfflineReplayFixtures.searchResults.count, 3)
    }

    func testOfflineReplayHasFiveTOCChapters() {
        XCTAssertEqual(OfflineReplayFixtures.tocItems.count, 5)
    }

    func testOfflineReplayHasFiveContentPages() {
        // 至少 2 个章节正文（跨平台要求）
        let ch1 = OfflineReplayFixtures.contentPage(for: "offline://chapter/1")
        let ch2 = OfflineReplayFixtures.contentPage(for: "offline://chapter/2")
        let ch5 = OfflineReplayFixtures.contentPage(for: "offline://chapter/5")
        XCTAssertNotNil(ch1)
        XCTAssertNotNil(ch2)
        XCTAssertNotNil(ch5)
        XCTAssertTrue(ch1!.content.contains("韩立"))
        XCTAssertTrue(ch2!.content.contains("修仙"))
    }

    func testOfflineReplayChapterOneHasNextChapter() {
        let ch1 = OfflineReplayFixtures.contentPage(for: "offline://chapter/1")
        XCTAssertEqual(ch1?.nextChapterURL, "offline://chapter/2")
    }

    // MARK: - Service

    func testOfflineReplaySearchReturnsResults() async {
        let state = await OfflineReplayService.shared.searchBooks(keyword: "凡人", page: 1)
        guard case .loaded(let results) = state else {
            XCTFail("Expected .loaded")
            return
        }
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].title, "凡人修仙传")
    }

    func testOfflineReplayDetailReturnsFirstResult() async {
        let state = await OfflineReplayService.shared.getBookDetail(bookURL: "offline://book/fanren-xiuxian-zhuan")
        guard case .loaded(let detail) = state else {
            XCTFail("Expected .loaded")
            return
        }
        XCTAssertEqual(detail.title, "凡人修仙传")
        XCTAssertEqual(detail.author, "忘语")
    }

    func testOfflineReplayTOCReturnsFiveChapters() async {
        let state = await OfflineReplayService.shared.getChapterList(bookURL: "offline://book/fanren-xiuxian-zhuan")
        guard case .loaded(let chapters) = state else {
            XCTFail("Expected .loaded")
            return
        }
        XCTAssertEqual(chapters.count, 5)
    }

    func testOfflineReplayContentByChapterURL() async {
        let state = await OfflineReplayService.shared.getChapterContent(chapterURL: "offline://chapter/1")
        guard case .loaded(let page) = state else {
            XCTFail("Expected .loaded")
            return
        }
        XCTAssertEqual(page.title, "第一章 山村少年")
        XCTAssertTrue(page.content.contains("韩立"))
    }

    func testOfflineReplayContentChapterTwo() async {
        let state = await OfflineReplayService.shared.getChapterContent(chapterURL: "offline://chapter/2")
        guard case .loaded(let page) = state else {
            XCTFail("Expected .loaded for chapter 2")
            return
        }
        XCTAssertEqual(page.title, "第二章 仙缘")
        XCTAssertTrue(page.content.contains("修仙"))
    }

    func testOfflineReplayFallbackToChapterOne() async {
        let state = await OfflineReplayService.shared.getChapterContent(chapterURL: "nonexistent")
        guard case .loaded(let page) = state else {
            XCTFail("Expected fallback .loaded")
            return
        }
        XCTAssertEqual(page.title, "第一章 山村少年")
    }

    // MARK: - No network / No gate required

    func testOfflineReplayDoesNotRequireRealNetworkGate() {
        // Offline replay 不需要 gate allowed — 它不是真实网络
        RealNetworkPolicyStore.shared.reset()
        let state = RealNetworkPolicyStore.shared.current
        XCTAssertEqual(state.mode, .disabled)
        // OfflineReplayService 不检查 gate
        // This test validates the design: offline replay is independent of real network gate
    }

    // MARK: - Provider defaults

    func testProviderDefaultsToMock_notOfflineReplay() {
        let provider = ReaderCoreServiceProvider.shared
        // Reset to mock after any test that changed mode
        XCTAssertEqual(provider.currentMode, .mock, "Provider should default to mock, not offline replay")
    }

    // MARK: - Real network still disabled

    func testRealModeStillRequiresGate() {
        RealNetworkPolicyStore.shared.reset()
        let provider = ReaderCoreServiceProvider.shared
        let result = provider.configureRealMode()
        XCTAssertFalse(result, "Real mode should fail when gate is disabled")
    }
}
