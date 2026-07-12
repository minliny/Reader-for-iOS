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
        .screen_keepAwake, .screen_allowSleep,
        .haptics_light, .haptics_medium, .haptics_heavy,
        .background_task_start, .background_task_end,
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
            return await handleVibrate(request.payload, type: request.type)
        case .haptics_light:
            return await handleVibrate(["style": AnyCodable("light")], type: request.type)
        case .haptics_medium:
            return await handleVibrate(["style": AnyCodable("medium")], type: request.type)
        case .haptics_heavy:
            return await handleVibrate(["style": AnyCodable("heavy")], type: request.type)
        case .device_screen_keep_on:
            return await handleScreenKeepOn(request.payload, type: request.type)
        case .screen_keepAwake:
            return await handleScreenKeepOn(["keepOn": AnyCodable(true)], type: request.type)
        case .device_screen_release, .screen_allowSleep:
            return await handleScreenRelease(type: request.type)
        case .background_schedule:
            return .failure(.notImplemented(
                .background_schedule,
                "BGTaskScheduler identifiers and launch handlers are not configured"
            ))
        case .background_task_start:
            return await handleBackgroundSchedule(request.payload, type: request.type)
        case .background_cancel:
            return .failure(.notImplemented(
                .background_cancel,
                "BGTaskScheduler cancellation is unavailable until scheduling is configured"
            ))
        case .background_task_end:
            return await handleBackgroundCancel(request.payload, type: request.type)
        default:
            return .failure(.notImplemented(request.type, "HostDeviceCapability does not handle \(request.type.rawValue)"))
        }
    }

    // MARK: - device.vibrate

    private func handleVibrate(
        _ payload: [String: AnyCodable],
        type: HostRequestType
    ) async -> HostCapabilityOutcome {
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
        await MainActor.run {
            let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
            generator.prepare()
            generator.impactOccurred()
        }
        if type == .haptics_light || type == .haptics_medium || type == .haptics_heavy {
            return .success(["performed": AnyCodable(true), "style": AnyCodable(style)])
        }
        return .success(["vibrated": AnyCodable(true), "style": AnyCodable(style)])
        #else
        return .failure(.notImplemented(type, "haptics require UIKit — not available on macOS swift build (style=\(style))"))
        #endif
    }

    // MARK: - device.screen.keep-on / release

    private func handleScreenKeepOn(
        _ payload: [String: AnyCodable],
        type: HostRequestType
    ) async -> HostCapabilityOutcome {
        let keepOn: Bool
        if type == .device_screen_keep_on {
            guard let enabled = payload["enabled"]?.value as? Bool else {
                return .failure(.invalidParams("device.screen.keep-on requires `enabled` Bool"))
            }
            keepOn = enabled
        } else {
            keepOn = true
        }
        #if canImport(UIKit)
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = keepOn
        }
        if type == .screen_keepAwake {
            return .success(["applied": AnyCodable(true), "keepAwake": AnyCodable(keepOn)])
        }
        return .success(["enabled": AnyCodable(keepOn)])
        #else
        return .failure(.notImplemented(type, "idle timer requires UIKit — not available on macOS swift build"))
        #endif
    }

    private func handleScreenRelease(type: HostRequestType) async -> HostCapabilityOutcome {
        #if canImport(UIKit)
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        if type == .screen_allowSleep {
            return .success(["applied": AnyCodable(true), "keepAwake": AnyCodable(false)])
        }
        return .success(["released": AnyCodable(true)])
        #else
        return .failure(.notImplemented(type, "idle timer requires UIKit — not available on macOS swift build"))
        #endif
    }

    // MARK: - background.schedule / cancel

    private func handleBackgroundSchedule(
        _ payload: [String: AnyCodable],
        type: HostRequestType
    ) async -> HostCapabilityOutcome {
        let nameKey = "name"
        guard let taskName = payload[nameKey]?.value as? String,
              !taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.invalidParams("\(type.rawValue) requires non-empty `\(nameKey)`"))
        }
        #if canImport(UIKit)
        let taskRegistry = backgroundTasks
        let taskId = await MainActor.run {
            UIApplication.shared.beginBackgroundTask(withName: taskName) {
                if let expiredTask = taskRegistry.end(byIdString: taskName) {
                    UIApplication.shared.endBackgroundTask(expiredTask)
                }
            }
        }
        guard taskId != UIBackgroundTaskIdentifier.invalid else {
            return .failure(.underlying("\(type.rawValue) was rejected by UIApplication"))
        }
        let taskIdString = "\(taskId)"
        backgroundTasks.register(name: taskName, taskId: taskId)
        if type == .background_task_start {
            return .success([
                "started": AnyCodable(true),
                "taskId": AnyCodable(taskIdString),
                "name": AnyCodable(taskName),
            ])
        }
        return .success([
            "scheduled": AnyCodable(true),
            "taskId": AnyCodable(taskIdString),
            "task": AnyCodable(taskName),
        ])
        #else
        return .failure(.notImplemented(type, "background tasks require UIKit — not available on macOS swift build (task=\(taskName))"))
        #endif
    }

    private func handleBackgroundCancel(
        _ payload: [String: AnyCodable],
        type: HostRequestType
    ) async -> HostCapabilityOutcome {
        guard let taskIdString = payload["taskId"]?.value as? String, !taskIdString.isEmpty else {
            return .failure(.invalidParams("\(type.rawValue) requires non-empty `taskId`"))
        }
        #if canImport(UIKit)
        if let taskId = backgroundTasks.end(byIdString: taskIdString) {
            await MainActor.run { UIApplication.shared.endBackgroundTask(taskId) }
            if type == .background_task_end {
                return .success(["ended": AnyCodable(true), "taskId": AnyCodable(taskIdString)])
            }
            return .success(["cancelled": AnyCodable(true), "taskId": AnyCodable(taskIdString)])
        }
        return .failure(.invalidParams("\(type.rawValue): no background task registered for taskId \(taskIdString)"))
        #else
        return .failure(.notImplemented(type, "background tasks require UIKit — not available on macOS swift build (taskId=\(taskIdString))"))
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
        guard let taskId = tasks[idString] else { return nil }
        tasks = tasks.filter { $0.value != taskId }
        return taskId
    }
    #else
    func register(name: String, taskId: Int) {}
    func end(byIdString idString: String) -> Int? { nil }
    #endif
}
