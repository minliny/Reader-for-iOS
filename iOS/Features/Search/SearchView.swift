import SwiftUI
import ReaderCoreModels
import ReaderShellValidation

public struct SearchView: View {
    private enum SearchDestination {
        case detail(SearchResultItem, String, BookSource?)
        case reader(SearchResultItem, BookSource?)
    }

    private enum SearchScope: String, CaseIterable {
        case all = "全部"
        case title = "书名"
        case author = "作者"
        case source = "书源"
    }

    @StateObject private var viewModel: SearchViewModel
    @StateObject private var bookshelfVM = BookshelfViewModel()
    @State private var searchHistory: [String] = []
    @State private var searchHistoryFailure: String?
    @State private var selectedScope: SearchScope = .all
    @State private var didApplyInitialQuery = false
    @State private var toastMessage: String?
    @State private var activeDestination: SearchDestination?
    private let initialQuery: String
    private let onExit: (() -> Void)?

    public init(initialQuery: String = "", onExit: (() -> Void)? = nil) {
        self.init(initialQuery: initialQuery, demoState: .idle, onExit: onExit)
    }

    init(initialQuery: String = "", demoState: SearchState, onExit: (() -> Void)? = nil) {
        self._viewModel = StateObject(
            wrappedValue: SearchViewModel(initialKeyword: initialQuery, initialSearchState: demoState)
        )
        self.initialQuery = initialQuery
        self.onExit = onExit
    }

    public var body: some View {
        ZStack {
            switch activeDestination {
            case .some(.detail(let result, let sourceName, let source)):
                BookDetailView(result: result, sourceName: sourceName, source: source) {
                    activeDestination = nil
                }
            case .some(.reader(let result, let source)):
                ReaderView(
                    chapterURL: result.detailURL,
                    chapterTitle: result.title,
                    chapterList: [],
                    currentChapterIndex: 0,
                    bookID: result.detailURL,
                    sourceID: sourceID(for: source),
                    source: source,
                    bookName: result.title,
                    bookAuthor: result.author,
                    onExit: { activeDestination = nil }
                )
            case .none:
                searchShell
            }
        }
        .onAppear { applyInitialQueryIfNeeded() }
        .task { await loadSearchHistory() }
        .task {
            await bookshelfVM.loadItems()
        }
    }

    private var searchShell: some View {
        DemoBackScreen(title: "书籍搜索", onBack: onExit) {
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
        searchHistory.map { ($0, "Core 搜索历史") }
    }

    private var searchEntry: some View {
        Button {
            performSearch()
        } label: {
            HStack(spacing: ReaderDesignTokens.searchEntryGap) {
                ReaderIcon(.search, size: 18, accessibilityLabel: "搜索")
                    .frame(width: ReaderDesignTokens.searchEntryIconColumn, height: ReaderDesignTokens.searchEntryIconColumn)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                Text(searchEntryText)
                    .font(.system(size: ReaderDesignTokens.readerSectionTitleFontSize, weight: viewModel.keyword.isEmpty ? .medium : .semibold))
                    .foregroundStyle(viewModel.keyword.isEmpty ? ReaderDesignTokens.Color.muted : ReaderDesignTokens.Color.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !viewModel.keyword.isEmpty {
                    ReaderIcon(.clear, size: 14, accessibilityLabel: "清空搜索")
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                }
            }
        }
        .buttonStyle(DemoPressButtonStyle())
        .padding(.horizontal, ReaderDesignTokens.searchEntryHorizontalPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.searchEntryMinHeight)
        .background(ReaderDesignTokens.Color.overlayWhite58, in: Capsule())
        .overlay(Capsule().stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("书籍搜索输入")
    }

    private var searchEntryText: String {
        let keyword = viewModel.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        return keyword.isEmpty ? "搜索书名、作者、关键词" : keyword
    }

    private var scopeChips: some View {
        HStack(spacing: 8) {
            ForEach(SearchScope.allCases, id: \.self) { scope in
                Button {
                    selectScope(scope)
                } label: {
                    Text(scope.rawValue)
                        .font(.system(size: ReaderDesignTokens.readerSectionTitleFontSize, weight: .bold))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(minWidth: 56, maxWidth: ReaderDesignTokens.chipMaxWidth, minHeight: 34)
                        .foregroundColor(selectedScope == scope ? .white : ReaderDesignTokens.Color.ink)
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
                DemoLoadingSpinner(size: .reader)
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

            if let searchHistoryFailure {
                SearchStateCard(
                    title: "搜索历史暂不可用",
                    message: searchHistoryFailure,
                    icon: .warning,
                    tone: .warning
                )
            } else if visibleHistory.isEmpty {
                Text("暂无搜索历史")
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.searchHistoryRowMinHeight, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(visibleHistory, id: \.keyword) { row in
                        SearchHistoryRow(keyword: row.keyword, meta: row.meta) {
                            viewModel.keyword = row.keyword
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
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineLimit(2)

                VStack(spacing: ReaderDesignTokens.searchResultListGap) {
                    ForEach(results, id: \.detailURL) { result in
                        let source = viewModel.source(for: result) ?? viewModel.selectedSource
                        SearchResultDemoRow(
                            result: result,
                            sourceName: viewModel.sourceName(for: result),
                            isInShelf: isInBookshelf(result: result, source: source),
                            onOpenDetail: {
                                activeDestination = .detail(result, viewModel.sourceName(for: result), source)
                            },
                            onRead: {
                                activeDestination = .reader(result, source)
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
                    Button {
                        activeDestination = .detail(result, viewModel.sourceName(for: result), source)
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
        let keyword = viewModel.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            showToast("请输入搜索关键词")
            return
        }
        selectScope(selectedScope)
        Task {
            await saveSearchHistory(keyword)
            await viewModel.search()
        }
    }

    private func resetSearch() {
        viewModel.reset()
        selectedScope = .all
    }

    private func clearSearchHistory() {
        Task {
            do {
                let service = try ReaderSlice10CoreService.production()
                _ = try await service.clearSearchHistory(correlationID: "search-history-clear:\(UUID().uuidString)")
                guard !Task.isCancelled else { return }
                searchHistory = []
                searchHistoryFailure = nil
            } catch is CancellationError {
                return
            } catch {
                searchHistoryFailure = error.localizedDescription
            }
        }
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

    @MainActor
    private func loadSearchHistory() async {
        do {
            let service = try ReaderSlice10CoreService.production()
            let keywords = try await service.listSearchHistory(
                limit: 10,
                correlationID: "search-history-list:\(UUID().uuidString)"
            )
            guard !Task.isCancelled else { return }
            searchHistory = keywords
            searchHistoryFailure = nil
        } catch is CancellationError {
            return
        } catch {
            searchHistory = []
            searchHistoryFailure = error.localizedDescription
        }
    }

    private func applyInitialQueryIfNeeded() {
        guard !didApplyInitialQuery else { return }
        didApplyInitialQuery = true

        let trimmed = initialQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        viewModel.keyword = trimmed
    }

    @MainActor
    private func saveSearchHistory(_ keyword: String) async {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let service = try ReaderSlice10CoreService.production()
            try await service.addSearchHistory(
                trimmed,
                correlationID: "search-history-add:\(UUID().uuidString)"
            )
            guard !Task.isCancelled else { return }
            searchHistory = try await service.listSearchHistory(
                limit: 10,
                correlationID: "search-history-refresh:\(UUID().uuidString)"
            )
            searchHistoryFailure = nil
        } catch is CancellationError {
            return
        } catch {
            searchHistoryFailure = error.localizedDescription
        }
    }
}

private struct SearchSectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: ReaderDesignTokens.readerTopTitleFontSize, weight: .heavy))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let actionTitle {
                Button(actionTitle, action: action)
                    .font(.system(size: ReaderDesignTokens.chipFontSize, weight: .black))
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
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.ink)
                        .lineLimit(1)
                    Text(meta)
                        .font(.system(size: ReaderDesignTokens.rssArticleRowBodyFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("填入")
                    .font(.system(size: ReaderDesignTokens.chipFontSize, weight: .black))
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

private struct SearchResultDemoRow: View {
    let result: SearchResultItem
    let sourceName: String
    let isInShelf: Bool
    let onOpenDetail: () -> Void
    let onRead: () -> Void
    let onAddToBookshelf: () -> Void

    init(
        result: SearchResultItem,
        sourceName: String,
        isInShelf: Bool,
        onOpenDetail: @escaping () -> Void,
        onRead: @escaping () -> Void,
        onAddToBookshelf: @escaping () -> Void
    ) {
        self.result = result
        self.sourceName = sourceName
        self.isInShelf = isInShelf
        self.onOpenDetail = onOpenDetail
        self.onRead = onRead
        self.onAddToBookshelf = onAddToBookshelf
    }

    var body: some View {
        HStack(spacing: ReaderDesignTokens.searchResultRowGap) {
            Button {
                onOpenDetail()
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
                Button {
                    onRead()
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
                        .stroke(ReaderDesignTokens.Color.searchResultBorder, lineWidth: 1)
                )
        )
    }

    private var resultText: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(result.title)
                .font(.system(size: ReaderDesignTokens.readerSectionTitleFontSize, weight: .heavy))
                .foregroundColor(ReaderDesignTokens.Color.ink)
                .lineLimit(1)
            HStack(spacing: 8) {
                Text(result.author?.isEmpty == false ? result.author! : "作者待补齐")
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .bold))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineLimit(1)
                Text(sourceName.isEmpty ? "当前书源" : sourceName)
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primary)
                    .lineLimit(1)
                    .frame(maxWidth: 64, alignment: .leading)
            }
            Text(latestText)
                .font(.system(size: ReaderDesignTokens.rssArticleRowBodyFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
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
        // demo `.fd-search-result-row img`: 0 5px 10px rgba(48,35,22,0.16)
        .shadow(color: ReaderDesignTokens.Color.Shadow.insetAlt, radius: 10, x: 0, y: 5)
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
            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .black))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 6)
            .frame(width: ReaderDesignTokens.searchResultStateColumn)
            .frame(minHeight: 24)
            .foregroundColor(isInShelf ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.muted)
            .background(Capsule().fill(isInShelf ? ReaderDesignTokens.Color.primary.opacity(0.10) : ReaderDesignTokens.Color.chipBackground))
    }
}

private struct SearchResultActionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
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
            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
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
            return ReaderDesignTokens.Color.muted
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
            return ReaderDesignTokens.Color.Semantic.warning
        case .danger:
            return ReaderDesignTokens.Color.Semantic.danger
        case .muted:
            return ReaderDesignTokens.Color.muted
        }
    }

    var background: SwiftUI.Color {
        switch self {
        case .info:
            return ReaderDesignTokens.Color.primary.opacity(0.10)
        case .warning:
            return ReaderDesignTokens.Color.Semantic.warningTint
        case .danger:
            return ReaderDesignTokens.Color.Semantic.danger.opacity(0.10)
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
                        .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                        .lineLimit(1)
                    Text(message)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
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
            .font(.system(size: ReaderDesignTokens.chipFontSize, weight: .black))
            .foregroundColor(.white)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md).fill(ReaderDesignTokens.Color.primaryDark))
    }
}
