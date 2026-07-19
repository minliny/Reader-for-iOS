import Foundation
import SwiftUI
import ReaderUIContract

/// ReaderCoordinator — 协调 navigation stack / overlay / activeSession。
///
/// 职责（CONTRACT_FIRST_NATIVE_UI_PLAN.md §6）：
/// - 协调 navigation stack（route push/pop）
/// - 协调 overlay 显隐
/// - 协调 activeSession（reading / tts / autoPage）
///
/// 设计：
/// - Slice 1 仅作为骨架，所有方法留给后续 slice 落地。
/// - 不持有状态，状态由 `AppNavigationState` 持有；coordinator 只发指令。
/// - 包装既有 `AppNavigationState.navigate / enterImmersiveReading / exitImmersiveReading`，
///   不重写。
@MainActor
public final class ReaderCoordinator {
    private let navigationState: AppNavigationState
    private let runtimeShadow: ReaderUIRuntimeShadowCoordinator?
    private let playbackPilot: ReaderPlaybackPilotCoordinator?
    private let sourceSwitchPilot: ReaderSourceSwitchPilotCoordinator?
    private let replaceRulePilot: ReaderReplaceRulePilotCoordinator?
    private let syncPilot: ReaderSyncPilotCoordinator?
    private let cacheCoordinator: ReaderCacheCoordinator?

    public init(
        navigationState: AppNavigationState,
        runtimeShadow: ReaderUIRuntimeShadowCoordinator? = nil,
        playbackPilot: ReaderPlaybackPilotCoordinator? = nil,
        sourceSwitchPilot: ReaderSourceSwitchPilotCoordinator? = nil,
        replaceRulePilot: ReaderReplaceRulePilotCoordinator? = nil,
        syncPilot: ReaderSyncPilotCoordinator? = nil,
        cacheCoordinator: ReaderCacheCoordinator? = nil
    ) {
        self.navigationState = navigationState
        self.runtimeShadow = runtimeShadow
        self.playbackPilot = playbackPilot
        self.sourceSwitchPilot = sourceSwitchPilot
        self.replaceRulePilot = replaceRulePilot
        self.syncPilot = syncPilot
        self.cacheCoordinator = cacheCoordinator
    }

    // MARK: - Slice 1 占位（后续 slice 落地）

    /// Slice 2：bookshelf → open book → reader surface
    ///
    /// P0-05 验收：
    /// - 打开书进入 immersive-reading（不是 book-detail，直接进沉浸阅读）
    /// - back 返回来源页（由 ContractNavigationStack.defaultPredecessor 处理深链）
    /// - 重复 open 是 latest-intent-wins（enterImmersiveReading 覆盖 readerContext）
    public func openBook(_ bookId: String) {
        let context = ReaderContext(
            bookID: bookId,
            chapterURL: "slice2://chapter",
            chapterTitle: "Chapter",
            source: .actionToImmersive
        )
        navigationState.enterImmersiveReading(context)
    }

    /// Slice 3：reader overlay / control dock / reader mode
    public func toggleReaderControl() {
        reducer.dispatch(UiEvent(
            type: .reader_control_toggle,
            payload: ["overlay": AnyCodable("reader-control")]
        ))
    }

    // MARK: - H2 W2: 翻页 / TTS / 自动翻页 UiEvent 链路

    /// 翻到下一页。dispatch `.reader_page_next` → reducer 更新 readerPageIndex。
    /// Shadow 模式下 reducer 是状态真源；Pilot 由 ReaderPlaybackPilotCoordinator 拦截。
    public func readerPageNext() {
        reducer.dispatch(UiEvent(type: .reader_page_next))
    }

    /// 翻到上一页。dispatch `.reader_page_prev` → reducer 更新 readerPageIndex（下限 0）。
    public func readerPagePrev() {
        reducer.dispatch(UiEvent(type: .reader_page_prev))
    }

    /// 启动 TTS。dispatch `.reader_tts_start` → reducer 设置 activeSession=.tts(playing: true)。
    public func startTts() {
        reducer.dispatch(UiEvent(type: .reader_tts_start))
    }

    /// 停止 TTS。dispatch `.reader_tts_stop` → reducer 清除 activeSession。
    public func stopTts() {
        reducer.dispatch(UiEvent(type: .reader_tts_stop))
    }

    /// 启动自动翻页。dispatch `.reader_autoPage_start` → reducer 设置 activeSession=.autoPage(playing: true)。
    /// payload 携带 intervalMs，对齐契约 `reader.autoPage.start` payload `{ intervalMs }`。
    public func startAutoPage(intervalMs: Int = 5_000) {
        reducer.dispatch(UiEvent(type: .reader_autoPage_start, payload: [
            "intervalMs": AnyCodable(intervalMs)
        ]))
    }

    /// 停止自动翻页。dispatch `.reader_autoPage_stop` → reducer 清除 activeSession。
    public func stopAutoPage() {
        reducer.dispatch(UiEvent(type: .reader_autoPage_stop))
    }

    /// Slice 6：sync / conflict / offline state
    /// Dispatch `sync.start` through the sync pilot coordinator. When the
    /// pilot is not configured, falls back to the native placeholder.
    public func runSync() {
        guard let syncPilot else {
            breakPoint("Slice 6 sync pilot 未配置")
            return
        }
        let outcome = syncPilot.startSync(payload: [:], correlationId: nil)
        if outcome == .failedClosed {
            breakPoint("Slice 6 sync.start fail-closed: \(syncPilot.lastFailure ?? "unknown")")
        }
    }

    // MARK: - B1-iOS P0: 通过 reducer dispatch 的协调方法

    /// 内部 reducer facade。包装既有 navigationState，提供 UiEvent dispatch 入口。
    private lazy var reducer: ReaderReducer = ReaderReducer(
        navigationState: navigationState,
        runtimeShadow: runtimeShadow,
        playbackPilot: playbackPilot,
        sourceSwitchPilot: sourceSwitchPilot,
        replaceRulePilot: replaceRulePilot,
        cacheCoordinator: cacheCoordinator
    )

    /// Generic ScreenGraph controls enter the same reducer/pilot boundary as hand-authored Native
    /// controls. The caller must still provide this callback explicitly; shadow diagnostics disable
    /// hit testing and therefore cannot mutate production state.
    public func dispatch(_ event: UiEvent) {
        reducer.dispatch(event)
    }

    /// 打开书籍详情页。dispatch `.book_detail_open` → reducer 推入 bookDetail 路由。
    public func openBookDetail(bookId: String, title: String? = nil, author: String? = nil) {
        var payload: [String: AnyCodable] = ["bookURL": AnyCodable(bookId)]
        if let title { payload["title"] = AnyCodable(title) }
        if let author { payload["author"] = AnyCodable(author) }
        reducer.dispatch(UiEvent(type: .book_detail_open, payload: payload))
    }

    /// 打开书源切换页。dispatch `.source_switch_open` → reducer 推入 sourceSwitch 路由。
    public func openSourceSwitch(bookId: String) {
        reducer.dispatch(UiEvent(type: .source_switch_open, payload: [
            "bookURL": AnyCodable(bookId)
        ]))
    }

    /// 打开设置覆盖层。dispatch `.settings_overlay_open` → reducer 设置 overlay 为 .dialog。
    public func openSettings() {
        reducer.dispatch(UiEvent(type: .settings_overlay_open))
    }

    /// 切换阅读器控制层。dispatch `.reader_control_toggle` → reducer 切换 overlay sheet。
    public func readerControl(action: String? = nil) {
        _ = action
        toggleReaderControl()
    }

    // MARK: - P0 修复：ReaderCoordinator 模块切换/覆盖层入口

    /// 打开阅读器目录覆盖层。dispatch `.reader_directory_open`；R8 Pilot 由
    /// runtime 写 semantic directory，shadow rollback 才回到 native reducer。
    public func openBookDirectory(bookId: String? = nil) {
        // `reader.directory.open` is intentionally an empty-object contract.
        // The optional native book identity remains a caller convenience only;
        // reader session state already owns the selected book.
        _ = bookId
        reducer.dispatch(UiEvent(type: .reader_directory_open))
    }

    /// 关闭阅读器目录覆盖层。与 open 共用同一 runtime-aware dispatch 入口；
    /// schema 2 仅在 semantic overlay 仍为 directory 时清除。
    public func closeBookDirectory() {
        reducer.dispatch(UiEvent(type: .reader_directory_close))
    }

    /// 打开阅读器外观覆盖层。dispatch `.reader_appearance_open` → reducer 设置 overlay 为 .sheet。
    /// 对齐契约 `reader.appearance.open`（demo: `reader.appearance.open` payload `{}`）。
    public func openReaderAppearance() {
        reducer.dispatch(UiEvent(type: .reader_appearance_open))
    }

    /// 打开阅读器设置覆盖层。dispatch `.reader_settings_open` → reducer 设置 overlay 为 .sheet。
    /// 对齐契约 `reader.settings.open`（demo: `reader.settings.open` payload `{}`）。
    public func openReaderSettings() {
        reducer.dispatch(UiEvent(type: .reader_settings_open))
    }

    /// Resolve the cache surface against an explicit live reader identity.
    /// Missing source/book values are never substituted by demo identifiers.
    public func openBookCache(sourceID: String, bookID: String, chapterIndex: Int? = nil) {
        var payload: [String: AnyCodable] = [
            "sourceId": AnyCodable(sourceID),
            "bookId": AnyCodable(bookID),
        ]
        if let chapterIndex { payload["chapterIndex"] = AnyCodable(chapterIndex) }
        reducer.dispatch(UiEvent(type: .reader_bookCache_open, payload: payload))
    }

    public func clearDerivedCacheFromSettings() {
        reducer.dispatch(UiEvent(type: .settings_cache_clear))
    }

    /// 分派阅读器模块切换事件。dispatch `.reader_module_switch` → reducer 按 module 分派 sheet overlay。
    /// 对齐契约 `reader.module.switch`（demo: `reader.module.switch` payload `{ module }`）。
    /// 模块切换是 replace 语义（同层切换），不是 push 堆叠。
    public func readerModuleSwitch(module: String) {
        reducer.dispatch(UiEvent(type: .reader_module_switch, payload: [
            "module": AnyCodable(module)
        ]))
    }

    /// 确认换源。dispatch `.source_switch_confirm` → reducer 通过 pilot coordinator dispatch。
    /// 对齐契约 `source.switch.confirm`（demo: `source.switch.confirm` payload `{ sourceId }`）。
    /// H4-D: When the source switch pilot is active, the coordinator dispatches
    /// source.switch.confirm (emitEffects → source.switch.commit Core effect).
    public func sourceSwitchConfirm(sourceId: String? = nil) {
        var payload: [String: AnyCodable] = [:]
        if let sourceId { payload["sourceId"] = AnyCodable(sourceId) }
        reducer.dispatch(UiEvent(type: .source_switch_confirm, payload: payload))
    }

    /// 取消换源。dispatch `.source_switch_cancel` → reducer 通过 pilot coordinator dispatch。
    /// 对齐契约 `source.switch.cancel`（demo: `source.switch.cancel` payload `{}`）。
    /// H4-D: When the source switch pilot is active, the coordinator dispatches
    /// source.switch.cancel (popRoute, no Core effect).
    public func sourceSwitchCancel() {
        reducer.dispatch(UiEvent(type: .source_switch_cancel))
    }

    // MARK: - 既有 navigation 包装（不重写）

    public func navigate(to route: Route) {
        navigationState.navigate(to: route)
    }

    public func enterImmersiveReading(_ context: ReaderContext) {
        navigationState.enterImmersiveReading(context)
    }

    public func exitImmersiveReading() {
        navigationState.exitImmersiveReading()
    }

    private func breakPoint(_ msg: String) {
        // Slice 1 阶段：后续 slice 未落地前，记录但不执行。
        // 后续 slice 落地时替换为真实实现。
        #if DEBUG
        print("[ReaderCoordinator] \(msg)")
        #endif
    }
}
