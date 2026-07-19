import XCTest
import ReaderCoreNativeAdapter
import ReaderUIRuntime
@testable import ReaderShellValidation
@testable import ReaderApp

final class ReaderSlice11CompatibilityCoreExecutorTests: XCTestCase {
    @MainActor
    func testImportAndRSSCompatibilityCommandsUseExactMethods() async throws {
        let runtime = FakeSlice11CompatibilityRuntime()
        let executor = ReaderSlice11CompatibilityCoreExecutor(runtime: runtime, requestTimeout: 1)

        let parsed = try await executor.executeParse(
            payload: ["source": .object(["bookSourceName": .string("Example")])],
            correlationID: "import-parse"
        )
        let persisted = try await executor.executeSubscriptionPersist(
            payload: ["params": .object([
                "subscriptionId": .string("feed-1"),
                "feedUrl": .string("https://feeds.example.test/main.xml"),
            ])],
            correlationID: "rss-persist"
        )
        let refreshed = try await executor.executeFeedRefresh(
            payload: ["subscriptionId": .string("feed-1")],
            correlationID: "rss-refresh"
        )

        XCTAssertEqual(runtime.methods, [
            "import.parse", "rss.subscription.persist", "rss.feed.refresh",
        ])
        XCTAssertEqual(parsed["accepted"]?.boolValue, true)
        XCTAssertEqual(persisted["accepted"]?.boolValue, true)
        XCTAssertEqual(refreshed["accepted"]?.boolValue, true)
    }

    @MainActor
    func testCompatibilityImportRejectsPlaintextCredentialBeforeDispatch() async {
        let runtime = FakeSlice11CompatibilityRuntime()
        let executor = ReaderSlice11CompatibilityCoreExecutor(runtime: runtime, requestTimeout: 1)

        do {
            _ = try await executor.executePersist(
                payload: [
                    "source": .object([
                        "bookSourceName": .string("Unsafe"),
                        "password": .string("plaintext"),
                    ]),
                ],
                correlationID: "unsafe-import"
            )
            XCTFail("plaintext credential material must fail closed")
        } catch let error as ReaderSlice11CompatibilityExecutorError {
            guard case .failedClosed(let code, _) = error else {
                XCTFail("unexpected compatibility error \(error)")
                return
            }
            XCTAssertEqual(code, "SLICE11_EMBEDDED_CREDENTIAL_REJECTED")
        } catch {
            XCTFail("unexpected error \(error)")
        }
        XCTAssertTrue(runtime.commands.isEmpty)
    }

    @MainActor
    func testCompatibilityRSSRejectsCredentialBearingURLBeforeDispatch() async {
        let runtime = FakeSlice11CompatibilityRuntime()
        let executor = ReaderSlice11CompatibilityCoreExecutor(runtime: runtime, requestTimeout: 1)

        do {
            _ = try await executor.executeSubscriptionPersist(
                payload: ["params": .object([
                    "subscriptionId": .string("feed-1"),
                    "feedUrl": .string("https://feeds.example.test/main.xml?token=plaintext"),
                ])],
                correlationID: "unsafe-rss"
            )
            XCTFail("authenticated RSS must fail closed without an opaque binding")
        } catch let error as ReaderSlice11CompatibilityExecutorError {
            guard case .failedClosed(let code, _) = error else {
                XCTFail("unexpected compatibility error \(error)")
                return
            }
            XCTAssertEqual(code, "SLICE11_EMBEDDED_CREDENTIAL_REJECTED")
        } catch {
            XCTFail("unexpected error \(error)")
        }
        XCTAssertTrue(runtime.commands.isEmpty)
    }
}

private final class FakeSlice11CompatibilityRuntime: RustCoreCommandRuntime {
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
}
