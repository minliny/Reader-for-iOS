import SwiftUI

public struct ReaderPaper: Sendable, Equatable, Identifiable {
    private let palette: ReaderPaperPalette

    private init(_ palette: ReaderPaperPalette) { self.palette = palette }

    public init(id: String) {
        self.init(ReaderPaperThemes.byId(id) ?? ReaderPaperThemes.all[0])
    }

    public static let all = ReaderPaperThemes.all.map(Self.init)
    public var id: String { palette.id }
    public var name: String { palette.displayName }
    public var isDark: Bool { palette.scheme == "night" }
    public var background: Color { color(palette.paperStart) }
    public var backgroundEnd: Color { color(palette.paperEnd) }
    public var foreground: Color { color(palette.ink) }
    public var muted: Color { color(palette.chromeMeta) }
    public var controlBackground: Color { color(palette.paperBack) }
    public var statusBackground: Color { color(palette.statusBackground) }
    public var statusForeground: Color { color(palette.statusForeground) }
    public var selection: Color { color(palette.selection) }
    public var swatch: Color { color(palette.swatch) }

    public var webBackground: String { cssHex(palette.paperStart) }
    public var webForeground: String { cssHex(palette.ink) }

    public var foregroundARGB: UInt32 { palette.ink }
    public var backgroundARGB: UInt32 { palette.paperStart }
    public var statusForegroundARGB: UInt32 { palette.statusForeground }
    public var statusBackgroundARGB: UInt32 { palette.statusBackground }

    @MainActor public var uiForeground: UIColor { ReaderThemeColor(argb: palette.ink).uiColor }
    @MainActor public var uiStatusForeground: UIColor { ReaderThemeColor(argb: palette.statusForeground).uiColor }

    private func cssHex(_ argb: UInt32) -> String { String(format: "#%06X", argb & 0xFFFFFF) }

    private func color(_ argb: UInt32) -> Color { ReaderThemeColor(argb: argb).swiftUIColor }
}
