// AdapterIntegrationTestHarnessTests.swift
// OT-006: Adapter Integration Test Harness — Test Suite
//
// Tests cover:
// 1. Adapter contract pass path (MockHTTPAdapter + verifier)
// 2. Malformed adapter impl fail path
// 3. Required protocol behavior assertions
// 4. Storage adapter contract verification (skeleton)
// 5. Scheduler adapter mock verification (skeleton)
// 6. Report aggregation
//
// Clean-room: No external GPL code. No Legado Android reference.

import XCTest
import ReaderCoreModels
import ReaderCoreProtocols
@testable import ReaderPlatformAdapters

final class AdapterIntegrationTestHarnessTests: XCTestCase {

    // MARK: - MockHTTPAdapter Contract Pass Path

    func testMockHTTPAdapter_enqueuedResponse_isReturned() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, headers: ["Content-Type": "text/html"], body: "<html>ok</html>")

        let response = try await mock.send(HTTPRequest(url: "https://example.com/test"))
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.headers["Content-Type"], "text/html")
        XCTAssertEqual(String(data: response.data, encoding: .utf8), "<html>ok</html>")
    }

    func testMockHTTPAdapter_multipleEnqueued_responsesInOrder() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, body: "first")
        await mock.enqueue(statusCode: 404, body: "second")

        let r1 = try await mock.send(HTTPRequest(url: "https://example.com/1"))
        XCTAssertEqual(r1.statusCode, 200)
        XCTAssertEqual(String(data: r1.data, encoding: .utf8), "first")

        let r2 = try await mock.send(HTTPRequest(url: "https://example.com/2"))
        XCTAssertEqual(r2.statusCode, 404)
        XCTAssertEqual(String(data: r2.data, encoding: .utf8), "second")
    }

    func testMockHTTPAdapter_noEnqueuedResponse_returnsDefault200() async throws {
        let mock = MockHTTPAdapter()
        let response = try await mock.send(HTTPRequest(url: "https://example.com/default"))
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertTrue(response.data.isEmpty)
    }

    func testMockHTTPAdapter_errorInjection() async {
        let mock = MockHTTPAdapter()
        await mock.enqueueError(URLError(.notConnectedToInternet))

        do {
            _ = try await mock.send(HTTPRequest(url: "https://example.com/error"))
            XCTFail("Expected error to be thrown")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - MockHTTPAdapter Request Capture

    func testMockHTTPAdapter_capturesRequest() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, body: "ok")

        let request = HTTPRequest(
            url: "https://example.com/capture",
            method: "POST",
            headers: ["X-Auth": "token-123"],
            body: Data("payload".utf8)
        )
        _ = try await mock.send(request)

        let captured = await mock.capturedRequests
        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured[0].url, "https://example.com/capture")
        XCTAssertEqual(captured[0].method, "POST")
        XCTAssertEqual(captured[0].headers["X-Auth"], "token-123")
        XCTAssertEqual(captured[0].body, Data("payload".utf8))
    }

    func testMockHTTPAdapter_requestCount() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, body: "a")
        await mock.enqueue(statusCode: 200, body: "b")
        await mock.enqueue(statusCode: 200, body: "c")

        _ = try await mock.send(HTTPRequest(url: "https://example.com/1"))
        _ = try await mock.send(HTTPRequest(url: "https://example.com/2"))
        _ = try await mock.send(HTTPRequest(url: "https://example.com/3"))

        let count = await mock.requestCount
        XCTAssertEqual(count, 3)
    }

    func testMockHTTPAdapter_reset() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, body: "before")
        _ = try await mock.send(HTTPRequest(url: "https://example.com/before"))

        await mock.reset()

        let count = await mock.requestCount
        XCTAssertEqual(count, 0)
    }

    // MARK: - Contract Verifier: HTTP Adapter Pass Path

    func testContractVerifier_mockHTTPAdapter_passesAllContracts() async {
        let verifier = AdapterContractVerifier(adapterName: "MockHTTPAdapter")
        await verifier.addHTTPMockContractTests()

        let report = await verifier.runAll()
        XCTAssertTrue(report.allPassed, "MockHTTPAdapter should pass all standard HTTP contracts. Failures: \(report.results.filter { !$0.passed })")
        XCTAssertGreaterThanOrEqual(report.results.count, 5, "Should have at least 5 contract tests")
    }

    func testContractVerifier_specificContractPassed() async {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, headers: ["X-Response": "ok"], body: "response-body")

        let verifier = AdapterContractVerifier(adapterName: "MockHTTPAdapter-Headers")
        verifier.addHTTPContractTests(adapter: mock)

        let report = await verifier.runAll()
        XCTAssertTrue(report.allPassed)
    }

    // MARK: - Contract Verifier: Malformed Adapter Fail Path

    func testContractVerifier_malformedAdapter_invalidURLDoesNotThrow_fails() async {
        let verifier = AdapterContractVerifier(adapterName: "MalformedAdapter")

        // Add only the invalid URL test with a malformed adapter that doesn't throw
        verifier.addTest(name: "HTTP_send_invalidURLThrows") {
            let malformedAdapter = NeverThrowingHTTPAdapter()
            let request = HTTPRequest(url: "not-a-valid-url", method: "GET")
            do {
                _ = try await malformedAdapter.send(request)
                return AdapterContractResult(
                    contractName: "HTTP_send_invalidURLThrows",
                    passed: false,
                    failures: [.init(requirement: "Invalid URL must throw", message: "send() did not throw for invalid URL")]
                )
            } catch {
                return AdapterContractResult(contractName: "HTTP_send_invalidURLThrows", passed: true)
            }
        }

        let report = await verifier.runAll()
        XCTAssertFalse(report.allPassed, "Malformed adapter should fail contract verification")
        XCTAssertEqual(report.results.count, 1)
        XCTAssertEqual(report.results[0].contractName, "HTTP_send_invalidURLThrows")
    }

    // MARK: - Contract Verifier: Required Protocol Behavior

    func testContractVerifier_HTTPAdapterProtocol_conformanceIsRequired() async throws {
        // Verify MockHTTPAdapter conforms to HTTPAdapterProtocol
        let mock: any HTTPAdapterProtocol = MockHTTPAdapter()
        // Note: enqueue is on MockHTTPAdapter, not on the protocol.
        // We need to cast back to use test helpers.
        let mockAdapter = mock as! MockHTTPAdapter
        await mockAdapter.enqueue(statusCode: 200, body: "protocol-ok")

        let response = try await mock.send(HTTPRequest(url: "https://example.com/proto"))
        XCTAssertEqual(response.statusCode, 200)
    }

    func testContractVerifier_customAssertion() async {
        let verifier = AdapterContractVerifier(adapterName: "CustomAssertion")

        verifier.addAssertion(name: "Custom_check", requirement: "Value must be positive") {
            return 42 > 0
        }

        let report = await verifier.runAll()
        XCTAssertTrue(report.allPassed)
        XCTAssertEqual(report.results.count, 1)
    }

    func testContractVerifier_customAssertionFailing() async {
        let verifier = AdapterContractVerifier(adapterName: "CustomAssertionFail")

        verifier.addAssertion(name: "Failing_check", requirement: "Value must be negative") {
            return 42 < 0
        }

        let report = await verifier.runAll()
        XCTAssertFalse(report.allPassed)
        XCTAssertEqual(report.results[0].failures.count, 1)
        XCTAssertEqual(report.results[0].failures[0].requirement, "Value must be negative")
    }

    // MARK: - Contract Verifier: Custom Throwing Assertion

    func testContractVerifier_throwingAssertion() async {
        let verifier = AdapterContractVerifier(adapterName: "ThrowingAssertion")

        verifier.addAssertion(name: "Throwing_check", requirement: "Must not throw") {
            throw URLError(.badServerResponse)
        }

        let report = await verifier.runAll()
        XCTAssertFalse(report.allPassed)
        XCTAssertTrue(report.results[0].failures[0].message.contains("Assertion threw"))
    }

    // MARK: - Storage Adapter Mock (Skeleton)

    func testMockStorageAdapter_readAfterWrite() async throws {
        let mock = MockStorageAdapter()
        let data = Data("stored-value".utf8)

        try await mock.write(data, key: "test-key")
        let result = try await mock.read(key: "test-key")

        XCTAssertEqual(result, data)
    }

    func testMockStorageAdapter_readMissingKeyReturnsNil() async throws {
        let mock = MockStorageAdapter()
        let result = try await mock.read(key: "nonexistent-key")
        XCTAssertNil(result)
    }

    func testMockStorageAdapter_remove() async throws {
        let mock = MockStorageAdapter()
        let data = Data("to-remove".utf8)

        try await mock.write(data, key: "remove-key")
        try await mock.remove(key: "remove-key")
        let result = try await mock.read(key: "remove-key")

        XCTAssertNil(result)
    }

    func testMockStorageAdapter_writeLog() async throws {
        let mock = MockStorageAdapter()
        try await mock.write(Data("a".utf8), key: "k1")
        try await mock.write(Data("b".utf8), key: "k2")

        let log = await mock.writeLog
        XCTAssertEqual(log.count, 2)
        XCTAssertEqual(log[0].key, "k1")
        XCTAssertEqual(log[1].key, "k2")
    }

    func testMockStorageAdapter_stub() async throws {
        let mock = MockStorageAdapter()
        await mock.setStub(Data("stubbed".utf8), forKey: "stub-key")

        let result = try await mock.read(key: "stub-key")
        XCTAssertEqual(result, Data("stubbed".utf8))
    }

    // MARK: - Scheduler Adapter Mock (Skeleton)

    func testMockSchedulerAdapter_scheduleAndCancel() async throws {
        let mock = MockSchedulerAdapter()

        try await mock.schedule(taskId: "task-1", executeAfter: 5.0)
        try await mock.schedule(taskId: "task-2", executeAfter: 10.0)
        try await mock.cancel(taskId: "task-1")

        let scheduled = await mock.scheduledTasks
        let cancelled = await mock.cancelledTasks

        XCTAssertEqual(scheduled.count, 2)
        XCTAssertEqual(scheduled[0].taskId, "task-1")
        XCTAssertEqual(scheduled[0].interval, 5.0)
        XCTAssertEqual(scheduled[1].taskId, "task-2")
        XCTAssertEqual(cancelled, ["task-1"])
    }

    // MARK: - Contract Verifier: Storage Adapter

    func testContractVerifier_mockStorageAdapter_passesAllContracts() async {
        let mock = MockStorageAdapter()
        let verifier = AdapterContractVerifier(adapterName: "MockStorageAdapter")
        verifier.addStorageContractTests(adapter: mock)

        let report = await verifier.runAll()
        XCTAssertTrue(report.allPassed, "MockStorageAdapter should pass all standard Storage contracts")
        XCTAssertGreaterThanOrEqual(report.results.count, 3, "Should have at least 3 storage contract tests")
    }

    // MARK: - Report Aggregation

    func testContractReport_allPassed_whenAllResultsPass() {
        let results = [
            AdapterContractResult(contractName: "C1", passed: true),
            AdapterContractResult(contractName: "C2", passed: true),
        ]
        let report = AdapterContractReport(adapterName: "TestAdapter", results: results)
        XCTAssertTrue(report.allPassed)
    }

    func testContractReport_notAllPassed_whenAnyResultFails() {
        let results = [
            AdapterContractResult(contractName: "C1", passed: true),
            AdapterContractResult(contractName: "C2", passed: false, failures: [
                .init(requirement: "req", message: "msg")
            ]),
        ]
        let report = AdapterContractReport(adapterName: "TestAdapter", results: results)
        XCTAssertFalse(report.allPassed)
    }

    func testContractResult_failureDetails() {
        let failure = AdapterContractResult.ContractFailure(requirement: "Must return 200", message: "Got 500")
        let result = AdapterContractResult(contractName: "StatusCheck", passed: false, failures: [failure])

        XCTAssertFalse(result.passed)
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertEqual(result.failures[0].requirement, "Must return 200")
        XCTAssertEqual(result.failures[0].message, "Got 500")
    }

    // MARK: - Integration: CoreAdapterDependencies with Mocks

    func testCoreAdapterDependencies_withMockHTTPAdapter() async throws {
        let mockHTTP = MockHTTPAdapter()
        await mockHTTP.enqueue(statusCode: 200, body: "core-deps-ok")

        let deps = CoreAdapterDependencies(http: mockHTTP)
        let response = try await deps.http.send(HTTPRequest(url: "https://example.com/deps"))

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(String(data: response.data, encoding: .utf8), "core-deps-ok")
    }

    func testCoreAdapterDependencies_withAllMocks() async throws {
        let mockHTTP = MockHTTPAdapter()
        let mockStorage = MockStorageAdapter()
        let mockScheduler = MockSchedulerAdapter()

        let deps = CoreAdapterDependencies(
            http: mockHTTP,
            storage: mockStorage,
            scheduler: mockScheduler
        )

        // Verify all adapters are wired
        XCTAssertNotNil(deps.http)
        XCTAssertNotNil(deps.storage)
        XCTAssertNotNil(deps.scheduler)
    }

    // MARK: - AdapterAssertions

    func testAdapterAssertions_assertPassed_succeedsForPassedResult() {
        let result = AdapterContractResult(contractName: "C1", passed: true)
        // Should not crash / assert
        AdapterAssertions.assertPassed(result)
    }

    func testAdapterAssertions_assertAllPassed_succeedsForAllPassReport() {
        let report = AdapterContractReport(
            adapterName: "A1",
            results: [AdapterContractResult(contractName: "C1", passed: true)]
        )
        AdapterAssertions.assertAllPassed(report)
    }

    func testAdapterAssertions_assertContractPassed_succeedsForNamedContract() {
        let report = AdapterContractReport(
            adapterName: "A1",
            results: [AdapterContractResult(contractName: "my_contract", passed: true)]
        )
        AdapterAssertions.assertContractPassed(report, contractName: "my_contract")
    }
}

// MARK: - Test Helper: Malformed Adapter

/// A deliberately broken adapter that never throws, even for invalid URLs.
/// Used to verify that the contract verifier correctly detects violations.
private final class NeverThrowingHTTPAdapter: HTTPAdapterProtocol, @unchecked Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        // Always succeeds, even with invalid URLs — this is a contract violation
        return HTTPResponse(statusCode: 200, headers: [:], data: Data())
    }
}
