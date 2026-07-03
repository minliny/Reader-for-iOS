import Foundation
#if canImport(SwiftUI)
import SwiftUI

public struct ReaderSessionSummaryView: View {
    public let title: String
    public let subtitle: String
    public let actionTitle: String
    public let action: () -> Void
    
    public init(
        title: String,
        subtitle: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                    ReaderIcon(.bookOpen, size: 18, accessibilityLabel: "会话上下文")
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)
                        .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("会话上下文")
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        Text(title)
                            .font(ReaderTypography.demoSerif(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .bold))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(subtitle)
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssReaderInlineActionMinHeight)
                        .background(Capsule().fill(ReaderDesignTokens.Color.primaryDark))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
#endif
