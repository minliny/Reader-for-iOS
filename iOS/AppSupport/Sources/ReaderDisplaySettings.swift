import Foundation

public enum ReaderBackgroundMode: String, Codable, CaseIterable {
    case light
    case sepia
    case dark

    public var backgroundColor: String {
        switch self {
        case .light: return "#fff8f4" // --fd-ds-color-paper
        case .sepia: return "#f8f4ec" // --fd-ds-color-paper-alt（对齐 demo fixture #f8f4ec）
        case .dark: return "#24211e" // --fd-ds-color-paper-night（对齐 demo fixture #24211e）
        }
    }

    public var textColor: String {
        switch self {
        case .light: return "#1f1b17" // --fd-ds-color-ink
        case .sepia: return "#5C4B37" // 合约外 sepia 主题色，合约无 sepia 专用 token
        case .dark: return "#d8ccc4" // --fd-ds-color-ink-night
        }
    }
}

public enum PageTurnMode: String, Codable, CaseIterable {
    case scroll
    case paginated
}

public struct ReaderDisplaySettings: Codable, Equatable {
    public var fontSize: Int
    public var fontFamily: String
    public var lineSpacing: Double
    public var paragraphSpacing: Double
    public var horizontalPadding: Double
    public var verticalPadding: Double
    public var backgroundMode: ReaderBackgroundMode
    public var pageTurnMode: PageTurnMode
    public var tapZoneEnabled: Bool
    public var brightnessOverrideEnabled: Bool
    public var brightnessLevel: Double
    public var volumeKeyPageTurnEnabled: Bool
    public var dualPageEnabled: Bool
    /// 隐藏状态栏：沉浸阅读时隐藏顶部系统状态栏
    public var hideStatusBar: Bool
    /// 自动翻页：定时自动翻到下一页（对齐前端 demo `autoPage`）
    public var autoPageEnabled: Bool
    /// 横屏锁定：锁定横屏方向（对齐前端 demo `landscapeLock`）
    public var landscapeLockEnabled: Bool
    /// 屏幕常亮：阅读时保持屏幕常亮（对齐前端 demo `keepScreenOn`）
    public var keepScreenOnEnabled: Bool
    /// 页脚进度信息：在页脚显示阅读进度（对齐前端 demo `statusInfo`）
    public var statusInfoEnabled: Bool
    /// 触摸反馈：交互时触发触感反馈（对齐前端 demo `hapticFeedback`）
    public var hapticFeedbackEnabled: Bool
    /// 自动缓存后续章节：自动缓存下一批章节（对齐前端 demo `cacheNext`）
    public var cacheNextEnabled: Bool

    public static let demoSerifFontFamily = "Songti SC"
    public static let legacySansDefaultFontFamily = "SF Pro Display"

    public init(
        fontSize: Int = 18,
        fontFamily: String = ReaderDisplaySettings.demoSerifFontFamily,
        lineSpacing: Double = 8.0,
        paragraphSpacing: Double = 16.0,
        horizontalPadding: Double = 16.0,
        verticalPadding: Double = 16.0,
        backgroundMode: ReaderBackgroundMode = .light,
        pageTurnMode: PageTurnMode = .scroll,
        tapZoneEnabled: Bool = true,
        brightnessOverrideEnabled: Bool = false,
        brightnessLevel: Double = 0.8,
        volumeKeyPageTurnEnabled: Bool = false,
        dualPageEnabled: Bool = false,
        hideStatusBar: Bool = false,
        autoPageEnabled: Bool = false,
        landscapeLockEnabled: Bool = false,
        keepScreenOnEnabled: Bool = false,
        statusInfoEnabled: Bool = true,
        hapticFeedbackEnabled: Bool = false,
        cacheNextEnabled: Bool = true
    ) {
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.lineSpacing = lineSpacing
        self.paragraphSpacing = paragraphSpacing
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.backgroundMode = backgroundMode
        self.pageTurnMode = pageTurnMode
        self.tapZoneEnabled = tapZoneEnabled
        self.brightnessOverrideEnabled = brightnessOverrideEnabled
        self.brightnessLevel = min(1.0, max(0.0, brightnessLevel))
        self.volumeKeyPageTurnEnabled = volumeKeyPageTurnEnabled
        self.dualPageEnabled = dualPageEnabled
        self.hideStatusBar = hideStatusBar
        self.autoPageEnabled = autoPageEnabled
        self.landscapeLockEnabled = landscapeLockEnabled
        self.keepScreenOnEnabled = keepScreenOnEnabled
        self.statusInfoEnabled = statusInfoEnabled
        self.hapticFeedbackEnabled = hapticFeedbackEnabled
        self.cacheNextEnabled = cacheNextEnabled
    }

    /// Backward-compatible decoder: falls back to defaults for keys absent
    /// in older persisted settings files.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fontSize = try c.decodeIfPresent(Int.self, forKey: .fontSize) ?? 18
        fontFamily = try c.decodeIfPresent(String.self, forKey: .fontFamily) ?? Self.demoSerifFontFamily
        lineSpacing = try c.decodeIfPresent(Double.self, forKey: .lineSpacing) ?? 8.0
        paragraphSpacing = try c.decodeIfPresent(Double.self, forKey: .paragraphSpacing) ?? 16.0
        horizontalPadding = try c.decodeIfPresent(Double.self, forKey: .horizontalPadding) ?? 16.0
        verticalPadding = try c.decodeIfPresent(Double.self, forKey: .verticalPadding) ?? 16.0
        backgroundMode = try c.decodeIfPresent(ReaderBackgroundMode.self, forKey: .backgroundMode) ?? .light
        pageTurnMode = try c.decodeIfPresent(PageTurnMode.self, forKey: .pageTurnMode) ?? .scroll
        tapZoneEnabled = try c.decodeIfPresent(Bool.self, forKey: .tapZoneEnabled) ?? true
        brightnessOverrideEnabled = try c.decodeIfPresent(Bool.self, forKey: .brightnessOverrideEnabled) ?? false
        brightnessLevel = try c.decodeIfPresent(Double.self, forKey: .brightnessLevel) ?? 0.8
        volumeKeyPageTurnEnabled = try c.decodeIfPresent(Bool.self, forKey: .volumeKeyPageTurnEnabled) ?? false
        dualPageEnabled = try c.decodeIfPresent(Bool.self, forKey: .dualPageEnabled) ?? false
        // 新增字段：缺失时回落到默认值，保证旧持久化文件可平滑升级
        hideStatusBar = try c.decodeIfPresent(Bool.self, forKey: .hideStatusBar) ?? false
        autoPageEnabled = try c.decodeIfPresent(Bool.self, forKey: .autoPageEnabled) ?? false
        landscapeLockEnabled = try c.decodeIfPresent(Bool.self, forKey: .landscapeLockEnabled) ?? false
        keepScreenOnEnabled = try c.decodeIfPresent(Bool.self, forKey: .keepScreenOnEnabled) ?? false
        statusInfoEnabled = try c.decodeIfPresent(Bool.self, forKey: .statusInfoEnabled) ?? true
        hapticFeedbackEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticFeedbackEnabled) ?? false
        cacheNextEnabled = try c.decodeIfPresent(Bool.self, forKey: .cacheNextEnabled) ?? true
    }

    public static let `default` = ReaderDisplaySettings()
}
