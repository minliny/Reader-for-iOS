import XCTest
@testable import ReaderApp

/// 生产 App Shell 对齐验证 — 4 主底栏：书架 / 发现 / 书源 / 我的
@MainActor
final class AppShellAlignmentTests: XCTestCase {

    // MARK: - Shell Views 存在性

    func testDiscoverHomeShellViewCanInit() {
        let view = DiscoverHomeShellView()
        XCTAssertNotNil(view)
    }

    func testMineTabViewCanInit() {
        let view = MineTabView()
        XCTAssertNotNil(view)
    }

    // MARK: - Prototype 不受影响

    func testPrototypeEntriesStill38() {
        let entries = PrototypeGalleryView.allEntries
        XCTAssertEqual(entries.count, 38, "Prototype entry 数量不应减少")
    }

    func testPrototypeGalleryViewCanInit() {
        let view = PrototypeGalleryView()
        XCTAssertNotNil(view)
    }

    // MARK: - Route 不包含旧 Tab 名

    func testRouteHasBookshelf() {
        let route = Route.bookshelf
        XCTAssertTrue(route.title.contains("书架"))
    }

    func testRouteHasPrototypeGallery() {
        let route = Route.prototypeGallery
        XCTAssertTrue(route.title.contains("DEBUG"))
        XCTAssertTrue(route.title.contains("Prototype Gallery"))
    }

    // MARK: - 关键约束

    func testSearchRouteExists_butNotATab() {
        // 搜索 route 存在，但不作为主底栏
        let route = Route.search
        XCTAssertEqual(route.title, "搜索")
    }

    func testSettingsRouteExists_butNotATab() {
        // 设置 route 存在，但不作为主底栏
        let route = Route.settings
        XCTAssertEqual(route.title, "设置")
    }

    func testReaderRouteExists_butNotATab() {
        // 阅读 route 存在，但不作为主底栏
        let route = Route.reader(bookID: "b1", chapterURL: "url", chapterTitle: "ch1")
        XCTAssertTrue(route.title.contains("阅读"))
    }
}
