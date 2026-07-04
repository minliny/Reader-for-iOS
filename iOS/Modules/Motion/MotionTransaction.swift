import Foundation

/// 动效事务。
///
/// 真源：`frontend-demo/motion-controller.js` `create()` 返回的 controller 内部事务对象
/// （demo line 1263-1275 `transaction` 字面量，含 `id` / `from` / `to` / `phase` /
/// `duration` / `sequence` / `timer` 等字段）。
///
/// 本结构承载单个动效事务的生命周期状态，不复制 Web `data-*` attribute 写入逻辑
/// （demo line 1198-1213 `writeRootState` / `clearTargetState`）；
/// iOS 端用 `phase` / `settledAt` 表达状态机推进，由 `MotionController` 统一调度。
public struct MotionTransaction: Identifiable, Sendable {

    /// 事务唯一 ID。
    public let id: UUID
    /// 关联的动效 ID。
    public let motionId: MotionId
    /// 起始状态（对应 demo 状态机 `from`，demo line 293-621）。
    public let fromState: String
    /// 目标状态（对应 demo 状态机 `to`，demo line 293-621）。
    public let toState: String
    /// 打断模式（事务创建时声明的接管策略）。
    public let interruptMode: MotionInterruptMode
    /// 最终状态（对应 demo 状态机 `finalState`，demo line 293-621）。
    public let finalState: String
    /// 时长（秒）。reduced motion 下由调用方归一化为 0。
    public let durationSeconds: TimeInterval
    /// 事务创建时间。
    public let createdAt: Date

    /// 当前阶段。
    public var phase: MotionPhase
    /// 进入 settled 阶段的时间。
    public var settledAt: Date?

    /// 成员构造器。
    public init(
        id: UUID = UUID(),
        motionId: MotionId,
        fromState: String,
        toState: String,
        interruptMode: MotionInterruptMode,
        finalState: String,
        durationSeconds: TimeInterval,
        createdAt: Date = Date(),
        phase: MotionPhase,
        settledAt: Date? = nil
    ) {
        self.id = id
        self.motionId = motionId
        self.fromState = fromState
        self.toState = toState
        self.interruptMode = interruptMode
        self.finalState = finalState
        self.durationSeconds = durationSeconds
        self.createdAt = createdAt
        self.phase = phase
        self.settledAt = settledAt
    }

    /// 创建进入中（`entering`）状态的事务。
    ///
    /// 对照 demo `start()`（demo line 1256-1297）创建 `phase: "running"` 事务的语义；
    /// iOS 端用 `.entering` 表达 from → to 的正向过渡起始。
    public static func start(
        id: UUID = UUID(),
        motionId: MotionId,
        fromState: String,
        toState: String,
        interruptMode: MotionInterruptMode,
        finalState: String,
        durationSeconds: TimeInterval,
        createdAt: Date = Date()
    ) -> MotionTransaction {
        MotionTransaction(
            id: id,
            motionId: motionId,
            fromState: fromState,
            toState: toState,
            interruptMode: interruptMode,
            finalState: finalState,
            durationSeconds: durationSeconds,
            createdAt: createdAt,
            phase: .entering,
            settledAt: nil
        )
    }

    /// 转入打断（`interrupted`）阶段。
    ///
    /// 对照 demo `interrupt()`（demo line 1240-1254）将 `phase` 置为 `"interrupted"` 的语义。
    /// `mode` 由 `MotionController` 在调用方决定接管策略（cancel / redirect / completeThenReplace）；
    /// 事务层只负责推进 phase，不在此处执行接管动作。
    /// 已 `settled` 或已 `interrupted` 的事务不可再被打断。
    public mutating func interrupt(mode: MotionInterruptMode) {
        guard phase != .settled, phase != .interrupted else { return }
        // mode 由上层 MotionController 决定接管策略；事务层统一推进到 interrupted。
        phase = .interrupted
    }

    /// 转入稳定（`settled`）阶段并记录 `settledAt`。
    ///
    /// 对照 demo `settle()`（demo line 1215-1238）将 `phase` 置为 `"settled"`、
    /// 清理 `timer` 并 dispatch `"settle"` 事件的语义；
    /// iOS 端用 `settledAt` 表达落位时间，timer / dispatch 由 `MotionController` 统一管理。
    /// 已 `settled` 的事务不可再次 settle。
    public mutating func settle() {
        guard phase != .settled else { return }
        phase = .settled
        settledAt = Date()
    }

    /// 当前事务的状态快照。
    ///
    /// 对照 demo `getSnapshot()`（demo line 1315-1320）返回的 active 事务快照；
    /// 用于跨层广播、调试面板、测试断言。
    public var snapshot: MotionStateSnapshot {
        MotionStateSnapshot(
            id: motionId,
            phase: phase,
            fromState: fromState,
            toState: toState,
            interruptMode: interruptMode,
            finalState: finalState,
            startedAt: createdAt,
            durationSeconds: durationSeconds
        )
    }
}
