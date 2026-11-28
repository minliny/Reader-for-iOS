import SwiftUI

public struct ReaderTheme: Sendable, Equatable {
    public let night: Bool

    public init(night: Bool) { self.night = night }

    public var background: Color { color(.appWindowBackground) }
    public var surface: Color { color(.tokCardBg) }
    public var elevated: Color { color(.tokSurfaceElevated) }
    public var field: Color { color(.tokSurfaceField) }
    public var panel: Color { color(.tokSurfacePanel) }
    public var primaryText: Color { color(.appWindowForeground) }
    public var secondaryText: Color { color(.tokMuted) }
    public var mutedText: Color { color(.tokMessageMuted) }
    public var accent: Color { color(.tokPrimaryText) }
    public var accentFill: Color { color(.tokPrimaryDark) }
    public var onAccent: Color { color(.tokOnPrimary) }
    public var accentTint: Color { color(.tokPrimarySoft) }
    public var divider: Color { color(.tokRowDivider) }
    public var outline: Color { color(.tokBorder) }
    public var progressTrack: Color { color(.tokLine) }
    public var mutedFill: Color { color(.tokMetaBg) }
    public var danger: Color { color(.tokDanger) }
    public var dangerTint: Color { color(.appActionDestructiveSoft) }
    public var success: Color { color(.tokGreen) }
    public var warning: Color { color(.tokAccent) }
    public var shadow: Color { color(.appShadowDialog) }
    public var scrim: Color { color(.tokSsDrawerScrim) }
    public var coverPlaceholder: Color { color(.tokPrimaryBg) }
    public var messageSurface: Color { color(.tokMessageSurface) }
    public var messageText: Color { color(.tokMessageInk) }
    public var messageBorder: Color { color(.tokMessageBorder) }
    public var noticeSurface: Color { color(.tokMessageNotice) }
    public var noticeText: Color { color(.tokMessageNoticeInk) }
    public var messageSoftSurface: Color { color(.tokMessageSoft) }
    public var messageSoftText: Color { color(.tokMessageSoftInk) }

    public var press: Color {
        color(.tokInk).opacity(night ? ReaderDesignMetrics.pressNightOpacity : ReaderDesignMetrics.pressDayOpacity)
    }

    // Recessed segmented rail tokens aligned with Reader-UI/theme/registry.json (app.segment.*).
    public var segmentTrack: Color {
        night
            ? Color(.sRGB, red: 11.0 / 255.0, green: 13.0 / 255.0, blue: 11.0 / 255.0, opacity: 1)
            : Color(.sRGB, red: 226.0 / 255.0, green: 217.0 / 255.0, blue: 201.0 / 255.0, opacity: 1)
    }
    public var segmentTrackTopShadow: Color {
        night
            ? Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.72)
            : Color(.sRGB, red: 62.0 / 255.0, green: 50.0 / 255.0, blue: 35.0 / 255.0, opacity: 0.18)
    }
    public var segmentTrackBorder: Color {
        night
            ? Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.45)
            : Color(.sRGB, red: 92.0 / 255.0, green: 79.0 / 255.0, blue: 63.0 / 255.0, opacity: 0.14)
    }
    public var segmentTrackBevel: Color {
        night
            ? Color(.sRGB, red: 236.0 / 255.0, green: 232.0 / 255.0, blue: 224.0 / 255.0, opacity: 0.09)
            : Color(.sRGB, red: 255.0 / 255.0, green: 253.0 / 255.0, blue: 249.0 / 255.0, opacity: 0.90)
    }
    public var segmentThumb: Color {
        night
            ? Color(.sRGB, red: 40.0 / 255.0, green: 46.0 / 255.0, blue: 41.0 / 255.0, opacity: 1)
            : Color(.sRGB, red: 255.0 / 255.0, green: 253.0 / 255.0, blue: 249.0 / 255.0, opacity: 1)
    }
    public var segmentThumbShadow: Color {
        night
            ? Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.52)
            : Color(.sRGB, red: 45.0 / 255.0, green: 36.0 / 255.0, blue: 26.0 / 255.0, opacity: 0.16)
    }
    public var segmentThumbHighlight: Color {
        night
            ? Color(.sRGB, red: 236.0 / 255.0, green: 232.0 / 255.0, blue: 224.0 / 255.0, opacity: 0.13)
            : Color(.sRGB, red: 255.0 / 255.0, green: 255.0 / 255.0, blue: 255.0 / 255.0, opacity: 0.95)
    }

    func color(_ role: ReaderAppRole) -> Color {
        ReaderThemeTokens.color(role, night: night).swiftUIColor
    }
}

private struct ReaderThemeKey: EnvironmentKey {
    static let defaultValue = ReaderTheme(night: false)
}

public extension EnvironmentValues {
    var readerTheme: ReaderTheme {
        get { self[ReaderThemeKey.self] }
        set { self[ReaderThemeKey.self] = newValue }
    }
}

public extension View {
    func readerDesign() -> some View { modifier(ReaderDesignStyle()) }
}

private struct ReaderDesignStyle: ViewModifier {
    @Environment(\.readerTheme) private var theme
    func body(content: Content) -> some View {
        content
            .tint(theme.accent)
            .foregroundStyle(theme.primaryText)
    }
}

extension ReaderThemeColor {
    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    @MainActor var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
