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

    public init(navigationState: AppNavigationState) {
        self.navigationState = navigationState
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
        // Slice 3 落地：reader.control.toggle
        breakPoint("Slice 3 未落地：toggleReaderControl")
    }

    /// Slice 4：progress / session / focus / TTS
    public func startTts() {
        // Slice 4 落地：tts.queue.start + activeSession=tts
        breakPoint("Slice 4 未落地：startTts")
    }

    /// Slice 5：RSS / source / search
    public func openSearch() {
        // Slice 5 落地：route.push(search-home)
        breakPoint("Slice 5 未落地：openSearch")
    }

    /// Slice 6：sync / conflict / offline state
    public func runSync() {
        // Slice 6 落地：sync.run
        breakPoint("Slice 6 未落地：runSync")
    }

    // MARK: - B1-iOS P0: 通过 reducer dispatch 的协调方法

    /// 内部 reducer facade。包装既有 navigationState，提供 UiEvent dispatch 入口。
    private lazy var reducer: ReaderReducer = ReaderReducer(navigationState: navigationState)

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
        reducer.dispatch(UiEvent(type: .reader_control_toggle))
    }

    // MARK: - P0 修复：ReaderCoordinator 模块切换/覆盖层入口

    /// 打开阅读器目录覆盖层。dispatch `.reader_directory_open` → reducer 设置 overlay 为 .sheet。
    /// 对齐契约 `reader.directory.open`（demo: `reader.directory.open` payload `{}`）。
    public func openBookDirectory(bookId: String? = nil) {
        var payload: [String: AnyCodable] = [:]
        if let bookId { payload["bookId"] = AnyCodable(bookId) }
        reducer.dispatch(UiEvent(type: .reader_directory_open, payload: payload))
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

    /// 分派阅读器模块切换事件。dispatch `.reader_module_switch` → reducer 按 module 分派 sheet overlay。
    /// 对齐契约 `reader.module.switch`（demo: `reader.module.switch` payload `{ module }`）。
    /// 模块切换是 replace 语义（同层切换），不是 push 堆叠。
    public func readerModuleSwitch(module: String) {
        reducer.dispatch(UiEvent(type: .reader_module_switch, payload: [
            "module": AnyCodable(module)
        ]))
    }

    /// 确认换源。dispatch `.source_switch_confirm` → reducer pop 路由回到来源页。
    /// 对齐契约 `source.switch.confirm`（demo: `source.switch.confirm` payload `{ sourceId }`）。
    public func sourceSwitchConfirm(sourceId: String? = nil) {
        var payload: [String: AnyCodable] = [:]
        if let sourceId { payload["sourceId"] = AnyCodable(sourceId) }
        reducer.dispatch(UiEvent(type: .source_switch_confirm, payload: payload))
    }

    /// 取消换源。dispatch `.source_switch_cancel` → reducer pop 路由。
    /// 对齐契约 `source.switch.cancel`（demo: `source.switch.cancel` payload `{}`）。
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
