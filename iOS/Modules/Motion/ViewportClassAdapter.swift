import Foundation
import CoreGraphics
import SwiftUI

/// 视口类别。对照 demo `render-runtime.js` `viewportClassSnapshot()`（第 179-226 行）
/// 的 `viewportClass` 字段，简化为四态以匹配 iOS SwiftUI 的 size class 语义。
///
/// 阈值对照 `ReaderDesignTokens.readerExpandedWidthMinWidth` (600) /
/// `readerTabletExpandedMinWidth` (840) / `readerCompactLandscapeMaxHeight` (520)，
/// 与 demo `viewportClassSnapshot()` 第 190-216 行的判定一致。
public enum ViewportClass: String, Sendable, Equatable, CaseIterable {
    /// 竖屏手机（width < 600）。
    case compact
    /// 横屏手机（landscape 且 height <= 520）。
    case compactLandscape
    /// expanded-width（600 <= width < 840）。
    case expanded
    /// tablet-expanded（width >= 840）。
    case tabletExpanded
}

/// 视口重排三段式阶段。
///
/// 对照 demo `motion-controller.js` 第 42-44 行：
/// - `viewport.orientation.prepare` = 80ms
/// - `viewport.orientation.reshape` = 240ms
/// - `viewport.orientation.settle` = 240ms
///
/// 时长映射到 `ReaderMotion.Duration`：
/// - `prepare` —— `orientationFreeze` (0.08) / `interruptSettle` (0.08)
/// - `reshape` —— `viewportReshape` (0.24)
/// - `settle` —— `orientationSettle` (0.24)
public enum ViewportReshapePhase: String, Sendable, Equatable {
    /// 80ms 冻结旧动画、释放手势、记录锚点。
    case prepare
    /// 240ms 重排（正文重新测量、控制层/overlay/胶囊重新定位）。
    case reshape
    /// 240ms 锚定（恢复 focus/语义、clamp dock、恢复微动效）。
    case settle
    /// 未在 reshape 中。
    case idle
}

/// 视口快照。对应 demo `viewportClassSnapshot()` 返回的快照对象，但只保留
/// 契约需要的字段（class / width / height / phase / phaseStartedAt / phaseDuration）。
public struct ViewportSnapshot: Sendable, Equatable {
    /// 当前视口类别。
    public let viewportClass: ViewportClass
    /// 当前宽度（pt）。
    public let width: CGFloat
    /// 当前高度（pt）。
    public let height: CGFloat
    /// 当前 reshape 阶段。
    public let phase: ViewportReshapePhase
    /// 当前阶段开始时间。
    public let phaseStartedAt: Date
    /// 当前阶段时长（秒）。
    public let phaseDurationSeconds: TimeInterval

    public init(
        viewportClass: ViewportClass,
        width: CGFloat,
        height: CGFloat,
        phase: ViewportReshapePhase,
        phaseStartedAt: Date,
        phaseDurationSeconds: TimeInterval
    ) {
        self.viewportClass = viewportClass
        self.width = width
        self.height = height
        self.phase = phase
        self.phaseStartedAt = phaseStartedAt
        self.phaseDurationSeconds = phaseDurationSeconds
    }
}

/// 视口类别适配器：三段式 reshape 状态机。
///
/// 当 `ViewportClass` 发生变化时，依次进入 `prepare` (80ms) → `reshape` (240ms) →
/// `settle` (240ms) → `idle`。对应契约 `viewport.orientation.prepare/reshape/settle`。
///
/// 三段式时序通过 `Task` + `Task.sleep` 实现，不引入 Combine Timer。每次新 reshape
/// 启动会取消上一次进行中的 `Task`（对应 `motion.interrupt.cancel` 语义）。
@MainActor
public final class ViewportClassAdapter: ObservableObject {

    /// 当前视口类别。
    @Published private(set) var currentClass: ViewportClass = .compact

    /// 当前 reshape 阶段。
    @Published private(set) var reshapePhase: ViewportReshapePhase = .idle

    /// 最近一次快照。
    @Published private(set) var lastSnapshot: ViewportSnapshot?

    /// 单例。
    public static let shared: ViewportClassAdapter = ViewportClassAdapter()

    /// 当前 reshape 序列的 Task，用于在新 reshape 启动或 `reset()` 时取消。
    private var reshapeTask: Task<Void, Never>?

    public init() {}

    /// 静态分类函数。阈值对照 `ReaderDesignTokens` 三个常量，与 demo
    /// `viewportClassSnapshot()` 判定顺序一致：
    /// 1. landscape 且 height <= 520 → `compactLandscape`
    /// 2. width >= 840 → `tabletExpanded`
    /// 3. width >= 600 → `expanded`
    /// 4. 其余 → `compact`
    ///
    /// `nonisolated`：只读 `ReaderDesignTokens` 全局常量，线程安全，允许在任意上下文调用。
    public nonisolated static func classify(width: CGFloat, height: CGFloat) -> ViewportClass {
        let isLandscape = width > height
        if isLandscape && height <= ReaderDesignTokens.readerCompactLandscapeMaxHeight {
            return .compactLandscape
        }
        if width >= ReaderDesignTokens.readerTabletExpandedMinWidth {
            return .tabletExpanded
        }
        if width >= ReaderDesignTokens.readerExpandedWidthMinWidth {
            return .expanded
        }
        return .compact
    }

    /// 接收新尺寸。若 `ViewportClass` 变化则启动三段式 reshape 序列；返回当前快照。
    @discardableResult
    public func update(width: CGFloat, height: CGFloat) -> ViewportSnapshot {
        let newClass = ViewportClassAdapter.classify(width: width, height: height)
        let classChanged = newClass != currentClass
        if classChanged {
            currentClass = newClass
            startReshapeSequence(width: width, height: height)
        }
        let snapshot = ViewportSnapshot(
            viewportClass: newClass,
            width: width,
            height: height,
            phase: reshapePhase,
            phaseStartedAt: Date(),
            phaseDurationSeconds: phaseDuration(for: reshapePhase)
        )
        lastSnapshot = snapshot
        return snapshot
    }

    /// 推进到下一阶段（由外部 Timer 驱动场景；与内部 `Task.sleep` 二选一）。
    /// `idle` 时无操作。
    public func advancePhase() {
        let next: ViewportReshapePhase
        switch reshapePhase {
        case .prepare: next = .reshape
        case .reshape: next = .settle
        case .settle: next = .idle
        case .idle: return
        }
        if let last = lastSnapshot {
            recordSnapshot(
                viewportClass: last.viewportClass,
                width: last.width,
                height: last.height,
                phase: next
            )
        } else {
            reshapePhase = next
        }
    }

    /// 回到 `idle`，取消进行中的 reshape 序列。
    public func reset() {
        reshapeTask?.cancel()
        reshapeTask = nil
        reshapePhase = .idle
    }

    // MARK: - Private

    /// 启动三段式 reshape 序列：prepare → reshape → settle → idle。
    /// 每次启动取消上一次进行中的 Task。
    private func startReshapeSequence(width: CGFloat, height: CGFloat) {
        reshapeTask?.cancel()
        reshapeTask = Task { [weak self] in
            guard let self else { return }
            let phases: [ViewportReshapePhase] = [.prepare, .reshape, .settle]
            for phase in phases {
                if Task.isCancelled { return }
                self.recordSnapshot(
                    viewportClass: self.currentClass,
                    width: width,
                    height: height,
                    phase: phase
                )
                let duration = self.phaseDuration(for: phase)
                if duration > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                }
            }
            if Task.isCancelled { return }
            self.recordSnapshot(
                viewportClass: self.currentClass,
                width: width,
                height: height,
                phase: .idle
            )
        }
    }

    /// 记录快照并更新 `reshapePhase`。
    private func recordSnapshot(
        viewportClass: ViewportClass,
        width: CGFloat,
        height: CGFloat,
        phase: ViewportReshapePhase
    ) {
        reshapePhase = phase
        lastSnapshot = ViewportSnapshot(
            viewportClass: viewportClass,
            width: width,
            height: height,
            phase: phase,
            phaseStartedAt: Date(),
            phaseDurationSeconds: phaseDuration(for: phase)
        )
    }

    /// 各阶段时长，对照 `ReaderMotion.Duration`。
    private func phaseDuration(for phase: ViewportReshapePhase) -> TimeInterval {
        switch phase {
        case .prepare:
            // 80ms 冻结（对应 orientationFreeze / interruptSettle）。
            return ReaderMotion.Duration.orientationFreeze
        case .reshape:
            // 240ms 重排（对应 viewportReshape）。
            return ReaderMotion.Duration.viewportReshape
        case .settle:
            // 240ms 锚定（对应 orientationSettle）。
            return ReaderMotion.Duration.orientationSettle
        case .idle:
            return 0
        }
    }
}
