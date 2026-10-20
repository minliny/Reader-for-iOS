import Foundation
import Combine

/// Host-owned display choices, independent of Core's durable books and positions.
@MainActor
final class ReaderPreferences: ObservableObject {
    private let defaults: UserDefaults
    @Published var appDark: Bool { didSet { defaults.set(appDark, forKey: "appearance.appDark") } }
    @Published var theme: ReaderTheme { didSet { defaults.set(theme.rawValue, forKey: "appearance.paper") } }
    @Published var fontSize: Double { didSet { defaults.set(fontSize, forKey: "appearance.fontSize") } }
    @Published var lineHeight: Double { didSet { defaults.set(lineHeight, forKey: "appearance.lineHeight") } }
    @Published var grid: Bool { didSet { defaults.set(grid, forKey: "bookshelf.grid") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appDark = defaults.bool(forKey: "appearance.appDark")
        theme = ReaderTheme(rawValue: defaults.string(forKey: "appearance.paper") ?? "day") ?? .day
        fontSize = defaults.object(forKey: "appearance.fontSize") == nil ? 18 : min(40, max(12, defaults.double(forKey: "appearance.fontSize")))
        lineHeight = defaults.object(forKey: "appearance.lineHeight") == nil ? 1.96 : min(2.8, max(1.2, defaults.double(forKey: "appearance.lineHeight")))
        grid = defaults.bool(forKey: "bookshelf.grid")
    }
}
