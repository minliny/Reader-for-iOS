import SwiftUI
import ReaderAppSupport

/// 跨平台 Reader 字体 token
/// 真源：Reader-Core docs/cross-platform-ui/CROSS_PLATFORM_UI_BASELINE.md §4.2
public enum ReaderTypography {
    /// 真源：Reader UI `frontend-demo/tokens.css` `--reader-ds-font-serif`。
    public static let demoSerifSource = "Reader UI/frontend-demo/tokens.css --reader-ds-font-serif"
    public static let demoSerifPrimaryFamily = ReaderDisplaySettings.demoSerifFontFamily
    public static let demoSerifRegularPostScriptName = "STSongti-SC-Regular"
    public static let demoSerifBoldPostScriptName = "STSongti-SC-Bold"
    public static let demoSerifFallbackFamilies = [
        "Songti SC",
        "STSong",
        "Noto Serif CJK SC",
        "Source Han Serif SC",
        "Georgia",
        "Palatino",
        "Times New Roman"
    ]
    public static let legacyReaderSerifFamilies = [
        ReaderDisplaySettings.legacySansDefaultFontFamily,
        "Georgia",
        "Palatino",
        "Times New Roman"
    ]

    /// 阅读标题 28/36/700
    public static let readerTitle = demoSerif(size: 28, weight: .bold)
    /// 正文 18/1.72/400
    public static let readerBody = demoSerif(size: 18)
    /// 控制面板标题 18/24/700
    public static let controlTitle = Font.system(size: 18, weight: .bold)
    /// 控制面板标签 12/16/500
    public static let controlLabel = Font.system(size: 12, weight: .medium)
    /// 列表标题 14/18/600
    public static let listTitle = Font.system(size: 14, weight: .semibold)
    /// 页面标题 20/26/700
    public static let pageTitle = Font.system(size: 20, weight: .bold)
    /// 章节标题 28/36/700（同 readerTitle）
    public static let chapterTitle = demoSerif(size: 28, weight: .bold)

    public static func demoSerif(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(demoSerifPostScriptName(for: weight), size: size)
    }

    public static func readerDisplayFont(
        family: String,
        size: CGFloat,
        weight: Font.Weight = .regular
    ) -> Font {
        let resolved = resolvedReaderFontFamily(family)
        if resolved == demoSerifPrimaryFamily {
            return demoSerif(size: size, weight: weight)
        }
        return Font.custom(resolved, size: size).weight(weight)
    }

    public static func resolvedReaderFontFamily(_ family: String) -> String {
        let trimmed = family.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || legacyReaderSerifFamilies.contains(trimmed) {
            return demoSerifPrimaryFamily
        }
        return trimmed
    }

    private static func demoSerifPostScriptName(for weight: Font.Weight) -> String {
        if weight == .semibold || weight == .bold || weight == .heavy || weight == .black {
            return demoSerifBoldPostScriptName
        }
        return demoSerifRegularPostScriptName
    }
}

public extension CGFloat {
    /// 正文行高倍数 1.72
    static let readerBodyLineHeight: CGFloat = 1.72
}
