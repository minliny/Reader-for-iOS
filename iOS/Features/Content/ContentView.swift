import SwiftUI
import ReaderCoreModels
import ReaderShellValidation

public struct ContentView: View {
    @ObservedObject public var coordinator: ReadingFlowCoordinator
    public let chapter: TOCItem

    public init(coordinator: ReadingFlowCoordinator, chapter: TOCItem) {
        self.coordinator = coordinator
        self.chapter = chapter
    }

    private var surfaceKind: ContentSurfaceKind {
        if coordinator.isLoading {
            return .loading
        }
        if coordinator.currentError != nil {
            return .error
        }
        if coordinator.contentPage != nil {
            return .content
        }
        return .empty
    }

    private var stageTitle: String {
        if coordinator.isLoading {
            return "正文加载中"
        }
        if coordinator.currentError != nil {
            return "正文加载失败"
        }
        if coordinator.contentPage != nil {
            return "正文已加载"
        }
        return "等待加载正文"
    }

    private var stageDetail: String {
        if coordinator.isLoading {
            return "正在获取章节内容..."
        }
        if let error = coordinator.currentError {
            return error.message
        }
        if coordinator.contentPage != nil {
            return coordinator.contentPage?.title ?? ""
        }
        return "暂无正文内容"
    }

    public var body: some View {
        DemoBackScreen(title: "正文") {
            contentSurface
        }
        .task {
            if coordinator.selectedChapter != chapter || coordinator.contentPage == nil {
                await coordinator.selectChapter(chapter)
            }
        }
    }

    @ViewBuilder
    private var contentSurface: some View {
        switch surfaceKind {
        case .loading:
            ReaderStateBanner(
                icon: .refresh,
                title: stageTitle,
                messages: [stageDetail]
            )

        case .error:
            ReaderStateCard(
                icon: .warning,
                title: stageTitle,
                subtitle: stageDetail,
                actionTitle: "重新加载"
            ) {
                Task { await coordinator.selectChapter(chapter) }
            }

        case .content:
            if let contentPage = coordinator.contentPage {
                loadedContent(contentPage)
            }

        case .empty:
            emptyState
        }
    }

    private func loadedContent(_ contentPage: ContentPage) -> some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
            ReaderContentSectionView(
                title: contentPage.title,
                bodyText: contentPage.content,
                bookTitle: coordinator.selectedBook?.title,
                sourceName: coordinator.selectedSource?.bookSourceName
            )

            progressCard

            chapterControlBar
        }
    }

    private var progressCard: some View {
        ReaderCard {
            VStack(spacing: 0) {
                DemoIconRow(
                    icon: .progress,
                    title: "阅读进度",
                    subtitle: chapter.chapterTitle,
                    detail: "\(currentChapterIndex + 1)/\(max(totalChapterCount, 1))"
                )
                Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                DemoIconRow(
                    icon: .sourceSwitch,
                    title: "当前来源",
                    subtitle: coordinator.selectedSource?.bookSourceName ?? "未选中书源",
                    detail: coordinator.selectedBook?.title
                )
            }
        }
    }

    private var chapterControlBar: some View {
        HStack(spacing: ReaderDesignTokens.rssModeRowGap) {
            chapterControlButton("上一章", action: previousChapterAction)
            chapterControlButton("刷新") {
                Task { await coordinator.selectChapter(chapter) }
            }
            chapterControlButton("下一章", action: nextChapterAction)
        }
    }

    private func chapterControlButton(_ title: String, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            Text(title)
                .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .heavy))
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.plain)
        .foregroundColor(action == nil ? ReaderDesignTokens.readerModuleTextColor.opacity(0.45) : ReaderDesignTokens.Color.primaryDark)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm)
                .fill(ReaderDesignTokens.Color.controlBackground)
        )
        .disabled(action == nil)
    }

    private var emptyState: some View {
        ReaderStateCard(
            icon: .file,
            title: "暂无正文",
            subtitle: stageDetail,
            actionTitle: "重新加载正文"
        ) {
            Task { await coordinator.selectChapter(chapter) }
        }
    }

    private var previousChapterAction: (() -> Void)? {
        guard let currentIndex = coordinator.tocItems.firstIndex(where: { $0.chapterURL == chapter.chapterURL }),
              currentIndex > 0 else {
            return nil
        }
        let previous = coordinator.tocItems[currentIndex - 1]
        return {
            Task { await coordinator.selectChapter(previous) }
        }
    }

    private var nextChapterAction: (() -> Void)? {
        guard let currentIndex = coordinator.tocItems.firstIndex(where: { $0.chapterURL == chapter.chapterURL }),
              currentIndex < coordinator.tocItems.count - 1 else {
            return nil
        }
        let next = coordinator.tocItems[currentIndex + 1]
        return {
            Task { await coordinator.selectChapter(next) }
        }
    }

    private var currentChapterIndex: Int {
        coordinator.tocItems.firstIndex(where: { $0.chapterURL == chapter.chapterURL }) ?? max(0, chapter.chapterIndex)
    }

    private var totalChapterCount: Int {
        coordinator.tocItems.isEmpty ? max(chapter.chapterIndex + 1, 1) : coordinator.tocItems.count
    }
}

private enum ContentSurfaceKind: String {
    case loading = "加载中"
    case error = "错误"
    case content = "已加载"
    case empty = "空"
}
