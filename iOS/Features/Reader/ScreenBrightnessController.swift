import Foundation
import ReaderShellValidation
#if canImport(UIKit)
import UIKit
#endif

/// iOS bridge that applies `BrightnessPolicy` to `UIScreen.main.brightness`.
///
/// Foundation-only protocol conformance is testable via `StubBrightnessController`
/// on the macOS host. The real `UIScreen` integration lives behind
/// `#if canImport(UIKit)` so the host build never touches UIKit.
public final class ScreenBrightnessController: BrightnessControlling, @unchecked Sendable {
    #if canImport(UIKit)
    private var savedLevel: CGFloat?
    #endif

    public init() {}

    public func apply(_ policy: BrightnessPolicy) {
        guard policy.enabled else { return }
        #if canImport(UIKit)
        if savedLevel == nil {
            savedLevel = UIScreen.main.brightness
        }
        UIScreen.main.brightness = CGFloat(min(1.0, max(0.0, policy.level)))
        #endif
    }

    public func restore() {
        #if canImport(UIKit)
        if let saved = savedLevel {
            UIScreen.main.brightness = saved
            savedLevel = nil
        }
        #endif
    }

    public func currentLevel() -> Double {
        #if canImport(UIKit)
        return Double(UIScreen.main.brightness)
        #else
        return 1.0
        #endif
    }
}
