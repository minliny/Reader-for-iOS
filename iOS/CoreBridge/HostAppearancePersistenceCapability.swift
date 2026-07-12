import Foundation
import ReaderUIContract

/// UI-owned appearance persistence reuses the same opaque-string, revision-CAS
/// store as Core. The Host never interprets theme/font/typography JSON.
public struct HostAppearancePersistenceCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [.persistence_get, .persistence_put]
    public let tier: HostCapabilityTier = .crossPlatform

    public init() {}

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        guard supportedTypes.contains(request.type) else {
            return .failure(.notImplemented(request.type, "unsupported appearance persistence request"))
        }
        guard let namespace = request.payload["namespace"]?.value as? String, !namespace.isEmpty,
              let key = request.payload["key"]?.value as? String, !key.isEmpty else {
            return .failure(.invalidParams("\(request.type.rawValue) requires non-empty `namespace` and `key`"))
        }
        var params: [String: Any] = ["namespace": namespace, "key": key]
        let result: [String: Any]
        switch request.type {
        case .persistence_get:
            result = try HostPersistenceStore.shared.get(params: params)
        case .persistence_put:
            guard let value = request.payload["value"]?.value as? String else {
                return .failure(.invalidParams("persistence.put requires string `value`"))
            }
            guard let expectedRevision = request.payload["expectedRevision"]?.value as? String,
                  Self.isRevision(expectedRevision) else {
                return .failure(.invalidParams("persistence.put requires decimal `expectedRevision`"))
            }
            params["value"] = value
            params["expectedRevision"] = expectedRevision
            result = try HostPersistenceStore.shared.put(params: params)
        default:
            return .failure(.notImplemented(request.type, "unsupported appearance persistence request"))
        }
        var payload: [String: AnyCodable] = [:]
        for (key, value) in result {
            if let string = value as? String { payload[key] = AnyCodable(string) }
            else if let bool = value as? Bool { payload[key] = AnyCodable(bool) }
            else {
                return .failure(.underlying("\(request.type.rawValue) returned an unsupported result value"))
            }
        }
        return .success(payload)
    }

    private static func isRevision(_ value: String) -> Bool {
        guard !value.isEmpty, value.allSatisfy(\.isNumber) else { return false }
        return value == "0" || !value.hasPrefix("0")
    }
}
