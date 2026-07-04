import SwiftUI
import ReaderCoreModels
import ReaderAppSupport
import ReaderAppPersistence
import ReaderShellValidation

private enum BookDetailDestination {
    case directory
    case reader(BookDetailPreviewChapter?)
}

public struct BookDetailView: View {
    @StateObject private var viewModel: BookDetailViewModel
    @State private var isInBookshelf = false
    @State private var bookshelfItemID: String?
    @State private var showSourceSheet = false
    @State private var showRemoveDialog = false
    @State private var activeDestination: BookDetailDestination?
    let result: SearchResultItem
    let sourceName: String
    let source: BookSource?
    let onExit: (() -> Void)?
    private let bookshelfStore = BookshelfStore.shared
    private var sourceIdentity: ReaderAppSupport.SourceIdentity {
        SourceIdentityFactory.from(searchResult: result)
    }
    private var resolvedSourceID: String {
        if let id = source?.id, !id.isEmpty {
            return id
        }
        return sourceIdentity.id
    }

    public init(result: SearchResultItem, sourceName: String = "", source: BookSource? = nil, onExit: (() -> Void)? = nil) {
        self.result = result
        self.sourceName = sourceName
        self.source = source
        self.onExit = onExit
        self._viewModel = StateObject(wrappedValue: BookDetailViewModel(bookURL: result.detailURL, source: source))
    }

    public var body: some View {
        ZStack {
            switch activeDestination {
            case .some(.directory):
                BookDirectoryPreviewView(bookURL: result.detailURL, title: result.title) {
                    activeDestination = nil
                }
            case .some(.reader(let chapter)):
                readerView(chapter: chapter) {
                    activeDestination = nil
                }
            case .none:
                detailShell
            }
        }
        .onAppear {
            Task {
                await viewModel.loadDetail()
                checkBookshelfStatus()
            }
        }
    }

    private var detailShell: some View {
        DemoBackScreen(title: "书籍详情", onBack: onExit) {
            if let notice = detailStatusNotice {
                BookDetailNoticeCard(notice: notice)
            }
            bookDetailContent(detail: displayDetail)
        } trailing: {
            EmptyView()
        } bottomActionHost: {
            bottomActions
        } sheetHost: {
            if showSourceSheet {
                DemoBottomSheet(title: "更换书源", maxHeight: 320, onDismiss: { showSourceSheet = false }) {
                    BookDetailSourceSheet(
                        currentSourceName: displaySourceName,
                        onDismiss: { showSourceSheet = false }
                    )
                }
            }
        } dialogHost: {
            if showRemoveDialog {
                DemoDialogOverlay(onDismiss: { showRemoveDialog = false }) {
                    BookDetailRemoveDialog(
                        onCancel: { showRemoveDialog = false },
                        onConfirm: {
                            removeFromBookshelf()
                            showRemoveDialog = false
                        }
                    )
                }
            }
        } stateHost: {
            EmptyView()
        }
    }

    private func checkBookshelfStatus() {
        if let item = try? bookshelfStore.find(bookURL: result.detailURL, sourceID: resolvedSourceID) {
            isInBookshelf = true
            bookshelfItemID = item.id
        } else {
            isInBookshelf = false
            bookshelfItemID = nil
        }
    }

    private var displayDetail: SearchResultItem {
        switch viewModel.detailState {
        case .loaded(let detail), .partial(let detail, _):
            return detail
        default:
            return result
        }
    }

    private var detailStatusNotice: BookDetailStatusNotice? {
        switch viewModel.detailState {
        case .idle, .loading:
            return BookDetailStatusNotice(
                title: "正在加载详情",
                message: "先展示搜索结果中的基础信息，书源返回后会补齐简介和章节。",
                icon: .refresh,
                tone: .loading
            )
        case .empty:
            return BookDetailStatusNotice(
                title: "详情暂不可用",
                message: "当前书源没有返回详情内容，仍可从搜索结果继续进入阅读。",
                icon: .info,
                tone: .warning
            )
        case .failed(let message):
            return BookDetailStatusNotice(
                title: "详情加载失败",
                message: message,
                icon: .warning,
                tone: .danger
            )
        case .unsupported(let reason):
            return BookDetailStatusNotice(
                title: "当前书源不支持详情",
                message: reason,
                icon: .warning,
                tone: .warning
            )
        case .partial(_, let warnings):
            return BookDetailStatusNotice(
                title: "详情数据不完整",
                message: warnings.joined(separator: "；"),
                icon: .info,
                tone: .warning
            )
        case .loaded:
            return nil
        }
    }

    private var displaySourceName: String {
        let explicit = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty {
            return String(explicit.split(separator: "·").first ?? Substring(explicit))
        }
        let sourceTitle = source?.bookSourceName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !sourceTitle.isEmpty {
            return sourceTitle
        }
        let identityName = sourceIdentity.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return identityName.isEmpty ? "当前书源" : identityName
    }

    private var previewChapters: [BookDetailPreviewChapter] {
        if !viewModel.chapters.isEmpty {
            return viewModel.chapters.prefix(4).enumerated().map { offset, item in
                BookDetailPreviewChapter(
                    id: item.chapterURL.isEmpty ? "chapter-\(offset)" : item.chapterURL,
                    title: item.chapterTitle.isEmpty ? "第 \(offset + 1) 章" : item.chapterTitle,
                    chapterURL: item.chapterURL,
                    sourceIndex: offset,
                    isCurrent: offset == 0,
                    isCached: offset < 2,
                    isBookmarked: offset == 1
                )
            }
        }

        return BookDetailPreviewChapter.demoChapters
    }

    private func bookDetailContent(detail: SearchResultItem) -> some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
            bookHeroCard(detail: detail)
            summaryCard(detail: detail)
            chapterPreviewCard
        }
    }

    private func bookHeroCard(detail: SearchResultItem) -> some View {
        ReaderCard {
            HStack(alignment: .top, spacing: ReaderDesignTokens.bookDetailHeroGap) {
                BookDetailCoverView(coverURL: detail.coverURL, title: detail.title)

                VStack(alignment: .leading, spacing: 0) {
                    Text(detail.title)
                        .font(ReaderTypography.demoSerif(size: 22, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(authorText(for: detail))
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .medium))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .lineLimit(1)
                        .padding(.top, 8)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("最新")
                            .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                            .frame(width: 34, alignment: .leading)
                        Text(latestChapterText(for: detail))
                            .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                            .foregroundColor(ReaderDesignTokens.Color.ink)
                            .lineLimit(1)
                    }
                    .padding(.top, 10)

                    HStack(spacing: 8) {
                        Text("书源：\(displaySourceName)")
                            .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: .bold))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            showSourceSheet = true
                        } label: {
                            Text("更换书源")
                                .font(.system(size: ReaderDesignTokens.bookDetailInlineSourceButtonFontSize, weight: .black))
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .frame(minHeight: ReaderDesignTokens.bookDetailInlineSourceButtonMinHeight)
                                .foregroundColor(ReaderDesignTokens.Color.primary)
                                .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(ReaderDesignTokens.bookDetailHeroPadding - ReaderDesignTokens.cardPadding)
        }
    }

    private func summaryCard(detail: SearchResultItem) -> some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.bookDetailSummaryGap) {
                Text("简介")
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                    .lineLimit(1)
                Text(summaryText(for: detail))
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineSpacing(6)
                    .lineLimit(4)
            }
            .padding(ReaderDesignTokens.bookDetailSummaryPadding - ReaderDesignTokens.cardPadding)
        }
    }

    private var chapterPreviewCard: some View {
        ReaderCard {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("章节信息")
                        .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        activeDestination = .directory
                    } label: {
                        HStack(spacing: 6) {
                            ReaderIcon(.directory, size: 16, accessibilityLabel: "完整目录")
                            Text("完整目录")
                                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: .black))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .frame(minHeight: ReaderDesignTokens.bookDetailInlineRouteMinHeight)
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                }
                .frame(minHeight: ReaderDesignTokens.bookDetailChapterPreviewHeaderMinHeight)
                .padding(.horizontal, ReaderDesignTokens.bookDirectoryFullHorizontalPadding)

                ForEach(previewChapters) { chapter in
                    Divider().overlay(ReaderDesignTokens.Color.readerModuleNavBorder)
                    Button {
                        addToBookshelfIfNeeded()
                        activeDestination = .reader(chapter)
                    } label: {
                        BookDetailPreviewChapterRow(chapter: chapter)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, ReaderDesignTokens.bookDirectoryListTopPadding - ReaderDesignTokens.cardPadding)
            .padding(.bottom, -ReaderDesignTokens.cardPadding)
            .padding(.horizontal, -ReaderDesignTokens.cardPadding)
        }
    }

    private var bottomActions: some View {
        BottomFixedActionRow {
            Button {
                addToBookshelfIfNeeded()
                activeDestination = .reader(nil)
            } label: {
                BookDetailBottomLabel(title: isInBookshelf ? "继续阅读" : "开始阅读", isPrimary: true)
            }
            .buttonStyle(.plain)
        } trailing: {
            Button {
                if isInBookshelf {
                    showRemoveDialog = true
                } else {
                    addToBookshelf()
                }
            } label: {
                BookDetailBottomLabel(
                    title: isInBookshelf ? "移除书架" : "加入书架",
                    isPrimary: false,
                    isDanger: isInBookshelf
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func readerView(chapter: BookDetailPreviewChapter?, onExit: (() -> Void)? = nil) -> ReaderView {
        let requestedIndex = chapter?.sourceIndex ?? 0
        let resolvedIndex = viewModel.chapters.indices.contains(requestedIndex) ? requestedIndex : 0
        let resolvedChapter = viewModel.chapters.indices.contains(resolvedIndex) ? viewModel.chapters[resolvedIndex] : nil
        let fallbackChapterTitle = chapter?.title ?? viewModel.firstChapter?.chapterTitle ?? "第一章"
        let fallbackChapterURL = chapter?.chapterURL ?? viewModel.firstChapter?.chapterURL ?? result.detailURL

        return ReaderView(
            chapterURL: resolvedChapter?.chapterURL ?? fallbackChapterURL,
            chapterTitle: resolvedChapter?.chapterTitle ?? fallbackChapterTitle,
            chapterList: viewModel.chapters,
            currentChapterIndex: resolvedIndex,
            bookID: sourceIdentity.id,
            sourceID: resolvedSourceID,
            source: source,
            onExit: onExit
        )
    }

    private func authorText(for detail: SearchResultItem) -> String {
        let author = detail.author?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return author.isEmpty ? "作者待补齐" : author
    }

    private func latestChapterText(for detail: SearchResultItem) -> String {
        let latest = detail.nextPageUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return latest.isEmpty ? "待接入章节更新" : latest
    }

    private func summaryText(for detail: SearchResultItem) -> String {
        let intro = detail.intro?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !intro.isEmpty {
            return intro
        }
        return "旧世界的余烬尚未冷却，新的秩序已经在废墟之上生长。主角沿着被遗忘的线索追寻真相，也在一次次选择里确认自己想守住的东西。"
    }

    private func addToBookshelfIfNeeded() {
        if !isInBookshelf {
            addToBookshelf()
        }
    }

    private func addToBookshelf() {
        let identity = sourceIdentity
        let item = BookshelfItem(
            sourceID: resolvedSourceID,
            sourceName: source?.bookSourceName ?? identity.name,
            bookURL: result.detailURL,
            title: result.title,
            author: result.author,
            coverURL: result.coverURL,
            latestChapter: nil
        )
        try? bookshelfStore.addOrUpdate(item)
        isInBookshelf = true
        bookshelfItemID = item.id
    }

    private func removeFromBookshelf() {
        let itemID = bookshelfItemID ?? (try? bookshelfStore.find(bookURL: result.detailURL, sourceID: resolvedSourceID))??.id
        if let itemID {
            try? bookshelfStore.remove(id: itemID)
        }
        isInBookshelf = false
        bookshelfItemID = nil
    }
}

private struct BookDetailStatusNotice {
    let title: String
    let message: String
    let icon: ReaderAssetIcon
    let tone: BookDetailNoticeTone
}

private enum BookDetailNoticeTone {
    case loading
    case warning
    case danger

    var foreground: SwiftUI.Color {
        switch self {
        case .loading:
            return ReaderDesignTokens.Color.primaryDark
        case .warning:
            return ReaderDesignTokens.Color.Semantic.warning
        case .danger:
            return ReaderDesignTokens.Color.Semantic.danger
        }
    }

    var background: SwiftUI.Color {
        switch self {
        case .loading:
            return ReaderDesignTokens.Color.primary.opacity(0.10)
        case .warning:
            return ReaderDesignTokens.Color.Semantic.warningTint
        case .danger:
            return ReaderDesignTokens.Color.Semantic.danger.opacity(0.10)
        }
    }
}

private struct BookDetailNoticeCard: View {
    let notice: BookDetailStatusNotice

    var body: some View {
        ReaderCard {
            HStack(spacing: 10) {
                ReaderIcon(notice.icon, size: 18, accessibilityLabel: notice.title)
                    .foregroundColor(notice.tone.foreground)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(notice.tone.background))
                VStack(alignment: .leading, spacing: 4) {
                    Text(notice.title)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .foregroundColor(notice.tone.foreground)
                        .lineLimit(1)
                    Text(notice.message)
                        .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .lineLimit(2)
                }
            }
        }
    }
}

private struct BookDetailCoverView: View {
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
        .frame(width: ReaderDesignTokens.bookDetailHeroCoverWidth, height: ReaderDesignTokens.bookDetailHeroCoverHeight)
        .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm))
        // demo `.fd-book-detail-hero img`: 0 8px 16px rgba(52,38,26,0.18)
        .shadow(color: ReaderDesignTokens.Color.Shadow.bookDetailHero, radius: 16, x: 0, y: 8)
        .accessibilityLabel(Text("\(title)封面"))
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    ReaderDesignTokens.Color.primary.opacity(0.16),
                    ReaderDesignTokens.Color.chipBackground.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            ReaderIcon(.bookOpen, size: 28, accessibilityLabel: title)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        }
    }
}

private struct BookDetailPreviewChapter: Identifiable, Hashable {
    let id: String
    let title: String
    let chapterURL: String?
    let sourceIndex: Int
    let isCurrent: Bool
    let isCached: Bool
    let isBookmarked: Bool

    static let demoChapters: [BookDetailPreviewChapter] = [
        BookDetailPreviewChapter(id: "demo-30", title: "第 30 章 旧日", chapterURL: nil, sourceIndex: 0, isCurrent: false, isCached: true, isBookmarked: false),
        BookDetailPreviewChapter(id: "demo-31", title: "第 31 章 归途", chapterURL: nil, sourceIndex: 0, isCurrent: false, isCached: true, isBookmarked: true),
        BookDetailPreviewChapter(id: "demo-32", title: "第 32 章 雨夜", chapterURL: nil, sourceIndex: 0, isCurrent: true, isCached: false, isBookmarked: true),
        BookDetailPreviewChapter(id: "demo-33", title: "第 33 章 灯塔", chapterURL: nil, sourceIndex: 0, isCurrent: false, isCached: false, isBookmarked: false)
    ]
}

private struct BookDetailPreviewChapterRow: View {
    let chapter: BookDetailPreviewChapter

    var body: some View {
        HStack(spacing: 12) {
            Text(chapter.title)
                .font(.system(size: ReaderDesignTokens.readerSectionTitleFontSize, weight: chapter.isCurrent ? .heavy : .regular))
                .foregroundColor(chapter.isCurrent ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: ReaderDesignTokens.bookDirectoryMarkerGap) {
                markerIcon(chapter.isCached ? .check : .download, isActive: chapter.isCached, accessibilityLabel: chapter.isCached ? "已缓存" : "未缓存")
                markerIcon(.bookmark, isActive: chapter.isBookmarked, accessibilityLabel: chapter.isBookmarked ? "书签" : "无书签")
            }
            .frame(width: ReaderDesignTokens.bookDirectoryMarkerColumnWidth, alignment: .trailing)
        }
        .padding(.horizontal, ReaderDesignTokens.bookDirectoryFullHorizontalPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookDetailChapterPreviewRowMinHeight, alignment: .leading)
        .background(chapter.isCurrent ? ReaderDesignTokens.Color.primary.opacity(0.08) : SwiftUI.Color.clear)
        .contentShape(Rectangle())
    }

    private func markerIcon(_ icon: ReaderAssetIcon, isActive: Bool, accessibilityLabel: String) -> some View {
        ReaderIcon(icon, size: 15, accessibilityLabel: accessibilityLabel)
            .foregroundColor(isActive ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.muted.opacity(0.58))
            .frame(width: ReaderDesignTokens.bookDirectoryMarkerSize, height: ReaderDesignTokens.bookDirectoryMarkerSize)
            .background(
                Capsule()
                    .fill(isActive ? ReaderDesignTokens.Color.primary.opacity(0.10) : ReaderDesignTokens.Color.chipBackground.opacity(0.82))
            )
    }
}

private struct BookDetailBottomLabel: View {
    let title: String
    let isPrimary: Bool
    var isDanger: Bool = false

    var body: some View {
        Text(title)
            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
            .foregroundColor(foreground)
            .background(
                Capsule()
                    .fill(background)
                    .overlay(Capsule().stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: isPrimary ? 0 : 1))
            )
    }

    private var foreground: SwiftUI.Color {
        if isPrimary {
            return .white
        }
        if isDanger {
            return ReaderDesignTokens.Color.Semantic.danger
        }
        return ReaderDesignTokens.Color.primaryDark
    }

    private var background: SwiftUI.Color {
        isPrimary ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.mainNavBackground
    }
}

private struct BookDetailSourceSheet: View {
    let currentSourceName: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 8) {
                sourceButton(currentSourceName, isCurrent: true)
                sourceButton("优书网", isCurrent: false)
                sourceButton("书仓搜索", isCurrent: false)
                sourceButton("本地缓存", isCurrent: false)
                sourceButton("关闭", isCurrent: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sourceButton(_ title: String, isCurrent: Bool) -> some View {
        Button {
            onDismiss()
        } label: {
            HStack(spacing: 10) {
                ReaderIcon(isCurrent ? .check : .source, size: 16, accessibilityLabel: title)
                    .foregroundColor(isCurrent ? .white : ReaderDesignTokens.Color.primaryDark)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(isCurrent ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.primary.opacity(0.10)))
                Text(title)
                    .font(.system(size: ReaderDesignTokens.readerSectionTitleFontSize, weight: .heavy))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isCurrent {
                    Text("当前")
                        .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 24)
                        .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                    .fill(ReaderDesignTokens.Color.surface)
                    .overlay(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md).stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct BookDetailRemoveDialog: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ConfirmDialog(
            icon: .trash,
            iconColor: ReaderDesignTokens.Color.Semantic.danger,
            title: "确认删除？",
            message: "只从书架移除，不删除本地文件和阅读记录。"
        ) {
            HStack(spacing: ReaderDesignTokens.rssModeRowGap) {
                Button(action: onCancel) {
                    BookDetailBottomLabel(title: "取消", isPrimary: false)
                }
                .buttonStyle(.plain)

                Button(action: onConfirm) {
                    BookDetailBottomLabel(title: "删除", isPrimary: true, isDanger: true)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

extension SearchResultItem {
    var latestChapterLabel: String {
        if let next = nextPageUrl, !next.isEmpty { return "最新章节：\(next)" }
        return "最新章节：待接入（M2.2）"
    }
}
