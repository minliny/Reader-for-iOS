import SwiftUI
import ReaderUIContract

// MARK: - Slice 5c Component Views（搜索/书籍详情/书架管理扩展）
//
// 真源：contracts/fixtures/view-state.fixtures.json 的 book-search / search-home /
// search-results / search-empty / search-loading / search-error /
// book-detail-toc-preview / book-directory / group-management /
// book-batch-management / bookshelf-group-management RouteId

// MARK: - 1. SearchInputBox

struct SearchInputBoxView: View {
    let props: SearchInputBoxProps

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ReaderDesignTokens.Color.muted)
            Text(props.query?.isEmpty == false ? props.query! : "搜索书名/作者")
                .foregroundColor(props.query?.isEmpty == false ? ReaderDesignTokens.Color.ink : ReaderDesignTokens.Color.muted)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ReaderDesignTokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
    }
}

// MARK: - 2. ScopeSelector

struct ScopeSelectorView: View {
    let props: ScopeSelectorProps

    var body: some View {
        HStack(spacing: 8) {
            chip("书名", active: true)
            chip("作者", active: false)
            chip("标签", active: false)
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private func chip(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: active ? .semibold : .regular))
            .foregroundColor(active ? ReaderDesignTokens.Color.surface : ReaderDesignTokens.Color.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(active ? ReaderDesignTokens.Color.ink : ReaderDesignTokens.Color.surface)
            .clipShape(Capsule())
    }
}

// MARK: - 3. GroupSelector

struct GroupSelectorView: View {
    let props: GroupSelectorProps

    var body: some View {
        HStack(spacing: 8) {
            Text("全部分组")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundColor(ReaderDesignTokens.Color.muted)
            Image(systemName: "chevron.down")
                .font(.system(size: 10))
                .foregroundColor(ReaderDesignTokens.Color.muted)
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - 4. SearchHistoryList

struct SearchHistoryListView: View {
    let props: SearchHistoryListProps

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("搜索历史")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: .semibold))
                .foregroundColor(ReaderDesignTokens.Color.muted)
            Text("（Slice 5c 占位，后续 slice 接历史记录）")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundColor(ReaderDesignTokens.Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - 5. SearchHomePage

struct SearchHomePageView: View {
    let props: SearchHomePageProps

    var body: some View {
        VStack(spacing: ReaderDesignTokens.demoContentGap) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
                Text(props.placeholder ?? "搜索书名/作者")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(ReaderDesignTokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            Spacer()
        }
    }
}

// MARK: - 6. SearchResultsPage

struct SearchResultsPageView: View {
    let props: SearchResultsPageProps

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
                if let query = props.query {
                    Text("「\(query)」的搜索结果")
                        .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .semibold))
                        .foregroundColor(ReaderDesignTokens.Color.ink)
                }
                Text("（Slice 5c 占位，后续 slice 接搜索结果列表）")
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - 7. SearchStatePage

struct SearchStatePageView: View {
    let props: SearchStatePageProps

    var body: some View {
        VStack(spacing: ReaderDesignTokens.demoContentGap) {
            Image(systemName: iconName)
                .font(.system(size: 36))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            if let title = props.title {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .semibold))
                    .foregroundColor(ReaderDesignTokens.Color.ink)
            }
            if let message = props.message {
                Text(message)
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .multilineTextAlignment(.center)
            }
            if let action = props.action {
                Button(action) {
                    // Slice 5c 占位
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(ReaderDesignTokens.Color.ink)
                .foregroundColor(ReaderDesignTokens.Color.surface)
                .clipShape(Capsule())
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 32)
    }

    private var iconName: String {
        switch props.variant {
        case "loading": return "arrow.clockwise"
        case "error": return "exclamationmark.triangle"
        default: return "magnifyingglass"
        }
    }
}

// MARK: - 8. BookTocPreviewPage

struct BookTocPreviewPageView: View {
    let props: BookTocPreviewPageProps

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
                if let title = props.title {
                    Text(title)
                        .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.Color.ink)
                }
                Text("（Slice 5c 占位，后续 slice 接目录预览列表）")
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - 9. BookDirectoryPage

struct BookDirectoryPageView: View {
    let props: BookDirectoryPageProps

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
                Text("书籍目录")
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.ink)
                Text("（Slice 5c 占位，后续 slice 接目录树）")
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - 10. GroupManagementPage

struct GroupManagementPageView: View {
    let props: GroupManagementPageProps

    var body: some View {
        Form {
            Section("分组管理") {
                if let variant = props.variant {
                    LabeledRow(label: "模式", value: variant)
                }
                Text("（Slice 5c 占位，后续 slice 接分组列表）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - 11. BookBatchManagementPage

struct BookBatchManagementPageView: View {
    let props: BookBatchManagementPageProps

    var body: some View {
        Form {
            Section("批量管理") {
                Text("（Slice 5c 占位，后续 slice 接批量操作）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - 12. BookGroupManagementPage

struct BookGroupManagementPageView: View {
    let props: BookGroupManagementPageProps

    var body: some View {
        Form {
            Section(props.title ?? "分组") {
                Text("（Slice 5c 占位，后续 slice 接书架分组列表）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - Slice 5c Component Registration

extension ComponentRegistry {

    /// 注册 Slice 5c 的 12 个搜索/书籍详情/书架管理 component。
    public static func registerSlice5cComponents() {
        register([
            (.searchInputBox, { component in
                let props = SearchInputBoxProps(props: component.props) ?? SearchInputBoxProps(props: [:])!
                return AnyView(SearchInputBoxView(props: props))
            }),
            (.scopeSelector, { component in
                let props = ScopeSelectorProps(props: component.props) ?? ScopeSelectorProps(props: [:])!
                return AnyView(ScopeSelectorView(props: props))
            }),
            (.groupSelector, { component in
                let props = GroupSelectorProps(props: component.props) ?? GroupSelectorProps(props: [:])!
                return AnyView(GroupSelectorView(props: props))
            }),
            (.searchHistoryList, { component in
                let props = SearchHistoryListProps(props: component.props) ?? SearchHistoryListProps(props: [:])!
                return AnyView(SearchHistoryListView(props: props))
            }),
            (.searchHomePage, { component in
                let props = SearchHomePageProps(props: component.props) ?? SearchHomePageProps(props: [:])!
                return AnyView(SearchHomePageView(props: props))
            }),
            (.searchResultsPage, { component in
                let props = SearchResultsPageProps(props: component.props) ?? SearchResultsPageProps(props: [:])!
                return AnyView(SearchResultsPageView(props: props))
            }),
            (.searchStatePage, { component in
                let props = SearchStatePageProps(props: component.props) ?? SearchStatePageProps(props: [:])!
                return AnyView(SearchStatePageView(props: props))
            }),
            (.bookTocPreviewPage, { component in
                let props = BookTocPreviewPageProps(props: component.props) ?? BookTocPreviewPageProps(props: [:])!
                return AnyView(BookTocPreviewPageView(props: props))
            }),
            (.bookDirectoryPage, { component in
                let props = BookDirectoryPageProps(props: component.props) ?? BookDirectoryPageProps(props: [:])!
                return AnyView(BookDirectoryPageView(props: props))
            }),
            (.groupManagementPage, { component in
                let props = GroupManagementPageProps(props: component.props) ?? GroupManagementPageProps(props: [:])!
                return AnyView(GroupManagementPageView(props: props))
            }),
            (.bookBatchManagementPage, { component in
                let props = BookBatchManagementPageProps(props: component.props) ?? BookBatchManagementPageProps(props: [:])!
                return AnyView(BookBatchManagementPageView(props: props))
            }),
            (.bookGroupManagementPage, { component in
                let props = BookGroupManagementPageProps(props: component.props) ?? BookGroupManagementPageProps(props: [:])!
                return AnyView(BookGroupManagementPageView(props: props))
            }),
        ])
    }
}
