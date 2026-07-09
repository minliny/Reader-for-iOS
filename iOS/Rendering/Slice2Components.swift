import SwiftUI
import ReaderUIContract

// MARK: - Slice 2 Component Views
//
// 书架→沉浸阅读链路的 10 个 component view。
// 真源：contracts/fixtures/view-state.fixtures.json 的 bookshelf / immersive-reading RouteId
//
// 设计：
// - 每个 view 从 ViewStateComponent.props 解码为强类型 Props（ComponentProps 协议）
// - 容器 view（BookshelfShelfSection / BookGrid）通过 ChildrenView 递归渲染 children
// - BottomNav 渲染纯视觉 tab bar，交互由 shell 层处理
// - ReaderBase 按 theme 选择背景色 token
// - ReadingTextFlow 用 ReaderTextPaginator 分页（阶段 1 骨架，无 engine 时返回单页）

// MARK: - 1. AppTopBar

struct AppTopBarView: View {
    let props: AppTopBarProps

    var body: some View {
        DemoTopBar(title: props.title)
    }
}

// MARK: - 2. ContinueReadingCard

struct ContinueReadingCardView: View {
    let props: ContinueReadingCardProps

    var body: some View {
        HStack(spacing: ReaderDesignTokens.demoContentGap) {
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm)
                .fill(ReaderDesignTokens.Color.chipBackground)
                .frame(width: 44, height: 62)

            VStack(alignment: .leading, spacing: 4) {
                Text(props.title)
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.ink)
                    .lineLimit(1)
                Text(props.author)
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
        }
        .padding(ReaderDesignTokens.cardPadding)
        .background(ReaderDesignTokens.Color.surface)
    }
}

// MARK: - 3. BookshelfShelfSection

struct BookshelfShelfSectionView: View {
    let props: BookshelfShelfSectionProps
    let children: [ViewStateComponent]?

    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
            ChildrenView(children)
        }
    }
}

// MARK: - 4. ShelfSectionHeader

struct ShelfSectionHeaderView: View {
    let props: ShelfSectionHeaderProps

    var body: some View {
        HStack {
            Text(props.title)
                .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                .foregroundColor(ReaderDesignTokens.Color.ink)
            Spacer()
            Image(systemName: props.viewMode == "cover" ? "square.grid.2x2" : "list.bullet")
                .font(.system(size: 14))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
        }
    }
}

// MARK: - 5. BookGrid

struct BookGridView: View {
    let props: BookGridProps
    let children: [ViewStateComponent]?

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: ReaderDesignTokens.bookGridColumnSpacing),
        count: ReaderDesignTokens.bookGridColumns
    )

    var body: some View {
        if props.viewMode == "list" {
            VStack(spacing: ReaderDesignTokens.bookGridListRowSpacing) {
                ChildrenView(children)
            }
        } else {
            LazyVGrid(columns: columns, spacing: ReaderDesignTokens.bookGridRowSpacing) {
                ChildrenView(children)
            }
        }
    }
}

// MARK: - 6. BookCard

struct BookCardView: View {
    let props: BookCardProps

    var body: some View {
        VStack(spacing: ReaderDesignTokens.bookCardGap) {
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm)
                .fill(ReaderDesignTokens.Color.chipBackground)
                .aspectRatio(3, contentMode: .fit)

            Text(props.title)
                .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .medium))
                .foregroundColor(ReaderDesignTokens.Color.ink)
                .lineLimit(ReaderDesignTokens.bookCardTitleLineLimit)
                .multilineTextAlignment(.center)

            Text(props.author)
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
                .lineLimit(1)
        }
    }
}

// MARK: - 7. BookListItem

struct BookListItemView: View {
    let props: BookListItemProps

    var body: some View {
        HStack(spacing: ReaderDesignTokens.demoContentGap) {
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm)
                .fill(ReaderDesignTokens.Color.chipBackground)
                .frame(width: 46, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(props.title)
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .medium))
                    .foregroundColor(ReaderDesignTokens.Color.ink)
                    .lineLimit(1)
                Text(props.author)
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - 8. ReaderBase

struct ReaderBaseView: View {
    let props: ReaderBaseProps

    var body: some View {
        backgroundColor.ignoresSafeArea()
    }

    private var backgroundColor: Color {
        switch props.theme {
        case "paper", "paper-night":
            return ReaderDesignTokens.Color.paperSolid
        case "warm", "warm-night":
            return ReaderDesignTokens.Color.paperSolidAlt
        default:
            return ReaderDesignTokens.Color.paperSolid
        }
    }
}

// MARK: - 9. ReadingTextFlow

struct ReadingTextFlowView: View {
    let props: ReadingTextFlowProps

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.bookCardGap) {
                Text("正在加载 \(props.bookId)…")
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - 10. BottomNav

struct BottomNavView: View {
    let props: BottomNavProps

    var body: some View {
        let selectedTab = appTab(from: props.selected)
        FloatingTabBar(
            tabs: [.bookshelf, .discover, .rss, .settings],
            selection: .constant(selectedTab),
            onSelect: { _ in }
        )
    }

    private func appTab(from raw: String) -> AppTab {
        switch raw {
        case "discover": return .discover
        case "rss":      return .rss
        case "settings": return .settings
        default:         return .bookshelf
        }
    }
}

// MARK: - Slice 2 Component Registration

extension ComponentRegistry {

    /// 注册 Slice 2 的 10 个 component。
    /// 应在 App 启动时调用（如 ReaderApp.init）。
    public static func registerSlice2Components() {
        register([
            (.appTopBar, { component in
                guard let props = AppTopBarProps(props: component.props) else {
                    return AnyView(EmptyView())
                }
                return AnyView(AppTopBarView(props: props))
            }),
            (.continueReadingCard, { component in
                guard let props = ContinueReadingCardProps(props: component.props) else {
                    return AnyView(EmptyView())
                }
                return AnyView(ContinueReadingCardView(props: props))
            }),
            (.bookshelfShelfSection, { component in
                guard let props = BookshelfShelfSectionProps(props: component.props) else {
                    return AnyView(EmptyView())
                }
                return AnyView(BookshelfShelfSectionView(props: props, children: component.children))
            }),
            (.shelfSectionHeader, { component in
                guard let props = ShelfSectionHeaderProps(props: component.props) else {
                    return AnyView(EmptyView())
                }
                return AnyView(ShelfSectionHeaderView(props: props))
            }),
            (.bookGrid, { component in
                guard let props = BookGridProps(props: component.props) else {
                    return AnyView(EmptyView())
                }
                return AnyView(BookGridView(props: props, children: component.children))
            }),
            (.bookCard, { component in
                guard let props = BookCardProps(props: component.props) else {
                    return AnyView(EmptyView())
                }
                return AnyView(BookCardView(props: props))
            }),
            (.bookListItem, { component in
                guard let props = BookListItemProps(props: component.props) else {
                    return AnyView(EmptyView())
                }
                return AnyView(BookListItemView(props: props))
            }),
            (.readerBase, { component in
                guard let props = ReaderBaseProps(props: component.props) else {
                    return AnyView(EmptyView())
                }
                return AnyView(ReaderBaseView(props: props))
            }),
            (.readingTextFlow, { component in
                guard let props = ReadingTextFlowProps(props: component.props) else {
                    return AnyView(EmptyView())
                }
                return AnyView(ReadingTextFlowView(props: props))
            }),
            (.bottomNav, { component in
                guard let props = BottomNavProps(props: component.props) else {
                    return AnyView(EmptyView())
                }
                return AnyView(BottomNavView(props: props))
            }),
        ])
    }
}
