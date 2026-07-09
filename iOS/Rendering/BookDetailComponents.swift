import SwiftUI
import ReaderUIContract

// MARK: - BackTopBar + BookDetail Component Views（B1-iOS P0 核心接线）
//
// 补齐两个系统性缺口：
// 1. `BackTopBar` ComponentType 此前未在任何 slice 注册，LibraryShell / FlowShell /
//    SettingsShell 渲染时落 `EmptyView`。本文件注册 BackTopBar → BackTopBarView。
// 2. `book-detail` RouteId 在 `ViewStateComponentFactory` 中落入 `default` 返回空数组，
//    contract renderer 无组件可渲染。本文件注册 book-detail 系列组件并暴露
//    `registerBookDetailComponents()` 供 `bootstrapAllSlices()` 调用。
//
// 设计：
// - 颜色一律走 `ReaderTokenAdapter`，不使用 raw `Color.black` / `.white`。
// - 视图为纯展示层，返回栏的 back 动作由 shell 层（AppShellView contract-host）统一处理。
// - book-detail 组件树对齐 `view-state.fixtures.json` 的 book-detail fixture：
//   BackTopBar + BookHero(BookCover + BookTitleAuthor + SourceStatus) + BookIntro +
//   DirectoryPreview + ReadButton + AddToShelfButton。

// MARK: - BackTopBar

/// 二级页返回栏。显示返回箭头 + 标题。
/// 真源：`frontend-demo-optimized/styles/01-shell-layout.css` `.fd-back-bar`
public struct BackTopBarView: View {
    private let props: BackTopBarProps
    public init(props: BackTopBarProps) { self.props = props }

    public var body: some View {
        HStack(spacing: ReaderDesignTokens.demoContentGap) {
            Image(systemName: "chevron.left")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: .semibold))
                .foregroundColor(ReaderTokenAdapter.color(named: "--fd-ds-color-primary") ?? ReaderDesignTokens.Color.primary)
            Text(props.title)
                .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                .foregroundColor(ReaderTokenAdapter.color(named: "--fd-ds-color-ink") ?? ReaderDesignTokens.Color.ink)
                .lineLimit(1)
            Spacer()
        }
        .frame(height: ReaderDesignTokens.topBarMinHeight)
        .padding(.horizontal, ReaderDesignTokens.demoContentHorizontalPadding)
        .background(ReaderTokenAdapter.color(named: "--fd-ds-color-surface") ?? ReaderDesignTokens.Color.surface)
        .accessibilityIdentifier("back-top-bar")
    }
}

// MARK: - BookDetail Props

/// `BookHero` props（book-detail fixture：`{ title, author, coverKey? }`）
public struct BookHeroProps: ComponentProps {
    public let title: String
    public let author: String
    public let coverKey: String?
    public init?(props: [String: AnyCodable]?) {
        guard let title = props?.string("title"),
              let author = props?.string("author") else { return nil }
        self.title = title
        self.author = author
        self.coverKey = props?.string("coverKey")
    }
}

/// `BookCover` props（book-detail fixture：`{ coverKey? }`）
public struct BookCoverProps: ComponentProps {
    public let coverKey: String?
    public init?(props: [String: AnyCodable]?) {
        self.coverKey = props?.string("coverKey")
    }
}

/// `BookTitleAuthor` props（book-detail fixture：`{ title, author }`）
public struct BookTitleAuthorProps: ComponentProps {
    public let title: String
    public let author: String
    public init?(props: [String: AnyCodable]?) {
        guard let title = props?.string("title"),
              let author = props?.string("author") else { return nil }
        self.title = title
        self.author = author
    }
}

/// `SourceStatus` props（book-detail fixture：`{ sourceName? }`）
public struct SourceStatusProps: ComponentProps {
    public let sourceName: String?
    public init?(props: [String: AnyCodable]?) {
        self.sourceName = props?.string("sourceName")
    }
}

/// `BookIntro` props（book-detail fixture：`{ intro? }`）
public struct BookIntroProps: ComponentProps {
    public let intro: String?
    public init?(props: [String: AnyCodable]?) {
        self.intro = props?.string("intro")
    }
}

/// `DirectoryPreview` props（book-detail fixture：`{ chapterCount? }`）
public struct DirectoryPreviewProps: ComponentProps {
    public let chapterCount: Int?
    public init?(props: [String: AnyCodable]?) {
        self.chapterCount = props?.int("chapterCount")
    }
}

/// `ReadButton` props（book-detail fixture：`{}`）
public struct ReadButtonProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `AddToShelfButton` props（book-detail fixture：`{}`）
public struct AddToShelfButtonProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

// MARK: - BookDetail Component Views

/// 书籍详情头部：封面 + 标题/作者 + 来源状态。
public struct BookHeroView: View {
    private let props: BookHeroProps
    private let children: [ViewStateComponent]?
    public init(props: BookHeroProps, children: [ViewStateComponent]?) {
        self.props = props
        self.children = children
    }
    public var body: some View {
        HStack(alignment: .top, spacing: ReaderDesignTokens.bookDetailHeroGap) {
            ChildrenView(children)
        }
        .padding(ReaderDesignTokens.bookDetailHeroPadding)
    }
}

public struct BookCoverView: View {
    private let props: BookCoverProps
    public init(props: BookCoverProps) { self.props = props }
    public var body: some View {
        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm)
            .fill(ReaderTokenAdapter.color(named: "--fd-ds-color-surface-soft") ?? ReaderDesignTokens.Color.chipBackground)
            .frame(width: ReaderDesignTokens.bookDetailHeroCoverWidth,
                   height: ReaderDesignTokens.bookDetailHeroCoverHeight)
            .accessibilityIdentifier("book-cover")
    }
}

public struct BookTitleAuthorView: View {
    private let props: BookTitleAuthorProps
    public init(props: BookTitleAuthorProps) { self.props = props }
    public var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.bookDetailSummaryGap) {
            Text(props.title)
                .font(.system(size: ReaderDesignTokens.readerOverlayLargeTitleFontSize, weight: .heavy))
                .foregroundColor(ReaderTokenAdapter.color(named: "--fd-ds-color-ink") ?? ReaderDesignTokens.Color.ink)
            Text(props.author)
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundColor(ReaderTokenAdapter.color(named: "--fd-ds-color-muted") ?? ReaderDesignTokens.Color.muted)
            Spacer(minLength: 0)
        }
    }
}

public struct SourceStatusView: View {
    private let props: SourceStatusProps
    public init(props: SourceStatusProps) { self.props = props }
    public var body: some View {
        Text(props.sourceName.map { "来源：\($0)" } ?? "来源：默认")
            .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
            .foregroundColor(ReaderTokenAdapter.color(named: "--fd-ds-color-muted") ?? ReaderDesignTokens.Color.muted)
    }
}

public struct BookIntroView: View {
    private let props: BookIntroProps
    public init(props: BookIntroProps) { self.props = props }
    public var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.bookDetailSummaryGap) {
            Text("简介")
                .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .semibold))
                .foregroundColor(ReaderTokenAdapter.color(named: "--fd-ds-color-ink") ?? ReaderDesignTokens.Color.ink)
            Text(props.intro ?? "暂无简介")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundColor(ReaderTokenAdapter.color(named: "--fd-ds-color-muted") ?? ReaderDesignTokens.Color.muted)
                .lineLimit(4)
        }
        .padding(.horizontal, ReaderDesignTokens.bookDetailSummaryPadding)
    }
}

public struct DirectoryPreviewView: View {
    private let props: DirectoryPreviewProps
    public init(props: DirectoryPreviewProps) { self.props = props }
    public var body: some View {
        HStack {
            Text("目录预览")
                .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .semibold))
                .foregroundColor(ReaderTokenAdapter.color(named: "--fd-ds-color-ink") ?? ReaderDesignTokens.Color.ink)
            Spacer()
            Text("共 \(props.chapterCount ?? 0) 章")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundColor(ReaderTokenAdapter.color(named: "--fd-ds-color-muted") ?? ReaderDesignTokens.Color.muted)
        }
        .frame(minHeight: ReaderDesignTokens.bookDetailChapterPreviewHeaderMinHeight)
        .padding(.horizontal, ReaderDesignTokens.bookDetailSummaryPadding)
    }
}

public struct ReadButtonView: View {
    private let props: ReadButtonProps
    public init(props: ReadButtonProps) { self.props = props }
    public var body: some View {
        Text("开始阅读")
            .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: .heavy))
            .foregroundColor(ReaderTokenAdapter.color(named: "--fd-ds-color-surface") ?? ReaderDesignTokens.Color.surface)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookDetailInlineRouteMinHeight)
            .background(ReaderTokenAdapter.color(named: "--fd-ds-color-primary") ?? ReaderDesignTokens.Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm))
            .padding(.horizontal, ReaderDesignTokens.bookDetailSummaryPadding)
            .accessibilityIdentifier("book-read-button")
    }
}

public struct AddToShelfButtonView: View {
    private let props: AddToShelfButtonProps
    public init(props: AddToShelfButtonProps) { self.props = props }
    public var body: some View {
        Text("加入书架")
            .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: .heavy))
            .foregroundColor(ReaderTokenAdapter.color(named: "--fd-ds-color-primary") ?? ReaderDesignTokens.Color.primary)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookDetailInlineRouteMinHeight)
            .background(ReaderTokenAdapter.color(named: "--fd-ds-color-surface-soft") ?? ReaderDesignTokens.Color.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm))
            .padding(.horizontal, ReaderDesignTokens.bookDetailSummaryPadding)
            .accessibilityIdentifier("book-add-to-shelf-button")
    }
}

// MARK: - BookDetail + BackTopBar Component Registration

extension ComponentRegistry {

    /// 注册 BackTopBar 与 book-detail 系列组件。
    /// 由 `bootstrapAllSlices()` 调用；幂等由 bootstrap 标记保证。
    public static func registerBookDetailComponents() {
        register([
            (.backTopBar, { component in
                let props = BackTopBarProps(props: component.props)
                    ?? BackTopBarProps(props: ["title": .init("返回")])!
                return AnyView(BackTopBarView(props: props))
            }),
            (.bookHero, { component in
                let props = BookHeroProps(props: component.props)
                    ?? BookHeroProps(props: ["title": .init("未知书名"), "author": .init("未知作者")])!
                return AnyView(BookHeroView(props: props, children: component.children))
            }),
            (.bookCover, { component in
                let props = BookCoverProps(props: component.props) ?? BookCoverProps(props: [:])!
                return AnyView(BookCoverView(props: props))
            }),
            (.bookTitleAuthor, { component in
                let props = BookTitleAuthorProps(props: component.props)
                    ?? BookTitleAuthorProps(props: ["title": .init("未知书名"), "author": .init("未知作者")])!
                return AnyView(BookTitleAuthorView(props: props))
            }),
            (.sourceStatus, { component in
                let props = SourceStatusProps(props: component.props) ?? SourceStatusProps(props: [:])!
                return AnyView(SourceStatusView(props: props))
            }),
            (.bookIntro, { component in
                let props = BookIntroProps(props: component.props) ?? BookIntroProps(props: [:])!
                return AnyView(BookIntroView(props: props))
            }),
            (.directoryPreview, { component in
                let props = DirectoryPreviewProps(props: component.props) ?? DirectoryPreviewProps(props: [:])!
                return AnyView(DirectoryPreviewView(props: props))
            }),
            (.readButton, { component in
                let props = ReadButtonProps(props: component.props) ?? ReadButtonProps(props: [:])!
                return AnyView(ReadButtonView(props: props))
            }),
            (.addToShelfButton, { component in
                let props = AddToShelfButtonProps(props: component.props) ?? AddToShelfButtonProps(props: [:])!
                return AnyView(AddToShelfButtonView(props: props))
            }),
        ])
    }
}
