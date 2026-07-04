import SwiftUI

/// 跨平台 Reader 阅读页布局 metrics
/// 真源：Reader-Core docs/cross-platform-ui/CROSS_PLATFORM_READER_CONTROL_SPEC.md §2
public enum ReaderControlMetrics {
    public static let topBarHeight: CGFloat = 56
    public static let metaRowHeight: CGFloat = 48
    public static let bottomBarHeight: CGFloat = 68
    public static let pageControlHeight: CGFloat = 52
    public static let pageControlWidth: CGFloat = 342
    public static let quickCircleSize: CGFloat = 48
    public static let quickCircleGap: CGFloat = 20
    public static let brightnessWidth: CGFloat = 40
    public static let brightnessHeight: CGFloat = 256
    public static let brightnessInset: CGFloat = 12
    public static let contentPaddingTop: CGFloat = 128
    public static let contentPaddingBottom: CGFloat = 230
    public static let contentPaddingHorizontal: CGFloat = 24
}

/// Reader 主题调色板（day/night 解析后的运行时值）
///
/// 对照 demo `render-runtime.js` `readerThemeStyle()` 返回的 control 对象：
/// 当 `effectiveIsNight == false` 时返回 `ReaderDesignTokens.Color.*`（day），
/// 当 `effectiveIsNight == true` 时返回 `ReaderDesignTokens.Color.Night.*`（night）。
/// alpha 独立核算（day/night 各自的 alpha 值，不共享）。
public struct ReaderThemePalette {
    public let isNight: Bool

    public init(isNight: Bool) {
        self.isNight = isNight
    }

    // MARK: - Surface / Panel（对照 control.surface / panel / elevated / field）

    /// control.surface —— day rgba(255,252,248,0.88) / night rgba(38,35,31,0.96)
    public var surface: SwiftUI.Color {
        isNight ? ReaderDesignTokens.Color.Night.surface : ReaderDesignTokens.Color.surface
    }
    /// control.surfaceSolid —— day #fffaf4 / night rgba(34,31,28,0.98)
    public var surfaceSolid: SwiftUI.Color {
        isNight ? ReaderDesignTokens.Color.Night.surfaceSolid : ReaderDesignTokens.Color.controlSurfaceSolid
    }
    /// control.panel —— day 0.62 / night 0.82
    public var panel: SwiftUI.Color {
        isNight ? ReaderDesignTokens.Color.Night.panel : ReaderDesignTokens.Color.bottomBarBg
    }
    /// control.elevated —— day 0.74 / night 0.92
    public var elevated: SwiftUI.Color {
        isNight ? ReaderDesignTokens.Color.Night.elevated : ReaderDesignTokens.Color.floatingControlBg
    }
    /// control.field —— day rgba(238,230,219,0.56) / night rgba(58,52,46,0.78)
    public var field: SwiftUI.Color {
        isNight ? ReaderDesignTokens.Color.Night.field : ReaderDesignTokens.Color.controlPanelSoft56
    }

    // MARK: - Ink / Muted / Icon（对照 control.ink / muted / icon）

    /// control.ink —— day #1f1b17 / night #eadfce
    public var ink: SwiftUI.Color {
        isNight ? ReaderDesignTokens.Color.Night.ink : ReaderDesignTokens.Color.ink
    }
    /// control.muted —— day #756f69 / night #baad9c
    public var muted: SwiftUI.Color {
        isNight ? ReaderDesignTokens.Color.Night.muted : ReaderDesignTokens.Color.muted
    }
    /// control.icon —— day #3f372f / night #d4c5b2
    public var icon: SwiftUI.Color {
        isNight ? ReaderDesignTokens.Color.Night.icon : ReaderDesignTokens.Color.controlIcon
    }

    // MARK: - Primary / Action（对照 control.primary / action）

    /// control.primary —— day #2f6373 / night #7a684f（色相完全不同）
    public var primary: SwiftUI.Color {
        isNight ? ReaderDesignTokens.Color.Night.primary : ReaderDesignTokens.Color.primary
    }
    /// control.primaryText —— day #fffaf4 / night #fffaf4（一致）
    public var primaryText: SwiftUI.Color {
        isNight ? ReaderDesignTokens.Color.Night.primaryText : ReaderDesignTokens.Color.controlSurfaceSolid
    }
    /// control.action —— day #2f6373 / night #d2bd96
    public var action: SwiftUI.Color {
        isNight ? ReaderDesignTokens.Color.Night.action : ReaderDesignTokens.Color.primary
    }

    // MARK: - Line / Border（对照 control.line / lineStrong）

    public var line: SwiftUI.Color {
        isNight ? ReaderDesignTokens.Color.Night.line : ReaderDesignTokens.Color.mainNavBorder.opacity(0.18)
    }
    public var lineStrong: SwiftUI.Color {
        isNight ? ReaderDesignTokens.Color.Night.lineStrong : ReaderDesignTokens.Color.mainNavBorder.opacity(0.34)
    }

    // MARK: - Paper / Accent（对照 --fd-paper / --fd-accent）

    /// `--fd-paper` —— day #fff8f4 / night #24211e
    public var paper: SwiftUI.Color {
        isNight ? ReaderDesignTokens.Color.Night.paperSolid : ReaderDesignTokens.Color.paperSolid
    }
    /// `--fd-paper-solid` —— day #f8f4ec / night #1c1a18
    public var paperSolid: SwiftUI.Color {
        isNight ? ReaderDesignTokens.Color.Night.paperSolidAlt : ReaderDesignTokens.Color.paperSolidAlt
    }
    /// `--fd-accent` —— day #f48b13 / night #d69b5f
    public var accent: SwiftUI.Color {
        isNight ? ReaderDesignTokens.Color.Night.accent : ReaderDesignTokens.Color.accent
    }
}

/// 跨平台 Reader 主题管理器
/// 日间/夜间模式切换，支持手动 override + 系统 ColorScheme 自动解析
/// （对照 demo `render-runtime.js` `readerThemeStyle()` 的 theme 解析逻辑）
@MainActor
public final class ReaderThemeManager: ObservableObject {
    /// 手动夜间模式标志（用户显式切换）。`nil` 表示跟随系统。
    @Published public var isNightModeOverride: Bool? = nil
    /// 系统颜色方案（由 View 通过 `@Environment(\.colorScheme)` 注入）
    @Published public var systemColorScheme: ColorScheme? = nil

    public init() {}

    /// 旧 API 兼容：显式夜间模式标志
    public var isNightMode: Bool {
        get { effectiveIsNight }
        set { isNightModeOverride = newValue }
    }

    /// 解析后的有效夜间模式：手动 override 优先，否则跟随系统
    public var effectiveIsNight: Bool {
        if let override = isNightModeOverride {
            return override
        }
        return systemColorScheme == .dark
    }

    /// 当前解析后的调色板
    public var palette: ReaderThemePalette {
        ReaderThemePalette(isNight: effectiveIsNight)
    }

    /// 切换手动夜间/日间模式（非弹窗，旧 API 兼容）
    public func toggleNightMode() {
        isNightModeOverride = !effectiveIsNight
    }

    /// 清除手动 override，回到跟随系统
    public func clearOverride() {
        isNightModeOverride = nil
    }

    /// View 层调用：注入系统 ColorScheme（通常在根视图 `.onAppear` 或 `.environment` 中调用）
    public func updateSystemColorScheme(_ scheme: ColorScheme) {
        systemColorScheme = scheme
    }
}

// MARK: - Environment Key（供 View 通过 @Environment(\.readerThemePalette) 读取）

private struct ReaderThemePaletteEnvironmentKey: EnvironmentKey {
    static let defaultValue: ReaderThemePalette = ReaderThemePalette(isNight: false)
}

public extension EnvironmentValues {
    /// 当前解析后的 Reader 主题调色板（day/night 已解析）
    var readerThemePalette: ReaderThemePalette {
        get { self[ReaderThemePaletteEnvironmentKey.self] }
        set { self[ReaderThemePaletteEnvironmentKey.self] = newValue }
    }
}

public extension View {
    /// 注入 Reader 主题调色板到环境（通常在根视图调用）
    func readerThemePalette(_ palette: ReaderThemePalette) -> some View {
        environment(\.readerThemePalette, palette)
    }
}
