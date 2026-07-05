import XCTest
@testable import ReaderApp
import ReaderUIContract

/// Slice 1 Golden Tests — AppShell + main tabs
///
/// 验证 ReaderReducer 消费 `mainTab.select` 事件后，`AppNavigationState.activeTab`
/// 正确更新，且 `ReaderViewState` 能正确派生 contract `MainTab` 与 `RouteId`。
///
/// 契约对齐（CONTRACT_FIRST_NATIVE_UI_PLAN.md §9 Phase 3 Slice 1）：
/// - 事件：`mainTab.select`
/// - 状态：`UiState.tab`（本地映射为 `AppNavigationState.activeTab`）
/// - 派生：`ReaderViewState.mainTab` / `ReaderViewState.routeId`
@MainActor
final class ReaderReducerSlice1GoldenTests: XCTestCase {

    // MARK: - Golden: mainTab.select(bookshelf)

    func testGolden_mainTabSelect_bookshelf() {
        let nav = AppNavigationState()
        nav.activeTab = .discover // 起始态非 bookshelf
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("bookshelf")]
        ))

        XCTAssertEqual(nav.activeTab, .bookshelf)

        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.mainTab, .bookshelf)
        XCTAssertEqual(vs.routeId, .bookshelf)
    }

    // MARK: - Golden: mainTab.select(discover)

    func testGolden_mainTabSelect_discover() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("discover")]
        ))

        XCTAssertEqual(nav.activeTab, .discover)

        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.mainTab, .discover)
        XCTAssertEqual(vs.routeId, .discover)
    }

    // MARK: - Golden: mainTab.select(rss)

    func testGolden_mainTabSelect_rss() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("rss")]
        ))

        XCTAssertEqual(nav.activeTab, .rss)

        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.mainTab, .rss)
        XCTAssertEqual(vs.routeId, .rss)
    }

    // MARK: - Golden: mainTab.select(settings)

    func testGolden_mainTabSelect_settings() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("settings")]
        ))

        XCTAssertEqual(nav.activeTab, .settings)

        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.mainTab, .settings)
        XCTAssertEqual(vs.routeId, .settings)
    }

    // MARK: - Golden: 重复 select 同一 tab 应无副作用

    func testGolden_mainTabSelect_sameTab_noOp() {
        let nav = AppNavigationState()
        nav.activeTab = .bookshelf
        let reducer = ReaderReducer(navigationState: nav)

        // 重复选 bookshelf，AppNavigationState.switchTab 内部 guard 拦截
        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("bookshelf")]
        ))

        XCTAssertEqual(nav.activeTab, .bookshelf)
    }

    // MARK: - Golden: payload 缺失 tab 字段应静默忽略

    func testGolden_mainTabSelect_missingPayload_ignored() {
        let nav = AppNavigationState()
        nav.activeTab = .bookshelf
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: [:]
        ))

        // 状态不变
        XCTAssertEqual(nav.activeTab, .bookshelf)
    }

    // MARK: - Golden: 非法 tab 值应静默忽略

    func testGolden_mainTabSelect_invalidTab_ignored() {
        let nav = AppNavigationState()
        nav.activeTab = .bookshelf
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("unknown-tab")]
        ))

        // 状态不变
        XCTAssertEqual(nav.activeTab, .bookshelf)
    }

    // MARK: - Golden: route stack minimal behavior

    func testGolden_routePushReplacePop_updatesNativeStackAndViewState() {
        let nav = AppNavigationState()
        nav.activeTab = .bookshelf
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .route_push,
            payload: ["route": AnyCodable("search-home")]
        ))

        XCTAssertEqual(nav.currentRoute, .search)
        XCTAssertEqual(nav.navigationPath, [.search])
        XCTAssertEqual(ReaderViewState(from: nav).routeId, .searchHome)

        reducer.dispatch(UiEvent(
            type: .route_replace,
            payload: ["route": AnyCodable("book-batch-management")]
        ))

        XCTAssertEqual(nav.currentRoute, .bookBatchManagement)
        XCTAssertEqual(nav.navigationPath, [.bookBatchManagement])
        XCTAssertEqual(ReaderViewState(from: nav).routeId, .bookBatchManagement)

        reducer.dispatch(UiEvent(type: .route_pop))

        XCTAssertEqual(nav.currentRoute, .home)
        XCTAssertTrue(nav.navigationPath.isEmpty)
        XCTAssertEqual(ReaderViewState(from: nav).routeId, .bookshelf)
    }

    func testGolden_routePush_mainTabRouteSwitchesTabWithoutStackPush() {
        let nav = AppNavigationState()
        nav.activeTab = .bookshelf
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .route_push,
            payload: ["route": AnyCodable("settings")]
        ))

        XCTAssertEqual(nav.activeTab, .settings)
        XCTAssertTrue(nav.navigationPath.isEmpty)
        XCTAssertEqual(ReaderViewState(from: nav).mainTab, .settings)
        XCTAssertEqual(ReaderViewState(from: nav).routeId, .settings)
    }

    func testGolden_routePush_unknownRoute_ignored() {
        let nav = AppNavigationState()
        nav.activeTab = .bookshelf
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .route_push,
            payload: ["route": AnyCodable("unknown-route")]
        ))

        XCTAssertEqual(nav.activeTab, .bookshelf)
        XCTAssertTrue(nav.navigationPath.isEmpty)
    }

    // MARK: - Golden: AppTab <-> MainTab 桥接一致性

    func testGolden_appTab_mainTab_bridgeConsistency() {
        let pairs: [(AppTab, MainTab, RouteId)] = [
            (.bookshelf, .bookshelf, .bookshelf),
            (.discover,  .discover,  .discover),
            (.rss,       .rss,       .rss),
            (.settings,  .settings,  .settings),
        ]
        for (appTab, mainTab, routeId) in pairs {
            XCTAssertEqual(MainTab(appTab: appTab), mainTab)
            XCTAssertEqual(RouteId(appTab: appTab), routeId)
        }
        XCTAssertEqual(AppTab.contractOrder.map(MainTab.init(appTab:)), MainTab.allCases)
    }

    // MARK: - Golden: ReaderViewState 默认 pageState

    func testGolden_viewState_defaultPageState() {
        let nav = AppNavigationState()
        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.pageState, .defaultValue)
    }

    // MARK: - Golden: overlay/session mutex 起点

    func testGolden_overlayOpenIsSingleSlotAndCloseClearsViewStateOverlay() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(type: .overlay_dialog_open))
        XCTAssertEqual(nav.overlayState, .dialog)
        XCTAssertEqual(ReaderViewState(from: nav).overlay, .dialog)

        reducer.dispatch(UiEvent(type: .overlay_sheet_open))
        XCTAssertEqual(nav.overlayState, .sheet)
        XCTAssertEqual(ReaderViewState(from: nav).overlay, .sheet)

        reducer.dispatch(UiEvent(type: .overlay_sheet_close))
        XCTAssertEqual(nav.overlayState, .none)
        XCTAssertNil(ReaderViewState(from: nav).overlay)
    }

    func testGolden_activeSessionIsSingleSlotAndClearsOverlayOnStart() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(type: .overlay_sheet_open))
        reducer.dispatch(UiEvent(type: .reader_session_ttsStart))

        XCTAssertEqual(nav.activeSession, .tts(playing: true))
        XCTAssertEqual(nav.overlayState, .none)
        XCTAssertEqual(ReaderViewState(from: nav).activeSession, .tts)
        XCTAssertNil(ReaderViewState(from: nav).overlay)

        reducer.dispatch(UiEvent(type: .reader_session_autoPageStart))

        XCTAssertEqual(nav.activeSession, .autoPage(playing: true))
        XCTAssertEqual(ReaderViewState(from: nav).activeSession, .autoPage)

        reducer.dispatch(UiEvent(type: .reader_session_capsuleExit))

        XCTAssertEqual(nav.activeSession, .none)
        XCTAssertNil(ReaderViewState(from: nav).activeSession)
    }

    // MARK: - Golden: reducedMotion bridge

    func testGolden_reducedMotionBridgeUpdatesMotionEnvironmentAndViewState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(type: .reducedMotion_enable))

        XCTAssertTrue(nav.motion.isReducedMotionEnabled)
        XCTAssertTrue(ReaderViewState(from: nav).reducedMotion)
        XCTAssertEqual(
            ReaderMotionAdapter.duration(for: .tab_switch, motion: nav.motion),
            ReaderMotion.Duration.instant,
            accuracy: 0.0001
        )

        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("discover")]
        ))

        XCTAssertEqual(nav.activeTab, .discover)

        reducer.dispatch(UiEvent(type: .reducedMotion_disable))

        XCTAssertFalse(nav.motion.isReducedMotionEnabled)
        XCTAssertFalse(ReaderViewState(from: nav).reducedMotion)
        XCTAssertEqual(
            ReaderMotionAdapter.duration(for: .tab_switch, motion: nav.motion),
            AppMotion.Duration.tabSwitch,
            accuracy: 0.0001
        )
    }

    // MARK: - Golden: focus restore 可测试部分

    func testGolden_focusRestoresToPreviousScopeAfterRoutePop() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .input_focus,
            payload: ["target": AnyCodable("bookshelf.search.button")]
        ))
        XCTAssertEqual(ReaderViewState(from: nav).focusTarget, "bookshelf.search.button")

        reducer.dispatch(UiEvent(
            type: .route_push,
            payload: ["route": AnyCodable("search-home")]
        ))
        XCTAssertNil(ReaderViewState(from: nav).focusTarget)

        reducer.dispatch(UiEvent(
            type: .input_focus,
            payload: ["target": AnyCodable("search.query.field")]
        ))
        XCTAssertEqual(ReaderViewState(from: nav).focusTarget, "search.query.field")

        reducer.dispatch(UiEvent(type: .route_pop))

        XCTAssertEqual(nav.currentRoute, .home)
        XCTAssertEqual(ReaderViewState(from: nav).focusTarget, "bookshelf.search.button")
    }

    func testGolden_inputBlurClearsCurrentFocusScope() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .input_focus,
            payload: ["focusTarget": AnyCodable("bookshelf.search.button")]
        ))
        reducer.dispatch(UiEvent(type: .input_blur))

        XCTAssertNil(nav.focusTarget)
        XCTAssertNil(ReaderViewState(from: nav).focusTarget)
    }
}
