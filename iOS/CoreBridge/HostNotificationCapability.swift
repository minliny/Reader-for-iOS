// CoreBridge
//
// HostNotificationCapability — UI/reducer-initiated
// `notification.show/cancel`.
//
// Bridges the contract `HostRequest` to `UNUserNotificationCenter`. Local
// notifications are scheduled with a `UNMutableNotificationContent` +
// `UNTimeIntervalNotificationTrigger`. Pre-iOS 14 in-foreground delivery
// requires a `UNUserNotificationCenterDelegate`; this handler does not install
// one — the app delegate owns that.
//
// Tier: simulatorProof — `UNUserNotificationCenter` works on the sim, but
// notifications are suppressed when the app is in the foreground unless a
// delegate is installed. Real-device proof adds the background-delivery
// assertion (the sim kills background tasks aggressively).
//
// Payload contract:
// - `.notification_show`:
//   `{ id: String, title: String, body: String, subtitle?: String,
//      delay?: Double, badge?: Int, sound?: String }`
//   → `{ shown: true, id: String }`
// - `.notification_cancel`:
//   `{ id: String }` → `{ cancelled: true, id: String }`

import Foundation
import UserNotifications
import ReaderUIContract

public struct HostNotificationCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [.notification_show, .notification_cancel]
    public let tier: HostCapabilityTier = .simulatorProof

    public init() {}

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        switch request.type {
        case .notification_show:
            return try await handleShow(request.payload)
        case .notification_cancel:
            return try await handleCancel(request.payload)
        default:
            return .failure(.notImplemented(request.type, "HostNotificationCapability does not handle \(request.type.rawValue)"))
        }
    }

    private func handleShow(_ payload: [String: AnyCodable]) async throws -> HostCapabilityOutcome {
        guard let id = payload["id"]?.value as? String, !id.isEmpty else {
            return .failure(.invalidParams("notification.show requires non-empty `id`"))
        }
        guard let title = payload["title"]?.value as? String else {
            return .failure(.invalidParams("notification.show requires `title`"))
        }
        guard let body = payload["body"]?.value as? String else {
            return .failure(.invalidParams("notification.show requires `body`"))
        }
        let subtitle = payload["subtitle"]?.value as? String
        let delay = (payload["delay"]?.value as? Double) ?? 0
        let badge = (payload["badge"]?.value as? Int).map { NSNumber(value: $0) }
        let sound = payload["sound"]?.value as? String

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let subtitle = subtitle { content.subtitle = subtitle }
        if let badge = badge { content.badge = badge }
        if let sound = sound {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
        } else {
            content.sound = .default
        }

        let trigger: UNNotificationTrigger?
        if delay > 0 {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        } else {
            trigger = nil
        }
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            return .success([
                "shown": AnyCodable(true),
                "id": AnyCodable(id),
            ])
        } catch {
            return .failure(.underlying("notification.show failed: \(error.localizedDescription)"))
        }
    }

    private func handleCancel(_ payload: [String: AnyCodable]) async throws -> HostCapabilityOutcome {
        guard let id = payload["id"]?.value as? String, !id.isEmpty else {
            return .failure(.invalidParams("notification.cancel requires non-empty `id`"))
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [id]
        )
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: [id]
        )
        return .success([
            "cancelled": AnyCodable(true),
            "id": AnyCodable(id),
        ])
    }
}
