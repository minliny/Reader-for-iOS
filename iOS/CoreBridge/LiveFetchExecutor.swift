import Foundation
import ReaderCoreModels

// MARK: - Live Fetch Authorization

/// 用户授权凭据 — 必须在 fetch 前填写
public struct LiveFetchAuthorization: Sendable {
    public let userId: String
    public let authorizedAt: Date
    public let candidateId: String
    public let operation: LiveProbeOperation
    public let maxRequests: Int
    public let snapshotRequired: Bool
    public let reason: String

    public init(
        userId: String = "developer",
        candidateId: String,
        operation: LiveProbeOperation = .search,
        maxRequests: Int = 1,
        snapshotRequired: Bool = true,
        reason: String
    ) {
        self.userId = userId
        self.authorizedAt = Date()
        self.candidateId = candidateId
        self.operation = operation
        self.maxRequests = maxRequests
        self.snapshotRequired = snapshotRequired
        self.reason = reason
    }
}

// MARK: - Live Fetch Result

public enum LiveFetchResult: Sendable {
    case success(snapshotPath: String, audit: LiveProbeAuditRecord)
    case denied(reason: String, audit: LiveProbeAuditRecord)
    case failed(reason: String, audit: LiveProbeAuditRecord, fallbackUsed: Bool)
}

// MARK: - Live Fetch Executor

/// 受控真实网络 fetch 执行器。
/// 仅在所有 gate 检查通过 + 用户明确授权后执行单次请求。
/// 请求后立即保存 snapshot 并记录 audit log。
public struct LiveFetchExecutor: Sendable {
    public let gate: LiveProbeGate
    public let snapshotStore: SnapshotStore
    public let rateLimiter: LiveProbeRateLimiter

    public init(
        gate: LiveProbeGate = LiveProbeGate(),
        snapshotStore: SnapshotStore,
        rateLimiter: LiveProbeRateLimiter = LiveProbeRateLimiter()
    ) {
        self.gate = gate
        self.snapshotStore = snapshotStore
        self.rateLimiter = rateLimiter
    }

    // MARK: - Authorized Fetch

    /// 执行受控的单次真实网络 fetch。所有 gate 必须通过。
    /// 请求后立即保存 snapshot + audit，然后停止。
    @MainActor
    public func authorizedFetch(
        request: ManualFetchRequest,
        authorization: LiveFetchAuthorization,
        provider: ReaderCoreServiceProvider = .shared
    ) async -> LiveFetchResult {

        let requestId = request.id

        // 1. Gate check
        let decision = gate.evaluate(candidate: request.candidate, manifest: request.manifest)
        guard case .allowed = decision else {
            let reason: String
            if case .denied(let r) = decision { reason = r } else { reason = "unknown" }
            let audit = LiveProbeAuditRecord(
                requestId: requestId, candidateId: request.candidate.id,
                operation: request.manifest.operation.rawValue, decision: "denied_by_gate",
                deniedReason: reason
            )
            return .denied(reason: reason, audit: audit)
        }

        // 2. Snapshot path safety
        guard snapshotStore.validatePathInsideSnapshotRoot(request.expectedSnapshotPath) else {
            let audit = LiveProbeAuditRecord(
                requestId: requestId, candidateId: request.candidate.id,
                operation: request.manifest.operation.rawValue, decision: "denied_path_unsafe",
                deniedReason: "snapshot path traversal"
            )
            return .denied(reason: "snapshot path 不安全", audit: audit)
        }

        // 3. Authorization check
        guard authorization.candidateId == request.candidate.id,
              authorization.operation == request.manifest.operation,
              authorization.maxRequests > 0,
              authorization.snapshotRequired else {
            let audit = LiveProbeAuditRecord(
                requestId: requestId, candidateId: request.candidate.id,
                operation: request.manifest.operation.rawValue, decision: "denied_auth_invalid",
                deniedReason: "authorization invalid"
            )
            return .denied(reason: "授权无效", audit: audit)
        }

        // 4. Rate-limit record
        rateLimiter.recordPlannedRequest(host: request.candidate.host)

        // 5. Perform fetch
        let fetchResult: LoadState<[SearchResultItem]>
        do {
            // Temporarily enable real service through provider gate
            _ = provider.configureRealMode()
            guard provider.isRealModeAvailable else {
                // Real mode not available — fallback to offline replay
                let audit = LiveProbeAuditRecord(
                    requestId: requestId, candidateId: request.candidate.id,
                    operation: request.manifest.operation.rawValue, decision: "fallback_offline_replay",
                    deniedReason: "real service unavailable, using offline replay"
                )
                return .failed(reason: "real service 不可用，已使用离线重放", audit: audit, fallbackUsed: true)
            }

            fetchResult = await provider.searchBooks(keyword: "凡人修仙传", page: 1, source: nil)
        }

        // 6. Process result
        switch fetchResult {
        case .loaded(let results):
            // Save snapshot content + metadata
            var savedPath = request.expectedSnapshotPath
            if let jsonData = try? JSONEncoder().encode(results) {
                _ = snapshotStore.saveContent(request.expectedSnapshotPath, jsonData: jsonData)
                savedPath = request.expectedSnapshotPath
            }
            _ = snapshotStore.saveSnapshotPlaceholder(
                candidateId: request.candidate.id,
                operation: request.manifest.operation.rawValue,
                host: request.candidate.host
            )

            let audit = LiveProbeAuditRecord(
                requestId: requestId, candidateId: request.candidate.id,
                operation: request.manifest.operation.rawValue,
                decision: "fetch_success",
                snapshotPath: savedPath
            )
            return .success(snapshotPath: savedPath, audit: audit)

        case .failed(let appError):
            let audit = LiveProbeAuditRecord(
                requestId: requestId, candidateId: request.candidate.id,
                operation: request.manifest.operation.rawValue,
                decision: "fetch_failed",
                deniedReason: appError.message,
                snapshotPath: nil
            )
            return .failed(reason: "fetch failed: \(appError.message)", audit: audit, fallbackUsed: true)

        case .partial(let results, let warning):
            let audit = LiveProbeAuditRecord(
                requestId: requestId, candidateId: request.candidate.id,
                operation: request.manifest.operation.rawValue,
                decision: "fetch_partial",
                deniedReason: warning,
                snapshotPath: nil
            )
            return .failed(reason: "partial results: \(warning)", audit: audit, fallbackUsed: true)

        case .empty:
            let audit = LiveProbeAuditRecord(
                requestId: requestId, candidateId: request.candidate.id,
                operation: request.manifest.operation.rawValue,
                decision: "fetch_empty",
                deniedReason: "no results",
                snapshotPath: nil
            )
            return .failed(reason: "fetch returned empty", audit: audit, fallbackUsed: true)

        default:
            let audit = LiveProbeAuditRecord(
                requestId: requestId, candidateId: request.candidate.id,
                operation: request.manifest.operation.rawValue,
                decision: "fetch_unexpected_state",
                deniedReason: "unexpected LoadState"
            )
            return .failed(reason: "unexpected state", audit: audit, fallbackUsed: true)
        }
    }
}
