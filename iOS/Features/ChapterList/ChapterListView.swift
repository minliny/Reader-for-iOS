import SwiftUI
import ReaderCoreModels

struct ChapterNavigation: Hashable {
    let chapterURL: String
    let chapterTitle: String
    let chapterIndex: Int

    init(chapterURL: String, chapterTitle: String, chapterIndex: Int = 0) {
        self.chapterURL = chapterURL
        self.chapterTitle = chapterTitle
        self.chapterIndex = chapterIndex
    }
}

public struct ChapterListView: View {
    @StateObject private var viewModel: ChapterListViewModel
    @State private var activeChapter: ChapterNavigation?
    let sourceName: String
    let source: BookSource?
    private var resolvedBookID: String { viewModel.bookURL }
    private var resolvedSourceID: String {
        if let id = source?.id, !id.isEmpty {
            return id
        }
        return viewModel.bookURL
    }

    public init(bookURL: String, bookTitle: String, sourceName: String = "", source: BookSource? = nil) {
        self.sourceName = sourceName
        self.source = source
        self._viewModel = StateObject(wrappedValue: ChapterListViewModel(bookURL: bookURL, bookTitle: bookTitle, source: source))
    }

    public var body: some View {
        ZStack {
            if let activeChapter {
                ReaderView(
                    chapterURL: activeChapter.chapterURL,
                    chapterTitle: activeChapter.chapterTitle,
                    chapterList: viewModel.chaptersForReader,
                    currentChapterIndex: activeChapter.chapterIndex,
                    bookID: resolvedBookID,
                    sourceID: resolvedSourceID,
                    source: source,
                    onExit: { self.activeChapter = nil }
                )
            } else {
            DemoBackScreen(title: "目录") {
                directoryCard
            }
            .onAppear {
                Task { await viewModel.loadChapters() }
            }
            }
        }
    }

    private var directoryCard: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.bookDirectoryFullGap) {
                header
                listStateView
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, ReaderDesignTokens.bookDirectoryListTopPadding - ReaderDesignTokens.demoContentVerticalPadding)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("目录")
    }

    private var header: some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            ReaderIcon(.readerModuleDirectory, size: 22, accessibilityLabel: "目录")
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)
                .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.bookTitle)
                    .font(.system(size: ReaderDesignTokens.readerTopTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .lineLimit(1)

                Text("\(displaySourceName) · \(chapterCountDescription)")
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .medium))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookDirectoryHeaderMinHeight, alignment: .leading)
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var listStateView: some View {
        switch viewModel.listState {
        case .idle:
            ReaderStateBanner(
                icon: .refresh,
                title: "准备加载目录",
                messages: ["等待目录请求启动。"]
            )

        case .loading:
            ReaderStateBanner(
                icon: .refresh,
                title: "加载目录中",
                messages: ["正在从当前书源获取章节列表。"]
            )

        case .loaded(let chapters):
            chapterList(chapters)

        case .empty:
            ReaderStateCard(
                icon: .readerModuleDirectory,
                title: "暂无目录",
                subtitle: "当前书籍还没有可展示的章节列表。",
                actionTitle: "重新加载"
            ) {
                Task { await viewModel.loadChapters() }
            }

        case .failed(let message):
            ReaderStateCard(
                icon: .warning,
                title: "目录加载失败",
                subtitle: message,
                actionTitle: "重新加载"
            ) {
                Task { await viewModel.loadChapters() }
            }

        case .unsupported(let reason):
            ReaderStateCard(
                icon: .warning,
                title: "目录暂不支持",
                subtitle: reason
            )

        case .partial(let chapters, let warnings):
            VStack(alignment: .leading, spacing: 12) {
                ReaderStateBanner(
                    icon: .warning,
                    title: "部分目录可用",
                    messages: warnings.isEmpty ? ["目录返回了部分章节。"] : warnings
                )

                chapterList(chapters)
            }
        }
    }

    private func chapterList(_ chapters: [TOCItem]) -> some View {
        // P2-B: 使用 LazyVStack 虚拟化长目录列表，避免一次性渲染全部章节行。
        // 真源：demo `.fd-reader-directory-list` 在长目录场景下用虚拟滚动；
        // iOS 用 LazyVStack 等价（仅在 ScrollView 内可见区域渲染行）。
        LazyVStack(spacing: 0) {
            ForEach(Array(chapters.enumerated()), id: \.element.chapterURL) { index, chapter in
                ChapterRowView(
                    chapter: chapter,
                    displayIndex: index + 1,
                    onTap: {
                        showChapterAction(chapter: chapter, index: index)
                    }
                )

                if chapter.chapterURL != chapters.last?.chapterURL {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                }
            }
        }
        .background(ReaderDesignTokens.Color.surface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
                .stroke(ReaderDesignTokens.Color.readerModuleNavBorder, lineWidth: 1)
        )
    }

    private func showChapterAction(chapter: TOCItem, index: Int) {
        activeChapter = ChapterNavigation(
            chapterURL: chapter.chapterURL,
            chapterTitle: chapter.chapterTitle,
            chapterIndex: index
        )
    }

    private var displaySourceName: String {
        if !sourceName.isEmpty {
            return sourceName
        }
        if let name = source?.bookSourceName, !name.isEmpty {
            return name
        }
        return "未选中书源"
    }

    private var chapterCountDescription: String {
        switch viewModel.listState {
        case .loaded(let chapters), .partial(let chapters, _):
            return "共 \(chapters.count) 章"
        case .empty:
            return "暂无目录"
        case .failed:
            return "加载失败"
        case .unsupported:
            return "暂不支持"
        case .idle:
            return "准备加载"
        case .loading:
            return "加载中"
        }
    }
}
