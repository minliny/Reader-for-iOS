import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// App Shell 一级底部主 Tab。
///
/// 真源：Reader UI `docs/cross-platform-ui/CROSS_PLATFORM_UI_BASELINE.md` App Shell
/// 契约：固定 4 项 —— 书架 / 发现 / RSS / 设置。
///
/// 约束（来自 `FRONTEND_DEVELOPMENT_SLICE_MATRIX.md` Slice 1）：
/// - 搜索、阅读页、书源管理都不是主 Tab。
/// - 主 Tab 切换不写成二级 route push。
/// - 顺序与点击热区稳定，对齐 `tab.item.press/select/switch` 与 `app.tab.switch`。
public enum AppTab: String, CaseIterable, Hashable, Identifiable {
    case bookshelf
    case discover
    case rss
    case settings

    public var id: String { rawValue }

    /// 契约要求的顺序：书架 / 发现 / RSS / 设置。
    public static var contractOrder: [AppTab] {
        [.bookshelf, .discover, .rss, .settings]
    }

    public var title: String {
        switch self {
        case .bookshelf: return "书架"
        case .discover: return "发现"
        case .rss: return "RSS"
        case .settings: return "设置"
        }
    }

    public var systemImageName: String {
        switch self {
        case .bookshelf: return "books.vertical"
        case .discover: return "safari"
        case .rss: return "antenna.radiowaves.left.and.right"
        case .settings: return "gearshape"
        }
    }

    /// Demo 图标素材库 token，对齐 `frontend-demo-optimized/asset-library/icons.js`。
    public var assetIcon: ReaderAssetIcon {
        switch self {
        case .bookshelf: return .bookshelf
        case .discover: return .discover
        case .rss: return .rss
        case .settings: return .settings
        }
    }
}

#if canImport(SwiftUI)
extension AppTab {
    /// `Label` for `tabItem`，几何稳定（不随 active 态改变尺寸/文案）。
    public var tabLabel: some View {
        Label {
            Text(title)
        } icon: {
            ReaderIcon(assetIcon, size: 20)
        }
    }
}
#endif
