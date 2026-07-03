import Foundation
#if canImport(SwiftUI)
import SwiftUI

public enum ReaderStageActionBarStyle {
    case regular
    case compactLandscape
}

/// 阅读底栏模块导航 —— 对齐 demo `.fd-reader-module-nav` / `.fd-reader-module` 规格。
///
/// 真源：`Reader UI/frontend-demo/styles/03-reader.css` `.fd-reader-module-nav` / `.fd-reader-module`
/// 规格（取自 `ReaderDesignTokens`，clean-room，不复制 CSS）：
/// - nav: grid 4 列 / gap 4 / min-h 78 / padding 8 / radius 12
///        背景 rgba(255,252,248,0.96) / 边框 1px rgba(180,166,151,0.34)
/// - module: grid 42/16 / gap 4 / 字号 12·800 / 色 #4d463f
///   icon-shell 42×42 circle / 背景 rgba(35,121,164,0.08) / active: primaryDark + 白
///
/// 在 `ReaderView` 中由 `chromeVisible` 控制显隐（`reader.control.show/hide`）。
public struct ReaderStageActionBar: View {
    public let onPrevious: (() -> Void)?
    public let onNext: (() -> Void)?
    public let onReload: (() -> Void)?
    public let onDirectory: (() -> Void)?
    public let style: ReaderStageActionBarStyle

    public init(
        onPrevious: (() -> Void)? = nil,
        onNext: (() -> Void)? = nil,
        onReload: (() -> Void)? = nil,
        onDirectory: (() -> Void)? = nil,
        style: ReaderStageActionBarStyle = .regular
    ) {
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.onReload = onReload
        self.onDirectory = onDirectory
        self.style = style
    }

    public var body: some View {
        HStack(spacing: navGap) {
            moduleItem(
                icon: .chevronLeft,
                label: "上一章",
                action: onPrevious
            )
            moduleItem(
                icon: .refresh,
                label: "刷新",
                action: onReload
            )
            moduleItem(
                icon: .readerModuleDirectory,
                label: "目录",
                action: onDirectory
            )
            moduleItem(
                icon: .chevron,
                label: "下一章",
                action: onNext
            )
        }
        .padding(navPadding)
        .frame(minHeight: navMinHeight)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.readerModuleNavCornerRadius)
                .fill(ReaderDesignTokens.Color.readerModuleNavBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.readerModuleNavCornerRadius)
                        .stroke(ReaderDesignTokens.Color.readerModuleNavBorder, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func moduleItem(icon: ReaderAssetIcon, label: String, action: (() -> Void)?) -> some View {
        let isActive = action != nil
        Button {
            action?()
        } label: {
            VStack(spacing: moduleGap) {
                ReaderIcon(icon, size: iconSize)
                    .frame(width: iconShellSize, height: iconShellSize)
                    .foregroundColor(isActive ? .white : ReaderDesignTokens.Color.primary)
                    .background(
                        Circle()
                            .fill(isActive ? ReaderDesignTokens.Color.primaryDark
                                    : ReaderDesignTokens.Color.readerModuleIconShellBackground)
                    )
                Text(label)
                    .font(.system(size: moduleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.readerModuleTextColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!isActive)
        .opacity(isActive ? 1 : 0.4)
    }

    private var navGap: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerDockCompactModuleGap : ReaderDesignTokens.readerModuleNavGap
    }

    private var navPadding: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerDockCompactModulePadding : ReaderDesignTokens.readerModuleNavPadding
    }

    private var navMinHeight: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerDockCompactNavHeight : ReaderDesignTokens.readerModuleNavMinHeight
    }

    private var moduleGap: CGFloat {
        style == .compactLandscape ? 2 : ReaderDesignTokens.readerModuleGap
    }

    private var iconSize: CGFloat {
        style == .compactLandscape ? 18 : 24
    }

    private var iconShellSize: CGFloat {
        style == .compactLandscape
            ? ReaderDesignTokens.readerDockCompactModuleIconShellSize
            : ReaderDesignTokens.readerModuleIconShellSize
    }

    private var moduleFontSize: CGFloat {
        style == .compactLandscape
            ? ReaderDesignTokens.readerDockCompactModuleFontSize
            : ReaderDesignTokens.readerModuleFontSize
    }
}
#endif
