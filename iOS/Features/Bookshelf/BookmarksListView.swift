import SwiftUI
import ReaderAppSupport
import ReaderAppPersistence

/// M5-B: Bookmarks list view shown as a sheet from BookshelfItemDetailView.
/// Lists all bookmarks for a given book, sorted by most recent first.
public struct BookmarksListView: View {
    private let bookId: String
    private let sourceId: String
    private let bookTitle: String
    private let onClose: (() -> Void)?
    @State private var bookmarks: [Bookmark] = []
    @State private var navigateToReader = false
    @State private var selectedBookmark: Bookmark?
    @SwiftUI.Environment(\.dismiss) private var dismiss

    public init(bookId: String, sourceId: String, bookTitle: String, onClose: (() -> Void)? = nil) {
        self.bookId = bookId
        self.sourceId = sourceId
        self.bookTitle = bookTitle
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            DemoBackBar(title: "书签", onBack: close) {
                Button("完成", action: close)
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            }

            DemoPaperScreen {
                ReaderCard {
                    if bookmarks.isEmpty {
                        BookmarkEmptyState(bookTitle: bookTitle)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(bookmarks.enumerated()), id: \.element.id) { index, bookmark in
                                BookmarkRowView(
                                    bookmark: bookmark,
                                    onOpen: {
                                        selectedBookmark = bookmark
                                        navigateToReader = true
                                    },
                                    onDelete: {
                                        deleteBookmark(bookmark)
                                    }
                                )
                                if index < bookmarks.count - 1 {
                                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                                }
                            }
                        }
                    }
                }
            }
        }
        .background(ReaderDesignTokens.Color.paperSolid.ignoresSafeArea())
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
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

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func loadBookmarks() {
        bookmarks = (try? BookmarkStore.shared.loadBookmarksForBook(bookId: bookId)) ?? []
    }

    private func deleteBookmark(_ bookmark: Bookmark) {
        try? BookmarkStore.shared.deleteBookmark(id: bookmark.id)
        loadBookmarks()
    }
}

struct BookmarkRowView: View {
    let bookmark: Bookmark
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            Button(action: onOpen) {
                HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                    ReaderIcon(.bookmark, size: 18, accessibilityLabel: bookmark.chapterTitle)
                        .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(bookmark.chapterTitle)
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if let snippet = bookmark.snippet, !snippet.isEmpty {
                            Text(snippet)
                                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        HStack(spacing: 8) {
                            Text("\(Int(bookmark.progress * 100))%")
                            Text(bookmark.createdAt, style: .date)
                        }
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                ReaderIcon(.trash, size: 16, accessibilityLabel: "删除书签")
                    .frame(width: 32, height: 32)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .background(Circle().fill(ReaderDesignTokens.Color.chipBackground))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 9)
    }
}

private struct BookmarkEmptyState: View {
    let bookTitle: String

    var body: some View {
        VStack(alignment: .center, spacing: ReaderDesignTokens.settingsSectionGap) {
            ReaderIcon(.bookmark, size: 34, accessibilityLabel: "无书签")
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .frame(width: 48, height: 48)
                .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
            Text("暂无书签")
                .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .heavy))
            Text("\(bookTitle) 的阅读书签会显示在这里")
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 156)
    }
}
