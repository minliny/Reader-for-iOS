import XCTest
import UIKit
import Vision

/// Select only after a read-only snapshot of the actual admitted library.
/// Environment belongs to this UITest runner, never the App. No queue, cache,
/// network response, delay, clock or original file is injected or replaced.
final class ReaderOnlineDownloadControlJourneyTests: XCTestCase {
    private enum Prerequisite: Error { case invalid(String) }
    private struct Book {
        let source: String
        let id: String
        let title: String
        var identity: String { source + "|" + id }
    }
    private struct Observation: Equatable {
        let state: String
        let attempts: UInt32
    }

    override func setUpWithError() throws { continueAfterFailure = false }

    func testActualFiniteDownloadPauseResumeCancelAndColdRetention() throws {
        let book = Book(source: try required("READER_ONLINE_SOURCE_ID"), id: try required("READER_ONLINE_BOOK_ID"),
                        title: try required("READER_ONLINE_BOOK_TITLE"))
        let first = try unsigned("READER_ONLINE_CONTROL_FIRST_INDEX")
        let count = try unsigned("READER_ONLINE_CONTROL_CHAPTER_COUNT")
        guard (8...12).contains(count), UInt64(first) + UInt64(count) <= UInt64(UInt32.max) else {
            XCTFail("Select only 8–12 actual missing readable canonical chapters, not a whole-book timing workaround")
            throw Prerequisite.invalid("finite original range")
        }
        let chosenRange = first..<(first + count)
        let oldCompleted = try existingCompletedIndexes()
        guard oldCompleted.allSatisfy({ !chosenRange.contains($0) }), !oldCompleted.isEmpty || count >= 9 else {
            XCTFail("Existing completed chapters must be outside the new batch; without one, reserve one of 9–12 new chapters as a completed baseline and leave at least eight for controls")
            throw Prerequisite.invalid("completed protection prerequisite")
        }

        let app = XCUIApplication(); app.launch(); open(book, app: app)
        let originalChapter = try currentChapter(book, app: app)
        for index in chosenRange {
            XCTAssertGreaterThan(abs(Int64(index) - Int64(originalChapter)), 2,
                                 "Every selected chapter must be outside the actual current +/-2 reading cache window")
        }
        hideControls(app)
        let originalProgress = app.staticTexts["reading-progress"].label
        let originalAnchor = try anchor(app)
        downloads(app)
        var protected: [UInt32: Observation] = [:]
        for index in oldCompleted.sorted() {
            let value = try observe(index, book: book, app: app)
            XCTAssertEqual(value.state, "已完成", "The optional original completed indexes must be actual completed tasks in this exact source")
            protected[index] = value
        }
        for index in chosenRange {
            let value = try observe(index, book: book, app: app)
            XCTAssertEqual(value.state, "未下载", "Do not clear, reuse or reclassify an existing cached/task chapter to create a missing prerequisite")
            XCTAssertEqual(value.attempts, 0)
        }
        facts(["sourceID": book.source, "bookID": book.id, "bookTitle": book.title,
               "currentChapter": String(originalChapter), "firstIndex": String(first), "count": String(count),
               "existingCompletedIndexes": oldCompleted.sorted().map(String.init).joined(separator: ",")],
              name: "actual-finite-download-original-selection")

        var controlStart = first
        if oldCompleted.isEmpty {
            dispatch(first..<(first + 1), app: app)
            waitState("已完成", index: first, book: book, app: app)
            waitForBatchOwner(app)
            let baseline = try observe(first, book: book, app: app)
            XCTAssertGreaterThan(baseline.attempts, 0)
            protected[first] = baseline
            controlStart += 1
        }
        let split = controlStart + (chosenRange.upperBound - controlStart) / 2
        let firstBatch = controlStart..<split
        let secondBatch = split..<chosenRange.upperBound
        XCTAssertGreaterThanOrEqual(firstBatch.count, 4); XCTAssertGreaterThanOrEqual(secondBatch.count, 4)
        let pauseIndex = firstBatch.upperBound - 1
        let cancelIndex = secondBatch.upperBound - 1

        dispatch(firstBatch, app: app)
        revealChapter(pauseIndex, book: book, app: app)
        let pausedState = state(pauseIndex, book: book, app: app)
        let pause = control("pause", index: pauseIndex, book: book, app: app)
        wait("Observe this exact newly dispatched task queued/inProgress before pausing; natural completion is a failed control prerequisite", timeout: 30) {
            pausedState.exists && ["排队中", "下载中"].contains(pausedState.label)
                && pause.exists && pause.isHittable && pause.isEnabled
        }
        let beforePause = try observe(pauseIndex, book: book, app: app)
        pause.tap()
        let resume = control("resume", index: pauseIndex, book: book, app: app)
        wait("The original pause must actually reach paused and release its action owner, not remain pending", timeout: 90) {
            pausedState.exists && pausedState.label == "已暂停" && resume.exists && resume.isEnabled
        }
        let paused = try observe(pauseIndex, book: book, app: app)
        // Core returns the active attempt charge on pause(inProgress). This is
        // its actual task counter, not a physical HTTP-attempt or lease ID.
        let returnedCharge = Int64(beforePause.attempts) - Int64(paused.attempts)
        XCTAssertTrue((0...1).contains(returnedCharge))
        facts(["chapterIndex": String(pauseIndex), "observedLiveState": beforePause.state,
               "observedLiveAttempts": String(beforePause.attempts), "pausedAttempts": String(paused.attempts)],
              name: "actual-download-pause-original-task")
        keep(app, name: "actual-finite-download-paused")
        for index in firstBatch where index != pauseIndex { waitState("已完成", index: index, book: book, app: app) }
        waitForBatchOwner(app)
        XCTAssertEqual(try observe(pauseIndex, book: book, app: app), paused,
                       "Finishing the original batch must not overwrite its paused task")
        revealChapter(pauseIndex, book: book, app: app)
        XCTAssertTrue(resume.exists && resume.isEnabled && resume.isHittable); resume.tap()
        waitState("已完成", index: pauseIndex, book: book, app: app)
        let resumed = try observe(pauseIndex, book: book, app: app)
        XCTAssertEqual(resumed.attempts, paused.attempts + 1, "The same resumed Core task must acquire its real next attempt")
        keep(app, name: "actual-finite-download-resumed-and-completed")

        dispatch(secondBatch, app: app)
        revealChapter(cancelIndex, book: book, app: app)
        let cancelledState = state(cancelIndex, book: book, app: app)
        let cancel = control("cancel", index: cancelIndex, book: book, app: app)
        wait("Observe a different new task queued/inProgress before cancellation; do not cancel an already completed task", timeout: 30) {
            cancelledState.exists && ["排队中", "下载中"].contains(cancelledState.label)
                && cancel.exists && cancel.isEnabled && cancel.isHittable
        }
        let beforeCancel = try observe(cancelIndex, book: book, app: app)
        cancel.tap()
        let continueCancelled = control("resume", index: cancelIndex, book: book, app: app)
        wait("The exact cancel must actually reach cancelled and release its original action owner", timeout: 90) {
            cancelledState.exists && cancelledState.label == "已取消" && continueCancelled.exists && continueCancelled.isEnabled
        }
        facts(["chapterIndex": String(cancelIndex), "observedLiveState": beforeCancel.state,
               "observedLiveAttempts": String(beforeCancel.attempts)], name: "actual-download-cancel-original-task")
        keep(app, name: "actual-finite-download-cancelled")
        for index in secondBatch where index != cancelIndex { waitState("已完成", index: index, book: book, app: app) }
        waitForBatchOwner(app)

        var settled = protected
        for index in chosenRange {
            let value = try observe(index, book: book, app: app)
            XCTAssertEqual(value.state, index == cancelIndex ? "已取消" : "已完成")
            settled[index] = value
        }
        for (index, value) in protected { XCTAssertEqual(try observe(index, book: book, app: app), value) }
        XCTAssertEqual(settled[pauseIndex], resumed)
        app.buttons["online-download-close"].tap()
        XCTAssertEqual(try currentChapter(book, app: app), originalChapter)
        hideControls(app)
        try visible(originalAnchor, app: app, name: "actual-download-controls-preserved-visible-body")
        XCTAssertEqual(app.staticTexts["reading-progress"].label, originalProgress)
        leave(app)
        app.terminate(); app.launch(); open(book, app: app)
        XCTAssertEqual(try currentChapter(book, app: app), originalChapter)
        hideControls(app)
        try visible(originalAnchor, app: app, name: "actual-download-controls-cold-body-and-position")
        XCTAssertEqual(app.staticTexts["reading-progress"].label, originalProgress)
        downloads(app)
        for index in settled.keys.sorted() {
            XCTAssertEqual(try observe(index, book: book, app: app), settled[index],
                           "Cold startup must preserve the actual completed/cancelled task and its Core attempt counter")
        }
        facts(Dictionary(uniqueKeysWithValues: settled.keys.sorted().map { index in
            (String(index), settled[index].map { $0.state + ":" + String($0.attempts) } ?? "missing")
        }), name: "actual-finite-download-cold-task-projection")
        app.buttons["online-download-close"].tap(); leave(app)
        // No queue/cache cleanup and no whole-book request. Root may add exact
        // original operation/lease evidence from the read-only retained ledger;
        // these native observations never manufacture receipt identities.
    }

    func testActualCurrentCanonicalWholeBookControlsAndColdCompletion() throws {
        let book = Book(source: try required("READER_ONLINE_SOURCE_ID"), id: try required("READER_ONLINE_BOOK_ID"),
                        title: try required("READER_ONLINE_BOOK_TITLE"))
        let canonicalCount = try unsigned("READER_ONLINE_WHOLE_CHAPTER_COUNT")
        let pauseIndex = try unsigned("READER_ONLINE_WHOLE_PAUSE_INDEX")
        let cancelIndex = try unsigned("READER_ONLINE_WHOLE_CANCEL_INDEX")
        let snapshot = try required("READER_ONLINE_WHOLE_INPUT_SNAPSHOT_SHA256")
        let pieces = try required("READER_ONLINE_WHOLE_READABLE_INDEXES").split(separator: ",", omittingEmptySubsequences: false)
        let indexes = pieces.compactMap { UInt32($0.trimmingCharacters(in: .whitespaces)) }
        let readable = Set(indexes), oldCompleted = try existingCompletedIndexes()
        // This is the real currently admitted Baidu catalog extent, not the
        // historical 1,279-chapter other source or a larger finite delay batch.
        guard book.source == "https://dushu.baidu.com/", canonicalCount == 50,
              indexes.count == pieces.count, readable == Set(UInt32(0)..<canonicalCount),
              indexes.count == readable.count, readable.contains(pauseIndex), readable.contains(cancelIndex),
              pauseIndex != cancelIndex, !oldCompleted.isEmpty, oldCompleted.isSubset(of: readable),
              !oldCompleted.contains(pauseIndex), !oldCompleted.contains(cancelIndex),
              snapshot.count == 64, snapshot.allSatisfy({ $0.isHexDigit }) else {
            XCTFail("Use Root's fresh exact current Baidu 50-readable-chapter snapshot and two distinct genuinely missing control targets; preserve every original completed task")
            throw Prerequisite.invalid("actual whole-book selection")
        }
        let app = XCUIApplication(); app.launch(); open(book, app: app)
        let originalChapter = try currentChapter(book, app: app)
        for index in [pauseIndex, cancelIndex] {
            XCTAssertGreaterThan(abs(Int64(index) - Int64(originalChapter)), 2,
                                 "Control targets must be outside the actual current +/-2 reading cache window")
        }
        hideControls(app)
        let originalProgress = app.staticTexts["reading-progress"].label
        let originalAnchor = try anchor(app)
        downloads(app)
        for index in oldCompleted.sorted() {
            XCTAssertEqual(try observe(index, book: book, app: app).state, "已完成")
        }
        for index in [pauseIndex, cancelIndex] {
            let original = try observe(index, book: book, app: app)
            XCTAssertEqual(original.state, "未下载", "Never clear/reclassify cached or existing work to create control timing")
            XCTAssertEqual(original.attempts, 0)
        }
        let whole = app.buttons["整本下载"]
        revealTop(whole, app: app)
        XCTAssertEqual(app.textFields["末章"].value as? String, String(canonicalCount),
                       "The actual initial catalog extent must equal the exact read-only snapshot")
        XCTAssertTrue(whole.exists && whole.isEnabled && whole.isHittable,
                      "An unresolved original parent is a failed prerequisite, not permission to create another intent")
        facts(["sourceID": book.source, "bookID": book.id, "currentCanonicalCount": String(canonicalCount),
               "readableIndexes": readable.sorted().map(String.init).joined(separator: ","),
               "pauseIndex": String(pauseIndex), "cancelIndex": String(cancelIndex),
               "originalCompletedIndexes": oldCompleted.sorted().map(String.init).joined(separator: ","),
               "inputSnapshotSHA256": snapshot,
               "scope": "Current complete Baidu catalog only; original other-source catalog is protected separately by Root"],
              name: "actual-whole-book-original-selection")
        // Exactly one real whole-book intent. Do not edit range fields, press
        // Refresh/Update Catalog, clear caches or repeat to obtain a slow run.
        whole.tap()
        let paused = try attemptWholeControl("pause", terminal: "已暂停", index: pauseIndex, book: book, app: app)
        let cancelled = try attemptWholeControl("cancel", terminal: "已取消", index: cancelIndex, book: book, app: app)
        // Finish consuming the ORIGINAL whole-book parent and its leases
        // before any resume creates its existing original-ID :acquire child.
        waitForBatchOwner(app)
        var settled: [UInt32: Observation] = [:]
        for index in readable.sorted() {
            let expected = index == pauseIndex && paused != nil ? "已暂停"
                : index == cancelIndex && cancelled != nil ? "已取消" : "已完成"
            waitState(expected, index: index, book: book, app: app)
            let value = try observe(index, book: book, app: app)
            if expected == "已完成" { XCTAssertGreaterThan(value.attempts, 0) }
            settled[index] = value
        }
        if let paused { XCTAssertEqual(settled[pauseIndex], paused) }
        if let cancelled { XCTAssertEqual(settled[cancelIndex], cancelled) }
        facts(Dictionary(uniqueKeysWithValues: settled.keys.sorted().map { index in
            (String(index), settled[index].map { $0.state + ":" + String($0.attempts) } ?? "missing")
        }), name: "actual-whole-original-parent-terminal-task-projection")
        keep(app, name: "actual-whole-original-parent-consumed")
        app.buttons["online-download-close"].tap()
        XCTAssertEqual(try currentChapter(book, app: app), originalChapter)
        hideControls(app)
        try visible(originalAnchor, app: app, name: "actual-whole-parent-preserved-original-body")
        XCTAssertEqual(app.staticTexts["reading-progress"].label, originalProgress)
        leave(app); app.terminate(); app.launch(); open(book, app: app)
        XCTAssertEqual(try currentChapter(book, app: app), originalChapter)
        hideControls(app)
        try visible(originalAnchor, app: app, name: "actual-whole-parent-cold-original-body")
        XCTAssertEqual(app.staticTexts["reading-progress"].label, originalProgress)
        downloads(app)
        for index in readable.sorted() {
            XCTAssertEqual(try observe(index, book: book, app: app), settled[index],
                           "Cold startup must preserve each actual original task outcome and attempt counter")
        }
        keep(app, name: "actual-whole-parent-cold-task-retention")
        for (index, stopped) in [(pauseIndex, paused), (cancelIndex, cancelled)] {
            guard let stopped else { continue }
            revealChapter(index, book: book, app: app)
            let resume = control("resume", index: index, book: book, app: app)
            wait("The preceding original resume/control owner must settle before another Continue", timeout: 300) {
                resume.exists && resume.isEnabled && resume.isHittable
            }
            XCTAssertTrue(resume.exists && resume.isEnabled && resume.isHittable)
            resume.tap()
            waitState("已完成", index: index, book: book, app: app)
            let resumed = try observe(index, book: book, app: app)
            XCTAssertEqual(resumed.attempts, stopped.attempts + 1,
                           "The real existing task must acquire its next attempt through normal Continue")
            // This existing button consumes the separate canClear binding of
            // BOTH task action owners. Observe it, never tap or clear anything.
            // Fresh completed state alone cannot release the resume parent.
            let row = exact("online-download-attempt:" + book.identity + ":" + String(index) + ":" + String(resumed.attempts), app: app)
            let clear = row.buttons["清除此章下载"]
            wait("The original Continue acquisition must release its real action owner after completion", timeout: 300) {
                clear.exists && clear.isEnabled
            }
        }
        var completed: [UInt32: Observation] = [:]
        for index in readable.sorted() {
            let value = try observe(index, book: book, app: app)
            XCTAssertEqual(value.state, "已完成"); XCTAssertGreaterThan(value.attempts, 0)
            completed[index] = value
        }
        // These are mutually exclusive Core state buckets. A chapter with a
        // completed explicit task belongs to completedCount, while cachedCount
        // describes a reading-cache-only chapter. Root separately verifies
        // all 50 physical cached bodies and the original lease/report ACKs.
        let summary = "已完成 \(readable.count) · 缓存 0 · 失败 0 · 暂停 0"
        revealTop(whole, app: app)
        wait("All CURRENT readable canonical chapters must occupy the actual completed-task bucket", timeout: 30) {
            app.staticTexts[summary].exists
        }
        keep(app, name: "actual-current-whole-book-completed-and-cached")
        app.buttons["online-download-close"].tap(); leave(app)
        app.terminate(); app.launch(); open(book, app: app)
        XCTAssertEqual(try currentChapter(book, app: app), originalChapter)
        hideControls(app)
        try visible(originalAnchor, app: app, name: "actual-current-whole-completed-cold-original-body")
        XCTAssertEqual(app.staticTexts["reading-progress"].label, originalProgress)
        downloads(app)
        for index in readable.sorted() { XCTAssertEqual(try observe(index, book: book, app: app), completed[index]) }
        revealTop(whole, app: app); XCTAssertTrue(app.staticTexts[summary].exists)
        facts(["currentReadableCount": String(readable.count), "allCurrentTaskStatesCompleted": "true",
               "physicalCacheProof": "Root must separately verify all physical bodies and original lease/report ACKs; the UI buckets do not count a chapter twice",
               "coldTaskAndAttemptRetention": "true", "pauseActuallyConfirmed": String(paused != nil),
               "cancelActuallyConfirmed": String(cancelled != nil),
               "receiptEvidence": "Original operation IDs/outcomes come only from Root's retained read-only ledger, not fresh task rows",
               "protectedCompletedBoundary": "Whole-book readmission may update current task generation/timestamps; prior bodies/resources and other-source full-row SHAs are protected by Root"],
              name: "actual-current-whole-completion-separate-from-control-prerequisite")
        keep(app, name: "actual-current-whole-completed-cold-retention")
        app.buttons["online-download-close"].tap(); leave(app)
        // Keep genuine whole completion evidence even if nature left no live
        // control opportunity. An unissued pause/cancel is still a FAIL here.
        XCTAssertTrue(paused != nil, "Pause was not confirmed against a live original whole-book task; completion alone cannot pass the control prerequisite")
        XCTAssertTrue(cancelled != nil, "Cancel was not confirmed against a different live original whole-book task; never slow, clear or repeat the batch to manufacture this prerequisite")
    }

    private func attemptWholeControl(_ action: String, terminal: String, index: UInt32,
                                     book: Book, app: XCUIApplication) throws -> Observation? {
        revealChapter(index, book: book, app: app)
        let value = state(index, book: book, app: app), button = control(action, index: index, book: book, app: app)
        let live = ["排队中", "下载中"], stopped = ["已完成", "失败", "已暂停", "已取消"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            value.exists && (stopped.contains(value.label)
                || live.contains(value.label) && button.exists && button.isEnabled && button.isHittable)
        }, object: nil)
        let readyResult = XCTWaiter.wait(for: [ready], timeout: 30)
        let before = try observe(index, book: book, app: app)
        guard readyResult == .completed, live.contains(before.state), button.exists,
              button.isEnabled, button.isHittable, live.contains(value.label) else {
            facts(["action": action, "chapterIndex": String(index), "observedState": before.state,
                   "attempts": String(before.attempts), "issued": "false", "confirmed": "false",
                   "reason": "No actual live enabled control opportunity; retain whole completion evidence and fail the control prerequisite"],
                  name: "actual-whole-" + action + "-prerequisite-not-met")
            keep(app, name: "actual-whole-" + action + "-not-issued")
            return nil
        }
        button.tap()
        let resume = control("resume", index: index, book: book, app: app)
        let acknowledged = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            value.exists && (value.label == terminal && resume.exists && resume.isEnabled
                || stopped.contains(value.label) && value.label != terminal)
        }, object: nil)
        let result = XCTWaiter.wait(for: [acknowledged], timeout: 90)
        let after = try observe(index, book: book, app: app)
        let confirmed = result == .completed && after.state == terminal && resume.exists && resume.isEnabled
        facts(["action": action, "chapterIndex": String(index), "beforeState": before.state,
               "beforeAttempts": String(before.attempts), "afterState": after.state,
               "afterAttempts": String(after.attempts), "issued": "true", "confirmed": String(confirmed)],
              name: "actual-whole-" + action + "-original-task")
        keep(app, name: "actual-whole-" + action + "-original-task")
        if confirmed && action == "pause" {
            XCTAssertTrue((0...1).contains(Int64(before.attempts) - Int64(after.attempts)),
                          "Core may return exactly the active attempt charge on real pause")
        }
        return confirmed ? after : nil
    }

    private func required(_ key: String) throws -> String {
        guard let value = ProcessInfo.processInfo.environment[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            XCTFail("Missing actual-library UITest runner prerequisite: " + key)
            throw Prerequisite.invalid(key)
        }
        return value
    }
    private func unsigned(_ key: String) throws -> UInt32 {
        let text = try required(key)
        guard let value = UInt32(text) else { XCTFail("Invalid canonical index/count: " + key); throw Prerequisite.invalid(key) }
        return value
    }
    private func existingCompletedIndexes() throws -> Set<UInt32> {
        // Omit only when Root's current read-only source/book snapshot found
        // no completed tasks. Include every actual original completed index.
        guard let raw = ProcessInfo.processInfo.environment["READER_ONLINE_CONTROL_EXISTING_COMPLETED_INDEXES"],
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let pieces = raw.split(separator: ",", omittingEmptySubsequences: false)
        let indexes = pieces.compactMap { UInt32($0.trimmingCharacters(in: .whitespaces)) }
        guard indexes.count == pieces.count, Set(indexes).count == indexes.count else {
            XCTFail("Existing completed prerequisites must be exact, unique canonical indexes")
            throw Prerequisite.invalid("READER_ONLINE_CONTROL_EXISTING_COMPLETED_INDEXES")
        }
        return Set(indexes)
    }
    private func exact(_ id: String, type: XCUIElement.ElementType = .any, app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: type).matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }
    private func state(_ index: UInt32, book: Book, app: XCUIApplication) -> XCUIElement {
        exact("online-download-state:" + book.identity + ":" + String(index), type: .staticText, app: app)
    }
    private func control(_ action: String, index: UInt32, book: Book, app: XCUIApplication) -> XCUIElement {
        exact("online-download-" + action + ":" + book.identity + ":" + String(index), type: .button, app: app)
    }
    private func observe(_ index: UInt32, book: Book, app: XCUIApplication) throws -> Observation {
        revealChapter(index, book: book, app: app)
        let state = state(index, book: book, app: app)
        XCTAssertTrue(state.exists)
        let prefix = "online-download-attempt:" + book.identity + ":" + String(index) + ":"
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
        XCTAssertEqual(row.count, 1, "Read only this exact source/book/chapter's public task projection")
        let value = row.firstMatch.identifier
        guard let attempts = UInt32(value.dropFirst(prefix.count)) else {
            XCTFail("The actual chapter row must expose its Core attempt counter without changing spoken text")
            throw Prerequisite.invalid("actual task attempt")
        }
        return Observation(state: state.label, attempts: attempts)
    }
    private func waitState(_ expected: String, index: UInt32, book: Book, app: XCUIApplication) {
        revealChapter(index, book: book, app: app)
        let value = state(index, book: book, app: app)
        wait("The exact new chapter must actually become " + expected, timeout: 300) { value.exists && value.label == expected }
    }
    private func dispatch(_ range: Range<UInt32>, app: XCUIApplication) {
        let start = app.textFields["起章"], end = app.textFields["末章"]
        revealTop(start, app: app)
        replace(start, with: String(range.lowerBound + 1))
        replace(end, with: String(range.upperBound))
        XCTAssertEqual(start.value as? String, String(range.lowerBound + 1))
        XCTAssertEqual(end.value as? String, String(range.upperBound))
        let download = app.buttons["下载"]
        XCTAssertTrue(download.exists && download.isEnabled && download.isHittable); download.tap()
    }
    private func replace(_ field: XCUIElement, with value: String) {
        XCTAssertTrue(field.exists && field.isHittable)
        let previous = field.value as? String ?? ""
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + value)
    }
    private func waitForBatchOwner(_ app: XCUIApplication) {
        // Never tap this button. Its existing hasPending disabled binding is
        // the original batch owner's UI barrier, separate from fresh status.
        let barrier = app.buttons["整本下载"]
        revealTop(barrier, app: app)
        wait("The original finite batch owner must settle before another batch/acquisition", timeout: 300) { barrier.exists && barrier.isEnabled }
    }
    private func revealTop(_ target: XCUIElement, app: XCUIApplication) {
        let scroll = app.scrollViews["online-download-scroll"]
        XCTAssertTrue(scroll.exists)
        for _ in 0..<160 {
            if target.exists && target.isHittable { return }
            scroll.swipeDown()
        }
        XCTAssertTrue(target.exists && target.isHittable, app.debugDescription)
    }
    private func revealChapter(_ index: UInt32, book: Book, app: XCUIApplication) {
        let target = state(index, book: book, app: app), scroll = app.scrollViews["online-download-scroll"]
        XCTAssertTrue(scroll.exists)
        let prefix = "online-download-state:" + book.identity + ":"
        for _ in 0..<160 {
            if target.exists && target.isHittable { return }
            let visible = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).allElementsBoundByIndex
                .filter(\.isHittable).compactMap { UInt32($0.identifier.dropFirst(prefix.count)) }
            if let first = visible.min(), index < first { scroll.swipeDown() }
            else { scroll.swipeUp() }
        }
        XCTAssertTrue(target.exists && target.isHittable, "Reach the exact actual chapter through normal scrolling.\n" + app.debugDescription)
    }
    private func open(_ book: Book, app: XCUIApplication) {
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 25))
        if app.textFields["shelf-filter"].exists { app.buttons["搜索本地书架"].tap() }
        let rows = app.buttons.matching(NSPredicate(format: "identifier == %@", "book-" + book.id))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 20)); XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(rows.firstMatch.isHittable); rows.firstMatch.tap()
        XCTAssertTrue(app.textViews["reading-body"].waitForExistence(timeout: 180))
        controls(app)
        let title = exact("reading-book:" + book.identity, type: .staticText, app: app)
        XCTAssertTrue(title.exists); XCTAssertEqual(title.label, book.title)
    }
    private func currentChapter(_ book: Book, app: XCUIApplication) throws -> UInt32 {
        controls(app)
        XCTAssertTrue(exact("reading-book:" + book.identity, type: .staticText, app: app).exists)
        let prefix = "reading-chapter:"
        let row = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        return try XCTUnwrap(UInt32(row.identifier.dropFirst(prefix.count)))
    }
    private func controls(_ app: XCUIApplication) {
        if !app.buttons["reader-more"].isHittable {
            app.textViews["reading-body"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        }
        wait("Normal native reading controls must appear", timeout: 10) { app.buttons["reader-more"].isHittable }
    }
    private func hideControls(_ app: XCUIApplication) {
        let hide = app.buttons["收起阅读控制"]
        if hide.isHittable { hide.tap() }
        wait("Normal native reading controls must hide", timeout: 10) { !hide.isHittable }
    }
    private func downloads(_ app: XCUIApplication) {
        controls(app); app.buttons["reader-more"].tap()
        XCTAssertTrue(app.buttons["下载管理"].waitForExistence(timeout: 5)); app.buttons["下载管理"].tap()
        XCTAssertTrue(app.buttons["online-download-selected"].waitForExistence(timeout: 30))
    }
    private func leave(_ app: XCUIApplication) {
        controls(app); app.buttons["leave-reader"].tap()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 30))
    }
    private func wait(_ fact: String, timeout: TimeInterval, _ condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed, fact)
    }
    private func anchor(_ app: XCUIApplication) throws -> String {
        var lines: [String] = []
        wait("Use the real visible online body before controlling unrelated downloads", timeout: 30) {
            guard let actual = try? self.ocr(app), actual.count >= 4 else { return false }
            lines = actual; return true
        }
        let anchor = String(normalize(lines.dropFirst().prefix(2).joined()).prefix(24))
        XCTAssertGreaterThanOrEqual(anchor.count, 18)
        facts(["visibleOCRAnchor": anchor], name: "actual-download-original-visible-body")
        keep(app, name: "actual-download-original-visible-body")
        return anchor
    }
    private func visible(_ anchor: String, app: XCUIApplication, name: String) throws {
        wait("Preserve the actual original visible-body anchor", timeout: 30) {
            guard let lines = try? self.ocr(app) else { return false }
            return self.normalize(lines.joined()).contains(anchor)
        }
        keep(app, name: name)
    }
    private func normalize(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
    }
    private func ocr(_ app: XCUIApplication) throws -> [String] {
        let source = try XCTUnwrap(app.screenshot().image.cgImage), window = app.frame
        let frame = app.textViews["reading-body"].frame.intersection(window).insetBy(dx: 6, dy: 6)
        let rect = CGRect(x: (frame.minX - window.minX) * CGFloat(source.width) / window.width,
                          y: (frame.minY - window.minY) * CGFloat(source.height) / window.height,
                          width: frame.width * CGFloat(source.width) / window.width,
                          height: frame.height * CGFloat(source.height) / window.height).integral
        let image = try XCTUnwrap(source.cropping(to: rect))
        let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]; request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).sorted {
            abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.01
                ? $0.boundingBox.midY > $1.boundingBox.midY : $0.boundingBox.minX < $1.boundingBox.minX
        }.compactMap { $0.topCandidates(1).first?.string }
    }
    private func facts(_ values: [String: String], name: String) {
        let attachment = XCTAttachment(string: values.keys.sorted().map { $0 + "=" + (values[$0] ?? "") }.joined(separator: "\n"))
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func keep(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
