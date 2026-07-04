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

    // MARK: - Golden: 非 mainTab.select 事件在 Slice 1 应被忽略

    func testGolden_unhandledEvent_ignored() {
        let nav = AppNavigationState()
        nav.activeTab = .bookshelf
        let reducer = ReaderReducer(navigationState: nav)

        // route.push 在 Slice 1 未实现，应被忽略
        reducer.dispatch(UiEvent(
            type: .route_push,
            payload: ["route": AnyCodable("search-home")]
        ))

        // 状态不变
        XCTAssertEqual(nav.activeTab, .bookshelf)
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
    }

    // MARK: - Golden: ReaderViewState 默认 pageState

    func testGolden_viewState_defaultPageState() {
        let nav = AppNavigationState()
        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.pageState, .defaultValue)
    }
}
