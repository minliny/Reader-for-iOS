import XCTest
import ReaderCoreNativeAdapter
@testable import ReaderShellValidation

final class RustCoreTTSServiceTests: XCTestCase {
    func testTypedRequestScopedPlanPlayReportNextStopMapping() async throws {
        let runtime = FakeTTSCommandRuntime()
        let service = RustCoreTTSService(runtime: runtime, requestTimeout: 1)
        let chapter = CoreTTSChapterReference(
            sourceID: "source-1",
            bookID: "book-1",
            chapterIndex: 4,
            chapterTitle: "Chapter 5",
            chapterURL: "https://example.test/chapter-5"
        )

        let plan = try await service.startPlanStage(
            chapter: chapter,
            content: "First paragraph.\n\nSecond paragraph.",
            correlationID: "tts-service"
        ).value()
        let playing = try await service.startQueueStage(
            plan: plan,
            correlationID: "tts-service"
        ).value()
        let reported = try await service.startReportDoneStage(
            chapter: chapter,
            sliceIndex: 0,
            correlationID: "tts-service"
        ).value()
        let completed = try await service.startNextStage(
            chapter: chapter,
            correlationID: "tts-service"
        ).value()
        let stopped = try await service.startStopStage(
            chapter: chapter,
            correlationID: "tts-service"
        ).value()

        XCTAssertEqual(runtime.methods, [
            "tts.slice",
            "tts.queue.play",
            "tts.queue.report-status",
            "tts.queue.next",
            "tts.queue.stop",
        ])
        XCTAssertEqual(plan.slices.map(\.text), ["First paragraph.", "Second paragraph."])
        XCTAssertEqual(playing.state, .playing)
        XCTAssertEqual(reported.sliceStatuses.first, .done)
        XCTAssertEqual(completed.state, .completed)
        XCTAssertEqual(stopped.state, .stopped)
        XCTAssertEqual(runtime.cancelledRequestIDs, [])

        let report = try XCTUnwrap(runtime.commands.first { $0["method"] as? String == "tts.queue.report-status" })
        let reportParams = try XCTUnwrap(report["params"] as? [String: Any])
        XCTAssertEqual(reportParams["sliceIndex"] as? Int, 0)
        XCTAssertEqual(reportParams["status"] as? String, "done")
    }

    func testTypedParsersRejectSparsePlanAndBroadNSNumberCoercion() throws {
        XCTAssertThrowsError(try RustCoreTTSService.parsePlan([
            "plan": [
                "chapter": chapterObject(),
                "strategy": "paragraph",
                "slices": [[
                    "index": 1,
                    "text": "Sparse",
                    "charStart": 0,
                    "charEnd": 6,
                    "paragraphIndex": 0,
                ]],
                "sourceCharCount": 6,
            ],
        ]))

        XCTAssertThrowsError(try RustCoreTTSService.parseSnapshotEnvelope([
            "snapshot": [
                "state": "playing",
                "currentSliceIndex": true,
                "totalSlices": 2,
                "completedSlices": 0,
                "chapter": chapterObject(),
                "sliceStatuses": ["speaking", "pending"],
            ],
        ]))
    }

    private func chapterObject() -> [String: Any] {
        [
            "sourceId": "source-1",
            "bookId": "book-1",
            "chapterIndex": 4,
            "chapterTitle": "Chapter 5",
            "chapterUrl": "https://example.test/chapter-5",
        ]
    }
}

private final class FakeTTSCommandRuntime: RustCoreCommandRuntime {
    var commands: [[String: Any]] = []
    var methods: [String] { commands.compactMap { $0["method"] as? String } }
    var cancelledRequestIDs: [UInt64] = []
    private var events: [UInt64: ReaderCoreNativeEvent] = [:]

    @discardableResult
    func send(json: Data) throws -> Int32 {
        let command = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        commands.append(command)
        let requestID = try XCTUnwrap((command["requestId"] as? NSNumber)?.uint64Value)
        let method = try XCTUnwrap(command["method"] as? String)
        let data: [String: Any]
        switch method {
        case "tts.slice":
            data = ["plan": planObject()]
        case "tts.queue.play":
            data = ["snapshot": snapshotObject(state: "playing", index: 0, completed: 0, statuses: ["speaking", "pending"])]
        case "tts.queue.report-status":
            data = ["snapshot": snapshotObject(state: "playing", index: 0, completed: 1, statuses: ["done", "pending"])]
        case "tts.queue.next":
            data = ["snapshot": snapshotObject(state: "completed", index: 1, completed: 2, statuses: ["done", "done"])]
        case "tts.queue.stop":
            data = ["snapshot": snapshotObject(state: "stopped", index: 1, completed: 2, statuses: ["done", "done"])]
        default:
            XCTFail("unexpected Core method \(method)")
            data = [:]
        }
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

    private func chapterObject() -> [String: Any] {
        [
            "sourceId": "source-1",
            "bookId": "book-1",
            "chapterIndex": 4,
            "chapterTitle": "Chapter 5",
            "chapterUrl": "https://example.test/chapter-5",
        ]
    }

    private func planObject() -> [String: Any] {
        [
            "chapter": chapterObject(),
            "strategy": "paragraph",
            "slices": [
                ["index": 0, "text": "First paragraph.", "charStart": 0, "charEnd": 16, "paragraphIndex": 0],
                ["index": 1, "text": "Second paragraph.", "charStart": 18, "charEnd": 35, "paragraphIndex": 1],
            ],
            "sourceCharCount": 35,
        ]
    }

    private func snapshotObject(
        state: String,
        index: Int,
        completed: Int,
        statuses: [String]
    ) -> [String: Any] {
        [
            "state": state,
            "currentSliceIndex": index,
            "totalSlices": 2,
            "completedSlices": completed,
            "chapter": chapterObject(),
            "sliceStatuses": statuses,
        ]
    }
}
