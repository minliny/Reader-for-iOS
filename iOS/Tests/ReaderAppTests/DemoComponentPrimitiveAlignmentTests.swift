import XCTest
import SwiftUI
import ReaderCoreModels
import ReaderAppSupport
@testable import ReaderApp

final class DemoComponentPrimitiveAlignmentTests: XCTestCase {

    func testDiscoverControlTokensMatchDemoMatrix() {
        XCTAssertEqual(ReaderDesignTokens.discoverSourceBarMinHeight, 58)
        XCTAssertEqual(ReaderDesignTokens.discoverSourceIconColumn, 34)
        XCTAssertEqual(ReaderDesignTokens.discoverSourceChevronColumn, 18)
        XCTAssertEqual(ReaderDesignTokens.discoverSourceGap, 10)
        XCTAssertEqual(ReaderDesignTokens.discoverEntryRowGap, 7)
        XCTAssertEqual(ReaderDesignTokens.chipMinHeight, 32)
    }

    @MainActor
    func testDiscoverFeatureStateViewsCanInitFromDemoRoutes() {
        let routes = DemoRouteMappings.expectedMainTabShellRoutes.filter { $0.hasPrefix("discover-") }
        XCTAssertEqual(routes.count, 30)
        for route in routes {
            let view = DiscoverHomeShellView(demoRoute: route)
            XCTAssertNotNil(view)
        }
    }

    func testRSSControlTokensMatchDemoMatrix() {
        XCTAssertEqual(ReaderDesignTokens.rssSummaryMinHeight, 62)
        XCTAssertEqual(ReaderDesignTokens.rssSummaryIconColumn, 34)
        XCTAssertEqual(ReaderDesignTokens.rssModeRowMinHeight, 30)
        XCTAssertEqual(ReaderDesignTokens.rssTopBarGap, 10)
        XCTAssertEqual(ReaderDesignTokens.rssTopActionMinHeight, 34)
        XCTAssertEqual(ReaderDesignTokens.rssTopRefreshDotSize, 9)
        XCTAssertEqual(ReaderDesignTokens.rssTopRefreshGap, 7)
        XCTAssertEqual(ReaderDesignTokens.rssTopManageMinWidth, 64)
        XCTAssertEqual(ReaderDesignTokens.rssSourceStripItemWidth, 138)
        XCTAssertEqual(ReaderDesignTokens.rssSourceStripMinHeight, 58)
        XCTAssertEqual(ReaderDesignTokens.rssSearchEntryMinHeight, 44)
    }

    @MainActor
    func testRSSFeatureStateViewsCanInitFromDemoRoutes() {
        let routes = [
            "rss-all",
            "rss-starred",
            "rss-source-feed",
            "rss-source-category-releases",
            "rss-source-category-issues",
            "rss-source-category-discussions",
            "rss-refreshing"
        ]
        for route in routes {
            let view = RSSFeedView(demoRoute: route)
            XCTAssertNotNil(view)
        }
    }

    @MainActor
    func testDiscoverSourceLoginAndBookshelfManagementViewsCanInit() {
        let loginView = DiscoverSourceLoginView()
        let batchView = BookshelfBatchManagementView()
        let groupView = BookshelfGroupManagementView()
        let localImportView = BookshelfLocalImportView()
        let searchView = SearchView()
        let directoryView = BookDirectoryPreviewView(bookURL: "demo://book/long-night", title: "长夜余火")
        XCTAssertNotNil(loginView)
        XCTAssertNotNil(batchView)
        XCTAssertNotNil(groupView)
        XCTAssertNotNil(localImportView)
        XCTAssertNotNil(searchView)
        XCTAssertNotNil(directoryView)
    }

    @MainActor
    func testLegacyCompatibilitySurfacesUseDemoPrimitives() {
        let source = BookSource(id: "legacy-source", bookSourceName: "兼容书源", bookSourceUrl: "https://legacy.example")
        let result = SearchResultItem(
            title: "长夜余火",
            detailURL: "demo://book/long-night",
            author: "爱潜水的乌贼",
            intro: "旧世界的余烬尚未冷却。"
        )
        let item = BookshelfItem(
            id: "demo-book",
            sourceID: "demo-source",
            sourceName: "优书网",
            bookURL: "demo://book/long-night",
            title: "长夜余火",
            author: "爱潜水的乌贼",
            latestChapter: "第 32 章 雨夜",
            addedAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_010_000),
            lastReadChapterTitle: "第 32 章 雨夜",
            lastReadChapterURL: "demo://chapter/32",
            readingProgress: 0.38
        )
        let error = ReaderError(code: .unknown, message: "兼容错误")

        XCTAssertNotNil(FileImportView())
        XCTAssertNotNil(BookSourceDetailView(source: source))
        XCTAssertNotNil(SearchResultRowView(result: result, sourceName: "优书网"))
        XCTAssertNotNil(BookshelfItemRowView(item: item))
        XCTAssertNotNil(ErrorView(error: error))
        XCTAssertNotNil(ReaderEmptyStateView(title: "暂无内容", message: "稍后再试", systemImage: "book"))
        XCTAssertNotNil(ReaderSessionSummaryView(title: "长夜余火", subtitle: "第 32 章 雨夜", actionTitle: "继续阅读") {})
        XCTAssertNotNil(MineTabView())
        XCTAssertEqual(ReaderDesignTokens.searchResultRowMinHeight, 86)
        XCTAssertEqual(ReaderDesignTokens.bookListCardMinHeight, 66)
        XCTAssertEqual(ReaderDesignTokens.settingsRowMinHeight, 58)
        XCTAssertEqual(ReaderDesignTokens.settingsSwitchTrackWidth, 38)
        XCTAssertEqual(ReaderAssetIcon.warning.rawValue, "warning")
        XCTAssertEqual(ReaderAssetIcon.cloud.rawValue, "cloud")
    }

    func testRSSReaderDetailTokensMatchDemoMatrix() {
        XCTAssertEqual(ReaderDesignTokens.rssReaderSourceMinHeight, 58)
        XCTAssertEqual(ReaderDesignTokens.rssReaderSourceIconSize, 32)
        XCTAssertEqual(ReaderDesignTokens.rssReaderTitleFontSize, 20)
        XCTAssertEqual(ReaderDesignTokens.rssReaderTitleLineHeight, 1.28)
        XCTAssertEqual(ReaderDesignTokens.rssReaderSubtitleFontSize, 13)
        XCTAssertEqual(ReaderDesignTokens.rssReaderSubtitleLineHeight, 1.62)
        XCTAssertEqual(ReaderDesignTokens.rssReaderInlineActionMinHeight, 34)
        XCTAssertEqual(ReaderDesignTokens.rssReaderBodyFontSize, 15)
        XCTAssertEqual(ReaderDesignTokens.rssReaderBodyLineHeight, 1.86)
        XCTAssertEqual(ReaderDesignTokens.rssReaderOriginalCardMinHeight, 58)
        XCTAssertEqual(ReaderDesignTokens.rssReaderBottomActionsMinHeight, 86)
    }

    func testRSSOriginalPreviewTokensMatchDemoMatrix() {
        XCTAssertEqual(ReaderDesignTokens.rssOriginalPreviewGap, 12)
        XCTAssertEqual(ReaderDesignTokens.rssOriginalHeaderMinHeight, 62)
        XCTAssertEqual(ReaderDesignTokens.rssOriginalHeaderIconSize, 32)
        XCTAssertEqual(ReaderDesignTokens.rssOriginalWebPreviewMinHeight, 360)
        XCTAssertEqual(ReaderDesignTokens.rssOriginalWebPreviewTitleFontSize, 17)
        XCTAssertEqual(ReaderDesignTokens.rssOriginalWebPreviewBodyFontSize, 13)
    }

    func testRSSBrowserConfirmTokensMatchDemoMatrix() {
        XCTAssertEqual(ReaderDesignTokens.rssBrowserConfirmCardMinHeight, 256)
        XCTAssertEqual(ReaderDesignTokens.rssBrowserConfirmIconSize, 44)
        XCTAssertEqual(ReaderDesignTokens.rssBrowserConfirmGap, 10)
        XCTAssertEqual(ReaderDesignTokens.rssBrowserConfirmVerticalPadding, 26)
        XCTAssertEqual(ReaderDesignTokens.rssBrowserConfirmHorizontalPadding, 18)
        XCTAssertEqual(ReaderDesignTokens.rssBrowserConfirmTextMaxWidth, 278)
        XCTAssertEqual(ReaderDesignTokens.rssBrowserConfirmTitleFontSize, 17)
        XCTAssertEqual(ReaderDesignTokens.rssBrowserConfirmBodyFontSize, 13)
        XCTAssertEqual(ReaderDesignTokens.rssBrowserConfirmDetailFontSize, 11)
    }

    func testSharedStateSurfaceUsesDemoStateAndConfirmTokens() {
        XCTAssertEqual(StateSurfaceKind.error(message: "失败").routeTitle, "错误")
        XCTAssertEqual(StateSurfaceKind.error(message: "失败").icon, .warning)
        XCTAssertEqual(StateSurfaceKind.offline.routeTitle, "离线")
        XCTAssertEqual(StateSurfaceKind.offline.icon, .offline)
        XCTAssertEqual(StateSurfaceKind.permission(permission: "本地文件").routeTitle, "权限")
        XCTAssertEqual(StateSurfaceKind.permission(permission: "本地文件").icon, .permission)
        XCTAssertEqual(ReaderDesignTokens.rssBrowserConfirmCardMinHeight, 256)
        XCTAssertEqual(ReaderDesignTokens.bottomFixedActionRowMinHeight, 52)
        XCTAssertEqual(ReaderDesignTokens.bottomFixedActionButtonMinHeight, 46)
    }

    func testRSSSourceManagementTokensMatchDemoMatrix() {
        XCTAssertEqual(ReaderDesignTokens.rssManageActionButtonMinHeight, 38)
        XCTAssertEqual(ReaderDesignTokens.rssManageActionGridGap, 6)
        XCTAssertEqual(ReaderDesignTokens.rssSourceListRowMinHeight, 58)
        XCTAssertEqual(ReaderDesignTokens.rssSourceListIconSize, 30)
        XCTAssertEqual(ReaderDesignTokens.rssSourceListStatusWidth, 24)
        XCTAssertEqual(ReaderDesignTokens.rssSourceListMoreButtonSize, 30)
        XCTAssertEqual(ReaderDesignTokens.rssManageBatchRowMinHeight, 38)
        XCTAssertEqual(ReaderDesignTokens.rssSourceSettingsRowMinHeight, 50)
        XCTAssertEqual(ReaderDesignTokens.rssActionSourceCardMinHeight, 64)
        XCTAssertEqual(ReaderDesignTokens.rssActionGridColumns, 4)
        XCTAssertEqual(ReaderDesignTokens.rssActionGridGap, 7)
        XCTAssertEqual(ReaderDesignTokens.rssActionGridButtonMinHeight, 58)
        XCTAssertEqual(ReaderDesignTokens.rssActionGridCompactButtonMinHeight, 54)
        XCTAssertEqual(ReaderDesignTokens.rssEditTabsMinHeight, 30)
        XCTAssertEqual(ReaderDesignTokens.rssEditListRowMinHeight, 56)
        XCTAssertEqual(ReaderDesignTokens.rssDebugPanelPadding, 10)
        XCTAssertEqual(ReaderDesignTokens.rssDebugHeaderIconSize, 30)
        XCTAssertEqual(ReaderDesignTokens.rssImportPanelPadding, 10)
        XCTAssertEqual(ReaderDesignTokens.rssImportPanelLabelMinHeight, 38)
        XCTAssertEqual(ReaderDesignTokens.rssImportListIconSize, 28)
        XCTAssertEqual(ReaderDesignTokens.rssImportListActionMinHeight, 28)
        XCTAssertEqual(ReaderDesignTokens.rssManagementListRowMinHeight, 54)
    }

    @MainActor
    func testRSSArticleDetailViewCanInitFromSubscriptionItem() {
        let item = SubscriptionItem(
            title: "Reader UI 前端输入件更新说明",
            link: "https://example.com/rss/article",
            author: "GitHub Releases",
            summary: "RSS 阅读页展示正文、原文入口和源相关操作。",
            publishedAt: Date(timeIntervalSince1970: 1_800_000_000),
            sourceId: "github-releases",
            sourceName: "GitHub Releases"
        )

        let view = RSSArticleDetailView(item: item, sourceTitle: "GitHub Releases")
        XCTAssertNotNil(view)

        let fallback = RSSArticleDetailView.fallbackItem(link: "https://example.com/fallback")
        XCTAssertEqual(fallback.title, "RSS 阅读")
        XCTAssertEqual(fallback.sourceName, "RSS")
    }

    @MainActor
    func testRSSOriginalPreviewViewCanInitFromOriginalURL() {
        let view = RSSOriginalPreviewView(
            urlString: "https://example.com/article",
            title: "Reader UI 前端输入件更新说明",
            sourceTitle: "GitHub Releases"
        )
        XCTAssertNotNil(view)
    }

    @MainActor
    func testRSSOriginalBrowserConfirmViewCanInitFromOriginalURL() {
        let view = RSSOriginalBrowserConfirmView(
            urlString: "https://example.com/article",
            title: "Reader UI 前端输入件更新说明",
            sourceTitle: "GitHub Releases"
        )
        XCTAssertNotNil(view)
    }

    @MainActor
    func testRSSSourceManagementViewsCanInitFromDemoAndCoreSources() {
        let source = RSSSource(
            url: "https://example.com/rss.xml",
            name: "Example Feed",
            sourceGroup: "开源项目",
            loginUrl: "https://example.com/login",
            sortUrl: "releases::issues",
            ruleContent: ".article",
            enableJs: false
        )
        let view = RSSSubscriptionManagementView(sources: [source])
        let actionView = RSSSourceActionsView(sourceID: "github-releases", title: "GitHub Releases")
        let editView = RSSSourceEditView(sourceID: "github-releases", title: "GitHub Releases")
        let debugView = RSSSourceDebugView(sourceID: "github-releases", title: "GitHub Releases")
        let varsView = RSSSourceVarsView(sourceID: "github-releases", title: "GitHub Releases")
        let loginView = RSSSourceLoginView(sourceID: "source-maintenance", title: "书源维护公告")
        let loginWebView = RSSSourceLoginWebView(sourceID: "source-maintenance", title: "书源维护公告")
        let loginCookieView = RSSSourceLoginCookieView(sourceID: "source-maintenance", title: "书源维护公告")
        let loginClearView = RSSSourceLoginClearView(sourceID: "source-maintenance", title: "书源维护公告")
        let groupsView = RSSSourceGroupsView()
        let groupEditView = RSSSourceGroupEditView(groupID: "open-source", title: "开源项目")
        let batchView = RSSSourceBatchView()
        let exportView = RSSSourceExportView()
        let exportDetailView = RSSSourceExportDetailView(sourceID: "github-releases", title: "GitHub Releases")
        let exportResultView = RSSSourceExportResultView()
        let pinView = RSSSourcePinConfirmView(sourceID: "github-releases", title: "GitHub Releases")
        let disableView = RSSSourceDisableConfirmView(sourceID: "github-releases", title: "GitHub Releases")
        let batchDisableView = RSSSourceBatchDisableConfirmView()
        let importView = RSSSourceImportView()
        let importDetailView = RSSSourceImportDetailView(sourceID: "source-maintenance", title: "书源维护公告")
        let importResultView = RSSSourceImportResultView()
        let searchView = RSSSearchView()
        let readRecordView = RSSReadRecordView(sourceID: "github-releases", title: "GitHub Releases")
        let recordClearView = RSSRecordClearConfirmView()
        let ruleSubscriptionView = RSSRuleSubscriptionView()
        let ruleDetailView = RSSRuleSubscriptionDetailView(subscriptionID: "community-rss", title: "社区 RSS 源订阅")
        let ruleEditView = RSSRuleSubscriptionEditView(subscriptionID: "community-rss", title: "社区 RSS 源订阅")
        let ruleTestView = RSSRuleSubscriptionTestView(subscriptionID: "community-rss", title: "社区 RSS 源订阅")
        let ruleApplyView = RSSRuleSubscriptionApplyConfirmView(subscriptionID: "community-rss", title: "社区 RSS 源订阅")
        let favoriteGroupsView = RSSFavoriteGroupsView()
        let favoriteEditView = RSSFavoriteGroupEditView(groupID: "default", title: "默认分组")
        let favoriteClearView = RSSFavoriteClearConfirmView()
        let emptyView = RSSStateView(kind: .empty)
        let errorView = RSSStateView(kind: .error)

        XCTAssertNotNil(view)
        XCTAssertNotNil(actionView)
        XCTAssertNotNil(editView)
        XCTAssertNotNil(debugView)
        XCTAssertNotNil(varsView)
        XCTAssertNotNil(loginView)
        XCTAssertNotNil(loginWebView)
        XCTAssertNotNil(loginCookieView)
        XCTAssertNotNil(loginClearView)
        XCTAssertNotNil(groupsView)
        XCTAssertNotNil(groupEditView)
        XCTAssertNotNil(batchView)
        XCTAssertNotNil(exportView)
        XCTAssertNotNil(exportDetailView)
        XCTAssertNotNil(exportResultView)
        XCTAssertNotNil(pinView)
        XCTAssertNotNil(disableView)
        XCTAssertNotNil(batchDisableView)
        XCTAssertNotNil(importView)
        XCTAssertNotNil(importDetailView)
        XCTAssertNotNil(importResultView)
        XCTAssertNotNil(searchView)
        XCTAssertNotNil(readRecordView)
        XCTAssertNotNil(recordClearView)
        XCTAssertNotNil(ruleSubscriptionView)
        XCTAssertNotNil(ruleDetailView)
        XCTAssertNotNil(ruleEditView)
        XCTAssertNotNil(ruleTestView)
        XCTAssertNotNil(ruleApplyView)
        XCTAssertNotNil(favoriteGroupsView)
        XCTAssertNotNil(favoriteEditView)
        XCTAssertNotNil(favoriteClearView)
        XCTAssertNotNil(emptyView)
        XCTAssertNotNil(errorView)
        XCTAssertEqual(RSSManagementSource.demoSources.count, 4)
        XCTAssertEqual(RSSManagementSource.from([source]).first?.status, "需登录")
    }

    func testSettingsAndSourceRowTokensMatchDemoMatrix() {
        XCTAssertEqual(ReaderDesignTokens.settingsSectionTitleFontSize, 13)
        XCTAssertEqual(ReaderDesignTokens.settingsRowMinHeight, 58)
        XCTAssertEqual(ReaderDesignTokens.settingsRowIconColumn, 28)
        XCTAssertEqual(ReaderDesignTokens.settingsSwitchTrackWidth, 38)
        XCTAssertEqual(ReaderDesignTokens.settingsSwitchTrackHeight, 22)
        XCTAssertEqual(ReaderDesignTokens.settingsSwitchThumbSize, 18)
        XCTAssertEqual(ReaderDesignTokens.settingsSearchFieldHeight, 40)
        XCTAssertEqual(ReaderDesignTokens.sourceRowMinHeight, 64)
    }

    func testDemoTopAndBackBarTokensMatchDemoCSS() {
        XCTAssertEqual(ReaderDesignTokens.topBarMinHeight, 58)
        XCTAssertEqual(ReaderDesignTokens.topBarTopPadding, 6)
        XCTAssertEqual(ReaderDesignTokens.topBarHorizontalPadding, 20)
        XCTAssertEqual(ReaderDesignTokens.topBarTitleFontSize, 29)
        XCTAssertEqual(ReaderDesignTokens.topBarActionGap, 18)
        XCTAssertEqual(ReaderDesignTokens.topBarIconButtonSize, 44)
        XCTAssertEqual(ReaderDesignTokens.backBarGap, 10)
        XCTAssertEqual(ReaderDesignTokens.backBarTitleFontSize, 24)
    }

    @MainActor
    func testDemoTopAndBackBarsCanInitialize() {
        let topBar = DemoTopBar(title: "书架") {
            DemoTopActionButton(icon: .search, accessibilityLabel: "搜索书籍") {}
            DemoTopActionButton(icon: .more, accessibilityLabel: "更多") {}
        }
        let backBar = DemoBackBar(title: "书籍目录", onBack: {}) {
            DemoTopActionButton(icon: .more, accessibilityLabel: "更多") {}
        }
        let backScreen = DemoBackScreen(title: "书籍搜索") {
            Text("搜索内容")
        }
        XCTAssertNotNil(topBar)
        XCTAssertNotNil(backBar)
        XCTAssertNotNil(backScreen)
    }

    @MainActor
    func testSettingsDemoFeatureStateViewsCanInitFromDemoRoutes() {
        XCTAssertEqual(DemoRouteMappings.expectedSettingsShellRoutes.count, 28)
        for route in DemoRouteMappings.expectedSettingsShellRoutes {
            let view = SettingsDemoShellView(demoRoute: route)
            XCTAssertNotNil(view)
        }
    }

    func testReaderControlSheetTokensMatchDemoMatrix() {
        XCTAssertEqual(ReaderDesignTokens.readerControlSheetSideInset, 12)
        XCTAssertEqual(ReaderDesignTokens.readerControlSheetBottomInset, 18)
        XCTAssertEqual(ReaderDesignTokens.readerControlSheetHeight, 330)
        XCTAssertEqual(ReaderDesignTokens.readerControlMainActionRowHeight, 70)
        XCTAssertEqual(ReaderDesignTokens.readerControlChapterPanelHeight, 96)
        XCTAssertEqual(ReaderDesignTokens.readerSettingsPanelRowHeight, 32)
        XCTAssertEqual(ReaderDesignTokens.readerSettingsSwatchSize, 18)
        XCTAssertEqual(ReaderDesignTokens.readerSettingsLargeSwatchWidth, 22)
        XCTAssertEqual(ReaderDesignTokens.readerSettingsStepperSize, 24)
        XCTAssertEqual(ReaderDesignTokens.readerSessionCapsuleHeight, 44)
        XCTAssertEqual(ReaderDesignTokens.readerSessionCapsuleIconSize, 28)
        XCTAssertEqual(ReaderDesignTokens.readerSessionCapsuleCountdownSize, 22)
    }

    func testReaderControlSessionStateMatchesTTSPlaybackContract() {
        let ready = ReaderControlSession.ready
        XCTAssertEqual(ready.icon, .progress)
        XCTAssertEqual(ready.title, "控制层就绪")
        XCTAssertEqual(ready.statusLabel, "ready")
        XCTAssertEqual(ready.countdownLabel, "ready")
        XCTAssertFalse(ready.isTTSPlaying)

        let running = ReaderControlSession.tts(playbackState: .playing)
        XCTAssertEqual(running.icon, .tts)
        XCTAssertEqual(running.title, "朗读")
        XCTAssertEqual(running.statusLabel, "运行中")
        XCTAssertEqual(running.countdownLabel, "00:22")
        XCTAssertTrue(running.isTTSPlaying)

        let paused = ReaderControlSession.tts(playbackState: .paused)
        XCTAssertEqual(paused.statusLabel, "已暂停")
        XCTAssertEqual(paused.countdownLabel, "pause")
        XCTAssertTrue(paused.isTTSPaused)
    }

    func testReaderAppearanceQuickActionsMutateDisplaySettings() {
        var settings = ReaderDisplaySettings(fontSize: 18, lineSpacing: 8, backgroundMode: .light, pageTurnMode: .scroll)

        ReaderAppearanceQuickAction.fontSize(delta: 2).apply(to: &settings)
        XCTAssertEqual(settings.fontSize, 20)
        ReaderAppearanceQuickAction.fontSize(delta: 40).apply(to: &settings)
        XCTAssertEqual(settings.fontSize, 32)
        ReaderAppearanceQuickAction.fontSize(delta: -40).apply(to: &settings)
        XCTAssertEqual(settings.fontSize, 12)

        ReaderAppearanceQuickAction.lineSpacing(delta: 2).apply(to: &settings)
        XCTAssertEqual(settings.lineSpacing, 10)
        ReaderAppearanceQuickAction.lineSpacing(delta: 40).apply(to: &settings)
        XCTAssertEqual(settings.lineSpacing, 24)
        ReaderAppearanceQuickAction.theme(.sepia).apply(to: &settings)
        XCTAssertEqual(settings.backgroundMode, .sepia)
        ReaderAppearanceQuickAction.pageTurnMode(.paginated).apply(to: &settings)
        XCTAssertEqual(settings.pageTurnMode, .paginated)
    }

    func testReaderSettingsQuickActionsMutateDisplaySettings() {
        var settings = ReaderDisplaySettings.default
        XCTAssertTrue(settings.tapZoneEnabled)
        XCTAssertFalse(settings.volumeKeyPageTurnEnabled)
        XCTAssertFalse(settings.dualPageEnabled)
        XCTAssertFalse(settings.brightnessOverrideEnabled)

        ReaderSettingsQuickAction.toggleTapZones.apply(to: &settings)
        XCTAssertFalse(settings.tapZoneEnabled)
        ReaderSettingsQuickAction.toggleVolumeKeyPageTurn.apply(to: &settings)
        XCTAssertTrue(settings.volumeKeyPageTurnEnabled)
        ReaderSettingsQuickAction.toggleDualPage.apply(to: &settings)
        XCTAssertTrue(settings.dualPageEnabled)
        ReaderSettingsQuickAction.toggleBrightnessOverride.apply(to: &settings)
        XCTAssertTrue(settings.brightnessOverrideEnabled)
    }

    @MainActor
    func testReaderSettingsPanelCanInitWithDemoToggleRows() {
        let view = ReaderSettingsPanel(displaySettings: .constant(.default)) {}

        XCTAssertNotNil(view)
        XCTAssertEqual(ReaderDesignTokens.settingsSwitchTrackWidth, 38)
        XCTAssertEqual(ReaderDesignTokens.settingsSwitchTrackHeight, 22)
        XCTAssertEqual(ReaderAssetIcon.gesture.rawValue, "gesture")
        XCTAssertEqual(ReaderAssetIcon.volume.rawValue, "volume")
        XCTAssertEqual(ReaderAssetIcon.columns.rawValue, "columns")
    }

    @MainActor
    func testReaderFullModuleShellStatesCanInitFromControlRoutes() {
        let routes = ["reader-full-directory", "reader-full-tts", "reader-full-appearance", "reader-full-settings"]

        for route in routes {
            let view = ReaderDemoShellView(demoRoute: route)
            XCTAssertNotNil(view)
        }
    }

    func testReaderDemoCompactModuleRoutesMatchDemoContract() throws {
        let routeByModule: [(ReaderDemoModule, compact: String, full: String)] = [
            (.directory, "toc-bookmarks", "reader-full-directory"),
            (.tts, "tts", "reader-full-tts"),
            (.appearance, "reader-appearance", "reader-full-appearance"),
            (.settings, "reader-settings", "reader-full-settings")
        ]

        for (module, compactRoute, fullRoute) in routeByModule {
            XCTAssertEqual(module.compactRoute, compactRoute)
            XCTAssertEqual(module.fullRoute, fullRoute)

            let compactState = ReaderDemoRouteState(route: try XCTUnwrap(module.compactRoute))
            XCTAssertEqual(compactState.route, compactRoute)
            XCTAssertEqual(compactState.module, module)
            XCTAssertEqual(compactState.presentation, .compact)

            let fullState = ReaderDemoRouteState(route: try XCTUnwrap(module.fullRoute))
            XCTAssertEqual(fullState.route, fullRoute)
            XCTAssertEqual(fullState.module, module)
            XCTAssertEqual(fullState.presentation, .full)
        }

        XCTAssertNil(ReaderDemoModule.search.compactRoute)
        XCTAssertNil(ReaderDemoModule.autoPage.compactRoute)
        XCTAssertNil(ReaderDemoModule.replacement.compactRoute)
        XCTAssertNil(ReaderDemoModule.cache.compactRoute)
        XCTAssertNil(ReaderDemoModule.debug.compactRoute)
        XCTAssertNil(ReaderDemoModule.search.fullRoute)
        XCTAssertNil(ReaderDemoModule.autoPage.fullRoute)
        XCTAssertNil(ReaderDemoModule.replacement.fullRoute)
        XCTAssertNil(ReaderDemoModule.cache.fullRoute)
        XCTAssertNil(ReaderDemoModule.debug.fullRoute)
    }

    func testReaderDemoSessionStateMatchesMotionContract() {
        let ttsRunning = ReaderDemoSession.tts(playing: true)
        XCTAssertTrue(ttsRunning.isActive)
        XCTAssertTrue(ttsRunning.isPlaying)
        XCTAssertEqual(ttsRunning.icon, .tts)
        XCTAssertEqual(ttsRunning.title, "朗读")
        XCTAssertEqual(ttsRunning.statusLabel, "运行中")
        XCTAssertEqual(ttsRunning.startMotionID, "reader.session.tts.start")

        let autoPaused = ReaderDemoSession.autoPage(playing: false)
        XCTAssertTrue(autoPaused.isActive)
        XCTAssertFalse(autoPaused.isPlaying)
        XCTAssertEqual(autoPaused.icon, .readerAutoPage)
        XCTAssertEqual(autoPaused.title, "自动翻页")
        XCTAssertEqual(autoPaused.statusLabel, "已暂停")
        XCTAssertEqual(autoPaused.countdownLabel, "pause")
        XCTAssertEqual(autoPaused.startMotionID, "reader.session.autoPage.start")

        XCTAssertFalse(ReaderDemoSession.none.isActive)
        XCTAssertNil(ReaderDemoSession.none.startMotionID)
    }

    @MainActor
    func testReaderStageActionBarCanOpenDirectoryModule() {
        var didOpenDirectory = false
        let view = ReaderStageActionBar(
            onPrevious: {},
            onNext: {},
            onReload: {},
            onDirectory: { didOpenDirectory = true }
        )

        XCTAssertNotNil(view)
        view.onDirectory?()
        XCTAssertTrue(didOpenDirectory)
    }

    func testReaderResponsiveDockTokensMatchDemoCSS() {
        XCTAssertEqual(ReaderDesignTokens.readerExpandedWidthMinWidth, 560)
        XCTAssertEqual(ReaderDesignTokens.readerTabletExpandedMinWidth, 760)
        XCTAssertEqual(ReaderDesignTokens.readerCompactLandscapeMaxHeight, 520)
        XCTAssertEqual(ReaderDesignTokens.readerDockMaxWidth, 340)
        XCTAssertEqual(ReaderDesignTokens.readerDockExpandedRightInset, 18)
        XCTAssertEqual(ReaderDesignTokens.readerDockTabletRightInset, 24)
        XCTAssertEqual(ReaderDesignTokens.readerDockCompactRightInset, 16)
        XCTAssertEqual(ReaderDesignTokens.readerDockWideSheetHeight, 252)
        XCTAssertEqual(ReaderDesignTokens.readerDockCompactSheetHeight, 230)
        XCTAssertEqual(ReaderDesignTokens.readerDockNavBottomInset, 32)
        XCTAssertEqual(ReaderDesignTokens.readerDockCompactNavBottomInset, 16)
        XCTAssertEqual(ReaderDesignTokens.readerDockNavHeight, 79)
        XCTAssertEqual(ReaderDesignTokens.readerDockCompactNavHeight, 54)
        XCTAssertEqual(ReaderDesignTokens.readerDockGap, -1)
        XCTAssertEqual(ReaderDesignTokens.readerDockReadingTopInset, 92)
        XCTAssertEqual(ReaderDesignTokens.readerDockReadingSideInset, 44)
        XCTAssertEqual(ReaderDesignTokens.readerDockReadingBottomInset, 56)
        XCTAssertEqual(ReaderDesignTokens.readerDockCompactReadingTopInset, 74)
        XCTAssertEqual(ReaderDesignTokens.readerDockCompactReadingLeftInset, 30)
        XCTAssertEqual(ReaderDesignTokens.readerDockCompactReadingBottomInset, 24)
        XCTAssertEqual(ReaderDesignTokens.readerDockCompactReadingRightInset, 384)
    }

    func testReaderResponsiveLayoutMatchesDemoViewportClasses() {
        let phone = ReaderResponsiveLayout.make(size: CGSize(width: 390, height: 844))
        XCTAssertEqual(phone.viewportClass, .phonePortrait)
        XCTAssertEqual(phone.controlPlacement, .bottom)
        XCTAssertEqual(phone.readingInsets.top, 72)
        XCTAssertEqual(phone.readingInsets.leading, 32)
        XCTAssertEqual(phone.readingInsets.bottom, 48)
        XCTAssertEqual(phone.readingInsets.trailing, 32)

        let expanded = ReaderResponsiveLayout.make(size: CGSize(width: 620, height: 844))
        XCTAssertEqual(expanded.viewportClass, .expandedWidth)
        XCTAssertEqual(expanded.controlPlacement, .trailingDock)
        XCTAssertEqual(expanded.dockRightInset, 18)
        XCTAssertEqual(expanded.dockWidth, 340)
        XCTAssertEqual(expanded.dockSheetHeight, 252)
        XCTAssertEqual(expanded.readingInsets.top, 92)
        XCTAssertEqual(expanded.readingInsets.trailing, 44)

        let tablet = ReaderResponsiveLayout.make(size: CGSize(width: 820, height: 960))
        XCTAssertEqual(tablet.viewportClass, .tabletExpanded)
        XCTAssertEqual(tablet.controlPlacement, .trailingDock)
        XCTAssertEqual(tablet.dockRightInset, 24)
        XCTAssertEqual(tablet.dockWidth, 340)
        XCTAssertEqual(tablet.readingInsets.trailing, 400)

        let compactLandscape = ReaderResponsiveLayout.make(size: CGSize(width: 1_180, height: 500))
        XCTAssertEqual(compactLandscape.viewportClass, .compactLandscape)
        XCTAssertEqual(compactLandscape.controlPlacement, .trailingDock)
        XCTAssertEqual(compactLandscape.dockRightInset, 16)
        XCTAssertEqual(compactLandscape.dockWidth, 340)
        XCTAssertEqual(compactLandscape.dockSheetHeight, 230)
        XCTAssertEqual(compactLandscape.dockNavBottomInset, 16)
        XCTAssertEqual(compactLandscape.dockNavHeight, 54)
        XCTAssertEqual(compactLandscape.readingInsets.top, 74)
        XCTAssertEqual(compactLandscape.readingInsets.leading, 30)
        XCTAssertEqual(compactLandscape.readingInsets.trailing, 384)
        XCTAssertTrue(compactLandscape.compactModuleNav)
    }

    func testReaderResponsiveVisualAuditCoversDockAndTopBarGeometry() {
        let phone = ReaderResponsiveVisualAudit.make(size: CGSize(width: 390, height: 844))
        XCTAssertEqual(phone.layout.viewportClass, .phonePortrait)
        XCTAssertNil(phone.dockStackRect)
        XCTAssertTrue(phone.readingRectInsideViewport)
        XCTAssertTrue(phone.topBarClearsReadingContent)
        XCTAssertEqual(phone.topBarRect.maxY, phone.readingRect.minY)

        let expanded = ReaderResponsiveVisualAudit.make(size: CGSize(width: 620, height: 844))
        XCTAssertEqual(expanded.layout.viewportClass, .expandedWidth)
        XCTAssertFalse(expanded.requiresHardDockAvoidance)
        XCTAssertNotNil(expanded.dockStackRect)
        XCTAssertTrue(expanded.dockStackInsideViewport)
        XCTAssertTrue(expanded.topBarClearsReadingContent)

        let tablet = ReaderResponsiveVisualAudit.make(size: CGSize(width: 820, height: 960))
        XCTAssertEqual(tablet.layout.viewportClass, .tabletExpanded)
        XCTAssertTrue(tablet.requiresHardDockAvoidance)
        XCTAssertTrue(tablet.readingAvoidsDockWhenRequired)
        XCTAssertTrue(tablet.dockStackInsideViewport)
        XCTAssertEqual(tablet.readingRect.maxX, 420)
        XCTAssertEqual(tablet.dockStackRect?.minX, 456)

        let compactLandscape = ReaderResponsiveVisualAudit.make(size: CGSize(width: 1_180, height: 500))
        XCTAssertEqual(compactLandscape.layout.viewportClass, .compactLandscape)
        XCTAssertTrue(compactLandscape.requiresHardDockAvoidance)
        XCTAssertTrue(compactLandscape.readingAvoidsDockWhenRequired)
        XCTAssertTrue(compactLandscape.dockStackInsideViewport)
        XCTAssertTrue(compactLandscape.topBarClearsReadingContent)
        XCTAssertEqual(compactLandscape.topBarRect.maxY, 60)
        XCTAssertEqual(compactLandscape.readingRect.minY, 74)
        XCTAssertEqual(compactLandscape.readingRect.maxX, 796)
        XCTAssertEqual(compactLandscape.dockStackRect?.minX, 824)
    }

    func testReaderReadingLayerAndTopTokensMatchDemoMatrix() {
        XCTAssertEqual(ReaderDisplaySettings.demoSerifFontFamily, "Songti SC")
        XCTAssertEqual(ReaderDisplaySettings.default.fontFamily, ReaderDisplaySettings.demoSerifFontFamily)
        XCTAssertEqual(ReaderTypography.demoSerifSource, "Reader UI/frontend-demo/tokens.css --reader-ds-font-serif")
        XCTAssertEqual(ReaderTypography.demoSerifPrimaryFamily, "Songti SC")
        XCTAssertEqual(ReaderTypography.demoSerifRegularPostScriptName, "STSongti-SC-Regular")
        XCTAssertEqual(ReaderTypography.demoSerifBoldPostScriptName, "STSongti-SC-Bold")
        XCTAssertEqual(ReaderTypography.demoSerifFallbackFamilies.prefix(4), [
            "Songti SC",
            "STSong",
            "Noto Serif CJK SC",
            "Source Han Serif SC"
        ])
        XCTAssertEqual(ReaderTypography.resolvedReaderFontFamily("Georgia"), "Songti SC")
        XCTAssertEqual(ReaderTypography.resolvedReaderFontFamily("SF Pro Display"), "Songti SC")
        XCTAssertEqual(ReaderDesignTokens.immersiveReadingLayerTopInset, 72)
        XCTAssertEqual(ReaderDesignTokens.immersiveReadingLayerSideInset, 32)
        XCTAssertEqual(ReaderDesignTokens.immersiveReadingLayerBottomInset, 48)
        XCTAssertEqual(ReaderDesignTokens.immersiveBodyFontSize, 18)
        XCTAssertEqual(ReaderDesignTokens.immersiveBodyLineHeight, 1.96)
        XCTAssertEqual(ReaderDesignTokens.immersiveBodyParagraphIndent, 2)
        XCTAssertEqual(ReaderDesignTokens.immersiveTitleFontSizeOffset, 5)
        XCTAssertEqual(ReaderDesignTokens.immersiveTitleLineHeight, 1.25)
        XCTAssertEqual(ReaderDesignTokens.immersiveTitleBottomMargin, 24)
        XCTAssertEqual(ReaderDesignTokens.readerTopTopInset, 18)
        XCTAssertEqual(ReaderDesignTokens.readerTopSideInset, 14)
        XCTAssertEqual(ReaderDesignTokens.readerTopMinHeight, 54)
        XCTAssertEqual(ReaderDesignTokens.readerTopBackColumnWidth, 44)
        XCTAssertEqual(ReaderDesignTokens.readerTopSourceColumnWidth, 62)
        XCTAssertEqual(ReaderDesignTokens.readerTopMoreColumnWidth, 34)
        XCTAssertEqual(ReaderDesignTokens.readerTopGap, 8)
        XCTAssertEqual(ReaderDesignTokens.readerTopHorizontalPadding, 12)
        XCTAssertEqual(ReaderDesignTokens.readerTopButtonMinHeight, 42)
        XCTAssertEqual(ReaderDesignTokens.readerTopTitleFontSize, 16)
        XCTAssertEqual(ReaderDesignTokens.readerTopSubtitleFontSize, 12)
        XCTAssertEqual(ReaderDesignTokens.readerTopTitleLineLimit, 2)
        XCTAssertEqual(ReaderDesignTokens.readerTopCompactTopInset, 12)
        XCTAssertEqual(ReaderDesignTokens.readerTopTabletSideInset, 28)
        XCTAssertEqual(ReaderDesignTokens.readerTopCompactMinHeight, 48)
        XCTAssertEqual(ReaderDesignTokens.readerTopCompactBackColumnWidth, 40)
        XCTAssertEqual(ReaderDesignTokens.readerTopCompactSourceColumnWidth, 58)
        XCTAssertEqual(ReaderDesignTokens.readerTopCompactMoreColumnWidth, 32)
        XCTAssertEqual(ReaderDesignTokens.readerTopCompactGap, 6)
        XCTAssertEqual(ReaderDesignTokens.readerTopCompactHorizontalPadding, 10)
        XCTAssertEqual(ReaderDesignTokens.readerTopCompactTitleFontSize, 13)
        XCTAssertEqual(ReaderDesignTokens.readerTopCompactSubtitleFontSize, 10)
        XCTAssertEqual(ReaderDesignTokens.readerTopCompactButtonMinHeight, 36)
        XCTAssertEqual(ReaderDesignTokens.readerTopCompactButtonFontSize, 11)
    }

    @MainActor
    func testPaginatedReaderViewCanInitWithDemoReadingInsets() {
        let layout = ReaderResponsiveLayout.make(size: CGSize(width: 390, height: 844))
        let view = PaginatedReaderView(
            title: "第 32 章 雨夜",
            text: "风穿过旧楼。\n灯火在雨里摇晃。",
            displaySettings: ReaderDisplaySettings(pageTurnMode: .paginated),
            contentInsets: layout.readingInsets,
            onToggleUI: {},
            onProgressUpdate: { _ in },
            pageTurnTrigger: PageTurnTrigger()
        )

        XCTAssertNotNil(view)
        XCTAssertEqual(layout.readingInsets.top, ReaderDesignTokens.immersiveReadingLayerTopInset)
        XCTAssertEqual(layout.readingInsets.leading, ReaderDesignTokens.immersiveReadingLayerSideInset)
        XCTAssertEqual(ReaderDesignTokens.hotzonePrevRatio, 0.26)
        XCTAssertEqual(ReaderDesignTokens.hotzoneCenterRatio, 0.48)
        XCTAssertEqual(ReaderDesignTokens.hotzoneNextRatio, 0.26)
    }

    func testReaderHotZoneSegmentsMatchDemoContract() {
        XCTAssertEqual(ReaderHotZoneSegment.allCases, [.previousPage, .controls, .nextPage])
        XCTAssertEqual(ReaderHotZoneSegment.previousPage.widthRatio, 0.26)
        XCTAssertEqual(ReaderHotZoneSegment.controls.widthRatio, 0.48)
        XCTAssertEqual(ReaderHotZoneSegment.nextPage.widthRatio, 0.26)

        XCTAssertEqual(ReaderHotZoneSegment.previousPage.pageTurnDirection, .previous)
        XCTAssertNil(ReaderHotZoneSegment.controls.pageTurnDirection)
        XCTAssertEqual(ReaderHotZoneSegment.nextPage.pageTurnDirection, .next)

        XCTAssertEqual(ReaderHotZoneSegment.previousPage.motionID, "reader.page.turn.prev")
        XCTAssertEqual(ReaderHotZoneSegment.controls.motionID, "reader.control.show/hide")
        XCTAssertEqual(ReaderHotZoneSegment.nextPage.motionID, "reader.page.turn.next")
    }

    @MainActor
    func testReaderProgressSurfaceViewCanInitWithDemoTopActions() {
        let view = ReaderProgressSurfaceView(
            chapterIndex: 31,
            chapterCount: 80,
            progressPercentage: 0.38,
            title: "第 32 章 雨夜",
            subtitle: "优书网 · 38.0% · 共 80 章",
            onBack: {},
            onSourceSwitch: {},
            onMore: {}
        )
        XCTAssertNotNil(view)

        let compact = ReaderProgressSurfaceView(
            chapterIndex: 31,
            chapterCount: 80,
            progressPercentage: 0.38,
            title: "第 32 章 雨夜",
            subtitle: "优书网 · 38.0% · 共 80 章",
            onBack: {},
            onSourceSwitch: {},
            onMore: {},
            style: .compactLandscape
        )
        XCTAssertNotNil(compact)
    }

    @MainActor
    func testReaderStateSurfacesCanInitWithDemoPrimitiveTokens() {
        let card = ReaderStateCard(
            icon: .warning,
            title: "加载失败",
            subtitle: "当前章节加载失败，请稍后重试。"
        )
        let banner = ReaderStateBanner(
            icon: .warning,
            title: "内容不完整",
            messages: ["部分正文由缓存或兜底内容呈现。"]
        )

        XCTAssertNotNil(card)
        XCTAssertNotNil(banner)
        XCTAssertEqual(ReaderDesignTokens.rssBrowserConfirmCardMinHeight, 256)
        XCTAssertEqual(ReaderDesignTokens.rssBrowserConfirmIconSize, 44)
        XCTAssertEqual(ReaderDesignTokens.rssBrowserConfirmTitleFontSize, 17)
        XCTAssertEqual(ReaderDesignTokens.rssBrowserConfirmBodyFontSize, 13)
    }

    @MainActor
    func testReaderTOCAndContentFallbackSurfacesUseDemoPrimitives() {
        let chapter = TOCItem(
            chapterTitle: "第 32 章 雨夜",
            chapterURL: "demo://chapter/32",
            chapterIndex: 31
        )
        let row = TOCChapterDemoRow(chapter: chapter, displayIndex: 32, isCurrent: true)
        let content = ReaderContentSectionView(
            title: "第 32 章 雨夜",
            bodyText: "雨声落在旧窗上。\n灯塔在远处亮起。",
            bookTitle: "长夜余火",
            sourceName: "优书网"
        )

        XCTAssertNotNil(row)
        XCTAssertNotNil(content)
        XCTAssertEqual(ReaderDesignTokens.bookDirectoryRowMinHeight, 48)
        XCTAssertEqual(ReaderDesignTokens.bookDirectoryMarkerColumnWidth, 64)
        XCTAssertEqual(ReaderDesignTokens.immersiveBodyFontSize, 18)
        XCTAssertEqual(ReaderDesignTokens.immersiveBodyLineHeight, 1.96)
    }

    func testReaderSourceSwitchFlowTokensMatchDemoMatrix() {
        XCTAssertEqual(ReaderDesignTokens.sourceSwitchFlowGap, 12)
        XCTAssertEqual(ReaderDesignTokens.sourceSwitchWindowWidth, 300)
        XCTAssertEqual(ReaderDesignTokens.sourceSwitchResultWidth, 200)
        XCTAssertEqual(ReaderDesignTokens.sourceSwitchResultPadding, 16)
        XCTAssertEqual(ReaderDesignTokens.sourceSwitchResultGap, 12)
        XCTAssertEqual(ReaderDesignTokens.sourceSwitchResultIconSize, 36)
        XCTAssertEqual(ReaderDesignTokens.sourceSwitchResultButtonMinHeight, 42)
        XCTAssertEqual(ReaderDesignTokens.sourceSwitchCandidateRowMinHeight, 54)
        XCTAssertEqual(ReaderDesignTokens.sourceSwitchCandidateRowGap, 7)
    }

    @MainActor
    func testReaderDemoFeatureStateViewsCanInitFromDemoRoutes() {
        let routes = DemoRouteMappings.expectedReaderShellRoutes.filter {
            $0 != "immersive-reading" && $0 != "reader"
        }
        XCTAssertEqual(routes.count, 13)
        for route in routes {
            let view = ReaderDemoShellView(demoRoute: route)
            XCTAssertNotNil(view)
        }
    }

    @MainActor
    func testReaderSourceSwitchFlowViewCanInitFromDemoRoute() {
        let view = ReaderSourceSwitchFlowView(bookURL: "demo://book/lighthouse")
        XCTAssertNotNil(view)
    }

    func testAdaptiveAndBottomActionTokensMatchDemoMatrix() {
        XCTAssertEqual(ReaderDesignTokens.tabletNavWidth, 82)
        XCTAssertEqual(ReaderDesignTokens.tabletNavItemHeight, 58)
        XCTAssertEqual(ReaderDesignTokens.bottomFixedActionRowMinHeight, 52)
        XCTAssertEqual(ReaderDesignTokens.bottomFixedActionButtonMinHeight, 46)
    }
}
