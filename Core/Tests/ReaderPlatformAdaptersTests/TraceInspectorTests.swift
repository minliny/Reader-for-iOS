// TraceInspectorTests.swift
// OT-007: Request / Response Trace Inspector — Test Suite
//
// Tests cover:
// 1. Request traced
// 2. Response traced
// 3. Error traced
// 4. Duration recorded
// 5. Header redaction works
// 6. Body preview truncated
// 7. Decorator preserves underlying behavior
// 8. Multiple requests append correctly
//
// Clean-room: No external GPL code. No Legado Android reference.

import XCTest
import ReaderCoreModels
import ReaderCoreProtocols
@testable import ReaderPlatformAdapters

final class TraceInspectorTests: XCTestCase {

    // MARK: - Helper: Create a TracingHTTPClient with InMemoryTraceCollector

    private func makeTracingClient(
        mock: MockHTTPAdapter = MockHTTPAdapter(),
        redactionPolicy: HeaderRedactionPolicy = HeaderRedactionPolicy(),
        bodyPreviewConfig: BodyPreviewConfig = BodyPreviewConfig()
    ) async -> (client: TracingHTTPClient, collector: InMemoryTraceCollector) {
        let collector = InMemoryTraceCollector()
        let config = TraceConfig(
            redactionPolicy: redactionPolicy,
            bodyPreviewConfig: bodyPreviewConfig,
            sink: collector
        )
        let tracingClient = TracingHTTPClient(wrapping: mock, config: config)
        return (tracingClient, collector)
    }

    // MARK: - 1. Request Traced

    func testRequestTraced() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, body: "ok")
        let (client, collector) = await makeTracingClient(mock: mock)

        _ = try await client.send(HTTPRequest(
            url: "https://example.com/test",
            method: "POST",
            headers: ["X-Custom": "value"]
        ))

        let records = await collector.allRecords()
        XCTAssertEqual(records.count, 1)

        let request = records[0].request
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url, "https://example.com/test")
        XCTAssertEqual(request.headers["X-Custom"], "value")
    }

    // MARK: - 2. Response Traced

    func testResponseTraced() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, headers: ["Content-Type": "text/html"], body: "hello")
        let (client, collector) = await makeTracingClient(mock: mock)

        _ = try await client.send(HTTPRequest(url: "https://example.com/test"))

        let records = await collector.allRecords()
        XCTAssertEqual(records.count, 1)

        let response = records[0].response
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertEqual(response?.headers["Content-Type"], "text/html")
        XCTAssertEqual(response?.bodyPreview, "hello")
    }

    // MARK: - 3. Error Traced

    func testErrorTraced() async {
        let mock = MockHTTPAdapter()
        await mock.enqueueError(URLError(.notConnectedToInternet))
        let (client, collector) = await makeTracingClient(mock: mock)

        do {
            _ = try await client.send(HTTPRequest(url: "https://example.com/fail"))
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
        }

        let records = await collector.allRecords()
        XCTAssertEqual(records.count, 1)

        XCTAssertNil(records[0].response)
        XCTAssertNotNil(records[0].error)
        XCTAssertFalse(records[0].error?.isEmpty ?? true)
    }

    // MARK: - 4. Duration Recorded

    func testDurationRecorded() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, body: "ok")
        let (client, collector) = await makeTracingClient(mock: mock)

        _ = try await client.send(HTTPRequest(url: "https://example.com/test"))

        let records = await collector.allRecords()
        XCTAssertEqual(records.count, 1)

        let response = records[0].response
        XCTAssertNotNil(response)
        XCTAssertGreaterThanOrEqual(response?.durationMs ?? -1, 0)
    }

    func testDurationRecordedOnError() async {
        let mock = MockHTTPAdapter()
        await mock.enqueueError(URLError(.timedOut))
        let (client, collector) = await makeTracingClient(mock: mock)

        do {
            _ = try await client.send(HTTPRequest(url: "https://example.com/timeout"))
            XCTFail("Expected error")
        } catch {
            // Expected
        }

        let records = await collector.allRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertNotNil(records[0].error)
        // Duration should be in metadata for error records
        XCTAssertNotNil(records[0].metadata["durationMs"])
    }

    // MARK: - 5. Header Redaction Works

    func testHeaderRedaction_defaultSensitiveHeaders() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, body: "ok")
        let (client, collector) = await makeTracingClient(mock: mock)

        _ = try await client.send(HTTPRequest(
            url: "https://example.com/test",
            headers: [
                "Authorization": "Bearer secret-token",
                "Cookie": "session=abc123",
                "X-Custom": "safe-value",
                "X-Api-Key": "my-api-key",
            ]
        ))

        let records = await collector.allRecords()
        XCTAssertEqual(records.count, 1)

        let tracedHeaders = records[0].request.headers
        XCTAssertEqual(tracedHeaders["Authorization"], "[REDACTED]")
        XCTAssertEqual(tracedHeaders["Cookie"], "[REDACTED]")
        XCTAssertEqual(tracedHeaders["X-Api-Key"], "[REDACTED]")
        XCTAssertEqual(tracedHeaders["X-Custom"], "safe-value")
    }

    func testHeaderRedaction_responseSetCookie() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(
            statusCode: 200,
            headers: [
                "Set-Cookie": "session=xyz",
                "Content-Type": "text/html",
            ],
            body: "ok"
        )
        let (client, collector) = await makeTracingClient(mock: mock)

        _ = try await client.send(HTTPRequest(url: "https://example.com/test"))

        let records = await collector.allRecords()
        let responseHeaders = records[0].response?.headers
        XCTAssertEqual(responseHeaders?["Set-Cookie"], "[REDACTED]")
        XCTAssertEqual(responseHeaders?["Content-Type"], "text/html")
    }

    func testHeaderRedaction_customPolicy() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, body: "ok")

        let customPolicy = HeaderRedactionPolicy(
            sensitiveHeaders: ["X-Secret"],
            redactedValue: "***"
        )
        let (client, collector) = await makeTracingClient(
            mock: mock,
            redactionPolicy: customPolicy
        )

        _ = try await client.send(HTTPRequest(
            url: "https://example.com/test",
            headers: [
                "X-Secret": "classified",
                "Authorization": "Bearer token",  // Not in custom policy
            ]
        ))

        let records = await collector.allRecords()
        let tracedHeaders = records[0].request.headers
        XCTAssertEqual(tracedHeaders["X-Secret"], "***")
        // Authorization NOT in custom sensitive headers → not redacted
        XCTAssertEqual(tracedHeaders["Authorization"], "Bearer token")
    }

    func testHeaderRedaction_caseInsensitive() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, body: "ok")
        let (client, collector) = await makeTracingClient(mock: mock)

        _ = try await client.send(HTTPRequest(
            url: "https://example.com/test",
            headers: [
                "authorization": "Basic abc",   // lowercase
                "AUTHORIZATION": "Basic def",    // uppercase — both should be redacted
            ]
        ))

        let records = await collector.allRecords()
        let tracedHeaders = records[0].request.headers
        // At least one should be redacted (both keys present in dict)
        let authValues = tracedHeaders.filter { $0.key.lowercased() == "authorization" }.values
        for value in authValues {
            XCTAssertEqual(value, "[REDACTED]")
        }
    }

    // MARK: - 6. Body Preview Truncated

    func testBodyPreview_truncatedForLargeBody() async throws {
        let mock = MockHTTPAdapter()
        let largeBody = String(repeating: "A", count: 2000)
        await mock.enqueue(statusCode: 200, body: largeBody)

        let config = BodyPreviewConfig(maxBytes: 100, enabled: true)
        let (client, collector) = await makeTracingClient(mock: mock, bodyPreviewConfig: config)

        _ = try await client.send(HTTPRequest(url: "https://example.com/test"))

        let records = await collector.allRecords()
        let preview = records[0].response?.bodyPreview
        XCTAssertNotNil(preview)
        // Should contain truncation indicator
        XCTAssertTrue(preview?.contains("bytes total") == true)
        // Preview should be shorter than full body
        XCTAssertLessThan(preview?.count ?? Int.max, largeBody.count)
    }

    func testBodyPreview_disabled() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, body: "hello")

        let config = BodyPreviewConfig(enabled: false)
        let (client, collector) = await makeTracingClient(mock: mock, bodyPreviewConfig: config)

        _ = try await client.send(HTTPRequest(url: "https://example.com/test"))

        let records = await collector.allRecords()
        XCTAssertNil(records[0].response?.bodyPreview)
    }

    func testBodyPreview_binaryData() async throws {
        let binaryData = Data([0x00, 0x01, 0x02, 0xFF, 0xFE, 0xFD])
        let mock = MockHTTPAdapter()
        await mock.enqueueResponse(HTTPResponse(
            statusCode: 200,
            headers: [:],
            data: binaryData
        ))
        let (client, collector) = await makeTracingClient(mock: mock)

        _ = try await client.send(HTTPRequest(url: "https://example.com/test"))

        let records = await collector.allRecords()
        let preview = records[0].response?.bodyPreview
        XCTAssertNotNil(preview)
        // Binary data should be represented as hex
        XCTAssertTrue(preview?.contains("binary") == true || preview?.contains("00 01 02") == true)
    }

    func testBodyPreview_requestBody() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, body: "ok")
        let (client, collector) = await makeTracingClient(mock: mock)

        _ = try await client.send(HTTPRequest(
            url: "https://example.com/test",
            method: "POST",
            body: Data("request-payload".utf8)
        ))

        let records = await collector.allRecords()
        XCTAssertEqual(records[0].request.bodyPreview, "request-payload")
    }

    // MARK: - 7. Decorator Preserves Underlying Behavior

    func testDecoratorPreservesSuccessfulResponse() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, headers: ["X-Test": "yes"], body: "response-body")
        let (client, _) = await makeTracingClient(mock: mock)

        let response = try await client.send(HTTPRequest(url: "https://example.com/test"))
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.headers["X-Test"], "yes")
        XCTAssertEqual(String(data: response.data, encoding: .utf8), "response-body")
    }

    func testDecoratorPreservesErrorPropagation() async {
        let mock = MockHTTPAdapter()
        let expectedError = URLError(.dnsLookupFailed)
        await mock.enqueueError(expectedError)
        let (client, _) = await makeTracingClient(mock: mock)

        do {
            _ = try await client.send(HTTPRequest(url: "https://example.com/fail"))
            XCTFail("Expected error to propagate")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .dnsLookupFailed)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testDecoratorConformsToHTTPClient() async throws {
        // Verify TracingHTTPClient can be used as HTTPClient
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, body: "ok")
        let (tracingClient, _) = await makeTracingClient(mock: mock)

        let client: any HTTPClient = tracingClient
        let response = try await client.send(HTTPRequest(url: "https://example.com/test"))
        XCTAssertEqual(response.statusCode, 200)
    }

    // MARK: - 8. Multiple Requests Append Correctly

    func testMultipleRequestsAppendCorrectly() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, body: "first")
        await mock.enqueue(statusCode: 404, body: "second")
        await mock.enqueue(statusCode: 500, body: "third")
        let (client, collector) = await makeTracingClient(mock: mock)

        _ = try await client.send(HTTPRequest(url: "https://example.com/1"))
        _ = try await client.send(HTTPRequest(url: "https://example.com/2"))
        _ = try await client.send(HTTPRequest(url: "https://example.com/3"))

        let records = await collector.allRecords()
        XCTAssertEqual(records.count, 3)

        XCTAssertEqual(records[0].request.url, "https://example.com/1")
        XCTAssertEqual(records[0].response?.statusCode, 200)

        XCTAssertEqual(records[1].request.url, "https://example.com/2")
        XCTAssertEqual(records[1].response?.statusCode, 404)

        XCTAssertEqual(records[2].request.url, "https://example.com/3")
        XCTAssertEqual(records[2].response?.statusCode, 500)
    }

    // MARK: - TraceRecord Properties

    func testTraceRecord_hasUniqueId() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, body: "ok")
        await mock.enqueue(statusCode: 200, body: "ok2")
        let (client, collector) = await makeTracingClient(mock: mock)

        _ = try await client.send(HTTPRequest(url: "https://example.com/1"))
        _ = try await client.send(HTTPRequest(url: "https://example.com/2"))

        let records = await collector.allRecords()
        XCTAssertEqual(records.count, 2)
        XCTAssertNotEqual(records[0].id, records[1].id)
    }

    func testTraceRecord_requestHasTimestamp() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, body: "ok")
        let (client, collector) = await makeTracingClient(mock: mock)

        let before = Date()
        _ = try await client.send(HTTPRequest(url: "https://example.com/test"))
        let after = Date()

        let records = await collector.allRecords()
        let timestamp = records[0].request.timestamp
        XCTAssertGreaterThanOrEqual(timestamp, before)
        XCTAssertLessThanOrEqual(timestamp, after)
    }

    func testTraceRecord_metadataOnSuccess_isEmpty() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, body: "ok")
        let (client, collector) = await makeTracingClient(mock: mock)

        _ = try await client.send(HTTPRequest(url: "https://example.com/test"))

        let records = await collector.allRecords()
        XCTAssertTrue(records[0].metadata.isEmpty)
    }

    // MARK: - InMemoryTraceCollector

    func testInMemoryTraceCollector_clear() async throws {
        let collector = InMemoryTraceCollector()
        await collector.record(TraceRecord(
            request: TraceRequest(method: "GET", url: "https://example.com", headers: [:])
        ))
        let countBefore = await collector.count
        XCTAssertEqual(countBefore, 1)

        await collector.clear()
        let countAfter = await collector.count
        XCTAssertEqual(countAfter, 0)
    }

    func testInMemoryTraceCollector_allRecords() async throws {
        let collector = InMemoryTraceCollector()
        let record1 = TraceRecord(
            request: TraceRequest(method: "GET", url: "https://a.com", headers: [:])
        )
        let record2 = TraceRecord(
            request: TraceRequest(method: "POST", url: "https://b.com", headers: [:])
        )
        await collector.record(record1)
        await collector.record(record2)

        let all = await collector.allRecords()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all[0].request.url, "https://a.com")
        XCTAssertEqual(all[1].request.url, "https://b.com")
    }

    // MARK: - HeaderRedactionPolicy

    func testHeaderRedactionPolicy_defaultSensitiveHeaders() {
        let policy = HeaderRedactionPolicy()
        XCTAssertTrue(policy.sensitiveHeaders.contains("authorization"))
        XCTAssertTrue(policy.sensitiveHeaders.contains("cookie"))
        XCTAssertTrue(policy.sensitiveHeaders.contains("set-cookie"))
        XCTAssertTrue(policy.sensitiveHeaders.contains("x-api-key"))
        XCTAssertTrue(policy.sensitiveHeaders.contains("token"))
    }

    func testHeaderRedactionPolicy_redact() {
        let policy = HeaderRedactionPolicy()
        let input: [String: String] = [
            "Authorization": "Bearer xyz",
            "Content-Type": "text/html",
            "Cookie": "a=1",
        ]
        let result = policy.redact(input)
        XCTAssertEqual(result["Authorization"], "[REDACTED]")
        XCTAssertEqual(result["Content-Type"], "text/html")
        XCTAssertEqual(result["Cookie"], "[REDACTED]")
    }

    func testHeaderRedactionPolicy_customRedactedValue() {
        let policy = HeaderRedactionPolicy(redactedValue: "****")
        let input: [String: String] = ["Authorization": "secret"]
        let result = policy.redact(input)
        XCTAssertEqual(result["Authorization"], "****")
    }

    // MARK: - BodyPreviewConfig

    func testBodyPreviewConfig_nilData() {
        let config = BodyPreviewConfig()
        XCTAssertNil(config.preview(from: nil))
    }

    func testBodyPreviewConfig_emptyData() {
        let config = BodyPreviewConfig()
        XCTAssertNil(config.preview(from: Data()))
    }

    func testBodyPreviewConfig_smallUtf8Data() {
        let config = BodyPreviewConfig(maxBytes: 1024)
        let result = config.preview(from: Data("hello".utf8))
        XCTAssertEqual(result, "hello")
    }

    func testBodyPreviewConfig_truncationIndicator() {
        let config = BodyPreviewConfig(maxBytes: 5)
        let data = Data("hello world this is long".utf8)
        let result = config.preview(from: data)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("bytes total") == true)
    }

    // MARK: - TraceConfig

    func testTraceConfig_defaultValues() {
        let config = TraceConfig()
        XCTAssertEqual(config.redactionPolicy, HeaderRedactionPolicy())
        XCTAssertEqual(config.bodyPreviewConfig, BodyPreviewConfig())
        XCTAssertNil(config.sink)
    }

    // MARK: - Integration: TracingHTTPClient with MockHTTPAdapter from OT-006

    func testTracingClient_withAdapterIntegrationHarness() async throws {
        let mock = MockHTTPAdapter()
        await mock.enqueue(statusCode: 200, headers: ["X-Response": "traced"], body: "integration-ok")

        let collector = InMemoryTraceCollector()
        let config = TraceConfig(sink: collector)
        let tracingClient = TracingHTTPClient(wrapping: mock, config: config)

        let response = try await tracingClient.send(HTTPRequest(
            url: "https://example.com/integration",
            method: "GET",
            headers: ["X-Request": "test"]
        ))

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(String(data: response.data, encoding: .utf8), "integration-ok")

        let records = await collector.allRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].request.headers["X-Request"], "test")
        XCTAssertEqual(records[0].response?.headers["X-Response"], "traced")
    }
}
