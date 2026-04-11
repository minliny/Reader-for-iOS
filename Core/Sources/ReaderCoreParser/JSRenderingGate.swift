import Foundation

/// Allows NonJSParserEngine to obtain JS-rendered HTML without importing
/// ReaderCoreJSRenderer directly. Inject a concrete implementation (e.g.,
/// JSRuntimeDOMBridge) at the app boundary; default is NullJSRenderingGate.
public protocol JSRenderingGate: Sendable {
    /// Execute `evalScript` against the DOM derived from `html` and return
    /// the resulting `document.documentElement.outerHTML`.
    /// Returns `html` unchanged on any error or timeout.
    func execute(html: String, evalScript: String?) -> String
}

/// No-op gate: passes HTML through unmodified.
/// Used when no JS renderer is wired in (default production path for non-JS sources).
public final class NullJSRenderingGate: JSRenderingGate, @unchecked Sendable {
    public static let shared = NullJSRenderingGate()
    public init() {}
    public func execute(html: String, evalScript: String?) -> String { html }
}
