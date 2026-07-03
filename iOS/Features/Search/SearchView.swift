import SwiftUI
import ReaderCoreModels

public struct SearchView: View {
    private enum SearchScope: String, CaseIterable {
        case all = "全部"
        case title = "书名"
        case author = "作者"
        case source = "书源"
    }

    @StateObject private var viewModel = SearchViewModel()
    @StateObject private var bookshelfVM = BookshelfViewModel()
    @AppStorage("search_history") private var historyData: Data = Data()
    @State private var searchHistory: [String] = []
    @State private var selectedScope: SearchScope = .all
    @State private var showDemoHistoryFallback = true
    @State private var didApplyInitialQuery = false
    @State private var toastMessage: String?
    private let initialQuery: String

    public init(initialQuery: String = "") {
        self.initialQuery = initialQuery
    }

    public var body: some View {
        DemoBackScreen(title: "书籍搜索") {
            if let toastMessage {
                SearchToastCard(message: toastMessage)
            }
            searchEntry
            if shouldShowScopeChips {
                scopeChips
            }
            searchStateSurface
        } bottomActionHost: {
            bottomActions
        }
        .onAppear {
            loadSearchHistory()
            applyInitialQueryIfNeeded()
        }
        .task {
            await bookshelfVM.loadItems()
        }
    }

    private var shouldShowScopeChips: Bool {
        switch viewModel.searchState {
        case .idle:
            return false
        default:
            return true
        }
    }

    private var hasResultPhase: Bool {
        switch viewModel.searchState {
        case .success, .partial:
            return true
        default:
            return false
        }
    }

    private var firstSearchResult: SearchResultItem? {
        switch viewModel.searchState {
        case .success(let results), .partial(let results, _):
            return results.first
        default:
            return nil
        }
    }

    private var visibleHistory: [(keyword: String, meta: String)] {
        if !searchHistory.isEmpty {
            return searchHistory.map { ($0, "历史搜索") }
        }
        guard showDemoHistoryFallback else { return [] }
        return [
            ("长夜余火", "书名 · 网络"),
            ("三体", "书名 · 全部"),
            ("爱潜水的乌贼", "作者 · 网络"),
            ("本地导入", "关键词 · 本地")
        ]
    }

    private var searchEntry: some View {
        HStack(spacing: ReaderDesignTokens.searchEntryGap) {
            ReaderIcon(.search, size: 18, accessibilityLabel: "搜索")
                .frame(width: ReaderDesignTokens.searchEntryIconColumn, height: ReaderDesignTokens.searchEntryIconColumn)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)

            TextField("搜索书名、作者、关键词", text: $viewModel.keyword)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .submitLabel(.search)
                .onSubmit {
                    performSearch()
                }
        }
        .padding(.horizontal, ReaderDesignTokens.searchEntryHorizontalPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.searchEntryMinHeight)
        .background(SwiftUI.Color.white.opacity(0.58), in: Capsule())
        .overlay(Capsule().stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("书籍搜索输入")
    }

    private var scopeChips: some View {
        HStack(spacing: 8) {
            ForEach(SearchScope.allCases, id: \.self) { scope in
                Button {
                    selectScope(scope)
                } label: {
                    Text(scope.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(minWidth: 56, maxWidth: ReaderDesignTokens.chipMaxWidth, minHeight: 34)
                        .foregroundColor(selectedScope == scope ? .white : .primary)
                        .background(
                            Capsule()
                                .fill(selectedScope == scope ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.surface)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedScope == scope ? [.isButton, .isSelected] : [.isButton])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var searchStateSurface: some View {
        switch viewModel.searchState {
        case .idle:
            searchHistorySurface
        case .loading:
            SearchStateCard(title: "正在搜索", message: "正在请求书源并整理结果。", icon: .refresh, tone: .info) {
                ProgressView()
                    .tint(ReaderDesignTokens.Color.primary)
            }
        case .success(let results):
            searchResultsSurface(results: results, warnings: [])
        case .partial(let results, let warnings):
            VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
                SearchStateCard(
                    title: "部分书源返回异常",
                    message: warnings.joined(separator: "；"),
                    icon: .warning,
                    tone: .warning
                )
                searchResultsSurface(results: results, warnings: warnings)
            }
        case .empty:
            SearchStateCard(
                title: "未找到结果",
                message: "换一个关键词，或切换到全部书源后重新搜索。",
                icon: .search,
                tone: .muted
            )
        case .failed(let message):
            SearchStateCard(title: "搜索失败", message: message, icon: .warning, tone: .danger)
        case .unsupported(let reason):
            SearchStateCard(title: "当前书源不支持搜索", message: reason, icon: .warning, tone: .warning)
        }
    }

    private var searchHistorySurface: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.searchStateGap) {
            SearchSectionHeader(title: "搜索历史", actionTitle: visibleHistory.isEmpty ? nil : "清空") {
                clearSearchHistory()
            }

            if visibleHistory.isEmpty {
                Text("暂无搜索历史")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.searchHistoryRowMinHeight, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(visibleHistory, id: \.keyword) { row in
                        SearchHistoryRow(keyword: row.keyword, meta: row.meta) {
                            viewModel.keyword = row.keyword
                            saveSearchHistory(row.keyword)
                            performSearch()
                        }
                        if row.keyword != visibleHistory.last?.keyword {
                            Divider().overlay(ReaderDesignTokens.Color.readerModuleNavBorder)
                        }
                    }
                }
                .overlay(alignment: .top) {
                    Divider().overlay(ReaderDesignTokens.Color.readerModuleNavBorder)
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }

    private func searchResultsSurface(results: [SearchResultItem], warnings: [String]) -> some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.searchStateGap) {
                SearchSectionHeader(title: "搜索结果", actionTitle: nil) {}
                Text(resultSummaryText(count: results.count, warnings: warnings))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                VStack(spacing: ReaderDesignTokens.searchResultListGap) {
                    ForEach(results, id: \.detailURL) { result in
                        let source = viewModel.source(for: result) ?? viewModel.selectedSource
                        SearchResultDemoRow(
                            result: result,
                            sourceName: viewModel.sourceName(for: result),
                            isInShelf: isInBookshelf(result: result, source: source),
                            detailDestination: {
                                BookDetailView(
                                    result: result,
                                    sourceName: viewModel.sourceName(for: result),
                                    source: source
                                )
                            },
                            readerDestination: {
                                ReaderView(
                                    chapterURL: result.detailURL,
                                    chapterTitle: result.title,
                                    chapterList: [],
                                    currentChapterIndex: 0,
                                    bookID: result.detailURL,
                                    sourceID: sourceID(for: source),
                                    source: source
                                )
                            },
                            onAddToBookshelf: {
                                addToBookshelf(result: result, source: source)
                            }
                        )
                    }
                }
            }
            .padding(ReaderDesignTokens.searchStatePadding - ReaderDesignTokens.cardPadding)
        }
    }

    @ViewBuilder
    private var bottomActions: some View {
        if hasResultPhase {
            BottomFixedActionRow {
                Button {
                    resetSearch()
                } label: {
                    SearchBottomActionLabel(title: "重新搜索", isPrimary: true)
                }
                .buttonStyle(.plain)
            } trailing: {
                if let result = firstSearchResult {
                    let source = viewModel.source(for: result) ?? viewModel.selectedSource
                    NavigationLink {
                        BookDetailView(
                            result: result,
                            sourceName: viewModel.sourceName(for: result),
                            source: source
                        )
                    } label: {
                        SearchBottomActionLabel(title: "查看详情", isPrimary: false)
                    }
                    .buttonStyle(.plain)
                } else {
                    SearchBottomActionLabel(title: "查看详情", isPrimary: false, isDisabled: true)
                }
            }
        } else {
            BottomFixedActionRow {
                Button {
                    performSearch()
                } label: {
                    SearchBottomActionLabel(title: "开始搜索", isPrimary: true)
                }
                .buttonStyle(.plain)
            } trailing: {
                Button {
                    clearSearchHistory()
                } label: {
                    SearchBottomActionLabel(title: "清除历史", isPrimary: false)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func selectScope(_ scope: SearchScope) {
        selectedScope = scope
        switch scope {
        case .all:
            viewModel.selectAllEnabledSources()
        case .title, .author:
            if let selected = viewModel.selectedSource {
                viewModel.selectSource(selected)
            } else if let first = viewModel.enabledSources.first {
                viewModel.selectSource(first)
            }
        case .source:
            if let first = viewModel.enabledSources.first {
                viewModel.selectSource(first)
            }
        }
    }

    private func performSearch() {
        selectScope(selectedScope)
        saveSearchHistory(viewModel.keyword)
        Task {
            await viewModel.search()
        }
    }

    private func resetSearch() {
        viewModel.reset()
        selectedScope = .all
        showDemoHistoryFallback = searchHistory.isEmpty
    }

    private func clearSearchHistory() {
        searchHistory = []
        historyData = Data()
        showDemoHistoryFallback = false
    }

    private func addToBookshelf(result: SearchResultItem, source: BookSource?) {
        Task {
            await bookshelfVM.addOrUpdateItem(
                from: result,
                sourceID: sourceID(for: source),
                sourceName: source?.bookSourceName
            )
            showToast("已加入「\(result.title)」")
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            toastMessage = nil
        }
    }

    private func isInBookshelf(result: SearchResultItem, source: BookSource?) -> Bool {
        bookshelfVM.isInBookshelf(bookURL: result.detailURL, sourceID: sourceID(for: source))
    }

    private func sourceID(for source: BookSource?) -> String {
        source?.id ?? "unknown"
    }

    private func resultSummaryText(count: Int, warnings: [String]) -> String {
        if warnings.isEmpty {
            return "找到 \(count) 个结果 · 已标注书架状态"
        }
        return "找到 \(count) 个结果 · \(warnings.count) 条书源提示"
    }

    private func loadSearchHistory() {
        searchHistory = (try? JSONDecoder().decode([String].self, from: historyData)) ?? []
        showDemoHistoryFallback = searchHistory.isEmpty
    }

    private func applyInitialQueryIfNeeded() {
        guard !didApplyInitialQuery else { return }
        didApplyInitialQuery = true

        let trimmed = initialQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        viewModel.keyword = trimmed
        showDemoHistoryFallback = false
    }

    private func saveSearchHistory(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var history = searchHistory
        history.removeAll { $0 == trimmed }
        history.insert(trimmed, at: 0)
        if history.count > 10 {
            history = Array(history.prefix(10))
        }
        searchHistory = history
        showDemoHistoryFallback = false
        historyData = (try? JSONEncoder().encode(history)) ?? Data()
    }
}

private struct SearchSectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .heavy))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let actionTitle {
                Button(actionTitle, action: action)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(minHeight: ReaderDesignTokens.searchSectionActionMinHeight)
                    .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.08)))
                    .buttonStyle(.plain)
            }
        }
    }
}

private struct SearchHistoryRow: View {
    let keyword: String
    let meta: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ReaderDesignTokens.searchHistoryRowGap) {
                ReaderIcon(.clock, size: 16, accessibilityLabel: keyword)
                    .frame(width: ReaderDesignTokens.searchHistoryIconColumn)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                VStack(alignment: .leading, spacing: 3) {
                    Text(keyword)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(meta)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("填入")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primary)
                    .lineLimit(1)
                    .frame(width: ReaderDesignTokens.searchHistoryActionColumn, alignment: .trailing)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.searchHistoryRowMinHeight)
        }
        .buttonStyle(.plain)
    }
}

private struct SearchResultDemoRow<DetailDestination: View, ReaderDestination: View>: View {
    let result: SearchResultItem
    let sourceName: String
    let isInShelf: Bool
    let detailDestination: DetailDestination
    let readerDestination: ReaderDestination
    let onAddToBookshelf: () -> Void

    init(
        result: SearchResultItem,
        sourceName: String,
        isInShelf: Bool,
        @ViewBuilder detailDestination: () -> DetailDestination,
        @ViewBuilder readerDestination: () -> ReaderDestination,
        onAddToBookshelf: @escaping () -> Void
    ) {
        self.result = result
        self.sourceName = sourceName
        self.isInShelf = isInShelf
        self.detailDestination = detailDestination()
        self.readerDestination = readerDestination()
        self.onAddToBookshelf = onAddToBookshelf
    }

    var body: some View {
        HStack(spacing: ReaderDesignTokens.searchResultRowGap) {
            NavigationLink {
                detailDestination
            } label: {
                HStack(spacing: ReaderDesignTokens.searchResultRowGap) {
                    SearchResultCover(coverURL: result.coverURL, title: result.title)
                    resultText
                    SearchResultShelfStateLabel(isInShelf: isInShelf)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            if isInShelf {
                NavigationLink {
                    readerDestination
                } label: {
                    SearchResultActionLabel(title: "阅读")
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onAddToBookshelf) {
                    SearchResultActionLabel(title: "加入书架")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(ReaderDesignTokens.searchResultRowPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.searchResultRowMinHeight)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
                .fill(ReaderDesignTokens.Color.surface.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
                        .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                )
        )
    }

    private var resultText: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(result.title)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(.primary)
                .lineLimit(1)
            HStack(spacing: 8) {
                Text(result.author?.isEmpty == false ? result.author! : "作者待补齐")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(sourceName.isEmpty ? "当前书源" : sourceName)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primary)
                    .lineLimit(1)
                    .frame(maxWidth: 64, alignment: .leading)
            }
            Text(latestText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var latestText: String {
        let latest = result.nextPageUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !latest.isEmpty {
            return latest
        }
        let intro = result.intro?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return intro.isEmpty ? "匹配：搜索结果 · 待确认目录" : intro
    }
}

private struct SearchResultCover: View {
    let coverURL: String?
    let title: String

    var body: some View {
        Group {
            if let coverURL, let url = URL(string: coverURL) {
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
        }
        .frame(width: ReaderDesignTokens.searchResultCoverWidth, height: ReaderDesignTokens.searchResultCoverHeight)
        .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xs))
        .shadow(color: SwiftUI.Color(red: 48/255, green: 35/255, blue: 22/255, opacity: 0.16), radius: 5, x: 0, y: 4)
        .accessibilityLabel(Text("\(title)封面"))
    }

    private var placeholder: some View {
        ZStack {
            ReaderDesignTokens.Color.chipBackground
            ReaderIcon(.bookOpen, size: 20, accessibilityLabel: title)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        }
    }
}

private struct SearchResultShelfStateLabel: View {
    let isInShelf: Bool

    var body: some View {
        Text(isInShelf ? "已在书架" : "未加入")
            .font(.system(size: 10, weight: .heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 6)
            .frame(width: ReaderDesignTokens.searchResultStateColumn)
            .frame(minHeight: 24)
            .foregroundColor(isInShelf ? ReaderDesignTokens.Color.primary : .secondary)
            .background(Capsule().fill(isInShelf ? ReaderDesignTokens.Color.primary.opacity(0.10) : ReaderDesignTokens.Color.chipBackground))
    }
}

private struct SearchResultActionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .frame(width: ReaderDesignTokens.searchResultActionColumn)
            .frame(minHeight: ReaderDesignTokens.searchResultActionMinHeight)
            .foregroundColor(.white)
            .background(Capsule().fill(ReaderDesignTokens.Color.primary))
    }
}

private struct SearchBottomActionLabel: View {
    let title: String
    let isPrimary: Bool
    var isDisabled: Bool = false

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .frame(minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
            .foregroundColor(foreground)
            .background(
                Capsule()
                    .fill(background)
                    .overlay(Capsule().stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: isPrimary ? 0 : 1))
            )
            .opacity(isDisabled ? 0.58 : 1)
    }

    private var foreground: SwiftUI.Color {
        if isDisabled {
            return .secondary
        }
        return isPrimary ? .white : ReaderDesignTokens.Color.primaryDark
    }

    private var background: SwiftUI.Color {
        if isDisabled {
            return ReaderDesignTokens.Color.chipBackground
        }
        return isPrimary ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.mainNavBackground
    }
}

private enum SearchStateTone {
    case info
    case warning
    case danger
    case muted

    var foreground: SwiftUI.Color {
        switch self {
        case .info:
            return ReaderDesignTokens.Color.primaryDark
        case .warning:
            return SwiftUI.Color(red: 0.66, green: 0.38, blue: 0.08)
        case .danger:
            return SwiftUI.Color(red: 0.72, green: 0.16, blue: 0.14)
        case .muted:
            return .secondary
        }
    }

    var background: SwiftUI.Color {
        switch self {
        case .info:
            return ReaderDesignTokens.Color.primary.opacity(0.10)
        case .warning:
            return SwiftUI.Color(red: 0.96, green: 0.74, blue: 0.36, opacity: 0.18)
        case .danger:
            return SwiftUI.Color(red: 0.72, green: 0.16, blue: 0.14, opacity: 0.10)
        case .muted:
            return ReaderDesignTokens.Color.chipBackground.opacity(0.78)
        }
    }
}

private struct SearchStateCard<Accessory: View>: View {
    let title: String
    let message: String
    let icon: ReaderAssetIcon
    let tone: SearchStateTone
    let accessory: Accessory

    init(
        title: String,
        message: String,
        icon: ReaderAssetIcon,
        tone: SearchStateTone,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.tone = tone
        self.accessory = accessory()
    }

    var body: some View {
        ReaderCard {
            HStack(spacing: 10) {
                ReaderIcon(icon, size: 18, accessibilityLabel: title)
                    .foregroundColor(tone.foreground)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(tone.background))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .heavy))
                        .lineLimit(1)
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                accessory
            }
            .padding(ReaderDesignTokens.searchStatePadding - ReaderDesignTokens.cardPadding)
        }
    }
}

private extension SearchStateCard where Accessory == EmptyView {
    init(title: String, message: String, icon: ReaderAssetIcon, tone: SearchStateTone) {
        self.init(title: title, message: message, icon: icon, tone: tone) {
            EmptyView()
        }
    }
}

private struct SearchToastCard: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .heavy))
            .foregroundColor(.white)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md).fill(ReaderDesignTokens.Color.primaryDark))
    }
}
