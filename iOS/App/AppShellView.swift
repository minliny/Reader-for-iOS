import SwiftUI
import ReaderCoreModels
import ReaderShellValidation

/// 原生 SwiftUI App Shell —— 4 主底栏：书架 / 发现 / RSS / 设置。
///
/// 真源：
/// - `docs/cross-platform-ui/CROSS_PLATFORM_UI_BASELINE.md` App Shell
/// - `docs/ui-handoff/FRONTEND_DEVELOPMENT_SLICE_MATRIX.md` Slice 1
/// - `Reader UI/frontend-demo/styles/01-shell-layout.css` `.fd-main-nav`
///
/// 契约对齐：
/// - 四主 Tab 顺序固定：书架 / 发现 / RSS / 设置。
/// - 搜索、阅读页、书源管理都不是主 Tab。
/// - 主 Tab 切换走 `AppNavigationState.switchTab`（`app.tab.switch`），不写成二级 route push。
/// - `tab.item.press/select/switch` 由 `FloatingTabBar` 承载，按钮数量、尺寸、点击热区稳定。
/// - 内容区使用 `opacity` transition（`app.tab.switch` 内容区短 fade）。
/// - Tab 栏使用浮动 pill 样式（`.fd-main-nav` 规格），不是系统 49pt 实心栏。
struct AppShellView: View {
    struct ReaderRoutePayload: Equatable {
        let bookID: String
        let chapterURL: String
        let chapterTitle: String
    }

    @ObservedObject var coordinator: ReadingFlowCoordinator
    @ObservedObject var navigationState: AppNavigationState
    let environment: ReaderShellEnvironment
    @State private var routePath: [Route] = []
    @State private var mainNavVisibleByContent = true
    @State private var mainTabTopBarRequest: MainTabTopBarRequest?

    var body: some View {
        NavigationStack(path: $routePath) {
            GeometryReader { proxy in
                let viewport = DemoViewportSnapshot.make(size: proxy.size)
                shellBody(viewport: viewport)
            }
            .navigationDestination(for: Route.self) { route in
                destinationView(for: route)
            }
        }
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
    }

    @ViewBuilder
    private func shellBody(viewport: DemoViewportSnapshot) -> some View {
        let layout = AppShellMainTabLayout(viewport: viewport)
        DemoMainTabShell(
            contentLeadingPadding: layout.contentLeadingPadding,
            mainNavAlignment: layout.usesTabletRail ? .leading : .bottom,
            topBar: {
                mainTabTopBar
            },
            contentRegion: {
                tabContentRegion
                    .animation(
                        navigationState.motion.animation(AppMotion.Duration.tabSwitch),
                        value: navigationState.activeTab
                    )
            },
            stateHost: {
                EmptyView()
            },
            mainNav: {
                if shouldShowMainNav {
                    FloatingTabBar(
                        tabs: AppTab.contractOrder,
                        selection: tabBinding,
                        onSelect: { tab in navigationState.switchTab(tab) },
                        axis: layout.tabBarAxis
                    )
                    .frame(width: layout.mainNavWidth)
                    .padding(.leading, layout.mainNavLeadingPadding)
                    .accessibilityIdentifier("fd-main-nav-slot")
                    .transition(.opacity)
                }
            }
        )
    }

    @ViewBuilder
    private var mainTabTopBar: some View {
        if shouldShowMainNav && routePath.isEmpty {
            switch navigationState.activeTab {
            case .bookshelf:
                DemoTopBar(title: "书架") {
                    DemoTopActionButton(
                        icon: .search,
                        accessibilityLabel: "搜索书籍",
                        action: { mainTabTopBarRequest = .bookshelfSearch }
                    )

                    DemoTopActionButton(
                        icon: .more,
                        accessibilityLabel: "书架更多操作",
                        action: { mainTabTopBarRequest = .bookshelfMore }
                    )
                }

            case .discover:
                DemoTopBar(title: "发现") {
                    DemoTopActionButton(
                        icon: .refresh,
                        accessibilityLabel: "刷新发现入口",
                        action: { mainTabTopBarRequest = .discoverRefresh }
                    )
                }

            case .rss:
                let routeState = RSSDemoRouteState(route: "rss")
                RSSRootTopBar(
                    subscriptionCount: routeState.coreSources.filter(\.enabled).count,
                    statusText: routeState.statusText,
                    sources: routeState.coreSources,
                    onRefresh: { mainTabTopBarRequest = .rssRefresh },
                    onManage: { mainTabTopBarRequest = .rssManage },
                    isRefreshDisabled: false
                )

            case .settings:
                DemoTopBar(title: AppTab.settings.title)
            }
        }
    }

    @ViewBuilder
    private var tabContentRegion: some View {
        rootView(for: navigationState.activeTab)
            .id(navigationState.activeTab)
            .transition(.opacity)
            .onPreferenceChange(MainTabBarVisibilityPreferenceKey.self) { isVisible in
                mainNavVisibleByContent = isVisible
            }
    }

    struct AppShellMainTabLayout: Equatable {
        let usesTabletRail: Bool

        init(viewport: DemoViewportSnapshot) {
            self.usesTabletRail = viewport.usesTabletMainNav
        }

        var contentLeadingPadding: CGFloat {
            usesTabletRail ? ReaderDesignTokens.tabletNavWidth + 18 : 0
        }

        var contentBottomPadding: CGFloat {
            ReaderDesignTokens.mainTabContentBottomPadding
        }

        var mainNavWidth: CGFloat? {
            usesTabletRail ? ReaderDesignTokens.tabletNavWidth : nil
        }

        var mainNavLeadingPadding: CGFloat {
            usesTabletRail ? 16 : 0
        }

        var tabBarAxis: FloatingTabBarAxis {
            usesTabletRail ? .vertical : .horizontal
        }
    }

    var shouldShowMainNav: Bool {
        mainNavVisibleByContent && navigationState.readerContext == nil
    }

    /// 当前 Tab 的根视图。搜索、阅读、书源管理都不是主 Tab。
    @ViewBuilder
    private func rootView(for tab: AppTab) -> some View {
        switch tab {
        case .bookshelf:
            BookshelfView(
                navigationState: navigationState,
                showsTopBar: false,
                topBarRequest: $mainTabTopBarRequest
            )

        case .discover:
            DiscoverHomeShellView(
                showsTopBar: false,
                topBarRequest: $mainTabTopBarRequest
            )

        case .rss:
            RSSFeedView(
                showsTopBar: false,
                topBarRequest: $mainTabTopBarRequest
            )

        case .settings:
            SettingsTabView(coordinator: coordinator, showsTopBar: false)
        }
    }

    /// Value-route fallback for legacy callers that still push `Route`.
    /// Demo route ownership is tracked by `DemoRouteMappings`; this switch keeps
    /// the native destination bridge for concrete `Route` values.
    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
        case .home, .bookshelf:
            BookshelfView(
                navigationState: navigationState,
                showsTopBar: false,
                topBarRequest: $mainTabTopBarRequest
            )

        case .discover:
            DiscoverHomeShellView(
                showsTopBar: false,
                topBarRequest: $mainTabTopBarRequest
            )

        case .rssList:
            RSSFeedView(
                showsTopBar: false,
                topBarRequest: $mainTabTopBarRequest
            )

        case .settings:
            SettingsTabView(coordinator: coordinator, showsTopBar: false)

        case .reader(let bookID, let chapterURL, let chapterTitle):
            ReaderView(
                chapterURL: chapterURL,
                chapterTitle: chapterTitle,
                bookID: bookID
            )

        case .search:
            SearchView()

        case .searchResults(let query):
            SearchView(initialQuery: query)

        case .bookBatchManagement:
            BookshelfBatchManagementView()

        case .bookshelfGroups:
            BookshelfGroupManagementView()

        case .bookshelfImport:
            BookshelfLocalImportView()

        case .rssSearch:
            RSSSearchView()

        case .rssDetail(let rssID):
            RSSArticleDetailView(
                item: RSSArticleDetailView.fallbackItem(link: rssID),
                sourceTitle: "RSS"
            )

        case .rssOriginal(let url, let title, let sourceTitle):
            RSSOriginalPreviewView(urlString: url, title: title, sourceTitle: sourceTitle)

        case .rssOriginalBrowser(let url, let title, let sourceTitle):
            RSSOriginalBrowserConfirmView(urlString: url, title: title, sourceTitle: sourceTitle)

        case .rssSubscriptions:
            RSSSubscriptionManagementView()

        case .rssSourceActions(let sourceID, let title):
            RSSSourceActionsView(sourceID: sourceID, title: title)

        case .rssSourceEdit(let sourceID, let title):
            RSSSourceEditView(sourceID: sourceID, title: title)

        case .rssSourceDebug(let sourceID, let title):
            RSSSourceDebugView(sourceID: sourceID, title: title)

        case .rssSourceVars(let sourceID, let title):
            RSSSourceVarsView(sourceID: sourceID, title: title)

        case .rssSourceLogin(let sourceID, let title):
            RSSSourceLoginView(sourceID: sourceID, title: title)

        case .rssSourceLoginWeb(let sourceID, let title):
            RSSSourceLoginWebView(sourceID: sourceID, title: title)

        case .rssSourceLoginCookie(let sourceID, let title):
            RSSSourceLoginCookieView(sourceID: sourceID, title: title)

        case .rssSourceLoginClear(let sourceID, let title):
            RSSSourceLoginClearView(sourceID: sourceID, title: title)

        case .rssSourceGroups:
            RSSSourceGroupsView()

        case .rssSourceGroupEdit(let groupID, let title):
            RSSSourceGroupEditView(groupID: groupID, title: title)

        case .rssSourceBatch:
            RSSSourceBatchView()

        case .rssSourceExport:
            RSSSourceExportView()

        case .rssSourceExportDetail(let sourceID, let title):
            RSSSourceExportDetailView(sourceID: sourceID, title: title)

        case .rssSourceExportResult:
            RSSSourceExportResultView()

        case .rssSourcePin(let sourceID, let title):
            RSSSourcePinConfirmView(sourceID: sourceID, title: title)

        case .rssSourceDisable(let sourceID, let title):
            RSSSourceDisableConfirmView(sourceID: sourceID, title: title)

        case .rssSourceBatchDisable:
            RSSSourceBatchDisableConfirmView()

        case .rssSourceImport:
            RSSSourceImportView()

        case .rssSourceImportDetail(let sourceID, let title):
            RSSSourceImportDetailView(sourceID: sourceID, title: title)

        case .rssSourceImportResult:
            RSSSourceImportResultView()

        case .rssReadRecord(let sourceID, let title):
            RSSReadRecordView(sourceID: sourceID, title: title)

        case .rssRecordClear:
            RSSRecordClearConfirmView()

        case .rssRuleSubscription:
            RSSRuleSubscriptionView()

        case .rssRuleSubscriptionDetail(let subscriptionID, let title):
            RSSRuleSubscriptionDetailView(subscriptionID: subscriptionID, title: title)

        case .rssRuleSubscriptionEdit(let subscriptionID, let title):
            RSSRuleSubscriptionEditView(subscriptionID: subscriptionID, title: title)

        case .rssRuleSubscriptionTest(let subscriptionID, let title):
            RSSRuleSubscriptionTestView(subscriptionID: subscriptionID, title: title)

        case .rssRuleSubscriptionApply:
            RSSRuleSubscriptionApplyConfirmView()

        case .rssFavoriteGroups:
            RSSFavoriteGroupsView()

        case .rssFavoriteGroupEdit(let groupID, let title):
            RSSFavoriteGroupEditView(groupID: groupID, title: title)

        case .rssFavoriteClear:
            RSSFavoriteClearConfirmView()

        case .rssEmpty:
            RSSStateView(kind: .empty)

        case .rssError:
            RSSStateView(kind: .error)

        case .bookSources:
            BookSourceListView(coordinator: coordinator)

        case .bookSourceImport:
            BookSourceImportView()

        case .settingsReading, .settingsAbout, .backupSettings, .syncProgress, .webdavBooks,
             .sourceDetail, .sourceAdd, .sourceEdit, .sourceTestResult:
            SettingsDemoShellView(demoRoute: Self.settingsDemoFallbackRoute(for: route) ?? "settings-general")

        case .bookDetail(let bookURL, let title, let author):
            BookDetailView(result: SearchResultItem(
                title: title,
                detailURL: bookURL,
                author: author
            ))

        case .bookDetailToc(let bookURL, let title):
            BookDirectoryPreviewView(bookURL: bookURL, title: title)

        case .sourceSwitch(let bookURL):
            ReaderSourceSwitchFlowView(bookURL: bookURL)

        case .toc:
            if let book = coordinator.selectedBook {
                TOCView(coordinator: coordinator, book: book)
            } else {
                ReaderDemoShellView(demoRoute: Self.readerContextFallbackRoute(for: route) ?? "reader-full-directory")
            }

        case .content:
            if let chapter = coordinator.selectedChapter {
                ContentView(coordinator: coordinator, chapter: chapter)
            } else {
                ReaderDemoShellView(demoRoute: Self.readerContextFallbackRoute(for: route) ?? "reader")
            }

        case .webdavSettings:
            WebDAVSettingsView()

        case .prototypeGallery:
            PrototypeGalleryView()

        case .stateError(let message):
            StateSurfaceView(kind: .error(message: message))

        case .stateOffline:
            StateSurfaceView(kind: .offline)

        case .statePermission(let permission):
            PermissionStateView(permission: permission)
        }
    }

    static func readerRoutePayload(for route: Route) -> ReaderRoutePayload? {
        guard case let .reader(bookID, chapterURL, chapterTitle) = route else {
            return nil
        }
        return ReaderRoutePayload(bookID: bookID, chapterURL: chapterURL, chapterTitle: chapterTitle)
    }

    static func searchResultsQuery(for route: Route) -> String? {
        guard case let .searchResults(query) = route else {
            return nil
        }
        return query
    }

    static func readerContextFallbackRoute(for route: Route) -> String? {
        switch route {
        case .toc:
            return "reader-full-directory"
        case .content:
            return "reader"
        default:
            return nil
        }
    }

    static func settingsDemoFallbackRoute(for route: Route) -> String? {
        switch route {
        case .settingsReading:
            return "settings-general"
        case .settingsAbout:
            return "about-feedback"
        case .backupSettings:
            return "sync-backup"
        case .syncProgress:
            return "restore-progress"
        case .webdavBooks:
            return "webdav-config"
        case .sourceDetail(_):
            return "source-detail"
        case .sourceAdd:
            return "source-import-options"
        case .sourceEdit(_):
            return "source-rule-edit"
        case .sourceTestResult(_):
            return "source-detect"
        default:
            return nil
        }
    }

    /// `app.tab.switch` 绑定：写回 `AppNavigationState.activeTab`（单一状态源），
    /// 切换时由 `switchTab` 处理打断与 motion。
    private var tabBinding: Binding<AppTab> {
        Binding(
            get: { navigationState.activeTab },
            set: { newTab in navigationState.switchTab(newTab) }
        )
    }
}
