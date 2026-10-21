import Foundation
import Combine

enum ReaderTextAlignment: String, Codable, CaseIterable, Identifiable {
    case justified, left, center, right
    var id: String { rawValue }
}

enum ReaderPageMode: String, Codable, CaseIterable, Identifiable {
    case scroll, paged
    var id: String { rawValue }
    var displayName: String { self == .scroll ? "滚动" : "分页" }
}

enum ReaderOrientation: String, Codable, CaseIterable, Identifiable {
    case system, portrait, landscape
    var id: String { rawValue }
    var displayName: String {
        switch self { case .system: return "跟随系统"; case .portrait: return "竖屏"; case .landscape: return "横屏" }
    }
}

enum ReaderScreenAwakeMode: String, Codable, CaseIterable, Identifiable {
    case system, oneMinute, fiveMinutes, tenMinutes, alwaysOn
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .oneMinute: return "1 分钟"
        case .fiveMinutes: return "5 分钟"
        case .tenMinutes: return "10 分钟"
        case .alwaysOn: return "始终开启"
        }
    }
    var leaseSeconds: TimeInterval? {
        switch self { case .oneMinute: return 60; case .fiveMinutes: return 300; case .tenMinutes: return 600; default: return nil }
    }
}

/// Host-owned display choices, independent of Core's durable books and positions.
@MainActor
final class ReaderPreferences: ObservableObject {
    private let defaults: UserDefaults
    private var projectingAppearance = false
    private var observedSystemDark: Bool?
    @Published var appDark: Bool {
        didSet {
            defaults.set(appDark, forKey: "appearance.appDark")
            guard !projectingAppearance else { return }
            projectingAppearance = true
            followSystem = false
            theme = appDark ? nightTheme : dayTheme
            projectingAppearance = false
        }
    }
    @Published var followSystem: Bool {
        didSet {
            defaults.set(followSystem, forKey: "appearance.followSystem")
            guard !projectingAppearance else { return }
            projectingAppearance = true
            let dark = followSystem ? (observedSystemDark ?? appDark) : appDark
            appDark = dark; theme = dark ? nightTheme : dayTheme
            projectingAppearance = false
        }
    }
    @Published var theme: ReaderTheme {
        didSet {
            defaults.set(theme.rawValue, forKey: "appearance.paper")
            guard !projectingAppearance else { return }
            let effectiveDark = followSystem ? (observedSystemDark ?? appDark) : appDark
            // Frozen ReaderThemeSelection: a same-scheme paper keeps system
            // mode; choosing the other scheme makes that scheme explicit.
            if theme.isDark != effectiveDark {
                projectingAppearance = true
                followSystem = false; appDark = theme.isDark
                projectingAppearance = false
            }
        }
    }
    @Published var dayTheme: ReaderTheme {
        didSet {
            if dayTheme.isDark { dayTheme = .day }
            defaults.set(dayTheme.rawValue, forKey: "appearance.defaultDayPaper")
        }
    }
    @Published var nightTheme: ReaderTheme {
        didSet {
            if !nightTheme.isDark { nightTheme = .night }
            defaults.set(nightTheme.rawValue, forKey: "appearance.defaultNightPaper")
        }
    }
    @Published var fontSize: Double { didSet { defaults.set(fontSize, forKey: "appearance.fontSize") } }
    @Published var lineHeight: Double { didSet { defaults.set(lineHeight, forKey: "appearance.lineHeight") } }
    @Published var grid: Bool { didSet { defaults.set(grid, forKey: "bookshelf.grid") } }
    @Published var paragraphSpacing: Double { didSet { defaults.set(paragraphSpacing, forKey: "appearance.paragraphSpacing") } }
    @Published var letterSpacing: Double { didSet { defaults.set(letterSpacing, forKey: "appearance.letterSpacing") } }
    /// Physical em indentation; it does not insert spaces into Core text.
    @Published var firstLineIndentEm: Double { didSet { defaults.set(firstLineIndentEm, forKey: "appearance.firstLineIndentEm") } }
    /// Zero keeps the frozen adaptive page margin.
    @Published var horizontalMargin: Double { didSet { defaults.set(horizontalMargin, forKey: "appearance.horizontalMargin") } }
    @Published var textAlignment: ReaderTextAlignment { didSet { defaults.set(textAlignment.rawValue, forKey: "appearance.alignment") } }
    /// Nil selects the registered Noto Serif default; ReaderFontLibrary also
    /// owns the explicit reader:system selector for the native iOS system face.
    @Published var fontPostScriptName: String? {
        didSet {
            defaults.set(fontPostScriptName, forKey: "appearance.fontPostScriptName")
            if fontPostScriptName != oldValue { fontSlotID = nil }
        }
    }
    /// Product slots may share a physical face (宋体 / 思源宋体).
    @Published var fontSlotID: String? { didSet { defaults.set(fontSlotID, forKey: "appearance.fontSlotID") } }
    @Published var pageMode: ReaderPageMode { didSet { defaults.set(pageMode.rawValue, forKey: "reader.pageMode") } }
    @Published var pageTransition: ReaderPageTransition { didSet { defaults.set(pageTransition.rawValue, forKey: "reader.pageTransition") } }
    @Published var autoPageSeconds: Double { didSet { defaults.set(autoPageSeconds, forKey: "reader.autoPageSeconds") } }
    @Published var autoPageTimerMinutes: Int { didSet { defaults.set(autoPageTimerMinutes, forKey: "reader.autoPageTimerMinutes") } }
    @Published var autoPageTimerSeconds: Int { didSet { defaults.set(autoPageTimerSeconds, forKey: "reader.autoPageTimerSeconds") } }
    @Published var autoPageFollowHighlight: Bool { didSet { defaults.set(autoPageFollowHighlight, forKey: "reader.autoPageFollowHighlight") } }
    @Published var screenTimeout: ReaderScreenAwakeMode {
        didSet {
            defaults.set(screenTimeout.rawValue, forKey: "reader.screenTimeout")
            defaults.set(screenTimeout == .alwaysOn, forKey: "reader.keepAwake")
        }
    }
    /// Compatibility for the old two-state caller; finite leases use screenTimeout.
    var keepAwake: Bool {
        get { screenTimeout == .alwaysOn }
        set { screenTimeout = newValue ? .alwaysOn : .system }
    }
    @Published var longPressSelectText: Bool { didSet { defaults.set(longPressSelectText, forKey: "reader.longPressSelectText") } }
    @Published var hideStatusBar: Bool { didSet { defaults.set(hideStatusBar, forKey: "reader.hideStatusBar") } }
    @Published var hideNavigationBar: Bool { didSet { defaults.set(hideNavigationBar, forKey: "reader.hideNavigationBar") } }
    @Published var extendIntoCutout: Bool { didSet { defaults.set(extendIntoCutout, forKey: "reader.extendIntoCutout") } }
    @Published var alignPageBottom: Bool { didSet { defaults.set(alignPageBottom, forKey: "reader.alignPageBottom") } }
    @Published var orientation: ReaderOrientation { didSet { defaults.set(orientation.rawValue, forKey: "reader.orientation") } }
    @Published var reduceMotion: Bool { didSet { defaults.set(reduceMotion, forKey: "appearance.reduceMotion") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appDark = defaults.bool(forKey: "appearance.appDark")
        let hasLegacyAppearance = defaults.object(forKey: "appearance.appDark") != nil || defaults.object(forKey: "appearance.paper") != nil
        followSystem = defaults.object(forKey: "appearance.followSystem") == nil ? !hasLegacyAppearance : defaults.bool(forKey: "appearance.followSystem")
        theme = ReaderTheme(rawValue: defaults.string(forKey: "appearance.paper") ?? "day") ?? .day
        let storedDay = ReaderTheme(rawValue: defaults.string(forKey: "appearance.defaultDayPaper") ?? "day") ?? .day
        dayTheme = storedDay.isDark ? .day : storedDay
        let storedNight = ReaderTheme(rawValue: defaults.string(forKey: "appearance.defaultNightPaper") ?? "night") ?? .night
        nightTheme = storedNight.isDark ? storedNight : .night
        fontSize = defaults.object(forKey: "appearance.fontSize") == nil ? 18 : min(40, max(12, defaults.double(forKey: "appearance.fontSize")))
        lineHeight = defaults.object(forKey: "appearance.lineHeight") == nil ? 1.96 : min(2.8, max(1.2, defaults.double(forKey: "appearance.lineHeight")))
        grid = defaults.bool(forKey: "bookshelf.grid")
        paragraphSpacing = Self.number(defaults, "appearance.paragraphSpacing", fallback: 16, range: 0...32)
        letterSpacing = Self.number(defaults, "appearance.letterSpacing", fallback: 0, range: -2...4)
        firstLineIndentEm = Self.number(defaults, "appearance.firstLineIndentEm", fallback: 0, range: 0...2)
        horizontalMargin = Self.number(defaults, "appearance.horizontalMargin", fallback: 0, range: 0...96)
        textAlignment = ReaderTextAlignment(rawValue: defaults.string(forKey: "appearance.alignment") ?? "justified") ?? .justified
        fontPostScriptName = defaults.string(forKey: "appearance.fontPostScriptName").flatMap { $0.isEmpty ? nil : $0 }
        fontSlotID = defaults.string(forKey: "appearance.fontSlotID")
        pageMode = ReaderPageMode(rawValue: defaults.string(forKey: "reader.pageMode") ?? "paged") ?? .paged
        pageTransition = ReaderPageTransition(rawValue: defaults.string(forKey: "reader.pageTransition") ?? "slide") ?? .slide
        // Host33f7 ReaderAutoPageFullState owns these whole-second UI bounds.
        autoPageSeconds = Self.number(defaults, "reader.autoPageSeconds", fallback: 8, range: 2...20).rounded(.towardZero)
        autoPageTimerMinutes = Int(Self.number(defaults, "reader.autoPageTimerMinutes", fallback: 15, range: 0...180).rounded(.towardZero))
        autoPageTimerSeconds = Int(Self.number(defaults, "reader.autoPageTimerSeconds", fallback: 0, range: 0...59).rounded(.towardZero))
        autoPageFollowHighlight = defaults.bool(forKey: "reader.autoPageFollowHighlight")
        screenTimeout = ReaderScreenAwakeMode(rawValue: defaults.string(forKey: "reader.screenTimeout") ?? "")
            ?? (defaults.bool(forKey: "reader.keepAwake") ? .alwaysOn : .system)
        longPressSelectText = defaults.object(forKey: "reader.longPressSelectText") == nil ? true : defaults.bool(forKey: "reader.longPressSelectText")
        hideStatusBar = defaults.bool(forKey: "reader.hideStatusBar")
        hideNavigationBar = defaults.bool(forKey: "reader.hideNavigationBar")
        extendIntoCutout = defaults.bool(forKey: "reader.extendIntoCutout")
        alignPageBottom = defaults.bool(forKey: "reader.alignPageBottom")
        orientation = ReaderOrientation(rawValue: defaults.string(forKey: "reader.orientation") ?? "system") ?? .system
        reduceMotion = defaults.bool(forKey: "appearance.reduceMotion")
        defaults.set(followSystem, forKey: "appearance.followSystem")
    }

    func resolvedAppDark(systemDark: Bool) -> Bool { followSystem ? systemDark : appDark }

    func resolvedTheme(systemDark: Bool) -> ReaderTheme {
        guard followSystem, theme.isDark != systemDark else { return theme }
        return systemDark ? nightTheme : dayTheme
    }

    /// Call with the unoverridden system scheme at the App boundary. Runtime
    /// observations are not a fifth persisted theme choice.
    func applySystemAppearance(systemDark: Bool) {
        let changed = observedSystemDark.map { $0 != systemDark } ?? false
        observedSystemDark = systemDark
        guard followSystem else { return }
        projectingAppearance = true
        appDark = systemDark
        if changed || theme.isDark != systemDark { theme = systemDark ? nightTheme : dayTheme }
        projectingAppearance = false
    }

    /// Selecting a paper never silently replaces a remembered default.
    func setDefaultTheme() {
        if theme.isDark { nightTheme = theme } else { dayTheme = theme }
    }

    private static func number(_ defaults: UserDefaults, _ key: String, fallback: Double,
                               range: ClosedRange<Double>) -> Double {
        guard defaults.object(forKey: key) != nil else { return fallback }
        let value = defaults.double(forKey: key)
        return value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }
}
