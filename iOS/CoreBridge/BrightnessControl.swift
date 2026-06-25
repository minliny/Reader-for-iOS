import Foundation

/// User preference for in-reader screen brightness override.
///
/// Foundation-only (no UIKit) so it can be unit-tested on the macOS host.
/// The iOS view layer bridges to `UIScreen.main.brightness` via
/// `ScreenBrightnessController` (guarded with `#if os(iOS)`).
public struct BrightnessPolicy: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var level: Double
    public var restoreOnExit: Bool

    public init(enabled: Bool = false, level: Double = 0.8, restoreOnExit: Bool = true) {
        self.enabled = enabled
        self.level = min(1.0, max(0.0, level))
        self.restoreOnExit = restoreOnExit
    }
}

/// Abstraction over platform brightness APIs.
public protocol BrightnessControlling: Sendable {
    func apply(_ policy: BrightnessPolicy)
    func restore()
    func currentLevel() -> Double
}

/// Host-testable stub that records calls without touching real screen APIs.
public final class StubBrightnessController: BrightnessControlling, @unchecked Sendable {
    public private(set) var appliedPolicy: BrightnessPolicy?
    public private(set) var restoreCallCount: Int = 0
    private var simulatedLevel: Double = 1.0

    public init(initialLevel: Double = 1.0) {
        self.simulatedLevel = initialLevel
    }

    public func apply(_ policy: BrightnessPolicy) {
        guard policy.enabled else { return }
        appliedPolicy = policy
        simulatedLevel = policy.level
    }

    public func restore() {
        restoreCallCount += 1
        appliedPolicy = nil
    }

    public func currentLevel() -> Double {
        simulatedLevel
    }
}
