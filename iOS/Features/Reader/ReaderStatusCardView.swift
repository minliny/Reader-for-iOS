import Foundation
#if canImport(SwiftUI)
import SwiftUI

public struct ReaderStatusCardItem: Identifiable, Equatable {
    public let id: String
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.id = UUID().uuidString
        self.label = label
        self.value = value
    }
}

public struct ReaderStatusCardView: View {
    public let eyebrow: String
    public let title: String
    public let subtitle: String
    public let items: [ReaderStatusCardItem]

    public init(
        eyebrow: String,
        title: String,
        subtitle: String,
        items: [ReaderStatusCardItem] = []
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !eyebrow.isEmpty {
                Text(eyebrow.uppercased())
                    // demo `.fd-settings-row-title`：13/800
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                    .foregroundStyle(ReaderDesignTokens.Color.primary)
                    .tracking(1.2)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    // demo `.fd-top-bar h1` serif
                    .font(ReaderTypography.demoSerif(size: ReaderDesignTokens.backBarTitleFontSize, weight: .bold))
                    .foregroundStyle(ReaderDesignTokens.Color.ink)
                Text(subtitle)
                    // demo meta：10-12px
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !items.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { item in
                        HStack {
                            Text(item.element.label)
                                // demo meta：10-12px
                                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: .semibold))
                                .foregroundStyle(ReaderDesignTokens.Color.muted)
                            Spacer()
                            Text(item.element.value)
                                // demo `.fd-settings-row-value`：11px
                                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize))
                                .foregroundStyle(ReaderDesignTokens.Color.ink)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.vertical, 10)

                        if item.offset < items.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, ReaderDesignTokens.cardPadding)
                // demo `.fd-restore-progress-meter` 轨道色 rgba(35,121,164,0.12)
                .background(
                    ReaderDesignTokens.Color.primary.opacity(0.12)
                )
                .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md))
            }
        }
        .padding(ReaderDesignTokens.cardPadding)
        // demo `ReaderCard` 背景：surface
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(ReaderDesignTokens.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                        .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                )
                // demo `--reader-ds-shadow-soft`: 0 8px 26px rgba(89,70,50,0.1)
                .shadow(
                    color: ReaderDesignTokens.Color.Shadow.soft,
                    radius: 26,
                    x: 0,
                    y: 8
                )
        )
    }
}
#endif
