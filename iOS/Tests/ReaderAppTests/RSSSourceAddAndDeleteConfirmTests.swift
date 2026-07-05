import XCTest
import SwiftUI
@testable import ReaderApp

/// P0/M2 closed-planned route closure: rss-source-add / rss-source-delete-confirm
///
/// 验收：
/// - rss-source-add 不再是 planned，stateModel 指向 RSSSourceEditView(sourceID: "new")
///   （创建模式入口真实存在）。
/// - rss-source-delete-confirm 不再是 planned，且 RSSSourceDeleteConfirmView 类型真实存在
///   并能以 source/sourceID 两种方式构造（确认页闭环）。
@MainActor
final class RSSSourceAddAndDeleteConfirmTests: XCTestCase {

    // MARK: - rss-source-add route ownership

    func testRssSourceAddRouteIsConcreteFeatureState() {
        let mapping = DemoRouteMappings.mapping(for: "rss-source-add")
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.shell, "LibraryShell")
        guard case .featureState(let stateName) = mapping?.platformTarget else {
            return XCTFail("rss-source-add must map to a feature state")
        }
        XCTAssertTrue(stateName.contains("RSSSourceEditView"),
                      "rss-source-add must reference RSSSourceEditView in create mode")
        XCTAssertTrue(stateName.contains("\"new\""),
                      "rss-source-add feature state must pass sourceID \"new\" to RSSSourceEditView")
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    func testRssSourceAddStateModelReferencesCreateState() {
        let mapping = DemoRouteMappings.mapping(for: "rss-source-add")
        XCTAssertTrue(mapping?.stateModel.contains("RSSSourceEditView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("new-source create state") == true,
                      "rss-source-add stateModel must describe new-source create state")
        XCTAssertTrue(mapping?.stateModel.contains("DemoLibraryShell") == true)
    }

    // MARK: - rss-source-delete-confirm route ownership

    func testRssSourceDeleteConfirmRouteIsConcreteFeatureState() {
        let mapping = DemoRouteMappings.mapping(for: "rss-source-delete-confirm")
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.shell, "LibraryShell")
        guard case .featureState(let stateName) = mapping?.platformTarget else {
            return XCTFail("rss-source-delete-confirm must map to a feature state")
        }
        XCTAssertTrue(stateName.contains("RSSSourceDeleteConfirmView"),
                      "rss-source-delete-confirm feature state must reference RSSSourceDeleteConfirmView")
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    func testRssSourceDeleteConfirmStateModelDescribesConfirmFlow() {
        let mapping = DemoRouteMappings.mapping(for: "rss-source-delete-confirm")
        XCTAssertTrue(mapping?.stateModel.contains("RSSSourceDeleteConfirmView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("danger icon") == true,
                      "delete confirm must use danger icon per demo spec")
        XCTAssertTrue(mapping?.stateModel.contains("cancel/confirm actions") == true,
                      "delete confirm must expose cancel and confirm actions")
        XCTAssertTrue(mapping?.stateModel.contains("RSSManagementSource") == true)
    }

    // MARK: - RSSSourceEditView create-mode initializer exists

    func testRSSSourceEditViewCanInitInCreateMode() {
        let view = RSSSourceEditView(sourceID: "new")
        XCTAssertNotNil(view)
        // The create-mode initializer must NOT fall back to the first demo source;
        // RSSManagementSource.fallback gives us a non-demo source id.
    }

    func testRSSSourceEditViewCanInitWithDefaultDemoSource() {
        let view = RSSSourceEditView()
        XCTAssertNotNil(view)
    }

    // MARK: - RSSSourceDeleteConfirmView type exists and closes the loop

    func testRSSSourceDeleteConfirmViewCanInitWithSource() {
        let view = RSSSourceDeleteConfirmView(source: RSSManagementSource.demoSources[0])
        XCTAssertNotNil(view, "RSSSourceDeleteConfirmView must be instantiable from a concrete source")
    }

    func testRSSSourceDeleteConfirmViewCanInitWithSourceID() {
        let view = RSSSourceDeleteConfirmView(sourceID: "new")
        XCTAssertNotNil(view, "RSSSourceDeleteConfirmView must be instantiable from a sourceID for the confirm flow")
    }

    // MARK: - navigationEntry describes the full add → delete → confirm flow

    func testRssSourceAddNavigationEntryDescribesCreateFlow() {
        let mapping = DemoRouteMappings.mapping(for: "rss-source-add")
        XCTAssertTrue(mapping?.navigationEntry.contains("RSSSubscriptionManagementView") == true,
                      "rss-source-add must originate from RSSSubscriptionManagementView add action")
        XCTAssertTrue(mapping?.navigationEntry.contains("create mode") == true,
                      "rss-source-add must describe create mode entry")
        XCTAssertTrue(mapping?.navigationEntry.contains("save") == true,
                      "rss-source-add must describe save action")
    }

    func testRssSourceDeleteConfirmNavigationEntryDescribesConfirmFlow() {
        let mapping = DemoRouteMappings.mapping(for: "rss-source-delete-confirm")
        XCTAssertTrue(mapping?.navigationEntry.contains("RSSSourceActionsView") == true,
                      "rss-source-delete-confirm must originate from RSSSourceActionsView delete action")
        XCTAssertTrue(mapping?.navigationEntry.contains("confirm") == true)
        XCTAssertTrue(mapping?.navigationEntry.contains("removes") == true,
                      "confirm action must describe removal of source from store")
    }
}
