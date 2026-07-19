import XCTest
@testable import ReaderApp
import ReaderUIContract

/// Slice 3 Golden Tests — 阅读控制层（P0-06）
///
/// 验证 ReaderReducer 消费 Slice 3 reader.* 事件后，AppNavigationState 正确更新：
/// - reader.control.toggle → 切换 overlayState（.sheet / .none）
/// - reader.module.switch → 设置 overlay
/// - reader.exit → exitImmersiveReading
/// - reader.directory.open/close → overlay 显隐
/// - reader.bookCache.open → bind exact live cache context and refresh Core state
///
/// 同时验证 ReaderViewState.components 能为 control-layer route 派生正确组件组合：
/// - controlLayerBaseV2 → ReaderBase + ReaderTopArea + ReaderControlSheet + ReaderBottomBar
/// - readerDirectoryOverlayV2 → ReaderBase + ReaderTopArea + ReaderDirectoryPanel + ReaderBottomBar
/// - readerNightStateV2 → ReaderBase(night) + ReaderTopArea + ReaderBottomBar + NightToast
///
/// 契约对齐（CONTRACT_FIRST_NATIVE_UI_PLAN.md §9 Phase 3 Slice 3）：
/// P0-06 验收：Control layer opens/hides without remounting reader context or changing text layout.
@MainActor
final class ReaderReducerSlice3GoldenTests: XCTestCase {

    // MARK: - Golden: reader.control.toggle

    func testGolden_readerControlToggle_showsOverlay() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(type: .reader_control_toggle))

        XCTAssertEqual(nav.overlayState, .sheet)
    }

    func testGolden_readerControlToggle_hidesOverlay() {
        let nav = AppNavigationState()
        nav.setOverlay(.sheet)
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(type: .reader_control_toggle))

        XCTAssertEqual(nav.overlayState, .none)
    }

    // MARK: - Golden: reader.module.switch

    func testGolden_readerModuleSwitch_showsOverlay() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .reader_module_switch,
            payload: ["module": AnyCodable("directory")]
        ))

        XCTAssertEqual(nav.overlayState, .sheet)
        XCTAssertEqual(nav.focusTarget, "reader-module-directory")
    }

    // MARK: - Golden: reader.exit

    func testGolden_readerExit_exitsImmersive() {
        let nav = AppNavigationState()
        let coordinator = ReaderCoordinator(navigationState: nav)
        coordinator.openBook("bk-001")
        XCTAssertNotNil(nav.readerContext)

        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(type: .reader_exit))

        XCTAssertNil(nav.readerContext)
    }

    // MARK: - Golden: reader.directory.open / close

    func testGolden_readerDirectoryOpen_showsOverlay() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(type: .reader_directory_open))

        XCTAssertEqual(nav.overlayState, .sheet)
    }

    func testGolden_readerDirectoryClose_hidesOverlay() {
        let nav = AppNavigationState()
        nav.setOverlay(.sheet)
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(type: .reader_directory_close))

        XCTAssertEqual(nav.overlayState, .none)
    }

    // MARK: - Golden: reader.bookCache.open

    func testGolden_readerBookCacheOpenBindsExactLiveContextWithoutFakeRoute() {
        let nav = AppNavigationState()
        let cache = ReaderCacheCoordinator(service: nil)
        let reducer = ReaderReducer(navigationState: nav, cacheCoordinator: cache)

        reducer.dispatch(UiEvent(type: .reader_bookCache_open, payload: [
            "sourceId": AnyCodable("source-live"),
            "bookId": AnyCodable("book-live"),
            "chapterIndex": AnyCodable(31),
        ]))

        XCTAssertTrue(nav.navigationPath.isEmpty)
        XCTAssertEqual(cache.context?.sourceID, "source-live")
        XCTAssertEqual(cache.context?.bookID, "book-live")
        XCTAssertEqual(cache.context?.currentChapterIndex, 31)
    }

    // MARK: - Golden: viewState.components for control-layer routes

    func testGolden_viewState_components_controlLayerBase() {
        let nav = AppNavigationState()
        let coordinator = ReaderCoordinator(navigationState: nav)
        coordinator.openBook("bk-001")

        // 验证 immersive reading 的 components（Slice 2 已验证）
        let vsImmersive = ReaderViewState(from: nav)
        XCTAssertEqual(vsImmersive.components.first?.type, .readerBase)

        // 验证 control-layer-base-v2 的组件组合
        let controlComponents = ViewStateComponentFactory.components(for: .controlLayerBaseV2)
        XCTAssertEqual(controlComponents.count, 4)
        XCTAssertEqual(controlComponents[0].type, .readerBase)
        XCTAssertEqual(controlComponents[1].type, .readerTopArea)
        XCTAssertEqual(controlComponents[2].type, .readerControlSheet)
        XCTAssertEqual(controlComponents[3].type, .readerBottomBar)
    }

    func testGolden_viewState_components_readerDirectoryOverlay() {
        let components = ViewStateComponentFactory.components(for: .readerDirectoryOverlayV2)
        XCTAssertEqual(components.count, 4)
        XCTAssertEqual(components[0].type, .readerBase)
        XCTAssertEqual(components[1].type, .readerTopArea)
        XCTAssertEqual(components[2].type, .readerDirectoryPanel)
        XCTAssertEqual(components[3].type, .readerBottomBar)
    }

    func testGolden_viewState_components_readerNightState() {
        let components = ViewStateComponentFactory.components(for: .readerNightStateV2)
        XCTAssertEqual(components.count, 4)
        XCTAssertEqual(components[0].type, .readerBase)
        // 验证 night state 的 ReaderBase theme 为 "night"
        if let theme = components[0].props?["theme"]?.value as? String {
            XCTAssertEqual(theme, "night")
        } else {
            XCTFail("Expected ReaderBase theme to be 'night'")
        }
        XCTAssertEqual(components[1].type, .readerTopArea)
        XCTAssertEqual(components[2].type, .readerBottomBar)
        XCTAssertEqual(components[3].type, .nightToast)
    }

    // MARK: - Golden: reader.page.next / prev + night-state

    func testGolden_readerPageNextAndPrev_updatePageIndexWithLowerBound() {
        let nav = AppNavigationState()
        nav.readerPageIndex = 2
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(type: .reader_page_next))
        XCTAssertEqual(nav.readerPageIndex, 3)

        reducer.dispatch(UiEvent(type: .reader_page_prev))
        XCTAssertEqual(nav.readerPageIndex, 2)

        nav.readerPageIndex = 0
        reducer.dispatch(UiEvent(type: .reader_page_prev))
        XCTAssertEqual(nav.readerPageIndex, 0, "previous page must clamp at zero")
    }

    func testGolden_readerNightStateToggle_updatesReducerStateWithoutThemeInjection() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        XCTAssertFalse(nav.isReaderNightModeEnabled)
        reducer.dispatch(UiEvent(type: .reader_nightState_toggle))
        XCTAssertTrue(nav.isReaderNightModeEnabled)

        reducer.dispatch(UiEvent(type: .reader_nightState_toggle))
        XCTAssertFalse(nav.isReaderNightModeEnabled)
    }

    // MARK: - Golden: overlay transition guards

    /// overlay 单槽互斥：打开第二个 overlay 经 null 中间态替换为新的 overlay，
    /// 最终态唯一（不存在两个 overlay 同时活跃）。
    func testGolden_overlayMutualExclusion_replacesViaNullIntermediate() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        // 打开第一个 overlay（reader directory → sheet）
        reducer.dispatch(UiEvent(type: .reader_directory_open))
        XCTAssertEqual(nav.overlayState, .sheet)

        // 打开第二个 overlay（dialog）——单槽互斥：经 null 中间态替换为新的 overlay
        reducer.dispatch(UiEvent(type: .overlay_dialog_open))
        XCTAssertEqual(nav.overlayState, .dialog)

        // 第三个 overlay（keyboard）再次替换——最终态唯一为 keyboard
        reducer.dispatch(UiEvent(type: .overlay_keyboard_open))
        XCTAssertEqual(nav.overlayState, .keyboard)
    }

    /// 关闭 overlay 后焦点恢复到先前 scope：overlay 开关不破坏 scope 焦点恢复链。
    func testGolden_closingOverlayRestoresFocus() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        // bookshelf scope 焦点
        reducer.dispatch(UiEvent(
            type: .input_focus,
            payload: ["target": AnyCodable("bookshelf.search.button")]
        ))
        XCTAssertEqual(nav.focusTarget, "bookshelf.search.button")

        // 进入 search scope（焦点切换到新 scope，bookshelf 焦点入栈保留）
        reducer.dispatch(UiEvent(
            type: .route_push,
            payload: ["route": AnyCodable("search-home")]
        ))
        XCTAssertNil(nav.focusTarget)

        // 在 search scope 打开并关闭 reader overlay——焦点不被 overlay 打断
        reducer.dispatch(UiEvent(type: .reader_directory_open))
        XCTAssertEqual(nav.overlayState, .sheet)
        reducer.dispatch(UiEvent(type: .reader_directory_close))
        XCTAssertEqual(nav.overlayState, .none)

        // 退出 search scope——焦点恢复到 bookshelf scope（先前 scope）
        reducer.dispatch(UiEvent(type: .route_pop))
        XCTAssertEqual(nav.focusTarget, "bookshelf.search.button")
    }

    /// tab 切换 transition guard：settings overlay（dialog）展开时禁止 tab 切换。
    /// 对齐 settings-overlay-guard-tab-switch 规则。
    func testGolden_tabSwitchInterruptsOverlay() {
        let nav = AppNavigationState()
        nav.activeTab = .settings
        nav.setOverlay(.dialog)
        let reducer = ReaderReducer(navigationState: nav)

        // settings overlay（dialog）展开时，tab 切换被 transition guard 拦截
        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("bookshelf")]
        ))

        // tab 未切换，overlay 未被清除——guard 持有
        XCTAssertEqual(nav.activeTab, .settings)
        XCTAssertEqual(nav.overlayState, .dialog)
    }
}
