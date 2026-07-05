import XCTest
import SwiftUI
@testable import ReaderApp

/// P0/M2 closed-planned route closure: rss-rule-subscription-create
///
/// 验收：
/// - rss-rule-subscription-create 不再是 planned，stateModel 指向
///   RSSRuleSubscriptionEditView(subscriptionID: "new-subscription") 创建模式入口。
/// - RSSRuleSubscriptionEditView 类型真实存在并能以 subscriptionID 构造。
/// - navigationEntry 描述 RSSRuleSubscriptionView → edit → test 的完整创建链路。
@MainActor
final class RSSRuleSubscriptionCreateTests: XCTestCase {

    // MARK: - Route ownership

    func testRssRuleSubscriptionCreateRouteIsConcreteFeatureState() {
        let mapping = DemoRouteMappings.mapping(for: "rss-rule-subscription-create")
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.shell, "LibraryShell")
        guard case .featureState(let stateName) = mapping?.platformTarget else {
            return XCTFail("rss-rule-subscription-create must map to a feature state")
        }
        XCTAssertTrue(stateName.contains("RSSRuleSubscriptionEditView"),
                      "rss-rule-subscription-create must reference RSSRuleSubscriptionEditView")
        XCTAssertTrue(stateName.contains("\"new-subscription\""),
                      "rss-rule-subscription-create feature state must pass subscriptionID \"new-subscription\"")
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    func testRssRuleSubscriptionCreateStateModelDescribesCreateState() {
        let mapping = DemoRouteMappings.mapping(for: "rss-rule-subscription-create")
        XCTAssertTrue(mapping?.stateModel.contains("RSSRuleSubscriptionEditView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("new-subscription create state") == true,
                      "stateModel must describe new-subscription create state")
        XCTAssertTrue(mapping?.stateModel.contains("RSSSupplementalRouteHost") == true,
                      "stateModel must reference RSSSupplementalRouteHost for in-flow navigation")
    }

    // MARK: - RSSRuleSubscriptionEditView create-mode initializer exists

    func testRSSRuleSubscriptionEditViewCanInitInCreateMode() {
        let view = RSSRuleSubscriptionEditView(subscriptionID: "new-subscription")
        XCTAssertNotNil(view, "RSSRuleSubscriptionEditView must accept subscriptionID \"new-subscription\" for create mode")
    }

    func testRSSRuleSubscriptionEditViewCanInitWithDefaultSubscriptionID() {
        let view = RSSRuleSubscriptionEditView()
        XCTAssertNotNil(view)
    }

    func testRSSRuleSubscriptionEditViewCanInitWithOnExitClosure() {
        var exitCalled = false
        let view = RSSRuleSubscriptionEditView(
            subscriptionID: "new-subscription",
            title: "新建规则订阅",
            onExit: { exitCalled = true }
        )
        XCTAssertNotNil(view)
        // Verify the closure can be captured without crashing; full invocation requires
        // a SwiftUI environment, but instantiation alone closes the route contract.
        XCTAssertFalse(exitCalled)
    }

    // MARK: - navigationEntry describes the full create → test → save flow

    func testNavigationEntryDescribesCreateFlowFromRuleSubscriptionView() {
        let mapping = DemoRouteMappings.mapping(for: "rss-rule-subscription-create")
        XCTAssertTrue(mapping?.navigationEntry.contains("RSSRuleSubscriptionView") == true,
                      "rss-rule-subscription-create must originate from RSSRuleSubscriptionView create action")
        XCTAssertTrue(mapping?.navigationEntry.contains("create mode") == true,
                      "navigationEntry must describe create mode entry")
        XCTAssertTrue(mapping?.navigationEntry.contains("RSSRuleSubscriptionTestView") == true,
                      "navigationEntry must describe test action pushing RSSRuleSubscriptionTestView")
    }

    // MARK: - motionIDs describe the create flow motions

    func testMotionIDsIncludeCreateFlowMotions() {
        let mapping = DemoRouteMappings.mapping(for: "rss-rule-subscription-create")
        let motionIDs = mapping?.motionIDs ?? []
        XCTAssertTrue(motionIDs.contains("button.press"))
        XCTAssertTrue(motionIDs.contains("button.activate"))
        XCTAssertTrue(motionIDs.contains("input.focus"))
        XCTAssertTrue(motionIDs.contains("app.route.push.forward"),
                      "create flow must include route push forward motion")
    }
}
