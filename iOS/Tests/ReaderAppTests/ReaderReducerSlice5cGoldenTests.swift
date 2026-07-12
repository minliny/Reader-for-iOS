import XCTest
@testable import ReaderApp
import ReaderUIContract

/// Slice 5c Golden Tests — 搜索/书籍详情/书架管理扩展
@MainActor
final class ReaderReducerSlice5cGoldenTests: XCTestCase {

    // MARK: - Golden: ViewStateComponentFactory — 搜索/书架 RouteId 派生

    func testGolden_viewState_components_bookSearch() {
        let components = ViewStateComponentFactory.components(for: .bookSearch)
        XCTAssertEqual(components.count, 5)
        XCTAssertEqual(components[0].type, .appTopBar)
        XCTAssertEqual(components[1].type, .searchInputBox)
        XCTAssertEqual(components[2].type, .scopeSelector)
        XCTAssertEqual(components[3].type, .groupSelector)
        XCTAssertEqual(components[4].type, .searchHistoryList)
    }

    func testGolden_viewState_components_searchHome() {
        let components = ViewStateComponentFactory.components(for: .searchHome)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .searchHomePage)
    }

    func testGolden_viewState_components_searchResults() {
        let components = ViewStateComponentFactory.components(for: .searchResults)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .searchResultsPage)
    }

    func testGolden_viewState_components_searchEmpty_usesStatePage() {
        let components = ViewStateComponentFactory.components(for: .searchEmpty)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .searchStatePage)
    }

    func testGolden_viewState_components_searchLoading_usesStatePage() {
        let components = ViewStateComponentFactory.components(for: .searchLoading)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .searchStatePage)
    }

    func testGolden_viewState_components_searchError_usesStatePage() {
        let components = ViewStateComponentFactory.components(for: .searchError)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .searchStatePage)
    }

    func testGolden_viewState_components_bookDetailTocPreview() {
        let components = ViewStateComponentFactory.components(for: .bookDetailTocPreview)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .bookTocPreviewPage)
    }

    func testGolden_viewState_components_bookDirectory() {
        let components = ViewStateComponentFactory.components(for: .bookDirectory)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .bookDirectoryPage)
    }

    func testGolden_viewState_components_groupManagement() {
        let components = ViewStateComponentFactory.components(for: .groupManagement)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .groupManagementPage)
    }

    func testGolden_viewState_components_bookBatchManagement() {
        let components = ViewStateComponentFactory.components(for: .bookBatchManagement)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .bookBatchManagementPage)
    }

    func testGolden_viewState_components_bookshelfGroupManagement() {
        let components = ViewStateComponentFactory.components(for: .bookshelfGroupManagement)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .bookGroupManagementPage)
    }

    // MARK: - Golden: ComponentRegistry.registerSlice5cComponents() 注册覆盖

    func testGolden_componentRegistry_registerSlice5c_allTypesRegistered() {
        ComponentRegistry.reset()
        ComponentRegistry.registerSlice5cComponents()

        XCTAssertTrue(ComponentRegistry.isRegistered(.searchInputBox))
        XCTAssertTrue(ComponentRegistry.isRegistered(.scopeSelector))
        XCTAssertTrue(ComponentRegistry.isRegistered(.groupSelector))
        XCTAssertTrue(ComponentRegistry.isRegistered(.searchHistoryList))
        XCTAssertTrue(ComponentRegistry.isRegistered(.searchHomePage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.searchResultsPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.searchStatePage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.bookTocPreviewPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.bookDirectoryPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.groupManagementPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.bookBatchManagementPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.bookGroupManagementPage))
    }

    func testGolden_componentRegistry_registerSlice5c_countIs12() {
        ComponentRegistry.reset()
        let before = ComponentRegistry.registeredCount
        ComponentRegistry.registerSlice5cComponents()
        let after = ComponentRegistry.registeredCount
        XCTAssertEqual(after - before, 12)
    }

    // MARK: - Golden: ReaderReducer search state + bookshelf effects

    func testGolden_reducer_searchSubmit_updatesQueryLoadingAndRoute() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(
            type: .search_submit,
            payload: ["query": AnyCodable("三体")]
        ))
        XCTAssertEqual(nav.searchQuery, "三体")
        XCTAssertTrue(nav.searchIsLoading)
        XCTAssertEqual(nav.currentRoute, .searchResults(query: "三体"))
    }

    func testGolden_reducer_groupCreate_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(type: .bookshelf_groupManagement_create))
        XCTAssertEqual(nav.activeSession, .none)
    }

    func testGolden_reducer_bookBatchDelete_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(type: .bookshelf_batchManagement_open))
        XCTAssertEqual(nav.activeSession, .none)
    }

    // MARK: - Golden: search.submit 设置 query / search.success 设置结果并清除 loading

    /// search.submit owns query/loading and opens the results route.
    func testGolden_searchSubmit_setsQuery() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .search_submit,
            payload: ["query": AnyCodable("深空信号")]
        ))

        XCTAssertEqual(nav.searchQuery, "深空信号")
        XCTAssertTrue(nav.searchIsLoading)
        XCTAssertEqual(nav.currentRoute, .searchResults(query: "深空信号"))
        XCTAssertEqual(ReaderViewState(from: nav).routeId, .searchResults)
    }

    /// Core search completion clears loading and records the terminal count.
    func testGolden_searchSuccess_setsResultsAndClearsLoading() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .search_submit,
            payload: ["query": AnyCodable("深空信号")]
        ))
        XCTAssertTrue(nav.searchIsLoading)

        reducer.receive(CoreEvent(
            type: .source_search_completed,
            payload: [
                "results": AnyCodable([
                    AnyCodable(["title": AnyCodable("深空信号")]),
                    AnyCodable(["title": AnyCodable("宇宙回声")]),
                ]),
                "count": AnyCodable(2),
            ]
        ))

        XCTAssertEqual(nav.currentRoute, .searchResults(query: "深空信号"))
        XCTAssertEqual(nav.navigationPath, [.searchResults(query: "深空信号")])
        XCTAssertFalse(nav.searchIsLoading)
        XCTAssertEqual(nav.searchResultCount, 2)
        XCTAssertEqual(nav.overlayState, .none)
        XCTAssertEqual(nav.activeSession, .none)
        XCTAssertEqual(ReaderViewState(from: nav).pageState, .defaultValue)
    }
}
