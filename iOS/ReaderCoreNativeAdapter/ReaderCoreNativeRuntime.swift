// ReaderCoreNativeAdapter
//
// Host adapter that connects the Reader for iOS app to the Rust Reader-Core-Native
// via its C ABI (ReaderCore.xcframework, `reader_core.h`).
//
// This is the app-side bridge: it owns the runtime handle, serializes commands to
// JSON, drains events from the Core-owned callback thread into a thread-safe
// buffer, and exposes the ABI/protocol surface to the rest of the app.
//
// Round 1 scope: ABI connectivity only — runtime lifecycle (create/send/cancel/
// destroy), event polling, core.info / runtime.ping. Service-protocol backing
// (SearchService/TOCService/ContentService) comes in later rounds.
//
// Evidence discipline: this adapter is exercised by ShellSmokeTests with
// [core] / [app-side] partitioning. Wrapper smoke ≠ device completion.

import Foundation
#if canImport(ReaderCore)
import ReaderCore
#endif

/// Errors surfaced by the native adapter.
public enum ReaderCoreNativeError: Error, Equatable {
    case createFailed(Int32)
    case sendFailed(Int32)
    case cancelFailed(Int32)
    case runtimeDestroyed
    case requestTimedOut(UInt64)
    case coreError(code: String, message: String)
    case invalidEventJSON
}

/// A single Core event, parsed from the JSON the callback delivered.
public struct ReaderCoreNativeEvent: Equatable {
    public let rawData: Data
    public let object: [String: Any]

    public init(data: Data) throws {
        let value = try? JSONSerialization.jsonObject(with: data)
        guard let object = value as? [String: Any] else {
            throw ReaderCoreNativeError.invalidEventJSON
        }
        self.rawData = data
        self.object = object
    }

    public var type: String { object["type"] as? String ?? "" }
    public var requestId: UInt64? {
        (object["requestId"] as? NSNumber)?.uint64Value
    }
    public var data: [String: Any]? { object["data"] as? [String: Any] }
    public var errorObject: [String: Any]? { object["error"] as? [String: Any] }

    public var coreErrorCode: String? { errorObject?["code"] as? String }
    public var coreErrorMessage: String? { errorObject?["message"] as? String }

    public static func == (lhs: ReaderCoreNativeEvent, rhs: ReaderCoreNativeEvent) -> Bool {
        lhs.rawData == rhs.rawData
    }
}

/// Thread-safe event buffer drained from the Core callback thread.
final class ReaderCoreNativeEventBuffer {
    private let lock = NSLock()
    private var events: [UInt64: [Data]] = [:]

    func append(_ data: Data, requestId: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        events[requestId, default: []].append(data)
    }

    /// Blocking wait for the next event for `requestId`.
    func wait(requestId: UInt64, timeout: TimeInterval) throws -> ReaderCoreNativeEvent {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            lock.lock()
            let queue = events[requestId]
            if let next = queue?.first {
                events[requestId]?.removeFirst()
                lock.unlock()
                return try ReaderCoreNativeEvent(data: next)
            }
            let remaining = deadline.timeIntervalSinceNow
            lock.unlock()
            if remaining <= 0 {
                throw ReaderCoreNativeError.requestTimedOut(requestId)
            }
            // Short sleep before re-checking; the callback thread signals via queue growth.
            Thread.sleep(forTimeInterval: min(0.01, remaining))
        }
    }

    /// Non-blocking poll: returns the next event for `requestId` or nil.
    func poll(requestId: UInt64) -> ReaderCoreNativeEvent? {
        lock.lock()
        defer { lock.unlock() }
        guard let next = events[requestId]?.first else { return nil }
        events[requestId]?.removeFirst()
        return try? ReaderCoreNativeEvent(data: next)
    }
}

/// The native runtime handle wrapper.
public final class ReaderCoreNativeRuntime: @unchecked Sendable {
    public static var abiVersion: UInt32 {
        rc_abi_version()
    }

    private var handle: OpaquePointer?
    private let buffer = ReaderCoreNativeEventBuffer()

    public init(configJSON: Data = Data()) throws {
        let context = Unmanaged.passUnretained(self).toOpaque()
        var out: OpaquePointer?
        let status = configJSON.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Int32 in
            let base = raw.bindMemory(to: UInt8.self).baseAddress
            return rc_runtime_create(base, raw.count, { ctx, json, len in
                guard let ctx, let json else { return }
                let runtime = Unmanaged<ReaderCoreNativeRuntime>.fromOpaque(ctx).takeUnretainedValue()
                let data = Data(bytes: json, count: len)
                // requestId is parsed from the event JSON; buffer keyed by it.
                if let requestId = ReaderCoreNativeRuntime.requestId(of: data) {
                    runtime.buffer.append(data, requestId: requestId)
                }
            }, context, &out)
        }
        guard status == 0, let out else {
            throw ReaderCoreNativeError.createFailed(status)
        }
        self.handle = out
    }

    deinit { destroy() }

    public func destroy() {
        guard let handle else { return }
        rc_runtime_destroy(handle)
        self.handle = nil
    }

    @discardableResult
    public func send(json: Data) throws -> Int32 {
        guard let handle else { throw ReaderCoreNativeError.runtimeDestroyed }
        let status = json.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Int32 in
            let base = raw.bindMemory(to: UInt8.self).baseAddress
            return rc_runtime_send(handle, base, raw.count)
        }
        guard status == 0 else { throw ReaderCoreNativeError.sendFailed(status) }
        return status
    }

    @discardableResult
    public func send(jsonString: String) throws -> Int32 {
        guard let data = jsonString.data(using: .utf8) else {
            throw ReaderCoreNativeError.sendFailed(-1)
        }
        return try send(json: data)
    }

    public func cancel(requestId: UInt64) throws {
        guard let handle else { throw ReaderCoreNativeError.runtimeDestroyed }
        let status = rc_runtime_cancel(handle, requestId)
        guard status == 0 else { throw ReaderCoreNativeError.cancelFailed(status) }
    }

    /// Blocking wait for the next event for `requestId`.
    public func waitForEvent(requestId: UInt64, timeout: TimeInterval = 5) throws -> ReaderCoreNativeEvent {
        try buffer.wait(requestId: requestId, timeout: timeout)
    }

    /// Non-blocking poll.
    public func pollEvent(requestId: UInt64) -> ReaderCoreNativeEvent? {
        buffer.poll(requestId: requestId)
    }

    private static func requestId(of data: Data) -> UInt64? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return (object["requestId"] as? NSNumber)?.uint64Value
    }
}

/// High-level convenience: send a command and wait for its resolved event.
public extension ReaderCoreNativeRuntime {
    @discardableResult
    func request(method: String, requestId: UInt64, params: [String: Any] = [:], timeout: TimeInterval = 5) throws -> ReaderCoreNativeEvent {
        let command: [String: Any] = [
            "protocolVersion": 1,
            "requestId": NSNumber(value: requestId),
            "method": method,
            "params": params,
        ]
        let json = try JSONSerialization.data(withJSONObject: command)
        try send(json: json)
        let event = try waitForEvent(requestId: requestId, timeout: timeout)
        if event.type == "error" {
            throw ReaderCoreNativeError.coreError(
                code: event.coreErrorCode ?? "INTERNAL",
                message: event.coreErrorMessage ?? ""
            )
        }
        return event
    }
}
