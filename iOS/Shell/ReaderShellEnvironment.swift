import Foundation

public struct ReaderShellEnvironment {
    public var appEntry: AppEntry
    public var supportsDebugOverlay: Bool

    public init(appEntry: AppEntry = AppEntry(), supportsDebugOverlay: Bool = false) {
        self.appEntry = appEntry
        self.supportsDebugOverlay = supportsDebugOverlay
    }
}
