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
    /// 当前 RouteId 的组件列表（contract `ViewState.components`）
    /// Slice 2 初期硬编码 bookshelf / immersiveReading 的标准组件组合。
    public let components: [ViewStateComponent]

    public init(
        mainTab: MainTab,
        routeId: RouteId,
        pageState: PageState = .defaultValue,
        overlay: Overlay? = nil,
        activeSession: ActiveSession? = nil,
        focusTarget: String? = nil,
        reducedMotion: Bool = false,
        components: [ViewStateComponent] = []
    ) {
        self.mainTab = mainTab
        self.routeId = routeId
        self.pageState = pageState
        self.overlay = overlay
        self.activeSession = activeSession
        self.focusTarget = focusTarget
        self.reducedMotion = reducedMotion
        self.components = components
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
            pageState: ReaderViewState.derivedPageState(from: navigationState),
            overlay: ReaderUIContract.Overlay(overlayState: navigationState.overlayState),
            activeSession: ReaderUIContract.ActiveSession(readerSession: navigationState.activeSession),
            focusTarget: navigationState.focusTarget,
            reducedMotion: navigationState.motion.isReducedMotionEnabled,
            components: ViewStateComponentFactory.components(for: route)
        )
    }

    /// 从 `AppNavigationState` 派生 contract `PageState`。
    ///
    /// 对齐 state-rule.fixtures.json：
    /// - `book-detail-error-requires-error-pagestate`：error 态必须反映到 pageState
    /// - `error-requires-error-pagestate`：全局 error 非空时 pageState 必须为 error
    ///
    /// 当前 AppNavigationState 没有 per-route loading/error 字段，pageState 由 route 派生：
    /// - `.stateError` → `.error`
    /// - `.stateOffline` → `.offline`
    /// - `.statePermission` → `.permission`
    /// - 其他 → `.default`
    @MainActor
    private static func derivedPageState(from navigationState: AppNavigationState) -> PageState {
        guard let route = navigationState.navigationPath.last else {
            return .defaultValue
        }
        switch route {
        case .stateError:
            return .error
        case .stateOffline:
            return .offline
        case .statePermission:
            return .permission
        default:
            return .defaultValue
        }
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

// MARK: - ViewStateFactory

/// 构造 contract `ReaderUIContract.ViewState`。
///
/// `ViewState` 是 generated 类型（`ReaderUIContract.ViewState`），其 memberwise init
/// 是 internal，跨模块无法直接构造。本 helper 用 `JSONEncoder`/`JSONDecoder` 走
/// Codable 路径构造，避免手改 generated 代码。
///
/// P1 修复：`ContractHostView` 走 `ShellContainer` 需要 `ViewState` 实例；
/// route 参数通过 `context` 字段注入，供带参工厂方法读取。
enum ViewStateFactory {
    /// 构造带 route context 的 ViewState。
    static func make(
        routeId: RouteId,
        pageState: PageState = .defaultValue,
        context: [String: AnyCodable]? = nil,
        components: [ViewStateComponent]? = nil
    ) -> ReaderUIContract.ViewState {
        let resolvedComponents = components ?? ViewStateComponentFactory.components(
            for: routeId, context: context
        )
        return makeViewState(
            routeId: routeId.rawValue,
            pageState: pageState,
            context: context,
            components: resolvedComponents
        )
    }

    /// 用 JSONDecoder 构造 ViewState（绕过 internal memberwise init 限制）。
    private static func makeViewState(
        routeId: String,
        pageState: PageState,
        context: [String: AnyCodable]?,
        components: [ViewStateComponent]
    ) -> ReaderUIContract.ViewState {
        var dict: [String: Any] = [
            "routeId": routeId,
            "pageState": pageState.rawValue,
        ]
        // components → JSON → Any
        if let componentsData = try? JSONEncoder().encode(components),
           let componentsJSON = try? JSONSerialization.jsonObject(with: componentsData) {
            dict["components"] = componentsJSON
        } else {
            dict["components"] = [] as [Any]
        }
        // context → JSON → Any
        if let context = context,
           let contextData = try? JSONEncoder().encode(context),
           let contextJSON = try? JSONSerialization.jsonObject(with: contextData) as? [String: Any] {
            dict["context"] = contextJSON
        }
        // dict → JSON → ViewState
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let viewState = try? JSONDecoder().decode(ReaderUIContract.ViewState.self, from: data) else {
            // fallback：空 ViewState（不应发生，components/context 都是 Codable）
            return makeFallbackViewState(routeId: routeId, pageState: pageState)
        }
        return viewState
    }

    private static func makeFallbackViewState(routeId: String, pageState: PageState) -> ReaderUIContract.ViewState {
        let dict: [String: Any] = [
            "routeId": routeId,
            "pageState": pageState.rawValue,
            "components": [] as [Any],
        ]
        let data = try! JSONSerialization.data(withJSONObject: dict)
        return try! JSONDecoder().decode(ReaderUIContract.ViewState.self, from: data)
    }
}

// MARK: - ViewStateComponentFactory

/// Slice 2 组件组合工厂——按 RouteId 返回标准组件列表。
///
/// 初期硬编码 bookshelf / immersiveReading 的组件组合（从 `view-state.fixtures.json` 提取）。
/// 使用 JSONDecoder 解码，因为 `ViewStateComponent` 的 memberwise init 是 internal，
/// 跨模块无法直接构造。后续 slice 可重构为从 Bundle 加载 fixture JSON。
enum ViewStateComponentFactory {
    /// 无 route context 的工厂方法（用于无参数路由或 fallback）。
    static func components(for routeId: RouteId) -> [ViewStateComponent] {
        switch routeId {
        case .bookshelf:
            return bookshelfComponents()
        case .immersiveReading, .reader, .readerContent:
            return immersiveReadingComponents()
        case .controlLayerBaseV2:
            return controlLayerBaseComponents()
        case .readerDirectoryOverlayV2:
            return readerOverlayComponents(panelType: "ReaderDirectoryPanel")
        case .readerAppearanceOverlayV2:
            return readerOverlayComponents(panelType: "ReaderAppearancePanel")
        case .readerTtsOverlayV2:
            return readerOverlayComponents(panelType: "ReaderTtsPanel")
        case .readerSettingsOverlayV2:
            return readerOverlayComponents(panelType: "ReaderSettingsPanel")
        case .readerSearchOverlayV2:
            return readerOverlayComponents(panelType: "ReaderSearchPanel")
        case .readerReplaceOverlayV2:
            return readerOverlayComponents(panelType: "ReaderReplacePanel")
        case .readerAutoScrollOverlayV2:
            return readerOverlayComponents(panelType: "ReaderAutoScrollPanel")
        case .readerNightStateV2:
            return readerNightStateComponents()
        // MARK: - Slice 4: reader-full-* / progress-sync 系列
        case .readerFullDirectory:
            return readerFullPageComponents(pageType: "ReaderFullDirectoryPage")
        case .readerFullTts:
            return readerFullPageComponents(pageType: "ReaderFullTtsPage")
        case .readerFullAppearance, .readerFullFont, .readerFullTheme,
             .readerFullThemeEdit, .readerFullLayout:
            return readerFullPageComponents(pageType: "ReaderFullAppearancePage")
        case .readerFullSettings, .readerFullPageTurn:
            return readerFullPageComponents(pageType: "ReaderFullSettingsPage")
        case .readerBookCache:
            return readerFullPageComponents(pageType: "ReaderBookCachePage")
        case .readerDebugInfo:
            return readerFullPageComponents(pageType: "ReaderDebugInfoPage")
        case .progressSync:
            return progressSyncComponents(pageType: "ProgressSyncPage")
        case .progressSyncStatus:
            return progressSyncComponents(pageType: "SyncProgressPage")
        // MARK: - Slice 5a: RSS 系列
        case .rss:
            return rssHomeComponents()
        case .rssAll:
            return rssSimplePageComponents(topbarTitle: "全部条目", pageType: "RssAllPage")
        case .rssDetail:
            return rssDetailComponents()
        case .rssOriginal:
            return rssSimplePageComponents(topbarTitle: "原文", pageType: "RssOriginalPage")
        case .rssSubscriptionManagement:
            return rssSubscriptionManagementComponents()
        case .rssEmpty:
            return rssEmptyStateComponents()
        case .rssError:
            return rssErrorStateComponents()
        case .rssRefreshing:
            return rssSimplePageComponents(topbarTitle: "刷新订阅", pageType: "RssRefreshingPage")
        case .rssSearch:
            return rssSearchComponents()
        case .rssStarred:
            return rssStarredComponents()
        case .rssOriginalBrowser:
            return rssSimplePageComponents(topbarTitle: "原文", pageType: "RssOriginalBrowserPage")
        case .rssFavoriteGroups:
            return rssSimplePageComponents(topbarTitle: "收藏分组", pageType: "RssFavoriteGroupsPage")
        case .rssSourceGroups:
            return rssSimplePageComponents(topbarTitle: "RSS 源分组", pageType: "RssSourceGroupsPage")
        case .rssSourceAdd:
            return rssSourceEditComponents(mode: "add", topbarTitle: "添加 RSS 源")
        case .rssSourceEdit:
            return rssSourceEditComponents(mode: "edit", topbarTitle: "编辑 RSS 源")
        case .rssSourceImport:
            return rssSourceImportComponents()
        // MARK: - Slice 5b: 书源系列
        case .sourceDetail:
            return sourceDetailComponents()
        case .sourceSwitch, .sourceSwitchResults:
            return sourceSwitchFlowComponents(context: nil)
        case .sourceManagement, .sourceSettingsEntry:
            return sourceManagementComponents()
        case .sourceAdd, .sourceImportOptions:
            return sourceImportOptionsComponents()
        case .sourceEdit, .sourceRuleEdit:
            return sourceRuleEditComponents(variant: nil)
        case .sourceEditDebug:
            return sourceRuleEditComponents(variant: "debug")
        case .sourceTestResult:
            return sourceTestResultComponents()
        case .sourceBatch:
            return sourceSimplePageComponents(topbarTitle: "已选 3 个", pageType: "SourceBatchPage")
        case .sourceCodeView:
            return sourceSimplePageComponents(topbarTitle: "源码查看", pageType: "SourceCodeViewPage")
        case .sourceDebug:
            return sourceSimplePageComponents(topbarTitle: "书源调测", pageType: "SourceDebugPage")
        case .sourceDebugCatalogResult:
            return sourceDebugResultComponents(variant: "catalog", topbarTitle: "目录调试结果")
        case .sourceDebugContentLog:
            return sourceSimplePageComponents(topbarTitle: "正文调试日志", pageType: "SourceDebugContentLogPage")
        case .sourceDebugDetailResult:
            return sourceDebugResultComponents(variant: "detail", topbarTitle: "详情调试结果")
        case .sourceDebugResult:
            return sourceDebugResultComponents(variant: "search", topbarTitle: "调试结果")
        case .sourceDebugRunning:
            return sourceSimplePageComponents(topbarTitle: "调试中", pageType: "SourceDebugRunningPage")
        case .sourceDebugSearchResult:
            return sourceDebugResultComponents(variant: "search", topbarTitle: "搜索调试结果")
        case .sourceDeleteConfirm:
            return sourceSimplePageComponents(topbarTitle: "删除书源", pageType: "SourceDeleteConfirmPage")
        case .sourceDetect:
            return sourceSimplePageComponents(topbarTitle: "书源检测", pageType: "SourceDetectPage")
        case .sourceGroups:
            return sourceSimplePageComponents(topbarTitle: "分组管理", pageType: "SourceGroupsPage")
        case .sourceImportPreview:
            return sourceSimplePageComponents(topbarTitle: "导入书源", pageType: "SourceImportPreviewPage")
        case .sourceLogs:
            return sourceSimplePageComponents(topbarTitle: "错误日志", pageType: "SourceLogsPage")
        // MARK: - Slice 5c: 搜索/书籍详情/书架管理扩展
        case .bookSearch:
            return bookSearchComponents()
        case .searchHome:
            return searchHomeComponents()
        case .searchResults:
            return searchResultsComponents()
        case .searchEmpty:
            return searchStateComponents(variant: "empty", topbarTitle: "搜索", title: "没有找到结果", message: "换个关键词或检查书源状态。", action: nil)
        case .searchLoading:
            return searchStateComponents(variant: "loading", topbarTitle: "搜索", title: "正在搜索", message: "正在从启用书源获取结果。", action: nil)
        case .searchError:
            return searchStateComponents(variant: "error", topbarTitle: "搜索", title: "搜索失败", message: "网络源暂时不可用。", action: "重试")
        // B1-iOS P0：book-detail 走 contract renderer，返回标准组件树。
        case .bookDetail:
            return bookDetailComponents(context: nil)
        case .bookDetailTocPreview:
            return bookTocPreviewComponents()
        case .bookDirectory:
            return sourceSimplePageComponents(topbarTitle: "书籍目录", pageType: "BookDirectoryPage")
        case .groupManagement:
            return groupManagementComponents()
        case .bookBatchManagement:
            return sourceSimplePageComponents(topbarTitle: "批量管理", pageType: "BookBatchManagementPage")
        case .bookshelfGroupManagement:
            return bookshelfGroupManagementComponents()
        // MARK: - Slice 5d: 发现系列
        case .discover:
            return discoverHomeComponents()
        case .discoverEmpty:
            return discoverStateComponents(variant: "empty", title: "当前没有启用发现的书源", message: "启用发现后，可以在这里浏览书源提供的排行榜、分类和书单。", action: "去书源管理")
        case .discoverError:
            return discoverStateComponents(variant: "error", title: "发现入口解析失败", message: "当前入口返回异常，已保留上一批缓存结果。你可以重试、刷新入口、编辑源或切换书源。", action: "重试")
        case .discoverLoading:
            return discoverStateComponents(variant: "loading", title: "加载中", message: "正在获取发现入口…", action: nil)
        case .discoverNoResults:
            return discoverStateComponents(variant: "no-results", title: "当前条件没有发现结果", message: "可以重置筛选、切换入口，或刷新当前书源。", action: "重置筛选")
        case .discoverRuleTest:
            return discoverSimplePageComponents(topbarTitle: "发现规则测试", pageType: "DiscoverRuleTestPage")
        case .discoverSourceBulk:
            return discoverSimplePageComponents(topbarTitle: "发现源管理", pageType: "DiscoverSourceBulkPage")
        case .discoverSourceLogin:
            return discoverSimplePageComponents(topbarTitle: "源登录", pageType: "DiscoverSourceLoginPage")
        // MARK: - Slice 6: 同步/冲突/离线/设置/about/app-shell
        case .syncBackup, .webdavConfig:
            return syncBackupComponents()
        case .syncError:
            return syncErrorComponents()
        case .syncSettingsEntry:
            return settingsSimplePageComponents(topbarTitle: "同步设置", pageType: "SyncSettingsEntryPage")
        case .restoreConflict:
            return settingsSimplePageComponents(topbarTitle: "冲突解决", pageType: "RestoreConflictPage")
        case .stateOffline:
            return offlineComponents()
        case .offlineState:
            return settingsSimplePageComponents(topbarTitle: "离线", pageType: "OfflineStatePage")
        case .settings:
            return settingsHomeComponents()
        case .globalSettings:
            return settingsSimplePageComponents(topbarTitle: "全局设置", pageType: "GlobalSettingsPage")
        case .settingsGeneral:
            return settingsSimplePageComponents(topbarTitle: "通用设置", pageType: "SettingsGeneralPage")
        case .readingSettingsEntry:
            return settingsSimplePageComponents(topbarTitle: "阅读设置", pageType: "ReadingSettingsEntryPage")
        case .backupSettings:
            return settingsSimplePageComponents(topbarTitle: "备份", pageType: "BackupSettingsPage")
        case .bookshelfSearchSettings:
            return settingsSimplePageComponents(topbarTitle: "书架搜索设置", pageType: "BookshelfSearchSettingsPage")
        case .appShell:
            return appShellComponents()
        case .about, .aboutFeedback:
            return settingsSimplePageComponents(topbarTitle: "关于", pageType: "AboutFeedbackPage")
        case .aboutVersion:
            return aboutVersionComponents()
        default:
            return []
        }
    }

    /// 带 route context 的工厂方法（用于注入真实 route 参数，如 bookURL/title/author）。
    ///
    /// P1 修复：book-detail / source-switch 等路由需要接收实际 route 参数，
    /// 不再硬编码 fixture（"长夜余火/爱潜水的乌贼"）。context 从 ViewState.context
    /// 传入，工厂方法读取 context 中的字段注入组件 props。
    static func components(
        for routeId: RouteId, context: [String: AnyCodable]?
    ) -> [ViewStateComponent] {
        switch routeId {
        case .bookDetail:
            return bookDetailComponents(context: context)
        case .sourceSwitch, .sourceSwitchResults:
            return sourceSwitchFlowComponents(context: context)
        default:
            return components(for: routeId)
        }
    }

    private static func bookshelfComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"AppTopBar","id":"bookshelf-topbar","props":{"title":"书架"}},
            {"type":"ContinueReadingCard","id":"continue-reading","props":{"bookId":"bk-001","title":"长夜余火","author":"爱潜水的乌贼","coverKey":"longNight"}},
            {"type":"BookshelfShelfSection","id":"bookshelf-shelf-section","props":{"title":"我的书架","viewMode":"cover"},"children":[
                {"type":"ShelfSectionHeader","id":"shelf-header","props":{"title":"我的书架","viewMode":"cover"}},
                {"type":"BookGrid","id":"book-grid","props":{"viewMode":"cover"},"children":[
                    {"type":"BookCard","id":"book-1","props":{"bookId":"bk-001","title":"长夜余火","author":"爱潜水的乌贼","coverKey":"longNight"}},
                    {"type":"BookCard","id":"book-2","props":{"bookId":"bk-002","title":"诡秘之主","author":"爱潜水的乌贼","coverKey":"mysteryLord"}},
                    {"type":"BookCard","id":"book-3","props":{"bookId":"bk-003","title":"明朝那些事儿","author":"当年明月","coverKey":"mingDynasty"}},
                    {"type":"BookCard","id":"book-4","props":{"bookId":"bk-004","title":"凡人修仙传","author":"忘语","coverKey":"mortalJourney"}},
                    {"type":"BookCard","id":"book-5","props":{"bookId":"bk-005","title":"斗破苍穹","author":"天蚕土豆","coverKey":"battleThrough"}},
                    {"type":"BookCard","id":"book-6","props":{"bookId":"bk-006","title":"遮天","author":"辰东","coverKey":"coverTheSky"}}
                ]}
            ]},
            {"type":"BottomNav","id":"bottom-nav","props":{"selected":"bookshelf"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    // B1-iOS P0 + P1：book-detail 标准组件树，注入真实 route 参数。
    // 真源：contracts/fixtures/view-state.fixtures.json 的 book-detail fixture +
    // frontend-demo-optimized book-detail 页面结构。
    // 组件由 registerBookDetailComponents() 注册的 renderer 渲染。
    //
    // P1 修复：之前硬编码"长夜余火/爱潜水的乌贼"，现在从 context 读取真实
    // title/author/bookURL。context 为 nil 时 fallback 到占位值（不崩溃）。
    // 用 [String: Any] dict + JSONSerialization 构造，避免用户输入的 JSON 注入风险。
    private static func bookDetailComponents(context: [String: AnyCodable]?) -> [ViewStateComponent] {
        let title = (context?["title"]?.value as? String) ?? "未知书名"
        let author = (context?["author"]?.value as? String) ?? "未知作者"
        let bookURL = (context?["bookURL"]?.value as? String) ?? ""

        let tree: [[String: Any]] = [
            [
                "type": "BackTopBar",
                "id": "book-detail-backbar",
                "props": ["title": "书籍详情"],
            ],
            [
                "type": "BookHero",
                "id": "book-detail-hero",
                "props": ["title": title, "author": author, "coverKey": "placeholder"],
                "children": [
                    ["type": "BookCover", "id": "book-detail-cover", "props": ["coverKey": "placeholder"] as [String: Any]],
                    ["type": "BookTitleAuthor", "id": "book-detail-title-author", "props": ["title": title, "author": author] as [String: Any]],
                    ["type": "SourceStatus", "id": "book-detail-source-status", "props": ["sourceName": "默认书源"] as [String: Any]],
                ] as [Any],
            ],
            [
                "type": "BookIntro",
                "id": "book-detail-intro",
                "props": ["intro": "简介加载中…"] as [String: Any],
            ],
            [
                "type": "DirectoryPreview",
                "id": "book-detail-directory",
                "props": ["chapterCount": 0] as [String: Any],
            ],
            [
                "type": "ReadButton",
                "id": "book-detail-read",
                "props": ["bookURL": bookURL] as [String: Any],
            ],
            [
                "type": "AddToShelfButton",
                "id": "book-detail-add",
                "props": ["bookURL": bookURL] as [String: Any],
            ],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: tree),
              let components = try? JSONDecoder().decode([ViewStateComponent].self, from: data) else {
            return []
        }
        return components
    }

    private static func immersiveReadingComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"ReaderBase","id":"reader-base","props":{"theme":"paper"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func controlLayerBaseComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"ReaderBase","id":"reader-base","props":{"theme":"paper"}},
            {"type":"ReaderTopArea","id":"reader-top-area","props":{}},
            {"type":"ReaderControlSheet","id":"reader-control-sheet","props":{}},
            {"type":"ReaderBottomBar","id":"reader-bottom-bar","props":{}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func readerOverlayComponents(panelType: String) -> [ViewStateComponent] {
        let json = """
        [
            {"type":"ReaderBase","id":"reader-base","props":{"theme":"paper"}},
            {"type":"ReaderTopArea","id":"reader-top-area","props":{}},
            {"type":"\(panelType)","id":"reader-panel","props":{}},
            {"type":"ReaderBottomBar","id":"reader-bottom-bar","props":{}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func readerNightStateComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"ReaderBase","id":"reader-base","props":{"theme":"night"}},
            {"type":"ReaderTopArea","id":"reader-top-area","props":{}},
            {"type":"ReaderBottomBar","id":"reader-bottom-bar","props":{}},
            {"type":"NightToast","id":"night-toast","props":{}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    // MARK: - Slice 4: reader-full-* 全屏页组件工厂

    /// reader-full-* 系列全屏页组件组合：ReaderBase + ReaderTopArea + Page。
    /// 真源：view-state.fixtures.json L2112-2270
    private static func readerFullPageComponents(pageType: String) -> [ViewStateComponent] {
        let json = """
        [
            {"type":"ReaderBase","id":"reader-base","props":{"theme":"paper"}},
            {"type":"ReaderTopArea","id":"reader-top-area","props":{}},
            {"type":"\(pageType)","id":"full-page","props":{}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    // MARK: - Slice 4: progress-sync 系列组件工厂

    /// progress-sync / progress-sync-status 组件组合：BackTopBar + Page。
    /// 真源：view-state.fixtures.json L1745-1776 / L2460-2477
    // MARK: - Slice 5a: RSS 工厂方法

    private static func rssHomeComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"AppTopBar","id":"rss-topbar","props":{"title":"RSS"}},
            {"type":"RssSearchEntry","id":"rss-search","props":{}},
            {"type":"RssModeRow","id":"rss-mode-row","props":{}},
            {"type":"RssSourceOverview","id":"rss-source-overview","props":{}},
            {"type":"RssArticleSection","id":"rss-article-section","props":{}},
            {"type":"BottomNav","id":"bottom-nav","props":{"selected":"rss"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func rssSimplePageComponents(topbarTitle: String, pageType: String) -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"rss-topbar","props":{"title":"\(topbarTitle)"}},
            {"type":"\(pageType)","id":"rss-page","props":{}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func rssDetailComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"rss-detail-topbar","props":{"title":"RSS 详情"}},
            {"type":"RssDetailPage","id":"rss-detail-page","props":{"title":"深空信号更新"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func rssSubscriptionManagementComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"topbar","props":{"title":"订阅管理"}},
            {"type":"RssSubscriptionManagementPage","id":"rss-subscription-management-page","props":{"title":"订阅源"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func rssEmptyStateComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"rss-empty-topbar","props":{"title":"RSS"}},
            {"type":"RssEmptyState","id":"rss-empty-page","props":{"title":"暂无订阅","message":"添加 RSS 订阅后查看更新。","action":"添加订阅"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func rssErrorStateComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"rss-error-topbar","props":{"title":"RSS"}},
            {"type":"RssErrorState","id":"rss-error-page","props":{"title":"订阅加载失败","message":"网络异常或订阅源不可访问。","action":"重试"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func rssSearchComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"AppTopBar","id":"rss-topbar","props":{"title":"RSS 搜索"}},
            {"type":"RssSearchEntry","id":"rss-search-entry","props":{}},
            {"type":"BottomNav","id":"bottom-nav","props":{"selected":"rss"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func rssStarredComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"AppTopBar","id":"rss-topbar","props":{"title":"RSS 收藏"}},
            {"type":"RssArticleSection","id":"starred-section","props":{}},
            {"type":"BottomNav","id":"bottom-nav","props":{"selected":"rss"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func rssSourceEditComponents(mode: String, topbarTitle: String) -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"topbar","props":{"title":"\(topbarTitle)"}},
            {"type":"RssSourceEditPage","id":"rss-source-edit-page","props":{"mode":"\(mode)"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    // MARK: - Slice 5b: 书源工厂方法

    private static func sourceDetailComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"source-detail-topbar","props":{"title":"书源详情"}},
            {"type":"SourceDetailPage","id":"source-detail-page","props":{"title":"笔趣阁"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    // P1 修复：source-switch 注入真实 bookURL + 加 BackTopBar（FlowShell filter 需要）。
    // 之前只有 SourceSwitchFlowPage（无 BackTopBar），FlowShellContainer 的 barTypes
    // filter 得到空，返回栏区域不渲染。现在加 BackTopBar 让 FlowShell 布局完整。
    private static func sourceSwitchFlowComponents(context: [String: AnyCodable]?) -> [ViewStateComponent] {
        let bookURL = (context?["bookURL"]?.value as? String) ?? ""
        let tree: [[String: Any]] = [
            [
                "type": "BackTopBar",
                "id": "source-switch-backbar",
                "props": ["title": "换源"] as [String: Any],
            ],
            [
                "type": "SourceSwitchFlowPage",
                "id": "source-switch-flow",
                "props": ["bookURL": bookURL] as [String: Any],
            ],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: tree),
              let components = try? JSONDecoder().decode([ViewStateComponent].self, from: data) else {
            return []
        }
        return components
    }

    private static func sourceManagementComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"source-management-topbar","props":{"title":"书源管理"}},
            {"type":"SourceManagementPage","id":"source-management-page","props":{"title":"书源管理"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func sourceImportOptionsComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"topbar","props":{"title":"书源管理"}},
            {"type":"SourceImportOptionsPage","id":"source-import-page","props":{"title":"导入书源"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func sourceRuleEditComponents(variant: String?) -> [ViewStateComponent] {
        let variantJson = variant.map { ",\"variant\":\"\($0)\"" } ?? ""
        let json = """
        [
            {"type":"BackTopBar","id":"topbar","props":{"title":"规则编辑"}},
            {"type":"SourceRuleEditPage","id":"source-rule-edit-page","props":{"title":"规则编辑"\(variantJson)}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func sourceTestResultComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"source-test-topbar","props":{"title":"书源测试结果"}},
            {"type":"SourceTestResultPage","id":"source-test-page","props":{"title":"测试结果"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func sourceSimplePageComponents(topbarTitle: String, pageType: String) -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"topbar","props":{"title":"\(topbarTitle)"}},
            {"type":"\(pageType)","id":"source-page","props":{}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    // MARK: - Slice 5c: 搜索/书架管理工厂方法

    private static func bookSearchComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"AppTopBar","id":"search-topbar","props":{"title":"搜索"}},
            {"type":"SearchInputBox","id":"search-input","props":{"query":""}},
            {"type":"ScopeSelector","id":"scope-selector","props":{}},
            {"type":"GroupSelector","id":"group-selector","props":{}},
            {"type":"SearchHistoryList","id":"search-history","props":{}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func searchHomeComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"search-topbar","props":{"title":"搜索"}},
            {"type":"SearchHomePage","id":"search-home-page","props":{"query":"","placeholder":"搜索书名/作者"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func searchResultsComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"search-results-topbar","props":{"title":"搜索结果"}},
            {"type":"SearchResultsPage","id":"search-results-page","props":{"query":"深空信号"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func searchStateComponents(variant: String, topbarTitle: String, title: String, message: String, action: String?) -> [ViewStateComponent] {
        let actionJson = action.map { ",\"action\":\"\($0)\"" } ?? ""
        let json = """
        [
            {"type":"BackTopBar","id":"search-state-topbar","props":{"title":"\(topbarTitle)"}},
            {"type":"SearchStatePage","id":"search-state-page","props":{"variant":"\(variant)","title":"\(title)","message":"\(message)"\(actionJson)}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func bookTocPreviewComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"book-toc-topbar","props":{"title":"目录预览"}},
            {"type":"BookTocPreviewPage","id":"book-toc-preview-page","props":{"title":"目录预览"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func groupManagementComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"topbar","props":{"title":"分组管理"}},
            {"type":"GroupManagementPage","id":"group-management-page","props":{"variant":"group-flow"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func bookshelfGroupManagementComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"topbar","props":{"title":"分组管理"}},
            {"type":"BookGroupManagementPage","id":"book-group-management-page","props":{"title":"分组"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    // MARK: - Slice 5d: 发现工厂方法

    private static func discoverHomeComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"AppTopBar","id":"discover-topbar","props":{"title":"发现"}},
            {"type":"DiscoverSourceBar","id":"discover-source-bar","props":{}},
            {"type":"DiscoverEntryRow","id":"discover-entry-row","props":{}},
            {"type":"DiscoverFilterTrigger","id":"discover-filter","props":{}},
            {"type":"DiscoverListHead","id":"discover-list-head","props":{}},
            {"type":"DiscoverBookList","id":"discover-book-list","props":{}},
            {"type":"BottomNav","id":"bottom-nav","props":{"selected":"discover"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func discoverStateComponents(variant: String, title: String, message: String, action: String?) -> [ViewStateComponent] {
        let actionJson = action.map { ",\"action\":\"\($0)\"" } ?? ""
        let json = """
        [
            {"type":"AppTopBar","id":"discover-topbar","props":{"title":"发现"}},
            {"type":"DiscoverStatePage","id":"discover-state-page","props":{"variant":"\(variant)","title":"\(title)","message":"\(message)"\(actionJson)}},
            {"type":"BottomNav","id":"bottom-nav","props":{"selected":"discover"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    // MARK: - Slice 6: 同步/设置/about 工厂方法

    private static func syncBackupComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"sync-backup-topbar","props":{"title":"备份同步"}},
            {"type":"SyncBackupPage","id":"sync-backup-page","props":{"variant":"webdav","status":"idle"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func syncErrorComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"sync-error-topbar","props":{"title":"同步错误"}},
            {"type":"SyncErrorPage","id":"sync-error-page","props":{"title":"同步失败","message":"WebDAV 连接超时。"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func offlineComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"Offline","id":"offline","props":{}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func settingsHomeComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"AppTopBar","id":"settings-topbar","props":{"title":"设置"}},
            {"type":"SettingsHomePage","id":"settings-home-page","props":{"title":"设置"}},
            {"type":"BottomNav","id":"bottom-nav","props":{"selected":"settings"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func settingsSimplePageComponents(topbarTitle: String, pageType: String) -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"topbar","props":{"title":"\(topbarTitle)"}},
            {"type":"\(pageType)","id":"settings-page","props":{"title":"\(topbarTitle)"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func appShellComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"AppTopBar","id":"app-topbar","props":{"title":"应用壳"}},
            {"type":"AppShellStructure","id":"app-shell-structure","props":{"title":"应用壳"}},
            {"type":"BottomNav","id":"bottom-nav","props":{"selected":"bookshelf"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func aboutVersionComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"topbar","props":{"title":"版本信息"}},
            {"type":"AboutVersionPage","id":"about-version-page","props":{"title":"Reader","version":"1.0.0"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func discoverSimplePageComponents(topbarTitle: String, pageType: String) -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"topbar","props":{"title":"\(topbarTitle)"}},
            {"type":"\(pageType)","id":"discover-page","props":{}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func sourceDebugResultComponents(variant: String, topbarTitle: String) -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"topbar","props":{"title":"\(topbarTitle)"}},
            {"type":"SourceDebugResultPage","id":"source-debug-result-page","props":{"variant":"\(variant)"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func rssSourceImportComponents() -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"topbar","props":{"title":"导入 RSS 源"}},
            {"type":"RssSourceImportPage","id":"rss-source-import-page","props":{"message":"从 OPML 或 URL 导入。"}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }

    private static func progressSyncComponents(pageType: String) -> [ViewStateComponent] {
        let json = """
        [
            {"type":"BackTopBar","id":"topbar","props":{"title":"同步进度"}},
            {"type":"\(pageType)","id":"progress-page","props":{}}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([ViewStateComponent].self, from: json)) ?? []
    }
}
