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
        default:
            return nil
        }
    }

    public static func length(for token: ReaderUIContract.Token) -> CGFloat? {
        switch token.category {
        case .spacing, .size, .radius, .textConstraint:
            return length(named: token.name)
        default:
            return nil
        }
    }

    public static func length(named name: String) -> CGFloat? {
        guard let token = token(named: name),
              [.spacing, .size, .radius, .textConstraint].contains(token.category) else {
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
