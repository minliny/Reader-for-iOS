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
/// - reader.bookCache.open → route.push(.content)
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

    func testGolden_readerBookCacheOpen_pushesContentRoute() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(type: .reader_bookCache_open))

        XCTAssertNotNil(nav.navigationPath.last)
        if let route = nav.navigationPath.last,
           case .content(let chapterTitle) = route {
            XCTAssertEqual(chapterTitle, "Slice3")
        } else {
            XCTFail("Expected .content route")
        }
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

    // MARK: - Golden: reader.page.next / prev (stub, should not crash)

    func testGolden_readerPageNext_doesNotCrash() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(type: .reader_page_next))
        // 无 crash 即通过——翻页不影响 navigation state
        XCTAssertTrue(true)
    }

    func testGolden_readerNightStateToggle_doesNotCrash() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(type: .reader_nightState_toggle))
        // 无 crash 即通过——夜间模式切换为 stub
        XCTAssertTrue(true)
    }
}
