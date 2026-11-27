import SwiftUI

public struct ReaderTaskProgress: View {
    @Environment(\.readerTheme) private var theme
    private let title: String
    private let completed: Int
    private let failed: Int
    private let total: Int

    public init(title: String, completed: Int, failed: Int, total: Int) {
        self.title = title
        self.completed = completed
        self.failed = failed
        self.total = total
    }

    public var body: some View {
        let card = RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius))
        VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceExtraSmall)) {
            Text(title)
                .readerTypography(ReaderDesignMetrics.pageTitle)
                .accessibilityAddTraits(.isHeader)
            if total > 0 {
                ProgressView(value: Double(completed + failed), total: Double(total))
                    .accessibilityLabel(title)
                Text("已完成 \(completed) · 失败 \(failed) · 未执行 \(max(0, total - completed - failed))")
                    .readerTypography(ReaderDesignMetrics.rowDetail)
                    .foregroundStyle(theme.secondaryText)
            } else {
                ProgressView()
                    .accessibilityLabel(title)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CGFloat(ReaderDesignMetrics.cardPadding))
        .background(theme.messageSurface, in: card)
        .overlay { card.strokeBorder(theme.messageBorder) }
        .accessibilityElement(children: .contain)
    }
}
