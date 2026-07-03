import Foundation
#if canImport(SwiftUI)
import SwiftUI

public enum ReaderProgressSurfaceStyle {
    case regular
    case compactLandscape
}

/// 阅读顶栏进度面 —— 对齐 demo `.fd-reader-top` 规格。
///
/// 真源：`Reader UI/frontend-demo/styles/01-shell-layout.css` `.fd-reader-top`
/// 规格（取自 `ReaderDesignTokens`，clean-room，不复制 CSS）：
/// - top 18pt / 左右 14pt / min-h 54pt / radius 24
/// - 背景 rgba(255,250,244,0.92) / 边框 1px rgba(154,139,124,0.35)
/// - strong 16pt line-clamp 2 · small 12pt
///
/// 在 `ReaderView` 中由 `chromeVisible` 控制显隐（`reader.control.show/hide`）。
public struct ReaderProgressSurfaceView: View {
    public let chapterIndex: Int
    public let chapterCount: Int
    public let progressPercentage: Double
    public let title: String?
    public let subtitle: String?
    public let onBack: (() -> Void)?
    public let onSourceSwitch: (() -> Void)?
    public let onMore: (() -> Void)?
    public let style: ReaderProgressSurfaceStyle

    public init(
        chapterIndex: Int,
        chapterCount: Int,
        progressPercentage: Double,
        title: String? = nil,
        subtitle: String? = nil,
        onBack: (() -> Void)? = nil,
        onSourceSwitch: (() -> Void)? = nil,
        onMore: (() -> Void)? = nil,
        style: ReaderProgressSurfaceStyle = .regular
    ) {
        self.chapterIndex = chapterIndex
        self.chapterCount = chapterCount
        self.progressPercentage = progressPercentage
        self.title = title
        self.subtitle = subtitle
        self.onBack = onBack
        self.onSourceSwitch = onSourceSwitch
        self.onMore = onMore
        self.style = style
    }

    public var body: some View {
        HStack(spacing: gap) {
            readerTopButton(
                icon: .back,
                title: "",
                accessibilityLabel: "返回阅读入口",
                action: onBack
            )
            .frame(width: backColumnWidth)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.system(size: titleFontSize, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(ReaderDesignTokens.readerTopTitleLineLimit)
                Text(displaySubtitle)
                    .font(.system(size: subtitleFontSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            readerTopButton(
                icon: .sourceSwitch,
                title: "换源",
                accessibilityLabel: "切换书源",
                action: onSourceSwitch
            )
            .frame(width: sourceColumnWidth)

            readerTopButton(
                icon: .more,
                title: "",
                accessibilityLabel: "更多阅读操作",
                action: onMore
            )
            .frame(width: moreColumnWidth)
        }
        .padding(.horizontal, horizontalPadding)
        .frame(minHeight: minHeight)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.readerTopCornerRadius)
                .fill(ReaderDesignTokens.Color.readerTopBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.readerTopCornerRadius)
                        .stroke(ReaderDesignTokens.Color.readerTopBorder, lineWidth: 1)
                )
        )
    }

    private var displayTitle: String {
        title ?? "第 \(chapterIndex + 1) 章"
    }

    private var displaySubtitle: String {
        subtitle ?? "共 \(chapterCount) 章 · \(String(format: "%.1f", progressPercentage * 100))%"
    }

    private func readerTopButton(
        icon: ReaderAssetIcon,
        title: String,
        accessibilityLabel: String,
        action: (() -> Void)?
    ) -> some View {
        Button(action: { action?() }) {
            HStack(spacing: 3) {
                ReaderIcon(icon, size: 16, accessibilityLabel: accessibilityLabel)
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: buttonFontSize, weight: .heavy))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: buttonMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
        .accessibilityLabel(accessibilityLabel)
        .disabled(action == nil)
        .opacity(action == nil ? 0.48 : 1)
    }

    private var minHeight: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerTopCompactMinHeight : ReaderDesignTokens.readerTopMinHeight
    }

    private var backColumnWidth: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerTopCompactBackColumnWidth : ReaderDesignTokens.readerTopBackColumnWidth
    }

    private var sourceColumnWidth: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerTopCompactSourceColumnWidth : ReaderDesignTokens.readerTopSourceColumnWidth
    }

    private var moreColumnWidth: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerTopCompactMoreColumnWidth : ReaderDesignTokens.readerTopMoreColumnWidth
    }

    private var gap: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerTopCompactGap : ReaderDesignTokens.readerTopGap
    }

    private var horizontalPadding: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerTopCompactHorizontalPadding : ReaderDesignTokens.readerTopHorizontalPadding
    }

    private var titleFontSize: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerTopCompactTitleFontSize : ReaderDesignTokens.readerTopTitleFontSize
    }

    private var subtitleFontSize: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerTopCompactSubtitleFontSize : ReaderDesignTokens.readerTopSubtitleFontSize
    }

    private var buttonMinHeight: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerTopCompactButtonMinHeight : ReaderDesignTokens.readerTopButtonMinHeight
    }

    private var buttonFontSize: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerTopCompactButtonFontSize : ReaderDesignTokens.readerTopSubtitleFontSize
    }
}
#endif
