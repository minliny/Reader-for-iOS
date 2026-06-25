import Foundation

public struct ReaderShellEnvironment {
    public var supportsDebugOverlay: Bool

    /// Production WKWebView adapter reachable from the reading shell.
    /// iOS-only (WebKit + UIKit); nil on macOS host builds so the
    /// ReaderShellValidation target stays macOS-compilable.
    /// Created via `ShellAssembly.makeProductionWebViewAdapter()`.
    #if canImport(WebKit) && canImport(UIKit)
    public var webViewAdapter: ProductionWebViewAdapter?
    #endif

    public init(supportsDebugOverlay: Bool = false) {
        self.supportsDebugOverlay = supportsDebugOverlay
        #if canImport(WebKit) && canImport(UIKit)
        self.webViewAdapter = nil
        #endif
    }
}
