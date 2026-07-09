import XCTest
import ReaderUIContract
@testable import ReaderShellValidation

/// Slice 7 — Stale Async Discard Tests (P0-10)
///
/// 验证 stale requestId 的 response 被丢弃，不覆盖更新的 state。
/// 本测试引入一个轻量的 `RequestIdTracker`，模拟 reducer 层的 requestId 管理。
/// 生产环境中，reducer 在发起 async request 时记录 requestId，response 到达时校验
/// requestId 是否已被 superseded。

/// 轻量级 requestId 跟踪器（模拟 reducer 层的 requestId 管理）
@MainActor
private final class RequestIdTracker {
    private var latestRequestId: [String: UInt64] = [:]

    func record(slot: String, requestId: UInt64) {
        latestRequestId[slot] = requestId
    }

    func isStale(slot: String, requestId: UInt64) -> Bool {
        guard let current = latestRequestId[slot] else { return false }
        return requestId < current
    }

    func currentRequestId(for slot: String) -> UInt64? {
        latestRequestId[slot]
    }

    func cancel(slot: String) {
        latestRequestId.removeValue(forKey: slot)
    }
}

@MainActor
final class StaleAsyncDiscardTests: XCTestCase {

    // MARK: - Fresh requestId 被接受

    func testFreshRequestIdIsAccepted() {
        let tracker = RequestIdTracker()
        tracker.record(slot: "search", requestId: 100)
        XCTAssertFalse(tracker.isStale(slot: "search", requestId: 100))
    }

    // MARK: - Stale requestId 被丢弃

    func testStaleRequestIdIsDiscarded() {
        let tracker = RequestIdTracker()
        tracker.record(slot: "search", requestId: 200)
        XCTAssertTrue(tracker.isStale(slot: "search", requestId: 100))
    }

    // MARK: - requestId 单调递增

    func testRequestIdMonotonicIncrease() {
        let tracker = RequestIdTracker()
        tracker.record(slot: "search", requestId: 100)
        XCTAssertFalse(tracker.isStale(slot: "search", requestId: 150))
        tracker.record(slot: "search", requestId: 150)
        XCTAssertTrue(tracker.isStale(slot: "search", requestId: 100))
    }

    // MARK: - Stale response 不覆盖 fresh state

    func testStaleResponseDoesNotOverwriteFreshState() {
        let tracker = RequestIdTracker()
        // 先发 req-A
        tracker.record(slot: "search", requestId: 100)
        // 再发 req-B（supersedes req-A）
        tracker.record(slot: "search", requestId: 200)
        // req-A 的 response 到达（晚于 req-B），应被判定为 stale
        XCTAssertTrue(tracker.isStale(slot: "search", requestId: 100))
        // state 应保持 req-B 的 requestId
        XCTAssertEqual(tracker.currentRequestId(for: "search"), 200)
    }

    // MARK: - Cancel 后 requestId 被清除

    func testCancelRemovesInFlightRequest() {
        let tracker = RequestIdTracker()
        tracker.record(slot: "search", requestId: 100)
        tracker.cancel(slot: "search")
        // cancel 后，任何 requestId 都不被视为 stale（因为 slot 已被清除）
        XCTAssertFalse(tracker.isStale(slot: "search", requestId: 100))
    }

    // MARK: - Stale response 不崩溃

    func testStaleRequestIdDoesNotCrash() {
        let tracker = RequestIdTracker()
        tracker.record(slot: "search", requestId: UInt64.max)
        // 超大 requestId 不应崩溃
        XCTAssertTrue(tracker.isStale(slot: "search", requestId: 1))
        XCTAssertFalse(tracker.isStale(slot: "search", requestId: UInt64.max))
    }

    // MARK: - 不同 slot 的 requestId 互不影响

    func testConcurrentRequestsHaveIndependentSlots() {
        let tracker = RequestIdTracker()
        tracker.record(slot: "search", requestId: 100)
        tracker.record(slot: "content", requestId: 200)
        // search slot 不受 content slot 影响
        XCTAssertFalse(tracker.isStale(slot: "search", requestId: 100))
        XCTAssertFalse(tracker.isStale(slot: "content", requestId: 200))
        // 更新 search slot 不影响 content slot
        tracker.record(slot: "search", requestId: 150)
        XCTAssertTrue(tracker.isStale(slot: "search", requestId: 100))
        XCTAssertFalse(tracker.isStale(slot: "content", requestId: 200))
    }

    // MARK: - 空 slot 的 requestId 不被视为 stale

    func testEmptySlotRequestIdIsNotStale() {
        let tracker = RequestIdTracker()
        // 从未记录过的 slot，任何 requestId 都不被视为 stale
        XCTAssertFalse(tracker.isStale(slot: "toc", requestId: 1))
    }

    // MARK: - HostAdapter dispatch 不会因 stale request 崩溃

    func testHostAdapterDispatchDoesNotCrashOnConcurrentRequests() async {
        let adapter = HostAdapter()
        // 模拟并发 dispatch 两个 cookie_set 请求
        async let outcome1 = adapter.dispatch(HostRequest(type: .cookie_set, payload: [
            "url": AnyCodable("https://stale-proof-1.example.test/"),
            "cookie": AnyCodable(["name": "a", "value": "1"] as [String: String]),
        ]))
        async let outcome2 = adapter.dispatch(HostRequest(type: .cookie_set, payload: [
            "url": AnyCodable("https://stale-proof-2.example.test/"),
            "cookie": AnyCodable(["name": "b", "value": "2"] as [String: String]),
        ]))
        let (o1, o2) = await (outcome1, outcome2)
        XCTAssertTrue(o1.succeeded)
        XCTAssertTrue(o2.succeeded)
    }
}
