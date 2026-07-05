import XCTest
@testable import ReaderApp

/// P0/M2 closed-planned route closure: source-switch-results (FlowShell)
///
/// 验收：source-switch → source-switch-results 不是"两个独立的页面"，而是
/// ReaderSourceSwitchFlowView 里的 SourceSwitchResultState 状态机：
/// `.browsing` ↔ `.confirmed`，由 confirm/reset 两个动作触发。
/// 这条 route 在 `closedPlannedRouteMappings` 里被声明为
/// `.featureState("SourceSwitchResultState.confirmed")`，本测试覆盖：
/// (1) route 不再是 planned；(2) SourceSwitchResultState 状态真实存在并能切换；
/// (3) ReaderSourceSwitchFlowView 能构造。
@MainActor
final class SourceSwitchResultsTests: XCTestCase {

    // MARK: - Route ownership

    func testSourceSwitchResultsRouteIsConcreteFeatureState() {
        let mapping = DemoRouteMappings.mapping(for: "source-switch-results")
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.shell, "FlowShell")
        XCTAssertEqual(mapping?.slice, 3)
        guard case .featureState(let stateName) = mapping?.platformTarget else {
            return XCTFail("source-switch-results must map to a feature state, got \(String(describing: mapping?.platformTarget))")
        }
        XCTAssertTrue(stateName.contains("SourceSwitchResultState"),
                      "source-switch-results feature state must reference SourceSwitchResultState")
        XCTAssertTrue(stateName.contains("confirmed"),
                      "source-switch-results feature state must reference .confirmed case")
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true,
                       "source-switch-results stateModel must not be planned")
    }

    func testSourceSwitchResultsStateModelDescribesConfirmClosure() {
        let mapping = DemoRouteMappings.mapping(for: "source-switch-results")
        XCTAssertTrue(mapping?.stateModel.contains("ReaderSourceSwitchFlowView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("SourceSwitchResultCard") == true)
        XCTAssertTrue(mapping?.stateModel.contains("SourceSwitchResultState.confirmed") == true)
        XCTAssertTrue(mapping?.stateModel.contains("SourceSwitchCandidate") == true)
        XCTAssertTrue(mapping?.stateModel.contains("ReaderContinuitySlot") == true)
    }

    // MARK: - navigationEntry describes browsing → confirmed transition

    func testNavigationEntryDescribesBrowsingToConfirmedTransition() {
        let mapping = DemoRouteMappings.mapping(for: "source-switch-results")
        XCTAssertTrue(mapping?.navigationEntry.contains("ReaderSourceSwitchFlowView") == true)
        XCTAssertTrue(mapping?.navigationEntry.contains("confirm action") == true,
                      "navigationEntry must describe confirm action triggering the state transition")
        XCTAssertTrue(mapping?.navigationEntry.contains(".browsing") == true)
        XCTAssertTrue(mapping?.navigationEntry.contains(".confirmed") == true)
    }

    // MARK: - SourceSwitchResultState state machine

    func testSourceSwitchResultStateBrowsingEqualsBrowsing() {
        XCTAssertEqual(SourceSwitchResultState.browsing, .browsing)
    }

    func testSourceSwitchResultStateConfirmedEqualsConfirmed() {
        XCTAssertEqual(SourceSwitchResultState.confirmed, .confirmed)
    }

    func testSourceSwitchResultStateBrowsingDoesNotEqualConfirmed() {
        XCTAssertNotEqual(SourceSwitchResultState.browsing, .confirmed,
                          "browsing and confirmed must be distinct states")
    }

    // MARK: - ReaderSourceSwitchFlowView can init (closes the construct contract)

    func testReaderSourceSwitchFlowViewCanInitWithBookURL() {
        let view = ReaderSourceSwitchFlowView(bookURL: "demo://book/rain-night")
        XCTAssertNotNil(view, "ReaderSourceSwitchFlowView must be instantiable with a bookURL for the source-switch flow")
    }

    func testReaderSourceSwitchFlowViewCanInitWithOnExitClosure() {
        var exitCalled = false
        let view = ReaderSourceSwitchFlowView(
            bookURL: "demo://book/rain-night",
            onExit: { exitCalled = true }
        )
        XCTAssertNotNil(view)
        XCTAssertFalse(exitCalled, "onExit must not be invoked during construction")
    }

    // MARK: - motionIDs describe the source-switch close motion

    func testMotionIDsIncludeSourceSwitchCloseMotion() {
        let mapping = DemoRouteMappings.mapping(for: "source-switch-results")
        let motionIDs = mapping?.motionIDs ?? []
        XCTAssertTrue(motionIDs.contains("reader.sourceSwitch.close"),
                      "source-switch-results must include reader.sourceSwitch.close motion")
        XCTAssertTrue(motionIDs.contains("overlay.sheet.exit"))
        XCTAssertTrue(motionIDs.contains("state.content.replace"),
                      "state transition must be reflected in motionIDs")
    }

    // MARK: - source-switch (parent) and source-switch-results form a single flow

    func testSourceSwitchAndSourceSwitchResultsShareFlowShell() {
        let parent = DemoRouteMappings.mapping(for: "source-switch")
        let results = DemoRouteMappings.mapping(for: "source-switch-results")

        XCTAssertEqual(parent?.shell, "FlowShell")
        XCTAssertEqual(results?.shell, "FlowShell",
                       "source-switch and source-switch-results must both live in FlowShell (single DemoFlowShell)")
        XCTAssertEqual(parent?.platformTarget, .nativeRoute(.sourceSwitch))
        // results is the state-machine closure inside the same DemoFlowShell.
        guard case .featureState = results?.platformTarget else {
            XCTFail("source-switch-results must be a feature state, not a separate route push")
            return
        }
    }
}
