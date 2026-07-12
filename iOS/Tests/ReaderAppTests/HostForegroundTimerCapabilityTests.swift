import XCTest
import ReaderUIContract
@testable import ReaderShellValidation

final class HostForegroundTimerCapabilityTests: XCTestCase {
    func testCanonicalTimerArmsOneShotAndFiresExactlyOnce() async throws {
        let recorder = TimerFireRecorder()
        let handler = HostForegroundTimerCapability { correlationID, generation in
            await recorder.record(correlationID: correlationID, generation: generation)
        }
        let outcome = try await handler.handle(HostRequest(
            type: .timer_foreground_arm,
            payload: timerPayload(id: "auto-1", generation: 7)
        ))

        XCTAssertTrue(outcome.succeeded)
        try await eventually { await recorder.count == 1 }
        try await Task.sleep(nanoseconds: 300_000_000)
        let finalCount = await recorder.count
        let finalCorrelationID = await recorder.lastCorrelationID
        let finalGeneration = await recorder.lastGeneration
        XCTAssertEqual(finalCount, 1)
        XCTAssertEqual(finalCorrelationID, "auto-1")
        XCTAssertEqual(finalGeneration, 7)
    }

    func testCancelInvalidatesTimerAndMalformedRepeatingRequestFailsClosed() async throws {
        let recorder = TimerFireRecorder()
        let store = HostForegroundTimerStore()
        let handler = HostForegroundTimerCapability(store: store) { correlationID, generation in
            await recorder.record(correlationID: correlationID, generation: generation)
        }
        _ = try await handler.handle(HostRequest(
            type: .timer_foreground_arm,
            payload: timerPayload(id: "auto-cancel", generation: 3)
        ))
        let cancel = try await handler.handle(HostRequest(
            type: .timer_foreground_cancel,
            payload: timerPayload(id: "auto-cancel", generation: 3)
        ))
        XCTAssertTrue(cancel.succeeded)
        XCTAssertEqual(cancel.result?["cancelled"]?.value as? Bool, true)
        try await Task.sleep(nanoseconds: 300_000_000)
        let cancelledCount = await recorder.count
        XCTAssertEqual(cancelledCount, 0)

        var malformed = timerPayload(id: "repeat", generation: 1)
        malformed["oneShot"] = AnyCodable(false)
        let rejected = try await handler.handle(HostRequest(
            type: .timer_foreground_arm,
            payload: malformed
        ))
        XCTAssertFalse(rejected.succeeded)
        guard case .invalidParams = rejected.error else {
            return XCTFail("repeating timer must fail with invalidParams")
        }
    }

    func testStaleGenerationCancelCannotKillReplacementTimer() async throws {
        let recorder = TimerFireRecorder()
        let store = HostForegroundTimerStore()
        let handler = HostForegroundTimerCapability(store: store) { correlationID, generation in
            await recorder.record(correlationID: correlationID, generation: generation)
        }
        _ = try await handler.handle(HostRequest(
            type: .timer_foreground_arm,
            payload: timerPayload(id: "auto-reuse", generation: 1)
        ))
        _ = try await handler.handle(HostRequest(
            type: .timer_foreground_arm,
            payload: timerPayload(id: "auto-reuse", generation: 2)
        ))

        let staleCancel = try await handler.handle(HostRequest(
            type: .timer_foreground_cancel,
            payload: timerPayload(id: "auto-reuse", generation: 1)
        ))
        XCTAssertTrue(staleCancel.succeeded)
        XCTAssertEqual(staleCancel.result?["cancelled"]?.value as? Bool, false)

        try await eventually { await recorder.count == 1 }
        let finalGeneration = await recorder.lastGeneration
        XCTAssertEqual(finalGeneration, 2)
    }

    private func timerPayload(id: String, generation: Int) -> [String: AnyCodable] {
        [
            "timerId": AnyCodable(id),
            "correlationId": AnyCodable(id),
            "delayMs": AnyCodable(250),
            "generation": AnyCodable(generation),
            "oneShot": AnyCodable(true),
            "foregroundOnly": AnyCodable(true),
        ]
    }

    private func eventually(
        attempts: Int = 500,
        _ condition: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<attempts {
            if await condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("timer did not fire")
    }
}

private actor TimerFireRecorder {
    private(set) var count = 0
    private(set) var lastCorrelationID: String?
    private(set) var lastGeneration: Int?

    func record(correlationID: String, generation: Int) {
        count += 1
        lastCorrelationID = correlationID
        lastGeneration = generation
    }
}
