import Foundation
import ReaderCoreNativeAdapter

/// Small abstraction around the C-ABI runtime used by request-scoped commands.
/// It is deliberately narrower than `ReaderCoreNativeRuntime` so cancellation
/// and stale-callback behavior can be tested without a live Core instance.
public protocol RustCoreCommandRuntime: AnyObject {
    @discardableResult func send(json: Data) throws -> Int32
    func pollEvent(requestId: UInt64) -> ReaderCoreNativeEvent?
    func cancel(requestId: UInt64) throws
}

extension ReaderCoreNativeRuntime: RustCoreCommandRuntime {}

/// The Host half of a request-scoped Core command. The Core request id and the
/// URLSession transport id intentionally stay independent: Core owns the
/// former, while the Host owns the latter.
public protocol RustCoreHostRequestRouting {
    func handleHostRequest(
        _ event: ReaderCoreNativeEvent,
        transportRequestID: String?,
        shouldDiscard: @escaping @Sendable () -> Bool
    ) async throws

    @discardableResult func cancelHTTPTransport(requestID: String) -> Bool
}

extension HostRequestRouter: RustCoreHostRequestRouting {}

/// One numeric Core command together with the Host transport work it may
/// trigger. A command is started once, awaited once or more safely, and can be
/// cancelled from a correlation replacement or a Swift task cancellation.
///
/// Cancellation is deliberately fail-closed:
/// - `rc_runtime_cancel(requestId)` invalidates Core's pending operation;
/// - the request-scoped URLSession task is cancelled if present;
/// - HostRequestRouter receives `shouldDiscard` and never sends a late
///   host.complete/host.error back into a cancelled Core operation;
/// - a late Core event is ignored by `value()` before it reaches the typed
///   result parser.
public final class RustCoreRequestScopedCommand<Value: Sendable>: @unchecked Sendable {
    public let requestID: UInt64
    public let correlationID: String?
    public let transportRequestID: String

    private enum Lifecycle {
        case prepared
        case pending
        case cancelled
        case completed
    }

    private let runtime: any RustCoreCommandRuntime
    private let router: (any RustCoreHostRequestRouting)?
    private let commandData: Data
    private let timeout: TimeInterval
    private let resultTransform: ([String: Any]?) throws -> Value
    private let lock = NSLock()
    private var lifecycle: Lifecycle = .prepared

    public init(
        runtime: any RustCoreCommandRuntime,
        router: (any RustCoreHostRequestRouting)? = nil,
        requestID: UInt64,
        correlationID: String? = nil,
        method: String,
        params: [String: Any],
        timeout: TimeInterval = 15,
        resultTransform: @escaping ([String: Any]?) throws -> Value
    ) throws {
        self.runtime = runtime
        self.router = router
        self.requestID = requestID
        self.correlationID = correlationID
        self.transportRequestID = RustCoreServiceSupport.transportRequestID(
            correlationID: correlationID,
            requestID: requestID
        )
        self.timeout = timeout
        self.resultTransform = resultTransform
        self.commandData = try JSONSerialization.data(withJSONObject: [
            "protocolVersion": 1,
            "requestId": NSNumber(value: requestID),
            "method": method,
            "params": params,
        ])
    }

    /// Sends the Core command exactly once. Calling `value()` before this
    /// method is a programming error and fails closed.
    public func start() throws {
        lock.lock()
        guard lifecycle == .prepared else {
            lock.unlock()
            throw ReaderCoreNativeError.sendFailed(-1)
        }
        lifecycle = .pending
        lock.unlock()

        do {
            try runtime.send(json: commandData)
        } catch {
            markCompletedUnlessCancelled()
            throw error
        }
    }

    /// Await the typed Core result. Task cancellation is bridged to the same
    /// Core + Host cancellation path as an explicit correlation replacement.
    public func value() async throws -> Value {
        try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await awaitTerminalResult()
        }, onCancel: {
            _ = self.cancel()
        })
    }

    /// Idempotently cancels the Core command and any registered URLSession
    /// transport. `false` means the command had already reached a terminal
    /// state, not that cancellation failed.
    @discardableResult
    public func cancel() -> Bool {
        lock.lock()
        guard lifecycle == .pending || lifecycle == .prepared else {
            lock.unlock()
            return false
        }
        lifecycle = .cancelled
        lock.unlock()

        _ = router?.cancelHTTPTransport(requestID: transportRequestID)
        // Core cancellation is intentionally best-effort here. The lifecycle
        // has already been invalidated, so a race with a terminal event can
        // never revive this command or write its late result into the domain.
        try? runtime.cancel(requestId: requestID)
        return true
    }

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return lifecycle == .cancelled
    }

    private func awaitTerminalResult() async throws -> Value {
        guard isPending else {
            if isCancelled { throw CancellationError() }
            throw ReaderCoreNativeError.sendFailed(-1)
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try Task.checkCancellation()
            if isCancelled { throw CancellationError() }

            if let event = runtime.pollEvent(requestId: requestID) {
                switch event.type {
                case "host.request":
                    guard let router else {
                        throw ReaderCoreNativeError.coreError(
                            code: "HOST_ROUTER_MISSING",
                            message: "Core command \(requestID) emitted host.request without a router"
                        )
                    }
                    try await router.handleHostRequest(
                        event,
                        transportRequestID: transportRequestID,
                        shouldDiscard: { [weak self] in self?.isCancelled ?? true }
                    )
                    if isCancelled { throw CancellationError() }

                case "result":
                    if isCancelled { throw CancellationError() }
                    do {
                        let value = try resultTransform(event.data)
                        markCompletedUnlessCancelled()
                        if isCancelled { throw CancellationError() }
                        return value
                    } catch {
                        markCompletedUnlessCancelled()
                        throw error
                    }

                case "error":
                    markCompletedUnlessCancelled()
                    if isCancelled { throw CancellationError() }
                    throw ReaderCoreNativeError.coreError(
                        code: event.coreErrorCode ?? "INTERNAL",
                        message: event.coreErrorMessage ?? "Core request \(requestID) failed"
                    )

                default:
                    // Core events are request-id scoped. Ignore diagnostics or
                    // future non-terminal event types until a terminal event.
                    continue
                }
            }

            try await Task.sleep(nanoseconds: 5_000_000)
        }

        if isCancelled { throw CancellationError() }
        markCompletedUnlessCancelled()
        throw ReaderCoreNativeError.requestTimedOut(requestID)
    }

    private var isPending: Bool {
        lock.lock()
        defer { lock.unlock() }
        return lifecycle == .pending
    }

    private func markCompletedUnlessCancelled() {
        lock.lock()
        defer { lock.unlock() }
        guard lifecycle != .cancelled else { return }
        lifecycle = .completed
    }
}
