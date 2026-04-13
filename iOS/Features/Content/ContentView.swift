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

    public var body: some View {
        let uxState = ReaderUXFoundationState(coordinator: coordinator, chapter: chapter)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ReaderStatusCardView(
                    eyebrow: "阅读阶段",
                    title: uxState.stageTitle,
                    subtitle: uxState.stageDetail,
                    items: contextItems(for: uxState)
                )

                switch uxState.surfaceKind {
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
                    if let title = uxState.contentTitle, let bodyText = uxState.contentBody {
                        ReaderContentSectionView(title: title, bodyText: bodyText)
                        
                        VStack(spacing: 12) {
                            if let chapterIndex = uxState.chapterIndex, uxState.chapterCount > 0 {
                                ReaderProgressSurfaceView(
                                    chapterIndex: chapterIndex,
                                    chapterCount: uxState.chapterCount,
                                    progressPercentage: uxState.progressPercentage ?? 0
                                )
                            }
                            
                            ReaderStageActionBar(
                                onPrevious: previousChapterAction,
                                onNext: nextChapterAction,
                                onReload: { Task { await coordinator.selectChapter(chapter) } }
                            )
                        }
                        .padding(.top, 16)
                    }

                case .empty:
                    emptyState(uxState)
                }
            }
            .padding(20)
        }
        .navigationTitle(chapter.chapterTitle)
        .inlineNavigationBarTitle()
        .task {
            if coordinator.selectedChapter != chapter || coordinator.contentPage == nil {
                await coordinator.selectChapter(chapter)
            }
        }
    }

    private func emptyState(_ uxState: ReaderUXFoundationState) -> some View {
        VStack(spacing: 16) {
            ReaderEmptyStateView(
                title: "暂无正文",
                message: uxState.stageDetail,
                systemImage: "doc.text"
            )
            
            Button("重新加载正文") {
                Task { await coordinator.selectChapter(chapter) }
            }
            .buttonStyle(.bordered)
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

    private func contextItems(for uxState: ReaderUXFoundationState) -> [ReaderStatusCardItem] {
        var items: [ReaderStatusCardItem] = []

        if let sourceName = uxState.sourceName {
            items.append(ReaderStatusCardItem(label: "书源", value: sourceName))
        }

        if let bookTitle = uxState.bookTitle {
            items.append(ReaderStatusCardItem(label: "书籍", value: bookTitle))
        }

        if let chapterTitle = uxState.chapterTitle {
            items.append(ReaderStatusCardItem(label: "章节", value: chapterTitle))
        }

        items.append(
            ReaderStatusCardItem(
                label: "状态",
                value: uxState.surfaceKind.rawValue
            )
        )

        return items
    }
}
