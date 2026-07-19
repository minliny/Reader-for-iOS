// CoreBridge
//
// HostPermissionCapability — UI/reducer-initiated `permission.request/check`.
//
// Bridges the contract `HostRequest` to iOS permission APIs:
// - `notification`: `UNUserNotificationCenter.requestAuthorization`
// - `camera`/`microphone`: `AVCaptureDevice.requestAccess`
// - `location`: check is supported; request fails closed until the app owns a
//   retained `CLLocationManager` and its delegate lifecycle.
//
// Tier: simulatorProof — the permission dialog appears on the sim but some
// flows (e.g. camera) require hardware. The handler exercises the API; full
// proof requires a real device for camera/microphone.
//
// Payload contract:
// - `.permission_request`:
//   `{ scope: "storage"|"notification"|"camera"|"microphone"|"location" }`
//   → `{ granted: Bool, status: String }`
// - `.permission_check`:
//   `{ scope: "storage"|"notification"|"camera"|"microphone"|"location" }`
//   → `{ granted: Bool, status: String }`
//
// Status values: "notDetermined", "restricted", "denied", "authorized",
// "provisional" (notification only), "ephemeral" (notification only).

import Foundation
import ReaderUIContract

#if canImport(UIKit)
import UIKit
import UserNotifications
import AVFoundation
import CoreLocation
#endif

public struct HostPermissionCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [.permission_request, .permission_check]
    public let tier: HostCapabilityTier = .simulatorProof

    public init() {}

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        switch request.type {
        case .permission_request:
            return try await handleRequest(request.payload)
        case .permission_check:
            return try await handleCheck(request.payload)
        default:
            return .failure(.notImplemented(request.type, "HostPermissionCapability does not handle \(request.type.rawValue)"))
        }
    }

    private func handleRequest(_ payload: [String: AnyCodable]) async throws -> HostCapabilityOutcome {
        guard let type = payload["scope"]?.value as? String else {
            return .failure(.invalidParams("permission.request requires `scope` string"))
        }
        if type == "storage" {
            // iOS app-container file access has no runtime permission prompt.
            return .success([
                "granted": AnyCodable(true),
                "status": AnyCodable("authorized"),
            ])
        }
        #if canImport(UIKit)
        switch type {
        case "notification":
            return try await requestNotification()
        case "camera":
            return try await requestAVMediaType(.video, label: type)
        case "microphone":
            return try await requestAVMediaType(.audio, label: type)
        case "location":
            return .failure(.notImplemented(
                .permission_request,
                "location permission requires an app-owned retained CLLocationManager"
            ))
        default:
            return .failure(.invalidParams("permission.request unknown type: \(type)"))
        }
        #else
        return .failure(.notImplemented(.permission_request, "permissions require UIKit — not available on macOS swift build (type=\(type))"))
        #endif
    }

    private func handleCheck(_ payload: [String: AnyCodable]) async throws -> HostCapabilityOutcome {
        guard let type = payload["scope"]?.value as? String else {
            return .failure(.invalidParams("permission.check requires `scope` string"))
        }
        if type == "storage" {
            return .success([
                "granted": AnyCodable(true),
                "status": AnyCodable("authorized"),
            ])
        }
        #if canImport(UIKit)
        switch type {
        case "notification":
            return try await checkNotification()
        case "camera":
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            return .success([
                "granted": AnyCodable(status == .authorized),
                "status": AnyCodable(Self.avStatusString(status)),
            ])
        case "microphone":
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            return .success([
                "granted": AnyCodable(status == .authorized),
                "status": AnyCodable(Self.avStatusString(status)),
            ])
        case "location":
            let status = CLLocationManager.authorizationStatus()
            return .success([
                "granted": AnyCodable(status == .authorizedAlways || status == .authorizedWhenInUse),
                "status": AnyCodable(Self.locationStatusString(status)),
            ])
        default:
            return .failure(.invalidParams("permission.check unknown type: \(type)"))
        }
        #else
        return .failure(.notImplemented(.permission_check, "permissions require UIKit — not available on macOS swift build (type=\(type))"))
        #endif
    }

    // MARK: - iOS implementations

    #if canImport(UIKit)
    private func requestNotification() async throws -> HostCapabilityOutcome {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            let settings = await center.notificationSettings()
            return .success([
                "granted": AnyCodable(granted),
                "status": AnyCodable(Self.unStatusString(settings.authorizationStatus)),
            ])
        } catch {
            return .failure(.underlying("notification permission failed: \(error.localizedDescription)"))
        }
    }

    private func requestAVMediaType(_ mediaType: AVMediaType, label: String) async throws -> HostCapabilityOutcome {
        let granted = await AVCaptureDevice.requestAccess(for: mediaType)
        return .success([
            "granted": AnyCodable(granted),
            "status": AnyCodable(Self.avStatusString(AVCaptureDevice.authorizationStatus(for: mediaType))),
        ])
    }

    private func checkNotification() async throws -> HostCapabilityOutcome {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let granted: Bool
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: granted = true
        default: granted = false
        }
        return .success([
            "granted": AnyCodable(granted),
            "status": AnyCodable(Self.unStatusString(settings.authorizationStatus)),
        ])
    }

    private static func unStatusString(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }

    private static func avStatusString(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorized: return "authorized"
        @unknown default: return "unknown"
        }
    }

    private static func locationStatusString(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown"
        }
    }
    #endif
}
