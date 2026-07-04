import SwiftUI
import ReaderAppSupport

public struct BookshelfItemRowView: View {
    let item: BookshelfItem
    let onTap: (() -> Void)?
    let onDelete: (() -> Void)?

    public init(item: BookshelfItem, onTap: (() -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.item = item
        self.onTap = onTap
        self.onDelete = onDelete
    }

    public var body: some View {
        ReaderCard {
            Button(action: {
                onTap?()
            }) {
                HStack(spacing: ReaderDesignTokens.bookListColumnGap) {
                    coverPlaceholder

                    VStack(alignment: .leading, spacing: ReaderDesignTokens.bookListRowGap) {
                        Text(item.title)
                            .font(ReaderTypography.demoSerif(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .bold))
                            .foregroundColor(ReaderDesignTokens.Color.ink)
                            .lineLimit(1)

                        if let author = item.author, !author.isEmpty {
                            Text(author)
                                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                                .foregroundStyle(ReaderDesignTokens.Color.muted)
                                .lineLimit(1)
                        }

                        if let lastChapter = item.lastReadChapterTitle, !lastChapter.isEmpty {
                            Text("上次读到：\(lastChapter)")
                                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                                .foregroundStyle(ReaderDesignTokens.Color.muted)
                                .lineLimit(1)
                        }

                        if item.readingProgress > 0 {
                            // demo `.fd-reader-book-progress`：文字百分比，无 bar。
                            Text("\(Int(item.readingProgress * 100))%")
                                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: .semibold))
                                .foregroundStyle(ReaderDesignTokens.Color.primaryDark)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if onDelete != nil {
                        ReaderIcon(.trash, size: 16, accessibilityLabel: "删除")
                            .foregroundColor(ReaderDesignTokens.Color.muted)
                    }
                }
                .padding(ReaderDesignTokens.bookGroupRowHorizontalPadding - ReaderDesignTokens.cardPadding)
            }
            .buttonStyle(.plain)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Text("删除")
            }
        }
    }

    private var coverPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm)
                .fill(ReaderDesignTokens.Color.chipBackground)
                .frame(width: ReaderDesignTokens.bookListCoverWidth, height: ReaderDesignTokens.bookListCoverWidth / ReaderDesignTokens.bookCoverAspectRatio)

            ReaderIcon(.book, size: 20, accessibilityLabel: item.title)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        }
    }
}
