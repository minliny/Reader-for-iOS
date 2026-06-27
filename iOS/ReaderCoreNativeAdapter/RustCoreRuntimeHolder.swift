// ReaderCoreNativeAdapter
//
// Singleton holder for the Rust Core runtime handle.
// App startup creates the runtime once; service adapters and the host request
// router share this single handle. Teardown happens on app termination.
//
// S6.1: This holder is the single entry point for the Rust Core runtime in the
// iOS host. It does NOT depend on ReaderCoreModels/Protocols — only on the
// C ABI wrapper (ReaderCoreNativeRuntime). Business adapters live in CoreBridge.

import Foundation

/// Singleton holding the shared `ReaderCoreNativeRuntime` instance.
///
/// Created on first access (or explicitly via `boot()`). The runtime is
/// thread-safe (`@unchecked Sendable`); all send/cancel/poll calls are
/// serialized by the caller.
@MainActor
public final class RustCoreRuntimeHolder {
    public static let shared = RustCoreRuntimeHolder()

    private var runtime: ReaderCoreNativeRuntime?

    private init() {}

    /// Lazily boot the Rust Core runtime. Safe to call multiple times.
    /// Throws if the runtime fails to create (e.g. ABI mismatch).
    public func boot() throws {
        if runtime != nil { return }
        let rt = try ReaderCoreNativeRuntime()
        runtime = rt
    }

    /// The shared runtime, or nil if `boot()` has not been called / failed.
    public var current: ReaderCoreNativeRuntime? { runtime }

    /// Whether the runtime is currently alive.
    public var isBooted: Bool { runtime != nil }

    /// Tear down the runtime. After this, all pending requests are cancelled.
    public func shutdown() {
        runtime?.destroy()
        runtime = nil
    }
}
