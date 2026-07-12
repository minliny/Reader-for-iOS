import XCTest
@testable import ReaderApp
import ReaderUIContract

/// Slice 5b Golden Tests — 书源系列
///
/// 验证：
/// 1. ViewStateComponentFactory 为 25 个书源 RouteId 派生正确组件组合（与 fixtures 对齐）
/// 2. ComponentRegistry.registerSlice5bComponents() 注册 18 个书源 ComponentType
/// 3. ReaderReducer 对书源业务事件 stub 不影响 navigation state
///
/// 契约对齐（CONTRACT_FIRST_NATIVE_UI_PLAN.md §9 Phase 3 Slice 5b）：
/// 书源管理全链路 component 注册 + 组件组合派生 + 事件 stub
@MainActor
final class ReaderReducerSlice5bGoldenTests: XCTestCase {

    // MARK: - Golden: ViewStateComponentFactory — 书源 RouteId 派生

    func testGolden_viewState_components_sourceDetail() {
        let components = ViewStateComponentFactory.components(for: .sourceDetail)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceDetailPage)
    }

    // P1 对齐：source-switch 与其他书源路由一致，由 BackTopBar + SourceSwitchFlowPage 组成
    // （FlowShellContainer 需 BackTopBar 才能渲染返回栏区域）。
    func testGolden_viewState_components_sourceSwitch() {
        let components = ViewStateComponentFactory.components(for: .sourceSwitch)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceSwitchFlowPage)
    }

    func testGolden_viewState_components_sourceSwitchResults() {
        let components = ViewStateComponentFactory.components(for: .sourceSwitchResults)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceSwitchFlowPage)
    }

    func testGolden_viewState_components_sourceManagement() {
        let components = ViewStateComponentFactory.components(for: .sourceManagement)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceManagementPage)
    }

    func testGolden_viewState_components_sourceSettingsEntry_usesManagementPage() {
        let components = ViewStateComponentFactory.components(for: .sourceSettingsEntry)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceManagementPage)
    }

    func testGolden_viewState_components_sourceAdd_usesImportOptions() {
        let components = ViewStateComponentFactory.components(for: .sourceAdd)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceImportOptionsPage)
    }

    func testGolden_viewState_components_sourceImportOptions() {
        let components = ViewStateComponentFactory.components(for: .sourceImportOptions)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceImportOptionsPage)
    }

    func testGolden_viewState_components_sourceEdit_usesRuleEdit() {
        let components = ViewStateComponentFactory.components(for: .sourceEdit)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceRuleEditPage)
    }

    func testGolden_viewState_components_sourceRuleEdit_usesRuleEdit() {
        let components = ViewStateComponentFactory.components(for: .sourceRuleEdit)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceRuleEditPage)
    }

    func testGolden_viewState_components_sourceEditDebug_usesRuleEditWithDebugVariant() {
        let components = ViewStateComponentFactory.components(for: .sourceEditDebug)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceRuleEditPage)
    }

    func testGolden_viewState_components_sourceTestResult() {
        let components = ViewStateComponentFactory.components(for: .sourceTestResult)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceTestResultPage)
    }

    func testGolden_viewState_components_sourceBatch() {
        let components = ViewStateComponentFactory.components(for: .sourceBatch)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceBatchPage)
    }

    func testGolden_viewState_components_sourceCodeView() {
        let components = ViewStateComponentFactory.components(for: .sourceCodeView)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceCodeViewPage)
    }

    func testGolden_viewState_components_sourceDebug() {
        let components = ViewStateComponentFactory.components(for: .sourceDebug)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceDebugPage)
    }

    func testGolden_viewState_components_sourceDebugCatalogResult_usesResultPage() {
        let components = ViewStateComponentFactory.components(for: .sourceDebugCatalogResult)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceDebugResultPage)
    }

    func testGolden_viewState_components_sourceDebugContentLog() {
        let components = ViewStateComponentFactory.components(for: .sourceDebugContentLog)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceDebugContentLogPage)
    }

    func testGolden_viewState_components_sourceDebugDetailResult_usesResultPage() {
        let components = ViewStateComponentFactory.components(for: .sourceDebugDetailResult)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceDebugResultPage)
    }

    func testGolden_viewState_components_sourceDebugResult_usesResultPage() {
        let components = ViewStateComponentFactory.components(for: .sourceDebugResult)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceDebugResultPage)
    }

    func testGolden_viewState_components_sourceDebugRunning() {
        let components = ViewStateComponentFactory.components(for: .sourceDebugRunning)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceDebugRunningPage)
    }

    func testGolden_viewState_components_sourceDebugSearchResult_usesResultPage() {
        let components = ViewStateComponentFactory.components(for: .sourceDebugSearchResult)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceDebugResultPage)
    }

    func testGolden_viewState_components_sourceDeleteConfirm() {
        let components = ViewStateComponentFactory.components(for: .sourceDeleteConfirm)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceDeleteConfirmPage)
    }

    func testGolden_viewState_components_sourceDetect() {
        let components = ViewStateComponentFactory.components(for: .sourceDetect)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceDetectPage)
    }

    func testGolden_viewState_components_sourceGroups() {
        let components = ViewStateComponentFactory.components(for: .sourceGroups)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceGroupsPage)
    }

    func testGolden_viewState_components_sourceImportPreview() {
        let components = ViewStateComponentFactory.components(for: .sourceImportPreview)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceImportPreviewPage)
    }

    func testGolden_viewState_components_sourceLogs() {
        let components = ViewStateComponentFactory.components(for: .sourceLogs)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .sourceLogsPage)
    }

    // MARK: - Golden: ComponentRegistry.registerSlice5bComponents() 注册覆盖

    func testGolden_componentRegistry_registerSlice5b_allSourceTypesRegistered() {
        ComponentRegistry.reset()
        ComponentRegistry.registerSlice5bComponents()

        XCTAssertTrue(ComponentRegistry.isRegistered(.sourceDetailPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.sourceSwitchFlowPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.sourceManagementPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.sourceImportOptionsPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.sourceRuleEditPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.sourceTestResultPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.sourceBatchPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.sourceCodeViewPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.sourceDebugPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.sourceDebugResultPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.sourceDebugContentLogPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.sourceDebugRunningPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.sourceDeleteConfirmPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.sourceDetectPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.sourceGroupsPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.sourceImportPreviewPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.sourceLogsPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.sourceDisabledState))
    }

    func testGolden_componentRegistry_registerSlice5b_countIs18() {
        ComponentRegistry.reset()
        let before = ComponentRegistry.registeredCount
        ComponentRegistry.registerSlice5bComponents()
        let after = ComponentRegistry.registeredCount
        XCTAssertEqual(after - before, 18)
    }

    // MARK: - Golden: ReaderReducer 书源业务事件 stub

    func testGolden_reducer_sourceManagementOpen_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(type: .source_management_open))
        XCTAssertEqual(nav.activeSession, .none)
    }

    func testGolden_reducer_sourceSwitchSelect_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(type: .source_switch_select))
        XCTAssertEqual(nav.activeSession, .none)
    }

    func testGolden_reducer_sourceImportApply_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(type: .source_import_apply))
        XCTAssertEqual(nav.activeSession, .none)
    }

    func testGolden_reducer_sourceDebugRun_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(type: .source_debug_run))
        XCTAssertEqual(nav.activeSession, .none)
    }

    func testGolden_reducer_sourceDeleteConfirm_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(type: .source_delete_confirm))
        XCTAssertEqual(nav.activeSession, .none)
    }

    // MARK: - Golden: source.import.open 打开本地导入路由

    /// source.import.open 事件 push .bookSourceImport 路由（对齐 BookSourceImportView）。
    func testGolden_sourceImportOpen_opensLocalImportRoute() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(type: .source_import_open))

        XCTAssertEqual(nav.currentRoute, .bookSourceImport)
        XCTAssertEqual(nav.navigationPath, [.bookSourceImport])
        XCTAssertEqual(ReaderViewState(from: nav).routeId, .sourceImportOptions)
    }
}
