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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if surfaceKind != .content {
                    ReaderStatusCardView(
                        eyebrow: "阅读阶段",
                        title: stageTitle,
                        subtitle: stageDetail,
                        items: contextItems()
                    )
                    .padding(.bottom, 8)
                }

                switch surfaceKind {
                case .loading:
                    LoadingView(message: "加载正文...")
                        .frame(maxWidth: .infinity, minHeight: 240)

                case .error:
                    if let error = coordinator.currentError {
                        ErrorView(error: error) {
                            Task {
                                await coordinator.selectChapter(chapter)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 240)
                    }

                case .content:
                    if let contentPage = coordinator.contentPage {
                        ReaderContentSectionView(
                            title: contentPage.title,
                            bodyText: contentPage.content,
                            bookTitle: coordinator.selectedBook?.title,
                            sourceName: coordinator.selectedSource?.bookSourceName
                        )

                        VStack(spacing: 12) {
                            let currentIndex = coordinator.tocItems.firstIndex(where: { $0.chapterURL == chapter.chapterURL }) ?? 0
                            let totalCount = coordinator.tocItems.count

                            ReaderProgressSurfaceView(
                                chapterIndex: currentIndex,
                                chapterCount: totalCount,
                                progressPercentage: totalCount > 0 ? Double(currentIndex) / Double(totalCount) : 0
                            )

                            ReaderStageActionBar(
                                onPrevious: previousChapterAction,
                                onNext: nextChapterAction,
                                onReload: { Task { await coordinator.selectChapter(chapter) } }
                            )
                        }
                        .padding(.top, 16)
                    }

                case .empty:
                    emptyState
                }
            }
            .padding(20)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(chapter.chapterTitle)
        .inlineNavigationBarTitle()
        .task {
            if coordinator.selectedChapter != chapter || coordinator.contentPage == nil {
                await coordinator.selectChapter(chapter)
            }
        }
    }

    private var emptyState: some View {
        ReaderEmptyStateView(
            title: "暂无正文",
            message: stageDetail,
            systemImage: "doc.text",
            actionTitle: "重新加载正文"
        ) {
            Task { await coordinator.selectChapter(chapter) }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
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

    private func contextItems() -> [ReaderStatusCardItem] {
        var items: [ReaderStatusCardItem] = []

        if let sourceName = coordinator.selectedSource?.bookSourceName {
            items.append(ReaderStatusCardItem(label: "书源", value: sourceName))
        }

        if let bookTitle = coordinator.selectedBook?.title {
            items.append(ReaderStatusCardItem(label: "书籍", value: bookTitle))
        }

        items.append(ReaderStatusCardItem(label: "章节", value: chapter.chapterTitle))

        items.append(
            ReaderStatusCardItem(
                label: "状态",
                value: surfaceKind.rawValue
            )
        )

        return items
    }
}

private enum ContentSurfaceKind: String {
    case loading = "加载中"
    case error = "错误"
    case content = "已加载"
    case empty = "空"
}
