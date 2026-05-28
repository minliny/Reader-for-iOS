import SwiftUI
import ReaderAppPersistence

/// M5-B: Bookmarks list view shown as a sheet from BookshelfItemDetailView.
/// Lists all bookmarks for a given book, sorted by most recent first.
public struct BookmarksListView: View {
    private let bookId: String
    private let sourceId: String
    private let bookTitle: String
    @State private var bookmarks: [Bookmark] = []
    @State private var navigateToReader = false
    @State private var selectedBookmark: Bookmark?
    @SwiftUI.Environment(\.dismiss) private var dismiss

    public init(bookId: String, sourceId: String, bookTitle: String) {
        self.bookId = bookId
        self.sourceId = sourceId
        self.bookTitle = bookTitle
    }

    public var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    ContentUnavailableView(
                        "无书签",
                        systemImage: "bookmark",
                        description: Text("在阅读时点击书签按钮添加书签")
                    )
                } else {
                    List {
                        ForEach(bookmarks) { bookmark in
                            BookmarkRowView(bookmark: bookmark)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedBookmark = bookmark
                                    navigateToReader = true
                                }
                        }
                        .onDelete(perform: deleteBookmarks)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("书签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $navigateToReader) {
                if let bm = selectedBookmark {
                    ReaderView(
                        chapterURL: bm.chapterURL,
                        chapterTitle: bm.chapterTitle,
                        bookID: bookId,
                        sourceID: sourceId
                    )
                }
            }
            .onAppear { loadBookmarks() }
        }
    }

    private func loadBookmarks() {
        bookmarks = (try? BookmarkStore.shared.loadBookmarksForBook(bookId: bookId)) ?? []
    }

    private func deleteBookmarks(at offsets: IndexSet) {
        for index in offsets {
            let bookmark = bookmarks[index]
            try? BookmarkStore.shared.deleteBookmark(id: bookmark.id)
        }
        loadBookmarks()
    }
}

struct BookmarkRowView: View {
    let bookmark: Bookmark

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(bookmark.chapterTitle)
                .font(.subheadline)
                .fontWeight(.medium)

            if let snippet = bookmark.snippet, !snippet.isEmpty {
                Text(snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Text("\(Int(bookmark.progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text(bookmark.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}