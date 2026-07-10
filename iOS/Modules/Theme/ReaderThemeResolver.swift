import SwiftUI

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

    /// 4 个纸张主题 ID（与 demo 主题网格一致）。
    public static let allOptions: [String] = ["paper", "warm", "green", "blue"]

    /// 主题展示名（中文名，对照 demo 主题网格标签）。
    public static func displayName(_ themeId: String) -> String {
        switch themeId {
        case "warm":  return "护眼"
        case "green": return "绿意"
        case "blue":  return "静蓝"
        default:      return "纸张"
        }
    }

    // MARK: - Swatch（快捷 4 色板填充色）

    /// 色板填充色（hex）。day: #F5EAD8 / #FBF0DF / #E7F0E2 / #E9F1F4，
    /// night: #2D2924 / #27231F / #202B26 / #232934（对照 demo fixture 真值）。
    public static func swatchHex(themeId: String, isNight: Bool) -> String {
        if isNight {
            switch themeId {
            case "warm":  return "#27231F"
            case "green": return "#202B26"
            case "blue":  return "#232934"
            default:      return "#2D2924"
            }
        } else {
            switch themeId {
            case "warm":  return "#FBF0DF"
            case "green": return "#E7F0E2"
            case "blue":  return "#E9F1F4"
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
            case "warm":  return Color(red: 0x27/255, green: 0x23/255, blue: 0x1F/255)
            case "green": return Color(red: 0x20/255, green: 0x2B/255, blue: 0x26/255)
            case "blue":  return Color(red: 0x23/255, green: 0x29/255, blue: 0x34/255)
            default:      return Color(red: 0x2D/255, green: 0x29/255, blue: 0x24/255)
            }
        } else {
            switch themeId {
            case "warm":  return Color(red: 0xFB/255, green: 0xF0/255, blue: 0xDF/255)
            case "green": return Color(red: 0xE7/255, green: 0xF0/255, blue: 0xE2/255)
            case "blue":  return Color(red: 0xE9/255, green: 0xF1/255, blue: 0xF4/255)
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
