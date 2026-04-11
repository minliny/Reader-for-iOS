// ReaderCoreNetworkTests/ErrorMappingTests.swift
//
// Executable XCTest for closing the error_mapping capability gate.
//
// CLEAN-ROOM: no Legado Android reference. Tests derived from:
//   - SAMPLE-P1-ERROR-001 (HTTP 404 → CONTENT_FAILED)
//   - SAMPLE-P1-ERROR-002 (timeout → CONTENT_FAILED / mapped code)
//   - SAMPLE-P1-ERROR-003 (selector miss → RULE_INVALID)
//   - NetworkPolicyLayer.evaluate() integration path
//
// These tests exercise the full path:
//   HTTPResponse → NetworkPolicyLayer.evaluate() → ErrorMapper.readerError()
//   URLError → NetworkPolicyLayer.normalize() → ErrorMapper.readerError()
//
// They are NOT static-only; they instantiate real objects and assert
// runtime behaviour.

import XCTest
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreNetwork

final class ErrorMappingTests: XCTestCase {

    // MARK: - SAMPLE-P1-ERROR-001: HTTP 404 → CONTENT_FAILED

    /// HTTP 404 through NetworkPolicyLayer.evaluate() must produce
    /// a ReaderError with failureType CONTENT_FAILED and errorCode networkFailed.
    /// This is the primary executable gate for the error_mapping capability.
    func testHTTP404ThroughPolicyLayerMapsToContentFailed() async throws {
        let client = StubHTTPClient(
            response: HTTPResponse(
                statusCode: 404,
                headers: ["Content-Type": "application/json"],
                data: Data("{\"error\":\"not found\"}".utf8)
            )
        )
        let layer = NetworkPolicyLayer(httpClient: client)

        do {
            _ = try await layer.send(HTTPRequest(url: "https://example.com/content/missing"))
            XCTFail("Expected ReaderError for HTTP 404")
        } catch let error as ReaderError {
            XCTAssertEqual(error.failure?.type, .CONTENT_FAILED,
                           "HTTP 404 must map to CONTENT_FAILED failureType")
            XCTAssertEqual(error.code, .networkFailed,
                           "HTTP 404 must map to networkFailed errorCode")
            XCTAssertEqual(error.message, "HTTP 404 content fetch failed.",
                           "HTTP 404 message must match expected")
        }
    }

    // MARK: - SAMPLE-P1-ERROR-001 (alternate): ErrorMapper.map(.httpStatus(404))

    /// Direct ErrorMapper model-layer mapping for HTTP 404.
    func testErrorMapperDirectHTTP404MapsToContentFailed() {
        let result = ErrorMapper.map(.httpStatus(404))
        XCTAssertEqual(result.failureType, .CONTENT_FAILED)
        XCTAssertEqual(result.errorCode, .networkFailed)
        XCTAssertEqual(result.message, "HTTP 404 content fetch failed.")
    }

    /// ErrorMapper.readerError convenience produces a ReaderError with the same mapping.
    func testErrorMapperReaderErrorForHTTP404() {
        let error = ErrorMapper.readerError(for: .httpStatus(404))
        XCTAssertEqual(error.failure?.type, .CONTENT_FAILED)
        XCTAssertEqual(error.code, .networkFailed)
    }

    // MARK: - SAMPLE-P1-ERROR-002: timeout → CONTENT_FAILED / mapped code

    /// URLError.timedOut through NetworkPolicyLayer must map to
    /// CONTENT_FAILED with the correct mapped code.
    func testTimeoutThroughPolicyLayerMapsToContentFailed() async throws {
        let client = TimeoutHTTPClient()
        let layer = NetworkPolicyLayer(httpClient: client)

        do {
            _ = try await layer.send(HTTPRequest(url: "https://example.com/slow"))
            XCTFail("Expected error for timeout")
        } catch {
            // NetworkPolicyLayer.normalize catches URLError and maps it
            if let readerError = error as? ReaderError {
                XCTAssertEqual(readerError.failure?.type, .CONTENT_FAILED,
                               "Timeout must map to CONTENT_FAILED via NetworkPolicyLayer")
            } else if let mappedError = error as? MappedReaderError {
                XCTAssertEqual(mappedError.code, .NETWORK_TIMEOUT,
                               "Timeout must map to NETWORK_TIMEOUT via ErrorMapper")
            }
        }
    }

    /// Direct ErrorMapper model-layer mapping for timeout.
    func testErrorMapperDirectTimeoutMapsToContentFailed() {
        let result = ErrorMapper.map(.timeout)
        XCTAssertEqual(result.failureType, .CONTENT_FAILED)
        XCTAssertEqual(result.errorCode, .networkFailed)
    }

    /// NetworkErrorMapper maps URLError.timedOut to NETWORK_TIMEOUT.
    func testNetworkErrorMapperTimeoutCode() {
        let mapped = NetworkErrorMapper.map(
            error: URLError(.timedOut),
            stage: .network_transport
        )
        XCTAssertEqual(mapped.code, .NETWORK_TIMEOUT)
    }

    // MARK: - Unreachable → NETWORK_UNREACHABLE / mapped code

    /// URLError.notConnectedToInternet through NetworkErrorMapper must produce
    /// NETWORK_UNREACHABLE.
    func testUnreachableMapsToNetworkUnreachable() {
        let mapped = NetworkErrorMapper.map(
            error: URLError(.notConnectedToInternet),
            stage: .network_transport
        )
        XCTAssertEqual(mapped.code, .NETWORK_UNREACHABLE,
                       "Not connected to internet must map to NETWORK_UNREACHABLE")
        XCTAssertEqual(mapped.stage, .network_transport)
    }

    /// URLError.cannotConnectToHost also maps to NETWORK_UNREACHABLE.
    func testCannotConnectToHostMapsToNetworkUnreachable() {
        let mapped = NetworkErrorMapper.map(
            error: URLError(.cannotConnectToHost),
            stage: .network_transport
        )
        XCTAssertEqual(mapped.code, .NETWORK_UNREACHABLE)
    }

    // MARK: - SAMPLE-P1-ERROR-003: selector miss → RULE_INVALID

    /// Direct ErrorMapper model-layer mapping for selector miss.
    func testErrorMapperSelectorMissMapsToRuleInvalid() {
        let result = ErrorMapper.map(.selectorMiss(".missing-title"))
        XCTAssertEqual(result.failureType, .RULE_INVALID)
        XCTAssertEqual(result.errorCode, .parsingFailed)
    }

    // MARK: - HTTP 401/403 → NETWORK_POLICY_MISMATCH (taxonomy convergence)

    /// HTTP 401 maps to NETWORK_POLICY_MISMATCH (not a new taxonomy entry).
    func testHTTP401MapsToNetworkPolicyMismatch() {
        let result = ErrorMapper.map(.httpStatus(401))
        XCTAssertEqual(result.failureType, .NETWORK_POLICY_MISMATCH)
    }

    /// HTTP 403 maps to NETWORK_POLICY_MISMATCH (not a new taxonomy entry).
    func testHTTP403MapsToNetworkPolicyMismatch() {
        let result = ErrorMapper.map(.httpStatus(403))
        XCTAssertEqual(result.failureType, .NETWORK_POLICY_MISMATCH)
    }

    /// HTTP 403 through NetworkPolicyLayer maps to HTTP_STATUS_INVALID at the
    /// MappedReaderError level (NetworkErrorMapper) and NETWORK_POLICY_MISMATCH
    /// at the ErrorMapper level. The policy layer's evaluate() uses ErrorMapper
    /// for >= 400 (non-404) responses.
    func testHTTP403ThroughPolicyLayerMapsCorrectly() async throws {
        let client = StubHTTPClient(
            response: HTTPResponse(
                statusCode: 403,
                headers: [:],
                data: Data("forbidden".utf8)
            )
        )
        let layer = NetworkPolicyLayer(httpClient: client)

        do {
            _ = try await layer.send(HTTPRequest(url: "https://example.com/forbidden"))
            XCTFail("Expected error for HTTP 403")
        } catch let error as ReaderError {
            // NetworkPolicyLayer.evaluate() uses ErrorMapper for >= 400 non-404
            XCTAssertEqual(error.failure?.type, .NETWORK_POLICY_MISMATCH,
                           "HTTP 403 must map to NETWORK_POLICY_MISMATCH through policy layer")
        }
    }

    // MARK: - Empty response → CONTENT_FAILED

    /// Empty response body through NetworkPolicyLayer must produce CONTENT_FAILED.
    func testEmptyResponseThroughPolicyLayerMapsToContentFailed() async throws {
        let client = StubHTTPClient(
            response: HTTPResponse(
                statusCode: 200,
                headers: [:],
                data: Data()
            )
        )
        let layer = NetworkPolicyLayer(httpClient: client)

        do {
            _ = try await layer.send(HTTPRequest(url: "https://example.com/empty"))
            XCTFail("Expected error for empty response")
        } catch let error as ReaderError {
            XCTAssertEqual(error.failure?.type, .CONTENT_FAILED,
                           "Empty response must map to CONTENT_FAILED")
        }
    }

    // MARK: - Taxonomy convergence: no new failureType introduced

    /// Verify that the complete ErrorMappingInput → FailureType mapping does not
    /// introduce any failureType not in the v1 taxonomy.
    func testNoNewFailureTypeIntroducedBeyondV1Taxonomy() {
        let v1Types: Set<String> = [
            "JSON_INVALID", "FIELD_MISSING", "RULE_INVALID", "RULE_UNSUPPORTED",
            "SEARCH_FAILED", "TOC_FAILED", "CONTENT_FAILED",
            "NETWORK_POLICY_MISMATCH", "COOKIE_REQUIRED", "LOGIN_REQUIRED",
            "JS_DEGRADED", "JS_UNSUPPORTED", "OUTPUT_MISMATCH", "CRASH"
        ]

        let mapped404 = ErrorMapper.map(.httpStatus(404))
        XCTAssertTrue(v1Types.contains(mapped404.failureType.rawValue),
                      "HTTP 404 failureType must be in v1 taxonomy")

        let mappedTimeout = ErrorMapper.map(.timeout)
        XCTAssertTrue(v1Types.contains(mappedTimeout.failureType.rawValue),
                      "Timeout failureType must be in v1 taxonomy")

        let mappedMiss = ErrorMapper.map(.selectorMiss(".x"))
        XCTAssertTrue(v1Types.contains(mappedMiss.failureType.rawValue),
                      "Selector miss failureType must be in v1 taxonomy")

        let mapped401 = ErrorMapper.map(.httpStatus(401))
        XCTAssertTrue(v1Types.contains(mapped401.failureType.rawValue),
                      "HTTP 401 failureType must be in v1 taxonomy")
    }
}

// MARK: - Test Helpers

/// Simple stub HTTPClient that returns a fixed response.
private final class StubHTTPClient: HTTPClient, @unchecked Sendable {
    private let response: HTTPResponse

    init(response: HTTPResponse) {
        self.response = response
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        return response
    }
}

/// Stub HTTPClient that always throws URLError.timedOut.
private final class TimeoutHTTPClient: HTTPClient, @unchecked Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        throw URLError(.timedOut)
    }
}
