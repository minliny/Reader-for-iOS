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
        ReaderEmptyStateView(
            title: "暂无正文",
            message: uxState.stageDetail,
            systemImage: "doc.text"
        )
        .frame(maxWidth: .infinity, minHeight: 240)
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
