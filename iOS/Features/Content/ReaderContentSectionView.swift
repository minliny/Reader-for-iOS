import SwiftUI

public struct ReaderContentSectionView: View {
    public let title: String
    public let bodyText: String
    public let bookTitle: String?
    public let sourceName: String?

    public init(
        title: String,
        bodyText: String,
        bookTitle: String? = nil,
        sourceName: String? = nil
    ) {
        self.title = title
        self.bodyText = bodyText
        self.bookTitle = bookTitle
        self.sourceName = sourceName
    }

    public var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    if let bookTitle = bookTitle {
                        Text(bookTitle)
                            .font(.system(size: ReaderDesignTokens.readerTopSubtitleFontSize, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(title)
                        .font(ReaderTypography.demoSerif(size: ReaderDesignTokens.immersiveBodyFontSize + ReaderDesignTokens.immersiveTitleFontSizeOffset, weight: .bold))
                        .lineSpacing((ReaderDesignTokens.immersiveBodyFontSize + ReaderDesignTokens.immersiveTitleFontSizeOffset) * (ReaderDesignTokens.immersiveTitleLineHeight - 1))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let sourceName = sourceName {
                        Text("来源：\(sourceName)")
                            .font(.system(size: ReaderDesignTokens.readerTopSubtitleFontSize, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                VStack(alignment: .leading, spacing: ReaderDesignTokens.immersiveBodyFontSize * 0.72) {
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(indentedParagraph(paragraph))
                            .font(ReaderTypography.demoSerif(size: ReaderDesignTokens.immersiveBodyFontSize))
                            .lineSpacing(ReaderDesignTokens.immersiveBodyFontSize * (ReaderDesignTokens.immersiveBodyLineHeight - 1))
                            .foregroundStyle(.primary.opacity(0.86))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var paragraphs: [String] {
        let lines = bodyText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? [bodyText] : lines
    }

    private func indentedParagraph(_ paragraph: String) -> String {
        let indentCount = max(0, Int(ReaderDesignTokens.immersiveBodyParagraphIndent.rounded()))
        return String(repeating: "\u{3000}", count: indentCount) + paragraph
    }
}
