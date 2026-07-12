import CoreFoundation
import Foundation
import ReaderUIContract

/// Process-local storage for canonical foreground one-shot timers. It is an
/// actor because HostAdapter dispatch can originate outside the main actor.
public actor HostForegroundTimerStore {
    public typealias FireHandler = @Sendable (_ correlationID: String, _ generation: Int) async -> Void

    private var tasks: [String: Task<Void, Never>] = [:]
    private var generations: [String: Int] = [:]
    private var tokens: [String: UInt64] = [:]
    private var nextToken: UInt64 = 0

    public init() {}

    @discardableResult
    public func arm(
        timerID: String,
        correlationID: String,
        delayMs: Int,
        generation: Int,
        onFire: @escaping FireHandler
    ) -> Bool {
        let previous = tasks.removeValue(forKey: timerID)
        let replaced = previous != nil
        previous?.cancel()
        nextToken &+= 1
        let token = nextToken
        generations[timerID] = generation
        tokens[timerID] = token
        tasks[timerID] = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled,
                  await self?.consume(timerID: timerID, generation: generation, token: token) == true else {
                return
            }
            await onFire(correlationID, generation)
        }
        return replaced
    }

    @discardableResult
    public func cancel(timerID: String, generation: Int) -> Bool {
        guard generations[timerID] == generation else { return false }
        generations[timerID] = nil
        tokens[timerID] = nil
        guard let task = tasks.removeValue(forKey: timerID) else { return false }
        task.cancel()
        return true
    }

    private func consume(timerID: String, generation: Int, token: UInt64) -> Bool {
        guard generations[timerID] == generation,
              tokens[timerID] == token else { return false }
        generations[timerID] = nil
        tokens[timerID] = nil
        tasks[timerID] = nil
        return true
    }
}

/// Typed HostAdapter handler for Reader-UI's staging timer pair. The timer is
/// always one-shot and foreground-only; repeating/background payloads are
/// rejected before a platform task is created.
public struct HostForegroundTimerCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [
        .timer_foreground_arm,
        .timer_foreground_cancel,
    ]
    public let tier: HostCapabilityTier = .crossPlatform

    private let store: HostForegroundTimerStore
    private let onFire: HostForegroundTimerStore.FireHandler

    public init(
        store: HostForegroundTimerStore = HostForegroundTimerStore(),
        onFire: @escaping HostForegroundTimerStore.FireHandler = { _, _ in }
    ) {
        self.store = store
        self.onFire = onFire
    }

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        switch request.type {
        case .timer_foreground_arm:
            return await arm(request.payload)
        case .timer_foreground_cancel:
            return await cancel(request.payload)
        default:
            return .failure(.notImplemented(request.type, "HostForegroundTimerCapability does not handle this type"))
        }
    }

    private func arm(_ payload: [String: AnyCodable]) async -> HostCapabilityOutcome {
        guard let timerID = nonBlankString(payload["timerId"]),
              let correlationID = nonBlankString(payload["correlationId"]),
              timerID == correlationID,
              let delayMs = integer(payload["delayMs"]),
              (250 ... 3_600_000).contains(delayMs),
              let generation = integer(payload["generation"]),
              generation >= 0,
              strictBool(payload["oneShot"]) == true,
              strictBool(payload["foregroundOnly"]) == true else {
            return .failure(.invalidParams(
                "timer.foreground.arm requires matching timerId/correlationId, delayMs=250...3600000, generation, oneShot=true and foregroundOnly=true"
            ))
        }
        let replaced = await store.arm(
            timerID: timerID,
            correlationID: correlationID,
            delayMs: delayMs,
            generation: generation,
            onFire: onFire
        )
        return .success([
            "armed": AnyCodable(true),
            "replaced": AnyCodable(replaced),
            "timerId": AnyCodable(timerID),
            "generation": AnyCodable(generation),
        ])
    }

    private func cancel(_ payload: [String: AnyCodable]) async -> HostCapabilityOutcome {
        guard let timerID = nonBlankString(payload["timerId"]),
              let correlationID = nonBlankString(payload["correlationId"]),
              timerID == correlationID,
              let generation = integer(payload["generation"]),
              generation >= 0,
              strictBool(payload["oneShot"]) == true,
              strictBool(payload["foregroundOnly"]) == true else {
            return .failure(.invalidParams(
                "timer.foreground.cancel requires matching timerId/correlationId, generation, oneShot=true and foregroundOnly=true"
            ))
        }
        let cancelled = await store.cancel(timerID: timerID, generation: generation)
        return .success([
            "cancelled": AnyCodable(cancelled),
            "timerId": AnyCodable(timerID),
            "generation": AnyCodable(generation),
        ])
    }

    private func nonBlankString(_ value: AnyCodable?) -> String? {
        guard let value = value?.value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func integer(_ value: AnyCodable?) -> Int? {
        if let value = value?.value as? Int { return value }
        if let value = value?.value as? String { return Int(value) }
        guard let number = value?.value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        guard double.isFinite,
              double.rounded(.towardZero) == double,
              double >= 0,
              double <= Double(Int.max) else { return nil }
        return Int(double)
    }

    private func strictBool(_ value: AnyCodable?) -> Bool? {
        if let value = value?.value as? Bool { return value }
        guard let number = value?.value as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }
}
