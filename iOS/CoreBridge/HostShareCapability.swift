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

    /// Present an actual file URL, not its path as plain text. Existing test
    /// presenters keep source compatibility through the default implementation;
    /// the production presenter overrides this method with a URL-backed share
    /// sheet.
    func present(fileURL: URL, excludedActivityTypes: [String]?) async -> String?
}

public extension HostSharePresenter {
    func present(fileURL: URL, excludedActivityTypes: [String]?) async -> String? {
        await present(items: [fileURL.absoluteString], excludedActivityTypes: excludedActivityTypes)
    }
}

public struct HostShareCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [.share_invoke, .share_text, .share_file]
    public let tier: HostCapabilityTier = .simulatorProof

    private let presenterProvider: @Sendable () async -> HostSharePresenter?

    public init(presenterProvider: @escaping @Sendable () async -> HostSharePresenter?) {
        self.presenterProvider = presenterProvider
    }

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        guard let presenter = await presenterProvider() else {
            return .failure(.notImplemented(request.type, "share presenter not available on this platform"))
        }
        switch request.type {
        case .share_text:
            return await handleText(request.payload, presenter: presenter)
        case .share_file:
            return await handleFile(request.payload, presenter: presenter)
        case .share_invoke:
            break
        default:
            return .failure(.notImplemented(request.type, "HostShareCapability does not handle \(request.type.rawValue)"))
        }
        guard let text = request.payload["text"]?.value as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.invalidParams("share.invoke requires non-empty `text`"))
        }
        if let files = Self.stringArray(request.payload["files"]?.value), !files.isEmpty {
            return .failure(.notImplemented(
                .share_invoke,
                "multi-file share.invoke requires a URL-capable presenter; use share.file for one file"
            ))
        }
        var strings = [text]
        if let url = request.payload["url"]?.value as? String, !url.isEmpty {
            strings.append(url)
        }

        let activityType = await presenter.present(items: strings, excludedActivityTypes: nil)
        var result: [String: AnyCodable] = ["shared": AnyCodable(activityType != nil)]
        if let activityType = activityType {
            result["activityType"] = AnyCodable(activityType)
        }
        return .success(result)
    }

    private func handleText(
        _ payload: [String: AnyCodable],
        presenter: HostSharePresenter
    ) async -> HostCapabilityOutcome {
        guard let text = payload["text"]?.value as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.invalidParams("share.text requires non-empty `text`"))
        }
        let activityType = await presenter.present(items: [text], excludedActivityTypes: nil)
        return shareOutcome(activityType: activityType)
    }

    private func handleFile(
        _ payload: [String: AnyCodable],
        presenter: HostSharePresenter
    ) async -> HostCapabilityOutcome {
        guard let path = payload["path"]?.value as? String, !path.isEmpty else {
            return .failure(.invalidParams("share.file requires non-empty `path`"))
        }
        let url: URL
        if let parsed = URL(string: path), parsed.isFileURL {
            url = parsed
        } else {
            url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failure(.invalidParams("share.file file does not exist at \(url.path)"))
        }
        let activityType = await presenter.present(fileURL: url, excludedActivityTypes: nil)
        var outcome = shareOutcome(activityType: activityType)
        if outcome.succeeded, var result = outcome.result {
            result["path"] = AnyCodable(url.path)
            outcome = .success(result)
        }
        return outcome
    }

    private func shareOutcome(activityType: String?) -> HostCapabilityOutcome {
        var result: [String: AnyCodable] = ["shared": AnyCodable(activityType != nil)]
        if let activityType {
            result["activityType"] = AnyCodable(activityType)
        }
        return .success(result)
    }

    private static func stringArray(_ raw: (any Sendable)?) -> [String]? {
        if let values = raw as? [String] { return values }
        if let values = raw as? [AnyCodable] {
            let strings = values.compactMap { $0.value as? String }
            return strings.count == values.count ? strings : nil
        }
        return nil
    }
}
