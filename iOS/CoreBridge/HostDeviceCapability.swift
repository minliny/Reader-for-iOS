// CoreBridge
//
// HostDeviceCapability — UI/reducer-initiated device + background capabilities.
//
// Bridges the contract `HostRequest` to:
// - `device.vibrate`: `UIImpactFeedbackGenerator` (iOS) — realDeviceProof
//   because the sim has no haptic hardware.
// - `device.screen.keep-on` / `device.screen.release`:
//   `UIApplication.isIdleTimerDisabled` (iOS) — realDeviceProof because the
//   sim display does not auto-lock the same way.
// - `background.schedule` / `background.cancel`:
//   `UIApplication.beginBackgroundTask` / `endBackgroundTask` (iOS) —
//   realDeviceProof because the sim kills background tasks aggressively.
//
// Tier: realDeviceProof — all three capability groups behave differently on
// the sim. The handler exercises the API on sim (so the registry path is
// covered), but full proof requires a real device.
//
// Payload contract:
// - `.device_vibrate`:
//   `{ style?: "light"|"medium"|"heavy"|"soft"|"rigid" }` → `{ vibrated: true }`
// - `.device_screen_keep_on`: `{ keepOn: Bool }` → `{ applied: true, keepOn: Bool }`
// - `.device_screen_release`: `{}` → `{ applied: true, keepOn: false }`
// - `.background_schedule`:
//   `{ task: String }` → `{ scheduled: true, taskId: String }`
// - `.background_cancel`:
//   `{ taskId: String }` → `{ cancelled: true, taskId: String }`

import Foundation
import ReaderUIContract

#if canImport(UIKit)
import UIKit
#endif

public struct HostDeviceCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [
        .device_vibrate, .device_screen_keep_on, .device_screen_release,
        .background_schedule, .background_cancel,
    ]
    public let tier: HostCapabilityTier = .realDeviceProof

    /// Background task IDs retained so they can be ended by `background.cancel`.
    /// `@unchecked Sendable` because the dictionary is mutated under
    /// `dispatch`'s await boundary; concurrent access from multiple dispatches
    /// is safe because the registry serializes per-request (UI requests are
    /// dispatched from the main actor).
    private let backgroundTasks = BackgroundTaskRegistry()

    public init() {}

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        switch request.type {
        case .device_vibrate:
            return handleVibrate(request.payload)
        case .device_screen_keep_on:
            return handleScreenKeepOn(request.payload)
        case .device_screen_release:
            return handleScreenRelease()
        case .background_schedule:
            return handleBackgroundSchedule(request.payload)
        case .background_cancel:
            return handleBackgroundCancel(request.payload)
        default:
            return .failure(.notImplemented(request.type, "HostDeviceCapability does not handle \(request.type.rawValue)"))
        }
    }

    // MARK: - device.vibrate

    private func handleVibrate(_ payload: [String: AnyCodable]) -> HostCapabilityOutcome {
        let style = (payload["style"]?.value as? String) ?? "light"
        #if canImport(UIKit)
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case "light": feedbackStyle = .light
        case "medium": feedbackStyle = .medium
        case "heavy": feedbackStyle = .heavy
        case "soft": feedbackStyle = .soft
        case "rigid": feedbackStyle = .rigid
        default:
            return .failure(.invalidParams("device.vibrate style not recognized: \(style)"))
        }
        let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
        generator.prepare()
        generator.impactOccurred()
        return .success(["vibrated": AnyCodable(true), "style": AnyCodable(style)])
        #else
        return .failure(.notImplemented(.device_vibrate, "haptics require UIKit — not available on macOS swift build (style=\(style))"))
        #endif
    }

    // MARK: - device.screen.keep-on / release

    private func handleScreenKeepOn(_ payload: [String: AnyCodable]) -> HostCapabilityOutcome {
        let keepOn = (payload["keepOn"]?.value as? Bool) ?? true
        #if canImport(UIKit)
        DispatchQueue.main.sync {
            UIApplication.shared.isIdleTimerDisabled = keepOn
        }
        return .success(["applied": AnyCodable(true), "keepOn": AnyCodable(keepOn)])
        #else
        return .failure(.notImplemented(.device_screen_keep_on, "idle timer requires UIKit — not available on macOS swift build"))
        #endif
    }

    private func handleScreenRelease() -> HostCapabilityOutcome {
        #if canImport(UIKit)
        DispatchQueue.main.sync {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        return .success(["applied": AnyCodable(true), "keepOn": AnyCodable(false)])
        #else
        return .failure(.notImplemented(.device_screen_release, "idle timer requires UIKit — not available on macOS swift build"))
        #endif
    }

    // MARK: - background.schedule / cancel

    private func handleBackgroundSchedule(_ payload: [String: AnyCodable]) -> HostCapabilityOutcome {
        guard let taskName = payload["task"]?.value as? String, !taskName.isEmpty else {
            return .failure(.invalidParams("background.schedule requires non-empty `task`"))
        }
        #if canImport(UIKit)
        let taskId = UIApplication.shared.beginBackgroundTask(withName: taskName) {
            // Expiration handler — the system calls this when background time
            // is about to expire. We end the task to avoid a crash.
            // No-op here; the registry's `background.cancel` is the normal
            // end path.
        }
        let taskIdString = taskId == UIBackgroundTaskIdentifier.invalid ? "invalid" : "\(taskId)"
        backgroundTasks.register(name: taskName, taskId: taskId)
        return .success([
            "scheduled": AnyCodable(true),
            "taskId": AnyCodable(taskIdString),
            "task": AnyCodable(taskName),
        ])
        #else
        return .failure(.notImplemented(.background_schedule, "background tasks require UIKit — not available on macOS swift build (task=\(taskName))"))
        #endif
    }

    private func handleBackgroundCancel(_ payload: [String: AnyCodable]) -> HostCapabilityOutcome {
        guard let taskIdString = payload["taskId"]?.value as? String, !taskIdString.isEmpty else {
            return .failure(.invalidParams("background.cancel requires non-empty `taskId`"))
        }
        #if canImport(UIKit)
        if let taskId = backgroundTasks.end(byIdString: taskIdString) {
            UIApplication.shared.endBackgroundTask(taskId)
            return .success(["cancelled": AnyCodable(true), "taskId": AnyCodable(taskIdString)])
        }
        return .failure(.invalidParams("background.cancel: no background task registered for taskId \(taskIdString)"))
        #else
        return .failure(.notImplemented(.background_cancel, "background tasks require UIKit — not available on macOS swift build (taskId=\(taskIdString))"))
        #endif
    }
}

/// Thread-safe registry of in-flight background task identifiers so
/// `background.cancel` can look up the `UIBackgroundTaskIdentifier` from its
/// stringified value.
private final class BackgroundTaskRegistry: @unchecked Sendable {
    #if canImport(UIKit)
    private var tasks: [String: UIBackgroundTaskIdentifier] = [:]
    #else
    private var tasks: [String: Int] = [:]
    #endif
    private let lock = NSLock()

    #if canImport(UIKit)
    func register(name: String, taskId: UIBackgroundTaskIdentifier) {
        lock.lock(); defer { lock.unlock() }
        let key = "\(taskId)"
        tasks[key] = taskId
        tasks[name] = taskId
    }

    func end(byIdString idString: String) -> UIBackgroundTaskIdentifier? {
        lock.lock(); defer { lock.unlock() }
        return tasks.removeValue(forKey: idString)
    }
    #else
    func register(name: String, taskId: Int) {}
    func end(byIdString idString: String) -> Int? { nil }
    #endif
}
