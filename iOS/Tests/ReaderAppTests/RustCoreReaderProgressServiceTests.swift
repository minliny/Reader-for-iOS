import XCTest
import ReaderCoreNativeAdapter
@testable import ReaderShellValidation

final class RustCoreReaderProgressServiceTests: XCTestCase {
    func testRequestScopedUpdateUsesExactCoreDTOAndRequiresMatchingStoredResult() async throws {
        let runtime = FakeProgressCommandRuntime()
        let service = RustCoreReaderProgressService(runtime: runtime, requestTimeout: 1)
        let request = progressRequest()

        let result = try await service.startUpdateStage(
            request,
            correlationID: "page-progress-1"
        ).value()

        let command = try XCTUnwrap(runtime.commands.first)
        XCTAssertEqual(command["method"] as? String, "reading.progress.update")
        let params = try XCTUnwrap(command["params"] as? [String: Any])
        XCTAssertEqual(Set(params.keys), [
            "sourceId", "bookId", "deviceId", "updatedAt", "chapterIndex",
            "chapterOffset", "chapterProgress", "locationRevision",
        ])
        XCTAssertEqual(params["sourceId"] as? String, request.sourceID)
        XCTAssertEqual(params["bookId"] as? String, request.bookID)
        XCTAssertEqual(params["updatedAt"] as? Int64, request.updatedAt)
        XCTAssertEqual(params["chapterIndex"] as? Int, request.chapterIndex)
        XCTAssertEqual(params["chapterOffset"] as? Int, request.chapterOffset)
        XCTAssertEqual(params["chapterProgress"] as? Double, request.chapterProgress)
        XCTAssertEqual(params["locationRevision"] as? String, request.locationRevision)
        XCTAssertEqual(result.sourceID, request.sourceID)
        XCTAssertEqual(result.bookID, request.bookID)
        XCTAssertEqual(result.locationRevision, request.locationRevision)
        XCTAssertTrue(result.stored)
        XCTAssertEqual(runtime.cancelledRequestIDs, [])
    }

    func testStrictParserRejectsFalseNumericOrUnknownStoredResults() throws {
        var storedFalse = validResult()
        storedFalse["stored"] = false

        var numericStored = validResult()
        numericStored["stored"] = 1

        var missingRevision = validResult()
        missingRevision.removeValue(forKey: "locationRevision")

        var unknownField = validResult()
        unknownField["bookName"] = "legacy-alias"

        var fractionalIndex = validResult()
        fractionalIndex["chapterIndex"] = 4.5

        var millisecondTimestamp = validResult()
        millisecondTimestamp["updatedAt"] = 1_720_000_000_000

        for payload in [
            storedFalse, numericStored, missingRevision, unknownField,
            fractionalIndex, millisecondTimestamp,
        ] {
            XCTAssertThrowsError(try RustCoreReaderProgressService.parseResult(payload))
        }
    }

    func testRequestScopedServiceRejectsMismatchedCoreIdentity() async throws {
        let runtime = FakeProgressCommandRuntime()
        runtime.resultOverride = ["bookId": "other-book"]
        let service = RustCoreReaderProgressService(runtime: runtime, requestTimeout: 1)

        do {
            _ = try await service.startUpdateStage(
                progressRequest(),
                correlationID: "page-progress-mismatch"
            ).value()
            XCTFail("mismatched Core identity must not commit")
        } catch {}
    }

    func testRequestValidationRejectsMillisecondsAndIncompleteIdentityInputs() {
        let runtime = FakeProgressCommandRuntime()
        let service = RustCoreReaderProgressService(runtime: runtime, requestTimeout: 1)
        let invalid = CoreReaderProgressStageRequest(
            sourceID: " ",
            bookID: "book-1",
            updatedAt: 0,
            chapterIndex: 4,
            chapterOffset: 120,
            chapterProgress: 0.5,
            locationRevision: "revision"
        )

        XCTAssertThrowsError(try service.startUpdateStage(invalid, correlationID: "progress-invalid"))

        let milliseconds = CoreReaderProgressStageRequest(
            sourceID: "source-1",
            bookID: "book-1",
            updatedAt: 1_720_000_000_000,
            chapterIndex: 4,
            chapterOffset: 120,
            chapterProgress: 0.5,
            locationRevision: "revision"
        )
        XCTAssertThrowsError(try service.startUpdateStage(milliseconds, correlationID: "progress-milliseconds"))
    }

    private func progressRequest() -> CoreReaderProgressStageRequest {
        CoreReaderProgressStageRequest(
            sourceID: "source-1",
            bookID: "book-1",
            deviceID: "ios-device-1",
            updatedAt: 1_720_000_000,
            chapterIndex: 4,
            chapterOffset: 120,
            chapterProgress: 0.5,
            locationRevision: "reader-location-v1:book-1:4:120"
        )
    }

    private func validResult() -> [String: Any] {
        [
            "sourceId": "source-1",
            "bookId": "book-1",
            "deviceId": "ios-device-1",
            "updatedAt": 1_720_000_000,
            "chapterIndex": 4,
            "chapterOffset": 120,
            "chapterProgress": 0.5,
            "locationRevision": "reader-location-v1:book-1:4:120",
            "stored": true,
        ]
    }
}

private final class FakeProgressCommandRuntime: RustCoreCommandRuntime {
    var commands: [[String: Any]] = []
    var cancelledRequestIDs: [UInt64] = []
    var resultOverride: [String: Any] = [:]
    private var events: [UInt64: ReaderCoreNativeEvent] = [:]

    @discardableResult
    func send(json: Data) throws -> Int32 {
        let command = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        commands.append(command)
        let requestID = try XCTUnwrap((command["requestId"] as? NSNumber)?.uint64Value)
        let params = try XCTUnwrap(command["params"] as? [String: Any])
        var data = params
        data["stored"] = true
        data.merge(resultOverride, uniquingKeysWith: { _, override in override })
        events[requestID] = try ReaderCoreNativeEvent(data: JSONSerialization.data(withJSONObject: [
            "type": "result",
            "requestId": NSNumber(value: requestID),
            "data": data,
        ]))
        return 0
    }

    func pollEvent(requestId: UInt64) -> ReaderCoreNativeEvent? {
        events.removeValue(forKey: requestId)
    }

    func cancel(requestId: UInt64) throws {
        cancelledRequestIDs.append(requestId)
    }
}
