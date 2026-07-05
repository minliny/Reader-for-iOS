import XCTest
@testable import ReaderApp

/// P0/M2 closed-planned route closure: rss-source-category-novel / -tech / -booklist
///
/// 验收：3 个新分类 route 不是 planned，且 RSSDemoRouteState 真实驱动分类切换
/// （RSSDemoCategoryFilter 选中后通过 onSelectRoute 切换 RSSFeedView 的 activeDemoRoute）。
@MainActor
final class RSSCategoryExtensionTests: XCTestCase {

    // MARK: - Route ownership: 3 new categories are concrete feature states

    func testRssSourceCategoryNovelRouteIsConcreteFeatureState() {
        let mapping = DemoRouteMappings.mapping(for: "rss-source-category-novel")
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.shell, "LibraryShell")
        guard case .featureState(let stateName) = mapping?.platformTarget else {
            return XCTFail("rss-source-category-novel must map to a feature state")
        }
        XCTAssertTrue(stateName.contains("RSSFeedView"))
        XCTAssertTrue(stateName.contains("rss-source-category-novel"))
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    func testRssSourceCategoryTechRouteIsConcreteFeatureState() {
        let mapping = DemoRouteMappings.mapping(for: "rss-source-category-tech")
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.shell, "LibraryShell")
        guard case .featureState(let stateName) = mapping?.platformTarget else {
            return XCTFail("rss-source-category-tech must map to a feature state")
        }
        XCTAssertTrue(stateName.contains("RSSFeedView"))
        XCTAssertTrue(stateName.contains("rss-source-category-tech"))
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    func testRssSourceCategoryBooklistRouteIsConcreteFeatureState() {
        let mapping = DemoRouteMappings.mapping(for: "rss-source-category-booklist")
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.shell, "LibraryShell")
        guard case .featureState(let stateName) = mapping?.platformTarget else {
            return XCTFail("rss-source-category-booklist must map to a feature state")
        }
        XCTAssertTrue(stateName.contains("RSSFeedView"))
        XCTAssertTrue(stateName.contains("rss-source-category-booklist"))
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    // MARK: - State model describes the RSSDemoCategory filter

    func testNovelStateModelReferencesRSSDemoCategoryAndFilter() {
        let mapping = DemoRouteMappings.mapping(for: "rss-source-category-novel")
        XCTAssertTrue(mapping?.stateModel.contains("RSSDemoCategory") == true)
        XCTAssertTrue(mapping?.stateModel.contains("RSSDemoCategoryFilter") == true)
        XCTAssertTrue(mapping?.stateModel.contains("RSSDemoRouteState") == true)
    }

    func testTechStateModelReferencesRSSDemoCategoryAndFilter() {
        let mapping = DemoRouteMappings.mapping(for: "rss-source-category-tech")
        XCTAssertTrue(mapping?.stateModel.contains("RSSDemoCategory") == true)
        XCTAssertTrue(mapping?.stateModel.contains("RSSDemoCategoryFilter") == true)
    }

    func testBooklistStateModelReferencesRSSDemoCategoryAndFilter() {
        let mapping = DemoRouteMappings.mapping(for: "rss-source-category-booklist")
        XCTAssertTrue(mapping?.stateModel.contains("RSSDemoCategory") == true)
        XCTAssertTrue(mapping?.stateModel.contains("RSSDemoCategoryFilter") == true)
    }

    // MARK: - RSSDemoRouteState drives category switching

    func testRSSDemoRouteStateResolvesNovelCategory() {
        let state = RSSDemoRouteState(route: "rss-source-category-novel")
        XCTAssertEqual(state.route, "rss-source-category-novel")
        XCTAssertEqual(state.category.route, "rss-source-category-novel")
        XCTAssertEqual(state.category.label, "Novel")
        XCTAssertEqual(state.presentation, .sourceFeed)
        XCTAssertEqual(RSSDemoRouteState.selectedMode(for: "rss-source-category-novel"), "源列表")
    }

    func testRSSDemoRouteStateResolvesTechCategory() {
        let state = RSSDemoRouteState(route: "rss-source-category-tech")
        XCTAssertEqual(state.route, "rss-source-category-tech")
        XCTAssertEqual(state.category.route, "rss-source-category-tech")
        XCTAssertEqual(state.category.label, "Tech")
        XCTAssertEqual(state.presentation, .sourceFeed)
    }

    func testRSSDemoRouteStateResolvesBooklistCategory() {
        let state = RSSDemoRouteState(route: "rss-source-category-booklist")
        XCTAssertEqual(state.route, "rss-source-category-booklist")
        XCTAssertEqual(state.category.route, "rss-source-category-booklist")
        XCTAssertEqual(state.category.label, "Booklist")
        XCTAssertEqual(state.presentation, .sourceFeed)
    }

    // MARK: - Existing categories still resolve (no regression)

    func testRSSDemoRouteStateResolvesExistingReleasesCategory() {
        let state = RSSDemoRouteState(route: "rss-source-category-releases")
        XCTAssertEqual(state.category.label, "Releases")
        XCTAssertEqual(state.presentation, .sourceFeed)
    }

    func testRSSDemoRouteStateResolvesDefaultFeedCategory() {
        let state = RSSDemoRouteState(route: "rss-source-feed")
        XCTAssertEqual(state.category.label, "全部")
        XCTAssertEqual(state.presentation, .sourceFeed)
    }

    // MARK: - Articles are filtered for the new categories

    func testNovelCategoryReturnsArticles() {
        let state = RSSDemoRouteState(route: "rss-source-category-novel")
        XCTAssertFalse(state.articles.isEmpty,
                       "rss-source-category-novel must surface articles via RSSDemoRouteState.articles")
    }

    func testTechCategoryReturnsArticles() {
        let state = RSSDemoRouteState(route: "rss-source-category-tech")
        XCTAssertFalse(state.articles.isEmpty)
    }

    func testBooklistCategoryReturnsArticles() {
        let state = RSSDemoRouteState(route: "rss-source-category-booklist")
        XCTAssertFalse(state.articles.isEmpty)
    }
}
