import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import ReaderAppSupport
import ReaderAppPersistence
import ReaderCoreModels

public struct BookshelfView: View {
    private enum BookshelfDestination {
        case reader(ReaderContext)
        case batchManagement
        case groupManagement
        case localImport
        case search
        case searchSettings
    }

    @StateObject private var viewModel: BookshelfViewModel
    @State private var selectedItem: BookshelfItem?
    @State private var activeDestination: BookshelfDestination?
    @State private var bookshelfDisplayMode: BookshelfDisplayMode = .cover
    @State private var bookshelfGroup = "全部"
    @State private var bookshelfSort = "最近更新"
    @State private var bookshelfFilter = "全部"
    @State private var bookshelfFilterOpen = false
    @State private var focusedBookshelfItem: BookshelfItem?
    @State private var showBookshelfMore = false
    @ObservedObject private var navigationState: AppNavigationState
    @Binding private var topBarRequest: MainTabTopBarRequest?
    private let showsTopBar: Bool
    private let autoloadOnAppear: Bool

    /// `navigationState` 为契约单一状态源，承载 `readerContext` / `motionInterrupt`，
    /// 用于对齐 `reader.entry.coverToImmersive` / `reader.entry.actionToImmersive`。
    /// 保留无参 init 仅供既有 `AppShellAlignmentTests.testMineTabViewCanInit` 等兼容路径使用。
    public init(
        navigationState: AppNavigationState? = nil,
        showsTopBar: Bool = true,
        topBarRequest: Binding<MainTabTopBarRequest?> = .constant(nil)
    ) {
        self.init(
            navigationState: navigationState,
            showsTopBar: showsTopBar,
            topBarRequest: topBarRequest,
            initialDemoRoute: nil
        )
    }

    init(
        demoRoute: String,
        navigationState: AppNavigationState? = nil,
        showsTopBar: Bool = true,
        topBarRequest: Binding<MainTabTopBarRequest?> = .constant(nil)
    ) {
        self.init(
            navigationState: navigationState,
            showsTopBar: showsTopBar,
            topBarRequest: topBarRequest,
            initialDemoRoute: demoRoute
        )
    }

    private init(
        navigationState: AppNavigationState?,
        showsTopBar: Bool,
        topBarRequest: Binding<MainTabTopBarRequest?>,
        initialDemoRoute: String?
    ) {
        let demoItems = initialDemoRoute == nil ? nil : DemoBookshelfFixture.items
        let initialState = demoItems.map { BookshelfState.loaded(items: $0) }
        self._viewModel = StateObject(wrappedValue: BookshelfViewModel(initialState: initialState))
        self._bookshelfFilterOpen = State(initialValue: initialDemoRoute == "sort-filter")
        self._focusedBookshelfItem = State(initialValue: initialDemoRoute == "bookshelf-book-more-menu" ? DemoBookshelfFixture.items.first : nil)
        // 对齐 demo `mainTabBookshelf(view=cover|list)`：cover-mode/list-mode 显式设初始 display mode。
        self._bookshelfDisplayMode = State(initialValue: initialDemoRoute == "bookshelf-list-mode" ? .list : .cover)
        if let navigationState {
            self._navigationState = ObservedObject(wrappedValue: navigationState)
        } else {
            self._navigationState = ObservedObject(wrappedValue: AppNavigationState())
        }
        self.showsTopBar = showsTopBar
        self._topBarRequest = topBarRequest
        self.autoloadOnAppear = initialDemoRoute == nil
    }

    public var body: some View {
        // Route ownership 由 `AppShellView` 提供；root 模式下 top bar 由
        // DemoMainTabShell.appTopBar slot 承载，兼容/预览路径仍可内联显示。
        VStack(spacing: 0) {
            if showsTopBar {
                bookshelfTopBar
            }

            DemoPaperScreen(bottomPadding: ReaderDesignTokens.mainTabContentBottomPadding) {
                continueReadingCard
                bookshelfStateView
            }
        }
        .background(ReaderDesignTokens.Color.paperSolidAlt.ignoresSafeArea())
        .overlay {
            ZStack {
                bookshelfOverlayLayer
                bookshelfDestinationLayer
                    .zIndex(ReaderZIndex.overlay.rawValue)
            }
        }
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
        // NavigationStack 即使 `.toolbar(.hidden, for: .navigationBar)` 仍会预留 ~132pt 导航栏 safe area，
        // 把 DemoTopBar 推到 y≈132pt。当 BookshelfView 自带 top bar（测试/独立预览）时忽略顶部 safe area，
        // 让 top bar 回到 y≈6pt（对齐 web demo）。AppShellView 内嵌时 showsTopBar=false，safe area 由 shell 承载。
        .ignoresSafeArea(.container, edges: showsTopBar ? .top : [])
        .onAppear {
            guard autoloadOnAppear else { return }
            Task { await viewModel.loadItems() }
        }
        .onChange(of: topBarRequest) { request in
            handleTopBarRequest(request)
        }
        .refreshable {
            await viewModel.loadItems()
        }
        .mainTabBarVisible(activeDestination == nil)
    }

    private var bookshelfTopBar: some View {
        DemoTopBar(title: "书架") {
            DemoTopActionButton(
                icon: .search,
                accessibilityLabel: "搜索书籍",
                action: { activeDestination = .search }
            )

            DemoTopActionButton(
                icon: .more,
                accessibilityLabel: "书架更多操作",
                action: openBookshelfMoreMenu
            )
        }
    }

    private func handleTopBarRequest(_ request: MainTabTopBarRequest?) {
        switch request {
        case .bookshelfSearch:
            activeDestination = .search
            topBarRequest = nil
        case .bookshelfMore:
            openBookshelfMoreMenu()
            topBarRequest = nil
        case .none, .discoverRefresh, .rssRefresh, .rssManage:
            break
        }
    }

    private func openBookshelfMoreMenu() {
        showBookshelfMore = true
        focusedBookshelfItem = nil
    }

    /// 继续阅读卡 —— 对齐 demo `.fd-continue-card` 规格（grid 62/1fr/82，min-h 100，
    /// strong serif 20px，cover aspect 2:3，button pill primary）。
    /// 仅在有「最近阅读」书且带 `lastReadChapterURL` 时显示。
    @ViewBuilder
    private var continueReadingCard: some View {
        if let lastItem = viewModel.items.first(where: { $0.lastReadChapterURL != nil }) {
            ContinueReadingCard(
                item: lastItem,
                onContinue: {
                    enterImmersive(from: lastItem, source: .coverToImmersive)
                },
                onFocus: {
                    focusedBookshelfItem = lastItem
                    showBookshelfMore = false
                }
            )
        }
    }

    @ViewBuilder
    private var bookshelfOverlayLayer: some View {
        ZStack {
            if showBookshelfMore {
                BookshelfMoreLayer(
                    onDismiss: { showBookshelfMore = false },
                    onBatch: {
                        showBookshelfMore = false
                        activeDestination = .batchManagement
                    },
                    onGroups: {
                        showBookshelfMore = false
                        activeDestination = .groupManagement
                    },
                    onImport: {
                        showBookshelfMore = false
                        activeDestination = .localImport
                    }
                )
            }

            if let focusedBookshelfItem {
                BookshelfBookFocusLayer(
                    item: focusedBookshelfItem,
                    onDismiss: { self.focusedBookshelfItem = nil },
                    onBatch: {
                        self.focusedBookshelfItem = nil
                        activeDestination = .batchManagement
                    },
                    onGroups: {
                        self.focusedBookshelfItem = nil
                        activeDestination = .groupManagement
                    },
                    onDetail: {
                        self.focusedBookshelfItem = nil
                        navigateToDetail(item: focusedBookshelfItem)
                    },
                    onDelete: {
                        let itemID = focusedBookshelfItem.id
                        self.focusedBookshelfItem = nil
                        Task { await viewModel.removeItem(id: itemID) }
                    }
                )
            }

            if let selectedItem {
                BookshelfItemDetailView(
                    item: selectedItem,
                    onClose: { self.selectedItem = nil },
                    onEnterImmersive: { _ in
                        self.selectedItem = nil
                        enterImmersive(from: selectedItem, source: .actionToImmersive)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(ReaderZIndex.overlay.rawValue)
            }
        }
    }

    @ViewBuilder
    private var bookshelfDestinationLayer: some View {
        switch activeDestination {
        case .some(.reader(let context)):
            ReaderView(
                chapterURL: context.chapterURL,
                chapterTitle: context.chapterTitle,
                chapterList: chapterList(for: context),
                currentChapterIndex: chapterIndex(for: context),
                bookID: context.bookID,
                sourceID: context.sourceID,
                immersiveStart: true,
                onExit: closeActiveDestination
            )
            .transition(.opacity)

        case .some(.batchManagement):
            BookshelfBatchManagementView(
                onExit: closeActiveDestination,
                onGroups: { activeDestination = .groupManagement }
            )
            .transition(.move(edge: .trailing).combined(with: .opacity))

        case .some(.groupManagement):
            BookshelfGroupManagementView(onExit: closeActiveDestination)
                .transition(.move(edge: .trailing).combined(with: .opacity))

        case .some(.localImport):
            BookshelfLocalImportView(onImported: { summary in
                Task {
                    await viewModel.addOrUpdateLocalBook(summary)
                    await MainActor.run {
                        closeActiveDestination()
                    }
                }
            }, onExit: closeActiveDestination)
            .transition(.move(edge: .trailing).combined(with: .opacity))

        case .some(.search):
            SearchView(onExit: closeActiveDestination)
                .transition(.move(edge: .trailing).combined(with: .opacity))

        case .some(.searchSettings):
            SettingsDemoShellView(demoRoute: "bookshelf-search-settings", onExit: closeActiveDestination)
                .transition(.move(edge: .trailing).combined(with: .opacity))

        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var bookshelfStateView: some View {
        switch viewModel.bookshelfState {
        case .idle:
            Text("加载中...")
                .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)

        case .loading:
            // demo `.fd-reader-loading-panel`：30×30 spinner + 文案，居中。
            VStack(spacing: 8) {
                DemoLoadingSpinner(size: .reader)
                Text("加载中...")
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 200)

        case .loaded(let items):
            bookshelfShelfSection(items: items)

        case .empty:
            ReaderCard {
                VStack(spacing: ReaderDesignTokens.settingsSectionGap) {
                    ReaderIcon(.bookshelf, size: 42, accessibilityLabel: "书架空状态")
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                    Text("书架还是空的")
                        .font(.system(size: ReaderDesignTokens.readerOverlaySectionTitleFontSize, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .multilineTextAlignment(.center)

                    Text("添加网络书籍或导入本地文件后，会在这里显示继续阅读和书架内容。")
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: ReaderDesignTokens.rssModeRowGap) {
                        BookshelfEmptyActionButton(
                            icon: .search,
                            title: "搜索书籍",
                            subtitle: "按书名、作者或关键词查找",
                            isPrimary: true,
                            action: { activeDestination = .search }
                        )
                        BookshelfEmptyActionButton(
                            icon: .folder,
                            title: "导入本地书",
                            subtitle: "添加本机文件到书架",
                            isPrimary: false,
                            action: { activeDestination = .localImport }
                        )
                    }
                    .padding(.top, 4)

                    HStack(spacing: ReaderDesignTokens.rssModeRowGap) {
                        BookshelfEmptyHintButton(icon: .sparkle, title: "去发现") {
                            navigationState.switchTab(.discover)
                        }
                        BookshelfEmptyHintButton(icon: .gear, title: "书架设置") {
                            activeDestination = .searchSettings
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 260)
            }

        case .failed(let message):
            ReaderCard {
                HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                    ReaderIcon(.warning, size: 20, accessibilityLabel: "错误")
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("加载失败")
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        Text(message)
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// 书架 shelf 区 —— 结构取自 demo `mainTabBookshelf()`：
    /// `fd-bookshelf-shelf-section` -> `fd-section-head` + optional
    /// `fd-bookshelf-filter-popover` + `fd-book-grid`。
    private func bookshelfShelfSection(items: [BookshelfItem]) -> some View {
        let visibleItems = filteredBookshelfItems(items)
        return VStack(alignment: .leading, spacing: ReaderDesignTokens.bookGridRowSpacing) {
            BookshelfSectionHeader(
                displayMode: $bookshelfDisplayMode,
                isFilterOpen: $bookshelfFilterOpen,
                filterIsActive: bookshelfFilterOpen
                    || bookshelfGroup != "全部"
                    || bookshelfSort != "最近更新"
                    || bookshelfFilter != "全部"
            )

            if bookshelfFilterOpen {
                BookshelfFilterPopover(
                    group: $bookshelfGroup,
                    sort: $bookshelfSort,
                    filter: $bookshelfFilter
                )
            }

            if visibleItems.isEmpty {
                Text("没有符合条件的书籍")
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookListCardMinHeight)
            } else if bookshelfDisplayMode == .cover {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: ReaderDesignTokens.bookGridColumnSpacing),
                        count: ReaderDesignTokens.bookGridColumns
                    ),
                    alignment: .leading,
                    spacing: ReaderDesignTokens.bookGridRowSpacing
                ) {
                    ForEach(Array(visibleItems.enumerated()), id: \.element.id) { _, item in
                        BookshelfBookCoverCard(
                            item: item,
                            onCoverTap: {
                                enterImmersive(from: item, source: .coverToImmersive)
                            },
                            onFocus: {
                                focusedBookshelfItem = item
                                showBookshelfMore = false
                            },
                            onDetailTap: {
                                navigateToDetail(item: item)
                            }
                        )
                    }
                }
                .accessibilityLabel("书籍封面网格")
            } else {
                VStack(spacing: ReaderDesignTokens.bookGridListRowSpacing) {
                    ForEach(visibleItems) { item in
                        BookshelfBookListCard(
                            item: item,
                            onCoverTap: {
                                enterImmersive(from: item, source: .coverToImmersive)
                            },
                            onFocus: {
                                focusedBookshelfItem = item
                                showBookshelfMore = false
                            },
                            onDetailTap: {
                                navigateToDetail(item: item)
                            }
                        )
                    }
                }
                .accessibilityLabel("书籍列表")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("我的书架")
    }

    private func navigateToDetail(item: BookshelfItem) {
        selectedItem = item
    }

    private func filteredBookshelfItems(_ items: [BookshelfItem]) -> [BookshelfItem] {
        var indexed = items.enumerated()
            .filter { pair in bookshelfGroup == "全部" || bookshelfBookGroup(pair.element, index: pair.offset) == bookshelfGroup }
            .filter { pair in bookshelfBookMatchesFilter(pair.element, index: pair.offset) }

        switch bookshelfSort {
        case "阅读进度":
            indexed.sort { left, right in
                if left.element.readingProgress == right.element.readingProgress {
                    return left.offset < right.offset
                }
                return left.element.readingProgress > right.element.readingProgress
            }
        case "书名":
            indexed.sort { left, right in
                let result = left.element.title.localizedStandardCompare(right.element.title)
                return result == .orderedSame ? left.offset < right.offset : result == .orderedAscending
            }
        case "作者":
            indexed.sort { left, right in
                let result = (left.element.author ?? "").localizedStandardCompare(right.element.author ?? "")
                return result == .orderedSame ? left.offset < right.offset : result == .orderedAscending
            }
        default:
            break
        }

        return indexed.map(\.element)
    }

    private func bookshelfBookGroup(_ item: BookshelfItem, index: Int) -> String {
        let source = "\(item.sourceID) \(item.sourceName ?? "") \(item.author ?? "")"
        if source.localizedCaseInsensitiveContains("local") || source.contains("本地") || source.contains("导入") {
            return "本地书"
        }
        if index < 4 || source.contains("书源") || source.contains("同步") {
            return "追更"
        }
        return "默认"
    }

    private func bookshelfBookMatchesFilter(_ item: BookshelfItem, index: Int) -> Bool {
        switch bookshelfFilter {
        case "未读":
            return item.readingProgress < 0.2
        case "已完结":
            return item.readingProgress >= 0.99 || (item.latestChapter ?? "").contains("完")
        case "更新失败":
            return item.latestChapter?.contains("失败") == true || item.title.contains("更新失败")
        default:
            return true
        }
    }

    // MARK: - Immersive entry (reader.entry.coverToImmersive / actionToImmersive)

    /// latest-intent-wins：连续点击只保留最后目标 —— 通过 `navigationState.enterImmersiveReading`
    /// 注入新 `ReaderContext`（新 requestID），旧 context 被覆盖。
    private func enterImmersive(from item: BookshelfItem, source: ReaderContext.EntrySource) {
        let chapterURL = item.lastReadChapterURL ?? item.bookURL
        let chapterTitle = item.lastReadChapterTitle ?? "继续阅读"
        let context = ReaderContext(
            bookID: item.id,
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            sourceID: item.sourceID,
            source: source
        )
        // P2-A HERO-P0-1: 用 withAnimation 触发 matchedGeometryEffect 过渡。
        // 真源：motion-controller.js line 412-417 reader.entry.coverToImmersive (240ms)
        // 与 line 418-423 reader.entry.actionToImmersive (200ms)。
        // 通过 ReaderMotionAdapter.resolve(request:) 解析契约 MotionId：
        // - sourceRole="bookCover" → .reader_entry_coverToImmersive (priority 350)
        // - sourceRole="actionButton" → .reader_entry_actionToImmersive (priority 350)
        // reduced motion 时 adapter 返回 nil，withAnimation(nil) 即时切换。
        let motion = MotionEnvironment()
        let entryRequest = MotionRequest(
            fromShell: .mainTabShell,
            toShell: .readerShell,
            operation: .push,
            sourceRole: source == .coverToImmersive ? "bookCover" : "actionButton"
        )
        withAnimation(ReaderMotionAdapter.animation(for: entryRequest, motion: motion)) {
            navigationState.enterImmersiveReading(context)
            activeDestination = .reader(context)
        }
    }

    private func closeActiveDestination() {
        if case .reader = activeDestination {
            // P2-A: 退出沉浸阅读同样包裹 withAnimation，让 matchedGeometryEffect 反向过渡。
            // operation: .pop from readerShell → mainTabShell 无特定 policy，
            // resolver 回退到 .motion_interrupt_redirect (80ms)，
            // 适合快速退出沉浸阅读。
            let motion = MotionEnvironment()
            let exitRequest = MotionRequest(
                fromShell: .readerShell,
                toShell: .mainTabShell,
                operation: .pop
            )
            withAnimation(ReaderMotionAdapter.animation(for: exitRequest, motion: motion)) {
                navigationState.exitImmersiveReading()
                activeDestination = nil
            }
        } else {
            activeDestination = nil
        }
    }

    private func chapterList(for context: ReaderContext) -> [TOCItem] {
        guard let item = viewModel.items.first(where: { $0.id == context.bookID }) else {
            return []
        }
        return item.localChapterList ?? []
    }

    private func chapterIndex(for context: ReaderContext) -> Int {
        let list = chapterList(for: context)
        guard !list.isEmpty else { return 0 }
        return list.firstIndex { $0.chapterURL == context.chapterURL } ?? 0
    }
}

enum BookshelfDisplayMode: String, CaseIterable {
    case cover
    case list
}

private struct BookshelfSectionHeader: View {
    @Binding var displayMode: BookshelfDisplayMode
    @Binding var isFilterOpen: Bool
    let filterIsActive: Bool

    var body: some View {
        HStack(alignment: .center, spacing: ReaderDesignTokens.bookshelfSectionHeadGap) {
            Text("我的书架")
                .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: ReaderDesignTokens.bookshelfSectionActionGap) {
                actionButton(
                    icon: .grid,
                    label: "封面视图",
                    isActive: displayMode == .cover
                ) {
                    displayMode = .cover
                }

                actionButton(
                    icon: .list,
                    label: "列表视图",
                    isActive: displayMode == .list
                ) {
                    displayMode = .list
                }

                actionButton(
                    icon: .filter,
                    label: "书架筛选",
                    isActive: filterIsActive
                ) {
                    isFilterOpen.toggle()
                }

                actionButton(
                    icon: .gear,
                    label: "书架显示设置",
                    isActive: false
                ) {}
                .disabled(true)
            }
        }
        .frame(minHeight: ReaderDesignTokens.bookshelfSectionHeadMinHeight)
    }

    private func actionButton(
        icon: ReaderAssetIcon,
        label: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ReaderIcon(icon, size: 18, accessibilityLabel: label)
                .frame(
                    width: ReaderDesignTokens.bookshelfSectionActionSize,
                    height: ReaderDesignTokens.bookshelfSectionActionSize
                )
                .foregroundColor(isActive ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.muted)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : [.isButton])
    }
}

private struct BookshelfFilterPopover: View {
    @Binding var group: String
    @Binding var sort: String
    @Binding var filter: String

    private let groupOptions = ["全部", "默认", "本地书", "追更"]
    private let sortOptions = ["最近更新", "阅读进度", "书名", "作者"]
    private let filterOptions = ["全部", "未读", "已完结", "更新失败"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            optionRow(title: "分组", options: groupOptions, selection: $group)
            optionRow(title: "排序", options: sortOptions, selection: $sort)
            optionRow(title: "筛选", options: filterOptions, selection: $filter)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
                .fill(ReaderDesignTokens.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
                        .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                )
        )
        .accessibilityLabel("书架排序与筛选选项")
    }

    private func optionRow(title: String, options: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: ReaderDesignTokens.chipFontSize, weight: .black))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            selection.wrappedValue = option
                        } label: {
                            Text(option)
                                .font(.system(size: ReaderDesignTokens.chipFontSize, weight: .black))
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 30)
                                .background(
                                    Capsule()
                                        .fill(selection.wrappedValue == option
                                              ? ReaderDesignTokens.Color.primary
                                              : ReaderDesignTokens.Color.chipBackground)
                                )
                                .foregroundColor(selection.wrappedValue == option ? .white : ReaderDesignTokens.Color.controlInkAlt)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selection.wrappedValue == option ? [.isButton, .isSelected] : [.isButton])
                    }
                }
            }
        }
    }
}

private struct BookshelfBookCoverCard: View {
    let item: BookshelfItem
    let onCoverTap: () -> Void
    let onFocus: () -> Void
    let onDetailTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.bookCardGap) {
            BookshelfCoverAction(
                item: item,
                mode: .cover,
                onTap: onCoverTap,
                onLongPress: onFocus
            ) {
                BookshelfCoverFrame(item: item, mode: .cover)
            }

            Button(action: onDetailTap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(ReaderTypography.demoSerif(size: ReaderDesignTokens.bookCardTitleFontSize))
                        .lineLimit(ReaderDesignTokens.bookCardTitleLineLimit)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(ReaderDesignTokens.Color.ink)

                    Text(item.author ?? item.sourceName ?? "未知作者")
                        .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                        .lineLimit(1)
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct BookshelfBookListCard: View {
    let item: BookshelfItem
    let onCoverTap: () -> Void
    let onFocus: () -> Void
    let onDetailTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: ReaderDesignTokens.bookListColumnGap) {
            BookshelfCoverAction(
                item: item,
                mode: .list,
                onTap: onCoverTap,
                onLongPress: onFocus
            ) {
                BookshelfCoverFrame(item: item, mode: .list)
                    .frame(width: ReaderDesignTokens.bookListCoverWidth)
            }

            Button(action: onDetailTap) {
                VStack(alignment: .leading, spacing: ReaderDesignTokens.bookListRowGap) {
                    Text(item.title)
                        .font(ReaderTypography.demoSerif(size: ReaderDesignTokens.bookCardTitleFontSize))
                        .lineLimit(1)
                        .foregroundStyle(ReaderDesignTokens.Color.ink)

                    Text(item.author ?? item.sourceName ?? "未知作者")
                        .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                        .lineLimit(1)
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookListCardMinHeight, alignment: .leading)
    }
}

private struct BookshelfCoverFrame: View {
    enum Mode {
        case cover
        case list
    }

    let item: BookshelfItem
    let mode: Mode

    // P2-A HERO-P0-1: 从 environment 读取 hero namespace，用于 coverToImmersive shared element。
    // 真源：MOTION_EFFECTS.md line 611-635 reader.entry.coverToImmersive
    // 封面作为"来源锚点"（isSource: true），与 ReaderView 入口锚点共享 id。
    // 使用 @SwiftUI.Environment 避免与 ReaderCoreModels.Environment 类型歧义。
    @SwiftUI.Environment(\.heroNamespace) private var heroNamespace

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(ReaderDesignTokens.Color.overlayWhite58)

            #if canImport(UIKit)
            if let demoCoverPNG {
                Image(uiImage: demoCoverPNG)
                    .resizable()
                    .scaledToFill()
            } else if let url = coverURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
            #else
            placeholder
            #endif
        }
        .aspectRatio(ReaderDesignTokens.bookCoverAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(
            // cover: demo `--fd-soft-shadow` 0 8px 26px rgba(89,70,50,0.1)
            // list:  demo `.fd-book-grid.is-list-view .fd-book-cover-frame` 0 6px 12px rgba(52,38,26,0.12)
            color: mode == .cover
                ? ReaderDesignTokens.Color.Shadow.soft
                : ReaderDesignTokens.Color.Shadow.bookList,
            radius: mode == .cover ? 26 : 12,
            x: 0,
            y: mode == .cover ? 8 : 6
        )
        // P2-A HERO-P0-1: 封面作为 coverToImmersive 的来源锚点（isSource: true）。
        // 仅在 .cover 模式下挂载（list 模式尺寸过小，不参与 hero 过渡）。
        // heroNamespace 为 nil 时（Preview / 未注入）原样返回，安全降级。
        .heroMatchedGeometry(id: "bookCover-\(item.id)", namespace: heroNamespace, isSource: mode == .cover)
    }

    private var placeholder: some View {
        ReaderIcon(.book, size: mode == .cover ? 26 : 18)
            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
    }

    private var cornerRadius: CGFloat {
        mode == .cover ? ReaderDesignTokens.bookCoverFrameCornerRadius : ReaderDesignTokens.bookListCoverCornerRadius
    }

    private var coverURL: URL? {
        guard let coverURL = item.coverURL, !coverURL.isEmpty else { return nil }
        if let url = URL(string: coverURL), url.scheme != nil {
            return url
        }
        return URL(fileURLWithPath: coverURL)
    }

    /// 从内联 base64 数据加载 demo 封面 PNG。
    /// `demo-cover://<key>` → `DemoCoverImageStore.uiImage(forCoverKey:)`。
    /// 资源通过 `DemoCoverImagesData.swift` 内联，避免 SPM 资源 bundle 在
    /// xcodebuild 下的不稳定性（`SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE`）。
    #if canImport(UIKit)
    private var demoCoverPNG: UIImage? {
        guard let coverURL = item.coverURL,
              let url = URL(string: coverURL),
              url.scheme == "demo-cover" else {
            return nil
        }
        let key = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return DemoCoverImageStore.uiImage(forCoverKey: key)
    }
    #endif
}

private struct BookshelfCoverAction<Content: View>: View {
    let item: BookshelfItem
    let mode: BookshelfCoverFrame.Mode
    let onTap: () -> Void
    let onLongPress: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var suppressTapAfterLongPress = false

    var body: some View {
        content()
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onTapGesture {
                if suppressTapAfterLongPress {
                    suppressTapAfterLongPress = false
                    return
                }
                onTap()
            }
            .onLongPressGesture(
                minimumDuration: ReaderDesignTokens.bookFocusLongPressDuration,
                perform: {
                    suppressTapAfterLongPress = true
                    onLongPress()
                }
            )
            .accessibilityLabel("打开 \(item.title)")
            .accessibilityAddTraits(.isButton)
    }

    private var cornerRadius: CGFloat {
        mode == .cover ? ReaderDesignTokens.bookCoverFrameCornerRadius : ReaderDesignTokens.bookListCoverCornerRadius
    }
}

private struct BookshelfBookFocusLayer: View {
    let item: BookshelfItem
    let onDismiss: () -> Void
    let onBatch: () -> Void
    let onGroups: () -> Void
    let onDetail: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ReaderDesignTokens.Color.ink.opacity(ReaderDesignTokens.bookFocusBackdropOpacity)
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: ReaderDesignTokens.bookFocusMenuGap) {
                header
                actionGrid
            }
            .padding(ReaderDesignTokens.bookFocusMenuPadding)
            .background(menuBackground)
            .padding(.horizontal, ReaderDesignTokens.bookFocusMenuHorizontalInset)
            .padding(.bottom, ReaderDesignTokens.mainNavHeight + ReaderDesignTokens.bookFocusMenuBottomGap)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("书籍操作")
    }

    private var header: some View {
        HStack(spacing: 10) {
            BookshelfCoverFrame(item: item, mode: .list)
                .frame(width: ReaderDesignTokens.bookFocusCoverSize,
                       height: ReaderDesignTokens.bookFocusCoverSize / ReaderDesignTokens.bookCoverAspectRatio)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: ReaderDesignTokens.readerTopTitleFontSize, weight: .heavy))
                    .lineLimit(1)

                Text("\(item.author ?? "未知作者") · \(item.lastReadChapterTitle ?? item.latestChapter ?? "继续阅读")")
                    .font(.system(size: ReaderDesignTokens.rssArticleRowBodyFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionGrid: some View {
        HStack(spacing: 8) {
            focusAction(icon: .check, title: "多选", role: nil, action: onBatch)
            focusAction(icon: .people, title: "分支", role: nil, action: onGroups)
            focusAction(icon: .info, title: "书籍详情", role: nil, action: onDetail)
            focusAction(icon: .trash, title: "删除", role: .destructive, action: onDelete)
        }
    }

    private func focusAction(
        icon: ReaderAssetIcon,
        title: String,
        role: ButtonRole?,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            VStack(spacing: 5) {
                ReaderIcon(icon, size: 18, accessibilityLabel: title)
                Text(title)
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookFocusActionMinHeight)
        }
        .buttonStyle(.plain)
        .foregroundColor(role == .destructive ? ReaderDesignTokens.Color.danger : ReaderDesignTokens.Color.ink)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(ReaderDesignTokens.Color.overlayWhite58)
        )
    }

    private var menuBackground: some View {
        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
            .fill(ReaderDesignTokens.Color.bookFocusMenuBackground)
            .overlay(
                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
                    .stroke(
                        SwiftUI.Color(
                            red: 180/255,
                            green: 166/255,
                            blue: 151/255,
                            opacity: ReaderDesignTokens.bookFocusMenuBorderOpacity
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: ReaderDesignTokens.Color.Shadow.elevated,
                    radius: 46, x: 0, y: 22)
    }
}

private struct BookshelfMoreLayer: View {
    let onDismiss: () -> Void
    let onBatch: () -> Void
    let onGroups: () -> Void
    let onImport: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ReaderDesignTokens.Color.ink.opacity(ReaderDesignTokens.bookshelfMoreBackdropOpacity)
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: ReaderDesignTokens.bookshelfMoreMenuGap) {
                Text("书架更多操作")
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                    .lineLimit(1)

                moreAction(icon: .check, title: "批量管理", meta: "选择多本书后移动或删除", action: onBatch)
                moreAction(icon: .people, title: "分组管理", meta: "编辑书架分组与归属", action: onGroups)
                moreAction(icon: .bookOpen, title: "本地书导入", meta: "导入本地文件到书架", action: onImport)
            }
            .padding(ReaderDesignTokens.bookshelfMoreMenuPadding)
            .frame(width: ReaderDesignTokens.bookshelfMoreMenuWidth, alignment: .leading)
            .background(menuBackground)
            .padding(.top, ReaderDesignTokens.bookshelfMoreMenuTopGap)
            .padding(.trailing, ReaderDesignTokens.bookshelfMoreMenuRightGap)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("书架更多操作")
    }

    private func moreAction(
        icon: ReaderAssetIcon,
        title: String,
        meta: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: ReaderDesignTokens.bookshelfMoreActionGap) {
                ReaderIcon(icon, size: 18, accessibilityLabel: title)
                    .frame(width: ReaderDesignTokens.bookshelfMoreActionIconColumn)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .lineLimit(1)
                    Text(meta)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, ReaderDesignTokens.bookshelfMoreActionHorizontalPadding)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookshelfMoreActionMinHeight, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundColor(ReaderDesignTokens.Color.ink)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(SwiftUI.Color.clear)
        )
    }

    private var menuBackground: some View {
        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
            .fill(ReaderDesignTokens.Color.bookFocusMenuBackground)
            .overlay(
                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
                    .stroke(
                        SwiftUI.Color(
                            red: 180/255,
                            green: 166/255,
                            blue: 151/255,
                            opacity: ReaderDesignTokens.bookFocusMenuBorderOpacity
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: ReaderDesignTokens.Color.Shadow.elevated,
                    radius: 42, x: 0, y: 22)
    }
}

struct BookshelfBatchManagementView: View {
    @State private var selectedIDs = Set(BookBatchItem.demoBooks.prefix(3).map(\.id))
    private let onExit: (() -> Void)?
    private let onGroups: (() -> Void)?

    init(onExit: (() -> Void)? = nil, onGroups: (() -> Void)? = nil) {
        self.onExit = onExit
        self.onGroups = onGroups
    }

    var body: some View {
        DemoBackScreen(title: "批量管理", onBack: onExit) {
            batchSummary
            batchList
        } bottomActionHost: {
            BottomFixedActionRow {
                Button {
                    onGroups?()
                } label: {
                    BookBatchBottomLabel(title: "移动分组", isPrimary: true)
                }
                .buttonStyle(.plain)
            } trailing: {
                BookBatchBottomButton(title: "删除所选", isPrimary: false, isDanger: true) {}
            }
        }
    }

    private var selectedCount: Int {
        selectedIDs.count
    }

    private var batchSummary: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text("已选 \(selectedCount) 本")
                        .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: toggleAll) {
                        Text(selectedCount == BookBatchItem.demoBooks.count ? "取消全选" : "全选")
                            .font(.system(size: ReaderDesignTokens.chipFontSize, weight: .black))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 30)
                            .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                }

                Text("长按书籍或从更多菜单进入，选择后统一移动分组、删除或取消选择。")
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineLimit(2)
            }
            .padding(ReaderDesignTokens.bookBatchSummaryPadding - ReaderDesignTokens.cardPadding)
        }
    }

    private var batchList: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("书架书籍")
                    .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .padding(.bottom, 4)

                ForEach(BookBatchItem.demoBooks) { item in
                    BookBatchRow(
                        item: item,
                        isSelected: selectedIDs.contains(item.id),
                        onToggle: { toggle(item) }
                    )
                    if item.id != BookBatchItem.demoBooks.last?.id {
                        Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                    }
                }
            }
        }
    }

    private func toggle(_ item: BookBatchItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    private func toggleAll() {
        if selectedCount == BookBatchItem.demoBooks.count {
            selectedIDs.removeAll()
        } else {
            selectedIDs = Set(BookBatchItem.demoBooks.map(\.id))
        }
    }
}

private struct BookBatchItem: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let chapter: String
    let group: String

    static let demoBooks: [BookBatchItem] = [
        BookBatchItem(id: "mist-lighthouse", title: "灯塔与雾", author: "书源同步", chapter: "第 42 章 风暴前夜", group: "追更"),
        BookBatchItem(id: "rain-city", title: "雨城札记", author: "林间", chapter: "第 18 章 旧书店", group: "默认"),
        BookBatchItem(id: "local-notes", title: "本地导入手记", author: "本地书", chapter: "离线章节 03", group: "本地书"),
        BookBatchItem(id: "sea-archive", title: "海边档案", author: "远山", chapter: "第 6 卷 附录", group: "追更"),
        BookBatchItem(id: "source-sync", title: "书源同步异常记录", author: "维护", chapter: "更新失败", group: "默认"),
        BookBatchItem(id: "long-title", title: "长标题测试：跨端书架布局校验", author: "设计验收", chapter: "第 9 章", group: "本地书")
    ]
}

private struct BookBatchRow: View {
    let item: BookBatchItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: ReaderDesignTokens.bookBatchRowGap) {
                BookBatchSelectControl(isSelected: isSelected)
                    .frame(width: ReaderDesignTokens.bookBatchSelectColumn)

                BookBatchCover(title: item.title)
                    .frame(width: ReaderDesignTokens.bookBatchCoverWidth)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .foregroundStyle(ReaderDesignTokens.Color.ink)
                        .lineLimit(1)
                    Text("\(item.author) · \(item.chapter)")
                        .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.group)
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 30)
                    .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
            }
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookBatchRowMinHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm)
                .fill(isSelected ? ReaderDesignTokens.Color.primary.opacity(0.08) : SwiftUI.Color.clear)
        )
        .accessibilityLabel("\(item.title)，\(isSelected ? "已选择" : "未选择")")
    }
}

private struct BookBatchSelectControl: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.surface)
                .overlay(
                    Circle()
                        .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                )
            if isSelected {
                ReaderIcon(.check, size: 13, accessibilityLabel: "已选择")
                    .foregroundColor(.white)
            }
        }
        .frame(width: ReaderDesignTokens.bookBatchSelectSize, height: ReaderDesignTokens.bookBatchSelectSize)
    }
}

private struct BookBatchCover: View {
    let title: String

    var body: some View {
        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm)
            .fill(ReaderDesignTokens.Color.primary.opacity(0.14))
            .overlay(
                Text(String(title.prefix(1)))
                    .font(.system(size: ReaderDesignTokens.readerTopTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            )
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .shadow(color: ReaderDesignTokens.Color.Shadow.bookBatch, radius: 10, x: 0, y: 3)
    }
}

private struct BookBatchBottomButton: View {
    let title: String
    let isPrimary: Bool
    var isDanger = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BookBatchBottomLabel(title: title, isPrimary: isPrimary, isDanger: isDanger)
        }
        .buttonStyle(.plain)
    }
}

private struct BookBatchBottomLabel: View {
    let title: String
    let isPrimary: Bool
    var isDanger = false

    var body: some View {
        Text(title)
            .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
            .lineLimit(1)
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
            .background(Capsule().fill(backgroundColor))
    }

    private var foregroundColor: SwiftUI.Color {
        if isDanger {
            return ReaderDesignTokens.Color.danger
        }
        return isPrimary ? .white : ReaderDesignTokens.Color.primaryDark
    }

    private var backgroundColor: SwiftUI.Color {
        isPrimary ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.surface
    }
}

struct BookshelfItemDetailView: View {
    let item: BookshelfItem
    let onClose: () -> Void
    let onEnterImmersive: (ReaderContext) -> Void
    @State private var showBookmarks = false

    init(
        item: BookshelfItem,
        onClose: @escaping () -> Void = {},
        onEnterImmersive: @escaping (ReaderContext) -> Void
    ) {
        self.item = item
        self.onClose = onClose
        self.onEnterImmersive = onEnterImmersive
    }

    var body: some View {
        DemoBackScreen(title: "书籍详情") {
            detailHeroCard
            detailInfoCard
            readingProgressCard
        } trailing: {
            Button("完成") { onClose() }
                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        } bottomActionHost: {
            BottomFixedActionRow {
                Button {
                    showBookmarks = true
                } label: {
                    detailActionLabel(icon: .bookmark, title: "查看书签", isPrimary: false)
                }
                .buttonStyle(.plain)
            } trailing: {
                Button {
                    continueReading()
                } label: {
                    detailActionLabel(icon: .bookOpen, title: "继续阅读", isPrimary: canContinueReading)
                }
                .buttonStyle(.plain)
                .disabled(!canContinueReading)
                .opacity(canContinueReading ? 1 : 0.48)
            }
        } sheetHost: {
            if showBookmarks {
                DemoBottomSheet(title: "书签", maxHeight: 620, onDismiss: { showBookmarks = false }) {
                    BookmarksListView(
                        bookId: item.id,
                        sourceId: item.sourceID,
                        bookTitle: item.title,
                        onClose: { showBookmarks = false }
                    )
                }
            }
        } dialogHost: {
            EmptyView()
        } stateHost: {
            EmptyView()
        }
    }

    private var detailHeroCard: some View {
        ReaderCard {
            HStack(alignment: .top, spacing: ReaderDesignTokens.bookDetailHeroGap) {
                BookshelfCoverFrame(item: item, mode: .list)
                    .frame(width: 54)
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(ReaderTypography.demoSerif(size: ReaderDesignTokens.continueCardTitleFontSize, weight: .bold))
                        .lineLimit(2)
                    Text(authorLabel)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .semibold))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .lineLimit(1)
                    Text(sourceLabel)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var detailInfoCard: some View {
        ReaderCard {
            VStack(spacing: 0) {
                DemoIconRow(icon: .bookOpen, title: "书名", subtitle: item.title, detail: nil)
                Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                DemoIconRow(icon: .sourceStack, title: "来源", subtitle: sourceLabel, detail: "书架")
                Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                DemoIconRow(icon: .clock, title: "添加时间", subtitle: addedDateLabel, detail: nil)
            }
        }
    }

    private var readingProgressCard: some View {
        ReaderCard {
            VStack(spacing: 0) {
                DemoIconRow(icon: .progress, title: "阅读进度", subtitle: progressLabel, detail: nil)
                if let chapter = item.lastReadChapterTitle {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                    DemoIconRow(icon: .directory, title: "最后阅读", subtitle: chapter, detail: "继续")
                }
            }
        }
    }

    private func detailActionLabel(icon: ReaderAssetIcon, title: String, isPrimary: Bool) -> some View {
        HStack(spacing: 7) {
            ReaderIcon(icon, size: 16, accessibilityLabel: title)
            Text(title)
                .font(.system(size: ReaderDesignTokens.chipFontSize, weight: .black))
                .lineLimit(1)
        }
        .foregroundColor(isPrimary ? .white : ReaderDesignTokens.Color.primaryDark)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(isPrimary ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                        .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: isPrimary ? 0 : 1)
                )
        )
    }

    private func continueReading() {
        guard let chapterURL = item.lastReadChapterURL else { return }
        let context = ReaderContext(
            bookID: item.id,
            chapterURL: chapterURL,
            chapterTitle: item.lastReadChapterTitle ?? "继续阅读",
            sourceID: item.sourceID,
            source: .actionToImmersive
        )
        onClose()
        onEnterImmersive(context)
    }

    private var canContinueReading: Bool {
        item.lastReadChapterURL != nil
    }

    private var authorLabel: String {
        guard let author = item.author?.trimmingCharacters(in: .whitespacesAndNewlines), !author.isEmpty else {
            return "未知作者"
        }
        return author
    }

    private var sourceLabel: String {
        guard let source = item.sourceName?.trimmingCharacters(in: .whitespacesAndNewlines), !source.isEmpty else {
            return "本地书架"
        }
        return source
    }

    private var progressLabel: String {
        "\(Int(item.readingProgress * 100))%"
    }

    private var addedDateLabel: String {
        item.addedAt.formatted(date: .numeric, time: .omitted)
    }

    private var localChapterList: [TOCItem] {
        item.localChapterList ?? []
    }

    private var currentChapterIndex: Int {
        guard let chapterURL = item.lastReadChapterURL else { return 0 }
        return localChapterList.firstIndex { $0.chapterURL == chapterURL } ?? 0
    }
}

private struct BookshelfEmptyActionButton: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(icon, size: 18, accessibilityLabel: title)
                    .frame(width: ReaderDesignTokens.settingsRowIconColumn)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                        .lineLimit(2)
                        .foregroundColor(isPrimary ? .white.opacity(0.82) : ReaderDesignTokens.Color.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.settingsRowMinHeight, alignment: .leading)
            .foregroundColor(isPrimary ? .white : ReaderDesignTokens.Color.primaryDark)
            .background(
                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                    .fill(isPrimary ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.chipBackground.opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                            .stroke(isPrimary ? ReaderDesignTokens.Color.primaryDark.opacity(0.4) : ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct BookshelfEmptyHintButton: View {
    let icon: ReaderAssetIcon
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                ReaderIcon(icon, size: 13, accessibilityLabel: title)
                Text(title)
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.searchSectionActionMinHeight)
            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            .background(Capsule().fill(ReaderDesignTokens.Color.chipBackground.opacity(0.72)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - 继续阅读卡

/// 继续阅读卡 —— 对齐 demo `.fd-continue-card` 规格。
///
/// 真源：`Reader UI/frontend-demo-optimized/styles/00-foundation.css` `.fd-continue-card`
/// 规格（取自 `ReaderDesignTokens`，clean-room，不复制 CSS）：
/// - grid 62pt / 1fr / 82pt（cover / text / action button）
/// - min-h 100pt / padding 10×16 / border 1 / radius 8 / surface bg / soft shadow
/// - h2: 13pt/900/primary · strong: serif 20pt line-clamp 2
/// - cover-button: 62pt wide / aspect 2:3 / radius 6
/// - action-button: min 74×40 / radius pill / primary bg / white / 13pt-800
struct ContinueReadingCard: View {
    let item: BookshelfItem
    let onContinue: () -> Void
    let onFocus: () -> Void

    var body: some View {
        HStack(spacing: ReaderDesignTokens.continueCardGap) {
            // 左：cover (62pt × aspect 2:3)
            BookshelfCoverAction(
                item: item,
                mode: .list,
                onTap: onContinue,
                onLongPress: onFocus
            ) {
                coverView
                    .frame(width: ReaderDesignTokens.continueCoverButtonWidth)
                    .aspectRatio(ReaderDesignTokens.continueCoverAspectRatio, contentMode: .fit)
            }

            // 中：title block
            VStack(alignment: .leading, spacing: 4) {
                Text("继续阅读")
                    .font(.system(size: ReaderDesignTokens.continueCardHeaderFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primary)

                Text(item.title)
                    .font(ReaderTypography.demoSerif(size: ReaderDesignTokens.continueCardTitleFontSize))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let author = item.author {
                    Text(author)
                        .font(.system(size: ReaderDesignTokens.readerSectionTitleFontSize))
                        .foregroundColor(ReaderDesignTokens.Color.muted)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 右：action button
            Button(action: onContinue) {
                Text("继续")
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                    .foregroundColor(.white)
                    .frame(
                        minWidth: ReaderDesignTokens.continueActionButtonMinWidth,
                        minHeight: ReaderDesignTokens.continueActionButtonMinHeight
                    )
                    .background(ReaderDesignTokens.Color.primary)
                    .clipShape(Capsule())
            }
            .frame(width: ReaderDesignTokens.continueCardActionButtonWidth)
        }
        .padding(.vertical, ReaderDesignTokens.continueCardVerticalPadding)
        .padding(.horizontal, ReaderDesignTokens.continueCardHorizontalPadding)
        .frame(minHeight: ReaderDesignTokens.continueCardMinHeight, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(ReaderDesignTokens.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                        .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                )
                // demo `--fd-ds-shadow-soft`: 0 8px 26px rgba(89,70,50,0.1)
                .shadow(color: ReaderDesignTokens.Color.Shadow.soft,
                        radius: 26, x: 0, y: 8)
        )
    }

    @ViewBuilder
    private var coverView: some View {
        BookshelfCoverFrame(item: item, mode: .list)
    }
}
