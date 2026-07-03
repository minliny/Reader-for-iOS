import SwiftUI
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderShellValidation

public struct RSSFeedView: View {
    @StateObject private var viewModel: RSSFeedViewModel
    private let loadsLiveSubscriptions: Bool
    @State private var activeDemoRoute: String?
    @State private var selectedMode: String
    @State private var activeGroupFilter: String
    @State private var isGroupFilterOpen: Bool
    @State private var isCategoryFilterOpen: Bool
    @State private var showSubscriptionManagement = false
    @Binding private var topBarRequest: MainTabTopBarRequest?
    private let showsTopBar: Bool

    @MainActor
    public init(
        showsTopBar: Bool = true,
        topBarRequest: Binding<MainTabTopBarRequest?> = .constant(nil)
    ) {
        self.loadsLiveSubscriptions = false
        self.showsTopBar = showsTopBar
        self._activeDemoRoute = State(initialValue: nil)
        self._selectedMode = State(initialValue: "源列表")
        self._activeGroupFilter = State(initialValue: "全部")
        self._isGroupFilterOpen = State(initialValue: false)
        self._isCategoryFilterOpen = State(initialValue: false)
        self._topBarRequest = topBarRequest
        self._viewModel = StateObject(wrappedValue: RSSFeedViewModel())
    }

    @MainActor
    public init(
        demoRoute: String,
        showsTopBar: Bool = true,
        topBarRequest: Binding<MainTabTopBarRequest?> = .constant(nil)
    ) {
        let state = RSSDemoRouteState(route: demoRoute)
        let viewModel = RSSFeedViewModel(feedURL: state.feedURL, feedName: state.source.name)
        viewModel.subscriptions = state.coreSources
        viewModel.selectedSubscriptionURL = state.selectedSourceURL
        viewModel.feedState = state.feedState
        self.loadsLiveSubscriptions = false
        self.showsTopBar = showsTopBar
        self._activeDemoRoute = State(initialValue: state.route)
        self._selectedMode = State(initialValue: state.selectedMode)
        self._activeGroupFilter = State(initialValue: "全部")
        self._isGroupFilterOpen = State(initialValue: false)
        self._isCategoryFilterOpen = State(initialValue: false)
        self._topBarRequest = topBarRequest
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    @MainActor
    public init(
        viewModel: RSSFeedViewModel,
        showsTopBar: Bool = true,
        topBarRequest: Binding<MainTabTopBarRequest?> = .constant(nil)
    ) {
        self.loadsLiveSubscriptions = true
        self.showsTopBar = showsTopBar
        self._activeDemoRoute = State(initialValue: nil)
        self._selectedMode = State(initialValue: "源列表")
        self._activeGroupFilter = State(initialValue: "全部")
        self._isGroupFilterOpen = State(initialValue: false)
        self._isCategoryFilterOpen = State(initialValue: false)
        self._topBarRequest = topBarRequest
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        let routeState = demoState

        if let routeState {
            DemoLibraryShell(title: routeState.navigationTitle, contentStyle: .custom) {
                DemoPaperScreen {
                    RSSDemoRouteContent(
                        state: routeState,
                        selectedMode: $selectedMode,
                        activeGroupFilter: $activeGroupFilter,
                        isGroupFilterOpen: $isGroupFilterOpen,
                        isCategoryFilterOpen: $isCategoryFilterOpen,
                        onSelectRoute: selectDemoRoute
                    )
                }
            }
        } else {
            rssMainTabContent(routeState: routeState)
        }
    }

    @ViewBuilder
    private func rssMainTabContent(routeState: RSSDemoRouteState?) -> some View {
        VStack(spacing: 0) {
            if showsTopBar {
                RSSRootTopBar(
                    subscriptionCount: topBarSources.filter(\.enabled).count,
                    statusText: statusText,
                    sources: topBarSources,
                    onRefresh: refreshCurrentFeed,
                    onManage: { showSubscriptionManagement = true },
                    isRefreshDisabled: isRSSActionDisabled
                )
            }

            DemoPaperScreen(bottomPadding: ReaderDesignTokens.mainTabContentBottomPadding) {
                RSSDemoHomeContent(
                    selectedMode: $selectedMode,
                    activeGroupFilter: $activeGroupFilter,
                    isGroupFilterOpen: $isGroupFilterOpen,
                    onSelectRoute: selectDemoRoute
                )
            }
        }
        .background(ReaderDesignTokens.Color.paperSolid.ignoresSafeArea())
        .navigationTitle(routeState?.navigationTitle ?? "RSS")
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
        .task {
            guard loadsLiveSubscriptions else { return }
            await viewModel.loadSubscriptions()
        }
        .onChange(of: topBarRequest) { _, request in
            handleTopBarRequest(request)
        }
        .navigationDestination(isPresented: $showSubscriptionManagement) {
            RSSSubscriptionManagementView(sources: topBarSources)
        }
    }

    private var demoState: RSSDemoRouteState? {
        activeDemoRoute.map(RSSDemoRouteState.init(route:))
    }

    private var topBarSources: [RSSSource] {
        if let demoState {
            return demoState.coreSources
        }
        if loadsLiveSubscriptions, !viewModel.subscriptions.isEmpty {
            return viewModel.subscriptions
        }
        return RSSDemoRouteState(route: "rss").coreSources
    }

    @ViewBuilder
    private var stateSection: some View {
        switch viewModel.feedState {
        case .idle:
            RSSStateCard(icon: .rss, title: "未加载", subtitle: "输入或选择订阅源后刷新。")
        case .loading:
            RSSStateCard(icon: .refresh, title: "刷新中...", subtitle: "RSSUIState.loading 已映射到状态卡。")
        case .loaded(let summary):
            summarySection(summary)
            itemSection(summary)
        case .empty(let summary):
            summarySection(summary)
            RSSStateCard(icon: .folderOff, title: "没有订阅条目", subtitle: "\(summary.source.name ?? summary.source.url) 暂无新条目。")
        case .failed(let message):
            RSSStateCard(icon: .warning, title: "解析失败", subtitle: message)
        }
    }

    private func summarySection(_ summary: CoreRSSFeedSummary) -> some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                Text("解析结果")
                    .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                DemoIconRow(icon: .rss, title: "格式", subtitle: summary.source.name ?? summary.source.url, detail: summary.format.rawValue.uppercased())
                DemoIconRow(icon: .list, title: "条目", subtitle: "当前结果数量", detail: "\(summary.items.count)")
                if let nextPageURL = summary.nextPageURL {
                    DemoIconRow(icon: .link, title: "下一页", subtitle: nextPageURL, detail: "next")
                }
                ForEach(summary.diagnostics.prefix(3), id: \.self) { diagnostic in
                    Text(diagnostic)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }

    private func itemSection(_ summary: CoreRSSFeedSummary) -> some View {
        let items = summary.items
        let sourceTitle = summary.source.name ?? summary.source.url
        return VStack(alignment: .leading, spacing: 0) {
            Text("最新条目")
                .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .heavy))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .padding(.horizontal, ReaderDesignTokens.cardPadding)
                .padding(.top, ReaderDesignTokens.cardPadding)

            ForEach(items, id: \.link) { item in
                NavigationLink {
                    RSSArticleDetailView(item: item, sourceTitle: sourceTitle)
                } label: {
                    RSSArticleRow(item: item)
                }
                .buttonStyle(.plain)
                if item.link != items.last?.link {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                }
            }
        }
        .backgroundCard()
    }

    private var statusText: String {
        if let demoState {
            return demoState.statusText
        }
        if !loadsLiveSubscriptions {
            return "10:18 更新"
        }

        switch viewModel.feedState {
        case .idle:
            return "未加载"
        case .loading:
            return "刷新中"
        case .loaded(let summary):
            return "\(summary.items.count) 条"
        case .empty:
            return "空结果"
        case .failed:
            return "失败"
        }
    }

    private var currentItemCount: Int {
        if let demoState {
            return demoState.articles.count
        }
        if !loadsLiveSubscriptions {
            return RSSDemoRouteState(route: "rss").articles.count
        }

        switch viewModel.feedState {
        case .loaded(let summary), .empty(let summary):
            return summary.items.count
        case .idle, .loading, .failed:
            return 0
        }
    }

    private var isRSSActionDisabled: Bool {
        guard loadsLiveSubscriptions else { return false }
        return viewModel.feedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func selectDemoRoute(_ route: String) {
        if route == "rss" {
            activeDemoRoute = nil
            selectedMode = "源列表"
        } else {
            activeDemoRoute = route
            selectedMode = RSSDemoRouteState.selectedMode(for: route)
        }
    }

    private func refreshCurrentFeed() {
        guard loadsLiveSubscriptions else {
            activeDemoRoute = "rss-refreshing"
            selectedMode = RSSDemoRouteState(route: "rss-refreshing").selectedMode
            return
        }
        Task { await viewModel.refresh() }
    }

    private func handleTopBarRequest(_ request: MainTabTopBarRequest?) {
        switch request {
        case .rssRefresh:
            refreshCurrentFeed()
            topBarRequest = nil
        case .rssManage:
            showSubscriptionManagement = true
            topBarRequest = nil
        case .none, .bookshelfSearch, .bookshelfMore, .discoverRefresh:
            break
        }
    }

    private func saveCurrentSubscription() {
        guard loadsLiveSubscriptions else { return }
        Task { await viewModel.saveCurrentSubscription() }
    }
}

enum RSSDemoPresentation {
    case articleHub
    case sourceFeed
    case refreshing
}

struct RSSFeedDemoArticle: Hashable {
    let title: String
    let source: String
    let time: String
    let group: String
    let desc: String
    let unread: Bool
    let starred: Bool

    var item: SubscriptionItem {
        SubscriptionItem(
            title: title,
            link: "https://example.com/rss/\(title.hashValue.magnitude)",
            author: "\(source) · \(time) · \(group)",
            summary: desc,
            publishedAt: Date(timeIntervalSince1970: 1_800_000_000),
            sourceId: source,
            sourceName: source
        )
    }
}

struct RSSDemoCategory: Hashable {
    let label: String
    let route: String
    let title: String
    let meta: String
}

struct RSSDemoRouteState {
    let route: String
    let presentation: RSSDemoPresentation
    let navigationTitle: String
    let selectedMode: String
    let statusText: String
    let source: RSSManagementSource
    let category: RSSDemoCategory
    let articles: [SubscriptionItem]
    let showsRefreshingLine: Bool

    init(route: String) {
        let normalizedRoute = route.isEmpty ? "rss-all" : route
        let source = RSSManagementSource.demoSources[0]
        let category = RSSDemoRouteState.category(for: normalizedRoute)
        let sourceRoutes = normalizedRoute == "rss-source-feed" || normalizedRoute.hasPrefix("rss-source-category-")
        let refreshing = normalizedRoute == "rss-refreshing"

        self.route = normalizedRoute
        self.source = source
        self.category = category
        self.presentation = refreshing ? .refreshing : (sourceRoutes ? .sourceFeed : .articleHub)
        self.navigationTitle = RSSDemoRouteState.title(for: normalizedRoute, category: category)
        self.selectedMode = RSSDemoRouteState.selectedMode(for: normalizedRoute)
        self.statusText = refreshing ? "刷新中" : "10:18 更新"
        self.showsRefreshingLine = refreshing
        self.articles = RSSDemoRouteState.filteredArticles(for: normalizedRoute).map(\.item)
    }

    var feedURL: String {
        "https://example.com/rss/\(source.id).xml"
    }

    var selectedSourceURL: String {
        feedURL
    }

    var coreSources: [RSSSource] {
        RSSManagementSource.demoSources.map { source in
            RSSSource(
                url: "https://example.com/rss/\(source.id).xml",
                name: source.name,
                lastFetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
                enabled: source.enabled,
                sourceGroup: source.group,
                loginUrl: source.loginRequired ? "https://example.com/login" : nil,
                sortUrl: source.categories > 1 ? "releases::issues::discussions" : nil,
                singleUrl: source.singleURL,
                articleStyle: source.articleStyle == "图文" ? 1 : 0,
                ruleContent: source.rule == "正文规则" ? ".article" : nil,
                enableJs: false
            )
        }
    }

    var feedState: RSSFeedState {
        if showsRefreshingLine {
            return .loading
        }
        return .loaded(summary: summary)
    }

    private var summary: CoreRSSFeedSummary {
        CoreRSSFeedSummary(
            source: RSSSource(
                url: feedURL,
                name: source.name,
                lastFetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
                sourceGroup: source.group,
                sortUrl: "releases::issues::discussions",
                enableJs: false
            ),
            format: ReaderCoreFeedFormat.rss,
            items: articles,
            nextPageURL: "https://example.com/rss/\(source.id)?page=2",
            diagnostics: ["demo route: \(route)", "source: \(source.name)", "category: \(category.label)"]
        )
    }

    private static let categories: [RSSDemoCategory] = [
        RSSDemoCategory(label: "全部", route: "rss-source-feed", title: "GitHub Releases", meta: "默认 RSS 解析 · 18 条"),
        RSSDemoCategory(label: "Releases", route: "rss-source-category-releases", title: "Releases", meta: "版本发布 · 8 条"),
        RSSDemoCategory(label: "Issues", route: "rss-source-category-issues", title: "Issues", meta: "问题讨论 · 6 条"),
        RSSDemoCategory(label: "Discussions", route: "rss-source-category-discussions", title: "Discussions", meta: "社区讨论 · 4 条")
    ]

    private static let demoArticles: [RSSFeedDemoArticle] = [
        RSSFeedDemoArticle(
            title: "Reader UI 前端输入件更新说明",
            source: "GitHub Releases",
            time: "10:18",
            group: "开源项目",
            desc: "新增发现页状态路由、阅读控制层响应式约束，并补充 RSS 页面结构规划。",
            unread: true,
            starred: true
        ),
        RSSFeedDemoArticle(
            title: "订阅源规则解析失败排查",
            source: "书源维护公告",
            time: "09:52",
            group: "维护",
            desc: "部分订阅源返回 HTML 而不是 XML，已建议检查 Cookie、登录态和正文提取规则。",
            unread: true,
            starred: false
        ),
        RSSFeedDemoArticle(
            title: "Legado 订阅源配置经验整理",
            source: "阅读器版本讨论",
            time: "昨天",
            group: "社区",
            desc: "社区整理了单 URL 源、分类入口、文章样式和 WebView 正文处理的常见配置方式。",
            unread: true,
            starred: false
        ),
        RSSFeedDemoArticle(
            title: "本地导入完成解析",
            source: "本地系统通知",
            time: "周二",
            group: "系统",
            desc: "本地 OPML 导入完成，4 个订阅源已启用，1 个订阅源需要补全图标。",
            unread: false,
            starred: false
        ),
        RSSFeedDemoArticle(
            title: "阅读器路线图讨论摘要",
            source: "阅读器版本讨论",
            time: "周一",
            group: "社区",
            desc: "围绕 RSS 收藏、源分组、正文阅读和同步备份的交互关系做了讨论。",
            unread: false,
            starred: true
        )
    ]

    private static func filteredArticles(for route: String) -> [RSSFeedDemoArticle] {
        if route == "rss-all" {
            return demoArticles
        }
        if route == "rss-starred" {
            return demoArticles.filter(\.starred)
        }
        if route == "rss-source-feed" || route.hasPrefix("rss-source-category-") {
            return demoArticles.filter { $0.source == "GitHub Releases" }
        }
        return demoArticles.filter(\.unread)
    }

    private static func category(for route: String) -> RSSDemoCategory {
        categories.first { $0.route == route } ?? categories[0]
    }

    private static func title(for route: String, category: RSSDemoCategory) -> String {
        if route == "rss-refreshing" {
            return "刷新订阅"
        }
        if route == "rss-all" {
            return "全部条目"
        }
        if route == "rss-starred" {
            return "收藏"
        }
        if route == "rss-source-feed" || route.hasPrefix("rss-source-category-") {
            return category.title
        }
        return "未读"
    }

    static func selectedMode(for route: String) -> String {
        if route == "rss" {
            return "源列表"
        }
        if route == "rss-all" {
            return "全部"
        }
        if route == "rss-starred" {
            return "收藏"
        }
        if route == "rss-rule-subscription" {
            return "规则订阅"
        }
        if route == "rss-source-feed" || route.hasPrefix("rss-source-category-") {
            return "源列表"
        }
        return "源列表"
    }
}

private struct RSSDemoHomeContent: View {
    @Binding var selectedMode: String
    @Binding var activeGroupFilter: String
    @Binding var isGroupFilterOpen: Bool
    let onSelectRoute: (String) -> Void

    private var state: RSSDemoRouteState {
        RSSDemoRouteState(route: "rss")
    }

    var body: some View {
        NavigationLink {
            RSSSearchView()
        } label: {
            RSSDemoSearchEntry()
        }
        .buttonStyle(.plain)

        RSSModeRow(selectedMode: $selectedMode, onSelectRoute: onSelectRoute)

        RSSDemoSourceOverview(
            activeFilter: $activeGroupFilter,
            isFilterOpen: $isGroupFilterOpen
        )

        RSSFeedDemoArticleSection(
            title: "最近未读",
            articles: Array(state.articles.prefix(3)),
            actionLabel: "查看全部",
            actionIcon: .list
        )
    }
}

private struct RSSDemoRouteContent: View {
    let state: RSSDemoRouteState
    @Binding var selectedMode: String
    @Binding var activeGroupFilter: String
    @Binding var isGroupFilterOpen: Bool
    @Binding var isCategoryFilterOpen: Bool
    let onSelectRoute: (String) -> Void

    var body: some View {
        switch state.presentation {
        case .articleHub:
            NavigationLink {
                RSSSearchView()
            } label: {
                RSSDemoSearchEntry()
            }
            .buttonStyle(.plain)
            RSSModeRow(selectedMode: $selectedMode, onSelectRoute: onSelectRoute)
            RSSDemoSourceStrip(activeSourceID: state.source.id)
            RSSFeedDemoArticleSection(
                title: state.navigationTitle,
                articles: state.articles,
                actionLabel: "管理源",
                actionIcon: .sourceStack
            )
        case .refreshing:
            NavigationLink {
                RSSSearchView()
            } label: {
                RSSDemoSearchEntry()
            }
            .buttonStyle(.plain)
            RSSModeRow(selectedMode: $selectedMode, onSelectRoute: onSelectRoute)
            RSSDemoRefreshLine(message: "正在刷新启用订阅源和分类入口")
            RSSDemoSourceOverview(
                activeFilter: $activeGroupFilter,
                isFilterOpen: $isGroupFilterOpen
            )
            RSSFeedDemoArticleSection(
                title: "最近未读",
                articles: state.articles,
                actionLabel: "查看全部",
                actionIcon: .list
            )
        case .sourceFeed:
            RSSDemoSourceHero(state: state)
            RSSDemoSourceToolbar()
            RSSDemoCategoryFilter(
                activeRoute: state.category.route,
                isOpen: $isCategoryFilterOpen,
                onSelectRoute: onSelectRoute
            )
            RSSFeedDemoArticleSection(
                title: state.category.title,
                articles: state.articles,
                actionLabel: "源操作",
                actionIcon: .more
            )
            RSSDemoBottomLoading()
        }
    }
}

struct RSSRootTopBar: View {
    let subscriptionCount: Int
    let statusText: String
    let sources: [RSSSource]
    let onRefresh: () -> Void
    let onManage: () -> Void
    let isRefreshDisabled: Bool

    var body: some View {
        HStack(spacing: ReaderDesignTokens.rssTopBarGap) {
            Text("RSS")
                .font(ReaderTypography.demoSerif(size: ReaderDesignTokens.topBarTitleFontSize, weight: .bold))
                .lineLimit(1)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)

            Spacer(minLength: 0)

            Button(action: onRefresh) {
                HStack(spacing: ReaderDesignTokens.rssTopRefreshGap) {
                    Circle()
                        .fill(ReaderDesignTokens.Color.primary)
                        .frame(
                            width: ReaderDesignTokens.rssTopRefreshDotSize,
                            height: ReaderDesignTokens.rssTopRefreshDotSize
                        )
                        .shadow(color: ReaderDesignTokens.Color.primary.opacity(0.16), radius: 4)

                    HStack(spacing: 4) {
                        Text("\(subscriptionCount) 个启用源")
                            .lineLimit(1)
                        Text("· \(statusText)")
                            .lineLimit(1)
                    }
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .minimumScaleFactor(0.78)

                    ReaderIcon(.refresh, size: 18, accessibilityLabel: "刷新当前订阅")
                        .frame(width: 18, height: 18)
                }
                .padding(.horizontal, 10)
                .frame(minHeight: ReaderDesignTokens.rssTopActionMinHeight)
                .background(
                    Capsule()
                        .fill(ReaderDesignTokens.Color.surface.opacity(0.86))
                        .overlay(
                            Capsule()
                                .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(isRefreshDisabled)
            .accessibilityLabel("刷新当前订阅")

            Button(action: onManage) {
                HStack(spacing: 4) {
                    ReaderIcon(.list, size: 16, accessibilityLabel: "管理 RSS 订阅")
                    Text("管理")
                        .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .heavy))
                }
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .padding(.horizontal, 8)
                .frame(minWidth: ReaderDesignTokens.rssTopManageMinWidth)
                .frame(minHeight: ReaderDesignTokens.rssTopActionMinHeight)
                .background(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                        .fill(ReaderDesignTokens.Color.surface.opacity(0.86))
                        .overlay(
                            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                                .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("管理 RSS 订阅")
        }
        .padding(.horizontal, ReaderDesignTokens.topBarHorizontalPadding)
        .padding(.top, ReaderDesignTokens.topBarTopPadding)
        .frame(minHeight: ReaderDesignTokens.topBarMinHeight)
        .background(ReaderDesignTokens.Color.paperSolid)
    }
}

private struct RSSModeRow: View {
    @Binding var selectedMode: String
    let onSelectRoute: (String) -> Void
    private let modes = [
        ("源列表", "rss"),
        ("全部", "rss-all"),
        ("收藏", "rss-starred"),
        ("规则订阅", "rss-rule-subscription")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ReaderDesignTokens.rssModeRowGap) {
                ForEach(modes, id: \.0) { mode in
                    PillChip(mode.0, isSelected: selectedMode == mode.0) {
                        selectedMode = mode.0
                        onSelectRoute(mode.1)
                    }
                    .frame(minHeight: ReaderDesignTokens.rssModeRowMinHeight)
                }
            }
        }
    }
}

private struct RSSSourceStrip: View {
    let sources: [RSSSource]
    let selectedURL: String?
    let onSelect: (RSSSource) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ReaderDesignTokens.rssModeRowGap) {
                ForEach(sources, id: \.url) { source in
                    Button {
                        onSelect(source)
                    } label: {
                        HStack(spacing: 8) {
                            ReaderIcon(source.enabled ? .rss : .offline, size: 18)
                                .frame(width: ReaderDesignTokens.rssSourceStripIconColumn)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.name ?? source.url)
                                    .font(.system(size: 12, weight: .heavy))
                                    .lineLimit(1)
                                Text(source.lastFetchedAt.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .short) } ?? "未刷新")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .frame(width: ReaderDesignTokens.rssSourceStripItemWidth, alignment: .leading)
                        .frame(minHeight: ReaderDesignTokens.rssSourceStripMinHeight, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                                .fill(selectedURL == source.url ? ReaderDesignTokens.Color.primary.opacity(0.16) : ReaderDesignTokens.Color.surface)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct RSSDemoSearchEntry: View {
    var body: some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            ReaderIcon(.search, size: 18, accessibilityLabel: "RSS 搜索")
                .frame(width: ReaderDesignTokens.settingsRowIconColumn)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            Text("搜索订阅源、文章标题或分组")
                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssSearchEntryMinHeight, alignment: .leading)
        .backgroundCard(cornerRadius: ReaderDesignTokens.Radius.md)
    }
}

private struct RSSDemoSourceStrip: View {
    let activeSourceID: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ReaderDesignTokens.rssModeRowGap) {
                ForEach(RSSManagementSource.demoSources) { source in
                    HStack(spacing: 8) {
                        ReaderIcon(source.enabled ? .rss : .offline, size: 18)
                            .frame(width: ReaderDesignTokens.rssSourceStripIconColumn)
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.name)
                                .font(.system(size: 12, weight: .heavy))
                                .lineLimit(1)
                            Text("\(source.group) · \(source.unread > 0 ? "\(source.unread) 未读" : "无未读")")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(width: ReaderDesignTokens.rssSourceStripItemWidth, alignment: .leading)
                    .frame(minHeight: ReaderDesignTokens.rssSourceStripMinHeight, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                            .fill(activeSourceID == source.id ? ReaderDesignTokens.Color.primary.opacity(0.16) : ReaderDesignTokens.Color.surface)
                    )
                }
            }
        }
    }
}

private struct RSSDemoSourceHero: View {
    let state: RSSDemoRouteState

    var body: some View {
        HStack(spacing: ReaderDesignTokens.rssSummaryGap) {
            ReaderIcon(.rss, size: ReaderDesignTokens.rssOriginalHeaderIconSize, accessibilityLabel: state.source.name)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            VStack(alignment: .leading, spacing: 3) {
                Text(state.source.name)
                    .font(.system(size: 15, weight: .heavy))
                    .lineLimit(1)
                Text("\(state.source.group) · \(state.category.meta) · \(state.source.rule) · \(state.source.latest)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            RSSDemoStatusBadge(source: state.source)
        }
        .padding(ReaderDesignTokens.cardPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssOriginalHeaderMinHeight, alignment: .leading)
        .backgroundCard(cornerRadius: ReaderDesignTokens.Radius.md)
    }
}

private struct RSSDemoSourceToolbar: View {
    private let actions: [(ReaderAssetIcon, String)] = [
        (.refresh, "刷新"),
        (.edit, "编辑源"),
        (.clock, "记录"),
        (.bug, "调试")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ReaderDesignTokens.rssModeRowGap) {
                ForEach(actions, id: \.1) { action in
                    LabelChip(icon: action.0, title: action.1)
                }
            }
        }
    }
}

private struct RSSDemoCategoryFilter: View {
    let activeRoute: String
    @Binding var isOpen: Bool
    let onSelectRoute: (String) -> Void

    private let categories = [
        RSSDemoCategory(label: "全部", route: "rss-source-feed", title: "GitHub Releases", meta: "默认 RSS 解析 · 18 条"),
        RSSDemoCategory(label: "Releases", route: "rss-source-category-releases", title: "Releases", meta: "版本发布 · 8 条"),
        RSSDemoCategory(label: "Issues", route: "rss-source-category-issues", title: "Issues", meta: "问题讨论 · 6 条"),
        RSSDemoCategory(label: "Discussions", route: "rss-source-category-discussions", title: "Discussions", meta: "社区讨论 · 4 条")
    ]

    var body: some View {
        DemoFilterDisclosure(
            label: "分类",
            summary: categories.first(where: { $0.route == activeRoute })?.label ?? "全部",
            accessibilityLabel: "RSS 分类入口",
            isOpen: $isOpen,
            groups: [
                DemoFilterGroup(
                    title: "分类入口",
                    options: categories.map { category in
                        DemoFilterOption(
                            label: category.label,
                            isActive: category.route == activeRoute,
                            action: { onSelectRoute(category.route) }
                        )
                    }
                )
            ]
        )
    }
}

private struct RSSDemoSourceOverview: View {
    @Binding var activeFilter: String
    @Binding var isFilterOpen: Bool

    private let filters = ["全部", "开源项目", "社区", "需登录", "暂停"]

    private var visibleSources: [RSSManagementSource] {
        RSSManagementSource.demoSources.filter { source in
            switch activeFilter {
            case "全部":
                return true
            case "需登录":
                return source.loginRequired
            case "暂停":
                return !source.enabled
            default:
                return source.group == activeFilter
            }
        }
    }

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                HStack {
                    Text("订阅源")
                        .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    Spacer(minLength: 0)
                    LabelChip(icon: .upload, title: "导入")
                    LabelChip(icon: .add, title: "新建")
                }

                DemoFilterDisclosure(
                    label: "筛选",
                    summary: activeFilter,
                    accessibilityLabel: "RSS 订阅源筛选",
                    isOpen: $isFilterOpen,
                    groups: [
                        DemoFilterGroup(
                            title: "分组与状态",
                            options: filters.map { filter in
                                DemoFilterOption(
                                    label: filter,
                                    isActive: activeFilter == filter,
                                    action: { activeFilter = filter }
                                )
                            }
                        )
                    ]
                )

                ForEach(visibleSources) { source in
                    HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                        ReaderIcon(source.enabled ? .rss : .offline, size: 18)
                            .frame(width: ReaderDesignTokens.settingsRowIconColumn)
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(source.name)
                                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                                .lineLimit(1)
                            Text(source.sourceMeta)
                                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(source.unread > 0 ? "\(source.unread)" : "0")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.secondary)
                        RSSDemoStatusBadge(source: source)
                    }
                    .frame(minHeight: ReaderDesignTokens.rssSourceListRowMinHeight)
                }
            }
        }
    }
}

private struct RSSFeedDemoArticleSection: View {
    let title: String
    let articles: [SubscriptionItem]
    let actionLabel: String
    let actionIcon: ReaderAssetIcon

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .lineLimit(1)
                Spacer(minLength: 0)
                LabelChip(icon: actionIcon, title: actionLabel)
            }
            .padding(.horizontal, ReaderDesignTokens.cardPadding)
            .padding(.top, ReaderDesignTokens.cardPadding)
            .padding(.bottom, 4)

            ForEach(articles, id: \.link) { item in
                RSSArticleRow(item: item)
                if item.link != articles.last?.link {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                }
            }
        }
        .backgroundCard()
    }
}

private struct RSSDemoRefreshLine: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.78)
            Text(message)
                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .heavy))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .backgroundCard(cornerRadius: ReaderDesignTokens.Radius.md)
    }
}

private struct RSSDemoBottomLoading: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.72)
            Text("继续下滑加载下一页")
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .heavy))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 34)
    }
}

private struct RSSDemoStatusBadge: View {
    let source: RSSManagementSource

    var body: some View {
        Text(source.status)
            .font(.system(size: 10, weight: .heavy))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(minHeight: 24)
            .background(Capsule().fill(backgroundColor))
            .foregroundColor(foregroundColor)
    }

    private var backgroundColor: SwiftUI.Color {
        switch source.tone {
        case .good:
            return SwiftUI.Color(red: 74/255, green: 149/255, blue: 96/255, opacity: 0.12)
        case .warn:
            return SwiftUI.Color(red: 209/255, green: 147/255, blue: 47/255, opacity: 0.14)
        case .muted:
            return SwiftUI.Color(red: 180/255, green: 166/255, blue: 151/255, opacity: 0.16)
        }
    }

    private var foregroundColor: SwiftUI.Color {
        switch source.tone {
        case .good:
            return SwiftUI.Color(red: 47/255, green: 138/255, blue: 80/255)
        case .warn:
            return SwiftUI.Color(red: 154/255, green: 104/255, blue: 23/255)
        case .muted:
            return .secondary
        }
    }
}

private struct LabelChip: View {
    let icon: ReaderAssetIcon
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            ReaderIcon(icon, size: 13, accessibilityLabel: title)
            Text(title)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .heavy))
        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        .padding(.horizontal, 10)
        .frame(minHeight: 30)
        .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
    }
}

private struct RSSSearchEntry: View {
    @Binding var feedURL: String
    @Binding var feedName: String

    var body: some View {
        VStack(spacing: ReaderDesignTokens.settingsSectionGap) {
            HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(.search, size: 18)
                    .frame(width: ReaderDesignTokens.settingsRowIconColumn)
                feedURLField
            }
            .frame(minHeight: ReaderDesignTokens.rssSearchEntryMinHeight)

            HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(.edit, size: 18)
                    .frame(width: ReaderDesignTokens.settingsRowIconColumn)
                TextField("Name", text: $feedName)
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize))
                    .textFieldStyle(.plain)
            }
            .frame(minHeight: ReaderDesignTokens.settingsInputHeight)
        }
    }

    @ViewBuilder
    private var feedURLField: some View {
        #if os(iOS)
        TextField("Feed URL", text: $feedURL)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize))
            .textFieldStyle(.plain)
        #else
        TextField("Feed URL", text: $feedURL)
            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize))
            .textFieldStyle(.plain)
        #endif
    }
}

private struct RSSArticleRow: View {
    let item: SubscriptionItem

    var body: some View {
        HStack(alignment: .top, spacing: ReaderDesignTokens.rssArticleRowGap) {
            Circle()
                .fill(ReaderDesignTokens.Color.rssDotRead)
                .frame(width: ReaderDesignTokens.rssArticleRowDotSize, height: ReaderDesignTokens.rssArticleRowDotSize)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: ReaderDesignTokens.rssArticleRowTitleFontSize, weight: .bold))
                    .lineLimit(2)
                if let author = item.author, !author.isEmpty {
                    Text(author)
                        .font(.system(size: ReaderDesignTokens.rssArticleRowSmallFontSize))
                        .foregroundStyle(.secondary)
                }
                if let summary = item.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: ReaderDesignTokens.rssArticleRowBodyFontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(ReaderDesignTokens.rssArticleRowBodyLineLimit)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ReaderIcon(.chevron, size: 12)
                .frame(width: ReaderDesignTokens.rssArticleRowChevronColumn)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, ReaderDesignTokens.rssArticleRowVerticalPadding)
        .padding(.horizontal, ReaderDesignTokens.rssArticleRowHorizontalPadding)
        .frame(minHeight: ReaderDesignTokens.rssArticleRowMinHeight, alignment: .top)
    }
}

private struct RSSStateCard: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String

    var body: some View {
        DemoIconRow(icon: icon, title: title, subtitle: subtitle, detail: nil)
            .backgroundCard()
    }
}

private extension View {
    func backgroundCard(cornerRadius: CGFloat = ReaderDesignTokens.Radius.lg) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(ReaderDesignTokens.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(ReaderDesignTokens.Color.mainNavBorder.opacity(0.72), lineWidth: 1)
                )
                .shadow(
                    color: SwiftUI.Color(red: 80/255, green: 67/255, blue: 52/255, opacity: 0.08),
                    radius: 12,
                    x: 0,
                    y: 8
                )
        )
    }
}
