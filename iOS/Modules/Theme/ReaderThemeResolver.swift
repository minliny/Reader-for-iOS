import SwiftUI
import ReaderUIContract

/// Reader 主题解析器（对照 HarmonyOS `ReaderThemeResolver.ets`）。
///
/// 8 主题 = 4 纸张变体（paper / warm / green / blue）× 2 明暗（day / night）。
/// 真源：demo `render-runtime.js` `readerThemeStyle()` + `frontend-demo-optimized`
/// 的纸张/墨色 fixture。本解析器只承载契约色值语义，不复制 Web CSS / DOM。
///
/// 职责：
/// - 提供 4 个主题选项（`allOptions`）供主题网格 / 快捷色板遍历。
/// - `swatchHex(themeId:isNight:)` 返回色板填充色（快捷 4 色板用）。
/// - `palette(themeId:isNight:)` 返回解析后的 `ReaderThemePalette`（含纸张背景 /
///   墨色 / 控制层色），供 `ReaderThemeManager` 注入到 `@Environment(\.readerThemePalette)`。
public enum ReaderThemeResolver {

    public struct FullAppearanceOption: Identifiable, Equatable {
        public let id: String
        public let themeId: String
        public let label: String
        public let isNight: Bool

        public init(themeId: String, label: String, isNight: Bool) {
            self.id = "\(themeId)-\(isNight ? "night" : "day")"
            self.themeId = themeId
            self.label = label
            self.isNight = isNight
        }
    }

    /// 4 个纸张主题 ID（与 demo 主题网格一致）。
    public static let allOptions: [String] = ReaderAppearanceSpecRegistry.themes
        .filter { $0.scheme == "day" }
        .map(\.id)

    /// Reader 2 / Full / AppearanceContent 的唯一展示顺序。
    public static let fullAppearanceOptions: [FullAppearanceOption] =
        ReaderAppearanceSpecRegistry.themes.map { theme in
            .init(
                themeId: theme.id.replacingOccurrences(of: "-night", with: ""),
                label: theme.label,
                isNight: theme.scheme == "night"
            )
        }

    /// 主题展示名（中文名，对照 demo 主题网格标签）。
    public static func displayName(_ themeId: String) -> String {
        ReaderAppearanceSpecRegistry.theme(id: themeId)?.label ?? themeId
    }

    // MARK: - Swatch（快捷 4 色板填充色）

    /// 色板填充色（hex），与 Reader 2 / Full / AppearanceContent 对齐。
    public static func swatchHex(themeId: String, isNight: Bool) -> String {
        let appearanceId = isNight ? "\(themeId)-night" : themeId
        if let generated = ReaderAppearanceSpecRegistry.theme(id: appearanceId) {
            return generated.swatchHex
        }
        if isNight {
            switch themeId {
            case "warm":  return "#302922"
            case "green": return "#263129"
            case "blue":  return "#26231F"
            default:      return "#34302B"
            }
        } else {
            switch themeId {
            case "warm":  return "#FBF0DF"
            case "green": return "#E7F0E2"
            case "blue":  return "#FFFFFF"
            default:      return "#F5EAD8"
            }
        }
    }

    /// 色板填充色（SwiftUI.Color，便捷入口）。
    public static func swatchColor(themeId: String, isNight: Bool) -> Color {
        Color(hex: swatchHex(themeId: themeId, isNight: isNight))
    }

    // MARK: - Paper / Ink（阅读背景 + 正文墨色，按主题 + 明暗变化）

    /// 阅读纸张背景色（`.fd-ir-reading-layer` paper / 控制层 paperSolid）。
    /// day 取各主题的纸张色；night 取各主题的暗纸色（对照 demo `--fd-paper` night 变体）。
    public static func paperColor(themeId: String, isNight: Bool) -> Color {
        if isNight {
            switch themeId {
            case "warm":  return Color(red: 0x30/255, green: 0x29/255, blue: 0x22/255)
            case "green": return Color(red: 0x26/255, green: 0x31/255, blue: 0x29/255)
            case "blue":  return Color(red: 0x26/255, green: 0x23/255, blue: 0x1F/255)
            default:      return Color(red: 0x34/255, green: 0x30/255, blue: 0x2B/255)
            }
        } else {
            switch themeId {
            case "warm":  return Color(red: 0xFB/255, green: 0xF0/255, blue: 0xDF/255)
            case "green": return Color(red: 0xE7/255, green: 0xF0/255, blue: 0xE2/255)
            case "blue":  return .white
            default:      return Color(red: 0xF5/255, green: 0xEA/255, blue: 0xD8/255)
            }
        }
    }

    /// 正文墨色（`.fd-ir-reading-layer p` color）。day 取深墨，night 取浅米墨
    /// （对照 demo `--fd-ink` day #1f1b17 / night #eadfce，各主题轻微偏色）。
    public static func inkColor(themeId: String, isNight: Bool) -> Color {
        if isNight {
            switch themeId {
            case "warm":  return Color(red: 0xE6/255, green: 0xD6/255, blue: 0xBE/255)
            case "green": return Color(red: 0xCF/255, green: 0xE2/255, blue: 0xD2/255)
            case "blue":  return Color(red: 0xC8/255, green: 0xD6/255, blue: 0xE6/255)
            default:      return Color(red: 0xEA/255, green: 0xDF/255, blue: 0xCE/255)
            }
        } else {
            switch themeId {
            case "warm":  return Color(red: 0x4A/255, green: 0x3B/255, blue: 0x2A/255)
            case "green": return Color(red: 0x2A/255, green: 0x3D/255, blue: 0x32/255)
            case "blue":  return Color(red: 0x2A/255, green: 0x34/255, blue: 0x42/255)
            default:      return Color(red: 0x1f/255, green: 0x1b/255, blue: 0x17/255)
            }
        }
    }

    // MARK: - Palette

    /// 解析后的调色板（供 `ReaderThemeManager.palette` 使用）。
    /// 控制层色（surface/panel/ink/muted/icon/primary/...）沿用 `ReaderThemePalette`
    /// 的 day/night 解析；纸张背景 / 正文墨色按 `themeId` 覆盖。
    public static func palette(themeId: String, isNight: Bool) -> ReaderThemePalette {
        ReaderThemePalette(themeId: themeId, isNight: isNight)
    }
}
