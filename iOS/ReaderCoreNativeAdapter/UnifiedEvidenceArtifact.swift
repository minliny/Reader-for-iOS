import Foundation

/// Schema version constant for the unified evidence artifact.
/// All platforms emit this single schema so reports/tooling/ can compare parity.
public let SCHEMA_VERSION = "unified-evidence/1"

/// The 15 canonical capabilities every unified evidence artifact MUST include.
/// Order is informational; the validator only checks set membership.
public let CANONICAL_CAPABILITIES: [String] = [
    "source.import",
    "book.search",
    "book.detail",
    "book.toc",
    "chapter.content",
    "manga.pages.extract",
    "rss.parse",
    "local_book.parse",
    "reading.progress.update",
    "bookmark.crud",
    "tts.queue",
    "http-tts",
    "sync.webdav",
    "runtime.ping",
    "host.request",
]

/// Optional device provenance for the artifact.
public struct DeviceInfo: Codable, Equatable, Sendable {
    public let model: String
    public let osVersion: String
    public let arch: String

    public init(model: String, osVersion: String, arch: String) {
        self.model = model
        self.osVersion = osVersion
        self.arch = arch
    }
}

/// A single capability result row in the artifact.
public struct CapabilityResult: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable {
        case pass
        case fail
        case skipped
        case blocked
    }

    public let capability: String
    public let status: Status
    public let method: String?
    public let durationMs: Int?
    public let redactedEvidence: String?
    public let error: String?
    public let hostRequests: [HostRequestRecord]?

    public init(
        capability: String,
        status: Status,
        method: String? = nil,
        durationMs: Int? = nil,
        redactedEvidence: String? = nil,
        error: String? = nil,
        hostRequests: [HostRequestRecord]? = nil
    ) {
        self.capability = capability
        self.status = status
        self.method = method
        self.durationMs = durationMs
        self.redactedEvidence = redactedEvidence
        self.error = error
        self.hostRequests = hostRequests
    }
}

/// A host request record emitted by Core during a capability run.
public struct HostRequestRecord: Codable, Equatable, Sendable {
    public let capability: String
    public let operationId: Int
    public let completed: Bool

    public init(capability: String, operationId: Int, completed: Bool) {
        self.capability = capability
        self.operationId = operationId
        self.completed = completed
    }
}

/// Aggregate summary over the capabilities array.
public struct EvidenceSummary: Codable, Equatable, Sendable {
    public let total: Int
    public let passed: Int
    public let failed: Int
    public let skipped: Int
    public let passRate: Double

    public init(total: Int, passed: Int, failed: Int, skipped: Int, passRate: Double) {
        self.total = total
        self.passed = passed
        self.failed = failed
        self.skipped = skipped
        self.passRate = passRate
    }
}

/// Optional host request loop evidence (the runtime.hostSmoke → host.request →
/// host.complete → result cycle).
public struct HostRequestLoopEvidence: Codable, Equatable, Sendable {
    public let requestId: Int
    public let capability: String
    public let operationId: Int
    public let resultBookCount: Int
    public let durationMs: Int

    public init(
        requestId: Int,
        capability: String,
        operationId: Int,
        resultBookCount: Int,
        durationMs: Int
    ) {
        self.requestId = requestId
        self.capability = capability
        self.operationId = operationId
        self.resultBookCount = resultBookCount
        self.durationMs = durationMs
    }
}

/// Top-level unified evidence artifact (unified-evidence/1).
///
/// Codable mapping of `protocol/unified-evidence.schema.json`. Optional fields
/// are modelled as Swift optionals; `JSONEncoder` omits nil keys, satisfying the
/// schema's `additionalProperties: false`.
public struct UnifiedEvidenceArtifact: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let platform: String
    public let tier: String
    public let generatedAt: Date
    public let coreCommit: String
    public let hostCommit: String
    public let device: DeviceInfo?
    public let capabilities: [CapabilityResult]
    public let summary: EvidenceSummary
    public let hostRequestLoop: HostRequestLoopEvidence?
    public let notes: [String]

    public init(
        schemaVersion: String = SCHEMA_VERSION,
        platform: String,
        tier: String,
        generatedAt: Date,
        coreCommit: String,
        hostCommit: String,
        device: DeviceInfo? = nil,
        capabilities: [CapabilityResult],
        summary: EvidenceSummary,
        hostRequestLoop: HostRequestLoopEvidence? = nil,
        notes: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.platform = platform
        self.tier = tier
        self.generatedAt = generatedAt
        self.coreCommit = coreCommit
        self.hostCommit = hostCommit
        self.device = device
        self.capabilities = capabilities
        self.summary = summary
        self.hostRequestLoop = hostRequestLoop
        self.notes = notes
    }

    /// Compute the summary from a capabilities list.
    /// `blocked` counts as `skipped`, matching the Python validator semantics
    /// (`status in ("skipped", "blocked")`).
    public static func computeSummary(from capabilities: [CapabilityResult]) -> EvidenceSummary {
        let total = capabilities.count
        let passed = capabilities.filter { $0.status == .pass }.count
        let failed = capabilities.filter { $0.status == .fail }.count
        let skipped = capabilities.filter { $0.status == .skipped || $0.status == .blocked }.count
        let passRate = total > 0 ? Double(passed) / Double(total) : 0.0
        return EvidenceSummary(
            total: total,
            passed: passed,
            failed: failed,
            skipped: skipped,
            passRate: passRate
        )
    }
}

/// Encoder/decoder helpers for the unified evidence artifact.
public enum UnifiedEvidenceArtifactCodec {
    /// Encode an artifact to pretty-printed JSON with sorted keys and ISO 8601 dates.
    public static func encode(_ artifact: UnifiedEvidenceArtifact) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(artifact)
    }

    /// Decode an artifact from JSON.
    public static func decode(_ data: Data) throws -> UnifiedEvidenceArtifact {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UnifiedEvidenceArtifact.self, from: data)
    }
}
