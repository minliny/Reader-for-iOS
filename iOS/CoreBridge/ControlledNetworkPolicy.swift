import Foundation

// MARK: - Controlled Network Operation

public enum ControlledNetworkOperation: String, Sendable, CaseIterable {
    case search
    case detail
    case toc
    case content
}

// MARK: - User Network Preference

public struct UserNetworkPreference: Sendable, Equatable {
    public var allowNetworkAccess: Bool
    public var allowCellular: Bool
    public var preferOfflineReplay: Bool
    public var cacheFirst: Bool
    public var auditEnabled: Bool
    public var maxRequestsPerHost: Int
    public var cooldownSeconds: Int

    /// 测试/CI 安全默认 — 不联网
    public static let safeDefault = UserNetworkPreference(
        allowNetworkAccess: false,
        allowCellular: false,
        preferOfflineReplay: true,
        cacheFirst: true,
        auditEnabled: true,
        maxRequestsPerHost: 3,
        cooldownSeconds: 5
    )

    /// 产品联网默认 — 用户显式开启后使用
    public static let productDefault = UserNetworkPreference(
        allowNetworkAccess: true,
        allowCellular: true,
        preferOfflineReplay: false,
        cacheFirst: true,
        auditEnabled: true,
        maxRequestsPerHost: 3,
        cooldownSeconds: 5
    )

    public init(
        allowNetworkAccess: Bool,
        allowCellular: Bool,
        preferOfflineReplay: Bool,
        cacheFirst: Bool,
        auditEnabled: Bool,
        maxRequestsPerHost: Int,
        cooldownSeconds: Int
    ) {
        self.allowNetworkAccess = allowNetworkAccess
        self.allowCellular = allowCellular
        self.preferOfflineReplay = preferOfflineReplay
        self.cacheFirst = cacheFirst
        self.auditEnabled = auditEnabled
        self.maxRequestsPerHost = maxRequestsPerHost
        self.cooldownSeconds = cooldownSeconds
    }
}

// MARK: - Source Network Policy

public struct SourceNetworkPolicy: Sendable, Equatable {
    public let sourceId: String
    public let sourceName: String
    public let host: String
    public var isEnabled: Bool
    public var allowSearch: Bool
    public var allowDetail: Bool
    public var allowTOC: Bool
    public var allowContent: Bool
    public var cooldownSeconds: Int
    public var lastRequestAt: Date?
    public var riskLevel: LiveProbeRiskLevel

    public static func fixture(id: String = "s001", name: String = "Fixture Source", host: String = "example.com") -> SourceNetworkPolicy {
        SourceNetworkPolicy(
            sourceId: id, sourceName: name, host: host,
            isEnabled: true, allowSearch: true, allowDetail: true, allowTOC: true, allowContent: true,
            cooldownSeconds: 5, lastRequestAt: nil, riskLevel: .low
        )
    }

    /// M1 候选源：星星小说网 — 真实搜索 MVP
    public static let m1Candidate = SourceNetworkPolicy(
        sourceId: "candidate-xingxingxsw",
        sourceName: "星星小说网",
        host: "www.xingxingxsw.com",
        isEnabled: true,
        allowSearch: true,
        allowDetail: true,
        allowTOC: true,
        allowContent: true,
        cooldownSeconds: 10,
        lastRequestAt: nil,
        riskLevel: .low
    )

    public init(
        sourceId: String, sourceName: String, host: String,
        isEnabled: Bool, allowSearch: Bool, allowDetail: Bool, allowTOC: Bool, allowContent: Bool,
        cooldownSeconds: Int, lastRequestAt: Date?, riskLevel: LiveProbeRiskLevel
    ) {
        self.sourceId = sourceId
        self.sourceName = sourceName
        self.host = host
        self.isEnabled = isEnabled
        self.allowSearch = allowSearch
        self.allowDetail = allowDetail
        self.allowTOC = allowTOC
        self.allowContent = allowContent
        self.cooldownSeconds = cooldownSeconds
        self.lastRequestAt = lastRequestAt
        self.riskLevel = riskLevel
    }

    public func allows(_ operation: ControlledNetworkOperation) -> Bool {
        switch operation {
        case .search: return allowSearch
        case .detail: return allowDetail
        case .toc: return allowTOC
        case .content: return allowContent
        }
    }
}

// MARK: - Controlled Network Decision

public enum ControlledNetworkDecision: Equatable, Sendable {
    case allowed(reason: String, audit: NetworkAuditEntry)
    case denied(reason: String, fallback: NetworkFallback)
    case fallbackToCache(reason: String, audit: NetworkAuditEntry)
}

public enum NetworkFallback: Sendable, Equatable {
    case offlineReplay
    case mock
    case cachedSnapshot
    case empty
    case error(String)
}

// MARK: - Network Audit Entry

public struct NetworkAuditEntry: Sendable, Equatable {
    public let sourceId: String
    public let operation: String
    public let host: String
    public let decision: String
    public let timestamp: Date
    public let cacheHit: Bool
    public let networkTriggered: Bool

    public init(
        sourceId: String, operation: String, host: String,
        decision: String, timestamp: Date = Date(),
        cacheHit: Bool = false, networkTriggered: Bool = false
    ) {
        self.sourceId = sourceId
        self.operation = operation
        self.host = host
        self.decision = decision
        self.timestamp = timestamp
        self.cacheHit = cacheHit
        self.networkTriggered = networkTriggered
    }
}

// MARK: - Network Access Controller

public struct NetworkAccessController: Sendable {
    public let rateLimiter: LiveProbeRateLimiter

    public init(rateLimiter: LiveProbeRateLimiter = LiveProbeRateLimiter()) {
        self.rateLimiter = rateLimiter
    }

    public func evaluate(
        userPreference: UserNetworkPreference,
        sourcePolicy: SourceNetworkPolicy,
        operation: ControlledNetworkOperation,
        now: Date = Date()
    ) -> ControlledNetworkDecision {

        let auditBase = NetworkAuditEntry(
            sourceId: sourcePolicy.sourceId,
            operation: operation.rawValue,
            host: sourcePolicy.host,
            decision: "pending"
        )

        // 1. User allows network?
        if !userPreference.allowNetworkAccess {
            return .denied(
                reason: "用户未开启网络访问",
                fallback: userPreference.preferOfflineReplay ? .offlineReplay : .mock
            )
        }

        // 2. Source enabled?
        if !sourcePolicy.isEnabled {
            return .denied(
                reason: "书源未启用",
                fallback: .offlineReplay
            )
        }

        // 3. Operation allowed?
        if !sourcePolicy.allows(operation) {
            return .denied(
                reason: "书源不允许此操作：\(operation.rawValue)",
                fallback: .offlineReplay
            )
        }

        // 4. Cache-first preference?
        if userPreference.cacheFirst {
            return .fallbackToCache(
                reason: "缓存优先策略",
                audit: NetworkAuditEntry(
                    sourceId: sourcePolicy.sourceId,
                    operation: operation.rawValue,
                    host: sourcePolicy.host,
                    decision: "cache_first",
                    cacheHit: true
                )
            )
        }

        // 5. Prefer offline replay?
        if userPreference.preferOfflineReplay {
            return .denied(
                reason: "用户偏好离线回放",
                fallback: .offlineReplay
            )
        }

        // 6. Rate-limit?
        if !rateLimiter.canRequest(host: sourcePolicy.host, now: now, windowSeconds: TimeInterval(sourcePolicy.cooldownSeconds)) {
            return .denied(
                reason: "冷却中：host '\(sourcePolicy.host)' 在 \(sourcePolicy.cooldownSeconds)s 窗口内已请求",
                fallback: .cachedSnapshot
            )
        }

        // 7. Record planned request
        rateLimiter.recordPlannedRequest(host: sourcePolicy.host, date: now)

        // 8. All checks passed
        let audit = NetworkAuditEntry(
            sourceId: sourcePolicy.sourceId,
            operation: operation.rawValue,
            host: sourcePolicy.host,
            decision: "allowed",
            networkTriggered: true
        )

        if userPreference.auditEnabled {
            return .allowed(reason: "受控网络访问已授权", audit: audit)
        } else {
            return .denied(reason: "审计未启用", fallback: .error("audit required"))
        }
    }

    // Simple convenience overload using RateLimiter defaults
    public func canRequest(host: String) -> Bool {
        rateLimiter.canRequest(host: host, windowSeconds: 5)
    }
}
