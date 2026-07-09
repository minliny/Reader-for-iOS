import SwiftUI
import ReaderUIContract

// MARK: - OverlayHost
//
// 21 种 Overlay 类型的 SwiftUI overlay 容器，z-index 按 `ReaderZIndex` token 映射。
//
// 真源：
// - `generated/swift/UiState.swift` L14-36 Overlay（21 case）
// - `frontend-demo-optimized/styles/01-shell-layout.css` z-index token 层级
// - `frontend-demo-optimized/MOTION_CONTRACT.md` §4 overlay.keyboard/sheet/dialog enter/exit
//
// 设计：
// - 接收 `overlay: Overlay?` + overlay 对应的 ViewStateComponent
// - 按 Overlay 类型选择 SwiftUI 容器（sheet / fullScreenCover / overlay / ZStack layer）
// - z-index：ReaderZIndex.bottomSheet(30) / ReaderZIndex.dialog(60) / ReaderZIndex.keyboard(70)
// - overlay 状态由 `AppNavigationState.overlayState` 驱动

/// 通用 Overlay 宿主容器。按 Overlay 类型选择 SwiftUI 容器。
public struct OverlayHost<Content: View>: View {
    public let overlay: ReaderUIContract.Overlay?
    public let overlayComponent: ViewStateComponent?
    @ViewBuilder public let content: Content

    public init(
        overlay: ReaderUIContract.Overlay?,
        overlayComponent: ViewStateComponent?,
        @ViewBuilder content: () -> Content
    ) {
        self.overlay = overlay
        self.overlayComponent = overlayComponent
        self.content = content()
    }

    public var body: some View {
        content
            .overlay(alignment: .center) {
                if let overlay, let component = overlayComponent {
                    overlayView(for: overlay, component: component)
                }
            }
    }

    @ViewBuilder
    private func overlayView(for overlay: ReaderUIContract.Overlay, component: ViewStateComponent) -> some View {
        switch overlay {
        case .keyboard:
            // keyboard overlay：z-index = keyboard(70)
            ComponentView(component)
                .zIndex(ReaderZIndex.keyboard.rawValue)
        case .sheet:
            // sheet overlay：z-index = bottomSheet(30)
            ComponentView(component)
                .zIndex(ReaderZIndex.bottomSheet.rawValue)
        case .dialog:
            // dialog overlay：z-index = dialog(60)
            ComponentView(component)
                .zIndex(ReaderZIndex.dialog.rawValue)
        case .toast:
            // toast：顶部弹出，z-index = dialog(60)
            ComponentView(component)
                .zIndex(ReaderZIndex.dialog.rawValue)
        case .readerControl, .directory, .tts, .appearance, .autoPage,
             .contentSearch, .contentReplacement, .sourceSwitch,
             .bookAction, .sortFilter, .groupManagement, .localImport,
             .batchManagement, .readerNightState, .readerDebugInfo, .readerBookCache,
             .settings:
            // reader / settings 相关 overlay：作为 ZStack layer 叠加
            ComponentView(component)
                .zIndex(ReaderZIndex.overlay.rawValue)
        }
    }
}

// MARK: - Overlay z-index 查询

extension ReaderUIContract.Overlay {
    /// Overlay 对应的 z-index token 值。
    public var zIndexValue: Double {
        switch self {
        case .keyboard:
            return ReaderZIndex.keyboard.rawValue
        case .dialog, .toast:
            return ReaderZIndex.dialog.rawValue
        case .sheet:
            return ReaderZIndex.bottomSheet.rawValue
        default:
            return ReaderZIndex.overlay.rawValue
        }
    }

    /// Overlay 是否是 reader 控制层类型（需要保持 reader context 不 remount）。
    /// P0-06 验收：控制层 open/hide 不 remount reader context、不改 text layout。
    public var isReaderControlLayer: Bool {
        switch self {
        case .readerControl, .directory, .tts, .appearance, .autoPage,
             .contentSearch, .contentReplacement, .sourceSwitch,
             .readerNightState, .readerDebugInfo, .readerBookCache:
            return true
        default:
            return false
        }
    }
}
