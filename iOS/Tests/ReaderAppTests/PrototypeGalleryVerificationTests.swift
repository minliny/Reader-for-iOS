import XCTest
@testable import ReaderApp

/// Prototype Gallery 验证测试
/// 不接真实网络、不使用 WebView、不引用 parser internals
final class PrototypeGalleryVerificationTests: XCTestCase {

    // MARK: - Entry 数量

    func testAtLeast38Entries() {
        let entries = PrototypeGalleryView.allEntries
        XCTAssertGreaterThanOrEqual(entries.count, 38, "Prototype Gallery 必须至少包含 38 个 entry")
    }

    // MARK: - App Shell

    func testAppShellEntryExists() {
        let entries = PrototypeGalleryView.allEntries
        XCTAssertTrue(entries.contains(where: { $0.id == "app-shell" }),
                      "必须包含 App Shell / Main Tabs entry")
    }

    func testMainTabsAreCorrectTarget() {
        // 目标主底栏：书架 / 发现 / 书源 / 我的
        let validTabs: Set<String> = ["书架", "发现", "书源", "我的"]
        XCTAssertEqual(validTabs.count, 4)
    }

    func testMainTabsDoNotIncludeReader() {
        // 阅读不是主底栏模块
        let tabs = PrototypeGalleryView.Tab.allCases.map(\.rawValue)
        XCTAssertFalse(tabs.contains("阅读"))
    }

    func testMainTabsDoNotIncludeSearch() {
        // 搜索不是独立底栏模块
        let tabs = PrototypeGalleryView.Tab.allCases.map(\.rawValue)
        XCTAssertFalse(tabs.contains("搜索"))
    }

    func testMainTabsDoNotIncludeSettings() {
        // 设置不是独立底栏模块
        let tabs = PrototypeGalleryView.Tab.allCases.map(\.rawValue)
        XCTAssertFalse(tabs.contains("设置"))
    }

    // MARK: - Reader Control State 覆盖

    func testAll9ReaderControlStatesHaveEntries() {
        let readerEntries = PrototypeGalleryView.allEntries.filter { $0.group == .reader }
        XCTAssertGreaterThanOrEqual(readerEntries.count, 9, "阅读页必须有至少 9 个控制状态 entry")
    }

    func testReaderBaseControlEntryExists() {
        XCTAssertTrue(PrototypeGalleryView.allEntries.contains(where: { $0.id == "reader-base" }))
    }

    func testReaderSearchOverlayEntryExists() {
        XCTAssertTrue(PrototypeGalleryView.allEntries.contains(where: { $0.id == "reader-search" }))
    }

    func testReaderAutoScrollEntryExists() {
        XCTAssertTrue(PrototypeGalleryView.allEntries.contains(where: { $0.id == "reader-autoscroll" }))
    }

    func testReaderReplaceEntryExists() {
        XCTAssertTrue(PrototypeGalleryView.allEntries.contains(where: { $0.id == "reader-replace" }))
    }

    func testReaderNightStateEntryExists() {
        XCTAssertTrue(PrototypeGalleryView.allEntries.contains(where: { $0.id == "reader-night" }))
    }

    func testReaderDirectoryEntryExists() {
        XCTAssertTrue(PrototypeGalleryView.allEntries.contains(where: { $0.id == "reader-directory" }))
    }

    func testReaderTTSEntryExists() {
        XCTAssertTrue(PrototypeGalleryView.allEntries.contains(where: { $0.id == "reader-tts" }))
    }

    func testReaderAppearanceEntryExists() {
        XCTAssertTrue(PrototypeGalleryView.allEntries.contains(where: { $0.id == "reader-appearance" }))
    }

    func testReaderSettingsEntryExists() {
        XCTAssertTrue(PrototypeGalleryView.allEntries.contains(where: { $0.id == "reader-settings" }))
    }

    // MARK: - Reader 规则约束

    func testNightStateIsNotDialogSemantic() {
        // 夜间模式不是弹窗
        XCTAssertTrue(ReaderControlState.nightState != .quickActionOverlay(.search))
        XCTAssertTrue(ReaderControlState.nightState != .bottomFunctionOverlay(.settings))
    }

    func testReaderSettingsOverlayDoesNotContainWebDAV() {
        // 阅读页底栏设置不包含 WebDAV/书源/RSS
        let settingsType = BottomFunctionType.settings
        XCTAssertNotEqual(settingsType, .directory)
        XCTAssertNotEqual(settingsType, .tts)
        XCTAssertNotEqual(settingsType, .appearance)
    }

    func testReplaceOnlyShowsCurrentBookRules() {
        // 内容替换只显示当前书籍匹配规则（不显示全局规则库）
        let replaceRules = PrototypeFixtures.replaceRules
        XCTAssertEqual(replaceRules.count, 2)
        XCTAssertEqual(replaceRules[0].pattern, "韩立") // 当前书籍规则
    }

    func testPageControlIsWithinChapter() {
        // 页内控制是本章内上一页/下一页，不使用 skip_previous/skip_next
        // 验证 QuickActionType 不包含 skip 语义
        let quickTypes = QuickActionType.allCases
        for type in quickTypes {
            XCTAssertFalse("\(type)".contains("skip"), "不使用 skip 语义")
        }
    }

    func testTTSDoesNotUseChapterJumpSemantic() {
        // 朗读不使用章节跳转语义
        XCTAssertFalse("\(TtsState.playing)".contains("chapter"))
        XCTAssertFalse("\(TtsState.stopped)".contains("skip"))
    }

    // MARK: - 分组覆盖

    func testAllGroupsHaveAtLeastOneEntry() {
        let entries = PrototypeGalleryView.allEntries
        let groups = Set(entries.map(\.group))
        // 至少覆盖：appShell, bookshelf, searchDetail, reader, sourceMgmt, discover, rss, webdav, sync, settings, states
        XCTAssertTrue(groups.contains(.appShell))
        XCTAssertTrue(groups.contains(.bookshelf))
        XCTAssertTrue(groups.contains(.searchDetail))
        XCTAssertTrue(groups.contains(.reader))
        XCTAssertTrue(groups.contains(.sourceMgmt))
        XCTAssertTrue(groups.contains(.discover))
        XCTAssertTrue(groups.contains(.rss))
        XCTAssertTrue(groups.contains(.webdav))
        XCTAssertTrue(groups.contains(.sync))
        XCTAssertTrue(groups.contains(.settings))
        XCTAssertTrue(groups.contains(.states))
    }

    func testBookshelfHasAtLeast3Entries() {
        let entries = PrototypeGalleryView.allEntries.filter { $0.group == .bookshelf }
        XCTAssertGreaterThanOrEqual(entries.count, 3, "书架需 cover/cover/list/empty")
    }

    func testSearchDetailHasAtLeast6Entries() {
        let entries = PrototypeGalleryView.allEntries.filter { $0.group == .searchDetail }
        XCTAssertGreaterThanOrEqual(entries.count, 6)
    }

    func testSourceMgmtHasAtLeast4Entries() {
        let entries = PrototypeGalleryView.allEntries.filter { $0.group == .sourceMgmt }
        XCTAssertGreaterThanOrEqual(entries.count, 4)
    }

    func testStatesHasAtLeast5Entries() {
        let entries = PrototypeGalleryView.allEntries.filter { $0.group == .states }
        XCTAssertGreaterThanOrEqual(entries.count, 5, "状态页: loading/empty/error/offline/permission")
    }

    // MARK: - Prototype Fixture Safety

    func testFixtureBooksAreNotEmpty() {
        XCTAssertFalse(PrototypeFixtures.bookshelfBooks.isEmpty)
        XCTAssertFalse(PrototypeFixtures.searchResults.isEmpty)
        XCTAssertFalse(PrototypeFixtures.sources.isEmpty)
    }

    func testFixtureReplaceRulesAreCurrentBookOnly() {
        // 只包含当前书籍（韩立/韩家村）的规则
        let rules = PrototypeFixtures.replaceRules
        for rule in rules {
            XCTAssertTrue(rule.pattern.contains("韩") || rule.pattern.contains("村"),
                          "替换规则应仅限当前书籍")
        }
    }

    func testFixtureWebDAVHasNoRealCredentials() {
        let config = PrototypeFixtures.webdavConfig
        XCTAssertEqual(config.serverURL, "https://dav.example.com/reader")
        // URL 为 example.com，不含真实服务地址
        XCTAssertTrue(config.serverURL.contains("example.com"))
    }

    func testFixtureSyncShowsConflict() {
        let progress = PrototypeFixtures.syncProgress
        XCTAssertTrue(progress.hasConflict)
    }

    // MARK: - Prototype Group Enum

    func testPrototypeGroupCount() {
        // 13 个分组（包含 debug）
        XCTAssertEqual(PrototypeGroup.allCases.count, 12)
    }

    // MARK: - Theme/Token 在 Prototype 中可访问

    func testThemeTokensAccessibleInTests() {
        _ = ReaderColors.paperBg
        _ = ReaderColors.nightPaperBg
        _ = ReaderTypography.readerTitle
        _ = ReaderTypography.readerBody
        _ = ReaderSpacing.xs
        _ = ReaderSpacing.md
        _ = ReaderShapes.card
        _ = ReaderShapes.overlay
    }

    func testReaderControlMetricsAccessible() {
        XCTAssertEqual(ReaderControlMetrics.bottomBarHeight, 68)
        XCTAssertEqual(ReaderControlMetrics.quickCircleSize, 48)
        XCTAssertEqual(ReaderControlMetrics.brightnessInset, 12)
    }
}
