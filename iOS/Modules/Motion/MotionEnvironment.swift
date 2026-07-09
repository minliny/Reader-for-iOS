import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Reduced-motion 平台适配器。
///
/// 真源：Reader UI `frontend-demo-optimized/MOTION_CONTRACT.md` §7 Reduced Motion 契约
/// 平台映射：`docs/ui-handoff/MOTION_PLATFORM_MAPPING.md` iOS SwiftUI Guardrails
///
/// 规则：
/// - 系统开启 reduced motion 时，时长降为 `instant`，或最多 80ms（`micro`）。
/// - 位移距离降为 0。
/// - 必要反馈通过颜色/透明度/选中态/内容替换保留。
///
/// 本类型不复制 Web CSS；它把契约 reduced-motion 语义映射到
/// `UIAccessibility.isReduceMotionEnabled`（iOS）/ 等价系统状态。
///
/// 实现为 `ObservableObject`（不标记 `@MainActor`），允许 `init(override:)` 从
/// 任意上下文构造（如 SwiftUI `MotionEnvironment()` 默认值、`AppNavigationState`
/// 的 `@Published` 默认值、`static let shared`）。`@Published` 属性因此为 nonisolated，
/// init 阶段无观察者，构造期写入安全。运行期 mutation 仅在 `refreshFromSystem()`
/// （`@MainActor`）发生，由 UI 生命周期驱动；读取侧（`duration`/`distance`/`animation`）
/// 是纯函数，可在任意上下文调用。
public final class MotionEnvironment: ObservableObject {

    /// 是否启用 reduced motion。`@Published` 以便 View 观察系统设置变化。
    @Published public private(set) var isReducedMotionEnabled: Bool

    /// 测试 / debug override。`nil` 表示读系统真实值。非 Published（内部状态）。
    private var override: Bool?

    /// nonisolated：仅设置存储属性，无 UI 交互，允许从任意上下文构造
    /// （如 `DemoLoadingSpinner` 的 default value、`AppNavigationState` 的 `@Published` 初始值）。
    /// `@Published` 在 init 阶段尚无观察者，写入安全。
    public init(override: Bool? = nil) {
        self.override = override
        if let override {
            self.isReducedMotionEnabled = override
        } else {
            self.isReducedMotionEnabled = MotionEnvironment.systemIsReduceMotionEnabled()
        }
    }

    /// 从 `UIAccessibility.isReduceMotionEnabled` 重新读取并更新。
    /// `@MainActor`：mutation 由 UI 生命周期触发（onAppear / scenePhase 切换），
    /// 强制主 actor 确保 SwiftUI 观察者收到一致的状态。
    /// `override` 非 `nil` 时跳过（测试场景以 override 为准）。
    @MainActor public func refreshFromSystem() {
        guard override == nil else { return }
        isReducedMotionEnabled = MotionEnvironment.systemIsReduceMotionEnabled()
    }

    /// 读取系统真实 reduced-motion 状态。
    /// `nonisolated`：`UIAccessibility.isReduceMotionEnabled` 是线程安全只读属性，
    /// 允许在任意上下文调用（保留原 struct 版本的调用兼容性）。
    public nonisolated static func systemIsReduceMotionEnabled() -> Bool {
        #if canImport(UIKit)
        return UIAccessibility.isReduceMotionEnabled
        #else
        return false
        #endif
    }

    /// 把契约时长按 reduced-motion 规则归一化：
    /// reduced motion 下返回 `instant`（0）或最多 `micro`（80ms）。
    public func duration(_ seconds: TimeInterval) -> TimeInterval {
        guard seconds > 0 else { return 0 }
        if isReducedMotionEnabled {
            // 契约：时长降为 instant，或最多 80ms（micro）。
            return min(seconds, ReaderMotion.Duration.micro)
        }
        return seconds
    }

    /// 把契约位移按 reduced-motion 规则归一化：
    /// reduced motion 下位移降为 0。
    public func distance(_ points: CGFloat) -> CGFloat {
        if isReducedMotionEnabled { return 0 }
        return points
    }

    /// 用归一化时长构造 `Animation`；reduced motion 下返回 `nil`（即时切换）。
    public func animation(_ seconds: TimeInterval) -> Animation? {
        let normalized = duration(seconds)
        guard normalized > 0 else { return nil }
        return .easeInOut(duration: normalized)
    }

    /// 在给定闭包里应用动效：reduced motion 下不包 `withAnimation`（即时），
    /// 否则用归一化时长驱动 `withAnimation`。对应 `motion.interrupt.cancel` ——
    /// 以最新 state 驱动，旧动画不排队。
    public func withMotionAnimation<R>(_ seconds: TimeInterval, _ body: () throws -> R) rethrows -> R {
        if let animation = animation(seconds) {
            return try withAnimation(animation, body)
        } else {
            return try body()
        }
    }

    /// 单例。用于无注入场景的全局访问。
    public static let shared: MotionEnvironment = MotionEnvironment()
}
