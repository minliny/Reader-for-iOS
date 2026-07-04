import Foundation

/// 动效运行时 Controller。
///
/// 真源：`frontend-demo/motion-controller.js` `create()`（demo line 1164-1334）
/// 返回的 controller 对象，对外暴露 `start` / `update` / `interrupt` / `settle` /
/// `setReducedMotion` / `getSnapshot` / `destroy` 七个方法。
///
/// 本类承载事务生命周期管理，不复制 Web `data-*` attribute 写入（demo line 1198-1213）、
/// `setTimeout`（demo line 1294）、`CustomEvent` 派发（demo line 1193-1196）逻辑；
/// iOS 端用 `@Published` 字典驱动 SwiftUI 视图更新，用 `print` 提供 debug 日志。
///
/// 设计要点（与 demo 的差异）：
/// - 支持多事务并发（按 UUID 索引），区别于 demo 的单 `active` 模型（demo line 1168）；
///   iOS 端阅读器可能同时存在 capsule / controlLayer / pageTurn 等多条动效链路。
/// - `activeTransactions` 只保留未 settled 的事务；settled 后移除，避免无限增长。
/// - `lastSnapshot` 保留每个 MotionId 的最新快照，供调试与测试断言。
/// - reduced motion 归一化由调用方（结合 `MotionEnvironment`）在 `start` 前完成，
///   Controller 不内置 `reducedMotion` 判定，保持单一职责。
@MainActor
public final class MotionController: ObservableObject {

    /// 单例。全局唯一运行时，便于跨模块访问；
    /// 测试可用 `reset()` 清空状态后注入新实例。
    public static let shared: MotionController = MotionController()

    /// 当前活跃事务（未 settled）。key 为事务 UUID。
    ///
    /// 对照 demo 的 `active` 变量（demo line 1168），但扩展为多事务字典。
    @Published public private(set) var activeTransactions: [UUID: MotionTransaction] = [:]

    /// 每个 MotionId 的最新快照。
    ///
    /// 对照 demo `getSnapshot()`（demo line 1315-1320）返回的 active 事务；
    /// iOS 端按 MotionId 索引，保留最新一份，便于调试面板与测试断言。
    @Published public private(set) var lastSnapshot: [MotionId: MotionStateSnapshot] = [:]

    public init() {}

    // MARK: - 事务生命周期

    /// 启动事务，返回事务 UUID。
    ///
    /// 对照 demo `start()`（demo line 1256-1297）：
    /// - demo 中若已有 active 事务会先 `interrupt`；iOS 端支持多事务并发，不自动打断，
    ///   由调用方显式调用 `interrupt(transactionId:mode:)`。
    /// - demo 中 `duration === 0` 时立即 `settle`（demo line 1291-1292）；
    ///   iOS 端由调用方在 reduced motion 下传 `durationSeconds: 0`，Controller 不自动 settle，
    ///   保持事务可追踪（settled 由显式调用或绑定层驱动）。
    ///
    /// - Parameters:
    ///   - id: 动效 ID。
    ///   - fromState: 起始状态。
    ///   - toState: 目标状态。
    ///   - interruptMode: 打断模式。
    ///   - finalState: 最终状态。
    ///   - durationSeconds: 时长（秒）。
    /// - Returns: 事务 UUID。
    @discardableResult
    public func start(
        id: MotionId,
        fromState: String,
        toState: String,
        interruptMode: MotionInterruptMode,
        finalState: String,
        durationSeconds: TimeInterval
    ) -> UUID {
        let transaction = MotionTransaction.start(
            motionId: id,
            fromState: fromState,
            toState: toState,
            interruptMode: interruptMode,
            finalState: finalState,
            durationSeconds: durationSeconds
        )
        activeTransactions[transaction.id] = transaction
        lastSnapshot[id] = transaction.snapshot
        print("[MotionController] start motion=\(id.rawValue) family=\(id.family.rawValue) tx=\(transaction.id) phase=entering from=\(fromState) to=\(toState) duration=\(durationSeconds)s mode=\(interruptMode.rawValue)")
        return transaction.id
    }

    /// 打断指定事务。
    ///
    /// 对照 demo `interrupt()`（demo line 1240-1254）将 `phase` 置为 `"interrupted"` 的语义。
    /// `mode` 决定接管策略（cancel / redirect / completeThenReplace），
    /// 由调用方结合 `MotionEnvironment` 与业务语义传入。
    ///
    /// - Parameters:
    ///   - transactionId: 事务 UUID。
    ///   - mode: 打断模式。
    public func interrupt(transactionId: UUID, mode: MotionInterruptMode) {
        guard var transaction = activeTransactions[transactionId] else {
            print("[MotionController] interrupt miss tx=\(transactionId) mode=\(mode.rawValue) (not active)")
            return
        }
        let previousPhase = transaction.phase
        transaction.interrupt(mode: mode)
        activeTransactions[transactionId] = transaction
        lastSnapshot[transaction.motionId] = transaction.snapshot
        print("[MotionController] interrupt tx=\(transactionId) motion=\(transaction.motionId.rawValue) mode=\(mode.rawValue) \(previousPhase.rawValue) -> interrupted")
    }

    /// 让事务进入 settled。
    ///
    /// 对照 demo `settle()`（demo line 1215-1238）将 `phase` 置为 `"settled"`、
    /// 清理 `timer` 的语义。settled 后事务从 `activeTransactions` 移除，
    /// `lastSnapshot` 保留最新快照。
    ///
    /// - Parameter transactionId: 事务 UUID。
    public func settle(transactionId: UUID) {
        guard var transaction = activeTransactions[transactionId] else {
            print("[MotionController] settle miss tx=\(transactionId) (not active)")
            return
        }
        transaction.settle()
        lastSnapshot[transaction.motionId] = transaction.snapshot
        activeTransactions.removeValue(forKey: transactionId)
        print("[MotionController] settle tx=\(transactionId) motion=\(transaction.motionId.rawValue) -> settled")
    }

    // MARK: - 查询

    /// 查询某 MotionId 的最新快照。
    ///
    /// 对照 demo `getSnapshot()`（demo line 1315-1320）。
    public func snapshot(for motionId: MotionId) -> MotionStateSnapshot? {
        lastSnapshot[motionId]
    }

    /// 查询某 MotionId 的活跃事务数。
    ///
    /// iOS 端支持多事务并发，此方法用于检测同 MotionId 是否已有未完成事务，
    /// 调用方可据此决定是否先 `interrupt` 再 `start`。
    public func activeCount(for motionId: MotionId) -> Int {
        activeTransactions.values.filter { $0.motionId == motionId }.count
    }

    // MARK: - 测试 / 重置

    /// 清空所有状态（测试用）。
    ///
    /// 对照 demo `destroy()`（demo line 1321-1333），但只清内存状态，
    /// 不涉及 Web attribute 清理。
    public func reset() {
        activeTransactions.removeAll()
        lastSnapshot.removeAll()
        print("[MotionController] reset")
    }
}
