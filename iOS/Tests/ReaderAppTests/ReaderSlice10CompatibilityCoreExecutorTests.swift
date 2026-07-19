import XCTest
import ReaderCoreNativeAdapter
import ReaderUIRuntime
@testable import ReaderShellValidation
@testable import ReaderApp

final class ReaderSlice10CompatibilityCoreExecutorTests: XCTestCase {
    @MainActor
    func testReplaceApplyAndSourceRollbackPreserveExactMethodsAndJSONPayloads() async throws {
        let runtime = FakeSlice10CompatibilityRuntime()
        let executor = ReaderSlice10CompatibilityCoreExecutor(runtime: runtime, requestTimeout: 1)

        let replacePayload: ReaderUIJSONPayload = [
            "ruleId": .number(7),
            "settings": .object(["regex": .bool(true), "pattern": .string("\\s+")]),
        ]
        let rollbackPayload: ReaderUIJSONPayload = [
            "rollbackToken": .string("rollback-1"),
            "reason": .string("user"),
        ]
        let replaceResult = try await executor.executeApply(
            payload: replacePayload,
            correlationID: "replace-7"
        )
        let rollbackResult = try await executor.executeRollback(
            payload: rollbackPayload,
            correlationID: "source-rollback"
        )

        XCTAssertEqual(runtime.methods, ["replace.apply", "source.switch.rollback"])
        XCTAssertEqual(replaceResult["accepted"]?.boolValue, true)
        XCTAssertEqual(rollbackResult["accepted"]?.boolValue, true)

        let replaceParams = try XCTUnwrap(runtime.command(method: "replace.apply")?["params"] as? [String: Any])
        XCTAssertEqual((replaceParams["ruleId"] as? NSNumber)?.intValue, 7)
        let settings = try XCTUnwrap(replaceParams["settings"] as? [String: Any])
        XCTAssertEqual(settings["regex"] as? Bool, true)
        XCTAssertEqual(settings["pattern"] as? String, "\\s+")

        let rollbackParams = try XCTUnwrap(runtime.command(method: "source.switch.rollback")?["params"] as? [String: Any])
        XCTAssertEqual(rollbackParams["rollbackToken"] as? String, "rollback-1")
        XCTAssertEqual(rollbackParams["reason"] as? String, "user")
    }
}

private final class FakeSlice10CompatibilityRuntime: RustCoreCommandRuntime {
    private var events: [UInt64: ReaderCoreNativeEvent] = [:]
    var commands: [[String: Any]] = []
    var methods: [String] { commands.compactMap { $0["method"] as? String } }

    @discardableResult
    func send(json: Data) throws -> Int32 {
        let command = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        commands.append(command)
        let requestID = try XCTUnwrap((command["requestId"] as? NSNumber)?.uint64Value)
        events[requestID] = try ReaderCoreNativeEvent(data: JSONSerialization.data(withJSONObject: [
            "type": "result",
            "requestId": NSNumber(value: requestID),
            "data": ["accepted": true],
        ]))
        return 0
    }

    func pollEvent(requestId: UInt64) -> ReaderCoreNativeEvent? {
        events.removeValue(forKey: requestId)
    }

    func cancel(requestId: UInt64) throws {}

    func command(method: String) -> [String: Any]? {
        commands.first { $0["method"] as? String == method }
    }
}
