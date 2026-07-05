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
/// - Slice 1 暴露 AppShell 可验证字段；深层 screen DTO 由后续 slice 逐步补齐。
public struct ReaderViewState: Equatable {
    /// 当前主 Tab（contract `MainTab`）
    public let mainTab: MainTab
    /// 当前 route id（contract `RouteId`）
    public let routeId: RouteId
    /// 当前 page state（contract `PageState`）—— Slice 1 恒为 `.default`
    public let pageState: PageState
    /// 当前 overlay（contract `Overlay`）
    public let overlay: Overlay?
    /// 当前 active session（contract `ActiveSession`）
    public let activeSession: ActiveSession?
    /// 当前可恢复焦点目标（contract `UiState.focusTarget`）
    public let focusTarget: String?
    /// 当前 reduced-motion 状态（contract `UiState.reducedMotion`）
    public let reducedMotion: Bool

    public init(
        mainTab: MainTab,
        routeId: RouteId,
        pageState: PageState = .defaultValue,
        overlay: Overlay? = nil,
        activeSession: ActiveSession? = nil,
        focusTarget: String? = nil,
        reducedMotion: Bool = false
    ) {
        self.mainTab = mainTab
        self.routeId = routeId
        self.pageState = pageState
        self.overlay = overlay
        self.activeSession = activeSession
        self.focusTarget = focusTarget
        self.reducedMotion = reducedMotion
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
        let route = ReaderUIContract.RouteId(
            appRoute: navigationState.navigationPath.last,
            fallbackTab: navigationState.activeTab,
            readerContext: navigationState.readerContext
        )
        self.init(
            mainTab: tab,
            routeId: route,
            overlay: ReaderUIContract.Overlay(overlayState: navigationState.overlayState),
            activeSession: ReaderUIContract.ActiveSession(readerSession: navigationState.activeSession),
            focusTarget: navigationState.focusTarget,
            reducedMotion: navigationState.motion.isReducedMotionEnabled
        )
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

    /// 从本地 pushed route 派生 contract route id；无二级 route 时回落到主 Tab。
    public init(appRoute route: Route?, fallbackTab: AppTab, readerContext: ReaderContext?) {
        if readerContext != nil {
            self = .immersiveReading
            return
        }

        guard let route else {
            self.init(appTab: fallbackTab)
            return
        }

        switch route {
        case .home:
            self.init(appTab: fallbackTab)
        case .bookshelf:
            self = .bookshelf
        case .bookshelfGroups:
            self = .bookshelfGroupManagement
        case .bookshelfImport:
            self = .localImport
        case .bookBatchManagement:
            self = .bookBatchManagement
        case .discover:
            self = .discover
        case .search:
            self = .searchHome
        case .searchResults:
            self = .searchResults
        case .bookDetail:
            self = .bookDetail
        case .bookDetailToc:
            self = .bookDetailTocPreview
        case .sourceSwitch:
            self = .sourceSwitch
        case .reader:
            self = .reader
        case .content:
            self = .readerContent
        case .bookSources:
            self = .sourceManagement
        case .bookSourceImport:
            self = .sourceImportOptions
        case .sourceDetail:
            self = .sourceDetail
        case .sourceAdd:
            self = .sourceAdd
        case .sourceEdit:
            self = .sourceEdit
        case .sourceTestResult:
            self = .sourceTestResult
        case .toc:
            self = .tocBookmarks
        case .rssList:
            self = .rss
        case .rssSearch:
            self = .rssSearch
        case .rssDetail:
            self = .rssDetail
        case .rssOriginal:
            self = .rssOriginal
        case .rssOriginalBrowser:
            self = .rssOriginalBrowser
        case .rssSubscriptions:
            self = .rssSubscriptionManagement
        case .rssSourceActions:
            self = .rssSourceActions
        case .rssSourceEdit:
            self = .rssSourceEdit
        case .rssSourceDebug:
            self = .rssSourceDebug
        case .rssSourceVars:
            self = .rssSourceVars
        case .rssSourceLogin:
            self = .rssSourceLogin
        case .rssSourceLoginWeb:
            self = .rssSourceLoginWeb
        case .rssSourceLoginCookie:
            self = .rssSourceLoginCookie
        case .rssSourceLoginClear:
            self = .rssSourceLoginClear
        case .rssSourceGroups:
            self = .rssSourceGroups
        case .rssSourceGroupEdit:
            self = .rssSourceGroupEdit
        case .rssSourceBatch:
            self = .rssSourceBatch
        case .rssSourceExport:
            self = .rssSourceExport
        case .rssSourceExportDetail:
            self = .rssSourceExportDetail
        case .rssSourceExportResult:
            self = .rssSourceExportResult
        case .rssSourcePin:
            self = .rssSourcePin
        case .rssSourceDisable:
            self = .rssSourceDisable
        case .rssSourceBatchDisable:
            self = .rssSourceBatchDisable
        case .rssSourceImport:
            self = .rssSourceImport
        case .rssSourceImportDetail:
            self = .rssSourceImportDetail
        case .rssSourceImportResult:
            self = .rssSourceImportResult
        case .rssReadRecord:
            self = .rssReadRecord
        case .rssRecordClear:
            self = .rssRecordClear
        case .rssRuleSubscription:
            self = .rssRuleSubscription
        case .rssRuleSubscriptionDetail:
            self = .rssRuleSubscriptionDetail
        case .rssRuleSubscriptionEdit:
            self = .rssRuleSubscriptionEdit
        case .rssRuleSubscriptionTest:
            self = .rssRuleSubscriptionTest
        case .rssRuleSubscriptionApply:
            self = .rssRuleSubscriptionApply
        case .rssFavoriteGroups:
            self = .rssFavoriteGroups
        case .rssFavoriteGroupEdit:
            self = .rssFavoriteGroupEdit
        case .rssFavoriteClear:
            self = .rssFavoriteClear
        case .rssEmpty:
            self = .rssEmpty
        case .rssError:
            self = .rssError
        case .webdavSettings:
            self = .webdavConfig
        case .webdavBooks:
            self = .remoteWebdavBooks
        case .backupSettings:
            self = .backupSettings
        case .syncProgress:
            self = .progressSync
        case .settings:
            self = .settings
        case .settingsReading:
            self = .readingSettingsEntry
        case .settingsAbout:
            self = .about
        case .stateError:
            self = .stateError
        case .stateOffline:
            self = .stateOffline
        case .statePermission:
            self = .permissionRequired
        case .prototypeGallery:
            self = .appShell
        }
    }
}

extension ReaderUIContract.Overlay {
    public init?(overlayState: OverlayState) {
        switch overlayState {
        case .none:
            return nil
        case .keyboard:
            self = .keyboard
        case .sheet:
            self = .sheet
        case .dialog:
            self = .dialog
        }
    }
}

extension ReaderUIContract.ActiveSession {
    public init?(readerSession: ReaderSession) {
        switch readerSession {
        case .none:
            return nil
        case .tts:
            self = .tts
        case .autoPage:
            self = .autoPage
        }
    }
}
