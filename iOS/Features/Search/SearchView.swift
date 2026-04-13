import SwiftUI
import ReaderCoreModels
import ReaderShellValidation

public struct SearchView: View {
    @ObservedObject public var coordinator: ReadingFlowCoordinator
    @State private var searchText = ""

    public init(coordinator: ReadingFlowCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchBar
            searchStageCard

            if coordinator.isLoading {
                LoadingView(message: "搜索中...")
            } else if let error = coordinator.currentError {
                ErrorView(error: error) {
                    coordinator.currentError = nil
                }
            } else if coordinator.searchResults.isEmpty {
                emptyState
            } else {
                resultsList
            }
        }
        .navigationTitle("搜索")
        .inlineNavigationBarTitle()
    }

    private var searchStageCard: some View {
        ReaderStatusCardView(
            eyebrow: "搜索阶段",
            title: coordinator.selectedSource?.bookSourceName ?? "等待书源",
            subtitle: coordinator.searchResults.isEmpty ? "输入关键词后进入最小搜索链路。" : "搜索结果已生成，可继续进入目录。",
            items: [
                ReaderStatusCardItem(label: "结果", value: "\(coordinator.searchResults.count) 条")
            ]
        )
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            TextField("输入关键词", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.search)
                .onSubmit(performSearch)

            Button(action: performSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.headline)
            }
            .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }

    private var emptyState: some View {
        ReaderEmptyStateView(
            title: "等待搜索",
            message: "输入关键词开始搜索，随后进入目录与正文链路。",
            systemImage: "text.magnifyingglass"
        )
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(coordinator.searchResults, id: \.detailURL) { book in
                    NavigationLink {
                        TOCView(coordinator: coordinator, book: book)
                    } label: {
                        BookRow(book: book)
                    }
                }
            }
        }
    }
}

private struct BookRow: View {
    let book: SearchResultItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(book.title)
                .font(.headline)
                .lineLimit(2)

            if let author = book.author {
                Text(author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let intro = book.intro {
                Text(intro)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension SearchView {
    func performSearch() {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return
        }

        Task {
            await coordinator.search(keyword: keyword)
        }
    }
}
