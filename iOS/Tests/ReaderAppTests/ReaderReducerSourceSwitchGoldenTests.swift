import XCTest
@testable import ReaderApp
import ReaderUIContract

/// Source-Switch Golden Tests — B2 source-switch 链路闭环
///
/// 验证 ReaderReducer 消费 source-switch 事件后，AppNavigationState 与 ReaderViewState
/// 正确更新，确认 source-switch 的 enter/exit 已接 `source.switch.route.push` /
/// `source.switch.route.pop`（FlowShell，priority 200）：
/// - open → route.push(.sourceSwitch)，routeId == .sourceSwitch
/// - loading → 业务事件（source_switch_select 等 stub），不影响 navigation state
/// - results → source-switch-results 是 feature state，不推独立 route
/// - select → source_switch_select stub，不影响 navigation state
/// - close → route.pop 回退到来源 route
@MainActor
final class ReaderReducerSourceSwitchGoldenTests: XCTestCase {

    // MARK: - Golden: open source-switch → route.push(.sourceSwitch)

    func testGolden_sourceSwitchOpen_pushesSourceSwitchRoute() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .source_switch_open,
            payload: ["bookURL": AnyCodable("bk-001")]
        ))

        XCTAssertEqual(nav.navigationPath.count, 1)
        XCTAssertNotNil(nav.navigationPath.last)

        if let route = nav.navigationPath.last,
           case .sourceSwitch(let bookURL) = route {
            XCTAssertEqual(bookURL, "bk-001")
        } else {
            XCTFail("Expected .sourceSwitch route, got \(String(describing: nav.navigationPath.last))")
        }

        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.routeId, .sourceSwitch)
    }

    // MARK: - Golden: source-switch components → SourceSwitchFlowPage

    func testGolden_sourceSwitch_components_sourceSwitchFlowPage() {
        let components = ViewStateComponentFactory.components(for: .sourceSwitch)

        XCTAssertFalse(components.isEmpty)
        XCTAssertEqual(components.first?.type, .sourceSwitchFlowPage)
    }

    // MARK: - Golden: source-switch motion 解析（push → source_switch_route_push）

    func testGolden_flowShell_push_resolvesToSourceSwitchRoutePush() {
        let request = MotionRequest(
            operation: .push,
            containerRole: .flowShell
        )
        let motionId = ReaderMotionAdapter.resolve(request: request)
        XCTAssertEqual(motionId, .source_switch_route_push,
                       "push in flowShell must resolve to .source_switch_route_push (flow-shell-route-push, priority 200)")
    }

    // MARK: - Golden: source-switch motion 解析（pop → source_switch_route_pop）

    func testGolden_flowShell_pop_resolvesToSourceSwitchRoutePop() {
        let request = MotionRequest(
            operation: .pop,
            containerRole: .flowShell
        )
        let motionId = ReaderMotionAdapter.resolve(request: request)
        XCTAssertEqual(motionId, .source_switch_route_pop,
                       "pop in flowShell must resolve to .source_switch_route_pop (flow-shell-route-pop, priority 200)")
    }

    // MARK: - Golden: loading / select / confirm 业务事件不影响 navigation state

    func testGolden_sourceSwitchSelect_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        // 先打开 source-switch
        reducer.dispatch(UiEvent(
            type: .source_switch_open,
            payload: ["bookURL": AnyCodable("bk-001")]
        ))
        let pathCountBefore = nav.navigationPath.count
        let routeBefore = nav.navigationPath.last

        // source_switch_select 是业务事件 stub，不影响 navigation state
        reducer.dispatch(UiEvent(type: .source_switch_select))
        reducer.dispatch(UiEvent(type: .source_switch_confirm))

        XCTAssertEqual(nav.navigationPath.count, pathCountBefore,
                       "source_switch_select/confirm 是业务事件 stub，不影响 navigationPath")
        XCTAssertEqual(nav.navigationPath.last, routeBefore,
                       "source_switch_select/confirm 不应改变当前 route")
    }

    // MARK: - Golden: close source-switch → route pop 回退

    func testGolden_sourceSwitchClose_popsRoute() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        // 来源：bookshelf → push source-switch
        reducer.dispatch(UiEvent(
            type: .source_switch_open,
            payload: ["bookURL": AnyCodable("bk-001")]
        ))
        XCTAssertEqual(ReaderViewState(from: nav).routeId, .sourceSwitch)

        // close → route_pop
        reducer.dispatch(UiEvent(type: .route_pop))

        XCTAssertTrue(nav.navigationPath.isEmpty)
        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.routeId, .bookshelf)
    }

    // MARK: - Golden: coordinator.openSourceSwitch dispatches correct event

    func testGolden_coordinatorOpenSourceSwitch_pushesRoute() {
        let nav = AppNavigationState()
        let coordinator = ReaderCoordinator(navigationState: nav)

        coordinator.openSourceSwitch(bookId: "bk-001")

        XCTAssertNotNil(nav.navigationPath.last)
        if let route = nav.navigationPath.last,
           case .sourceSwitch(let bookURL) = route {
            XCTAssertEqual(bookURL, "bk-001")
        } else {
            XCTFail("Expected .sourceSwitch route")
        }
    }

    // MARK: - Golden: source-switch-results 是 feature state（不推独立 route）

    func testGolden_sourceSwitchResults_isFeatureState_notSeparateRoute() {
        let mapping = DemoRouteMappings.mapping(for: "source-switch-results")
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.shell, "FlowShell")
        // source-switch-results 映射为 feature state，不是独立 route
        if let mapping = mapping {
            switch mapping.platformTarget {
            case .featureState(let stateName):
                XCTAssertTrue(stateName.contains("SourceSwitchResultState"),
                              "source-switch-results feature state must reference SourceSwitchResultState")
            default:
                XCTFail("source-switch-results must map to a feature state, got \(mapping.platformTarget)")
            }
        }
    }

    // MARK: - Golden: source_switch_cancel 是业务事件 stub（不影响 navigation state）

    func testGolden_sourceSwitchCancel_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .source_switch_open,
            payload: ["bookURL": AnyCodable("bk-001")]
        ))
        let pathCountBefore = nav.navigationPath.count

        // source_switch_cancel 是业务事件 stub
        reducer.dispatch(UiEvent(type: .source_switch_cancel))

        XCTAssertEqual(nav.navigationPath.count, pathCountBefore,
                       "source_switch_cancel 是业务事件 stub，不影响 navigationPath")
    }
}
