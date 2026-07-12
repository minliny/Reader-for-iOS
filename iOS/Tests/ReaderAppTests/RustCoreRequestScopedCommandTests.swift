import XCTest
import ReaderCoreNativeAdapter
@testable import ReaderShellValidation

final class RustCoreRequestScopedCommandTests: XCTestCase {
    func testCancelBindsCoreAndTransportAndDiscardsLateResult() async throws {
        let runtime = FakeCommandRuntime()
        let router = FakeHostRouter()
        let requestID: UInt64 = 91
        runtime.events[requestID] = [try resultEvent(requestID: requestID, data: ["value": "late"])]

        let command = try RustCoreRequestScopedCommand<String>(
            runtime: runtime,
            router: router,
            requestID: requestID,
            correlationID: "replace-a",
            method: "book.detail",
            params: [:],
            resultTransform: { data in data?["value"] as? String ?? "" }
        )
        try command.start()

        XCTAssertTrue(command.cancel())
        XCTAssertEqual(runtime.cancelledRequestIDs, [requestID])
        XCTAssertEqual(router.cancelledTransportIDs, ["core:replace-a:91"])

        do {
            _ = try await command.value()
            XCTFail("a cancelled correlation must not return a late result")
        } catch is CancellationError {
            // Expected: typed transform is never allowed to observe stale data.
        }
    }

    func testHostRequestUsesScopedTransportIDBeforeTerminalResult() async throws {
        let runtime = FakeCommandRuntime()
        let router = FakeHostRouter()
        let requestID: UInt64 = 92
        runtime.events[requestID] = [
            try hostRequestEvent(requestID: requestID),
            try resultEvent(requestID: requestID, data: ["value": "fresh"]),
        ]

        let command = try RustCoreRequestScopedCommand<String>(
            runtime: runtime,
            router: router,
            requestID: requestID,
            correlationID: "open-b",
            method: "book.detail",
            params: [:],
            resultTransform: { data in data?["value"] as? String ?? "" }
        )
        try command.start()

        let value = try await command.value()
        XCTAssertEqual(value, "fresh")
        XCTAssertEqual(router.handledTransportIDs, ["core:open-b:92"])
        XCTAssertEqual(router.discardChecks, [false])
        XCTAssertEqual(runtime.cancelledRequestIDs, [])
    }

    func testRequestIDsAndTransportIDsAreUniquePerCorrelation() {
        let first = RustCoreServiceSupport.allocateRequestID()
        let second = RustCoreServiceSupport.allocateRequestID()
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(
            RustCoreServiceSupport.transportRequestID(correlationID: "open-1", requestID: first),
            "core:open-1:\(first)"
        )
        XCTAssertEqual(
            RustCoreServiceSupport.transportRequestID(correlationID: nil, requestID: second),
            "core:unscoped:\(second)"
        )
    }

    private func resultEvent(requestID: UInt64, data: [String: Any]) throws -> ReaderCoreNativeEvent {
        try event([
            "type": "result",
            "requestId": NSNumber(value: requestID),
            "data": data,
        ])
    }

    private func hostRequestEvent(requestID: UInt64) throws -> ReaderCoreNativeEvent {
        try event([
            "type": "host.request",
            "requestId": NSNumber(value: requestID),
            "operationId": NSNumber(value: requestID),
            "capability": "http.execute",
            "params": ["url": "https://example.test/"],
        ])
    }

    private func event(_ object: [String: Any]) throws -> ReaderCoreNativeEvent {
        try ReaderCoreNativeEvent(data: JSONSerialization.data(withJSONObject: object))
    }
}

private final class FakeCommandRuntime: RustCoreCommandRuntime {
    var events: [UInt64: [ReaderCoreNativeEvent]] = [:]
    var sentPayloads: [Data] = []
    var cancelledRequestIDs: [UInt64] = []

    @discardableResult
    func send(json: Data) throws -> Int32 {
        sentPayloads.append(json)
        return 0
    }

    func pollEvent(requestId: UInt64) -> ReaderCoreNativeEvent? {
        guard var queued = events[requestId], !queued.isEmpty else { return nil }
        let next = queued.removeFirst()
        events[requestId] = queued
        return next
    }

    func cancel(requestId: UInt64) throws {
        cancelledRequestIDs.append(requestId)
    }
}

private final class FakeHostRouter: RustCoreHostRequestRouting {
    var handledTransportIDs: [String] = []
    var cancelledTransportIDs: [String] = []
    var discardChecks: [Bool] = []

    func handleHostRequest(
        _ event: ReaderCoreNativeEvent,
        transportRequestID: String?,
        shouldDiscard: @escaping @Sendable () -> Bool
    ) async throws {
        handledTransportIDs.append(transportRequestID ?? "")
        discardChecks.append(shouldDiscard())
    }

    @discardableResult
    func cancelHTTPTransport(requestID: String) -> Bool {
        cancelledTransportIDs.append(requestID)
        return true
    }
}
