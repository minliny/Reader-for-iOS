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
    @State private var bookshelfPath: [Route] = []
    @State private var discoverPath: [Route] = []
    @State private var rssPath: [Route] = []
    @State private var settingsPath: [Route] = []
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?

    var body: some View {
        ZStack(alignment: isExpandedLayout ? .leading : .bottom) {
            TabView(selection: tabBinding) {
                ForEach(AppTab.contractOrder) { tab in
                    NavigationStack(path: pathBinding(for: tab)) {
                        rootView(for: tab)
                            .navigationDestination(for: Route.self) { route in
                                destinationView(for: route)
                            }
                    }
                    .tag(tab)
                    .hiddenSystemTabBarIfAvailable()
                }
            }
            .animation(.easeInOut(duration: navigationState.motion.duration(AppMotion.Duration.tabSwitch)),
                       value: navigationState.activeTab)
            .padding(.leading, isExpandedLayout ? ReaderDesignTokens.tabletNavWidth + 12 : 0)
            .padding(.bottom, isExpandedLayout ? 0 : ReaderDesignTokens.mainNavHeight + 14)

            FloatingTabBar(
                tabs: AppTab.contractOrder,
                selection: tabBinding,
                onSelect: { tab in navigationState.switchTab(tab) },
                axis: isExpandedLayout ? .vertical : .horizontal
            )
            .frame(width: isExpandedLayout ? ReaderDesignTokens.tabletNavWidth : nil)
            .padding(.leading, isExpandedLayout ? 8 : 0)
            .padding(.horizontal, isExpandedLayout ? 0 : 0)
            .padding(.bottom, isExpandedLayout ? 0 : 0)
        }
    }

    private var isExpandedLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .regular
        #else
        false
        #endif
    }

    /// 每个主 Tab 保留独立 `NavigationPath`，对齐 demo Slice 1 的 back stack 语义。
    private func pathBinding(for tab: AppTab) -> Binding<[Route]> {
        switch tab {
        case .bookshelf:
            return $bookshelfPath
        case .discover:
            return $discoverPath
        case .rss:
            return $rssPath
        case .settings:
            return $settingsPath
        }
    }

    /// 当前 Tab 的根视图。搜索、阅读、书源管理都不是主 Tab。
    @ViewBuilder
    private func rootView(for tab: AppTab) -> some View {
        switch tab {
        case .bookshelf:
            BookshelfView(navigationState: navigationState)

        case .discover:
            DiscoverHomeShellView()

        case .rss:
            RSSFeedView()

        case .settings:
            SettingsTabView(coordinator: coordinator)
        }
    }

    /// Value-route fallback for legacy callers that still push `Route`.
    /// Full 131-route migration remains deferred by the UI slice matrix.
    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
        case .home, .bookshelf:
            BookshelfView(navigationState: navigationState)

        case .discover:
            DiscoverHomeShellView()

        case .rssList:
            RSSFeedView()

        case .settings:
            SettingsTabView(coordinator: coordinator)

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

private extension View {
    @ViewBuilder
    func hiddenSystemTabBarIfAvailable() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .tabBar)
        #else
        self
        #endif
    }
}
