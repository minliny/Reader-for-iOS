import SwiftUI
import Foundation

// MARK: - StateError

/// 状态错误分类。
///
/// 对照 demo `frontend-demo/styles/00-foundation.css` 中 `.fd-state-card` /
/// `.fd-empty` / `.fd-loading` 系列状态卡语义，将错误归并为 6 类，便于
/// `StateContainerView` 在 error 态统一映射图标、标题与配色。
///
/// clean-room：只承载契约分类语义，不复制 Web CSS / DOM 实现。
public enum StateErrorKind: String, Sendable, Equatable {
    /// 网络错误（请求失败 / 超时）。
    case network
    /// 离线（无可用网络）。
    case offline
    /// 权限缺失（系统权限未授予）。
    case permission
    /// 解析失败（书源规则 / 章节正文解析出错）。
    case parse
    /// 资源不存在（404 / 书籍或章节缺失）。
    case notFound
    /// 未知错误。
    case unknown
}

public extension StateErrorKind {
    /// 对齐 `StateSurfaceView.StateSurfaceKind` 的图标映射，复用 ReaderAssetIcon。
    var icon: ReaderAssetIcon {
        switch self {
        case .network:   return .wifi
        case .offline:   return .offline
        case .permission: return .permission
        case .parse:     return .bug
        case .notFound:  return .search
        case .unknown:   return .warning
        }
    }

    /// 图标配色，对照 `StateSurfaceView.StateSurfaceKind.iconColor`。
    var iconColor: SwiftUI.Color {
        switch self {
        case .network, .offline, .notFound:
            return ReaderDesignTokens.Color.muted
        case .permission:
            return ReaderDesignTokens.Color.primaryDark
        case .parse, .unknown:
            return ReaderDesignTokens.Color.Semantic.danger
        }
    }

    /// 错误标题，对照 `StateSurfaceView.StateSurfaceKind.heading`。
    var heading: String {
        switch self {
        case .network:    return "网络请求失败"
        case .offline:    return "当前处于离线状态"
        case .permission: return "需要系统权限"
        case .parse:      return "内容解析失败"
        case .notFound:   return "资源不存在"
        case .unknown:    return "出现错误"
        }
    }
}

/// 状态错误载体。
///
/// 承载 `StateContainerPhase.error` 关联值，由 `StateContainerView` 在 error 态
/// 渲染为 `ConfirmDialog`（复用 `StateSurfaceView` 中的 ConfirmDialog 模式）。
public struct StateError: Sendable, Equatable {
    public let kind: StateErrorKind
    public let message: String
    public let retryable: Bool
    public let detail: String?

    public init(
        kind: StateErrorKind,
        message: String,
        retryable: Bool = true,
        detail: String? = nil
    ) {
        self.kind = kind
        self.message = message
        self.retryable = retryable
        self.detail = detail
    }
}

// MARK: - StateContainerPhase

/// 4 态状态枚举。
///
/// 对照 demo `motion-controller.js` 中 `app.state.replace`（160ms）的状态语义，
/// 统一 idle / loading / result / error 4 态表现。`loading` 携带 `requestId`，
/// 用于 `AsyncResultGuard` 校验异步回调是否仍匹配当前 route / context。
///
/// 泛型 `T` 承载 result 态数据；`Equatable` 通过条件扩展提供（需要 `T: Equatable`），
/// 以便 `StateContainerView` 用 `.animation(value:)` / `.onChange(of:)` 驱动 4 态切换。
public enum StateContainerPhase<T: Sendable>: Sendable {
    /// 空闲态：未发起请求或无数据。
    case idle
    /// 加载态：异步请求进行中。`requestId` 关联 `AsyncResultGuard`，`nil` 表示无需校验。
    case loading(requestId: UUID? = nil)
    /// 结果态：承载结果数据。
    case result(T)
    /// 错误态：承载错误信息。
    case error(StateError)
}

extension StateContainerPhase: Equatable where T: Equatable {
    public static func == (lhs: StateContainerPhase<T>, rhs: StateContainerPhase<T>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case let (.loading(a), .loading(b)):
            return a == b
        case let (.result(a), .result(b)):
            return a == b
        case let (.error(a), .error(b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - StateContainerView

/// 4 态状态容器视图。
///
/// 统一 idle / loading / result / error 4 态切换表现：
/// - idle：渲染 `idleContent`
/// - loading：渲染 `DemoLoadingSpinner`（30×30 边框旋转圆，复用 `DemoPrimitives`）
/// - result：渲染 `resultContent(T)`
/// - error：渲染 `ConfirmDialog`（复用 `StateSurfaceView` 模式），可附带重试按钮
///
/// 4 态切换用 `.transition(.opacity.combined(with: .move(edge: .bottom)))` +
/// `motionEnvironment.animation(AppMotion.Duration.stateReplace)` 触发，
/// 对照 `motion-controller.js` 中 `app.state.replace`（160ms）的 motion 语义。
///
/// clean-room：只承载状态切换与复用既有原语，不复制 Web CSS / DOM 实现。
public struct StateContainerView<T: Sendable & Equatable, Content: View, ResultContent: View>: View {
    /// 当前状态相位。
    public let phase: StateContainerPhase<T>
    /// 动效环境（reduced-motion 归一化）。
    public let motionEnvironment: MotionEnvironment
    /// error 态重试回调。`nil` 或 `error.retryable == false` 时不显示重试按钮。
    public let retryAction: (() -> Void)?
    /// idle 态内容构造器。
    private let idleContent: () -> Content
    /// result 态内容构造器。
    private let resultContent: (T) -> ResultContent

    public init(
        phase: StateContainerPhase<T>,
        motionEnvironment: MotionEnvironment = .shared,
        retryAction: (() -> Void)? = nil,
        @ViewBuilder idleContent: @escaping () -> Content,
        @ViewBuilder resultContent: @escaping (T) -> ResultContent
    ) {
        self.phase = phase
        self.motionEnvironment = motionEnvironment
        self.retryAction = retryAction
        self.idleContent = idleContent
        self.resultContent = resultContent
    }

    public var body: some View {
        Group {
            switch phase {
            case .idle:
                idleContent()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            case .loading:
                StateContainerLoadingView(motionEnvironment: motionEnvironment)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            case .result(let value):
                resultContent(value)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            case .error(let error):
                StateContainerErrorCard(error: error, retryAction: retryAction)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        // 用 stateReplace（160ms）驱动 4 态切换 transition。
        .animation(motionEnvironment.animation(AppMotion.Duration.stateReplace), value: phase)
        // phase 切换时同步 reduced-motion 状态，保证后续动画归一化与系统设置一致。
        .onChange(of: phase) { _ in
            motionEnvironment.refreshFromSystem()
        }
    }
}

// MARK: - 便捷 init（idle 为 EmptyView 时）

extension StateContainerView where Content == EmptyView {
    /// 当 idle 态无需自定义内容时使用的便捷 init。
    public init(
        phase: StateContainerPhase<T>,
        motionEnvironment: MotionEnvironment = .shared,
        retryAction: (() -> Void)? = nil,
        @ViewBuilder resultContent: @escaping (T) -> ResultContent
    ) {
        self.phase = phase
        self.motionEnvironment = motionEnvironment
        self.retryAction = retryAction
        self.idleContent = { EmptyView() }
        self.resultContent = resultContent
    }
}

// MARK: - .stateContainer ViewModifier（链式调用）

public extension View {
    /// 将当前视图包装为 `StateContainerView` 的 idle 内容：
    /// phase 为 `.idle` 时显示当前视图，其余 3 态由容器接管。
    func stateContainer<T: Sendable & Equatable, ResultContent: View>(
        _ phase: StateContainerPhase<T>,
        motionEnvironment: MotionEnvironment = .shared,
        retryAction: (() -> Void)? = nil,
        @ViewBuilder resultContent: @escaping (T) -> ResultContent
    ) -> some View {
        modifier(
            StateContainerModifier(
                phase: phase,
                motionEnvironment: motionEnvironment,
                retryAction: retryAction,
                resultContent: resultContent
            )
        )
    }
}

private struct StateContainerModifier<T: Sendable & Equatable, ResultContent: View>: ViewModifier {
    let phase: StateContainerPhase<T>
    let motionEnvironment: MotionEnvironment
    let retryAction: (() -> Void)?
    // `@ViewBuilder` 转换已在 `stateContainer(...)` 的参数处完成，
    // 这里只持有已转换的闭包值，无需再标注。
    let resultContent: (T) -> ResultContent

    func body(content: Content) -> some View {
        StateContainerView(
            phase: phase,
            motionEnvironment: motionEnvironment,
            retryAction: retryAction,
            idleContent: { content },
            resultContent: resultContent
        )
    }
}

// MARK: - 内部子视图

/// loading 态视图：复用 `DemoLoadingSpinner`（30×30 边框旋转圆）。
private struct StateContainerLoadingView: View {
    let motionEnvironment: MotionEnvironment

    var body: some View {
        VStack(spacing: 14) {
            DemoLoadingSpinner(size: .reader, motion: motionEnvironment)
        }
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssBrowserConfirmCardMinHeight)
        .accessibilityElement(children: .combine)
    }
}

/// error 态视图：复用 `ConfirmDialog` 模式（来自 `StateSurfaceView.swift`），
/// 简化为只承载错误信息 + 可选重试按钮。
private struct StateContainerErrorCard: View {
    let error: StateError
    let retryAction: (() -> Void)?

    var body: some View {
        ConfirmDialog(
            icon: error.kind.icon,
            iconColor: error.kind.iconColor,
            title: error.kind.heading,
            message: error.message,
            detail: error.detail
        ) {
            if error.retryable, let retryAction {
                Button(action: retryAction) {
                    Text("重试")
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .foregroundColor(.white)
                        .frame(minWidth: 120, minHeight: ReaderDesignTokens.rssReaderInlineActionMinHeight)
                        .padding(.horizontal, 12)
                        .background(Capsule().fill(ReaderDesignTokens.Color.primaryDark))
                }
                .buttonStyle(DemoPressButtonStyle())
                .padding(.top, 4)
            }
        }
    }
}
