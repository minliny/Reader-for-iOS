import SwiftUI
import ReaderCoreModels
import ReaderShellValidation

public struct TOCView: View {
    @ObservedObject public var coordinator: ReadingFlowCoordinator
    public let book: SearchResultItem

    public init(coordinator: ReadingFlowCoordinator, book: SearchResultItem) {
        self.coordinator = coordinator
        self.book = book
    }

    public var body: some View {
        VStack(spacing: 0) {
            tocStageCard

            if coordinator.isLoading {
                LoadingView(message: "加载目录...")
            } else if let error = coordinator.currentError {
                ErrorView(error: error) {
                    Task {
                        await coordinator.selectBook(book)
                    }
                }
            } else if coordinator.tocItems.isEmpty {
                emptyState
            } else {
                tocList
            }
        }
        .navigationTitle(book.title)
        .inlineNavigationBarTitle()
        .task {
            if coordinator.tocItems.isEmpty {
                await coordinator.selectBook(book)
            }
        }
    }

    private var tocStageCard: some View {
        ReaderStatusCardView(
            eyebrow: "目录阶段",
            title: book.title,
            subtitle: "目录准备完成后，选择章节进入正文阅读。",
            items: [
                ReaderStatusCardItem(label: "书源", value: coordinator.selectedSource?.bookSourceName ?? "未选中"),
                ReaderStatusCardItem(label: "章节", value: "\(coordinator.tocItems.count) 条")
            ]
        )
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ReaderEmptyStateView(
                title: "暂无目录",
                message: "当前书籍还没有可展示的章节列表。",
                systemImage: "list.bullet"
            )
            
            Button("重新加载目录") {
                Task { await coordinator.selectBook(book) }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 32)
    }

    private var tocList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(coordinator.tocItems, id: \.chapterURL) { chapter in
                    NavigationLink {
                        ContentView(coordinator: coordinator, chapter: chapter)
                    } label: {
                        ChapterRow(chapter: chapter)
                    }
                }
            }
        }
    }
}

private struct ChapterRow: View {
    let chapter: TOCItem

    var body: some View {
        HStack {
            Text(chapter.chapterTitle)
                .font(.body)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
