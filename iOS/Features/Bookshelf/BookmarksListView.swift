import SwiftUI
import ReaderAppSupport
import ReaderShellValidation

/// M5-B: Bookmarks list view shown as a sheet from BookshelfItemDetailView.
/// Lists all bookmarks for a given book, sorted by most recent first.
public struct BookmarksListView: View {
    private let bookId: String
    private let sourceId: String
    private let bookTitle: String
    private let bookAuthor: String?
    private let onClose: (() -> Void)?
    @State private var bookmarks: [ReaderCoreBookmark] = []
    @State private var failureMessage: String?
    @SwiftUI.Environment(\.dismiss) private var dismiss

    public init(
        bookId: String,
        sourceId: String,
        bookTitle: String,
        bookAuthor: String? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.bookId = bookId
        self.sourceId = sourceId
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            DemoBackBar(title: "书签", onBack: close) {
                Button("完成", action: close)
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            }

            DemoPaperScreen {
                ReaderCard {
                    if let failureMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("书签暂不可用", systemImage: "exclamationmark.triangle")
                                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                            Text(failureMessage)
                                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                                .foregroundStyle(ReaderDesignTokens.Color.muted)
                            Button("重试") {
                                Task { await loadBookmarks() }
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
                    } else if bookmarks.isEmpty {
                        BookmarkEmptyState(bookTitle: bookTitle)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(bookmarks.enumerated()), id: \.element.id) { index, bookmark in
                                BookmarkRowView(
                                    bookmark: bookmark,
                                    onOpen: {
                                        failureMessage = "[SLICE10_BOOKMARK_LOCATOR_INCOMPLETE] Core bookmark does not yet carry sourceId/bookId/chapterURL; direct navigation is blocked"
                                    },
                                    onDelete: {
                                        Task { await deleteBookmark(bookmark) }
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
        .task { await loadBookmarks() }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    @MainActor
    private func loadBookmarks() async {
        do {
            let service = try ReaderSlice10CoreService.production()
            let loaded: [ReaderCoreBookmark]
            if let bookAuthor {
                loaded = try await service.listBookmarks(
                    bookName: bookTitle,
                    bookAuthor: bookAuthor,
                    correlationID: "bookmark-list:\(bookId):\(UUID().uuidString)"
                )
            } else {
                // The current Core filter is (bookName + bookAuthor) only.
                // When legacy shelf metadata lacks author, load the Core-owned
                // collection and narrow by bookName at the UI boundary.
                loaded = try await service.listBookmarks(
                    bookName: nil,
                    bookAuthor: nil,
                    correlationID: "bookmark-list:\(bookId):\(UUID().uuidString)"
                )
                .filter { $0.bookName == bookTitle }
            }
            guard !Task.isCancelled else { return }
            bookmarks = loaded.sorted { $0.time > $1.time }
            failureMessage = nil
        } catch is CancellationError {
            return
        } catch {
            bookmarks = []
            failureMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteBookmark(_ bookmark: ReaderCoreBookmark) async {
        do {
            let service = try ReaderSlice10CoreService.production()
            _ = try await service.deleteBookmark(
                time: bookmark.time,
                correlationID: "bookmark-delete:\(bookmark.time):\(UUID().uuidString)"
            )
            await loadBookmarks()
        } catch is CancellationError {
            return
        } catch {
            failureMessage = error.localizedDescription
        }
    }
}

struct BookmarkRowView: View {
    let bookmark: ReaderCoreBookmark
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            Button(action: onOpen) {
                HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                    ReaderIcon(.bookmark, size: 18, accessibilityLabel: bookmark.chapterName)
                        .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(bookmark.chapterName.isEmpty ? "第 \(bookmark.chapterIndex + 1) 章" : bookmark.chapterName)
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                            .foregroundColor(ReaderDesignTokens.Color.ink)
                            .lineLimit(1)

                        if !bookmark.bookText.isEmpty || !bookmark.content.isEmpty {
                            let snippet = bookmark.bookText.isEmpty ? bookmark.content : bookmark.bookText
                            Text(snippet)
                                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                                .foregroundStyle(ReaderDesignTokens.Color.muted)
                                .lineLimit(2)
                        }

                        HStack(spacing: 8) {
                            Text("第 \(bookmark.chapterIndex + 1) 章 · 位置 \(bookmark.chapterPosition)")
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
                .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
            Text("\(bookTitle) 的阅读书签会显示在这里")
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 156)
    }
}
