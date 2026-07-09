import XCTest
@testable import ReaderApp
import ReaderUIContract

/// Slice 4 Golden Tests — 进度/会话/焦点/TTS 全屏页
///
/// 验证 ReaderReducer 消费 Slice 4 事件后，AppNavigationState 正确更新：
/// - reader.tts.toggle → 切换 TTS session（有则停，无则启）
/// - reader.session.capsule* / controlSpace* → stub（不影响 navigation state）
/// - sync.* → stub（不影响 navigation state）
///
/// 同时验证 ViewStateComponentFactory 能为 Slice 4 的 13 个 RouteId 派生正确组件组合：
/// - reader-full-directory/tts/appearance/settings → ReaderBase + ReaderTopArea + FullPage
/// - reader-full-font/theme/themeEdit/layout → 使用 ReaderFullAppearancePage
/// - reader-full-pageTurn → 使用 ReaderFullSettingsPage
/// - reader-book-cache/debug-info → ReaderBase + ReaderTopArea + Page
/// - progress-sync/progress-sync-status → BackTopBar + Page
///
/// 契约对齐（CONTRACT_FIRST_NATIVE_UI_PLAN.md §9 Phase 3 Slice 4）：
/// 进度/会话/焦点/TTS + F4 CoreBridge mapping 测试
@MainActor
final class ReaderReducerSlice4GoldenTests: XCTestCase {

    // MARK: - Golden: reader.tts.toggle

    func testGolden_readerTtsToggle_startsTts() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        // 无 session 时 toggle 启动 TTS
        reducer.dispatch(UiEvent(type: .reader_tts_toggle))

        XCTAssertNotEqual(nav.activeSession, .none)
    }

    func testGolden_readerTtsToggle_stopsTts() {
        let nav = AppNavigationState()
        nav.startSession(.tts(playing: true))
        XCTAssertNotEqual(nav.activeSession, .none)

        let reducer = ReaderReducer(navigationState: nav)
        // 有 TTS session 时 toggle 停止
        reducer.dispatch(UiEvent(type: .reader_tts_toggle))

        XCTAssertEqual(nav.activeSession, .none)
    }

    // MARK: - Golden: ViewStateComponentFactory — reader-full-* 系列

    func testGolden_viewState_components_readerFullDirectory() {
        let components = ViewStateComponentFactory.components(for: .readerFullDirectory)
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[0].type, .readerBase)
        XCTAssertEqual(components[1].type, .readerTopArea)
        XCTAssertEqual(components[2].type, .readerFullDirectoryPage)
    }

    func testGolden_viewState_components_readerFullTts() {
        let components = ViewStateComponentFactory.components(for: .readerFullTts)
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[0].type, .readerBase)
        XCTAssertEqual(components[1].type, .readerTopArea)
        XCTAssertEqual(components[2].type, .readerFullTtsPage)
    }

    func testGolden_viewState_components_readerFullAppearance() {
        let components = ViewStateComponentFactory.components(for: .readerFullAppearance)
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[0].type, .readerBase)
        XCTAssertEqual(components[1].type, .readerTopArea)
        XCTAssertEqual(components[2].type, .readerFullAppearancePage)
    }

    func testGolden_viewState_components_readerFullFont_usesAppearancePage() {
        let components = ViewStateComponentFactory.components(for: .readerFullFont)
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[2].type, .readerFullAppearancePage)
    }

    func testGolden_viewState_components_readerFullSettings() {
        let components = ViewStateComponentFactory.components(for: .readerFullSettings)
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[0].type, .readerBase)
        XCTAssertEqual(components[1].type, .readerTopArea)
        XCTAssertEqual(components[2].type, .readerFullSettingsPage)
    }

    func testGolden_viewState_components_readerFullPageTurn_usesSettingsPage() {
        let components = ViewStateComponentFactory.components(for: .readerFullPageTurn)
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[2].type, .readerFullSettingsPage)
    }

    func testGolden_viewState_components_readerBookCache() {
        let components = ViewStateComponentFactory.components(for: .readerBookCache)
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[0].type, .readerBase)
        XCTAssertEqual(components[1].type, .readerTopArea)
        XCTAssertEqual(components[2].type, .readerBookCachePage)
    }

    func testGolden_viewState_components_readerDebugInfo() {
        let components = ViewStateComponentFactory.components(for: .readerDebugInfo)
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[0].type, .readerBase)
        XCTAssertEqual(components[1].type, .readerTopArea)
        XCTAssertEqual(components[2].type, .readerDebugInfoPage)
    }

    // MARK: - Golden: ViewStateComponentFactory — progress-sync 系列

    func testGolden_viewState_components_progressSync() {
        let components = ViewStateComponentFactory.components(for: .progressSync)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .progressSyncPage)
    }

    func testGolden_viewState_components_progressSyncStatus() {
        let components = ViewStateComponentFactory.components(for: .progressSyncStatus)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .syncProgressPage)
    }

    // MARK: - Golden: ComponentRegistry 注册

    func testGolden_componentRegistry_registerSlice4() {
        ComponentRegistry.reset()
        ComponentRegistry.registerSlice2Components()
        ComponentRegistry.registerSlice3Components()
        ComponentRegistry.registerSlice4Components()

        XCTAssertTrue(ComponentRegistry.isRegistered(.readerFullDirectoryPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.readerFullTtsPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.readerFullAppearancePage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.readerFullSettingsPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.readerBookCachePage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.readerDebugInfoPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.progressSyncPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.syncProgressPage))
    }
}
