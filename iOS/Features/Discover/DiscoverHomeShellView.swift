import SwiftUI

/// 发现 Tab Shell —— 对齐 demo `.fd-discover-*` 主 Tab feature states。
///
/// 真源：
/// - `Reader UI/frontend-demo-optimized/render-runtime.js` `discoverMainContent`
/// - `Reader UI/frontend-demo-optimized/styles/01-shell-layout.css` `.fd-discover-*`
///
/// 发现页的 30 条 demo routes 属于主 Tab 内 feature state，不扩展为二级 `Route`。
/// `demoRoute` 只用于把 demo contract 转成本地 SwiftUI 状态，生产入口仍由 Discover tab root 承载。
public struct DiscoverHomeShellView: View {
    @State private var activeDemoRoute: String
    @State private var selectedEntry: String
    @State private var selectedFilter: String
    @State private var selectedSort: String
    @State private var isControlPanelExpanded: Bool
    @State private var isFilterMenuOpen: Bool
    @Binding private var topBarRequest: MainTabTopBarRequest?
    private let showsTopBar: Bool

    public init(
        demoRoute: String = "discover",
        showsTopBar: Bool = true,
        topBarRequest: Binding<MainTabTopBarRequest?> = .constant(nil)
    ) {
        let state = DiscoverDemoState(route: demoRoute)
        self._activeDemoRoute = State(initialValue: demoRoute)
        self._selectedEntry = State(initialValue: state.activeEntry)
        self._selectedFilter = State(initialValue: state.activeFilter)
        self._selectedSort = State(initialValue: state.sort)
        self._isControlPanelExpanded = State(initialValue: state.isControlPanelExpanded)
        self._isFilterMenuOpen = State(initialValue: state.isSortOpen)
        self.showsTopBar = showsTopBar
        self._topBarRequest = topBarRequest
    }

    public var body: some View {
        let state = DiscoverDemoState(
            route: activeDemoRoute,
            selectedEntry: selectedEntry,
            selectedFilter: selectedFilter,
            selectedSort: selectedSort,
            isControlPanelExpanded: isControlPanelExpanded
        )

        VStack(spacing: 0) {
            if showsTopBar {
                discoverTopBar
            }

            DemoPaperScreen(bottomPadding: ReaderDesignTokens.mainTabContentBottomPadding) {
                switch state.presentation {
                case .empty:
                    DiscoverLargeStateCard(
                        icon: .sourceStack,
                        title: "当前没有启用发现的书源",
                        subtitle: "启用发现后，可以在这里浏览书源提供的排行榜、分类和书单。",
                        actions: ["去书源管理", "导入书源"]
                    )
                case .error:
                    DiscoverSourceBar(
                        sourceName: "优书网",
                        sourceMeta: "排行榜 · 解析失败",
                        isControlPanelExpanded: $isControlPanelExpanded
                    )
                    DiscoverLargeStateCard(
                        icon: .warning,
                        title: "发现入口解析失败",
                        subtitle: "当前入口返回异常，已保留上一批缓存结果。你可以重试、刷新入口、编辑源或切换书源。",
                        actions: ["重试", "切换书源", "编辑源"],
                        tone: .error
                    )
                    DiscoverBookList(books: state.books, isMuted: true)
                case .normal:
                    if state.showsCacheToast {
                        DiscoverToast(message: "已清除优书网发现缓存")
                    }

                    DiscoverSourceBar(
                        sourceName: state.sourceName,
                        sourceMeta: state.sourceMeta,
                        isControlPanelExpanded: $isControlPanelExpanded
                    )

                    if state.isControlPanelExpanded {
                        DiscoverControlPanel(
                            state: state,
                            selectedEntry: $selectedEntry,
                            selectedFilter: $selectedFilter,
                            selectedSort: $selectedSort
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        DiscoverEntryRow(entries: state.entries, selectedEntry: $selectedEntry)
                        DiscoverFilterRow(
                            selectedFilter: $selectedFilter,
                            selectedSort: $selectedSort,
                            isOpen: $isFilterMenuOpen,
                            onApply: {
                                activeDemoRoute = "discover-refreshing"
                                isFilterMenuOpen = false
                            }
                        )
                    }

                    if state.isRefreshing {
                        DiscoverRefreshLine(message: state.refreshMessage)
                    }

                    if state.presentation == .normal && state.showsNoResults {
                        DiscoverLargeStateCard(
                            icon: .search,
                            title: "当前条件没有发现结果",
                            subtitle: "可以重置筛选、切换入口，或刷新当前书源。",
                            actions: ["重置筛选", "切换入口", "刷新"]
                        )
                    } else {
                        DiscoverResultHeader(entry: state.activeEntry, total: state.total, sort: state.sort)
                        if state.isLoading {
                            DiscoverSkeletonList()
                        } else {
                            DiscoverBookList(books: state.books, isMuted: state.isMuted)
                        }
                        if state.isInfiniteLoading {
                            DiscoverBottomLoading()
                        }
                        if state.showsBackTop {
                            DiscoverBackTopButton()
                        }
                    }
                }
            }
        }
        // 对齐 web demo `discoverDialogHtml()`：确认卡片是 overlay（.fd-discover-dialog-backdrop +
        // .fd-discover-confirm-dialog），不是内联追加。用 ZStack overlay 在内容区上方渲染半透明遮罩
        // + 居中卡片，让背景列表仍可见但被压暗。
        .overlay {
            if state.showsCacheConfirm {
                DiscoverCacheConfirmOverlay()
            }
        }
        .background(ReaderDesignTokens.Color.paperSolidAlt.ignoresSafeArea())
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
        // NavigationStack 即使 `.toolbar(.hidden, for: .navigationBar)` 仍会预留 ~132pt 导航栏 safe area，
        // 把 DemoTopBar 推到 y≈132pt。当 DiscoverHomeShellView 自带 top bar（测试/独立预览）时忽略顶部 safe area，
        // 让 top bar 回到 y≈6pt（对齐 web demo）。AppShellView 内嵌时 showsTopBar=false，safe area 由 shell 承载。
        .ignoresSafeArea(.container, edges: showsTopBar ? .top : [])
        .onChange(of: topBarRequest) { request in
            handleTopBarRequest(request)
        }
    }

    private var discoverTopBar: some View {
        DemoTopBar(title: "发现") {
            DemoTopActionButton(
                icon: .refresh,
                accessibilityLabel: "刷新发现入口",
                action: refreshDiscoverEntry
            )
        }
    }

    private func handleTopBarRequest(_ request: MainTabTopBarRequest?) {
        guard request == .discoverRefresh else { return }
        refreshDiscoverEntry()
        topBarRequest = nil
    }

    private func refreshDiscoverEntry() {
        activeDemoRoute = "discover-refreshing"
    }
}

struct DiscoverSourceLoginView: View {
    @State private var cookieSaved = true
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    var body: some View {
        DemoBackScreen(title: "书源登录") {
            ReaderCard {
                HStack(spacing: ReaderDesignTokens.rssSummaryGap) {
                    ReaderIcon(.shield, size: ReaderDesignTokens.rssOriginalHeaderIconSize, accessibilityLabel: "书源登录")
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("轻小说文库")
                            .font(.system(size: ReaderDesignTokens.rssOriginalWebPreviewTitleFontSize, weight: .heavy))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                            .lineLimit(1)
                        Text("该书源的发现入口需要登录态，登录后返回当前入口并刷新列表。")
                            .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: ReaderDesignTokens.rssOriginalHeaderMinHeight, alignment: .leading)
            }

            ReaderCard {
                VStack(spacing: 0) {
                    DemoIconRow(icon: .warning, title: "登录状态", subtitle: "未登录 · 最近检测 10:32", detail: "需登录")
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                    DemoIconRow(icon: .sourceStack, title: "适用范围", subtitle: "发现入口、详情页、目录页", detail: "当前源")
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                    DemoToggleRow(
                        icon: .storage,
                        title: "Cookie 保存",
                        subtitle: "仅保存在本机书源配置中",
                        onDetail: "已保存",
                        offDetail: "关闭",
                        isOn: $cookieSaved
                    )
                }
            }

            ReaderCard {
                VStack(spacing: ReaderDesignTokens.rssModeRowGap) {
                    DiscoverLoginAction(icon: .globe, title: "打开网页登录", isPrimary: true)
                    DiscoverLoginAction(icon: .check, title: "保存登录信息", isPrimary: false)
                    DiscoverLoginAction(icon: .refresh, title: "重新检测", isPrimary: false)
                }
            }

            Text("返回发现页后，当前书源和当前入口保持不变，只刷新内容列表。")
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        } bottomActionHost: {
            BottomFixedActionRow {
                DiscoverLoginBottomButton(title: "返回控制层", icon: .sourceStack, isPrimary: false) {
                    dismiss()
                }
            } trailing: {
                DiscoverLoginBottomButton(title: "完成刷新", icon: .refresh, isPrimary: true) {
                    dismiss()
                }
            }
        }
    }
}

private struct DiscoverLoginAction: View {
    let icon: ReaderAssetIcon
    let title: String
    let isPrimary: Bool

    var body: some View {
        HStack(spacing: 7) {
            ReaderIcon(icon, size: 16, accessibilityLabel: title)
            Text(title)
                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundColor(isPrimary ? .white : ReaderDesignTokens.Color.primaryDark)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .background(
            Capsule()
                .fill(isPrimary ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.chipBackground)
        )
    }
}

private struct DiscoverLoginBottomButton: View {
    let title: String
    let icon: ReaderAssetIcon
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ReaderIcon(icon, size: 14, accessibilityLabel: title)
                Text(title)
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                    .lineLimit(1)
            }
            .foregroundColor(isPrimary ? .white : ReaderDesignTokens.Color.primaryDark)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
            .background(
                Capsule()
                    .fill(isPrimary ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.surface)
            )
        }
        .buttonStyle(DemoPressButtonStyle())
    }
}

private enum DiscoverPresentation: Hashable {
    case normal
    case empty
    case error
}

private struct DiscoverDemoState: Hashable {
    let route: String
    let sourceName: String
    let sourceMeta: String
    let entries: [String]
    let activeEntry: String
    let activeFilter: String
    let sort: String
    let total: Int
    let isSortOpen: Bool
    let isControlPanelExpanded: Bool
    let isLoading: Bool
    let isRefreshing: Bool
    let isInfiniteLoading: Bool
    let isMuted: Bool
    let showsNoResults: Bool
    let showsBackTop: Bool
    let showsCacheConfirm: Bool
    let showsCacheToast: Bool
    let entryError: Bool
    let presentation: DiscoverPresentation
    let books: [DiscoverBook]

    init(
        route: String,
        selectedEntry: String? = nil,
        selectedFilter: String? = nil,
        selectedSort: String? = nil,
        isControlPanelExpanded expandedOverride: Bool? = nil
    ) {
        let entryRouteMap = [
            "discover-entry-ranking": "排行榜",
            "discover-entry-bestseller": "畅销",
            "discover-entry-category": "分类",
            "discover-entry-finished": "完本",
            "discover-entry-latest": "最新",
            "discover-entry-new": "新书",
            "discover-entry-booklist": "书单"
        ]
        let filterRouteMap = [
            "discover-filter-keyword": "关键词",
            "discover-filter-male": "男频",
            "discover-filter-female": "女频"
        ]
        let sortRouteMap = [
            "discover-sort-popularity": "人气",
            "discover-sort-update": "更新",
            "discover-sort-collection": "收藏",
            "discover-sort-finished": "完本",
            "discover-sort-words": "字数"
        ]
        let switched = route == "discover-switched-source"
        let entries = switched ? ["畅销", "分类", "新书", "完本"] : ["排行榜", "分类", "完本", "最新", "书单"]
        let routedEntry = entryRouteMap[route]
        let resolvedEntry = routedEntry.flatMap { entries.contains($0) ? $0 : nil }
            ?? selectedEntry.flatMap { entries.contains($0) ? $0 : nil }
            ?? entries[0]
        let resolvedFilter = filterRouteMap[route] ?? selectedFilter ?? "男频"
        let resolvedSort = sortRouteMap[route] ?? selectedSort ?? (switched ? "更新" : "人气")
        let totalByRoute = [
            "discover-entry-category": 32,
            "discover-entry-finished": 21,
            "discover-entry-latest": 27,
            "discover-entry-booklist": 14,
            "discover-filter-keyword": 9,
            "discover-filter-female": 16,
            "discover-sort-update": 25,
            "discover-sort-collection": 19,
            "discover-sort-finished": 21,
            "discover-sort-words": 23
        ]
        let totalBySort = [
            "更新": 25,
            "收藏": 19,
            "完本": 21,
            "字数": 23
        ]
        let routeExpanded = ["discover-control", "discover-cache-confirm", "discover-switching-source", "discover-entry-error"].contains(route)
        let presentation: DiscoverPresentation
        if route == "discover-empty" {
            presentation = .empty
        } else if route == "discover-error" {
            presentation = .error
        } else {
            presentation = .normal
        }

        self.route = route
        self.sourceName = switched ? "起点导入" : "优书网"
        self.sourceMeta = switched ? "正版 · 已启用发现 · 180ms" : "默认分组 · 已启用发现 · 120ms"
        self.entries = entries
        self.activeEntry = resolvedEntry
        self.activeFilter = resolvedFilter
        self.sort = resolvedSort
        self.total = switched ? 24 : route == "discover-page-two" ? 38 : totalByRoute[route] ?? totalBySort[resolvedSort] ?? 18
        self.isSortOpen = route == "discover-sort"
        self.isControlPanelExpanded = expandedOverride ?? routeExpanded
        self.isLoading = route == "discover-loading"
        self.isRefreshing = route == "discover-refreshing" || route == "discover-login-return"
        self.isInfiniteLoading = route == "discover-infinite-loading"
        self.isMuted = route == "discover-switching-source" || route == "discover-entry-error"
        self.showsNoResults = route == "discover-no-results"
        self.showsBackTop = route == "discover-page-two"
        self.showsCacheConfirm = route == "discover-cache-confirm"
        self.showsCacheToast = route == "discover-cache-toast"
        self.entryError = route == "discover-entry-error"
        self.presentation = presentation
        self.books = DiscoverDemoState.books(route: route)
    }

    var refreshMessage: String {
        route == "discover-login-return" ? "登录成功，正在刷新当前发现入口" : "正在刷新当前列表"
    }

    private static func books(route: String) -> [DiscoverBook] {
        let switched = route == "discover-switched-source"
        let base: [DiscoverBook] = switched ? [
            DiscoverBook(title: "诡秘之主", author: "爱潜水的乌贼", kind: "奇幻 · 完本", latest: "最新：番外已整理", summary: "克莱恩在迷雾中醒来，新的线索沿着塔罗会延伸。", inShelf: true),
            DiscoverBook(title: "纸上城市", author: "默认分组", kind: "都市 · 连载", latest: "最新：第 18 章", summary: "城市被写在纸页上，所有路口都藏着旧书源的暗号。", inShelf: false),
            DiscoverBook(title: "灯塔与雾", author: "书源同步", kind: "悬疑 · 连载", latest: "最新：第 51 章", summary: "雾气吞没海岸线，灯塔的记录仍在夜里闪烁。", inShelf: false),
            DiscoverBook(title: "群星之间", author: "本地导入", kind: "科幻 · 连载", latest: "最新：第 12 章", summary: "星舰穿过静默航道，旧文明的坐标重新亮起。", inShelf: true)
        ] : [
            DiscoverBook(title: "长夜余火", author: "爱潜水的乌贼", kind: "科幻 · 连载", latest: "最新：第 32 章 雨夜", summary: "雨声在窗外连成一片，旧世界的线索在夜里慢慢浮出。", inShelf: true),
            DiscoverBook(title: "诡秘之主", author: "爱潜水的乌贼", kind: "奇幻 · 完本", latest: "最新：番外已整理", summary: "蒸汽、塔罗与旧日秘密交织，适合继续追读。", inShelf: true),
            DiscoverBook(title: "三体", author: "刘慈欣", kind: "科幻 · 完本", latest: "最新：三部曲合集", summary: "文明在宇宙暗处相互凝视，微小选择带来巨大回声。", inShelf: false),
            DiscoverBook(title: "明朝那些事儿", author: "当年明月", kind: "历史 · 完本", latest: "最新：全集校对", summary: "用更轻松的方式重新翻开明朝人物与权力线索。", inShelf: false),
            DiscoverBook(title: "纸上城市", author: "默认分组", kind: "都市 · 连载", latest: "最新：第 12 章", summary: "纸页边缘折起，城市的名字开始变化。", inShelf: false)
        ]
        if route == "discover-page-two" || route == "discover-infinite-loading" {
            return base + [
                DiscoverBook(title: "旧日回响", author: "离线书库", kind: "奇幻 · 连载", latest: "最新：第 18 章", summary: "旧日钟声从废墟里传回，缓存章节仍可打开。", inShelf: false)
            ]
        }
        return base
    }
}

private struct DiscoverBook: Hashable {
    let title: String
    let author: String
    let kind: String
    let latest: String
    let summary: String
    let inShelf: Bool
}

private struct DiscoverSourceBar: View {
    let sourceName: String
    let sourceMeta: String
    @Binding var isControlPanelExpanded: Bool
    private let motion = MotionEnvironment()

    var body: some View {
        Button {
            let duration = isControlPanelExpanded ? AppMotion.Duration.dropdownCollapse : AppMotion.Duration.dropdownExpand
            motion.withMotionAnimation(duration) {
                isControlPanelExpanded.toggle()
            }
        } label: {
            HStack(spacing: ReaderDesignTokens.discoverSourceGap) {
                ReaderIcon(.sourceStack, size: 22, accessibilityLabel: "当前书源")
                    .frame(width: ReaderDesignTokens.discoverSourceIconColumn)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                VStack(alignment: .leading, spacing: 3) {
                    Text(sourceName)
                        .font(.system(size: ReaderDesignTokens.discoverBookRowTitleFontSize, weight: .heavy))
                        .lineLimit(1)
                    Text(sourceMeta)
                        .font(.system(size: ReaderDesignTokens.discoverBookRowSmallFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ReaderIcon(.chevron, size: 14)
                    .frame(width: ReaderDesignTokens.discoverSourceChevronColumn)
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .rotationEffect(.degrees(isControlPanelExpanded ? 90 : 0))
                    .animation(
                        ReaderMotionAdapter.animation(
                            for: isControlPanelExpanded
                                ? MotionRequest(operation: .enter, targetRole: "dropdown", containerRole: .overlayHost)
                                : MotionRequest(operation: .exit, targetRole: "dropdown", containerRole: .overlayHost),
                            motion: motion
                        ),
                        value: isControlPanelExpanded
                    )
            }
            .padding(ReaderDesignTokens.discoverSourcePadding)
            .frame(minHeight: ReaderDesignTokens.discoverSourceBarMinHeight)
        }
        .buttonStyle(DemoPressButtonStyle())
        .backgroundCard()
    }
}

private struct DiscoverEntryRow: View {
    let entries: [String]
    @Binding var selectedEntry: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ReaderDesignTokens.discoverEntryRowGap) {
                ForEach(entries, id: \.self) { entry in
                    PillChip(entry, isSelected: selectedEntry == entry) {
                        selectedEntry = entry
                    }
                }
            }
        }
    }
}

private struct DiscoverFilterRow: View {
    @Binding var selectedFilter: String
    @Binding var selectedSort: String
    @Binding var isOpen: Bool
    let onApply: () -> Void
    private let filters = ["关键词", "男频", "女频"]
    private let sorts = ["人气", "更新", "收藏", "完本", "字数"]

    var body: some View {
        DemoFilterDisclosure(
            label: "筛选",
            summary: "\(selectedFilter) · \(selectedSort)",
            accessibilityLabel: "发现筛选与排序",
            applyTitle: "应用",
            isOpen: $isOpen,
            groups: [
                DemoFilterGroup(
                    title: "范围",
                    options: filters.map { filter in
                        DemoFilterOption(
                            label: filter,
                            icon: filter == "关键词" ? .search : nil,
                            isActive: selectedFilter == filter,
                            action: { selectedFilter = filter }
                        )
                    }
                ),
                DemoFilterGroup(
                    title: "排序",
                    options: sorts.map { sort in
                        DemoFilterOption(
                            label: sort,
                            isActive: selectedSort == sort,
                            action: { selectedSort = sort }
                        )
                    }
                )
            ],
            onApply: onApply
        )
    }
}

private struct DiscoverSortPopover: View {
    @Binding var selectedSort: String
    let sorts: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("排序方式")
                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 7)], alignment: .leading, spacing: 7) {
                ForEach(sorts, id: \.self) { sort in
                    PillChip(sort, isSelected: selectedSort == sort) {
                        selectedSort = sort
                    }
                }
            }
        }
        .padding(ReaderDesignTokens.cardPadding)
        .backgroundCard(cornerRadius: ReaderDesignTokens.Radius.md)
    }
}

private struct DiscoverControlPanel: View {
    let state: DiscoverDemoState
    @Binding var selectedEntry: String
    @Binding var selectedFilter: String
    @Binding var selectedSort: String

    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.discoverControlPanelGap) {
            DiscoverPanelSection(title: "当前书源") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 7)], alignment: .leading, spacing: 7) {
                    DiscoverSourceOption(title: "优书网", meta: "默认 · 120ms", isActive: state.sourceName == "优书网", tone: .good)
                    DiscoverSourceOption(title: "起点导入", meta: state.route == "discover-switching-source" ? "正在解析入口" : "正版 · 180ms", isActive: state.sourceName == "起点导入", tone: state.route == "discover-switching-source" ? .loading : .good)
                    DiscoverSourceOption(title: "轻小说文库", meta: "需登录", isActive: false, tone: .warn)
                    DiscoverSourceOption(title: "本地聚合源", meta: "维护中", isActive: false, tone: .muted)
                }
            }

            DiscoverPanelSection(title: "发现入口") {
                if state.entryError {
                    DiscoverInlineError()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ReaderDesignTokens.discoverEntryRowGap) {
                            ForEach(state.entries, id: \.self) { entry in
                                PillChip(entry, isSelected: selectedEntry == entry) {
                                    selectedEntry = entry
                                }
                            }
                        }
                    }
                }
            }

            DiscoverPanelSection(title: "筛选与排序") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ReaderDesignTokens.discoverEntryRowGap) {
                        ForEach(["关键词", "男频", "女频"], id: \.self) { filter in
                            PillChip(filter, isSelected: selectedFilter == filter) {
                                selectedFilter = filter
                            }
                        }
                        ForEach(["人气", "更新", "收藏", "完本", "字数"], id: \.self) { sort in
                            PillChip(sort, isSelected: selectedSort == sort) {
                                selectedSort = sort
                            }
                        }
                    }
                }
            }

            DiscoverPanelSection(title: "源操作") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 7)], alignment: .leading, spacing: 7) {
                    DiscoverActionLabel(icon: .refresh, title: "刷新入口")
                    DiscoverActionLabel(icon: .trash, title: "清缓存")
                    DiscoverActionLabel(icon: .shield, title: "登录")
                    DiscoverActionLabel(icon: .edit, title: "编辑源")
                    DiscoverActionLabel(icon: .source, title: "管理发现源")
                }
            }
        }
        .padding(ReaderDesignTokens.cardPadding)
        .backgroundCard()
    }
}

private struct DiscoverPanelSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum DiscoverOptionTone {
    case good
    case warn
    case muted
    case loading
}

private struct DiscoverSourceOption: View {
    let title: String
    let meta: String
    let isActive: Bool
    let tone: DiscoverOptionTone

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                .lineLimit(1)
            Text(meta)
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(isActive ? ReaderDesignTokens.Color.primary.opacity(0.12) : ReaderDesignTokens.Color.chipBackground.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                        .stroke(toneColor.opacity(isActive ? 0.45 : 0.18), lineWidth: 1)
                )
        )
    }

    private var toneColor: SwiftUI.Color {
        switch tone {
        case .good:
            return ReaderDesignTokens.Color.Semantic.success
        case .warn:
            return ReaderDesignTokens.Color.Semantic.warning
        case .muted:
            return ReaderDesignTokens.Color.muted
        case .loading:
            return ReaderDesignTokens.Color.primary
        }
    }
}

private struct DiscoverInlineError: View {
    var body: some View {
        HStack(spacing: 8) {
            ReaderIcon(.warning, size: 16, accessibilityLabel: "入口解析失败")
                .foregroundColor(ReaderDesignTokens.Color.Semantic.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("入口解析失败")
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                Text("当前书源的 exploreUrl 返回异常。")
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            DiscoverActionLabel(icon: .refresh, title: "重试", minWidth: 54)
        }
        .padding(.horizontal, 9)
        .frame(minHeight: 50)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(ReaderDesignTokens.Color.Semantic.warning.opacity(0.08))
        )
    }
}

private struct DiscoverActionLabel: View {
    let icon: ReaderAssetIcon
    let title: String
    var minWidth: CGFloat = 82

    var body: some View {
        HStack(spacing: 5) {
            ReaderIcon(icon, size: 13)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        .padding(.horizontal, 8)
        .frame(minWidth: minWidth, minHeight: ReaderDesignTokens.rssImportListActionMinHeight)
        .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
    }
}

private struct DiscoverResultHeader: View {
    let entry: String
    let total: Int
    let sort: String

    var body: some View {
        HStack {
            Text(entry)
                .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            Spacer(minLength: 0)
            Text("\(total) 本 · \(sort)")
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .black))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
        }
        .padding(.horizontal, 2)
    }
}

private struct DiscoverBookList: View {
    let books: [DiscoverBook]
    var isMuted = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(books.enumerated()), id: \.element) { index, book in
                DiscoverBookRow(book: book)
                if index < books.count - 1 {
                    Divider().overlay(ReaderDesignTokens.Color.discoverRowBorder)
                }
            }
        }
        .opacity(isMuted ? 0.58 : 1)
        .backgroundCard()
    }
}

private struct DiscoverBookRow: View {
    let book: DiscoverBook

    var body: some View {
        HStack(alignment: .top, spacing: ReaderDesignTokens.discoverBookRowGap) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xs)
                    .fill(ReaderDesignTokens.Color.surface)
                ReaderIcon(.book, size: 22, accessibilityLabel: "\(book.title)封面")
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                Circle()
                    .fill(book.inShelf ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.rssDotRead)
                    .frame(width: 7, height: 7)
                    .padding(5)
            }
            .frame(width: ReaderDesignTokens.discoverBookRowCoverWidth,
                   height: ReaderDesignTokens.discoverBookRowCoverHeight)
            .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xs))
            // demo `.fd-discover-book-row img`: 0 6px 14px rgba(80,67,52,0.12)
            .shadow(color: ReaderDesignTokens.Color.discoverCoverShadow, radius: 14, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: ReaderDesignTokens.discoverBookRowTitleFontSize, weight: .semibold))
                    .lineLimit(2)
                Text("\(book.author) · \(book.kind)")
                    .font(.system(size: ReaderDesignTokens.discoverBookRowSmallFontSize, weight: .bold))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineLimit(1)
                Text(book.latest)
                    .font(.system(size: ReaderDesignTokens.discoverBookRowSmallFontSize, weight: .bold))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .lineLimit(1)
                Text(book.summary)
                    .font(.system(size: ReaderDesignTokens.discoverBookRowBodyFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineLimit(ReaderDesignTokens.discoverBookRowBodyLineLimit)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ReaderDesignTokens.discoverBookRowPadding)
        .frame(minHeight: ReaderDesignTokens.discoverBookRowMinHeight, alignment: .top)
    }
}

private enum DiscoverStateTone {
    case normal
    case error
}

private struct DiscoverLargeStateCard: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String
    let actions: [String]
    var tone: DiscoverStateTone = .normal

    var body: some View {
        VStack(spacing: 10) {
            ReaderIcon(icon, size: 34, accessibilityLabel: title)
                .frame(width: ReaderDesignTokens.rssBrowserConfirmIconSize, height: ReaderDesignTokens.rssBrowserConfirmIconSize)
                .background(Circle().fill(iconColor.opacity(0.12)))
                .foregroundColor(iconColor)
            Text(title)
                .font(.system(size: ReaderDesignTokens.rssBrowserConfirmTitleFontSize, weight: .heavy))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: ReaderDesignTokens.rssBrowserConfirmBodyFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ForEach(actions, id: \.self) { title in
                    Text(title)
                        .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.horizontal, 8)
                        .frame(minHeight: ReaderDesignTokens.rssImportListActionMinHeight)
                        .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
                }
            }
        }
        .padding(.vertical, ReaderDesignTokens.rssBrowserConfirmVerticalPadding)
        .padding(.horizontal, ReaderDesignTokens.rssBrowserConfirmHorizontalPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssBrowserConfirmCardMinHeight)
        .backgroundCard(cornerRadius: ReaderDesignTokens.Radius.md)
    }

    private var iconColor: SwiftUI.Color {
        switch tone {
        case .normal:
            return ReaderDesignTokens.Color.primaryDark
        case .error:
            return ReaderDesignTokens.Color.Semantic.danger
        }
    }
}

private struct DiscoverSkeletonList: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                HStack(spacing: ReaderDesignTokens.discoverBookRowGap) {
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xs)
                        .fill(ReaderDesignTokens.Color.chipBackground)
                        .frame(width: ReaderDesignTokens.discoverBookRowCoverWidth, height: ReaderDesignTokens.discoverBookRowCoverHeight)
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xs).fill(ReaderDesignTokens.Color.chipBackground).frame(height: 12)
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xs).fill(ReaderDesignTokens.Color.chipBackground).frame(width: 132, height: 10)
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xs).fill(ReaderDesignTokens.Color.chipBackground.opacity(0.68)).frame(height: 10)
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xs).fill(ReaderDesignTokens.Color.chipBackground.opacity(0.68)).frame(width: 170, height: 10)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(ReaderDesignTokens.discoverBookRowPadding)
                .frame(minHeight: ReaderDesignTokens.discoverBookRowMinHeight)
                if index < 3 {
                    Divider().overlay(ReaderDesignTokens.Color.discoverRowBorder)
                }
            }
        }
        .backgroundCard()
        .redacted(reason: .placeholder)
    }
}

private struct DiscoverRefreshLine: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            // demo `.fd-discover-bottom-loading i`：14×14 旋转圆。
            DemoLoadingSpinner(size: .inline)
            Text(message)
                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .backgroundCard(cornerRadius: ReaderDesignTokens.Radius.md)
    }
}

private struct DiscoverBottomLoading: View {
    var body: some View {
        HStack(spacing: 8) {
            // demo `.fd-discover-bottom-loading i`：14×14 旋转圆。
            DemoLoadingSpinner(size: .inline)
            Text("继续加载")
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .black))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 34)
    }
}

private struct DiscoverBackTopButton: View {
    var body: some View {
        HStack(spacing: 5) {
            ReaderIcon(.top, size: 13)
            Text("回到顶部")
                .lineLimit(1)
        }
        .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 34)
        .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
    }
}

private struct DiscoverToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            ReaderIcon(.check, size: 13)
            Text(message)
                .lineLimit(1)
        }
        .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 34)
        .background(Capsule().fill(ReaderDesignTokens.Color.primaryDark))
    }
}

private struct DiscoverCacheConfirmOverlay: View {
    var body: some View {
        ZStack {
            // 对齐 web `.fd-discover-dialog-backdrop`：rgba(35,28,22,0.26) 半透明遮罩
            ReaderDesignTokens.Color.dialogBackdrop
                .ignoresSafeArea()

            // 对齐 web `.fd-discover-confirm-dialog`：top 44% + translateY(-50%) 居中
            VStack(spacing: 10) {
                Text("清除发现缓存？")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.ink)
                Text("将清除优书网的发现入口缓存，不影响书架和阅读进度。")
                    .font(.system(size: 13))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    Text("取消")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.Color.ink)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(Capsule().fill(ReaderDesignTokens.Color.chipBackground))
                    Text("确认清除")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(Capsule().fill(ReaderDesignTokens.Color.primary))
                }
            }
            .padding(18)
            .frame(maxWidth: 318)
            .background(
                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
                    .fill(ReaderDesignTokens.Color.bookFocusMenuBackground)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 22, x: 0, y: 22)
            .offset(y: -10)
        }
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
                    // demo `--fd-ds-shadow-soft`: 0 8px 26px rgba(89,70,50,0.1)
                    color: ReaderDesignTokens.Color.Shadow.soft,
                    radius: 26,
                    x: 0,
                    y: 8
                )
        )
    }
}
