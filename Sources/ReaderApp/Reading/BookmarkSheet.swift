import ReaderCoreBridge
import ReaderDesign
import SwiftUI

struct BookmarkSheet: View {
    let bookmarks: [BookmarkData]
    let onAdd: () -> Void
    let onJump: (BookmarkData) -> Void
    let onDelete: (BookmarkData) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.readerTheme) private var theme
    @State private var removal: BookmarkData?
    @State private var consent: ReaderConfirmation?
    @State private var actionGeneration = 0

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty { PageState(state: .empty("当前书籍没有书签")) }
                else {
                    List {
                        ForEach(bookmarks, id: \.time) { bookmark in
                            Button { onJump(bookmark) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(bookmark.chapterName).foregroundStyle(theme.primaryText)
                                    if !bookmark.bookText.isEmpty {
                                        Text(bookmark.bookText).foregroundStyle(theme.secondaryText).lineLimit(2)
                                    }
                                }
                            }
                            .swipeActions {
                                Button("删除", role: .destructive) { confirm(bookmark) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("书签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("添加当前位置", action: onAdd) }
            }
        }
        .readerConfirmation($consent) { generation in
            guard generation == actionGeneration, let removal else { return }
            onDelete(removal)
            self.removal = nil
        }
    }

    private func confirm(_ bookmark: BookmarkData) {
        actionGeneration += 1
        removal = bookmark
        consent = .init(title: "删除书签？", message: bookmark.chapterName, confirmTitle: "删除",
                        generation: actionGeneration)
    }
}
