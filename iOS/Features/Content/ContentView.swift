import SwiftUI
import ReaderCoreModels

public struct ContentView: View {
    @ObservedObject public var coordinator: ReadingFlowCoordinator
    public let chapter: TOCItem

    public init(coordinator: ReadingFlowCoordinator, chapter: TOCItem) {
        self.coordinator = coordinator
        self.chapter = chapter
    }

    public var body: some View {
        VStack(spacing: 0) {
            if coordinator.isLoading {
                LoadingView(message: "加载正文...")
            } else if let error = coordinator.currentError {
                ErrorView(error: error) {
                    Task {
                        await coordinator.selectChapter(chapter)
                    }
                }
            } else if let content = coordinator.contentPage {
                contentReader(content)
            } else {
                emptyState
            }
        }
        .navigationTitle(chapter.title ?? "正文")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if coordinator.selectedChapter != chapter || coordinator.contentPage == nil {
                await coordinator.selectChapter(chapter)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无内容")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func contentReader(_ content: ContentPage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let title = content.title {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Text(content.body)
                    .font(.body)
                    .lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
    }
}
