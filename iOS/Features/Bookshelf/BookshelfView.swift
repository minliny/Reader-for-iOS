import SwiftUI
import ReaderAppSupport

public struct BookshelfView: View {
    @StateObject private var viewModel = BookshelfViewModel()
    @State private var selectedItem: BookshelfItem?

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                bookshelfStateView
            }
            .padding()
            .navigationTitle("Bookshelf")
            .onAppear {
                Task { await viewModel.loadItems() }
            }
            .refreshable {
                await viewModel.loadItems()
            }
            .sheet(item: $selectedItem) { item in
                BookshelfItemDetailView(item: item)
                    .presentationDetents([.medium])
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
        selectedItem = item
    }
}

struct BookshelfItemDetailView: View {
    let item: BookshelfItem
    @SwiftUI.Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Book Info") {
                    LabeledContent("Title", value: item.title)
                    if let author = item.author {
                        LabeledContent("Author", value: author)
                    }
                    if let source = item.sourceName {
                        LabeledContent("Source", value: source)
                    }
                }

                Section("Reading Progress") {
                    LabeledContent("Progress") {
                        Text("\(Int(item.readingProgress * 100))%")
                    }
                    if let chapter = item.lastReadChapterTitle {
                        LabeledContent("Last Chapter", value: chapter)
                    }
                    LabeledContent("Added") {
                        Text(item.addedAt, style: .date)
                    }
                }
            }
            .navigationTitle(item.title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}