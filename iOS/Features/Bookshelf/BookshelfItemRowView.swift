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
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if let author = item.author, !author.isEmpty {
                            Text(author)
                                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if let lastChapter = item.lastReadChapterTitle, !lastChapter.isEmpty {
                            Text("上次读到：\(lastChapter)")
                                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if item.readingProgress > 0 {
                            ProgressView(value: item.readingProgress)
                                .frame(maxWidth: 120)
                                .tint(ReaderDesignTokens.Color.primaryDark)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if onDelete != nil {
                        ReaderIcon(.trash, size: 16, accessibilityLabel: "删除")
                            .foregroundColor(.secondary)
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
            RoundedRectangle(cornerRadius: 6)
                .fill(ReaderDesignTokens.Color.chipBackground)
                .frame(width: ReaderDesignTokens.bookListCoverWidth, height: ReaderDesignTokens.bookListCoverWidth / ReaderDesignTokens.bookCoverAspectRatio)

            ReaderIcon(.book, size: 20, accessibilityLabel: item.title)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        }
    }
}
