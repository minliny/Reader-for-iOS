import XCTest
@testable import ReaderCoreModels

final class ErrorMapperTests: XCTestCase {
    func testSample001MapsHTTP404ToContentFailed() {
        let mapped = ErrorMapper.map(.httpStatus(404))

        XCTAssertEqual(mapped.failureType, .CONTENT_FAILED)
        XCTAssertEqual(mapped.errorCode, .networkFailed)
        XCTAssertEqual(mapped.message, "HTTP 404 content fetch failed.")
    }

    func testSample002MapsTimeoutToContentFailed() {
        let mapped = ErrorMapper.map(.timeout)

        XCTAssertEqual(mapped.failureType, .CONTENT_FAILED)
        XCTAssertEqual(mapped.errorCode, .networkFailed)
    }

    func testSample003MapsSelectorMissToRuleInvalid() {
        let mapped = ErrorMapper.map(.selectorMiss(".missing-book-title"))

        XCTAssertEqual(mapped.failureType, .RULE_INVALID)
        XCTAssertEqual(mapped.errorCode, .parsingFailed)
    }

    func testHTTP401And403UseExistingNetworkPolicyMismatch() {
        XCTAssertEqual(ErrorMapper.map(.httpStatus(401)).failureType, .NETWORK_POLICY_MISMATCH)
        XCTAssertEqual(ErrorMapper.map(.httpStatus(403)).failureType, .NETWORK_POLICY_MISMATCH)
    }

    func testEmptyResponseMapsToContentFailed() {
        let error = ErrorMapper.readerError(for: .emptyResponse)

        XCTAssertEqual(error.code, .parsingFailed)
        XCTAssertEqual(error.failure?.type, .CONTENT_FAILED)
    }
}
