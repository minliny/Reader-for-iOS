import ReaderDesign
import ReaderHost
import SwiftUI

struct GlobalSearchContent: View {
    @Binding var query: String
    let history: [String]
    let rows: [OnlineBookReference]
    var busy = false
    var stopped = false
    var hasSearched = true
    var failed = false
    var onSearch: (String) -> Void = { _ in }
    var onStop: () -> Void = {}
    var onRetry: () -> Void = {}
    var onOpen: (OnlineBookReference) -> Void = { _ in }
    var network: NetworkAndWebHost? = nil
    @Environment(\.readerTheme) private var theme
    @FocusState private var editing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceMedium)) {
            searchBar
                .padding(.horizontal, CGFloat(ReaderDesignMetrics.searchResultOuterInset))
            if busy || stopped || hasSearched {
                status
                    .padding(.horizontal, CGFloat(ReaderDesignMetrics.searchResultOuterInset))
            }
            if rows.isEmpty {
                if busy && !stopped {
                    PageState(state: .loading)
                } else if !hasSearched && !stopped && !failed && !history.isEmpty {
                    historyList
                } else {
                    PageState(state: emptyState) { _ in onRetry() }
                }
            } else {
                results
            }
        }
        .padding(.top, CGFloat(ReaderDesignMetrics.spaceSmall))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.background)
    }

    private var emptyState: ReaderPageState {
        if failed { return .failed("暂时无法搜索在线书籍。", actionGeneration: 0) }
        if stopped { return .empty("停止前暂无可展示的结果") }
        return .empty(hasSearched ? "没有找到相关在线书籍" : "输入书名或作者搜索在线书籍")
    }

    private var searchBar: some View {
        HStack(spacing: CGFloat(ReaderDesignMetrics.controlInlineSpacing)) {
            HStack(spacing: CGFloat(ReaderDesignMetrics.spaceExtraSmall)) {
                ReaderIcon(ReaderIconRegistry.search)
                    .font(.system(size: CGFloat(ReaderDesignMetrics.searchFilterIconSize)))
                    .foregroundStyle(theme.secondaryText)
                TextField("书名或作者", text: $query)
                    .readerTypography(ReaderDesignMetrics.searchFieldText)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .focused($editing)
                    .onSubmit { submit(query) }
                    .accessibilityIdentifier("m2-search-field")
                if !query.isEmpty {
                    Button {
                        query = ""
                        editing = true
                    } label: {
                        ReaderIcon(ReaderIconRegistry.close)
                            .frame(minWidth: 28, minHeight: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清空搜索词")
                }
            }
            .padding(.horizontal, CGFloat(ReaderDesignMetrics.spaceSmall))
            .frame(minHeight: CGFloat(ReaderDesignMetrics.minimumActionTarget))
            .background(theme.field, in: .rect(cornerRadius: CGFloat(ReaderDesignMetrics.inputRadius)))
            Button("搜索") { submit(query) }
                .readerTypography(ReaderDesignMetrics.rowLabel)
                .padding(.horizontal, CGFloat(ReaderDesignMetrics.spaceMedium))
                .frame(minHeight: CGFloat(ReaderDesignMetrics.minimumActionTarget))
                .foregroundStyle(theme.onAccent)
                .background(theme.accentFill, in: Capsule())
                .buttonStyle(.plain)
                .disabled(busy || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("m2-search-submit")
        }
    }

    private var status: some View {
        HStack {
            Text(stopped ? (busy ? "已停止展示，正在核对原请求" : "搜索已停止") :
                    (busy ? "正在搜索在线书籍" : "搜索结果 · \(rows.count)"))
                .readerTypography(ReaderDesignMetrics.sectionHeading)
                .foregroundStyle(theme.secondaryText)
            Spacer()
            if busy && !stopped {
                Button("停止展示", action: onStop)
                    .accessibilityIdentifier("m2-search-stop")
            } else if hasSearched || stopped {
                Button("重新搜索", action: onRetry)
                    .disabled(busy)
                    .accessibilityIdentifier("m2-search-retry")
            }
        }
        .readerTypography(ReaderDesignMetrics.searchFieldText)
        .frame(minHeight: CGFloat(ReaderDesignMetrics.compactControlHeight))
    }

    private var historyList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.rowBlockSpacing)) {
                Label { Text("搜索历史") } icon: { ReaderIcon(ReaderIconRegistry.history) }
                    .readerTypography(ReaderDesignMetrics.sectionHeading)
                    .foregroundStyle(theme.secondaryText)
                ForEach(history, id: \.self) { keyword in
                    Button { submit(keyword) } label: {
                        HStack {
                            Text(keyword).readerTypography(ReaderDesignMetrics.rowLabel)
                            Spacer()
                            ReaderIcon(ReaderIconRegistry.search).foregroundStyle(theme.mutedText)
                        }
                        .frame(minHeight: CGFloat(ReaderDesignMetrics.minimumActionTarget))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
            .padding(.horizontal, CGFloat(ReaderDesignMetrics.searchResultOuterInset))
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var results: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= CGFloat(ReaderDesignMetrics.wideBreakpoint)
            ScrollView {
                LazyVGrid(columns: .init(repeating: GridItem(.flexible()), count: wide ? 2 : 1),
                          spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, book in
                        Button { onOpen(book) } label: {
                            result(book, wide: wide)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("m2-search-result-\(index)")
                    }
                }
                .padding(.horizontal, CGFloat(ReaderDesignMetrics.searchResultOuterInset))
                .padding(.bottom, CGFloat(ReaderDesignMetrics.spaceMedium))
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func result(_ book: OnlineBookReference, wide: Bool) -> some View {
        let width = CGFloat(wide ? ReaderDesignMetrics.searchResultCoverExpandedMaxWidth :
                                 ReaderDesignMetrics.searchResultCoverCompactMaxWidth)
        return HStack(alignment: .top, spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
            OnlineBookCover(book: book, width: width, height: width * ReaderDesignMetrics.searchResultCoverAspect,
                            radius: CGFloat(ReaderDesignMetrics.badgeRadius), network: network)
            VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.rowBlockSpacing)) {
                Text(book.title).readerTypography(ReaderDesignMetrics.onlineBookResultTitle)
                    .foregroundStyle(theme.primaryText).lineLimit(2)
                Text([book.author, book.displaySource].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .readerTypography(ReaderDesignMetrics.searchResultAuthor)
                    .foregroundStyle(theme.secondaryText).lineLimit(1)
                if let lastChapter = book.lastChapter, !lastChapter.isEmpty {
                    Text(lastChapter).readerTypography(ReaderDesignMetrics.searchResultChapter)
                        .foregroundStyle(theme.accent).lineLimit(1)
                }
                if let intro = book.intro, !intro.isEmpty {
                    Text(intro).readerTypography(ReaderDesignMetrics.searchResultIntro)
                        .foregroundStyle(theme.secondaryText).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ReaderIcon(ReaderIconRegistry.drillIn).foregroundStyle(theme.mutedText)
                .padding(.top, CGFloat(ReaderDesignMetrics.spaceExtraSmall))
        }
        .multilineTextAlignment(.leading)
        .padding(CGFloat(ReaderDesignMetrics.cardPadding))
        .background(theme.surface, in: .rect(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
        .contentShape(Rectangle())
    }

    private func submit(_ keyword: String) {
        editing = false
        onSearch(keyword)
    }
}
