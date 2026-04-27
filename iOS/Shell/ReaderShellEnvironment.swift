import Foundation

public struct ReaderShellEnvironment {
    public var supportsDebugOverlay: Bool

    public init(supportsDebugOverlay: Bool = false) {
        self.supportsDebugOverlay = supportsDebugOverlay
    }
}