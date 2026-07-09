import XCTest
@testable import ReaderApp
import ReaderUIContract

/// Slice 5d Golden Tests — 发现系列
@MainActor
final class ReaderReducerSlice5dGoldenTests: XCTestCase {

    // MARK: - Golden: ViewStateComponentFactory — 发现 RouteId 派生

    func testGolden_viewState_components_discover() {
        let components = ViewStateComponentFactory.components(for: .discover)
        XCTAssertEqual(components.count, 7)
        XCTAssertEqual(components[0].type, .appTopBar)
        XCTAssertEqual(components[1].type, .discoverSourceBar)
        XCTAssertEqual(components[2].type, .discoverEntryRow)
        XCTAssertEqual(components[3].type, .discoverFilterTrigger)
        XCTAssertEqual(components[4].type, .discoverListHead)
        XCTAssertEqual(components[5].type, .discoverBookList)
        XCTAssertEqual(components[6].type, .bottomNav)
    }

    func testGolden_viewState_components_discoverEmpty_usesStatePage() {
        let components = ViewStateComponentFactory.components(for: .discoverEmpty)
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[0].type, .appTopBar)
        XCTAssertEqual(components[1].type, .discoverStatePage)
        XCTAssertEqual(components[2].type, .bottomNav)
    }

    func testGolden_viewState_components_discoverError_usesStatePage() {
        let components = ViewStateComponentFactory.components(for: .discoverError)
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[0].type, .appTopBar)
        XCTAssertEqual(components[1].type, .discoverStatePage)
        XCTAssertEqual(components[2].type, .bottomNav)
    }

    func testGolden_viewState_components_discoverLoading_usesStatePage() {
        let components = ViewStateComponentFactory.components(for: .discoverLoading)
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[0].type, .appTopBar)
        XCTAssertEqual(components[1].type, .discoverStatePage)
        XCTAssertEqual(components[2].type, .bottomNav)
    }

    func testGolden_viewState_components_discoverNoResults_usesStatePage() {
        let components = ViewStateComponentFactory.components(for: .discoverNoResults)
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[0].type, .appTopBar)
        XCTAssertEqual(components[1].type, .discoverStatePage)
        XCTAssertEqual(components[2].type, .bottomNav)
    }

    func testGolden_viewState_components_discoverRuleTest() {
        let components = ViewStateComponentFactory.components(for: .discoverRuleTest)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .discoverRuleTestPage)
    }

    func testGolden_viewState_components_discoverSourceBulk() {
        let components = ViewStateComponentFactory.components(for: .discoverSourceBulk)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .discoverSourceBulkPage)
    }

    func testGolden_viewState_components_discoverSourceLogin() {
        let components = ViewStateComponentFactory.components(for: .discoverSourceLogin)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .discoverSourceLoginPage)
    }

    // MARK: - Golden: ComponentRegistry.registerSlice5dComponents() 注册覆盖

    func testGolden_componentRegistry_registerSlice5d_allTypesRegistered() {
        ComponentRegistry.reset()
        ComponentRegistry.registerSlice5dComponents()

        XCTAssertTrue(ComponentRegistry.isRegistered(.discoverSourceBar))
        XCTAssertTrue(ComponentRegistry.isRegistered(.discoverEntryRow))
        XCTAssertTrue(ComponentRegistry.isRegistered(.discoverFilterTrigger))
        XCTAssertTrue(ComponentRegistry.isRegistered(.discoverListHead))
        XCTAssertTrue(ComponentRegistry.isRegistered(.discoverBookList))
        XCTAssertTrue(ComponentRegistry.isRegistered(.discoverStatePage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.discoverRuleTestPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.discoverSourceBulkPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.discoverSourceLoginPage))
    }

    func testGolden_componentRegistry_registerSlice5d_countIs9() {
        ComponentRegistry.reset()
        let before = ComponentRegistry.registeredCount
        ComponentRegistry.registerSlice5dComponents()
        let after = ComponentRegistry.registeredCount
        XCTAssertEqual(after - before, 9)
    }

    // MARK: - Golden: ReaderReducer 发现事件 stub

    func testGolden_reducer_discoverFilterApply_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(type: .discover_filter_apply))
        XCTAssertEqual(nav.activeSession, .none)
    }

    func testGolden_reducer_discoverRefresh_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(type: .discover_refresh))
        XCTAssertEqual(nav.activeSession, .none)
    }

    func testGolden_reducer_discoverEntrySelect_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(type: .discover_entry_select))
        XCTAssertEqual(nav.activeSession, .none)
    }
}
