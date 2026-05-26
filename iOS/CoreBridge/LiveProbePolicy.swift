import Foundation

// MARK: - Live Probe Operation

public enum LiveProbeOperation: String, Sendable, CaseIterable {
    case search
    case detail
    case toc
    case content
}

// MARK: - Candidate Risk Level

public enum LiveProbeRiskLevel: String, Sendable, Comparable {
    case low
    case medium
    case high
    case banned

    public static func < (lhs: LiveProbeRiskLevel, rhs: LiveProbeRiskLevel) -> Bool {
        order(lhs) < order(rhs)
    }

    private static func order(_ level: LiveProbeRiskLevel) -> Int {
        switch level {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        case .banned: return 3
        }
    }

    public var canProbe: Bool {
        self == .low
    }
}

// MARK: - Live Probe Candidate

public struct LiveProbeCandidate: Sendable, Equatable {
    public let id: String
    public let name: String
    public let baseURL: String
    public let host: String
    public let riskLevel: LiveProbeRiskLevel
    public let allowedOperations: Set<LiveProbeOperation>
    public let reason: String

    public init(
        id: String,
        name: String,
        baseURL: String,
        host: String,
        riskLevel: LiveProbeRiskLevel,
        allowedOperations: Set<LiveProbeOperation>,
        reason: String
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.host = host
        self.riskLevel = riskLevel
        self.allowedOperations = allowedOperations
        self.reason = reason
    }

    /// 仅 Low risk 候选允许 probe
    public var isProbeAllowed: Bool {
        riskLevel.canProbe && !allowedOperations.isEmpty
    }
}

// MARK: - Live Probe Policy

public struct LiveProbePolicy: Sendable {
    public let debugOnly: Bool
    public let explicitOptInRequired: Bool
    public let snapshotRequired: Bool
    public let fallbackToOfflineReplayRequired: Bool
    public let releaseDisabled: Bool
    public let maxRequestsPerHost: Int
    public let windowSeconds: TimeInterval

    public static let `default` = LiveProbePolicy(
        debugOnly: true,
        explicitOptInRequired: true,
        snapshotRequired: true,
        fallbackToOfflineReplayRequired: true,
        releaseDisabled: true,
        maxRequestsPerHost: 1,
        windowSeconds: 300
    )

    public init(
        debugOnly: Bool,
        explicitOptInRequired: Bool,
        snapshotRequired: Bool,
        fallbackToOfflineReplayRequired: Bool,
        releaseDisabled: Bool,
        maxRequestsPerHost: Int,
        windowSeconds: TimeInterval
    ) {
        self.debugOnly = debugOnly
        self.explicitOptInRequired = explicitOptInRequired
        self.snapshotRequired = snapshotRequired
        self.fallbackToOfflineReplayRequired = fallbackToOfflineReplayRequired
        self.releaseDisabled = releaseDisabled
        self.maxRequestsPerHost = maxRequestsPerHost
        self.windowSeconds = windowSeconds
    }
}

// MARK: - Live Probe Manifest

public struct LiveProbeManifest: Sendable, Equatable {
    public let id: String
    public let candidateId: String
    public let operation: LiveProbeOperation
    public let approvedByUser: Bool
    public let reason: String
    public let expectedSnapshotPath: String
    public let createdAt: Date
    public let host: String

    public init(
        id: String = UUID().uuidString,
        candidateId: String,
        operation: LiveProbeOperation,
        approvedByUser: Bool,
        reason: String,
        expectedSnapshotPath: String,
        createdAt: Date = Date(),
        host: String
    ) {
        self.id = id
        self.candidateId = candidateId
        self.operation = operation
        self.approvedByUser = approvedByUser
        self.reason = reason
        self.expectedSnapshotPath = expectedSnapshotPath
        self.createdAt = createdAt
        self.host = host
    }

    public var isValid: Bool {
        !candidateId.isEmpty
        && !reason.isEmpty
        && !expectedSnapshotPath.isEmpty
        && !host.isEmpty
    }
}

// MARK: - Live Probe Decision

public enum LiveProbeDecision: Equatable, Sendable {
    case allowed
    case denied(reason: String)
}

// MARK: - Live Probe Rate Limiter

public final class LiveProbeRateLimiter: @unchecked Sendable {
    private var lastRequestByHost: [String: Date] = [:]
    private let lock = NSLock()

    public init() {}

    public func recordPlannedRequest(host: String, date: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        lastRequestByHost[host] = date
    }

    public func canRequest(host: String, now: Date = Date(), windowSeconds: TimeInterval) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let last = lastRequestByHost[host] else { return true }
        return now.timeIntervalSince(last) >= windowSeconds
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        lastRequestByHost.removeAll()
    }
}

// MARK: - Live Probe Gate

public struct LiveProbeGate: Sendable {
    public let policy: LiveProbePolicy
    public let rateLimiter: LiveProbeRateLimiter

    public init(policy: LiveProbePolicy = .default, rateLimiter: LiveProbeRateLimiter = LiveProbeRateLimiter()) {
        self.policy = policy
        self.rateLimiter = rateLimiter
    }

    public func evaluate(candidate: LiveProbeCandidate, manifest: LiveProbeManifest, now: Date = Date()) -> LiveProbeDecision {
        // 1. Release build: always denied
        #if !DEBUG
        if policy.releaseDisabled {
            return .denied(reason: "Release 构建永久禁止 live probe")
        }
        #endif

        // 2. Debug-only check
        #if DEBUG
        if policy.debugOnly { /* allowed to continue */ }
        #endif

        // 3. Explicit opt-in required
        if policy.explicitOptInRequired && !manifest.approvedByUser {
            return .denied(reason: "需要用户显式 opt-in 才能执行 live probe")
        }

        // 4. Manifest validity
        if !manifest.isValid {
            return .denied(reason: "Live probe manifest 不完整：缺少 candidateId/reason/snapshotPath/host")
        }

        // 5. Manifest approved
        if !manifest.approvedByUser {
            return .denied(reason: "Manifest 未获用户批准")
        }

        // 6. Reason required
        if manifest.reason.isEmpty {
            return .denied(reason: "缺少 live probe 原因")
        }

        // 7. Snapshot path required
        if policy.snapshotRequired && manifest.expectedSnapshotPath.isEmpty {
            return .denied(reason: "缺少 snapshot 保存路径")
        }

        // 8. Candidate risk level
        if !candidate.isProbeAllowed {
            return .denied(reason: "候选源风险等级不允许 live probe：\(candidate.riskLevel.rawValue)")
        }

        // 9. Candidate allows this operation
        if !candidate.allowedOperations.contains(manifest.operation) {
            return .denied(reason: "候选源不允许此操作：\(manifest.operation.rawValue)")
        }

        // 10. Candidate/Manifest host mismatch
        if candidate.host != manifest.host {
            return .denied(reason: "Manifest host 与候选源 host 不匹配")
        }

        // 11. Rate-limit check
        if !rateLimiter.canRequest(host: manifest.host, now: now, windowSeconds: policy.windowSeconds) {
            return .denied(reason: "速率限制：host '\(manifest.host)' 在 \(Int(policy.windowSeconds))s 窗口内已请求")
        }

        // 12. All checks passed — theoretical allow. Does NOT execute network.
        return .allowed
    }
}
