import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Keyframe 数据模型

/// 单个关键帧样本。
///
/// 真源：`frontend-demo/motion-tokens.css` 第 613-841 行 14 个 `@keyframes` 中
/// 的某个时间点（`from` / `to` / `0%` / `50%` / `100%`）。
/// 本类型只承载关键时间点的数值化属性，不复制 CSS selector / `var(--*)` 解析逻辑；
/// 由 `MotionKeyframeSequence` 组合成完整动画，由调用方（结合 `MotionEnvironment`）
/// 在 SwiftUI 中驱动 `withAnimation` / `keyframeAnimator` / `transition`。
public struct MotionKeyframeSample: Sendable, Equatable {
    /// 关键时间点，取值 0.0 ~ 1.0。对应 CSS `@keyframes` 的 `0%` / `50%` / `100%`。
    public let time: Double
    /// 不透明度。`nil` 表示该样本不改变 opacity。
    public let opacity: Double?
    /// X 位移（pt）。`nil` 表示不改变 x。对应 CSS `transform: translateX(...)` / `translate: ...`。
    public let offsetX: CGFloat?
    /// Y 位移（pt）。`nil` 表示不改变 y。对应 CSS `transform: translateY(...)` / `translate: ...`。
    public let offsetY: CGFloat?
    /// 缩放比例。`nil` 表示不改变 scale。对应 CSS `transform: scale(...)`。
    public let scale: CGFloat?

    public init(
        time: Double,
        opacity: Double? = nil,
        offsetX: CGFloat? = nil,
        offsetY: CGFloat? = nil,
        scale: CGFloat? = nil
    ) {
        self.time = time
        self.opacity = opacity
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.scale = scale
    }
}

/// 关键帧序列。
///
/// 真源：`frontend-demo/motion-tokens.css` 第 613-841 行 14 个 `@keyframes <name> { ... }`
/// 的完整定义。本类型只承载序列语义，不复制 CSS `var(--fd-motion-effective-*)` 解析逻辑；
/// `duration` 由调用方按 token 传入（参考 `AppMotion.Duration` / `ReaderMotion.Duration`），
/// reduced-motion 归一化由 `MotionEnvironment` 完成。
public struct MotionKeyframeSequence: Sendable, Equatable {
    /// 序列名（与 CSS `@keyframes` 名一致，便于跨端对照）。
    public let name: String
    /// 关键帧样本（按 `time` 升序）。
    public let samples: [MotionKeyframeSample]
    /// 默认时长（秒）。调用方可通过 `MotionEnvironment.duration(_:)` 归一化。
    public let defaultDuration: TimeInterval
    /// 是否循环播放（`voice-pulse` 为 `repeatForever`，其余为单次）。
    public let isRepeating: Bool

    public init(name: String, samples: [MotionKeyframeSample], defaultDuration: TimeInterval, isRepeating: Bool = false) {
        self.name = name
        self.samples = samples.sorted(by: { $0.time < $1.time })
        self.defaultDuration = defaultDuration
        self.isRepeating = isRepeating
    }
}

// MARK: - 14 个 @keyframes 的 Swift adapter

/// demo 14 个 `@keyframes` 的 Swift 适配层。
///
/// 真源：`frontend-demo/motion-tokens.css` 第 613-841 行。
/// 设计原则（clean-room）：
/// - 只承载关键时间点的数值化属性，不复制 CSS 文本 / `var(--*)` / `calc()` 解析逻辑
/// - 时长通过 `AppMotion.Duration` / `ReaderMotion.Duration` token 间接引用，不重复定义
/// - reduced-motion 归一化由调用方结合 `MotionEnvironment` 完成
/// - 多关键帧样本（如 `0%, 100%` 共享属性）按 `MotionKeyframeSample` 数组展开
public enum MotionKeyframe {

    // MARK: - App family

    /// `fd-app-first-open-enter`（demo line 705-714）。
    ///
    /// CSS 语义：`from { opacity: 0; transform: translateY(var(--first-open-y)); }`
    /// `to { opacity: 1; transform: translateY(0); }`
    /// 时长：`app.motion.duration.firstOpen` = 280ms。
    public static let appFirstOpenEnter = MotionKeyframeSequence(
        name: "fd-app-first-open-enter",
        samples: [
            .init(time: 0.0, opacity: 0.0, offsetY: AppMotion.Distance.firstOpenY),
            .init(time: 1.0, opacity: 1.0, offsetY: 0.0)
        ],
        defaultDuration: AppMotion.Duration.firstOpen
    )

    // MARK: - Reader family

    /// `fd-reader-session-capsule-enter`（demo line 694-703）。
    ///
    /// CSS 语义：`from { opacity: 0; transform: translateY(capsule-y) scale(capsule-enter-scale); }`
    /// `to { opacity: 1; transform: translateY(0) scale(1); }`
    /// 时长：`reader.motion.duration.capsuleEnter` = 160ms。
    public static let readerSessionCapsuleEnter = MotionKeyframeSequence(
        name: "fd-reader-session-capsule-enter",
        samples: [
            .init(time: 0.0, opacity: 0.0, offsetY: ReaderMotion.Distance.capsuleY, scale: ReaderMotion.Scale.capsuleEnterStart),
            .init(time: 1.0, opacity: 1.0, offsetY: 0.0, scale: 1.0)
        ],
        defaultDuration: ReaderMotion.Duration.capsuleEnter
    )

    /// `fd-reader-session-capsule-switch`（demo line 784-793）。
    ///
    /// CSS 语义：`0% { opacity: 0.72; transform: scale(0.98); }`
    /// `100% { opacity: 1; transform: scale(1); }`
    /// 时长：`reader.motion.duration.capsuleEnter` = 160ms（switch 复用 enter 时长）。
    public static let readerSessionCapsuleSwitch = MotionKeyframeSequence(
        name: "fd-reader-session-capsule-switch",
        samples: [
            .init(time: 0.0, opacity: 0.72, scale: 0.98),
            .init(time: 1.0, opacity: 1.0, scale: 1.0)
        ],
        defaultDuration: ReaderMotion.Duration.capsuleEnter
    )

    /// `fd-reader-session-capsule-tick`（demo line 795-804）。
    ///
    /// CSS 语义：`0% { opacity: 0; transform: translateY(capsule-tick-y); }`
    /// `100% { opacity: 1; transform: translateY(0); }`
    /// 时长：`reader.motion.duration.capsuleTick` = 120ms。
    public static let readerSessionCapsuleTick = MotionKeyframeSequence(
        name: "fd-reader-session-capsule-tick",
        samples: [
            .init(time: 0.0, opacity: 0.0, offsetY: ReaderMotion.Distance.capsuleTickY),
            .init(time: 1.0, opacity: 1.0, offsetY: 0.0)
        ],
        defaultDuration: ReaderMotion.Duration.capsuleTick
    )

    /// `fd-reader-session-voice-pulse`（demo line 806-815）。
    ///
    /// CSS 语义：`0%, 100% { opacity: 0.82; transform: scale(1); }`
    /// `50% { opacity: 1; transform: scale(voice-pulse-scale); }`
    /// 时长：`reader.motion.duration.voicePulse` = 960ms，`repeatForever` autoreverses。
    public static let readerSessionVoicePulse = MotionKeyframeSequence(
        name: "fd-reader-session-voice-pulse",
        samples: [
            .init(time: 0.0, opacity: 0.82, scale: 1.0),
            .init(time: 0.5, opacity: 1.0, scale: ReaderMotion.Scale.voicePulseMax),
            .init(time: 1.0, opacity: 0.82, scale: 1.0)
        ],
        defaultDuration: ReaderMotion.Duration.voicePulse,
        isRepeating: true
    )

    /// `fd-reader-control-space-enter`（demo line 817-826）。
    ///
    /// CSS 语义：`from { opacity: 0; transform: translateY(-running-space-y) scale(running-space-dock); }`
    /// `to { opacity: 1; transform: translateY(0) scale(1); }`
    /// 时长：`reader.motion.duration.runningSpace` = 180ms。
    public static let readerControlSpaceEnter = MotionKeyframeSequence(
        name: "fd-reader-control-space-enter",
        samples: [
            .init(time: 0.0, opacity: 0.0, offsetY: -ReaderMotion.Distance.runningSpaceY, scale: ReaderMotion.Scale.runningSpaceDockStart),
            .init(time: 1.0, opacity: 1.0, offsetY: 0.0, scale: 1.0)
        ],
        defaultDuration: ReaderMotion.Duration.runningSpace
    )

    /// `fd-reader-control-space-update`（demo line 828-841）。
    ///
    /// CSS 语义：`0% { transform: scale(1); box-shadow: 0 0 0 rgba(47,99,115,0); }`
    /// `55% { transform: scale(0.992); box-shadow: 0 0 0 4px rgba(47,99,115,0.08); }`
    /// `100% { transform: scale(1); box-shadow: 0 0 0 rgba(47,99,115,0); }`
    /// 时长：`reader.motion.duration.runningSpace` = 180ms（update 复用）。
    /// 注：`box-shadow` 在 iOS 端用 `shadow` modifier 表达，本序列只承载 scale。
    public static let readerControlSpaceUpdate = MotionKeyframeSequence(
        name: "fd-reader-control-space-update",
        samples: [
            .init(time: 0.0, scale: 1.0),
            .init(time: 0.55, scale: 0.992),
            .init(time: 1.0, scale: 1.0)
        ],
        defaultDuration: ReaderMotion.Duration.runningSpace
    )

    // MARK: - Overlay family

    /// `fd-motion-overlay-dialog-enter`（demo line 762-771）。
    ///
    /// CSS 语义：`from { opacity: 0; transform: translateY(-44%) scale(dialog-enter-scale); }`
    /// `to { opacity: 1; transform: translateY(-50%) scale(1); }`
    /// 时长：`reader.motion.duration.overlay` = 240ms。
    /// 注：CSS `translateY(-44%)` → `translateY(-50%)` 是相对自身高度的中心对齐微调；
    /// iOS 端用 `offset(y:)` + `scaleEffect` 表达，调用方按容器高度换算 pt 值。
    public static let motionOverlayDialogEnter = MotionKeyframeSequence(
        name: "fd-motion-overlay-dialog-enter",
        samples: [
            .init(time: 0.0, opacity: 0.0, offsetY: -44.0, scale: ReaderMotion.Scale.dialogEnterStart),
            .init(time: 1.0, opacity: 1.0, offsetY: -50.0, scale: 1.0)
        ],
        defaultDuration: ReaderMotion.Duration.overlay
    )

    /// `fd-motion-overlay-sheet-enter`（demo line 773-782）。
    ///
    /// CSS 语义：`from { opacity: 0.72; transform: translateY(14px); }`
    /// `to { opacity: 1; transform: translateY(0); }`
    /// 时长：`reader.motion.duration.overlay` = 240ms。
    public static let motionOverlaySheetEnter = MotionKeyframeSequence(
        name: "fd-motion-overlay-sheet-enter",
        samples: [
            .init(time: 0.0, opacity: 0.72, offsetY: 14.0),
            .init(time: 1.0, opacity: 1.0, offsetY: 0.0)
        ],
        defaultDuration: ReaderMotion.Duration.overlay
    )

    // MARK: - Motion interrupt family

    /// `fd-motion-interrupt-settle`（demo line 742-751）。
    ///
    /// CSS 语义：`from { opacity: 0.96; filter: saturate(0.97); }`
    /// `to { opacity: 1; filter: none; }`
    /// 时长：`reader.motion.duration.interruptSettle` = 80ms。
    /// 注：iOS 端 `filter: saturate(0.97)` 无直接等价；用 opacity 单维度表达。
    public static let motionInterruptSettle = MotionKeyframeSequence(
        name: "fd-motion-interrupt-settle",
        samples: [
            .init(time: 0.0, opacity: 0.96),
            .init(time: 1.0, opacity: 1.0)
        ],
        defaultDuration: ReaderMotion.Duration.interruptSettle
    )

    /// `fd-motion-async-complete`（demo line 753-760）。
    ///
    /// CSS 语义：`from { opacity: 0.96; }` `to { opacity: 1; }`
    /// 时长：`reader.motion.duration.interruptSettle` = 80ms（async-complete 复用 settle）。
    public static let motionAsyncComplete = MotionKeyframeSequence(
        name: "fd-motion-async-complete",
        samples: [
            .init(time: 0.0, opacity: 0.96),
            .init(time: 1.0, opacity: 1.0)
        ],
        defaultDuration: ReaderMotion.Duration.interruptSettle
    )

    // MARK: - Dropdown family

    /// `fd-motion-dropdown-switch-to`（demo line 613-623）。
    ///
    /// CSS 语义：`from { opacity: 0.72; transform: translateY(dropdown-y * 0.5); }`
    /// `to { opacity: 1; transform: translateY(0); }`
    /// 时长：`app.motion.duration.dropdownExpand` = 160ms。
    public static let motionDropdownSwitchTo = MotionKeyframeSequence(
        name: "fd-motion-dropdown-switch-to",
        samples: [
            .init(time: 0.0, opacity: 0.72, offsetY: AppMotion.Distance.dropdownY * 0.5),
            .init(time: 1.0, opacity: 1.0, offsetY: 0.0)
        ],
        defaultDuration: AppMotion.Duration.dropdownExpand
    )

    // MARK: - Viewport family

    /// `fd-viewport-orientation-reshape`（demo line 716-727）。
    ///
    /// CSS 语义：`from { opacity: 0.94; translate: 0 orientation-y; filter: saturate(0.98); }`
    /// `to { opacity: 1; translate: 0 0; filter: none; }`
    /// 时长：`reader.motion.duration.viewportReshape` = 240ms。
    /// 注：iOS 端 `filter: saturate(0.98)` 无直接等价；用 opacity + offset 两维度表达。
    public static let viewportOrientationReshape = MotionKeyframeSequence(
        name: "fd-viewport-orientation-reshape",
        samples: [
            .init(time: 0.0, opacity: 0.94, offsetY: ReaderMotion.Distance.orientationPanelY),
            .init(time: 1.0, opacity: 1.0, offsetY: 0.0)
        ],
        defaultDuration: ReaderMotion.Duration.viewportReshape
    )

    /// `fd-viewport-orientation-anchor-settle`（demo line 729-740）。
    ///
    /// CSS 语义：`from { opacity: 0.92; translate: 0 -orientation-y; filter: saturate(0.96); }`
    /// `to { opacity: 1; translate: 0 0; filter: none; }`
    /// 时长：`reader.motion.duration.orientationSettle` = 240ms。
    public static let viewportOrientationAnchorSettle = MotionKeyframeSequence(
        name: "fd-viewport-orientation-anchor-settle",
        samples: [
            .init(time: 0.0, opacity: 0.92, offsetY: -ReaderMotion.Distance.orientationPanelY),
            .init(time: 1.0, opacity: 1.0, offsetY: 0.0)
        ],
        defaultDuration: ReaderMotion.Duration.orientationSettle
    )
}

// MARK: - Keyframe 播放辅助

extension MotionKeyframeSequence {

    /// 按 reduced-motion 归一化后的时长。
    /// reduced-motion 下返回 0（即时切换），否则返回 `defaultDuration`。
    public func duration(in env: MotionEnvironment) -> TimeInterval {
        return env.duration(defaultDuration)
    }

    /// 构造 SwiftUI `Animation`。
    /// - reduced-motion: 返回 `nil`（即时切换）
    /// - repeating: 用 `easeInOut(duration:).repeatForever(autoreverses:)`
    /// - 单次: 用 `easeInOut(duration:)`
    public func animation(in env: MotionEnvironment) -> Animation? {
        let normalized = env.duration(defaultDuration)
        guard normalized > 0 else { return nil }
        if isRepeating {
            // voice-pulse 在 CSS 中是 `repeatForever` + `alternate`（autoreverses）
            return .easeInOut(duration: normalized).repeatForever(autoreverses: true)
        }
        return .easeInOut(duration: normalized)
    }

    /// 起始样本（time 最小）的 opacity/scale/offset 值，用于 `keyframeAnimator` 的初始状态。
    public var initialSample: MotionKeyframeSample? {
        samples.first
    }

    /// 结束样本（time 最大）的值，用于 `keyframeAnimator` 的终态。
    public var finalSample: MotionKeyframeSample? {
        samples.last
    }
}

// MARK: - if/else transition（motion.interrupt.cancel / redirect / completeThenReplace）

extension AnyTransition {

    /// `motion.interrupt.cancel`：旧视图立即移除（无 removal 动画），
    /// 新视图带 entering 动画进入。
    ///
    /// 真源：`frontend-demo/motion-controller.js` INTERRUPT_MODES `cancel`
    /// （demo line 580-586）—— 立即取消旧动画，跳到 finalState。
    ///
    /// SwiftUI 等价：`.asymmetric(insertion: .opacity, removal: .identity)`。
    /// `removal: .identity` 表示旧视图无动画地消失。
    public static func motionCancel(_ animation: Animation? = .easeInOut(duration: 0.16)) -> AnyTransition {
        .asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .identity)
            .animation(animation)
    }

    /// `motion.interrupt.redirect`：旧动画立即终止（snap 到 finalState），
    /// 新动画从当前位置接管。
    ///
    /// 真源：`frontend-demo/motion-controller.js` INTERRUPT_MODES `redirect`
    /// （demo line 587-593）。
    ///
    /// SwiftUI 等价：`.asymmetric(insertion: .opacity, removal: .opacity.animation(.linear(duration: 0.08)))`。
    /// removal 用 80ms (interruptSettle) 短淡出，避免视觉跳变。
    public static func motionRedirect(
        insertion animation: Animation? = .easeInOut(duration: 0.16),
        removal removalAnimation: Animation? = .linear(duration: 0.08)
    ) -> AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)).animation(animation),
            removal: .opacity.animation(removalAnimation)
        )
    }

    /// `motion.interrupt.completeThenReplace`：等旧动画完成再启动新动画。
    ///
    /// 真源：`frontend-demo/motion-controller.js` INTERRUPT_MODES `completeThenReplace`
    /// （demo line 594-600）。
    ///
    /// SwiftUI 等价：insertion 和 removal 都带动画，SwiftUI 会并行播放
    /// （严格串行需通过 `Task.sleep` + 状态切换手动实现，本 helper 提供并行版本）。
    public static func motionCompleteThenReplace(
        insertion animation: Animation? = .easeInOut(duration: 0.16),
        removal removalAnimation: Animation? = .easeInOut(duration: 0.16)
    ) -> AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)).animation(animation),
            removal: .opacity.animation(removalAnimation)
        )
    }
}

// MARK: - 调用方便利

extension View {

    /// 按 `MotionKeyframeSequence` 的初/末样本对视图做 opacity + offset + scale 插值。
    ///
    /// 调用方通过 `@State var isActive: Bool` 切换；本 modifier 在 `isActive` 变化时
    /// 用 `withAnimation(seq.animation(in:))` 驱动 SwiftUI 重渲染。
    /// 用法：
    /// ```swift
    /// Text("hello")
    ///     .motionKeyframe(MotionKeyframe.appFirstOpenEnter, isActive: appears, env: env)
    /// ```
    public func motionKeyframe(
        _ sequence: MotionKeyframeSequence,
        isActive: Bool,
        env: MotionEnvironment
    ) -> some View {
        let initial = sequence.initialSample
        let final = sequence.finalSample
        let active = isActive ? final : initial
        return self
            .opacity(active?.opacity ?? 1.0)
            .offset(x: active?.offsetX ?? 0, y: active?.offsetY ?? 0)
            .scaleEffect(active?.scale ?? 1.0)
            .animation(sequence.animation(in: env), value: isActive)
    }
}
