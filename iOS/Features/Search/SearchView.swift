import SwiftUI
import ReaderCoreModels

public struct SearchView: View {
    @ObservedObject public var coordinator: ReadingFlowCoordinator
    @State private var searchText = ""

    public init(coordinator: ReadingFlowCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchBar

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
        .navigationBarTitleDisplayMode(.inline)
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
        VStack(spacing: 16) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("输入关键词开始搜索")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(coordinator.searchResults, id: \.self) { book in
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
            Text(book.title ?? "无标题")
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
        .background(Color(.systemBackground))
    }
}
