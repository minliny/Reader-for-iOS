import XCTest
import ReaderCoreNativeAdapter
@testable import ReaderShellValidation

final class RustCoreAggregateStorageServiceTests: XCTestCase {
    func testRestoreAndFlushUseExactRuntimeStorageCommands() async throws {
        let runtime = FakeAggregateStorageRuntime()
        let service = RustCoreAggregateStorageService(
            runtime: runtime,
            router: NoopAggregateStorageRouter(),
            requestTimeout: 1
        )

        let restored = try await service.restore(correlationID: "restore")
        let flushed = try await service.flush(correlationID: "flush")

        XCTAssertEqual(runtime.methods, ["runtime.storage.restore", "runtime.storage.flush"])
        XCTAssertTrue(restored.restoredExistingSnapshot)
        XCTAssertEqual(restored.revision, "rev-3")
        XCTAssertEqual(restored.schemaVersion, 1)
        XCTAssertTrue(flushed.stored)
        XCTAssertEqual(flushed.revision, "rev-4")
        XCTAssertEqual(flushed.schemaVersion, 1)
        for command in runtime.commands {
            XCTAssertEqual((command["params"] as? [String: Any])?.count, 0)
        }
    }

    @MainActor
    func testStorageGateRejectsDuplicateBootstrapAndTracksTerminalState() throws {
        ReaderCoreAggregateStorageGate.resetForTests()
        defer { ReaderCoreAggregateStorageGate.resetForTests() }

        try ReaderCoreAggregateStorageGate.beginRestore()
        XCTAssertEqual(ReaderCoreAggregateStorageGate.state, .restoring)
        XCTAssertThrowsError(try ReaderCoreAggregateStorageGate.beginRestore()) { error in
            XCTAssertEqual((error as? ReaderSlice10CoreServiceError)?.code, "SLICE10_STORAGE_BOOTSTRAP_DUPLICATE")
        }
        ReaderCoreAggregateStorageGate.complete(
            .init(restoredExistingSnapshot: true, revision: "rev", schemaVersion: 1)
        )
        XCTAssertTrue(ReaderCoreAggregateStorageGate.isReady)
    }
}

private final class FakeAggregateStorageRuntime: RustCoreCommandRuntime {
    private var events: [UInt64: ReaderCoreNativeEvent] = [:]
    var commands: [[String: Any]] = []
    var methods: [String] { commands.compactMap { $0["method"] as? String } }

    @discardableResult
    func send(json: Data) throws -> Int32 {
        let command = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        commands.append(command)
        let requestID = try XCTUnwrap((command["requestId"] as? NSNumber)?.uint64Value)
        let method = try XCTUnwrap(command["method"] as? String)
        let result: [String: Any]
        switch method {
        case "runtime.storage.restore":
            result = ["restored": true, "revision": "rev-3", "schemaVersion": 1]
        case "runtime.storage.flush":
            result = ["stored": true, "revision": "rev-4", "schemaVersion": 1]
        default:
            XCTFail("unexpected method \(method)")
            result = [:]
        }
        events[requestID] = try ReaderCoreNativeEvent(data: JSONSerialization.data(withJSONObject: [
            "type": "result", "requestId": NSNumber(value: requestID), "data": result,
        ]))
        return 0
    }

    func pollEvent(requestId: UInt64) -> ReaderCoreNativeEvent? {
        events.removeValue(forKey: requestId)
    }

    func cancel(requestId: UInt64) throws {}
}

private final class NoopAggregateStorageRouter: RustCoreHostRequestRouting {
    func handleHostRequest(
        _ event: ReaderCoreNativeEvent,
        transportRequestID: String?,
        shouldDiscard: @escaping @Sendable () -> Bool
    ) async throws {}

    @discardableResult
    func cancelHTTPTransport(requestID: String) -> Bool { true }
}
