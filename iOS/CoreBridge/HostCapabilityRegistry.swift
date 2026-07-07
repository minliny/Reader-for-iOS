// CoreBridge
//
// HostCapabilityRegistry — UI/reducer-side Host capability dispatch.
//
// The contract `HostRequest` (from `ReaderUIContract`) is produced by the UI
// layer or the reducer. Unlike Core-initiated `host.request` events (which are
// routed by `HostRequestRouter` via the C ABI), UI/reducer-initiated requests
// carry a typed `HostRequestType` enum and an `AnyCodable` payload, and never
// touch the runtime's JSON event channel.
//
// This registry closes the UI/Reducer → Host capability path:
// 1. Each `HostCapabilityHandler` advertises the `HostRequestType` cases it
//    supports and a `HostCapabilityTier` (simulator-proof / real-device-proof
//    / cross-platform).
// 2. `HostCapabilityRegistry` indexes handlers by type and dispatches a
//    `HostRequest` to the matching handler.
// 3. `HostAdapter.send(_:)` becomes a thin facade over the registry — it no
//    longer returns `false` for every capability.
//
// Boundary: this file lives in `iOS/CoreBridge/` (Core imports allowed). It
// imports only `Foundation` + `ReaderUIContract` so it stays portable across
// the `ReaderShellValidation` and `ReaderApp` targets.

import Foundation
import ReaderUIContract

/// Tier classification for a Host capability handler.
///
/// Used by `HostAdapterRealDeviceProofManifestTests` to assert which
/// capabilities can be exercised on the simulator vs which require a real
/// device. The split is critical for capabilities that depend on UIKit /
//  WKWebView / AVFoundation / UserNotifications / AVAudioSession in ways the
/// simulator does not fully emulate.
public enum HostCapabilityTier: String, Sendable, CaseIterable {
    /// Verifiable on macOS `swift build` / `swift test` (pure logic, no UIKit).
    /// Examples: `cookie.get/set/clear`, `clipboard.copy/paste` (via
    /// `NSPasteboard` on macOS), `credential.get/set/delete` (Keychain stub).
    case crossPlatform

    /// Verifiable on the iOS simulator but not on macOS `swift build`.
    /// Examples: `http.execute` (URLSession live network), `file.read/write`
    /// (app sandbox paths), `share.invoke` (UIActivityViewController on sim),
    /// `device.vibrate` (sim haptic), `notification.show` (UNUserNotificationCenter
    /// on sim).
    case simulatorProof

    /// Requires a real device to fully exercise. The simulator may load the
    /// code path but the proof is incomplete (e.g. WKWebView anti-bot JS
    /// challenge solving behaves differently on sim because the user-agent
    /// and JIT differ; AVSpeechSynthesizer TTS works on sim but voice
    /// availability differs; background tasks are killed aggressively on sim;
    /// screen keep-on has no effect on sim display).
    case realDeviceProof
}

/// Structured error returned by a `HostCapabilityHandler` or by the registry
/// when a capability cannot be executed.
public enum HostCapabilityError: Error, Equatable, Sendable {
    /// No handler registered for this `HostRequestType`. Fail-closed signal —
    /// the UI sees `succeeded=false` and can surface a "capability not
    /// available" message.
    case notConfigured(HostRequestType)

    /// Handler is registered but the platform does not support the capability
    /// (e.g. `WKWebViewExecutor` on macOS `swift build`, or `device.vibrate`
    /// on a device without haptics). Distinct from `notConfigured` so the UI
    /// can distinguish "not wired" from "wired but unavailable on this
    /// platform".
    case notImplemented(HostRequestType, String)

    /// Handler rejected the payload (missing required field, invalid type,
    /// out-of-range value). The associated message is suitable for developer
    /// diagnostics, not user-facing copy.
    case invalidParams(String)

    /// Handler threw an underlying error. The message is the original error's
    /// `localizedDescription`.
    case underlying(String)
}

/// Outcome of dispatching a `HostRequest` to a `HostCapabilityHandler`.
///
/// `result` carries the handler's structured response (encoded as
/// `[String: AnyCodable]` so it round-trips through the contract layer).
/// `error` is non-nil when `succeeded == false`.
public struct HostCapabilityOutcome: Sendable, Equatable {
    public let succeeded: Bool
    public let result: [String: AnyCodable]?
    public let error: HostCapabilityError?

    public init(succeeded: Bool, result: [String: AnyCodable]? = nil, error: HostCapabilityError? = nil) {
        self.succeeded = succeeded
        self.result = result
        self.error = error
    }

    /// Convenience for a successful outcome with a result dict.
    public static func success(_ result: [String: AnyCodable] = [:]) -> HostCapabilityOutcome {
        HostCapabilityOutcome(succeeded: true, result: result, error: nil)
    }

    /// Convenience for a failure outcome with an error.
    public static func failure(_ error: HostCapabilityError) -> HostCapabilityOutcome {
        HostCapabilityOutcome(succeeded: false, result: nil, error: error)
    }
}

/// A handler for one or more `HostRequestType` cases.
///
/// Implementations live alongside the registry in `iOS/CoreBridge/`:
/// - `HostHttpCapability` — `http.execute`, `http.cancel` (bridges to
///   `URLSessionHTTPClient` via the existing `HTTPClient` protocol).
/// - `HostWebViewCapability` — `webview.open`, `webview.close`,
///   `webview.evaluate` (bridges to `WKWebViewExecutor`).
/// - `HostCookieCapability` — `cookie.get/set/clear` (bridges to
///   `ScopedCookieJar`).
/// - `HostFileCapability`, `HostCredentialCapability`, `HostTTSCapability`,
///   `HostPermissionCapability`, `HostNotificationCapability`,
///   `HostShareCapability`, `HostClipboardCapability`, `HostDeviceCapability`.
///
/// Handlers MUST be `Sendable` (they are stored in the registry which is
/// accessed from the main actor and from reducer-driven async contexts).
/// Handlers that wrap non-Sendable system APIs (e.g. `WKWebView`,
/// `AVSpeechSynthesizer`) use `@unchecked Sendable` and confine mutation to
/// the main actor inside `handle(_:)`.
public protocol HostCapabilityHandler: Sendable {
    /// The set of `HostRequestType` cases this handler accepts. Requests for
    /// any other type are routed to a different handler (or fail with
    /// `.notConfigured` if no handler claims them).
    var supportedTypes: Set<HostRequestType> { get }

    /// Tier classification for proof-test routing. A handler that supports
    /// multiple types MUST report the highest tier needed across those types
    /// (i.e. `realDeviceProof` if any type requires a device).
    var tier: HostCapabilityTier { get }

    /// Execute the request. Implementations SHOULD:
    /// - Return `HostCapabilityOutcome.success([...])` on success.
    /// - Return `HostCapabilityOutcome.failure(.invalidParams(...))` for
    ///   payload validation failures (do not throw).
    /// - Throw `HostCapabilityError.notImplemented` only when the platform
    ///   cannot support the capability at all (the registry converts the
    ///   throw into a `.failure` outcome).
    /// - Throw other errors only for unrecoverable underlying failures; the
    ///   registry wraps them in `.underlying(message)`.
    func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome
}

/// Registry of `HostCapabilityHandler`s, indexed by `HostRequestType`.
///
/// `HostAdapter` owns one registry instance and dispatches every UI/reducer
/// `HostRequest` through it. The registry is `@unchecked Sendable` because
/// mutation (`register`) is confined to setup (before any dispatch); once
/// constructed, the registry is effectively immutable. Tests that need to
/// mutate after dispatch use a fresh registry.
public final class HostCapabilityRegistry: @unchecked Sendable {
    /// Handlers indexed by the types they claim. If a handler claims multiple
    /// types, all of them map to the same handler instance. Guarded by an
    /// `NSLock` so `register` (setup-time) and `handler(for:)` / `dispatch`
    /// (runtime) can race safely if a test mutates after construction.
    private let handlers = LockedBox<[HostRequestType: HostCapabilityHandler]>([:])

    public init() {}

    /// Register a handler. All `supportedTypes` are mapped to this handler.
    /// A later registration for an already-registered type replaces the
    /// earlier handler for that type (last-writer-wins).
    public func register(_ handler: HostCapabilityHandler) {
        handlers.withLock { store in
            for type in handler.supportedTypes {
                store[type] = handler
            }
        }
    }

    /// Look up the handler registered for `type`, or nil if none.
    public func handler(for type: HostRequestType) -> HostCapabilityHandler? {
        handlers.withLock { $0[type] }
    }

    /// All types currently registered (unordered).
    public func registeredTypes() -> Set<HostRequestType> {
        Set(handlers.withLock { $0.keys })
    }

    /// Dispatch `request` to the matching handler. If no handler is
    /// registered for `request.type`, returns
    /// `.failure(.notConfigured(request.type))` (fail-closed — the UI can
    /// surface a "capability not available" message).
    ///
    /// Handler throws are converted to `.failure` outcomes:
    /// - `HostCapabilityError` → returned as-is.
    /// - Other errors → wrapped in `.underlying(error.localizedDescription)`.
    public func dispatch(_ request: HostRequest) async -> HostCapabilityOutcome {
        guard let handler = handler(for: request.type) else {
            return .failure(.notConfigured(request.type))
        }
        do {
            return try await handler.handle(request)
        } catch let error as HostCapabilityError {
            return .failure(error)
        } catch {
            return .failure(.underlying(error.localizedDescription))
        }
    }

    /// Tier for a registered type, or nil if the type is not registered.
    public func tier(for type: HostRequestType) -> HostCapabilityTier? {
        handler(for: type)?.tier
    }
}

/// Lock-protected mutable value. `NSLock` is used (not `os_unfair_lock`)
/// because the registry is rarely contended — registration is setup-time
/// only, and dispatch reads the handler map once. The wrapper is
/// `@unchecked Sendable` because all access goes through `withLock`.
private final class LockedBox<T>: @unchecked Sendable {
    private var _value: T
    private let lock = NSLock()

    init(_ value: T) {
        self._value = value
    }

    func withLock<R>(_ body: (inout T) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try body(&_value)
    }
}
