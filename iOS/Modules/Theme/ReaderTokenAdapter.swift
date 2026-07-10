import SwiftUI
import ReaderUIContract

/// Contract token facade for native SwiftUI surfaces.
///
/// Reader UI owns the generated `Token` records. This adapter is the iOS entry
/// point that maps those semantic names onto existing native token values.
/// Unknown tokens return `nil` so tests and future lint can distinguish
/// unsupported contract coverage from intentional platform defaults.
public enum ReaderTokenAdapter {
    public static func token(named name: String) -> ReaderUIContract.Token? {
        ReaderUIContract.TokenRegistry.token(named: name)
    }

    public static func color(for token: ReaderUIContract.Token, colorScheme: ColorScheme = .light) -> Color? {
        guard token.category == .color else { return nil }
        return color(named: token.name, colorScheme: colorScheme)
    }

    public static func color(named name: String, colorScheme: ColorScheme = .light) -> Color? {
        guard token(named: name)?.category == .color else { return nil }
        let night = colorScheme == .dark
        switch name {
        case "--fd-ds-color-paper":
            return night ? ReaderDesignTokens.Color.Night.paperSolid : ReaderDesignTokens.Color.paperSolid
        case "--fd-ds-color-paper-bright":
            return night ? ReaderDesignTokens.Color.Night.paperSolidAlt : ReaderDesignTokens.Color.paperSolidAlt
        case "--fd-ds-color-ink":
            return night ? ReaderDesignTokens.Color.Night.ink : ReaderDesignTokens.Color.ink
        case "--fd-ds-color-control-ink":
            return night ? ReaderDesignTokens.Color.Night.ink : ReaderDesignTokens.Color.controlInk
        case "--fd-ds-color-surface":
            return night ? ReaderDesignTokens.Color.Night.surface : ReaderDesignTokens.Color.surface
        case "--fd-ds-color-surface-soft":
            return night ? ReaderDesignTokens.Color.Night.panelSoft : ReaderDesignTokens.Color.controlBackground
        case "--fd-ds-color-border":
            return night ? ReaderDesignTokens.Color.Night.line : ReaderDesignTokens.Color.mainNavBorder
        case "--fd-ds-color-primary":
            return night ? ReaderDesignTokens.Color.Night.primary : ReaderDesignTokens.Color.primary
        case "--fd-ds-color-primary-dark":
            return night ? ReaderDesignTokens.Color.Night.primaryDark : ReaderDesignTokens.Color.primaryDark
        case "--fd-ds-color-accent":
            return night ? ReaderDesignTokens.Color.Night.accent : ReaderDesignTokens.Color.accent
        case "--fd-ds-color-bottom-bar-bg":
            return night ? ReaderDesignTokens.Color.Night.surface : ReaderDesignTokens.Color.bottomBarBg
        case "--fd-ds-color-floating-control-bg":
            return night ? ReaderDesignTokens.Color.Night.surface : ReaderDesignTokens.Color.floatingControlBg
        case "--fd-ds-color-floating-control-bg-alt":
            return night ? ReaderDesignTokens.Color.Night.panelSoft : ReaderDesignTokens.Color.floatingControlBgAlt
        case "--fd-ds-color-meta-bg":
            return night ? ReaderDesignTokens.Color.Night.panel : ReaderDesignTokens.Color.metaBg
        case "--fd-ds-color-muted":
            return night ? ReaderDesignTokens.Color.Night.muted : ReaderDesignTokens.Color.muted
        case "--fd-ds-color-rss-unread":
            return night ? ReaderDesignTokens.Color.Night.action : ReaderDesignTokens.Color.primary
        // P2.4: 补全缺失 color token（16/23 → 23/23）
        case "--fd-ds-color-status-good":
            // #338144 状态良好绿（light/dark 一致）
            return SwiftUI.Color(red: 0x33/255, green: 0x81/255, blue: 0x44/255)
        case "--fd-ds-color-status-warn":
            // #d7473e 状态警告红（light/dark 一致）
            return SwiftUI.Color(red: 0xd7/255, green: 0x47/255, blue: 0x3e/255)
        case "--fd-ds-color-paper-night":
            // #181f22 夜间纸面背景（固定值，不随 colorScheme 切换）
            return SwiftUI.Color(red: 0x18/255, green: 0x1f/255, blue: 0x22/255)
        case "--fd-ds-color-ink-night":
            // #d8ccc4 夜间文字色
            return SwiftUI.Color(red: 0xd8/255, green: 0xcc/255, blue: 0xc4/255)
        case "--fd-ds-color-control-ink-night":
            // #d7e1e5 夜间控制文字色
            return SwiftUI.Color(red: 0xd7/255, green: 0xe1/255, blue: 0xe5/255)
        case "--fd-ds-color-primary-night":
            // #8fb6ca 夜间主色（与 Night.primaryDark 一致）
            return ReaderDesignTokens.Color.Night.primaryDark
        case "--fd-ds-color-floating-control-bg-alt-night":
            // #2b3b43 夜间浮动控件 alt 背景
            return SwiftUI.Color(red: 0x2b/255, green: 0x3b/255, blue: 0x43/255)
        default:
            return nil
        }
    }

    // MARK: - Icon

    /// P2.4: 从 icon category token 解析对应的 `ReaderAssetIcon`。
    ///
    /// token.name 形如 `--fd-ds-icon-chevron`，去掉 `--fd-ds-icon-` 前缀后
    /// 得到 icon shortName（`chevron`），与 `ReaderAssetIcon.rawValue` 对齐。
    /// 非 icon category token 返回 nil。
    public static func icon(for token: ReaderUIContract.Token) -> ReaderAssetIcon? {
        guard token.category == .icon else { return nil }
        let name = token.name.replacingOccurrences(of: "--fd-ds-icon-", with: "")
        return ReaderAssetIcon(rawValue: name)
    }

    public static func length(for token: ReaderUIContract.Token) -> CGFloat? {
        switch token.category {
        case .spacing, .size, .radius, .textConstraint, .type:
            return length(named: token.name)
        default:
            return nil
        }
    }

    public static func length(named name: String) -> CGFloat? {
        guard let token = token(named: name),
              [.spacing, .size, .radius, .textConstraint, .type].contains(token.category) else {
            return nil
        }
        switch name {
        case "--fd-ds-space-screen-padding":
            return ReaderDesignTokens.demoContentHorizontalPadding
        case "--fd-ds-space-card-padding":
            return ReaderDesignTokens.cardPadding
        case "--fd-ds-space-safe-area-top":
            return ReaderDesignTokens.statusBarHeight / 2
        case "--fd-ds-space-safe-area-bottom":
            return 14
        case "--fd-ds-space-safe-area-horizontal":
            return ReaderDesignTokens.demoContentHorizontalPadding
        case "--fd-ds-space-keyboard-gap":
            return 12
        case "--fd-ds-space-md":
            return 16
        case "--fd-ds-size-bottom-bar-height", "--fd-ds-size-main-nav-height":
            return ReaderDesignTokens.mainNavHeight
        case "--fd-ds-size-reader-bottom-sheet-min-height":
            return ReaderDesignTokens.readerControlSheetHeight
        case "--fd-ds-size-reader-module-nav-height":
            return ReaderDesignTokens.readerModuleNavMinHeight
        case "--fd-ds-radius-card":
            return ReaderDesignTokens.bookCoverFrameCornerRadius
        case "--fd-ds-radius-control":
            return ReaderDesignTokens.mainNavCornerRadius
        case "--fd-ds-radius-bottom-sheet":
            return ReaderDesignTokens.readerModuleNavCornerRadius
        case "--fd-ds-text-reader-line-length":
            return 31
        default:
            if token.category == .type {
                return points(fromPxValue: token.value)
            }
            return nil
        }
    }

    public static func duration(for token: ReaderUIContract.Token, motion: MotionEnvironment = .shared) -> TimeInterval? {
        guard token.category == .motionDuration else { return nil }
        return duration(named: token.name, motion: motion)
    }

    public static func duration(named name: String, motion: MotionEnvironment = .shared) -> TimeInterval? {
        guard let token = token(named: name),
              token.category == .motionDuration,
              let seconds = seconds(fromDurationValue: token.value) else {
            return nil
        }
        return motion.duration(seconds)
    }

    public static func zIndex(for token: ReaderUIContract.Token) -> ReaderZIndex? {
        guard token.category == .zIndex else { return nil }
        return ReaderZIndex.from(tokenName: token.name)
    }

    public static func zIndex(named name: String) -> ReaderZIndex? {
        guard token(named: name)?.category == .zIndex else { return nil }
        return ReaderZIndex.from(tokenName: name)
    }

    public static func zIndexValue(for token: ReaderUIContract.Token) -> Double? {
        zIndex(for: token).map { $0.rawValue }
    }

    public static func font(for token: ReaderUIContract.Token, size: CGFloat) -> Font? {
        guard token.category == .font else { return nil }
        switch token.name {
        case "--fd-ds-font-sans":
            return Font.system(size: size, design: .default)
        case "--fd-ds-font-serif":
            return Font.custom("STSongti-SC-Regular", size: size)
        case "--fd-ds-font-kai":
            return Font.custom("STKaiti-SC-Regular", size: size)
        case "--fd-ds-font-fangsong":
            return Font.custom("STFangsong", size: size)
        case "--fd-ds-font-mono":
            return Font.system(size: size, design: .monospaced)
        default:
            return nil
        }
    }

    public static func font(named name: String, size: CGFloat) -> Font? {
        guard let token = token(named: name) else { return nil }
        return font(for: token, size: size)
    }

    public static func textConstraint(for token: ReaderUIContract.Token) -> Int? {
        guard token.category == .textConstraint else { return nil }
        return integer(fromValue: token.value)
    }

    public static func textConstraint(named name: String) -> Int? {
        guard let token = token(named: name),
              token.category == .textConstraint else {
            return nil
        }
        return integer(fromValue: token.value)
    }

    private static func points(fromPxValue value: String) -> CGFloat? {
        guard value.hasSuffix("px") else { return nil }
        return Double(value.dropLast(2)).map { CGFloat($0) }
    }

    private static func integer(fromValue value: String) -> Int? {
        let digits = value.prefix { $0.isNumber }
        return Int(digits)
    }

    private static func seconds(fromDurationValue value: String) -> TimeInterval? {
        if value.hasSuffix("ms") {
            return Double(value.dropLast(2)).map { $0 / 1000 }
        }
        if value.hasSuffix("s") {
            return Double(value.dropLast()).map { $0 }
        }
        return Double(value)
    }
}
