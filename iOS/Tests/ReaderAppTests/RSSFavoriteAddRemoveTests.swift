import XCTest
import SwiftUI
@testable import ReaderApp

/// P0/M2 closed-planned route closure: rss-favorite-add / rss-favorite-remove
///
/// 验收：
/// - rss-favorite-add 不再是 planned，stateModel 指向
///   RSSFavoriteGroupEditView(groupID: "new") 创建模式入口（真实存在）。
/// - rss-favorite-remove 不再是 planned，且 RSSFavoriteRemoveConfirmView 类型真实存在
///   并能以 groupName / onExit 构造（确认页闭环）。
@MainActor
final class RSSFavoriteAddRemoveTests: XCTestCase {

    // MARK: - rss-favorite-add route ownership

    func testRssFavoriteAddRouteIsConcreteFeatureState() {
        let mapping = DemoRouteMappings.mapping(for: "rss-favorite-add")
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.shell, "LibraryShell")
        guard case .featureState(let stateName) = mapping?.platformTarget else {
            return XCTFail("rss-favorite-add must map to a feature state")
        }
        XCTAssertTrue(stateName.contains("RSSFavoriteGroupEditView"),
                      "rss-favorite-add must reference RSSFavoriteGroupEditView")
        XCTAssertTrue(stateName.contains("\"new\""),
                      "rss-favorite-add feature state must pass groupID \"new\"")
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    func testRssFavoriteAddStateModelDescribesCreateState() {
        let mapping = DemoRouteMappings.mapping(for: "rss-favorite-add")
        XCTAssertTrue(mapping?.stateModel.contains("RSSFavoriteGroupEditView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("new-favorite-group create state") == true,
                      "stateModel must describe new-favorite-group create state")
        XCTAssertTrue(mapping?.stateModel.contains("RSSSupplementalRouteHost") == true)
    }

    // MARK: - rss-favorite-remove route ownership

    func testRssFavoriteRemoveRouteIsConcreteFeatureState() {
        let mapping = DemoRouteMappings.mapping(for: "rss-favorite-remove")
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.shell, "LibraryShell")
        guard case .featureState(let stateName) = mapping?.platformTarget else {
            return XCTFail("rss-favorite-remove must map to a feature state")
        }
        XCTAssertTrue(stateName.contains("RSSFavoriteRemoveConfirmView"),
                      "rss-favorite-remove feature state must reference RSSFavoriteRemoveConfirmView")
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    func testRssFavoriteRemoveStateModelDescribesConfirmFlow() {
        let mapping = DemoRouteMappings.mapping(for: "rss-favorite-remove")
        XCTAssertTrue(mapping?.stateModel.contains("RSSFavoriteRemoveConfirmView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("RSSSupplementalConfirmPage") == true)
        XCTAssertTrue(mapping?.stateModel.contains("danger icon") == true,
                      "remove confirm must use danger icon per demo spec")
        XCTAssertTrue(mapping?.stateModel.contains("cancel/confirm actions") == true)
    }

    // MARK: - RSSFavoriteGroupEditView create-mode initializer exists

    func testRSSFavoriteGroupEditViewCanInitInCreateMode() {
        let view = RSSFavoriteGroupEditView(groupID: "new")
        XCTAssertNotNil(view, "RSSFavoriteGroupEditView must accept groupID \"new\" for create mode")
    }

    func testRSSFavoriteGroupEditViewCanInitWithDefaultGroupID() {
        let view = RSSFavoriteGroupEditView()
        XCTAssertNotNil(view)
    }

    func testRSSFavoriteGroupEditViewCanInitWithOnExitClosure() {
        var exitCalled = false
        let view = RSSFavoriteGroupEditView(
            groupID: "new",
            title: "新建收藏分组",
            onExit: { exitCalled = true }
        )
        XCTAssertNotNil(view)
        XCTAssertFalse(exitCalled)
    }

    // MARK: - RSSFavoriteRemoveConfirmView type exists and closes the loop

    func testRSSFavoriteRemoveConfirmViewCanInitWithDefaultGroupName() {
        let view = RSSFavoriteRemoveConfirmView()
        XCTAssertNotNil(view, "RSSFavoriteRemoveConfirmView must be instantiable with default group name")
    }

    func testRSSFavoriteRemoveConfirmViewCanInitWithCustomGroupName() {
        let view = RSSFavoriteRemoveConfirmView(groupName: "技术周报")
        XCTAssertNotNil(view, "RSSFavoriteRemoveConfirmView must accept a custom group name for the confirm card")
    }

    func testRSSFavoriteRemoveConfirmViewCanInitWithOnExitClosure() {
        var exitCalled = false
        let view = RSSFavoriteRemoveConfirmView(groupName: "技术周报", onExit: { exitCalled = true })
        XCTAssertNotNil(view)
        XCTAssertFalse(exitCalled)
    }

    // MARK: - navigationEntry describes the full add/remove flow

    func testRssFavoriteAddNavigationEntryDescribesCreateFlow() {
        let mapping = DemoRouteMappings.mapping(for: "rss-favorite-add")
        XCTAssertTrue(mapping?.navigationEntry.contains("RSSFavoriteGroupsView") == true,
                      "rss-favorite-add must originate from RSSFavoriteGroupsView add action")
        XCTAssertTrue(mapping?.navigationEntry.contains("create mode") == true)
        XCTAssertTrue(mapping?.navigationEntry.contains("save") == true,
                      "rss-favorite-add must describe save action")
    }

    func testRssFavoriteRemoveNavigationEntryDescribesConfirmFlow() {
        let mapping = DemoRouteMappings.mapping(for: "rss-favorite-remove")
        XCTAssertTrue(mapping?.navigationEntry.contains("RSSFavoriteGroupsView") == true,
                      "rss-favorite-remove must originate from RSSFavoriteGroupsView remove action")
        XCTAssertTrue(mapping?.navigationEntry.contains("confirm") == true)
        XCTAssertTrue(mapping?.navigationEntry.contains("removes") == true,
                      "confirm action must describe removal of favorite group")
    }

    // MARK: - motionIDs describe the add/remove motions

    func testRssFavoriteAddMotionIDsIncludeCreateMotions() {
        let mapping = DemoRouteMappings.mapping(for: "rss-favorite-add")
        let motionIDs = mapping?.motionIDs ?? []
        XCTAssertTrue(motionIDs.contains("button.press"))
        XCTAssertTrue(motionIDs.contains("input.focus"))
        XCTAssertTrue(motionIDs.contains("app.route.push.forward"))
    }

    func testRssFavoriteRemoveMotionIDsIncludeConfirmMotions() {
        let mapping = DemoRouteMappings.mapping(for: "rss-favorite-remove")
        let motionIDs = mapping?.motionIDs ?? []
        XCTAssertTrue(motionIDs.contains("overlay.dialog.enter"))
        XCTAssertTrue(motionIDs.contains("overlay.dialog.exit"))
        XCTAssertTrue(motionIDs.contains("button.activate"))
    }
}
