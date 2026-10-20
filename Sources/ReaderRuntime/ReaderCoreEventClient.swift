import Foundation
#if canImport(ReaderCoreClient)
import ReaderCoreClient
#endif

/// Runtime-owned seam for retaining the exact Core reply. It does not alter
/// commands or replace Core business behavior; tests can delay an original ACK.
protocol ReaderCoreEventClient: AnyObject {
    @discardableResult
    func send(method: String, requestId: UInt64, params: [String: Any]) throws -> UInt64
    func pollEvent(requestId: UInt64) -> Result<ReaderCoreEvent, ReaderCoreClientError>?
    func cancel(requestId: UInt64) throws
    func destroy()
}

extension ReaderCoreClient: ReaderCoreEventClient {}

struct ReaderRequestTiming: Sendable {
    var now: @Sendable () -> TimeInterval
    var suspend: @Sendable () async -> Void

    static let live = ReaderRequestTiming(now: { ProcessInfo.processInfo.systemUptime }, suspend: {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .milliseconds(5)) {
                continuation.resume()
            }
        }
    })
}
