import SwiftUI

/// The app scheme and the user's reading paper are independent choices.
enum ReaderTheme: String, CaseIterable, Codable, Identifiable {
    case day, warm, night, warmNight, paper, green, paperNight, greenNight
    var id: String { rawValue }
    var isDark: Bool { [.night, .warmNight, .paperNight, .greenNight].contains(self) }
    var displayName: String { ReaderThemeRegistry.themeName(rawValue) }
}

/// Values come from Reader-UI@95366cd:theme/registry.json, bundled byte for byte.
struct ReaderPalette {
    let scheme: ColorScheme
    init(_ scheme: ColorScheme = .light) { self.scheme = scheme }
    init(scheme: ColorScheme) { self.scheme = scheme }

    func app(_ role: String) -> Color {
        ReaderThemeRegistry.appColor(role, dark: scheme == .dark)
    }
    var paper: Color { app("TOK_PAPER") }
    var ink: Color { app("TOK_INK") }
    var muted: Color { app("TOK_MUTED") }
    var card: Color { app("TOK_CARD_BG") }
    var panel: Color { app("TOK_SURFACE_PANEL") }
    var field: Color { app("TOK_FIELD_SURFACE") }
    var border: Color { app("TOK_BORDER") }
    var green: Color { app("TOK_GREEN") }
    var accent: Color { app("TOK_ACCENT") }
    var primaryDark: Color { app("TOK_PRIMARY_DARK") }
    var primarySoft: Color { app("TOK_PRIMARY_SOFT") }
    var onPrimary: Color { app("TOK_ON_PRIMARY") }
    var readInk: Color { app("TOK_READ_INK") }
    var readPrimary: Color { app("TOK_READ_PRIMARY") }
    var readElevated: Color { app("TOK_READ_ELEVATED") }
    var elevated: Color { readElevated }
    var line: Color { app("TOK_LINE") }
    func reader(_ theme: ReaderTheme) -> ReaderPaperPalette { ReaderPaperPalette(theme: theme) }
}

struct ReaderPaperPalette {
    let theme: ReaderTheme
    init(theme: ReaderTheme = .day) { self.theme = theme }
    var paper: Color { color("paperStart") }
    var paperEnd: Color { color("paperEnd") }
    var ink: Color { color("ink") }
    var meta: Color { color("chromeMeta") }
    var selection: Color { color("selection") }
    var paperTexture: Bool { ReaderThemeRegistry.effect("paperTexture", theme: theme.rawValue) }
    var sourcePaperLighting: Bool { ReaderThemeRegistry.effect("sourcePaperLighting", theme: theme.rawValue) }
    private func color(_ role: String) -> Color { ReaderThemeRegistry.readerColor(role, theme: theme.rawValue) }
}

private enum ReaderThemeRegistry {
    static let registry: [String: Any] = {
        let bundle = Bundle.main
        let url = bundle.url(forResource: "theme-registry", withExtension: "json", subdirectory: "Reference")
            ?? bundle.url(forResource: "theme-registry", withExtension: "json")
        guard let url, let bytes = try? Data(contentsOf: url),
              let value = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
            preconditionFailure("The frozen Reader theme registry is missing from the application resources.")
        }
        return value
    }()
    static func appColor(_ role: String, dark: Bool) -> Color {
        guard let roles = registry["appRoles"] as? [String: Any],
              let entry = roles[role] as? [String: Any],
              let rgba = entry[dark ? "night" : "day"] as? [String: Any] else {
            preconditionFailure("Unknown Reader app color role: \(role)")
        }
        return color(rgba)
    }
    static func reader(_ theme: String) -> [String: Any] {
        guard let themes = registry["reader"] as? [String: Any], let entry = themes[theme] as? [String: Any] else {
            preconditionFailure("Unknown Reader paper: \(theme)")
        }
        return entry
    }
    static func readerColor(_ role: String, theme: String) -> Color {
        guard let roles = reader(theme)["roles"] as? [String: Any], let rgba = roles[role] as? [String: Any] else {
            preconditionFailure("Unknown Reader paper role: \(role)")
        }
        return color(rgba)
    }
    static func effect(_ key: String, theme: String) -> Bool {
        (reader(theme)["effects"] as? [String: Any])?[key] as? Bool ?? false
    }
    static func themeName(_ theme: String) -> String { reader(theme)["displayName"] as? String ?? theme }
    static func color(_ value: [String: Any]) -> Color {
        func number(_ key: String, fallback: Double = 0) -> Double {
            (value[key] as? NSNumber)?.doubleValue ?? fallback
        }
        return Color(.sRGB, red: number("r") / 255, green: number("g") / 255,
                     blue: number("b") / 255, opacity: number("a", fallback: 1))
    }
}
