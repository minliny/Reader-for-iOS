import SwiftUI
import ReaderCoreModels

public struct TOCView: View {
    @ObservedObject public var coordinator: ReadingFlowCoordinator
    public let book: SearchResultItem

    public init(coordinator: ReadingFlowCoordinator, book: SearchResultItem) {
        self.coordinator = coordinator
        self.book = book
    }

    public var body: some View {
        VStack(spacing: 0) {
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
        .navigationTitle(book.title ?? "目录")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if coordinator.tocItems.isEmpty {
                await coordinator.selectBook(book)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无目录")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tocList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(coordinator.tocItems, id: \.self) { chapter in
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
            Text(chapter.title ?? "无标题")
                .font(.body)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
    }
}
