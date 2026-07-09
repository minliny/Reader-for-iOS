import SwiftUI
import ReaderCoreModels
import ReaderShellValidation
// 注意：不在此处 `import ReaderUIContract`。
// 该模块定义了 `public struct Content`，会与 SwiftUI `ViewModifier` 关联类型 `Content`
// 产生命名歧义，导致 `HeroMatchedGeometryModifier` 无法 conform `ViewModifier`。
// `ReaderViewState` 是本 target 内定义的派生类型，不需要在这里直接引用 contract 类型。

/// Hero transition namespace environment key.
///
/// 真源：`frontend-demo-optimized/MOTION_EFFECTS.md` line 611-635 `reader.entry.coverToImmersive`
/// 与 line 985-1001 `reader.session.controlSpace.enter/exit`。
///
/// 用途：在 AppShellView 顶层创建 `@Namespace`，通过 environment 注入到所有子视图，
/// 让 BookshelfView 的封面与 ReaderView 的入口锚点（或会话胶囊与控制层运行空间）
/// 能共享同一 `Namespace.ID`，从而驱动 `matchedGeometryEffect` 的 shared element 过渡。
///
/// 不复制 Web CSS / DOM；仅提供 SwiftUI 原生 `matchedGeometryEffect` 所需的 namespace 传递通道。
private struct HeroNamespaceEnvironmentKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    /// Hero transition namespace。`nil` 表示当前视图层级未提供 namespace，
    /// 子视图应跳过 `matchedGeometryEffect`（避免运行时崩溃）。
    var heroNamespace: Namespace.ID? {
        get { self[HeroNamespaceEnvironmentKey.self] }
        set { self[HeroNamespaceEnvironmentKey.self] = newValue }
    }
}

extension View {
    /// 注入 hero transition namespace。通常由 AppShellView 顶层调用一次。
    func heroNamespace(_ namespace: Namespace.ID?) -> some View {
        environment(\.heroNamespace, namespace)
    }

    /// 条件性应用 `matchedGeometryEffect`。
    /// `namespace` 为 `nil` 时（如 Preview / 测试 / 未注入场景）原样返回 content，
    /// 避免运行时崩溃。`isSource: true` 用于"来源锚点"（如书架封面），
    /// `isSource: false` 用于"目标锚点"（如阅读器入口）。
    ///
    /// 真源：MOTION_EFFECTS.md line 611-635 `reader.entry.coverToImmersive`
    /// 约束："封面是'来源锚点'，不是全屏 shared element 主体。可做轻量 shared element，
    /// 但不能把 2:3 封面拉伸成阅读纸面"。
    func heroMatchedGeometry(id: String, namespace: Namespace.ID?, isSource: Bool = false) -> some View {
        modifier(HeroMatchedGeometryModifier(id: id, namespace: namespace, isSource: isSource))
    }
}

/// `heroMatchedGeometry` 的 ViewModifier 实现。
private struct HeroMatchedGeometryModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID?
    let isSource: Bool

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedGeometryEffect(id: id, in: namespace, isSource: isSource)
        } else {
            content
        }
    }
}

/// 原生 SwiftUI App Shell —— 4 主底栏：书架 / 发现 / RSS / 设置。
///
/// 真源：
/// - `docs/cross-platform-ui/CROSS_PLATFORM_UI_BASELINE.md` App Shell
/// - `docs/ui-handoff/FRONTEND_DEVELOPMENT_SLICE_MATRIX.md` Slice 1
/// - `Reader UI/frontend-demo-optimized/styles/01-shell-layout.css` `.fd-main-nav`
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
    @State private var mainNavVisibleByContent = true
    @State private var mainTabTopBarRequest: MainTabTopBarRequest?
    // B1-iOS P0：contract-host 渲染开关。true = book-detail/source-switch 走 contract renderer。
    @State private var useContractHost = true

    // P3-B: 会话级状态存储，作为 @StateObject 注入子视图
    @StateObject private var sessionStore: ReaderSessionStore = ReaderSessionStore()

    // P2-A HERO-P1-1: hero transition namespace。
    // 真源：MOTION_EFFECTS.md line 611-635 reader.entry.coverToImmersive（封面 -> 沉浸阅读）
    // 与 line 985-1001 reader.session.controlSpace.enter/exit（胶囊 <-> 控制层运行空间 morph）。
    // 通过 .heroNamespace(heroNamespace) 注入 environment，让 BookshelfView / ReaderView
    // 等子视图可通过 @Environment(\.heroNamespace) 读取并应用 matchedGeometryEffect。
    @Namespace private var heroNamespace

    var body: some View {
        GeometryReader { proxy in
            let viewport = DemoViewportSnapshot.make(size: proxy.size)
            shellBody(viewport: viewport)
        }
        .overlay {
            routeOverlay
        }
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
        // P3-B: 注入 ReaderSessionStore 到所有子视图（包括 routeOverlay 中的 ReaderView）
        .environmentObject(sessionStore)
        // P2-A: 注入 hero namespace，供 BookshelfView / ReaderView 等子视图做 matchedGeometryEffect
        .heroNamespace(heroNamespace)
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
                        ReaderMotionAdapter.animation(
                            for: MotionRequest(operation: .tabSwitch, containerRole: .mainTabShell),
                            motion: navigationState.motion
                        ),
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
        if shouldShowMainNav && navigationState.navigationPath.isEmpty {
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
        mainNavVisibleByContent && navigationState.readerContext == nil && navigationState.navigationPath.isEmpty
    }

    // MARK: - Contract ViewState（Slice 1）

    /// 当前 contract `ReaderViewState`，用于 golden test 与 smoke 验证。
    ///
    /// 视图层仍直接消费 `navigationState.activeTab`，本属性只作为 contract 派生层入口，
    /// 不参与渲染。后续 slice 会逐步让视图层改消费 `ViewState`。
    var contractViewState: ReaderViewState {
        ReaderViewState(from: navigationState)
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
    /// Demo route ownership is tracked by `DemoRouteMappings`; the app shell
    /// renders the current route in-place instead of handing ownership to a
    /// system navigation stack.
    @ViewBuilder
    private var routeOverlay: some View {
        if let route = navigationState.navigationPath.last {
            destinationView(for: route, onExit: {
                navigationState.goBack()
            })
            // B1-iOS P0 + D6: push/pop 接线 ReaderMotionAdapter。
            // containerRole 按 route shell 区分：
            // - bookDetail → libraryShell（.app_route_push_forward/backward，priority 150）
            // - sourceSwitch → flowShell（.source_switch_route_push/pop，priority 200）
            // - 其他 → appShell（默认 route push/pop，priority 100）
            // resolver 返回 nil 时无动画（reduced-motion 或无策略命中），安全降级。
            .transition(
                .asymmetric(
                    insertion: .opacity.animation(
                        ReaderMotionAdapter.animation(
                            for: MotionRequest(operation: .push, containerRole: containerRole(for: route)),
                            motion: navigationState.motion
                        )
                    ),
                    removal: .opacity.animation(
                        ReaderMotionAdapter.animation(
                            for: MotionRequest(operation: .pop, containerRole: containerRole(for: route)),
                            motion: navigationState.motion
                        )
                    )
                )
            )
            .zIndex(ReaderZIndex.overlay.rawValue)
        }
    }

    // B1-iOS P0 + B2: 按 route shell 返回 MotionContainerRole。
    // book-detail → LibraryShell；source-switch → FlowShell；
    // settings 系列二级页 → SettingsShell；其他 → appShell。
    // 真源：generated/swift/MotionPolicy.swift RouteShellLookup。
    private func containerRole(for route: Route?) -> MotionContainerRole {
        guard let route else { return .appShell }
        switch route {
        case .bookDetail, .bookDetailToc:
            return .libraryShell
        case .sourceSwitch:
            return .flowShell
        // B2: settings 系列二级页走 SettingsShell（app.route.push.forward/backward, priority 150）
        case .settingsReading, .settingsAbout, .backupSettings, .syncProgress,
             .webdavSettings, .webdavBooks,
             .bookSources, .bookSourceImport,
             .sourceDetail, .sourceAdd, .sourceEdit, .sourceTestResult:
            return .settingsShell
        default:
            return .appShell
        }
    }

    @ViewBuilder
    private func destinationView(for route: Route, onExit: (() -> Void)? = nil) -> some View {
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
                bookID: bookID,
                onExit: onExit
            )

        case .search:
            SearchView(onExit: onExit)

        case .searchResults(let query):
            SearchView(initialQuery: query, onExit: onExit)

        case .bookBatchManagement:
            BookshelfBatchManagementView(onExit: onExit)

        case .bookshelfGroups:
            BookshelfGroupManagementView(onExit: onExit)

        case .bookshelfImport:
            BookshelfLocalImportView(onExit: onExit)

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
            BookSourceImportView(onExit: onExit)

        case .settingsReading, .settingsAbout, .backupSettings, .syncProgress, .webdavBooks,
             .sourceDetail, .sourceAdd, .sourceEdit, .sourceTestResult:
            SettingsDemoShellView(
                demoRoute: Self.settingsDemoFallbackRoute(for: route) ?? "settings-general",
                onExit: onExit
            )

        case .bookDetail(let bookURL, let title, let author):
            if useContractHost {
                // B1-iOS P0 + P1：book-detail 走 contract renderer（LibraryShell），
                // 注入真实 bookURL/title/author，不再渲染硬编码 fixture。
                ContractHostView(bookDetail: bookURL, title: title, author: author)
            } else {
                BookDetailView(result: SearchResultItem(
                    title: title,
                    detailURL: bookURL,
                    author: author
                ), onExit: onExit)
            }

        case .bookDetailToc(let bookURL, let title):
            BookDirectoryPreviewView(bookURL: bookURL, title: title, onExit: onExit)

        case .sourceSwitch(let bookURL):
            if useContractHost {
                // B1-iOS P0 + P1：source-switch 走 contract renderer（FlowShell），
                // 注入真实 bookURL。
                ContractHostView(sourceSwitch: bookURL)
            } else {
                ReaderSourceSwitchFlowView(bookURL: bookURL, onExit: onExit)
            }

        case .toc:
            if let book = coordinator.selectedBook {
                TOCView(coordinator: coordinator, book: book, onExit: onExit)
            } else {
                ReaderDemoShellView(
                    demoRoute: Self.readerContextFallbackRoute(for: route) ?? "reader-full-directory",
                    onExit: onExit
                )
            }

        case .content:
            if let chapter = coordinator.selectedChapter {
                ContentView(coordinator: coordinator, chapter: chapter, onExit: onExit)
            } else {
                ReaderDemoShellView(
                    demoRoute: Self.readerContextFallbackRoute(for: route) ?? "reader",
                    onExit: onExit
                )
            }

        case .webdavSettings:
            SettingsDemoShellView(demoRoute: "webdav-config", onExit: onExit)

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
