import Foundation
import SwiftUI
import ReaderUIContract

/// ReaderViewState — 从 `UiState` 派生可渲染的 `ViewState`。
///
/// 职责（CONTRACT_FIRST_NATIVE_UI_PLAN.md §6）：
/// - 把 `AppNavigationState`（本地真源）映射为 contract `ViewState` 字段
/// - 让 SwiftUI 视图层只消费 `ViewState`，不直接读 reducer 内部状态
///
/// 设计：
/// - 本文件是**派生层**，不持有新状态。所有字段从 `AppNavigationState` 计算。
/// - Slice 1 仅暴露 `mainTab` 与 `routeId`，后续 slice 逐步补 `overlay / activeSession / ...`。
public struct ReaderViewState: Equatable {
    /// 当前主 Tab（contract `MainTab`）
    public let mainTab: MainTab
    /// 当前 route id（contract `RouteId`）
    public let routeId: RouteId
    /// 当前 page state（contract `PageState`）—— Slice 1 恒为 `.default`
    public let pageState: PageState

    public init(mainTab: MainTab, routeId: RouteId, pageState: PageState = .defaultValue) {
        self.mainTab = mainTab
        self.routeId = routeId
        self.pageState = pageState
    }
}

extension ReaderViewState {
    /// 从 `AppNavigationState` 派生当前 `ReaderViewState`。
    ///
    /// `AppNavigationState` 是 `@MainActor`，本 init 也标记为 `@MainActor`
    /// 以避免 nonisolated 上下文访问 main actor 隔离属性。
    @MainActor
    public init(from navigationState: AppNavigationState) {
        let tab = MainTab(appTab: navigationState.activeTab)
        let route = RouteId(appTab: navigationState.activeTab)
        self.init(mainTab: tab, routeId: route)
    }
}

// MARK: - AppTab -> MainTab / RouteId 桥接

extension MainTab {
    /// 从本地 `AppTab` 桥接到 contract `MainTab`。
    public init(appTab: AppTab) {
        switch appTab {
        case .bookshelf: self = .bookshelf
        case .discover:  self = .discover
        case .rss:       self = .rss
        case .settings:  self = .settings
        }
    }
}

extension RouteId {
    /// 从本地 `AppTab` 桥接到 contract `RouteId`（主 Tab 首页）。
    ///
    /// Slice 1：4 个主 Tab 首页 route id 与 `MainTab` rawValue 一致。
    public init(appTab: AppTab) {
        switch appTab {
        case .bookshelf: self = .bookshelf
        case .discover:  self = .discover
        case .rss:       self = .rss
        case .settings:  self = .settings
        }
    }
}
