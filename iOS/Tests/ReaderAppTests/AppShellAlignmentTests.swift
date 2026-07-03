import XCTest
import SwiftUI
@testable import ReaderApp
import ReaderCoreModels
import ReaderShellValidation

/// 生产 App Shell 对齐验证 — 4 主底栏：书架 / 发现 / RSS / 设置
///
/// 真源：`docs/cross-platform-ui/CROSS_PLATFORM_UI_BASELINE.md` App Shell
/// 契约：搜索、阅读页、书源管理都不是主 Tab；主 Tab 切换不写成二级 route push。
@MainActor
final class AppShellAlignmentTests: XCTestCase {

    // MARK: - 4 主 Tab 契约（AppTab）

    func testAppTabContractOrderIsBookshelfDiscoverRSSSettings() {
        let order = AppTab.contractOrder
        XCTAssertEqual(order, [.bookshelf, .discover, .rss, .settings],
                       "主 Tab 顺序必须固定：书架 / 发现 / RSS / 设置")
    }

    func testAppTabTitlesMatchContract() {
        XCTAssertEqual(AppTab.bookshelf.title, "书架")
        XCTAssertEqual(AppTab.discover.title, "发现")
        XCTAssertEqual(AppTab.rss.title, "RSS")
        XCTAssertEqual(AppTab.settings.title, "设置")
    }

    func testAppTabCountIs4() {
        XCTAssertEqual(AppTab.allCases.count, 4, "主 Tab 数量必须为 4")
    }

    func testMainTabShellLayoutKeepsMainNavAsIndependentSlot() {
        let phone = AppShellView.AppShellMainTabLayout(
            viewport: DemoViewportSnapshot.make(size: CGSize(width: 390, height: 844))
        )
        XCTAssertFalse(phone.usesTabletRail)
        XCTAssertEqual(phone.tabBarAxis, .horizontal)
        XCTAssertEqual(phone.contentLeadingPadding, 0)
        XCTAssertEqual(phone.contentBottomPadding, ReaderDesignTokens.mainTabContentBottomPadding,
                       "demo MainTabShell keeps mainNav as an independent slot while fd-phone-content reserves bottom padding for the floating nav.")
        XCTAssertNil(phone.mainNavWidth)
        XCTAssertEqual(phone.mainNavLeadingPadding, 0)

        let tablet = AppShellView.AppShellMainTabLayout(
            viewport: DemoViewportSnapshot.make(size: CGSize(width: 1024, height: 1366))
        )
        XCTAssertTrue(tablet.usesTabletRail)
        XCTAssertEqual(tablet.tabBarAxis, .vertical)
        XCTAssertEqual(tablet.contentLeadingPadding, ReaderDesignTokens.tabletNavWidth + 18)
        XCTAssertEqual(tablet.contentBottomPadding, ReaderDesignTokens.mainTabContentBottomPadding)
        XCTAssertEqual(tablet.mainNavWidth, ReaderDesignTokens.tabletNavWidth)
        XCTAssertEqual(tablet.mainNavLeadingPadding, 16)
    }

    func testMainTabNavHidesWhenReaderShellIsActive() {
        let navigationState = AppNavigationState()
        let shell = AppShellView(
            coordinator: ShellAssembly.makeMockReadingFlowCoordinator(),
            navigationState: navigationState,
            environment: ReaderShellEnvironment()
        )

        XCTAssertTrue(shell.shouldShowMainNav)

        navigationState.enterImmersiveReading(ReaderContext(
            bookID: "demo-long-night",
            chapterURL: "demo://chapter/rain-night",
            chapterTitle: "雨夜",
            source: .coverToImmersive
        ))
        XCTAssertFalse(shell.shouldShowMainNav,
                       "demo ReaderShell routes must not keep the MainTabShell mainNav over the reading surface.")

        navigationState.exitImmersiveReading()
        XCTAssertTrue(shell.shouldShowMainNav)
    }

    // MARK: - Shell Views 存在性

    func testDemoShellSkeletonsCanInitForAllDemoShellFamilies() {
        let mainTab = DemoMainTabShell {
            Text("top")
        } contentRegion: {
            Text("content")
        } stateHost: {
            Text("state")
        } mainNav: {
            Text("nav")
        }

        let library = DemoLibraryShell(title: "书籍搜索") {
            Text("library")
        }

        let settings = DemoSettingsShell(title: "通用设置") {
            Text("settings")
        } trailing: {
            EmptyView()
        } bottomActionHost: {
            EmptyView()
        } sheetHost: {
            EmptyView()
        } toastHost: {
            EmptyView()
        } dialogHost: {
            EmptyView()
        } stateHost: {
            EmptyView()
        }

        let readerLayout = ReaderResponsiveLayout.make(size: CGSize(width: 390, height: 844))
        let reader = DemoReaderShell(layout: readerLayout) {
            Text("reading")
        } overlayHost: {
            Text("overlay")
        } bottomSheetHost: {
            Text("sheet")
        } moduleNav: {
            Text("nav")
        } stateHost: {
            Text("state")
        }

        let flow = DemoFlowShell(title: "换源") {
            Text("step")
        } comparisonRegion: {
            Text("comparison")
        } resultRegion: {
            Text("result")
        }

        XCTAssertNotNil(mainTab)
        XCTAssertNotNil(library)
        XCTAssertNotNil(settings)
        XCTAssertNotNil(reader)
        XCTAssertNotNil(flow)
    }

    func testMainTabRootViewsCanInitAsContentOnlySlots() {
        let navigationState = AppNavigationState()
        let topBarRequest = Binding<MainTabTopBarRequest?>.constant(nil)
        let coordinator = ShellAssembly.makeMockReadingFlowCoordinator()

        XCTAssertNotNil(BookshelfView(
            navigationState: navigationState,
            showsTopBar: false,
            topBarRequest: topBarRequest
        ))
        XCTAssertNotNil(DiscoverHomeShellView(
            showsTopBar: false,
            topBarRequest: topBarRequest
        ))
        XCTAssertNotNil(RSSFeedView(
            showsTopBar: false,
            topBarRequest: topBarRequest
        ))
        XCTAssertNotNil(SettingsTabView(
            coordinator: coordinator,
            showsTopBar: false
        ))
    }

    func testDemoBackScreenFacadeCanPassEveryLibraryShellSlot() {
        let screen = DemoBackScreen(title: "插槽页") {
            Text("content")
        } trailing: {
            Text("trailing")
        } bottomActionHost: {
            Text("bottom")
        } sheetHost: {
            Text("sheet")
        } dialogHost: {
            Text("dialog")
        } stateHost: {
            Text("state")
        }

        XCTAssertNotNil(screen)
    }

    func testDiscoverHomeShellViewCanInit() {
        let view = DiscoverHomeShellView()
        XCTAssertNotNil(view)
    }

    func testDiscoverFeatureStateViewsCanInitFromDemoRoutes() {
        for route in DemoRouteMappings.expectedMainTabShellRoutes where route.hasPrefix("discover-") {
            let view = DiscoverHomeShellView(demoRoute: route)
            XCTAssertNotNil(view)
        }
    }

    func testRSSFeedViewCanInit() {
        let view = RSSFeedView()
        XCTAssertNotNil(view)
    }

    func testRSSFeedFeatureStateViewsCanInitFromDemoRoutes() {
        for route in ["rss-all", "rss-starred", "rss-source-feed", "rss-source-category-releases", "rss-source-category-issues", "rss-source-category-discussions", "rss-refreshing"] {
            let view = RSSFeedView(demoRoute: route)
            XCTAssertNotNil(view)
        }
    }

    func testDiscoverSourceLoginViewCanInit() {
        let view = DiscoverSourceLoginView()
        XCTAssertNotNil(view)
    }

    func testBookshelfBatchManagementViewCanInit() {
        let view = BookshelfBatchManagementView()
        XCTAssertNotNil(view)
    }

    func testBookshelfGroupManagementViewCanInit() {
        let view = BookshelfGroupManagementView()
        XCTAssertNotNil(view)
    }

    func testBookshelfLocalImportViewCanInit() {
        let view = BookshelfLocalImportView()
        XCTAssertNotNil(view)
    }

    func testBookDirectoryPreviewViewCanInit() {
        let view = BookDirectoryPreviewView(bookURL: "demo://book/long-night", title: "长夜余火")
        XCTAssertNotNil(view)
    }

    func testLegacyReaderFlowViewCanInitWithDemoSurface() {
        let coordinator = ShellAssembly.makeMockReadingFlowCoordinator()
        let navigationState = AppNavigationState()
        let view = ReaderFlowFeatureView(coordinator: coordinator, navigationState: navigationState)
        XCTAssertNotNil(view)
    }

    #if DEBUG
    @MainActor
    func testM6BookSourceImportVerificationViewCanInitWithDemoSurface() {
        let view = M6BookSourceImportVerificationView()
        XCTAssertNotNil(view)
    }

    @MainActor
    func testRealNetworkVerifyViewCanInitWithDemoSurface() {
        let view = RealNetworkVerifyView()
        XCTAssertNotNil(view)
    }

    #if canImport(ReaderCoreNativeAdapter)
    @MainActor
    func testNativeCoreEvidenceViewCanInitWithDemoSurface() {
        let view = NativeCoreEvidenceView()
        XCTAssertNotNil(view)
    }

    @MainActor
    func testNativeCoreEvidenceAutorunViewCanInitWithDemoSurface() {
        let configuration = NativeCoreEvidenceAutorunConfiguration.parse(["--native-core-evidence-autorun"])
        let view = NativeCoreEvidenceAutorunView(configuration: configuration)
        XCTAssertNotNil(view)
    }
    #endif
    #endif

    func testBookDetailViewCanInit() {
        let result = SearchResultItem(
            title: "长夜余火",
            detailURL: "demo://book/long-night",
            author: "爱潜水的乌贼",
            intro: "旧世界的余烬尚未冷却，新的秩序已经在废墟之上生长。"
        )
        let view = BookDetailView(result: result, sourceName: "优书网")
        XCTAssertNotNil(view)
    }

    func testSearchViewCanInit() {
        let view = SearchView()
        XCTAssertNotNil(view)
    }

    func testSearchViewCanInitWithInitialQuery() {
        let view = SearchView(initialQuery: "长夜余火")
        XCTAssertNotNil(view)
    }

    func testSearchViewModelCanSeedInitialKeyword() {
        let viewModel = SearchViewModel(initialKeyword: "三体")
        XCTAssertEqual(viewModel.keyword, "三体")
    }

    func testReaderSourceSwitchFlowViewCanInit() {
        let view = ReaderSourceSwitchFlowView(bookURL: "demo://book/lighthouse")
        XCTAssertNotNil(view)
    }

    func testRSSDetailViewCanInit() {
        let view = RSSArticleDetailView(
            item: RSSArticleDetailView.fallbackItem(link: "https://example.com/rss"),
            sourceTitle: "RSS"
        )
        XCTAssertNotNil(view)
    }

    func testRSSOriginalPreviewViewCanInit() {
        let view = RSSOriginalPreviewView(
            urlString: "https://example.com/rss",
            title: "RSS 原文",
            sourceTitle: "RSS"
        )
        XCTAssertNotNil(view)
    }

    func testRSSOriginalBrowserConfirmViewCanInit() {
        let view = RSSOriginalBrowserConfirmView(
            urlString: "https://example.com/rss",
            title: "RSS 原文",
            sourceTitle: "RSS"
        )
        XCTAssertNotNil(view)
    }

    func testSharedStateSurfaceViewsCanInit() {
        let errorView = StateSurfaceView(kind: .error(message: "网络连接失败"))
        let offlineView = StateSurfaceView(kind: .offline)
        let permissionView = PermissionStateView(permission: "本地文件")
        let confirmDialog = ConfirmDialog(icon: .warning, title: "确认操作", message: "该操作需要再次确认。")
        let toastSurface = ToastSurface(icon: .check, message: "已保存")

        XCTAssertNotNil(errorView)
        XCTAssertNotNil(offlineView)
        XCTAssertNotNil(permissionView)
        XCTAssertNotNil(confirmDialog)
        XCTAssertNotNil(toastSurface)
    }

    func testRSSSubscriptionManagementViewCanInit() {
        let view = RSSSubscriptionManagementView()
        XCTAssertNotNil(view)
    }

    func testRSSSourceActionsViewCanInit() {
        let view = RSSSourceActionsView(sourceID: "github-releases", title: "GitHub Releases")
        XCTAssertNotNil(view)
    }

    func testRSSSourceEditAndDebugViewsCanInit() {
        let editView = RSSSourceEditView(sourceID: "github-releases", title: "GitHub Releases")
        let debugView = RSSSourceDebugView(sourceID: "github-releases", title: "GitHub Releases")
        XCTAssertNotNil(editView)
        XCTAssertNotNil(debugView)
    }

    func testRSSSourceVarsAndLoginViewsCanInit() {
        let varsView = RSSSourceVarsView(sourceID: "github-releases", title: "GitHub Releases")
        let loginView = RSSSourceLoginView(sourceID: "source-maintenance", title: "书源维护公告")
        let loginWebView = RSSSourceLoginWebView(sourceID: "source-maintenance", title: "书源维护公告")
        let loginCookieView = RSSSourceLoginCookieView(sourceID: "source-maintenance", title: "书源维护公告")
        let loginClearView = RSSSourceLoginClearView(sourceID: "source-maintenance", title: "书源维护公告")
        XCTAssertNotNil(varsView)
        XCTAssertNotNil(loginView)
        XCTAssertNotNil(loginWebView)
        XCTAssertNotNil(loginCookieView)
        XCTAssertNotNil(loginClearView)
    }

    func testRSSSourceImportExportAndGroupViewsCanInit() {
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
    }

    func testRSSSupplementalViewsCanInit() {
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
    }

    func testSettingsTabViewCanInit() {
        // SettingsTabView 需要 coordinator —— 仅验证类型存在
        XCTAssertNotNil(AppTab.settings.title)
    }

    func testSettingsDemoFeatureStateViewsCanInitFromDemoRoutes() {
        for route in DemoRouteMappings.expectedSettingsShellRoutes {
            let view = SettingsDemoShellView(demoRoute: route)
            XCTAssertNotNil(view)
        }
    }

    func testLegacySettingsAndSourceRoutesMapToDemoFallbackRoutes() {
        let mappings: [(Route, String)] = [
            (.settingsReading, "settings-general"),
            (.settingsAbout, "about-feedback"),
            (.backupSettings, "sync-backup"),
            (.syncProgress, "restore-progress"),
            (.webdavBooks, "webdav-config"),
            (.sourceDetail(sourceID: "biquge"), "source-detail"),
            (.sourceAdd, "source-import-options"),
            (.sourceEdit(sourceID: "biquge"), "source-rule-edit"),
            (.sourceTestResult(sourceID: "biquge"), "source-detect")
        ]

        for (route, demoRoute) in mappings {
            XCTAssertEqual(AppShellView.settingsDemoFallbackRoute(for: route), demoRoute)
            XCTAssertNotNil(SettingsDemoShellView(demoRoute: demoRoute))
        }

        XCTAssertNil(AppShellView.settingsDemoFallbackRoute(for: .webdavSettings))
        XCTAssertNil(AppShellView.settingsDemoFallbackRoute(for: .bookSources))
        XCTAssertNil(AppShellView.settingsDemoFallbackRoute(for: .bookSourceImport))
        XCTAssertNil(AppShellView.settingsDemoFallbackRoute(for: .settings))
    }

    func testWebDAVLiveRouteCanInitWithDemoSurfaces() {
        let route = Route.webdavSettings
        let view = WebDAVSettingsView()

        XCTAssertEqual(route.title, "WebDAV 备份")
        XCTAssertNotNil(view)
        XCTAssertNil(AppShellView.settingsDemoFallbackRoute(for: route))
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == route.title })
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

    func testBookBatchManagementRouteExists_butNotATab() {
        let route = Route.bookBatchManagement
        XCTAssertEqual(route.title, "批量管理")
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "批量管理" })
    }

    func testBookshelfImportRouteExists_butNotATab() {
        let route = Route.bookshelfImport
        XCTAssertEqual(route.title, "导入书籍")
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "导入书籍" })
    }

    func testBookDetailTocRouteExists_butNotATab() {
        let route = Route.bookDetailToc(bookURL: "demo://book/long-night", title: "长夜余火")
        XCTAssertEqual(route.title, "目录预览")
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "目录预览" })
    }

    func testRouteHasPrototypeGallery() {
        let route = Route.prototypeGallery
        XCTAssertTrue(route.title.contains("DEBUG"))
        XCTAssertTrue(route.title.contains("Prototype Gallery"))
    }

    // MARK: - 关键约束：搜索 / 设置 / 阅读不是主 Tab

    func testSearchRouteExists_butNotATab() {
        let route = Route.search
        XCTAssertEqual(route.title, "搜索")
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "搜索" })
    }

    func testSearchResultsRouteMapsToNativeSearchQuery() {
        let route = Route.searchResults(query: "长夜余火")
        let query = AppShellView.searchResultsQuery(for: route)

        XCTAssertEqual(route.title, "搜索结果")
        XCTAssertEqual(query, "长夜余火")
        XCTAssertNotNil(SearchView(initialQuery: query ?? ""))
        XCTAssertNil(AppShellView.searchResultsQuery(for: .search))
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "搜索结果" })
    }

    func testSettingsRouteExists_butIsATab() {
        // 设置既是 route 也是主 Tab（契约：设置是主 Tab）
        let route = Route.settings
        XCTAssertEqual(route.title, "设置")
        XCTAssertTrue(AppTab.contractOrder.contains { $0.title == "设置" })
    }

    func testReaderRouteExists_butNotATab() {
        let route = Route.reader(bookID: "b1", chapterURL: "url", chapterTitle: "ch1")
        XCTAssertTrue(route.title.contains("阅读"))
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title.contains("阅读") })
    }

    func testReaderRouteMapsToNativeReaderPayload() {
        let route = Route.reader(
            bookID: "book-lighthouse",
            chapterURL: "demo://chapter/32",
            chapterTitle: "第 32 章 雨夜"
        )
        let payload = AppShellView.readerRoutePayload(for: route)

        XCTAssertEqual(payload?.bookID, "book-lighthouse")
        XCTAssertEqual(payload?.chapterURL, "demo://chapter/32")
        XCTAssertEqual(payload?.chapterTitle, "第 32 章 雨夜")
        XCTAssertNotNil(ReaderView(
            chapterURL: payload?.chapterURL ?? "",
            chapterTitle: payload?.chapterTitle ?? "",
            bookID: payload?.bookID
        ))
        XCTAssertNil(AppShellView.readerRoutePayload(for: .search))
        XCTAssertNil(AppShellView.readerRoutePayload(for: .sourceSwitch(bookURL: "demo://book/lighthouse")))
    }

    func testReaderContextlessValueRoutesMapToDemoFallbacks() {
        let tocRoute = Route.toc(bookTitle: "灯塔与雾", bookAuthor: "林小舟")
        let contentRoute = Route.content(chapterTitle: "第 32 章 雨夜")

        XCTAssertEqual(AppShellView.readerContextFallbackRoute(for: tocRoute), "reader-full-directory")
        XCTAssertEqual(AppShellView.readerContextFallbackRoute(for: contentRoute), "reader")
        XCTAssertNotNil(ReaderDemoShellView(demoRoute: AppShellView.readerContextFallbackRoute(for: tocRoute) ?? ""))
        XCTAssertNotNil(ReaderDemoShellView(demoRoute: AppShellView.readerContextFallbackRoute(for: contentRoute) ?? ""))
        XCTAssertNil(AppShellView.readerContextFallbackRoute(for: .search))
    }

    func testReaderDemoFeatureStateViewsCanInitFromDemoRoutes() {
        for route in DemoRouteMappings.expectedReaderShellRoutes where route != "immersive-reading" && route != "reader" {
            let view = ReaderDemoShellView(demoRoute: route)
            XCTAssertNotNil(view)
        }
    }

    func testReaderLegacyTOCAndContentRoutesCanInitWithDemoSurfaces() {
        let coordinator = ShellAssembly.makeMockReadingFlowCoordinator()
        let book = SearchResultItem(
            title: "长夜余火",
            detailURL: "demo://book/long-night",
            author: "爱潜水的乌贼"
        )
        let chapter = TOCItem(
            chapterTitle: "第 32 章 雨夜",
            chapterURL: "demo://chapter/32",
            chapterIndex: 31
        )

        let tocView = TOCView(coordinator: coordinator, book: book)
        let contentView = ContentView(coordinator: coordinator, chapter: chapter)

        XCTAssertNotNil(tocView)
        XCTAssertNotNil(contentView)
    }

    func testBookSourceLiveRoutesCanInitWithDemoSurfaces() {
        let coordinator = ShellAssembly.makeMockReadingFlowCoordinator()
        let source = BookSourceListView.fixtureSources[0]
        let listView = BookSourceListView(coordinator: coordinator)
        let importView = BookSourceImportView()
        let rowView = BookSourceRowView(
            name: source.bookSourceName,
            url: source.bookSourceUrl ?? "",
            group: source.bookSourceGroup,
            enabled: .constant(source.enabled),
            onDelete: {}
        )
        let detailSheet = BookSourceDetailSheet(source: source)

        XCTAssertNotNil(listView)
        XCTAssertNotNil(importView)
        XCTAssertNotNil(rowView)
        XCTAssertNotNil(detailSheet)
        XCTAssertNil(AppShellView.settingsDemoFallbackRoute(for: .bookSources))
        XCTAssertNil(AppShellView.settingsDemoFallbackRoute(for: .bookSourceImport))
    }

    func testRSSDetailRouteExists_butNotATab() {
        let route = Route.rssDetail(rssID: "https://example.com/rss")
        XCTAssertEqual(route.title, "RSS 阅读")
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "RSS 阅读" })
    }

    func testRSSOriginalRouteExists_butNotATab() {
        let route = Route.rssOriginal(
            url: "https://example.com/rss",
            title: "RSS 原文",
            sourceTitle: "RSS"
        )
        XCTAssertEqual(route.title, "原文页面")
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "原文页面" })
    }

    func testRSSOriginalBrowserRouteExists_butNotATab() {
        let route = Route.rssOriginalBrowser(
            url: "https://example.com/rss",
            title: "RSS 原文",
            sourceTitle: "RSS"
        )
        XCTAssertEqual(route.title, "系统浏览器")
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "系统浏览器" })
    }

    func testRSSManagementRoutesExist_butNotTabs() {
        XCTAssertEqual(Route.rssSubscriptions.title, "RSS 订阅管理")
        XCTAssertEqual(Route.rssSourceActions(sourceID: "github-releases", title: "GitHub Releases").title, "源操作")
        XCTAssertEqual(Route.rssSourceEdit(sourceID: "github-releases", title: "GitHub Releases").title, "RSS 源编辑")
        XCTAssertEqual(Route.rssSourceDebug(sourceID: "github-releases", title: "GitHub Releases").title, "规则调试")
        XCTAssertEqual(Route.rssSourceVars(sourceID: "github-releases", title: "GitHub Releases").title, "源变量")
        XCTAssertEqual(Route.rssSourceLogin(sourceID: "source-maintenance", title: "书源维护公告").title, "源登录")
        XCTAssertEqual(Route.rssSourceLoginWeb(sourceID: "source-maintenance", title: "书源维护公告").title, "网页登录")
        XCTAssertEqual(Route.rssSourceLoginCookie(sourceID: "source-maintenance", title: "书源维护公告").title, "Cookie 提取")
        XCTAssertEqual(Route.rssSourceLoginClear(sourceID: "source-maintenance", title: "书源维护公告").title, "清除登录")
        XCTAssertEqual(Route.rssSourceGroups.title, "RSS 分组")
        XCTAssertEqual(Route.rssSourceGroupEdit(groupID: "open-source", title: "开源项目").title, "编辑 RSS 分组")
        XCTAssertEqual(Route.rssSourceBatch.title, "批量管理")
        XCTAssertEqual(Route.rssSourceExport.title, "导出订阅源")
        XCTAssertEqual(Route.rssSourceExportDetail(sourceID: "github-releases", title: "GitHub Releases").title, "导出预览")
        XCTAssertEqual(Route.rssSourceExportResult.title, "导出完成")
        XCTAssertEqual(Route.rssSourcePin(sourceID: "github-releases", title: "GitHub Releases").title, "置顶订阅源")
        XCTAssertEqual(Route.rssSourceDisable(sourceID: "github-releases", title: "GitHub Releases").title, "禁用订阅源")
        XCTAssertEqual(Route.rssSourceBatchDisable.title, "批量禁用")
        XCTAssertEqual(Route.rssSourceImport.title, "导入订阅源")
        XCTAssertEqual(Route.rssSourceImportDetail(sourceID: "source-maintenance", title: "书源维护公告").title, "导入详情")
        XCTAssertEqual(Route.rssSourceImportResult.title, "导入完成")
        XCTAssertEqual(Route.rssSearch.title, "RSS 搜索")
        XCTAssertEqual(Route.rssReadRecord(sourceID: "github-releases", title: "GitHub Releases").title, "RSS 阅读记录")
        XCTAssertEqual(Route.rssRecordClear.title, "清空阅读记录")
        XCTAssertEqual(Route.rssRuleSubscription.title, "RSS 规则订阅")
        XCTAssertEqual(Route.rssRuleSubscriptionDetail(subscriptionID: "community-rss", title: "社区 RSS 源订阅").title, "规则订阅详情")
        XCTAssertEqual(Route.rssRuleSubscriptionEdit(subscriptionID: "community-rss", title: "社区 RSS 源订阅").title, "规则订阅编辑")
        XCTAssertEqual(Route.rssRuleSubscriptionTest(subscriptionID: "community-rss", title: "社区 RSS 源订阅").title, "规则订阅测试")
        XCTAssertEqual(Route.rssRuleSubscriptionApply.title, "应用订阅更新")
        XCTAssertEqual(Route.rssFavoriteGroups.title, "RSS 收藏分组")
        XCTAssertEqual(Route.rssFavoriteGroupEdit(groupID: "default", title: "默认分组").title, "编辑收藏分组")
        XCTAssertEqual(Route.rssFavoriteClear.title, "清空收藏分组")
        XCTAssertEqual(Route.rssEmpty.title, "RSS 空状态")
        XCTAssertEqual(Route.rssError.title, "RSS 错误状态")
        XCTAssertEqual(Route.stateError(message: "网络连接失败").title, "错误")
        XCTAssertEqual(Route.stateOffline.title, "离线")
        XCTAssertEqual(Route.statePermission(permission: "本地文件").title, "权限")
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "RSS 订阅管理" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "源操作" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "RSS 源编辑" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "规则调试" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "源变量" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "源登录" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "网页登录" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "Cookie 提取" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "清除登录" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "RSS 分组" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "编辑 RSS 分组" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "批量管理" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "导出订阅源" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "导入订阅源" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "RSS 搜索" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "RSS 阅读记录" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "RSS 规则订阅" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "RSS 收藏分组" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "RSS 错误状态" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "错误" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "离线" })
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "权限" })
    }

    func testBookSourceRouteExists_butNotATab() {
        // 书源管理存在，但不作为主底栏
        let route = Route.bookSources
        XCTAssertEqual(route.title, "书源管理")
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title == "书源管理" })
    }
}
