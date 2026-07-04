import Foundation

/// 动效生命周期阶段。
///
/// 真源：`frontend-demo/motion-controller.js` 状态机 phase 语义（demo line 1215-1254）。
/// demo 中 phase 取值为 `running` / `settled` / `interrupted`；
/// 本枚举将 `running` 拆分为 `entering`（from → to）与 `leaving`（to → from），
/// 以更精确地表达阅读器主链路的双向过渡语义（如 reader.control.handle.release 的
/// snapBack / expand / collapse 三向收束、reader.session.capsule.enter / exit 双向）。
public enum MotionPhase: String, Sendable, Equatable {
    /// 进入中（from → to 过渡）。对应 demo 的 `running` 正向。
    case entering
    /// 离开中（to → from 过渡）。对应 demo 的 `running` 反向。
    case leaving
    /// 已稳定（停在 to 或 from）。对应 demo 的 `settled`（demo line 1222）。
    case settled
    /// 被打断（待接管）。对应 demo 的 `interrupted`（demo line 1247）。
    case interrupted
}

/// 打断模式。
///
/// 真源：`frontend-demo/motion-controller.js` INTERRUPT 三态
/// （demo line 39-41 `DEFAULT_DURATIONS` + demo line 580-600 `MOTION_ID_STATE_MACHINES`
/// 中 `motion.interrupt.cancel` / `redirect` / `completeThenReplace` 三个 Motion ID）。
///
/// 语义对照：
/// - `cancel`：立即取消旧动画，跳到 finalState。
/// - `redirect`：旧动画立即终止，新动画从当前位置接管。
/// - `completeThenReplace`：等旧动画完成再启动新动画。
public enum MotionInterruptMode: String, Sendable, Equatable {
    /// 立即取消旧动画，跳到 finalState。
    /// 对应 `motion.interrupt.cancel`（demo line 580）。
    case cancel
    /// 旧动画立即终止，新动画从当前位置接管。
    /// 对应 `motion.interrupt.redirect`（demo line 587）。
    case redirect
    /// 等旧动画完成再启动新动画。
    /// 对应 `motion.interrupt.completeThenReplace`（demo line 594）。
    case completeThenReplace
}

/// 动效状态快照。
///
/// 真源：`frontend-demo/motion-controller.js` `getSnapshot()`（demo line 1315-1320）
/// 返回的 active 事务快照（剥离 `target` / `timer` 等 Web 运行时字段）。
/// 本结构只承载状态语义，不复制 Web DOM / `data-*` selector；
/// 用于 iOS 端的调试面板、测试断言、跨层状态广播。
public struct MotionStateSnapshot: Sendable, Equatable {
    /// 动效 ID。
    public let id: MotionId
    /// 当前阶段。
    public let phase: MotionPhase
    /// 起始状态（对应 demo 状态机 `from`，demo line 293-621）。
    public let fromState: String
    /// 目标状态（对应 demo 状态机 `to`，demo line 293-621）。
    public let toState: String
    /// 打断模式。
    public let interruptMode: MotionInterruptMode
    /// 最终状态（对应 demo 状态机 `finalState`，demo line 293-621）。
    public let finalState: String
    /// 事务启动时间。
    public let startedAt: Date
    /// 时长（秒）。
    public let durationSeconds: TimeInterval

    public init(
        id: MotionId,
        phase: MotionPhase,
        fromState: String,
        toState: String,
        interruptMode: MotionInterruptMode,
        finalState: String,
        startedAt: Date,
        durationSeconds: TimeInterval
    ) {
        self.id = id
        self.phase = phase
        self.fromState = fromState
        self.toState = toState
        self.interruptMode = interruptMode
        self.finalState = finalState
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
    }
}
