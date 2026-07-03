import Foundation
import SwiftUI

/// 阅读器进入沉浸阅读的上下文锚点。
///
/// 对齐 Motion ID：
/// - `reader.entry.coverToImmersive`（书架封面入口）
/// - `reader.entry.actionToImmersive`（继续阅读/章节/详情按钮入口）
///
/// `requestID` 用于 `motion.async.resultGuard` —— 连续点击只保留最后目标，
/// 旧请求视为 cancelled/discarded，不覆盖新导航。
public struct ReaderContext: Equatable, Hashable, Identifiable {
    public let id: UUID
    public let bookID: String?
    public let chapterURL: String
    public let chapterTitle: String
    public let sourceID: String?
    public let source: EntrySource

    public enum EntrySource: String, Equatable, Hashable {
        /// `reader.entry.coverToImmersive`
        case coverToImmersive
        /// `reader.entry.actionToImmersive`
        case actionToImmersive
    }

    public init(
        id: UUID = UUID(),
        bookID: String?,
        chapterURL: String,
        chapterTitle: String,
        sourceID: String? = nil,
        source: EntrySource
    ) {
        self.id = id
        self.bookID = bookID
        self.chapterURL = chapterURL
        self.chapterTitle = chapterTitle
        self.sourceID = sourceID
        self.source = source
    }
}

/// 运行会话状态（自动翻页 / 朗读互斥）。对齐 `reader.session.autoPage.start` /
/// `reader.session.tts.start`。Slice 1-2 只占位为 `.none`，Slice 5 会落地。
public enum ReaderSession: Equatable {
    case none
    case autoPage(playing: Bool)
    case tts(playing: Bool)
}

/// 覆盖层状态。对齐 `overlay.keyboard/sheet/dialog.*`。Slice 1-2 只占位为 `.none`，
/// Slice 4 会落地。
public enum OverlayState: Equatable {
    case none
    case keyboard
    case sheet
    case dialog
}

/// 动画打断状态。对齐 `motion.interrupt.cancel/redirect/completeThenReplace`。
/// Slice 1-2 用它解释 tab 切换 / 连续封面点击的最终状态。
public enum MotionInterrupt: Equatable {
    case none
    case cancel
    case redirect
    case completeThenReplace
}

/// 单一 UI state / reducer / Observable model。
///
/// 覆盖契约要求的字段：`activeTab`、`currentRoute`、`navigationPath`、
/// `ReaderContext`、`activeSession`、`overlayState`、`motionInterrupt`。
///
/// 设计：
/// - `activeTab` + `readerContext`/`activeSession`/`overlayState`/`motionInterrupt`
///   由本 model 统一持有，是 reducer 的唯一状态源。
/// - 每个 Tab 的 `NavigationPath` 由 `AppShellView` 持有（SwiftUI 原生
///   `NavigationStack(path:)` 模式），本 model 通过 `currentRoute` +
///   `navigationPath` 解释当前返回栈语义，避免 fragile dict 绑定。
/// - 旧的 `navigate/push/goBack/popToRoot` 保留，供既有 `ReaderFlowFeatureView`
///   等使用，不破坏既有调用面。
@MainActor
public final class AppNavigationState: ObservableObject {
    @Published public var currentRoute: Route = .home
    @Published public var navigationPath: [Route] = []

    // MARK: - Shell contract fields

    /// 当前主 Tab。对齐 `app.tab.switch`。
    @Published public var activeTab: AppTab = .bookshelf

    /// 当前沉浸阅读上下文。`nil` 表示不在沉浸阅读态。
    @Published public var readerContext: ReaderContext?

    /// 运行会话。Slice 1-2 默认 `.none`。
    @Published public var activeSession: ReaderSession = .none

    /// 覆盖层状态。Slice 1-2 默认 `.none`。
    @Published public var overlayState: OverlayState = .none

    /// 动画打断标记。用于解释“最终状态唯一，旧动画不排队”。
    @Published public var motionInterrupt: MotionInterrupt = .none

    /// Reduced-motion 适配器（测试可 override）。
    @Published public var motion: MotionEnvironment = MotionEnvironment()

    public init() {}

    // MARK: - Tab switch（app.tab.switch / tab.item.switch / motion.interrupt.cancel）

    /// 切换主 Tab。主 Tab 切换不写成二级 route push；旧 transition 取消，
    /// 切到最新 activeTab。
    public func switchTab(_ tab: AppTab) {
        guard tab != activeTab else { return }
        // tab 切换属于打断：取消正在播放的装饰动画（motion.interrupt.cancel）。
        motionInterrupt = .cancel
        motion.withMotionAnimation(AppMotion.Duration.tabSwitch) {
            activeTab = tab
        }
        // 收尾后清回 none，表示最终状态已落定。
        DispatchQueue.main.async {
            self.motionInterrupt = .none
        }
    }

    // MARK: - Immersive reading entry（reader.entry.coverToImmersive / actionToImmersive）

    /// 进入沉浸阅读。连续点击只保留最后目标（latest intent wins）：
    /// 每次 enter 都生成新的 `ReaderContext`（新 requestID），旧 context 被替换，
    /// 旧 async 结果视为 cancelled/discarded。
    public func enterImmersiveReading(_ context: ReaderContext) {
        motionInterrupt = .cancel
        // 最新意图胜出：直接覆盖 readerContext。
        readerContext = context
        // reduced-motion 下即时进入；否则用 readerEntry 时长。
        // 实际 NavigationStack push 由 AppShellView/BookshelfView 触发，
        // 这里只负责状态锚点与打断语义。
        DispatchQueue.main.async {
            self.motionInterrupt = .none
        }
    }

    /// 退出沉浸阅读，返回来源页。对应 `app.route.pop`。
    public func exitImmersiveReading() {
        motionInterrupt = .cancel
        readerContext = nil
        DispatchQueue.main.async {
            self.motionInterrupt = .none
        }
    }

    // MARK: - Legacy navigation（既有调用面，不破坏）

    public func navigate(to route: Route) {
        currentRoute = route
        if !navigationPath.contains(route) {
            navigationPath.append(route)
        }
    }

    public func push(_ route: Route) {
        navigationPath.append(route)
    }

    public func goBack() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
        if let last = navigationPath.last {
            currentRoute = last
        } else {
            currentRoute = .home
        }
    }

    public func popToRoot() {
        navigationPath.removeAll()
        currentRoute = .home
    }
}
