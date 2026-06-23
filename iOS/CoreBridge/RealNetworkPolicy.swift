import Foundation

// MARK: - Real Network Mode

/// 真实网络接入模式。
/// 默认 `.unrestricted` — 本地调试期间不再阻断真实网络请求。
public enum RealNetworkMode: Sendable, Equatable {
    /// 不限制真实网络
    case unrestricted
    /// 完全禁止真实网络
    case disabled
    /// 手动 opt-in，当前不再限制在 Debug 构建
    case debugOptIn
    /// Live probe 已规划，当前也允许执行
    case liveProbePlanned
}

// MARK: - Real Network Policy

/// 真实网络接入策略 — 全局单例，默认 unrestricted
public struct RealNetworkPolicy: Sendable {
    public var mode: RealNetworkMode
    public var lastChangedAt: Date
    public var changedBy: String

    public static let `default` = RealNetworkPolicy(
        mode: .unrestricted,
        lastChangedAt: Date(),
        changedBy: "system"
    )

    /// 是否允许任何真实网络请求
    public var isNetworkAllowed: Bool {
        switch mode {
        case .unrestricted, .debugOptIn, .liveProbePlanned:
            return true
        case .disabled:
            return false
        }
    }

    /// 拒绝原因（用于日志和 UI 提示）
    public var denialReason: String? {
        if isNetworkAllowed { return nil }
        switch mode {
        case .unrestricted:
            return nil
        case .disabled:
            return "真实网络已禁用（默认策略）"
        case .debugOptIn:
            return nil
        case .liveProbePlanned:
            return nil
        }
    }

    public var requiresExplicitUserAction: Bool {
        false
    }

    public var isDebugOnly: Bool {
        switch mode {
        case .unrestricted, .disabled, .debugOptIn, .liveProbePlanned:
            return false
        }
    }
}

// MARK: - Real Network Gate

public enum RealNetworkGateDecision: Equatable, Sendable {
    case allowed
    case denied(reason: String)
}

public protocol RealNetworkGate: Sendable {
    func evaluate(_ policy: RealNetworkPolicy) -> RealNetworkGateDecision
}

/// 默认 RealNetworkGate 实现 — 本地 unrestricted 模式下不再阻断网络。
public struct DefaultRealNetworkGate: RealNetworkGate, Sendable {
    public init() {}

    public func evaluate(_ policy: RealNetworkPolicy) -> RealNetworkGateDecision {
        .allowed
    }
}

// MARK: - Global Policy Store

/// 线程安全的全局 RealNetworkPolicy 持有者
@MainActor
public final class RealNetworkPolicyStore: @unchecked Sendable {
    public static let shared = RealNetworkPolicyStore()

    private var policy: RealNetworkPolicy = .default
    private let lock = NSLock()

    public var current: RealNetworkPolicy {
        lock.lock()
        defer { lock.unlock() }
        return policy
    }

    /// 本地 unrestricted 模式下允许在任意构建配置修改网络模式。
    public func setMode(_ mode: RealNetworkMode, changedBy: String = "system") {
        lock.lock()
        policy = RealNetworkPolicy(mode: mode, lastChangedAt: Date(), changedBy: changedBy)
        lock.unlock()
    }

    public func reset() {
        lock.lock()
        policy = .default
        lock.unlock()
    }
}
