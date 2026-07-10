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
    /// 主题 ID（paper / warm / green / blue）。控制层色按 day/night 解析，
    /// 阅读纸张背景 / 正文墨色按 themeId + isNight 解析（对照 ReaderThemeResolver）。
    public let themeId: String

    public init(themeId: String = "paper", isNight: Bool) {
        self.themeId = themeId
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

    // MARK: - Reading surface（阅读正文层，按 readerTheme 主题化）

    /// 阅读纸张背景色（按 themeId + isNight 解析；对照 ReaderThemeResolver.paperColor）。
    /// Issue 6：阅读背景必须来自 palette，不再硬编码 ReaderDesignTokens / backgroundMode。
    public var readingPaper: SwiftUI.Color {
        ReaderThemeResolver.paperColor(themeId: themeId, isNight: isNight)
    }

    /// 阅读正文墨色（按 themeId + isNight 解析；对照 ReaderThemeResolver.inkColor）。
    /// Issue 6：正文墨色必须来自 palette，不再读 displaySettings.backgroundMode.textColor。
    public var readingInk: SwiftUI.Color {
        ReaderThemeResolver.inkColor(themeId: themeId, isNight: isNight)
    }
}

/// 跨平台 Reader 主题管理器
/// 日间/夜间模式切换，支持手动 override + 系统 ColorScheme 自动解析
/// （对照 demo `render-runtime.js` `readerThemeStyle()` 的 theme 解析逻辑）
@MainActor
public final class ReaderThemeManager: ObservableObject {
    /// 当前阅读主题 ID（paper / warm / green / blue）。对照 HarmonyOS `reader.readerTheme`。
    @Published public var readerTheme: String = "paper"
    /// App 主题模式（system / light / dark）。对照 HarmonyOS `reader.appThemeMode`。
    /// system → 跟随系统 ColorScheme；light → 强制日间；dark → 强制夜间。
    @Published public var appThemeMode: String = "system"
    /// 系统颜色方案（由 View 通过 `@Environment(\.colorScheme)` 注入）
    @Published public var systemColorScheme: ColorScheme? = nil

    public init() {}

    /// 手动夜间 override（旧 API 兼容）：appThemeMode 为 system 时 nil，否则反映 light/dark。
    public var isNightModeOverride: Bool? {
        switch appThemeMode {
        case "light": return false
        case "dark":  return true
        default:      return nil
        }
    }

    /// 旧 API 兼容：显式夜间模式标志
    public var isNightMode: Bool {
        get { effectiveIsNight }
        set { appThemeMode = newValue ? "dark" : "light" }
    }

    /// 解析后的有效夜间模式：appThemeMode 优先，system 时跟随系统 ColorScheme
    public var effectiveIsNight: Bool {
        switch appThemeMode {
        case "light": return false
        case "dark":  return true
        default:      return systemColorScheme == .dark
        }
    }

    /// 当前解析后的调色板（按 readerTheme + effectiveIsNight 主题化）
    public var palette: ReaderThemePalette {
        ReaderThemeResolver.palette(themeId: readerTheme, isNight: effectiveIsNight)
    }

    /// 设置阅读主题（对照 contract `set-reader-theme`）
    public func setReaderTheme(_ themeId: String) {
        readerTheme = themeId
    }

    /// 设置 App 主题模式（对照 contract `set-app-theme-mode`）
    public func setAppThemeMode(_ mode: String) {
        appThemeMode = mode
    }

    /// 切换夜间/日间模式（旧 API 兼容 + `reader_nightState_toggle`）
    public func toggleNightMode() {
        appThemeMode = effectiveIsNight ? "light" : "dark"
    }

    /// 清除手动 override，回到跟随系统
    public func clearOverride() {
        appThemeMode = "system"
    }

    /// View 层调用：注入系统 ColorScheme（通常在根视图 `.onAppear` 或 `.environment` 中调用）
    public func updateSystemColorScheme(_ scheme: ColorScheme) {
        systemColorScheme = scheme
    }
}

// MARK: - Environment Key（供 View 通过 @Environment(\.readerThemePalette) 读取）

private struct ReaderThemePaletteEnvironmentKey: EnvironmentKey {
    static let defaultValue: ReaderThemePalette = ReaderThemePalette(themeId: "paper", isNight: false)
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
