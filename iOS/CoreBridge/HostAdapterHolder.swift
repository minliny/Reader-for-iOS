import Foundation

/// Process-wide holder for the production `HostAdapter` instance.
///
/// `HostAdapter` itself lives in `ReaderShellValidation` (CoreBridge target)
/// and is constructed with default handlers. The TTS / Share capabilities
/// need concrete types from the app target (`ReaderTTSPlayer`,
/// `ReaderSharePresenter`), so the app calls
/// `HostAdapterHolder.adapter.setTTSSynthProvider(...)` /
/// `setSharePresenterProvider(...)` at launch to inject them.
///
/// The holder is `@MainActor` because `HostAdapter` is `@MainActor`-isolated.
@MainActor
public enum HostAdapterHolder {
    /// The shared production adapter. Lazily initialized with all 11
    /// capability handlers (TTS / Share providers return nil until injected).
    public static let adapter: HostAdapter = HostAdapter()
}
