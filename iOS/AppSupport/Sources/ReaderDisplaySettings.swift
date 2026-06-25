import Foundation

public enum ReaderBackgroundMode: String, Codable, CaseIterable {
    case light
    case sepia
    case dark

    public var backgroundColor: String {
        switch self {
        case .light: return "#FFFFFF"
        case .sepia: return "#F4ECD8"
        case .dark: return "#1C1C1E"
        }
    }

    public var textColor: String {
        switch self {
        case .light: return "#000000"
        case .sepia: return "#5C4B37"
        case .dark: return "#FFFFFF"
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

    public init(
        fontSize: Int = 18,
        fontFamily: String = "SF Pro Display",
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
        dualPageEnabled: Bool = false
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
    }

    /// Backward-compatible decoder: falls back to defaults for keys absent
    /// in older persisted settings files.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fontSize = try c.decodeIfPresent(Int.self, forKey: .fontSize) ?? 18
        fontFamily = try c.decodeIfPresent(String.self, forKey: .fontFamily) ?? "SF Pro Display"
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
    }

    public static let `default` = ReaderDisplaySettings()
}