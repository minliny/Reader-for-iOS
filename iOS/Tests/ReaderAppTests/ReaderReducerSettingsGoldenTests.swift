import XCTest
@testable import ReaderApp
import ReaderUIContract

/// Settings Golden Tests — B2 settings 链路闭环
///
/// 验证 ReaderReducer 消费 settings 事件后，AppNavigationState 与 ReaderViewState
/// 正确更新，对齐 state-rule.fixtures.json 中 `settings-overlay-guard-tab-switch` 规则：
/// - open settings → activeTab == .settings，routeId == .settings
/// - push settings sub-page → route.push(.settingsReading)，routeId == .readingSettingsEntry
/// - settings motion 解析：push → .app_route_push_forward；pop → .app_route_pop_backward
/// - settings.overlay.open → overlayState == .dialog（expandedOption 语义）
/// - settings.overlay 展开时禁止 tab 切换（settings-overlay-guard-tab-switch）
/// - settings.overlay.close → overlayState == .none，tab 切换恢复
/// - close settings sub-page → route pop 回退
@MainActor
final class ReaderReducerSettingsGoldenTests: XCTestCase {

    // MARK: - Golden: open settings tab → activeTab == .settings

    func testGolden_settingsOpen_switchesToSettingsTab() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("settings")]
        ))

        XCTAssertEqual(nav.activeTab, .settings)
        XCTAssertTrue(nav.navigationPath.isEmpty)

        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.routeId, .settings)
        XCTAssertEqual(vs.mainTab, .settings)
        XCTAssertFalse(vs.components.isEmpty)
        XCTAssertEqual(vs.components.first?.type, .appTopBar)
    }

    // MARK: - Golden: push settings sub-page → route.push(.settingsReading)

    func testGolden_settingsSubPagePush_setsSettingsReadingRoute() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        // 先切到 settings tab
        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("settings")]
        ))

        // push 阅读设置子页
        reducer.dispatch(UiEvent(
            type: .route_push,
            payload: ["route": AnyCodable("reading-settings-entry")]
        ))

        XCTAssertEqual(nav.navigationPath.count, 1)
        XCTAssertEqual(nav.navigationPath.last, .settingsReading)

        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.routeId, .readingSettingsEntry)
    }

    // MARK: - Golden: settings motion 解析（push → app_route_push_forward）

    func testGolden_settingsShell_push_resolvesToRoutePushForward() {
        let request = MotionRequest(
            operation: .push,
            containerRole: .settingsShell
        )
        let motionId = ReaderMotionAdapter.resolve(request: request)
        XCTAssertEqual(motionId, .app_route_push_forward,
                       "push in settingsShell must resolve to .app_route_push_forward (settings-shell-route-push, priority 150)")
    }

    // MARK: - Golden: settings motion 解析（pop → app_route_pop_backward）

    func testGolden_settingsShell_pop_resolvesToRoutePopBackward() {
        let request = MotionRequest(
            operation: .pop,
            containerRole: .settingsShell
        )
        let motionId = ReaderMotionAdapter.resolve(request: request)
        XCTAssertEqual(motionId, .app_route_pop_backward,
                       "pop in settingsShell must resolve to .app_route_pop_backward (settings-shell-route-pop, priority 150)")
    }

    // MARK: - Golden: settings overlay open → overlayState == .dialog

    func testGolden_settingsOverlayOpen_setsDialogOverlay() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(type: .settings_overlay_open))

        XCTAssertEqual(nav.overlayState, .dialog)

        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.overlay, .dialog)
    }

    // MARK: - Golden: settings-overlay-guard-tab-switch —— overlay 展开时禁止 tab 切换

    func testGolden_settingsOverlayGuard_blocksTabSwitch() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        // 切到 settings tab
        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("settings")]
        ))
        XCTAssertEqual(nav.activeTab, .settings)

        // 展开 settings overlay
        reducer.dispatch(UiEvent(type: .settings_overlay_open))
        XCTAssertEqual(nav.overlayState, .dialog)

        // 尝试切到 bookshelf —— 应被 guard 拒绝
        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("bookshelf")]
        ))

        XCTAssertEqual(nav.activeTab, .settings,
                       "settings-overlay-guard-tab-switch: overlay 展开时禁止 tab 切换")
    }

    // MARK: - Golden: settings.overlay.close → tab 切换恢复

    func testGolden_settingsOverlayClose_restoresTabSwitch() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        // 切到 settings tab + 展开 overlay
        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("settings")]
        ))
        reducer.dispatch(UiEvent(type: .settings_overlay_open))
        XCTAssertEqual(nav.overlayState, .dialog)

        // 关闭 overlay
        reducer.dispatch(UiEvent(type: .settings_overlay_close))
        XCTAssertEqual(nav.overlayState, .none)

        // tab 切换应恢复
        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("bookshelf")]
        ))
        XCTAssertEqual(nav.activeTab, .bookshelf,
                       "settings overlay 关闭后 tab 切换应恢复")
    }

    // MARK: - Golden: close settings sub-page → route pop 回退

    func testGolden_settingsSubPageClose_popsRoute() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        // settings tab + push sub-page
        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("settings")]
        ))
        reducer.dispatch(UiEvent(
            type: .route_push,
            payload: ["route": AnyCodable("reading-settings-entry")]
        ))
        XCTAssertEqual(nav.navigationPath.count, 1)
        XCTAssertEqual(ReaderViewState(from: nav).routeId, .readingSettingsEntry)

        // pop 回退
        reducer.dispatch(UiEvent(type: .route_pop))

        XCTAssertTrue(nav.navigationPath.isEmpty)
        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.routeId, .settings)
    }

    // MARK: - Golden: settings tab switch (settings → bookshelf) without overlay

    func testGolden_settingsTabSwitchWithoutOverlay_succeeds() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("settings")]
        ))
        XCTAssertEqual(nav.activeTab, .settings)

        // 无 overlay 时 tab 切换应成功
        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("bookshelf")]
        ))
        XCTAssertEqual(nav.activeTab, .bookshelf)
    }

    // MARK: - Golden: coordinator.openSettings dispatches settings_overlay_open

    func testGolden_coordinatorOpenSettings_dispatchesOverlayOpen() {
        let nav = AppNavigationState()
        let coordinator = ReaderCoordinator(navigationState: nav)

        coordinator.openSettings()

        XCTAssertEqual(nav.overlayState, .dialog,
                       "coordinator.openSettings should dispatch settings_overlay_open → overlayState == .dialog")
    }
}
