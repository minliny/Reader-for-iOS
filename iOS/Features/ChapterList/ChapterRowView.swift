import SwiftUI
import ReaderCoreModels

public struct ChapterRowView: View {
    let chapter: TOCItem
    let displayIndex: Int?
    let onTap: (() -> Void)?

    public init(chapter: TOCItem, displayIndex: Int? = nil, onTap: (() -> Void)? = nil) {
        self.chapter = chapter
        self.displayIndex = displayIndex
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: ReaderDesignTokens.bookGroupRowGap) {
                Text(chapter.chapterTitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: ReaderDesignTokens.bookDirectoryMarkerGap) {
                    markerText(chapterIndexLabel)
                    ReaderIcon(.chevron, size: 14, accessibilityLabel: "打开章节")
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .frame(width: ReaderDesignTokens.bookDirectoryMarkerSize, height: ReaderDesignTokens.bookDirectoryMarkerSize)
                        .background(Capsule().fill(ReaderDesignTokens.Color.chipBackground.opacity(0.82)))
                }
                .frame(width: ReaderDesignTokens.bookDirectoryMarkerColumnWidth, alignment: .trailing)
            }
            .padding(.horizontal, ReaderDesignTokens.bookDirectoryFullHorizontalPadding)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookDirectoryRowMinHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chapter.chapterTitle)
    }

    private var chapterIndexLabel: String {
        let resolvedIndex = displayIndex ?? max(1, chapter.chapterIndex + 1)
        if resolvedIndex < 100 {
            return String(format: "%02d", resolvedIndex)
        }
        return "\(resolvedIndex)"
    }

    private func markerText(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 10, weight: .heavy).monospacedDigit())
            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .frame(width: ReaderDesignTokens.bookDirectoryMarkerSize, height: ReaderDesignTokens.bookDirectoryMarkerSize)
            .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.12)))
    }
}
