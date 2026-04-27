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

public struct ReaderDisplaySettings: Codable, Equatable {
    public var fontSize: Int
    public var fontFamily: String
    public var lineSpacing: Double
    public var paragraphSpacing: Double
    public var horizontalPadding: Double
    public var verticalPadding: Double
    public var backgroundMode: ReaderBackgroundMode

    public init(
        fontSize: Int = 18,
        fontFamily: String = "SF Pro Display",
        lineSpacing: Double = 8.0,
        paragraphSpacing: Double = 16.0,
        horizontalPadding: Double = 16.0,
        verticalPadding: Double = 16.0,
        backgroundMode: ReaderBackgroundMode = .light
    ) {
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.lineSpacing = lineSpacing
        self.paragraphSpacing = paragraphSpacing
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.backgroundMode = backgroundMode
    }

    public static let `default` = ReaderDisplaySettings()
}