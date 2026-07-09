import XCTest
@testable import ReaderApp

/// Demo 图标素材库对齐验证。
///
/// 真源：`Reader UI/frontend-demo-optimized/asset-library/icons.js`
/// 导入入口：`scripts/import_demo_icon_assets.mjs`
final class ReaderIconAssetAlignmentTests: XCTestCase {

    func testDemoIconRegistryBaselineCount() {
        XCTAssertEqual(ReaderAssetIcon.demoBaselineCount, 92)
        XCTAssertEqual(ReaderAssetIcon.allNames.count, ReaderAssetIcon.demoBaselineCount)
        XCTAssertEqual(Set(ReaderAssetIcon.allNames).count, ReaderAssetIcon.demoBaselineCount)
    }

    func testCriticalDemoIconTokensExist() {
        let names = Set(ReaderAssetIcon.allNames)
        XCTAssertTrue(names.contains("bookshelf"))
        XCTAssertTrue(names.contains("discover"))
        XCTAssertTrue(names.contains("rss"))
        XCTAssertTrue(names.contains("settings"))
        XCTAssertTrue(names.contains("reader-module-directory"))
        XCTAssertTrue(names.contains("reader-module-tts"))
        XCTAssertTrue(names.contains("reader-module-appearance"))
        XCTAssertTrue(names.contains("reader-module-settings"))
    }

    func testAssetNamePrefixMatchesGeneratedCatalog() {
        XCTAssertEqual(ReaderAssetIcon.bookshelf.assetName, "reader-icon-bookshelf")
        XCTAssertEqual(ReaderAssetIcon.discover.assetName, "reader-icon-discover")
        XCTAssertEqual(ReaderAssetIcon.readerModuleDirectory.assetName, "reader-icon-reader-module-directory")
    }

    func testMainTabsUseDemoAssetIcons() {
        XCTAssertEqual(AppTab.bookshelf.assetIcon, .bookshelf)
        XCTAssertEqual(AppTab.discover.assetIcon, .discover)
        XCTAssertEqual(AppTab.rss.assetIcon, .rss)
        XCTAssertEqual(AppTab.settings.assetIcon, .settings)
    }
}
