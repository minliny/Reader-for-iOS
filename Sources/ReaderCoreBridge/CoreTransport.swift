import Foundation
import ReaderCore

public enum CoreBridgeFailure: Error, Sendable {
    case unsupportedABI
    case native(operation: String, status: Int32, diagnostic: String)
    case invalidEvent
    case closed
    case endpointMismatch
}

final class CallbackSink: Sendable {
    private let continuation: AsyncStream<Data>.Continuation

    init(_ continuation: AsyncStream<Data>.Continuation) {
        self.continuation = continuation
    }

    func receive(_ bytes: UnsafePointer<UInt8>, count: Int) {
        // Core owns borrowed bytes until this callback returns.
        if case .terminated = continuation.yield(Data(bytes: bytes, count: count)) {
            // Termination belongs to shutdown; no live consumer can take this receipt.
            return
        }
    }

    func finish() { continuation.finish() }
}

private let coreEventCallback: @convention(c) (
    UnsafeMutableRawPointer?, UnsafePointer<UInt8>?, Int
) -> Void = { context, bytes, count in
    guard let context, let bytes, count > 0 else { return }
    Unmanaged<CallbackSink>.fromOpaque(context).takeUnretainedValue().receive(bytes, count: count)
}

/// Borrowed only by the runtime actor. The raw callback context stays valid
/// across native destruction, including a callback already in progress.
final class CoreTransport {
    private var handle: OpaquePointer?
    private let sink: CallbackSink

    init(config: ReaderRuntimeConfig, sink: CallbackSink) throws {
        self.sink = sink
        guard rc_abi_version() == 1, rc_runtime_delivery_capabilities() & 1 == 1 else {
            throw CoreBridgeFailure.unsupportedABI
        }
        let bytes = try JSONEncoder().encode(config)
        let status = bytes.withUnsafeBytes { raw in
            rc_runtime_create(
                raw.bindMemory(to: UInt8.self).baseAddress,
                raw.count, coreEventCallback,
                Unmanaged.passUnretained(sink).toOpaque(), &handle
            )
        }
        try Self.check(status, "rc_runtime_create")
        guard let handle else { throw CoreBridgeFailure.invalidEvent }
        do {
            try Self.check(rc_runtime_enable_event_ack(handle), "rc_runtime_enable_event_ack")
        } catch {
            destroy()
            throw error
        }
    }

    deinit { destroy() }

    func send(_ bytes: Data) throws {
        guard let handle else { throw CoreBridgeFailure.closed }
        let status = bytes.withUnsafeBytes { raw in
            rc_runtime_send(handle, raw.bindMemory(to: UInt8.self).baseAddress, raw.count)
        }
        try Self.check(status, "rc_runtime_send")
    }

    func cancel(_ id: Int64) throws {
        guard let handle else { throw CoreBridgeFailure.closed }
        try Self.check(rc_runtime_cancel(handle, UInt64(id)), "rc_runtime_cancel")
    }

    func acknowledge(_ id: Int64) throws {
        guard let handle else { throw CoreBridgeFailure.closed }
        let status = rc_runtime_ack_event(handle, UInt64(id))
        if status != 0 {
            throw CoreBridgeFailure.native(operation: "rc_runtime_ack_event", status: status,
                                           diagnostic: "deliveryId \(id)")
        }
    }

    func destroy() {
        guard let previous = handle else { return }
        handle = nil
        withExtendedLifetime(sink) { rc_runtime_destroy(previous) }
        sink.finish()
    }

    static func check(_ status: Int32, _ operation: String) throws {
        guard status != 0 else { return }
        var reason = [CChar](repeating: 0, count: 4096)
        _ = rc_last_error(&reason, reason.count)
        let bytes = reason.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
        throw CoreBridgeFailure.native(operation: operation, status: status,
                                       diagnostic: String(decoding: bytes, as: UTF8.self))
    }
}
