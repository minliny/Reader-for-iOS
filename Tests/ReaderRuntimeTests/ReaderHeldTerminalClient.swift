import Foundation
#if canImport(ReaderCoreClient)
import ReaderCoreClient
#endif
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

/// Scheduling decorator. Commands and terminal payloads still come from Core.
/// A fixture may override parameter forwarding for its explicit negative control.
class ReaderHeldTerminalClient: ReaderCoreEventClient, @unchecked Sendable {
    private let base: any ReaderCoreEventClient
    private let lock = NSLock()
    private let onTerminalHeld: () -> Void
    private var methods: [String: Int] = [:]
    private var parameters: [String: [String: Any]] = [:]
    private var heldMethod: String?
    private var heldID: UInt64?
    private var held: Result<ReaderCoreEvent, ReaderCoreClientError>?
    private var released = false
    private var clock: TimeInterval = 0

    init(base: any ReaderCoreEventClient, onTerminalHeld: @escaping () -> Void = {}) {
        self.base = base; self.onTerminalHeld = onTerminalHeld
    }
    final func withHeldLock<T>(_ action: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }; return try action()
    }
    var now: TimeInterval { withHeldLock { clock } }
    var terminal: ReaderCoreEvent? {
        withHeldLock { if case .success(let event)? = held { return event }; return nil }
    }
    func hold(_ method: String, requireEmpty: Bool = false) {
        withHeldLock {
            if requireEmpty {
                precondition(heldID == nil && held == nil)
                released = false
            }
            heldMethod = method
        }
    }
    func release(requireHeld: Bool = false) {
        withHeldLock {
            if requireHeld { precondition(held != nil, "The test must first capture an actual terminal reply") }
            released = true
        }
    }
    func count(_ method: String) -> Int { withHeldLock { methods[method, default: 0] } }
    func lastParameters(_ method: String) -> [String: Any]? { withHeldLock { parameters[method] } }
    // Called under the same lock as forwarding and observation.
    func forwardedParameters(method: String, params: [String: Any]) -> [String: Any] { params }

    @discardableResult
    func send(method: String, requestId: UInt64, params: [String: Any]) throws -> UInt64 {
        try withHeldLock {
            let result = try base.send(method: method, requestId: requestId,
                                       params: forwardedParameters(method: method, params: params))
            methods[method, default: 0] += 1; parameters[method] = params
            if method == heldMethod && heldID == nil { heldID = requestId }
            return result
        }
    }
    func pollEvent(requestId: UInt64) -> Result<ReaderCoreEvent, ReaderCoreClientError>? {
        withHeldLock {
            guard requestId == heldID else { return base.pollEvent(requestId: requestId) }
            if held == nil, let reply = base.pollEvent(requestId: requestId) {
                if case .success(let event) = reply, ["result", "error"].contains(event.type) {
                    held = reply; clock += 200; onTerminalHeld()
                } else { return reply }
            }
            guard released, let reply = held else { return nil }
            held = nil; heldID = nil; heldMethod = nil; released = false
            return reply
        }
    }
    func cancel(requestId: UInt64) throws { try withHeldLock { try base.cancel(requestId: requestId) } }
    func destroy() { withHeldLock { base.destroy() } }
}
