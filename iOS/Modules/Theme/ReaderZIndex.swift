import SwiftUI

/// Z-index token 映射，对齐 contract `--fd-ds-z-*` token（frontend-demo-optimized/tokens.css 真源）。
/// 用于 SwiftUI `.zIndex()` 修饰符，确保 overlay / sheet / dialog 层级与 demo 一致。
public enum ReaderZIndex: Double, CaseIterable {
    case content = 0
    case overlay = 10
    case mainNav = 20
    case bottomSheet = 30
    case flowWindow = 36
    case readerModuleNav = 40
    case settingsDropdown = 42
    case dialog = 60
    case keyboard = 70
    case devOverlay = 95
    case devRegion = 96
    case demoSwitch = 100

    /// 从 contract token name 解析 z-index。
    /// 例如 `--fd-ds-z-flow-window` → `.flowWindow`
    public static func from(tokenName: String) -> ReaderZIndex? {
        switch tokenName {
        case "--fd-ds-z-content": return .content
        case "--fd-ds-z-overlay": return .overlay
        case "--fd-ds-z-main-nav": return .mainNav
        case "--fd-ds-z-bottom-sheet": return .bottomSheet
        case "--fd-ds-z-flow-window": return .flowWindow
        case "--fd-ds-z-reader-module-nav": return .readerModuleNav
        case "--fd-ds-z-settings-dropdown": return .settingsDropdown
        case "--fd-ds-z-dialog": return .dialog
        case "--fd-ds-z-keyboard": return .keyboard
        case "--fd-ds-z-dev-overlay": return .devOverlay
        case "--fd-ds-z-dev-region": return .devRegion
        case "--fd-ds-z-demo-switch": return .demoSwitch
        default: return nil
        }
    }

    /// dev-overlay / dev-region / demo-switch 是 demo 调试层，iOS 生产代码不使用。
    public var isDebugOnly: Bool {
        switch self {
        case .devOverlay, .devRegion, .demoSwitch:
            return true
        default:
            return false
        }
    }
}
