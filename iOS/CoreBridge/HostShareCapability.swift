// CoreBridge
//
// HostShareCapability — UI/reducer-initiated `share.invoke`.
//
// Bridges the contract `HostRequest` to `UIActivityViewController` (iOS) /
// `NSSharingServicePicker` (macOS). The handler presents the share sheet via
// a `HostSharePresenter` protocol so CoreBridge does not depend on UIKit
// presentation APIs directly.
//
// Tier: simulatorProof — `UIActivityViewController` works on the sim, but the
// list of available activities differs (no AirDrop targets, no Messages app
// on sim without account). Real-device proof adds the activity-availability
// assertion.
//
// Payload contract:
// - `.share_invoke`:
//   `{ items: [String], excludedActivityTypes?: [String], anchor?: { x: Double, y: Double } }`
//   → `{ shared: Bool, activityType?: String }`

import Foundation
import ReaderUIContract

#if canImport(UIKit)
import UIKit
#endif

/// Abstraction over the platform share-sheet presentation so CoreBridge does
/// not import `UIKit` presentation APIs (which require a presenting view
/// controller — not available in `swift build` tests).
@MainActor
public protocol HostSharePresenter: AnyObject {
    /// Present the share sheet for the given items. Returns the activity type
    /// the user selected, or nil if the user dismissed without sharing.
    func present(items: [String], excludedActivityTypes: [String]?) async -> String?
}

public struct HostShareCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [.share_invoke]
    public let tier: HostCapabilityTier = .simulatorProof

    private let presenterProvider: @Sendable () async -> HostSharePresenter?

    public init(presenterProvider: @escaping @Sendable () async -> HostSharePresenter?) {
        self.presenterProvider = presenterProvider
    }

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        guard let presenter = await presenterProvider() else {
            return .failure(.notImplemented(request.type, "share presenter not available on this platform"))
        }
        guard let items = request.payload["items"]?.value as? [Any], !items.isEmpty else {
            return .failure(.invalidParams("share.invoke requires non-empty `items` array"))
        }
        let strings = items.compactMap { $0 as? String }
        guard !strings.isEmpty else {
            return .failure(.invalidParams("share.invoke `items` must contain at least one String"))
        }
        let excluded: [String]?
        if let excludedRaw = request.payload["excludedActivityTypes"]?.value as? [Any] {
            excluded = excludedRaw.compactMap { $0 as? String }
        } else {
            excluded = nil
        }

        let activityType = await presenter.present(items: strings, excludedActivityTypes: excluded)
        var result: [String: AnyCodable] = ["shared": AnyCodable(activityType != nil)]
        if let activityType = activityType {
            result["activityType"] = AnyCodable(activityType)
        }
        return .success(result)
    }
}
