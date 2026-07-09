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
    /// Slice 1 处理 AppShell 级事件；深层业务事件留待后续 slice。
    public func dispatch(_ event: UiEvent) {
        switch event.type {
        case .route_push:
            handleRoutePush(event)
        case .route_replace:
            handleRouteReplace(event)
        case .route_pop:
            navigationState.goBack()
        case .route_popToRoot:
            navigationState.popToRoot()
        case .mainTab_select:
            handleMainTabSelect(event)
        case .overlay_dialog_open:
            navigationState.setOverlay(.dialog)
        case .overlay_sheet_open:
            navigationState.setOverlay(.sheet)
        case .overlay_keyboard_open:
            navigationState.setOverlay(.keyboard)
        case .overlay_dialog_close,
             .overlay_sheet_close,
             .overlay_keyboard_close:
            navigationState.setOverlay(.none)
        case .reader_session_ttsStart,
             .tts_queue_start,
             .reader_tts_start:
            navigationState.startSession(.tts(playing: true))
        case .reader_session_autoPageStart,
             .reader_autoPage_start:
            navigationState.startSession(.autoPage(playing: true))
        case .reader_session_capsuleExit,
             .tts_queue_stop,
             .reader_tts_stop,
             .reader_autoPage_stop:
            navigationState.clearSession()
        case .input_focus:
            handleInputFocus(event)
        case .input_blur:
            navigationState.blurFocus()
        case .reducedMotion_enable:
            navigationState.setReducedMotion(true)
        case .reducedMotion_disable:
            navigationState.setReducedMotion(false)
        // MARK: - Slice 2: book_open / book_detail_open / reader_enter / reader_entry_* / book_directory_open
        case .book_open, .book_detail_open:
            handleBookOpen(event)
        case .reader_enter:
            handleReaderEntry(event, source: .actionToImmersive)
        case .reader_entry_coverToImmersive:
            handleReaderEntry(event, source: .coverToImmersive)
        case .reader_entry_actionToImmersive:
            handleReaderEntry(event, source: .actionToImmersive)
        case .book_directory_open:
            handleBookDirectoryOpen(event)
        // MARK: - Slice 3: reader control layer events
        case .reader_control_toggle:
            handleReaderControlToggle(event)
        case .reader_module_switch:
            handleReaderModuleSwitch(event)
        case .reader_directory_open:
            navigationState.setOverlay(.sheet)
        case .reader_appearance_open,
             .reader_contentSearch_open,
             .reader_contentReplacement_open,
             .reader_sourceSwitch_open,
             .reader_settings_open:
            navigationState.setOverlay(.sheet)
        case .reader_directory_close,
             .reader_contentSearch_close,
             .reader_contentReplacement_close,
             .reader_sourceSwitch_close,
             .reader_settings_close:
            navigationState.setOverlay(.none)
        case .reader_exit:
            navigationState.exitImmersiveReading()
        case .reader_nightState_toggle:
            // Slice 3 stub: 夜间模式切换，后续 slice 落地 theme 管理
            break
        case .reader_page_next, .reader_page_prev, .reader_chapter_jump:
            // Slice 3 stub: 翻页/章节跳转，不影响 navigation state
            break
        case .reader_bookCache_open:
            navigationState.push(.content(chapterTitle: "Slice3"))
        case .reader_debugInfo_open:
            navigationState.push(.content(chapterTitle: "Slice3"))
        case .reader_textSelection_change, .reader_textSelection_clear:
            // Slice 3 stub: 文本选择，不影响 navigation state
            break
        case .reader_control_handlePress, .reader_control_handleRelease,
             .reader_control_handleDrag, .reader_control_dockDrag,
             .reader_control_dockLongPress, .reader_control_dockRelease,
             .reader_control_dockRebound:
            // Slice 3 stub: 控制层手势事件，不影响 navigation state
            break
        // MARK: - Slice 4: TTS toggle / session capsule / sync 事件
        case .reader_tts_toggle:
            handleReaderTtsToggle(event)
        case .reader_session_capsuleEnter, .reader_session_capsuleSwitch,
             .reader_session_capsuleControlPressToggle, .reader_session_capsuleCountdownTick,
             .reader_session_capsuleVoiceIconActive,
             .reader_session_controlSpaceEnter, .reader_session_controlSpaceUpdate,
             .reader_session_controlSpaceExit:
            // Slice 4 stub: 会话胶囊/控制空间事件，不影响 navigation state
            break
        case .sync_run, .sync_resolveConflict, .sync_conflict_list,
             .sync_conflict_dismiss, .sync_snapshot_view:
            // Slice 4 stub: 同步事件，后续 slice 接 CoreBridge 真实处理
            break
        // MARK: - Slice 5a: RSS 业务事件 stub
        // RSS 路由切换通过 route_push + routeId payload 触发（由 handleRoutePush/nativeRoute 处理）；
        // 业务事件（rss.entry.open / rss.subscription.open / rss.refresh / rss.search.submit 等）
        // 不影响 navigation state，留给后续 slice 接 CoreBridge 真实处理
        case .rss_entry_open, .rss_entry_openOriginal, .rss_entry_openOriginalBrowser,
             .rss_subscription_open, .rss_subscription_add, .rss_subscription_edit,
             .rss_subscription_delete,
             .rss_ruleSubscription_create, .rss_ruleSubscription_edit,
             .rss_favorite_add, .rss_favorite_remove,
             .rss_refresh, .rss_filter_select, .rss_sourceFilter_select,
             .rss_search_submit, .rss_search_clear:
            // Slice 5a stub: RSS 业务事件，不影响 navigation state
            break
        // MARK: - Slice 5b: 书源业务事件 stub
        // 书源路由切换通过 route_push + routeId payload 触发（由 handleRoutePush/nativeRoute 处理）；
        // 业务事件（source.management.open / source.detail.open / source.switch.select 等）
        // 不影响 navigation state，留给后续 slice 接 CoreBridge 真实处理
        case .source_management_open, .source_detail_open,
             .source_add_open, .source_edit_open,
             .source_delete_confirm, .source_detect_run,
             .source_rule_edit, .source_debug_open, .source_debug_run,
             .source_logs_open, .source_code_view,
             .source_import_open, .source_import_preview, .source_import_apply,
             .source_search_submit, .source_search_clear,
             .source_switch_open, .source_switch_select,
             .source_switch_confirm, .source_switch_cancel:
            // Slice 5b stub: 书源业务事件，不影响 navigation state
            break
        // MARK: - Slice 5c: 搜索/书架事件 stub
        case .search_submit, .search_clear, .search_filter_toggle, .search_sort_change,
             .search_loadMore, .search_result_open,
             .bookshelf_view_switch, .bookshelf_group_select,
             .bookshelf_sortFilter_open, .bookshelf_sortFilter_apply, .bookshelf_sortFilter_cancel,
             .bookshelf_groupManagement_open, .bookshelf_groupManagement_create,
             .bookshelf_groupManagement_rename, .bookshelf_groupManagement_delete,
             .bookshelf_groupManagement_reorder,
             .bookshelf_localImport_open, .bookshelf_localImport_apply,
             .bookshelf_batchManagement_open:
            // Slice 5c stub: 搜索/书架管理事件，不影响 navigation state
            break
        // MARK: - Slice 5d: 发现事件 stub
        case .discover_sourceType_select, .discover_filter_apply, .discover_filter_reset,
             .discover_sort_toggle, .discover_entry_select,
             .discover_source_bulkEnable, .discover_source_bulkDisable, .discover_source_bulkRefresh,
             .discover_refresh:
            // Slice 5d stub: 发现事件，不影响 navigation state
            break
        // MARK: - Slice 6: 设置/about 事件 stub
        case .settings_scope_open, .settings_scope_close,
             .settings_overlay_open, .settings_overlay_close,
             .settings_entry_open, .settings_localImport_invoke,
             .settings_cache_clear, .settings_sync_open,
             .settings_webdav_save,
             .settings_restore_scopeToggle, .settings_restore_preview, .settings_restore_run,
             .settings_about_open:
            // Slice 6 stub: 设置/about 事件，不影响 navigation state
            break
        default:
            // 后续 slice 逐步接入业务事件。
            break
        }
    }

    // MARK: - Slice 3: reader control layer

    private func handleReaderControlToggle(_ event: UiEvent) {
        if navigationState.overlayState == .none {
            navigationState.setOverlay(.sheet)
        } else {
            navigationState.setOverlay(.none)
        }
    }

    private func handleReaderModuleSwitch(_ event: UiEvent) {
        // 模块切换：directory/tts/appearance/settings → 显示 sheet overlay
        guard let module = stringPayload(event, keys: ["module", "target"]) else {
            navigationState.setOverlay(.sheet)
            return
        }
        // Slice 3: 所有模块切换都显示 sheet overlay，后续 slice 按 module 分派不同 panel
        navigationState.setOverlay(.sheet)
        navigationState.focus("reader-module-\(module)")
    }

    // MARK: - Slice 4: TTS toggle

    private func handleReaderTtsToggle(_ event: UiEvent) {
        // TTS 切换：有活跃 session 则停止，无则启动
        // 注意：activeSession 是非可选 ReaderSession（默认 .none），不是 Optional
        if navigationState.activeSession != .none {
            navigationState.clearSession()
        } else {
            navigationState.startSession(.tts(playing: true))
        }
    }

    // MARK: - Slice 2: book_open / book_detail_open

    private func handleBookOpen(_ event: UiEvent) {
        let bookURL = stringPayload(event, keys: ["bookURL", "bookUrl", "url", "bookId", "bookID"]) ?? "slice2://book"
        let title = stringPayload(event, keys: ["title"]) ?? "Book Detail"
        let author = stringPayload(event, keys: ["author"])
        navigationState.push(.bookDetail(bookURL: bookURL, title: title, author: author))
    }

    // MARK: - Slice 2: reader_enter / reader_entry_*

    private func handleReaderEntry(_ event: UiEvent, source: ReaderContext.EntrySource) {
        let bookID = stringPayload(event, keys: ["bookId", "bookID", "bookURL", "bookUrl"])
        let chapterURL = stringPayload(event, keys: ["chapterURL", "chapterUrl", "url"]) ?? "slice2://chapter"
        let chapterTitle = stringPayload(event, keys: ["chapterTitle", "title"]) ?? "Chapter"
        let context = ReaderContext(
            bookID: bookID,
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            source: source
        )
        navigationState.enterImmersiveReading(context)
    }

    // MARK: - Slice 2: book_directory_open

    private func handleBookDirectoryOpen(_ event: UiEvent) {
        let bookURL = stringPayload(event, keys: ["bookURL", "bookUrl", "url", "bookId", "bookID"]) ?? "slice2://book"
        let title = stringPayload(event, keys: ["title"]) ?? "Directory"
        navigationState.push(.bookDetailToc(bookURL: bookURL, title: title))
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

    // MARK: - route.*

    private func handleRoutePush(_ event: UiEvent) {
        guard let route = nativeRoute(from: event) else { return }
        navigationState.push(route)
    }

    private func handleRouteReplace(_ event: UiEvent) {
        guard let route = nativeRoute(from: event) else { return }
        navigationState.replaceTop(with: route)
    }

    private func nativeRoute(from event: UiEvent) -> Route? {
        guard let routeId = contractRouteId(from: event) else { return nil }
        switch routeId {
        case .bookshelf:
            navigationState.switchTab(.bookshelf)
            return nil
        case .discover:
            navigationState.switchTab(.discover)
            return nil
        case .rss:
            navigationState.switchTab(.rss)
            return nil
        case .settings:
            navigationState.switchTab(.settings)
            return nil
        case .searchHome, .bookSearch:
            return .search
        case .searchResults:
            return .searchResults(query: stringPayload(event, keys: ["query", "q"]) ?? "")
        case .bookBatchManagement:
            return .bookBatchManagement
        case .localImport:
            return .bookshelfImport
        case .bookDetail:
            return .bookDetail(
                bookURL: stringPayload(event, keys: ["bookURL", "bookUrl", "url"]) ?? "slice1://book",
                title: stringPayload(event, keys: ["title"]) ?? "Book Detail",
                author: stringPayload(event, keys: ["author"])
            )
        case .bookDetailTocPreview, .bookDirectory:
            return .bookDetailToc(
                bookURL: stringPayload(event, keys: ["bookURL", "bookUrl", "url"]) ?? "slice1://book",
                title: stringPayload(event, keys: ["title"]) ?? "Directory"
            )
        case .sourceSwitch:
            return .sourceSwitch(bookURL: stringPayload(event, keys: ["bookURL", "bookUrl", "url"]) ?? "slice1://book")
        case .immersiveReading, .reader:
            return .reader(
                bookID: stringPayload(event, keys: ["bookID", "bookId"]) ?? "slice1-book",
                chapterURL: stringPayload(event, keys: ["chapterURL", "chapterUrl"]) ?? "slice1://chapter",
                chapterTitle: stringPayload(event, keys: ["chapterTitle", "title"]) ?? "Chapter"
            )
        case .rssSearch:
            return .rssSearch
        case .rssDetail:
            return .rssDetail(rssID: stringPayload(event, keys: ["rssID", "rssId", "id"]) ?? "slice1-rss")
        case .rssOriginal:
            return .rssOriginal(
                url: stringPayload(event, keys: ["url"]) ?? "https://example.invalid",
                title: stringPayload(event, keys: ["title"]) ?? "Original",
                sourceTitle: stringPayload(event, keys: ["sourceTitle"]) ?? "RSS"
            )
        case .rssOriginalBrowser:
            return .rssOriginalBrowser(
                url: stringPayload(event, keys: ["url"]) ?? "https://example.invalid",
                title: stringPayload(event, keys: ["title"]) ?? "Original",
                sourceTitle: stringPayload(event, keys: ["sourceTitle"]) ?? "RSS"
            )
        case .sourceManagement:
            return .bookSources
        case .sourceImportOptions:
            return .bookSourceImport
        case .sourceDetail:
            return .sourceDetail(sourceID: stringPayload(event, keys: ["sourceID", "sourceId", "id"]) ?? "slice1-source")
        case .sourceAdd:
            return .sourceAdd
        case .sourceEdit:
            return .sourceEdit(sourceID: stringPayload(event, keys: ["sourceID", "sourceId", "id"]) ?? "slice1-source")
        case .sourceTestResult:
            return .sourceTestResult(sourceID: stringPayload(event, keys: ["sourceID", "sourceId", "id"]) ?? "slice1-source")
        case .webdavConfig:
            return .webdavSettings
        case .remoteWebdavBooks:
            return .webdavBooks
        case .backupSettings:
            return .backupSettings
        case .progressSync:
            return .syncProgress
        case .readingSettingsEntry:
            return .settingsReading
        case .about, .aboutVersion:
            return .settingsAbout
        case .stateError, .globalError:
            return .stateError(message: stringPayload(event, keys: ["message"]) ?? "Error")
        case .stateOffline, .offlineState:
            return .stateOffline
        case .permissionRequired:
            return .statePermission(permission: stringPayload(event, keys: ["permission"]) ?? "unknown")
        default:
            return nil
        }
    }

    private func contractRouteId(from event: UiEvent) -> ReaderUIContract.RouteId? {
        guard let raw = stringPayload(event, keys: ["route", "routeId", "id"]) else { return nil }
        return ReaderUIContract.RouteId(rawValue: raw)
    }

    // MARK: - focus

    private func handleInputFocus(_ event: UiEvent) {
        guard let target = stringPayload(event, keys: ["target", "focusTarget", "id"]) else { return }
        navigationState.focus(target)
    }

    private func stringPayload(_ event: UiEvent, keys: [String]) -> String? {
        for key in keys {
            if let value = event.payload[key]?.value as? String {
                return value
            }
        }
        return nil
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
