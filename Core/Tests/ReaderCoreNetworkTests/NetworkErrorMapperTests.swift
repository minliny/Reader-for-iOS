import XCTest
import ReaderCoreProtocols
@testable import ReaderCoreNetwork

final class NetworkErrorMapperTests: XCTestCase {

    // MARK: - URLError → timeout

    func testTimeoutMapsToNetworkTimeout() {
        let error = URLError(.timedOut)
        let mapped = NetworkErrorMapper.map(error: error, stage: .network_transport)
        XCTAssertEqual(mapped.code, .NETWORK_TIMEOUT)
        XCTAssertEqual(mapped.stage, .network_transport)
    }

    // MARK: - URLError → unreachable variants

    func testNotConnectedToInternetMapsToNetworkUnreachable() {
        let error = URLError(.notConnectedToInternet)
        let mapped = NetworkErrorMapper.map(error: error, stage: .network_transport)
        XCTAssertEqual(mapped.code, .NETWORK_UNREACHABLE)
    }

    func testCannotConnectToHostMapsToNetworkUnreachable() {
        let error = URLError(.cannotConnectToHost)
        let mapped = NetworkErrorMapper.map(error: error, stage: .network_transport)
        XCTAssertEqual(mapped.code, .NETWORK_UNREACHABLE)
    }

    func testNetworkConnectionLostMapsToNetworkUnreachable() {
        let error = URLError(.networkConnectionLost)
        let mapped = NetworkErrorMapper.map(error: error, stage: .network_transport)
        XCTAssertEqual(mapped.code, .NETWORK_UNREACHABLE)
    }

    // MARK: - URLError → unknown

    func testBadServerResponseMapsToUnknown() {
        let error = URLError(.badServerResponse)
        let mapped = NetworkErrorMapper.map(error: error, stage: .network_transport)
        XCTAssertEqual(mapped.code, .UNKNOWN)
    }

    // MARK: - Non-URLError → unknown

    func testNonURLErrorMapsToUnknown() {
        struct SentinelError: Error {}
        let mapped = NetworkErrorMapper.map(error: SentinelError(), stage: .network_transport)
        XCTAssertEqual(mapped.code, .UNKNOWN)
    }

    // MARK: - HTTP status mapping

    func testHTTP404MapsToHTTPStatusInvalid() {
        let mapped = NetworkErrorMapper.mapHTTPStatus(statusCode: 404)
        XCTAssertNotNil(mapped)
        XCTAssertEqual(mapped?.code, .HTTP_STATUS_INVALID)
        XCTAssertEqual(mapped?.context.statusCode, 404)
    }

    func testHTTP500MapsToHTTPStatusInvalid() {
        let mapped = NetworkErrorMapper.mapHTTPStatus(statusCode: 500)
        XCTAssertNotNil(mapped)
        XCTAssertEqual(mapped?.code, .HTTP_STATUS_INVALID)
        XCTAssertEqual(mapped?.context.statusCode, 500)
    }

    func testHTTP401MapsToHTTPStatusInvalid() {
        let mapped = NetworkErrorMapper.mapHTTPStatus(statusCode: 401)
        XCTAssertEqual(mapped?.code, .HTTP_STATUS_INVALID)
    }

    func testHTTP200ReturnsNil() {
        XCTAssertNil(NetworkErrorMapper.mapHTTPStatus(statusCode: 200))
    }

    func testHTTP201ReturnsNil() {
        XCTAssertNil(NetworkErrorMapper.mapHTTPStatus(statusCode: 201))
    }

    func testHTTP204ReturnsNil() {
        XCTAssertNil(NetworkErrorMapper.mapHTTPStatus(statusCode: 204))
    }

    // MARK: - Header required

    func testHeaderRequiredCode() {
        let mapped = NetworkErrorMapper.headerRequired(headerName: "X-Auth-Token")
        XCTAssertEqual(mapped.code, .HEADER_REQUIRED)
        XCTAssertEqual(mapped.stage, .policy_check)
    }

    func testHeaderRequiredMessageContainsHeaderName() {
        let mapped = NetworkErrorMapper.headerRequired(headerName: "X-Custom-Header")
        XCTAssertTrue(mapped.message.contains("X-Custom-Header"))
    }

    // MARK: - Cookie required

    func testCookieRequiredCode() {
        let mapped = NetworkErrorMapper.cookieRequired()
        XCTAssertEqual(mapped.code, .COOKIE_REQUIRED)
        XCTAssertEqual(mapped.stage, .policy_check)
    }

    // MARK: - Stage preservation

    func testStageIsPreservedAcrossMapping() {
        let stages: [ReaderFailureStage] = [
            .request_build, .network_transport, .response_validation,
            .decode, .search_parse, .toc_parse, .content_parse,
            .policy_check, .cache_lookup, .cache_store
        ]
        for stage in stages {
            let mapped = NetworkErrorMapper.map(error: URLError(.timedOut), stage: stage)
            XCTAssertEqual(mapped.stage, stage, "Stage \(stage) not preserved")
        }
    }

    // MARK: - Context preservation

    func testContextSampleIdPreservedOnURLError() {
        let ctx = ReaderErrorContext(sampleId: "SAMPLE-P1-COOKIE-001", sourceURL: "https://example.com")
        let mapped = NetworkErrorMapper.map(
            error: URLError(.timedOut),
            stage: .network_transport,
            context: ctx
        )
        XCTAssertEqual(mapped.context.sampleId, "SAMPLE-P1-COOKIE-001")
        XCTAssertEqual(mapped.context.sourceURL, "https://example.com")
    }

    func testContextStatusCodeInjectedByHTTPStatusMapping() {
        let ctx = ReaderErrorContext(sampleId: "SAMPLE-P1-POLICY-001")
        let mapped = NetworkErrorMapper.mapHTTPStatus(statusCode: 403, context: ctx)
        XCTAssertEqual(mapped?.code, .HTTP_STATUS_INVALID)
        XCTAssertEqual(mapped?.context.statusCode, 403)
        XCTAssertEqual(mapped?.context.sampleId, "SAMPLE-P1-POLICY-001")
    }

    func testContextDetailsPreservedOnUnknownError() {
        let ctx = ReaderErrorContext(details: ["attempt": "1", "source": "search"])
        struct CustomError: Error {}
        let mapped = NetworkErrorMapper.map(error: CustomError(), stage: .network_transport, context: ctx)
        XCTAssertEqual(mapped.code, .UNKNOWN)
        XCTAssertEqual(mapped.context.details["attempt"], "1")
        XCTAssertEqual(mapped.context.details["source"], "search")
    }
}
