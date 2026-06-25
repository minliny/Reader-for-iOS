import Foundation

// MARK: - Operator Approval Capability

/// Capabilities that require explicit operator approval before the iOS host
/// may execute them. Login/session-cookie flows are the first gated capability.
public enum OperatorApprovalCapability: String, Codable, Sendable {
    case sessionCookieLogin = "session_cookie_login"
}

// MARK: - Operator Approval Packet

/// A redacted, operator-issued approval packet that authorizes a single
/// (host, capability) pair for a bounded window. The packet never carries raw
/// credentials, cookies, tokens, or HTML — it is an authorization record only.
public struct OperatorApprovalPacket: Codable, Equatable, Sendable {
    public let packetId: String
    public let host: String
    public let capability: OperatorApprovalCapability
    public let grantedAt: Date
    public let expiresAt: Date?
    public let revoked: Bool
    public let grantedBy: String

    public init(
        packetId: String,
        host: String,
        capability: OperatorApprovalCapability,
        grantedAt: Date,
        expiresAt: Date?,
        revoked: Bool = false,
        grantedBy: String = "operator"
    ) {
        self.packetId = packetId
        self.host = host
        self.capability = capability
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
        self.revoked = revoked
        self.grantedBy = grantedBy
    }

    /// Self-contained validity check (no host/capability context). Used by
    /// evidence exporters that only need to know whether the packet itself is
    /// currently live.
    public func isValid(at now: Date) -> Bool {
        guard !revoked else { return false }
        guard let expiresAt else { return true }
        return expiresAt > now
    }
}

// MARK: - Operator Approval Decision

public enum OperatorApprovalDecision: Equatable, Sendable {
    case allowed
    case denied(reason: String)
}

// MARK: - Operator Approval Store

/// Thread-safe, file-backed store of operator approval packets. Modeled after
/// `RealNetworkPolicyStore` but persists to disk so approvals survive process
/// restarts on the simulator/device. Default state is empty: with no packet,
/// `validate` returns `.denied`, so login stays blocked-by-default.
@MainActor
public final class OperatorApprovalStore: @unchecked Sendable {
    public static let shared = OperatorApprovalStore()

    private var packets: [OperatorApprovalPacket]
    private let lock = NSLock()
    private let storeURL: URL

    public init(storeURL: URL = OperatorApprovalStore.defaultStoreURL()) {
        self.storeURL = storeURL
        self.packets = Self.load(from: storeURL)
    }

    public nonisolated static func defaultStoreURL() -> URL {
        let supportRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return supportRoot
            .appendingPathComponent("ReaderApp/HostRuntimeEvidence", isDirectory: true)
            .appendingPathComponent("operator_approval.json")
    }

    /// Validates whether an approval packet authorizes the given
    /// (host, capability) at `now`. Returns `.denied` when no live packet
    /// matches — login stays blocked-by-default.
    public func validate(
        host: String,
        capability: OperatorApprovalCapability,
        now: Date = Date()
    ) -> OperatorApprovalDecision {
        lock.lock()
        defer { lock.unlock() }

        let candidates = packets.filter { $0.capability == capability && $0.host == host }
        if candidates.isEmpty {
            return .denied(reason: "no operator approval packet for host/capability")
        }
        if candidates.contains(where: { $0.isValid(at: now) }) {
            return .allowed
        }
        if candidates.contains(where: { $0.revoked }) {
            return .denied(reason: "operator approval packet revoked")
        }
        return .denied(reason: "operator approval packet expired")
    }

    /// Inserts or replaces a packet by `packetId` and persists to disk.
    public func upsert(_ packet: OperatorApprovalPacket) {
        lock.lock()
        packets.removeAll { $0.packetId == packet.packetId }
        packets.append(packet)
        let snapshot = packets
        lock.unlock()
        Self.persist(snapshot, to: storeURL)
    }

    /// Marks a packet revoked by id and persists to disk.
    public func revoke(packetId: String) {
        lock.lock()
        packets = packets.map { packet in
            guard packet.packetId == packetId else { return packet }
            return OperatorApprovalPacket(
                packetId: packet.packetId,
                host: packet.host,
                capability: packet.capability,
                grantedAt: packet.grantedAt,
                expiresAt: packet.expiresAt,
                revoked: true,
                grantedBy: packet.grantedBy
            )
        }
        let snapshot = packets
        lock.unlock()
        Self.persist(snapshot, to: storeURL)
    }

    /// Clears all packets and removes the backing file. Used by tests and by
    /// operators to return to the default blocked state.
    public func reset() {
        lock.lock()
        packets = []
        lock.unlock()
        try? FileManager.default.removeItem(at: storeURL)
    }

    public func currentPackets() -> [OperatorApprovalPacket] {
        lock.lock()
        defer { lock.unlock() }
        return packets
    }

    // MARK: - File Backend

    private static func load(from url: URL) -> [OperatorApprovalPacket] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([OperatorApprovalPacket].self, from: data)) ?? []
    }

    private static func persist(_ packets: [OperatorApprovalPacket], to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(packets) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
    }
}
