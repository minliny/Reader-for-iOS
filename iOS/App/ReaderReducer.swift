import Foundation
import SwiftUI
import ReaderUIContract

/// ReaderReducer — Contract-first Native UI Architecture 的 Swift reducer 入口。
///
/// 职责（CONTRACT_FIRST_NATIVE_UI_PLAN.md §6）：
/// - 消费 `UiEvent` → 更新 `UiState` → emit `CoreCommand / HostCommand`
/// - 统一管理 navigation / readerMode / overlay / activeSession / focusTarget /
///   loading / error / async guard / reducedMotion
///
/// 设计：
/// - 本 reducer 是 contract 入口 facade，**不重写**既有 `AppNavigationState` 的状态机，
///   而是包装它，让 contract `UiEvent` 与既有 `switchTab / enterImmersiveReading` 等方法对接。
/// - Slice 1 仅落地 `mainTab.select` 事件路由。
/// - 后续 slice 逐步接入 `route.push / route.pop / reader.control.toggle / ...`。
///
/// 禁止（BOUNDARY_RULES.md）：
/// - 解析书籍、计算业务进度
/// - 直接写数据库
/// - 持有平台 View 引用
@MainActor
public final class ReaderReducer: ObservableObject {
    /// 既有状态机作为唯一真源。reducer 不复制状态，只转发事件。
    @ObservedObject public var navigationState: AppNavigationState

    public init(navigationState: AppNavigationState) {
        self.navigationState = navigationState
    }

    // MARK: - UiEvent 入口

    /// 派发 contract `UiEvent`。
    ///
    /// Slice 1 仅处理 `mainTab.select`。其他事件留待后续 slice。
    public func dispatch(_ event: UiEvent) {
        switch event.type {
        case .mainTab_select:
            handleMainTabSelect(event)
        default:
            // Slice 1 不处理其他事件。后续 slice 逐步接入。
            break
        }
    }

    // MARK: - mainTab.select

    private func handleMainTabSelect(_ event: UiEvent) {
        guard let tabRaw = event.payload["tab"]?.value as? String,
              let tab = MainTab(rawValue: tabRaw) else {
            return
        }
        let appTab = AppTab(contract: tab)
        navigationState.switchTab(appTab)
    }
}

// MARK: - MainTab -> AppTab 桥接

extension AppTab {
    /// 从 contract `MainTab` 桥接到本地 `AppTab`。
    ///
    /// Contract `MainTab` 与本地 `AppTab` 顺序与命名一致：
    /// bookshelf / discover / rss / settings。
    public init(contract tab: MainTab) {
        switch tab {
        case .bookshelf: self = .bookshelf
        case .discover:  self = .discover
        case .rss:       self = .rss
        case .settings:  self = .settings
        }
    }
}
