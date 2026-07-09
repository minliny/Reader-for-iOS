import XCTest
@testable import ReaderApp
import ReaderUIContract

/// Slice 5a Golden Tests — RSS 系列
///
/// 验证：
/// 1. ViewStateComponentFactory 为 16 个 RSS RouteId 派生正确组件组合（与 fixtures 对齐）
/// 2. ComponentRegistry.registerSlice5aComponents() 注册 16 个 RSS ComponentType
/// 3. ReaderReducer 对 RSS 业务事件 stub 不影响 navigation state（保持 Slice 5a 简洁）
///
/// 契约对齐（CONTRACT_FIRST_NATIVE_UI_PLAN.md §9 Phase 3 Slice 5a）：
/// RSS 全链路 component 注册 + 组件组合派生 + 事件 stub
@MainActor
final class ReaderReducerSlice5aGoldenTests: XCTestCase {

    // MARK: - Golden: ViewStateComponentFactory — RSS RouteId 派生

    func testGolden_viewState_components_rss() {
        let components = ViewStateComponentFactory.components(for: .rss)
        XCTAssertEqual(components.count, 6)
        XCTAssertEqual(components[0].type, .appTopBar)
        XCTAssertEqual(components[1].type, .rssSearchEntry)
        XCTAssertEqual(components[2].type, .rssModeRow)
        XCTAssertEqual(components[3].type, .rssSourceOverview)
        XCTAssertEqual(components[4].type, .rssArticleSection)
        XCTAssertEqual(components[5].type, .bottomNav)
    }

    func testGolden_viewState_components_rssAll() {
        let components = ViewStateComponentFactory.components(for: .rssAll)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .rssAllPage)
    }

    func testGolden_viewState_components_rssDetail() {
        let components = ViewStateComponentFactory.components(for: .rssDetail)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .rssDetailPage)
    }

    func testGolden_viewState_components_rssOriginal() {
        let components = ViewStateComponentFactory.components(for: .rssOriginal)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .rssOriginalPage)
    }

    func testGolden_viewState_components_rssSubscriptionManagement() {
        let components = ViewStateComponentFactory.components(for: .rssSubscriptionManagement)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .rssSubscriptionManagementPage)
    }

    func testGolden_viewState_components_rssEmpty() {
        let components = ViewStateComponentFactory.components(for: .rssEmpty)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .rssEmptyState)
    }

    func testGolden_viewState_components_rssError() {
        let components = ViewStateComponentFactory.components(for: .rssError)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .rssErrorState)
    }

    func testGolden_viewState_components_rssRefreshing() {
        let components = ViewStateComponentFactory.components(for: .rssRefreshing)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .rssRefreshingPage)
    }

    func testGolden_viewState_components_rssSearch() {
        let components = ViewStateComponentFactory.components(for: .rssSearch)
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[0].type, .appTopBar)
        XCTAssertEqual(components[1].type, .rssSearchEntry)
        XCTAssertEqual(components[2].type, .bottomNav)
    }

    func testGolden_viewState_components_rssStarred() {
        let components = ViewStateComponentFactory.components(for: .rssStarred)
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[0].type, .appTopBar)
        XCTAssertEqual(components[1].type, .rssArticleSection)
        XCTAssertEqual(components[2].type, .bottomNav)
    }

    func testGolden_viewState_components_rssOriginalBrowser() {
        let components = ViewStateComponentFactory.components(for: .rssOriginalBrowser)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .rssOriginalBrowserPage)
    }

    func testGolden_viewState_components_rssFavoriteGroups() {
        let components = ViewStateComponentFactory.components(for: .rssFavoriteGroups)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .rssFavoriteGroupsPage)
    }

    func testGolden_viewState_components_rssSourceGroups() {
        let components = ViewStateComponentFactory.components(for: .rssSourceGroups)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .rssSourceGroupsPage)
    }

    func testGolden_viewState_components_rssSourceAdd_modeAdd() {
        let components = ViewStateComponentFactory.components(for: .rssSourceAdd)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .rssSourceEditPage)
    }

    func testGolden_viewState_components_rssSourceEdit_modeEdit() {
        let components = ViewStateComponentFactory.components(for: .rssSourceEdit)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .rssSourceEditPage)
    }

    func testGolden_viewState_components_rssSourceImport() {
        let components = ViewStateComponentFactory.components(for: .rssSourceImport)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .rssSourceImportPage)
    }

    // MARK: - Golden: ComponentRegistry.registerSlice5aComponents() 注册覆盖

    func testGolden_componentRegistry_registerSlice5a_allRssTypesRegistered() {
        ComponentRegistry.reset()
        ComponentRegistry.registerSlice5aComponents()

        XCTAssertTrue(ComponentRegistry.isRegistered(.rssSearchEntry))
        XCTAssertTrue(ComponentRegistry.isRegistered(.rssModeRow))
        XCTAssertTrue(ComponentRegistry.isRegistered(.rssSourceOverview))
        XCTAssertTrue(ComponentRegistry.isRegistered(.rssArticleSection))
        XCTAssertTrue(ComponentRegistry.isRegistered(.rssAllPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.rssDetailPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.rssOriginalPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.rssRefreshingPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.rssOriginalBrowserPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.rssFavoriteGroupsPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.rssSourceGroupsPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.rssSourceImportPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.rssSourceEditPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.rssSubscriptionManagementPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.rssEmptyState))
        XCTAssertTrue(ComponentRegistry.isRegistered(.rssErrorState))
    }

    func testGolden_componentRegistry_registerSlice5a_countIs16() {
        ComponentRegistry.reset()
        let before = ComponentRegistry.registeredCount
        ComponentRegistry.registerSlice5aComponents()
        let after = ComponentRegistry.registeredCount
        XCTAssertEqual(after - before, 16)
    }

    // MARK: - Golden: ReaderReducer RSS 业务事件 stub

    func testGolden_reducer_rssEntryOpen_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        // RSS 业务事件 stub：不影响 navigation state
        reducer.dispatch(UiEvent(type: .rss_entry_open))
        // 无路由推送（route.push 由 contract 显式发送）
        XCTAssertEqual(nav.activeSession, .none)
    }

    func testGolden_reducer_rssSubscriptionOpen_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(type: .rss_subscription_open))
        XCTAssertEqual(nav.activeSession, .none)
    }

    func testGolden_reducer_rssSearchSubmit_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(type: .rss_search_submit))
        XCTAssertEqual(nav.activeSession, .none)
    }

    func testGolden_reducer_rssRefresh_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(type: .rss_refresh))
        XCTAssertEqual(nav.activeSession, .none)
    }

    func testGolden_reducer_rssFavoriteAdd_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(type: .rss_favorite_add))
        XCTAssertEqual(nav.activeSession, .none)
    }
}
