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
        default:
            // 后续 slice 逐步接入业务事件。
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
