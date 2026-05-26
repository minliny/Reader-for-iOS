import Foundation

// MARK: - Real Network Mode

/// 真实网络接入模式。
/// 默认 `.disabled` — 不允许任何真实网络请求。
/// Debug 下也默认 `.disabled`，需显式 opt-in 到 `.debugOptIn`。
/// `.liveProbePlanned` 为 Phase 4C/D 预留，当前不执行任何 live 请求。
public enum RealNetworkMode: Sendable, Equatable {
    /// 完全禁止真实网络
    case disabled
    /// Debug-only 手动 opt-in（需显式开启，Release 不可达）
    case debugOptIn
    /// Live probe 已规划但尚未执行（Phase 4C/D 预留）
    case liveProbePlanned
}

// MARK: - Real Network Policy

/// 真实网络接入策略 — 全局单例，默认 disabled
public struct RealNetworkPolicy: Sendable {
    public var mode: RealNetworkMode
    public var lastChangedAt: Date
    public var changedBy: String

    public static let `default` = RealNetworkPolicy(
        mode: .disabled,
        lastChangedAt: Date(),
        changedBy: "system"
    )

    /// 是否允许任何真实网络请求
    public var isNetworkAllowed: Bool {
        switch mode {
        case .disabled, .liveProbePlanned:
            return false
        case .debugOptIn:
            #if DEBUG
            return true
            #else
            return false
            #endif
        }
    }

    /// 拒绝原因（用于日志和 UI 提示）
    public var denialReason: String? {
        if isNetworkAllowed { return nil }
        switch mode {
        case .disabled:
            return "真实网络已禁用（默认策略）"
        case .debugOptIn:
            return "真实网络仅在 Debug 构建中可用"
        case .liveProbePlanned:
            return "Live probe 已规划但尚未执行"
        }
    }

    public var requiresExplicitUserAction: Bool {
        mode != .disabled
    }

    public var isDebugOnly: Bool {
        switch mode {
        case .debugOptIn: return true
        case .disabled, .liveProbePlanned: return false
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

/// 默认 RealNetworkGate 实现 — 仅允许 debugOptIn + DEBUG 构建
public struct DefaultRealNetworkGate: RealNetworkGate, Sendable {
    public init() {}

    public func evaluate(_ policy: RealNetworkPolicy) -> RealNetworkGateDecision {
        #if DEBUG
        if policy.mode == .debugOptIn {
            return .allowed
        }
        return .denied(reason: policy.denialReason ?? "真实网络未启用")
        #else
        return .denied(reason: "真实网络在 Release 构建中永久禁用")
        #endif
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

    /// 仅允许在 DEBUG 下修改为 debugOptIn；Release 下忽略
    public func setMode(_ mode: RealNetworkMode, changedBy: String = "system") {
        #if DEBUG
        lock.lock()
        policy = RealNetworkPolicy(mode: mode, lastChangedAt: Date(), changedBy: changedBy)
        lock.unlock()
        #else
        // Release build: silently ignore — policy stays .disabled
        _ = mode
        _ = changedBy
        #endif
    }

    public func reset() {
        lock.lock()
        policy = .default
        lock.unlock()
    }
}
