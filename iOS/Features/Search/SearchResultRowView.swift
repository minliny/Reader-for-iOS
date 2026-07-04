import SwiftUI
import ReaderCoreModels

public struct SearchResultRowView: View {
    let result: SearchResultItem
    let sourceName: String
    let onTap: (() -> Void)?
    let onAddToBookshelf: (() -> Void)?

    public init(
        result: SearchResultItem,
        sourceName: String,
        onTap: (() -> Void)? = nil,
        onAddToBookshelf: (() -> Void)? = nil
    ) {
        self.result = result
        self.sourceName = sourceName
        self.onTap = onTap
        self.onAddToBookshelf = onAddToBookshelf
    }

    public var body: some View {
        ReaderCard {
            HStack(alignment: .top, spacing: ReaderDesignTokens.searchResultRowGap) {
                ReaderIcon(.bookOpen, size: 20, accessibilityLabel: result.title)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .frame(width: ReaderDesignTokens.searchResultCoverWidth, height: ReaderDesignTokens.searchResultCoverHeight)
                    .background(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xs).fill(ReaderDesignTokens.Color.chipBackground))

                Button(action: { onTap?() }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(result.title)
                            .font(.system(size: ReaderDesignTokens.readerSectionTitleFontSize, weight: .heavy))
                            .foregroundColor(ReaderDesignTokens.Color.ink)
                            .lineLimit(1)

                        Text(searchMeta)
                            .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .bold))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                            .lineLimit(1)

                        if let intro = result.intro, !intro.isEmpty {
                            Text(intro)
                                .font(.system(size: ReaderDesignTokens.rssArticleRowBodyFontSize))
                                .foregroundStyle(ReaderDesignTokens.Color.muted)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                if let onAddToBookshelf = onAddToBookshelf {
                    Button(action: onAddToBookshelf) {
                        ReaderIcon(.add, size: 18, accessibilityLabel: "加入书架")
                            .foregroundColor(.white)
                            .frame(width: ReaderDesignTokens.searchResultActionColumn, height: ReaderDesignTokens.searchResultActionMinHeight)
                            .background(Capsule().fill(ReaderDesignTokens.Color.primary))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(ReaderDesignTokens.searchResultRowPadding - ReaderDesignTokens.cardPadding)
        }
    }

    private var searchMeta: String {
        let author = result.author?.isEmpty == false ? result.author! : "作者未知"
        return "\(author) · \(sourceName)"
    }
}
