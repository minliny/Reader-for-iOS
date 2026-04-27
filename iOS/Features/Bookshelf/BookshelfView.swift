import SwiftUI

public struct BookshelfView: View {
    @StateObject private var viewModel = BookshelfViewModel()
    @State private var navigationPath = NavigationPath()

    public init() {}

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(alignment: .leading, spacing: 16) {
                bookshelfStateView
            }
            .padding()
            .navigationTitle("Bookshelf")
            .onAppear {
                Task { await viewModel.loadItems() }
            }
        }
    }

    @ViewBuilder
    private var bookshelfStateView: some View {
        switch viewModel.bookshelfState {
        case .idle:
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)

        case .loading:
            ProgressView("Loading...")
                .frame(maxWidth: .infinity, minHeight: 200)

        case .loaded(let items):
            List {
                ForEach(items) { item in
                    BookshelfItemRowView(
                        item: item,
                        onTap: {
                            navigateToDetail(item: item)
                        },
                        onDelete: {
                            Task {
                                await viewModel.removeItem(id: item.id)
                            }
                        }
                    )
                }
            }
            .listStyle(.plain)

        case .empty:
            VStack(spacing: 16) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Empty Bookshelf")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Add books from search results")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label("Error", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline.weight(.semibold))

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func navigateToDetail(item: BookshelfItem) {
    }
}