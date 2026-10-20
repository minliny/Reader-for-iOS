import SwiftUI

/// Host@33f7c7b:ProductMotionTiming.ts and ReaderControlMotionPolicy.ts.
enum ReaderMotion {
    static let invoke: Double = 0.220
    static let expand: Double = 0.320
    static let collapse: Double = 0.260
    static let dismiss: Double = 0.200
    static let restore: Double = 0.220
    static let directionTolerance: CGFloat = 8
    static let shortPressLimit: Double = 0.500

    /// Finger-held controls consume their measured displacement directly; only automatic motion samples this curve.
    static func automaticProgress(_ progress: CGFloat) -> CGFloat {
        let t = min(1, max(0, progress)); return t * t * (3 - 2 * t)
    }
    static func animation(duration: Double, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .timingCurve(1.0 / 3, 0, 2.0 / 3, 1, duration: duration)
    }
}
