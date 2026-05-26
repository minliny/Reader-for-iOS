import Foundation

// MARK: - Manual Fetch Request

public struct ManualFetchRequest: Sendable {
    public let id: String
    public let candidate: LiveProbeCandidate
    public let manifest: LiveProbeManifest
    public let expectedSnapshotPath: String
    public let requestedByUser: Bool
    public let dryRunOnly: Bool
    public let reason: String

    public init(
        id: String = UUID().uuidString,
        candidate: LiveProbeCandidate,
        manifest: LiveProbeManifest,
        expectedSnapshotPath: String,
        requestedByUser: Bool = false,
        dryRunOnly: Bool = true,
        reason: String = ""
    ) {
        self.id = id
        self.candidate = candidate
        self.manifest = manifest
        self.expectedSnapshotPath = expectedSnapshotPath
        self.requestedByUser = requestedByUser
        self.dryRunOnly = dryRunOnly
        self.reason = reason
    }
}

// MARK: - Dry Run Result

public struct ManualFetchDryRunResult: Sendable, Equatable {
    public let requestId: String
    public let wouldPassGate: Bool
    public let gateDecision: LiveProbeDecision
    public let wouldWriteSnapshotPath: String?
    public let wouldWriteMetadataPath: String?
    public let wouldRecordAudit: Bool
    public let networkExecuted: Bool

    public static func denied(requestId: String, reason: String, gateDecision: LiveProbeDecision) -> ManualFetchDryRunResult {
        ManualFetchDryRunResult(
            requestId: requestId,
            wouldPassGate: false,
            gateDecision: gateDecision,
            wouldWriteSnapshotPath: nil,
            wouldWriteMetadataPath: nil,
            wouldRecordAudit: true,
            networkExecuted: false
        )
    }

    public static func allowed(requestId: String, snapshotPath: String, metadataPath: String) -> ManualFetchDryRunResult {
        ManualFetchDryRunResult(
            requestId: requestId,
            wouldPassGate: true,
            gateDecision: .allowed,
            wouldWriteSnapshotPath: snapshotPath,
            wouldWriteMetadataPath: metadataPath,
            wouldRecordAudit: true,
            networkExecuted: false
        )
    }
}

// MARK: - Snapshot Metadata

public struct SnapshotMetadata: Sendable, Codable, Equatable {
    public let snapshotId: String
    public let candidateId: String
    public let operation: String
    public let host: String
    public let requestedAtText: String
    public let reason: String
    public let sourceDescription: String
    public let contentTypeExpected: String
    public let isPlaceholder: Bool
    public let networkExecuted: Bool
    public let fallbackReplayScenario: String

    public init(
        snapshotId: String = UUID().uuidString,
        candidateId: String,
        operation: String,
        host: String,
        reason: String,
        sourceDescription: String = "Manual fetch not yet executed",
        contentTypeExpected: String = "application/json",
        isPlaceholder: Bool = true,
        networkExecuted: Bool = false,
        fallbackReplayScenario: String = "OfflineReplayFixtures"
    ) {
        self.snapshotId = snapshotId
        self.candidateId = candidateId
        self.operation = operation
        self.host = host
        self.requestedAtText = ISO8601DateFormatter().string(from: Date())
        self.reason = reason
        self.sourceDescription = sourceDescription
        self.contentTypeExpected = contentTypeExpected
        self.isPlaceholder = isPlaceholder
        self.networkExecuted = networkExecuted
        self.fallbackReplayScenario = fallbackReplayScenario
    }
}

// MARK: - Audit Record

public struct LiveProbeAuditRecord: Sendable, Codable, Equatable {
    public let requestId: String
    public let candidateId: String
    public let operation: String
    public let decision: String
    public let deniedReason: String?
    public let dryRunOnly: Bool
    public let networkExecuted: Bool
    public let snapshotPath: String?
    public let createdAtText: String

    public init(
        requestId: String,
        candidateId: String,
        operation: String,
        decision: String,
        deniedReason: String? = nil,
        dryRunOnly: Bool = true,
        networkExecuted: Bool = false,
        snapshotPath: String? = nil
    ) {
        self.requestId = requestId
        self.candidateId = candidateId
        self.operation = operation
        self.decision = decision
        self.deniedReason = deniedReason
        self.dryRunOnly = dryRunOnly
        self.networkExecuted = networkExecuted
        self.snapshotPath = snapshotPath
        self.createdAtText = ISO8601DateFormatter().string(from: Date())
    }
}

// MARK: - Manual Live Probe Executor

public struct ManualLiveProbeExecutor: Sendable {
    public let gate: LiveProbeGate
    public let snapshotStore: SnapshotStore

    public init(gate: LiveProbeGate = LiveProbeGate(), snapshotStore: SnapshotStore) {
        self.gate = gate
        self.snapshotStore = snapshotStore
    }

    // MARK: - Prepare

    public func prepare(request: ManualFetchRequest) -> Result<ManualFetchDryRunResult, Error> {
        // Validate manifest
        guard request.manifest.isValid else {
            return .success(.denied(requestId: request.id, reason: "manifest invalid", gateDecision: .denied(reason: "manifest invalid")))
        }

        // Validate snapshot path safety
        guard snapshotStore.validatePathInsideSnapshotRoot(request.expectedSnapshotPath) else {
            return .success(.denied(requestId: request.id, reason: "snapshot path traversal denied", gateDecision: .denied(reason: "path unsafe")))
        }

        // Gate evaluation
        let decision = gate.evaluate(candidate: request.candidate, manifest: request.manifest)

        guard case .allowed = decision else {
            let reason: String
            if case .denied(let r) = decision { reason = r } else { reason = "unknown" }
            return .success(.denied(requestId: request.id, reason: reason, gateDecision: decision))
        }

        let metaPath = snapshotStore.metadataPath(for: request.expectedSnapshotPath)
        return .success(.allowed(requestId: request.id, snapshotPath: request.expectedSnapshotPath, metadataPath: metaPath))
    }

    // MARK: - Dry Run

    public func dryRun(request: ManualFetchRequest) -> ManualFetchDryRunResult {
        switch prepare(request: request) {
        case .success(let result):
            return result
        case .failure:
            return .denied(requestId: request.id, reason: "prepare failed", gateDecision: .denied(reason: "error"))
        }
    }

    // MARK: - Execute (always denied — Phase 4D-next does not allow real fetch)

    public func execute(request: ManualFetchRequest) -> Result<LiveProbeAuditRecord, Error> {
        let result = dryRun(request: request)

        let audit = LiveProbeAuditRecord(
            requestId: request.id,
            candidateId: request.candidate.id,
            operation: request.manifest.operation.rawValue,
            decision: result.wouldPassGate ? "denied_by_executor" : "denied_by_gate",
            deniedReason: result.wouldPassGate
                ? "Phase 4D-next 不允许真实 fetch。需用户明确授权。"
                : "gate denied: \(result.gateDecision)",
            dryRunOnly: true,
            networkExecuted: false,
            snapshotPath: nil
        )

        return .failure(ManualExecutorError.fetchNotAllowedInPhase4DNext(audit))
    }

    // MARK: - Validation

    public func validateNoNetwork() -> Bool {
        // Always true in Phase 4D-next — executor never uses network
        true
    }
}

public enum ManualExecutorError: Error, LocalizedError {
    case fetchNotAllowedInPhase4DNext(LiveProbeAuditRecord)

    public var errorDescription: String? {
        switch self {
        case .fetchNotAllowedInPhase4DNext(let audit):
            return "Phase 4D-next 不允许真实 fetch：\(audit.decision) — \(audit.deniedReason ?? "无原因")"
        }
    }

    public var auditRecord: LiveProbeAuditRecord {
        switch self {
        case .fetchNotAllowedInPhase4DNext(let record): return record
        }
    }
}
