import Foundation
#if canImport(SwiftUI)
import SwiftUI

public enum ReaderStageActionBarStyle {
    case regular
    case compactLandscape
}

public enum ReaderStageModule: String, CaseIterable, Hashable {
    case directory = "目录"
    case tts = "朗读"
    case appearance = "外观"
    case settings = "设置"

    public var icon: ReaderAssetIcon {
        switch self {
        case .directory:
            return .readerModuleDirectory
        case .tts:
            return .readerModuleTts
        case .appearance:
            return .readerModuleAppearance
        case .settings:
            return .readerModuleSettings
        }
    }

    public var demoKey: String {
        switch self {
        case .directory:
            return "directory"
        case .tts:
            return "tts"
        case .appearance:
            return "appearance"
        case .settings:
            return "settings"
        }
    }

    public var compactDemoRoute: String {
        switch self {
        case .directory:
            return "toc-bookmarks"
        case .tts:
            return "tts"
        case .appearance:
            return "reader-appearance"
        case .settings:
            return "reader-settings"
        }
    }

    public var fullDemoRoute: String {
        switch self {
        case .directory:
            return "reader-full-directory"
        case .tts:
            return "reader-full-tts"
        case .appearance:
            return "reader-full-appearance"
        case .settings:
            return "reader-full-settings"
        }
    }
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
    public let activeModule: ReaderStageModule?
    public let onSelectModule: (ReaderStageModule) -> Void
    public let style: ReaderStageActionBarStyle

    public init(
        activeModule: ReaderStageModule? = nil,
        onSelectModule: @escaping (ReaderStageModule) -> Void,
        style: ReaderStageActionBarStyle = .regular
    ) {
        self.activeModule = activeModule
        self.onSelectModule = onSelectModule
        self.style = style
    }

    public var body: some View {
        HStack(spacing: navGap) {
            ForEach(ReaderStageModule.allCases, id: \.self) { module in
                moduleItem(module)
            }
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
        .accessibilityIdentifier("fd-reader-module-nav")
    }

    @ViewBuilder
    private func moduleItem(_ module: ReaderStageModule) -> some View {
        let isSelected = activeModule == module
        Button {
            onSelectModule(module)
        } label: {
            VStack(spacing: moduleGap) {
                ReaderIcon(module.icon, size: iconSize, accessibilityLabel: module.rawValue)
                    .frame(width: iconShellSize, height: iconShellSize)
                    .foregroundColor(isSelected ? .white : ReaderDesignTokens.Color.primary)
                    .background(
                        Circle()
                            .fill(isSelected ? ReaderDesignTokens.Color.primaryDark
                                    : ReaderDesignTokens.Color.readerModuleIconShellBackground)
                    )
                Text(module.rawValue)
                    .font(.system(size: moduleFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.readerModuleTextColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(module.rawValue)
        .accessibilityIdentifier("fd-reader-module-\(module.demoKey)")
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
