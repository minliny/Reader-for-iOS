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

    /// 本地 unrestricted 默认 — 不再阻断联网。
    public static let safeDefault = UserNetworkPreference(
        allowNetworkAccess: true,
        allowCellular: true,
        preferOfflineReplay: false,
        cacheFirst: false,
        auditEnabled: true,
        maxRequestsPerHost: 3,
        cooldownSeconds: 0
    )

    /// 产品联网默认 — 本地 unrestricted 模式下直接联网
    public static let productDefault = UserNetworkPreference(
        allowNetworkAccess: true,
        allowCellular: true,
        preferOfflineReplay: false,
        cacheFirst: false,
        auditEnabled: true,
        maxRequestsPerHost: 3,
        cooldownSeconds: 0
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
            cooldownSeconds: 0, lastRequestAt: nil, riskLevel: .low
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

        rateLimiter.recordPlannedRequest(host: sourcePolicy.host, date: now)

        let audit = NetworkAuditEntry(
            sourceId: sourcePolicy.sourceId,
            operation: operation.rawValue,
            host: sourcePolicy.host,
            decision: "allowed",
            networkTriggered: true
        )

        return .allowed(reason: "网络限制已解除：允许执行", audit: audit)
    }

    // Simple convenience overload using RateLimiter defaults
    public func canRequest(host: String) -> Bool {
        rateLimiter.canRequest(host: host, windowSeconds: 5)
    }
}
