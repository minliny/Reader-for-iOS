import Foundation
import ReaderUIContract

#if canImport(Network)
import Network
#endif

public struct HostNetworkStatus: Equatable, Sendable {
    public let connected: Bool
    public let status: String
    public let interface: String
    public let isExpensive: Bool
    public let isConstrained: Bool

    public init(
        connected: Bool,
        status: String,
        interface: String,
        isExpensive: Bool,
        isConstrained: Bool
    ) {
        self.connected = connected
        self.status = status
        self.interface = interface
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
    }
}

public protocol HostNetworkStatusProviding: Sendable {
    func currentStatus() async throws -> HostNetworkStatus
}

#if canImport(Network)
public struct NWPathNetworkStatusProvider: HostNetworkStatusProviding {
    public init() {}

    public func currentStatus() async throws -> HostNetworkStatus {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "com.reader.host.network-status")
        monitor.start(queue: queue)
        defer { monitor.cancel() }
        // NWPathMonitor publishes asynchronously. A short bounded wait lets
        // `currentPath` settle without creating an uncancellable continuation.
        try await Task.sleep(nanoseconds: 75_000_000)
        let path = monitor.currentPath
        return HostNetworkStatus(
            connected: path.status == .satisfied,
            status: Self.statusName(path.status),
            interface: Self.interfaceName(path),
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained
        )
    }

    private static func statusName(_ status: NWPath.Status) -> String {
        switch status {
        case .satisfied: return "online"
        case .requiresConnection: return "limited"
        case .unsatisfied: return "offline"
        @unknown default: return "offline"
        }
    }

    private static func interfaceName(_ path: NWPath) -> String {
        if path.usesInterfaceType(.wifi) { return "wifi" }
        if path.usesInterfaceType(.cellular) { return "cellular" }
        if path.usesInterfaceType(.wiredEthernet) { return "ethernet" }
        if path.usesInterfaceType(.loopback) { return "loopback" }
        if path.usesInterfaceType(.other) { return "other" }
        return "none"
    }
}
#endif

public struct HostNetworkCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [.network_status]
    public let tier: HostCapabilityTier = .simulatorProof

    private let provider: (any HostNetworkStatusProviding)?

    public init() {
        self.provider = Self.defaultProvider()
    }

    public init(provider: (any HostNetworkStatusProviding)?) {
        self.provider = provider
    }

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        guard request.type == .network_status else {
            return .failure(.notImplemented(
                request.type,
                "HostNetworkCapability does not handle \(request.type.rawValue)"
            ))
        }
        guard let provider else {
            return .failure(.notImplemented(.network_status, "Network framework is unavailable"))
        }
        do {
            let status = try await provider.currentStatus()
            return .success([
                "connected": AnyCodable(status.connected),
                "status": AnyCodable(Self.canonicalStatus(status.status, connected: status.connected)),
                "interface": AnyCodable(status.interface),
                "isExpensive": AnyCodable(status.isExpensive),
                "isConstrained": AnyCodable(status.isConstrained),
            ])
        } catch {
            return .failure(.underlying("network.status failed: \(error.localizedDescription)"))
        }
    }

    private static func defaultProvider() -> (any HostNetworkStatusProviding)? {
        #if canImport(Network)
        return NWPathNetworkStatusProvider()
        #else
        return nil
        #endif
    }

    private static func canonicalStatus(_ value: String, connected: Bool) -> String {
        switch value {
        case "online", "limited", "offline": return value
        case "connected", "satisfied": return "online"
        case "requiresConnection": return "limited"
        case "disconnected", "unsatisfied": return "offline"
        default: return connected ? "online" : "offline"
        }
    }
}
