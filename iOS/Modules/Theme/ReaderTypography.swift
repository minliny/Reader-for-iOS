import SwiftUI
import ReaderAppSupport

/// Reader 字体 token（demo `frontend-demo-optimized/tokens.css` `--fd-ds-font-*` /
/// `--fd-ds-type-*-size` 真源）。
///
/// 注意：demo `tokens.css` 仅定义 7 个字号 token（app-title 20 / page-title 20 /
/// section-title 15 / book-title 14 / book-meta 12 / reader-body 18 /
/// reader-control-label 12）。`readerTitle` / `chapterTitle` 28px 用于阅读器内
/// 书章节大标题（书内文本，非 UI chrome），demo 无对应 token；`controlTitle` 18px
/// 用于 reader 控制面板标题，demo `.fd-reader-panel-title` 实际为 13px/900，
/// 此处保留 18px 作为 reader 覆盖层标题层级，已标注偏差。
public enum ReaderTypography {
    /// 真源：Reader UI `frontend-demo-optimized/tokens.css` `--fd-ds-font-serif`。
    public static let demoSerifSource = "Reader UI/frontend-demo-optimized/tokens.css --fd-ds-font-serif"
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

    /// 阅读器内书章节大标题 28px serif bold（demo 无 28px token，用于书内文本非 UI chrome）。
    public static let readerTitle = demoSerif(size: 28, weight: .bold)
    /// 正文 18px serif（对应 demo `--fd-ds-type-reader-body-size: 18px`）。
    public static let readerBody = demoSerif(size: 18)
    /// 控制面板标题 18px bold（demo `.fd-reader-panel-title` 实际 13px/900，
    /// 此处 18px 作为 reader 覆盖层标题层级，存在偏差）。
    public static let controlTitle = Font.system(size: 18, weight: .bold)
    /// 控制面板标签 12px medium（对应 demo `--fd-ds-type-reader-control-label-size: 12px`）。
    public static let controlLabel = Font.system(size: 12, weight: .medium)
    /// 列表标题 14px semibold（对应 demo `--fd-ds-type-book-title-size: 14px`）。
    public static let listTitle = Font.system(size: 14, weight: .semibold)
    /// 页面标题 20px bold（对应 demo `--fd-ds-type-page-title-size: 20px`）。
    public static let pageTitle = Font.system(size: 20, weight: .bold)
    /// 章节标题 28px serif bold（同 readerTitle，demo 无对应 token）。
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
