import XCTest
import UIKit
import Vision
import CryptoKit
import CoreFoundation

/// Select only after a read-only snapshot of the actual admitted library.
/// Original-library selectors keep environment in the runner. The isolated
/// native cleanup selector forwards only its fixed DEBUG mode and fresh UUID;
/// no URL, body, queue, delay, clock or original file is injected or replaced.
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

    /// A single ordinary product-route retry of the retained real orphan task.
    /// The stopped preproof and independent Host/Core postproof own admission,
    /// receipt and preservation facts; a returned tap is not an accepted ACK.
    func testExistingOffShelfFailedDownloadIsReachableFromGlobalManagementAndSingleRetryUsesOriginalTask() throws {
        struct Preproof: Decodable {
            let schemaVersion: Int
            let policy: String
            let capturedAtUTC: String
            let targetUDID: String
            let bundleID: String
            let coreCommit: String
            let snapshotSHA256: String
            let captureReceiptsSHA256: String
            let hostCommandCount: Int
            let taskCount: Int
            let physicalBodyCount: Int
            let sourceId: String
            let bookId: String
            let chapterIndex: UInt32
            let state: String
            let attempts: UInt32
            let maxAttempts: UInt32
            let lastError: String
            let queueRowSHA256: String
            let onShelf: Bool
            let readingProgressPresent: Bool
            let cachedBodyPresent: Bool
            let sourceConfigured: Bool
            let originalUnknownOperationID: String
            let originalUnknownCommandSHA256: String
        }
        #if targetEnvironment(simulator)
        XCTFail("This selector requires the retained real task on the original physical iPhone")
        throw Prerequisite.invalid("global download physical target")
        #endif
        let raw = try required("READER_GLOBAL_DOWNLOAD_RETRY_PREPROOF_JSON")
        let expectedSHA = try required("READER_GLOBAL_DOWNLOAD_RETRY_PREPROOF_SHA256")
        let expectedCore = try required("READER_GLOBAL_DOWNLOAD_RETRY_EXPECTED_CORE_COMMIT")
        let target = try required("READER_PHYSICAL_TARGET_UDID")
        func hex(_ text: String, count: Int) -> Bool {
            text.utf8.count == count && text.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
        }
        let bytes = Data(raw.utf8)
        let actualSHA = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        guard bytes.count <= 16 * 1024, hex(expectedSHA, count: 64), actualSHA == expectedSHA else {
            XCTFail("Require the exact fresh external stopped-library retry proof before launching the App")
            throw Prerequisite.invalid("global retry preproof SHA")
        }
        let proof = try JSONDecoder().decode(Preproof.self, from: bytes)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let captured = formatter.date(from: proof.capturedAtUTC) ?? ISO8601DateFormatter().date(from: proof.capturedAtUTC)
        let age = captured.map { Date().timeIntervalSince($0) }
        guard proof.schemaVersion == 1, proof.policy == "physical-global-orphan-download-retry-v1",
              let age, (0...600).contains(age), proof.bundleID == "io.reader.minliny.free",
              proof.targetUDID == target,
              target.range(of: #"^(?:[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{40})$"#, options: .regularExpression) != nil,
              ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == nil,
              hex(expectedCore, count: 40), proof.coreCommit == expectedCore,
              [proof.snapshotSHA256, proof.captureReceiptsSHA256, proof.queueRowSHA256].allSatisfy({ hex($0, count: 64) }),
              (581...1_000_000).contains(proof.hostCommandCount),
              (51...1_000_000).contains(proof.taskCount), (57...1_000_000).contains(proof.physicalBodyCount),
              proof.sourceId == "https://m.idejian.com", proof.bookId == "https://m.idejian.com/book/13256174",
              proof.chapterIndex == 100, proof.state == "failed", proof.attempts == 3, proof.maxAttempts == 3,
              proof.lastError == "source returned empty chapter content",
              proof.queueRowSHA256 == "79b87ddf8017fceb992ce6a211068603207c0c64377cda0fc9b5e122fa96fa19",
              !proof.onShelf, !proof.readingProgressPresent, !proof.cachedBodyPresent, proof.sourceConfigured,
              proof.originalUnknownOperationID == "0ad35be2-67cd-43a0-b4b4-34e98814e40d",
              proof.originalUnknownCommandSHA256 == "b8da0dd291ca82d63ba2afb88a9e371a280cfd130317c6d7e5e167f0e93a8f82" else {
            XCTFail("Require this exact untouched genuine off-shelf failed task; never admit another book or invent a failure")
            throw Prerequisite.invalid("global retry original task")
        }
        let book = Book(source: proof.sourceId, id: proof.bookId, title: "")
        let app = XCUIApplication(bundleIdentifier: proof.bundleID)
        guard app.state == .notRunning else {
            XCTFail("Root must bind an actually stopped copy before this ordinary cold launch")
            throw Prerequisite.invalid("global retry stopped App")
        }
        app.launchEnvironment = [:]
        app.launchArguments = []
        app.launch()
        func one(_ id: String, type: XCUIElement.ElementType) throws -> XCUIElement {
            let matches = app.descendants(matching: type).matching(NSPredicate(format: "identifier == %@", id))
            guard matches.firstMatch.waitForExistence(timeout: 15), matches.count == 1 else {
                keep(app, name: "global-download-retry-missing-exact-element")
                XCTFail("Require exactly one ordinary product element: " + id)
                throw Prerequisite.invalid(id)
            }
            return matches.firstMatch
        }
        let more = app.buttons["更多书架操作"]
        guard more.waitForExistence(timeout: 25), more.isHittable else {
            XCTFail("The normal cold App must show its bookshelf without a fake reader or test host")
            throw Prerequisite.invalid("global retry bookshelf")
        }
        XCTAssertFalse(app.textViews["reading-body"].exists)
        more.tap()
        let entry = try one("bookshelf-download-management", type: .button)
        guard entry.isEnabled && entry.isHittable else { throw Prerequisite.invalid("global download ordinary entry") }
        entry.tap()
        let failed = try one("download-management-filter-failed", type: .button)
        guard failed.isEnabled && failed.isHittable else { throw Prerequisite.invalid("global failed filter") }
        failed.tap()
        let rowID = "download-management-book:" + String(proof.sourceId.utf8.count) + ":" + proof.sourceId
            + String(proof.bookId.utf8.count) + ":" + proof.bookId
        let row = try one(rowID, type: .button)
        guard row.isEnabled && row.isHittable else {
            XCTFail("The one real failed off-shelf book must be directly reachable in the failed-task list")
            throw Prerequisite.invalid("global orphan row")
        }
        keep(app, name: "global-download-real-off-shelf-failed-book")
        row.tap()
        let detailID = "online-download-book-identity:" + String(proof.sourceId.utf8.count) + ":" + proof.sourceId
            + String(proof.bookId.utf8.count) + ":" + proof.bookId
        _ = try one(detailID, type: .staticText)
        XCTAssertFalse(app.textViews["reading-body"].exists)
        let before = try readObservation(proof.chapterIndex, book: book, app: app)
        XCTAssertEqual(before, Observation(state: "失败", attempts: proof.attempts))
        let error = try one("online-download-error:" + book.identity + ":100", type: .staticText)
        XCTAssertEqual(error.label, proof.lastError)
        let retry = control("resume", index: proof.chapterIndex, book: book, app: app)
        guard retry.exists && retry.label == "重试" && retry.isEnabled && retry.isHittable else {
            XCTFail("Only this exact existing failed task's original Retry is authorized")
            throw Prerequisite.invalid("global original retry")
        }
        facts(["preproofSHA256": expectedSHA, "snapshotSHA256": proof.snapshotSHA256,
               "coreCommit": proof.coreCommit, "sourceId": proof.sourceId, "bookId": proof.bookId,
               "chapterIndex": "100", "queueRowSHA256": proof.queueRowSHA256,
               "beforeHostCount": String(proof.hostCommandCount), "beforeTaskCount": String(proof.taskCount),
               "beforeBodyCount": String(proof.physicalBodyCount), "retryTapCount": "0",
               "boundary": "Actual ordinary off-shelf route and original row only. No re-add, reader, catalog update or fabricated source/body. Root must bind the final original resume/acquire receipt and preserve every other queue/body/Host/source/progress fact."],
              name: "global-download-original-failed-task-before-single-retry")
        retry.tap() // Exactly one native action; no retry loop or replacement intent.
        let taskState = state(proof.chapterIndex, book: book, app: app)
        // This existing action is never tapped. Its enabled binding is the
        // shared original resume/control owner's pending barrier in this page.
        let clear = app.buttons.matching(NSPredicate(format: "label == %@", "清除此章下载"))
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            taskState.exists && ["失败", "已完成"].contains(taskState.label)
                && clear.count == 1 && clear.firstMatch.isEnabled
        }, object: nil)
        guard XCTWaiter.wait(for: [settled], timeout: 150) == .completed else {
            keep(app, name: "global-download-single-retry-unresolved")
            XCTFail("The one real retry remained unresolved; preserve its original operation and do not start another")
            throw Prerequisite.invalid("global original retry unresolved")
        }
        let after = try readObservation(proof.chapterIndex, book: book, app: app)
        let actualError = exact("online-download-error:" + book.identity + ":100", type: .staticText, app: app)
        if after.state == "失败" { XCTAssertTrue(actualError.exists && !actualError.label.isEmpty) }
        keep(app, name: "global-download-single-retry-actual-terminal-projection")
        facts(["preproofSHA256": expectedSHA, "retryTapCount": "1", "state": after.state,
               "attempts": String(after.attempts), "lastError": actualError.exists ? actualError.label : "",
               "boundary": "Native route/tap and terminal task projection only. Failure remains failure. Returned tap, idle UI and this method result do not prove resume ACK, child acquisition, body completeness or data preservation; the external original-lineage postproof is mandatory."],
              name: "global-download-single-retry-ui-observation")
        app.terminate()
    }

    /// Root binds a fresh stopped physical App snapshot before selecting this
    /// method, then independently compares the retained ledger after it. The
    /// runner reads the summary and first/middle/last task rows only; all 50
    /// task rows remain an external ledger comparison, never a UI-count claim.
    /// It never opens a reader session.
    func testPhysicalRetainedWholeDownloadSummaryAndSecondColdLaunchWithoutRedispatch() throws {
        struct Position: Decodable {
            let chapterIndex: UInt32
            let chapterOffset: UInt64
            let chapterProgress: Double
            let locationRevision: String?
        }
        struct Counts: Decodable {
            let completed: UInt32
            let cached: UInt32
            let failed: UInt32
            let paused: UInt32
        }
        struct Task: Decodable {
            let chapterIndex: UInt32
            let state: String
            let attempts: UInt32
            let maxAttempts: UInt32
        }
        struct Preproof: Decodable {
            let schemaVersion: Int
            let policy: String
            let capturedAtUTC: String
            let targetUDID: String
            let bundleID: String
            let sourceId: String
            let bookId: String
            let title: String
            let ledgerSHA256: String
            let progressSHA256: String
            let currentPosition: Position
            let chapterCount: UInt32
            let summaryCounts: Counts
            let tasks: [Task]
            let taskProjectionSHA256: String
            let physicalBodyCount: UInt32
            let pendingOperationCount: Int
            let otherBookFailedTaskCount: Int
        }
        #if targetEnvironment(simulator)
        XCTFail("This selector requires the original physical iPhone library")
        throw Prerequisite.invalid("physical download-summary target")
        #endif
        let raw = try required("READER_PHYSICAL_DOWNLOAD_SUMMARY_PREPROOF_JSON")
        let expectedSHA = try required("READER_PHYSICAL_DOWNLOAD_SUMMARY_PREPROOF_SHA256")
        let target = try required("READER_PHYSICAL_TARGET_UDID")
        let ledgerSHA = try required("READER_PHYSICAL_DOWNLOAD_LEDGER_SHA256")
        let progressSHA = try required("READER_PHYSICAL_DOWNLOAD_PROGRESS_SHA256")
        let book = Book(source: try required("READER_ONLINE_SOURCE_ID"), id: try required("READER_ONLINE_BOOK_ID"),
                        title: try required("READER_ONLINE_BOOK_TITLE"))
        let bytes = Data(raw.utf8)
        func digest(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
        func isSHA(_ value: String) -> Bool { value.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil }
        guard bytes.count <= 32 * 1024, isSHA(expectedSHA), digest(bytes) == expectedSHA else {
            XCTFail("Bind the exact external physical snapshot preproof bytes before any App launch")
            throw Prerequisite.invalid("physical download-summary proof digest")
        }
        let proof = try JSONDecoder().decode(Preproof.self, from: bytes)
        let timestamp = ISO8601DateFormatter()
        timestamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let captured = timestamp.date(from: proof.capturedAtUTC) ?? ISO8601DateFormatter().date(from: proof.capturedAtUTC)
        let age = captured.map { Date().timeIntervalSince($0) }
        let counts = proof.summaryCounts
        guard proof.schemaVersion == 1, proof.policy == "physical-shelf-download-summary-readonly-v1",
              let age, (0...1800).contains(age),
              target.range(of: #"^(?:[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{40})$"#, options: .regularExpression) != nil,
              proof.targetUDID == target, proof.bundleID == "io.reader.minliny.free",
              ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == nil,
              proof.sourceId == "https://dushu.baidu.com/", proof.sourceId == book.source,
              proof.bookId == book.id, proof.title == book.title,
              isSHA(ledgerSHA), proof.ledgerSHA256 == ledgerSHA,
              isSHA(progressSHA), proof.progressSHA256 == progressSHA,
              proof.currentPosition.chapterIndex < proof.chapterCount,
              proof.currentPosition.chapterProgress.isFinite,
              (0...1).contains(proof.currentPosition.chapterProgress),
              proof.chapterCount == 50, counts.completed == 50, counts.cached == 0,
              counts.failed == 0, counts.paused == 0,
              proof.tasks.map(\.chapterIndex) == Array(UInt32(0)..<UInt32(50)),
              proof.tasks.allSatisfy({ $0.state == "completed" && $0.attempts > 0 && $0.maxAttempts > 0 }),
              proof.physicalBodyCount >= counts.completed, proof.pendingOperationCount == 0,
              proof.otherBookFailedTaskCount > 0, isSHA(proof.taskProjectionSHA256) else {
            XCTFail("Require this fresh physical free-bundle library's exact Baidu completion, current progress and settled ledger; another book's failed task must remain separate")
            throw Prerequisite.invalid("physical download-summary snapshot identity")
        }
        let projection: [[String: Any]] = proof.tasks.map {
            ["chapterIndex": $0.chapterIndex, "state": $0.state, "attempts": $0.attempts, "maxAttempts": $0.maxAttempts]
        }
        guard digest(try JSONSerialization.data(withJSONObject: projection, options: [.sortedKeys])) == proof.taskProjectionSHA256 else {
            XCTFail("Every expected row must belong to the externally bound current task projection")
            throw Prerequisite.invalid("physical download-summary task projection")
        }
        facts(["preproofSHA256": expectedSHA, "capturedAtUTC": proof.capturedAtUTC, "targetUDID": target,
               "bundleID": proof.bundleID, "bookIdentity": book.identity,
               "ledgerSHA256": ledgerSHA, "progressSHA256": progressSHA,
               "currentChapter": String(proof.currentPosition.chapterIndex),
               "currentScalarOffset": String(proof.currentPosition.chapterOffset),
               "currentChapterProgress": String(proof.currentPosition.chapterProgress),
               "currentLocationRevision": proof.currentPosition.locationRevision ?? "null",
               "otherBookFailedTaskCount": String(proof.otherBookFailedTaskCount),
               "boundary": "These are external prelaunch facts; UI reading never substitutes for postlaunch ledger/progress comparison"],
              name: "physical-retained-download-summary-preproof")

        let app = XCUIApplication(bundleIdentifier: proof.bundleID)
        guard app.state == .notRunning else {
            XCTFail("Root must stop the original App before its fresh snapshot and this first cold launch")
            throw Prerequisite.invalid("physical download-summary cold prerequisite")
        }
        let summaryID = "online-download-summary:" + book.identity
        let expectedSummary = "已完成 50 · 缓存 0 · 失败 0 · 暂停 0"
        let sampledIndexes: [UInt32] = [0, 24, 49]
        func assertNoReaderOrDownloadControls() {
            XCTAssertFalse(app.textViews["reading-body"].exists, "Shelf status must never open the original reading session")
            let ids = ["reader-more", "online-download-selected", "online-update-catalog", "online-download-close"]
            let labels = ["整本下载", "下载所选", "清理自动缓存", "清除此章下载"]
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier IN %@ OR label IN %@", ids, labels)).count, 0,
                           "Only the read-only shelf status is permitted")
        }
        func reveal(_ element: XCUIElement, in scroll: XCUIElement, towardTop: Bool = false) throws {
            func finiteVisibleFrame(_ frame: CGRect) -> Bool {
                !frame.isNull && !frame.isInfinite && frame.minX.isFinite && frame.minY.isFinite
                    && frame.width.isFinite && frame.height.isFinite && frame.width > 0 && frame.height > 0
            }
            guard scroll.exists else {
                XCTFail("The exact read-only summary scroll must be visible before scrolling")
                throw Prerequisite.invalid("physical download-summary viewport")
            }
            let viewport = scroll.frame.intersection(app.frame)
            guard finiteVisibleFrame(viewport) else {
                XCTFail("The exact summary scroll must intersect the visible App window with finite bounds")
                throw Prerequisite.invalid("physical download-summary visible viewport")
            }
            for _ in 0..<60 {
                if element.exists {
                    let frame = element.frame
                    if finiteVisibleFrame(frame), viewport.contains(frame),
                       finiteVisibleFrame(frame.intersection(viewport)) { return }
                }
                if towardTop { scroll.swipeDown() } else { scroll.swipeUp() }
            }
            XCTFail("The exact original summary row was not reachable through its native scroll view")
            throw Prerequisite.invalid("physical download-summary row")
        }
        for launch in 1...2 {
            app.launch()
            guard app.buttons["更多书架操作"].waitForExistence(timeout: 25) else {
                XCTFail("Cold launch must return directly to the original shelf without opening a reader")
                throw Prerequisite.invalid("physical download-summary shelf")
            }
            assertNoReaderOrDownloadControls()
            // Production shelf AX uses raw ReaderBook.bookId; the test's
            // Book.id is that raw value, while Book.identity is source|bookId.
            // Duplicate raw IDs fail here rather than choosing an ambiguous
            // row. The menu entry must then prove the exact source identity.
            // Do not tap the book or use a coordinate fallback.
            let rows = app.descendants(matching: .button).matching(NSPredicate(format: "identifier == %@", "book-" + book.id))
            guard rows.firstMatch.waitForExistence(timeout: 15), rows.count == 1, rows.firstMatch.isHittable else {
                XCTFail("The exact original shelf book must already be uniquely visible")
                throw Prerequisite.invalid("physical download-summary original shelf row")
            }
            rows.firstMatch.press(forDuration: 1)
            let entry = exact("shelf-download-status:" + book.identity, type: .button, app: app)
            guard entry.waitForExistence(timeout: 10), entry.label == "下载状态", entry.isEnabled, entry.isHittable else {
                XCTFail("Require the native read-only entry for this exact source/book; never fall back to opening its body")
                throw Prerequisite.invalid("physical download-summary native entry")
            }
            entry.tap()
            let summary = exact(summaryID, type: .staticText, app: app)
            guard summary.waitForExistence(timeout: 30) else {
                XCTFail("The source-qualified summary must load from the retained real library")
                throw Prerequisite.invalid("physical download-summary response")
            }
            XCTAssertEqual(summary.label, expectedSummary, "Do not merge the other book's retained failed task into this book")
            XCTAssertEqual(exact("online-download-summary-title:" + book.identity, type: .staticText, app: app).label, book.title)
            XCTAssertTrue(exact("online-download-summary-source:" + book.identity, type: .staticText, app: app).exists)
            assertNoReaderOrDownloadControls()
            let scroll = app.scrollViews["online-download-summary-scroll"]
            var observed: [String: String] = [:]
            for index in sampledIndexes {
                let expected = proof.tasks[Int(index)]
                let suffix = book.identity + ":" + String(expected.chapterIndex)
                let row = exact("online-download-summary-chapter:" + suffix, app: app)
                try reveal(row, in: scroll)
                let state = exact("online-download-summary-state:" + suffix, type: .staticText, app: app)
                let observedState = state.label
                XCTAssertEqual(observedState, "已完成")
                let attempts = exact("online-download-summary-attempts:" + suffix, type: .staticText, app: app)
                let expectedAttempts = "尝试 \(expected.attempts) / \(expected.maxAttempts)"
                XCTAssertEqual(attempts.label, expectedAttempts, "Keep the externally observed original task counter")
                observed[String(expected.chapterIndex)] = observedState + ":" + attempts.label
            }
            try reveal(summary, in: scroll, towardTop: true)
            XCTAssertEqual(summary.label, expectedSummary)
            assertNoReaderOrDownloadControls()
            facts(observed, name: "physical-retained-download-summary-launch-" + String(launch) + "-sampled-rows")
            keep(app, name: "physical-retained-download-summary-launch-" + String(launch))
            let close = exact("online-download-summary-close", type: .button, app: app)
            guard close.exists, close.isEnabled, close.isHittable else {
                XCTFail("Close only this read-only summary through its native header")
                throw Prerequisite.invalid("physical download-summary close")
            }
            close.tap()
            wait("Return to the same shelf without a reader save barrier", timeout: 10) {
                !summary.exists && app.buttons["更多书架操作"].isHittable
            }
            assertNoReaderOrDownloadControls()
            if launch == 1 {
                app.terminate()
                XCTAssertTrue(app.wait(for: .notRunning, timeout: 10), "The second launch must start a new App process")
            }
        }
        facts(["summary": expectedSummary, "sampledTaskRowsObservedOnEachLaunch": String(sampledIndexes.count),
               "sampledChapterIndexes": sampledIndexes.map(String.init).joined(separator: ","),
               "downloadOrControlIntentRequested": "false", "readerSessionOpened": "false",
               "externalPostproofRequired": "All 50 original full queue rows, bodies, progress, raw files and ledger must remain exact after both cold launches; UI rows are samples only",
               "openBoundaries": "Pause, continue, cancel and OS offline are not exercised or accepted"],
              name: "physical-retained-download-summary-evidence-boundary")
    }

    /// Select only with a fresh external stopped-App preproof and a reviewed
    /// DEBUG artifact containing ReaderNativeCleanupHarness. The App prepares
    /// genuine data in a UUID library; the runner alone taps the production
    /// native confirmation. This is not permission to clean the original data.
    func testPhysicalIsolatedRealNativeCleanupConfirmExecutionAndResult() throws {
        struct Preproof: Decodable {
            let schemaVersion: Int
            let policy: String
            let capturedAtUTC: String
            let targetUDID: String
            let bundleID: String
            let runID: String
            let originalSnapshotSHA256: String
            let originalLibraryIdentitySHA256: String
            let sourcePackageSHA256: String
            let sourcePackageBytes: Int
            let completedTaskCount: Int
            let failedTaskCount: Int
            let physicalBodyCount: Int
            let oldHostCommandCount: Int
            let pendingOperationCount: Int
            let pendingOperationIDs: [String]
            let pendingOperations: [PendingOperation]
            let descriptorSHA256: String
            let preparationCommandSHA256: String
            let corePreparationPayloadSHA256: String
            let stoppedPhysicalApp: Bool
            let preserveDataUpdateVerified: Bool
            let originalFilesReadOnlySnapshot: Bool
        }
        #if !DEBUG || targetEnvironment(simulator)
        XCTFail("This selector requires the reviewed DEBUG App on the physical iPhone")
        throw Prerequisite.invalid("isolated physical native cleanup target")
        #endif
        let raw = try required("READER_NATIVE_CLEANUP_PREPROOF_JSON")
        let expectedSHA = try required("READER_NATIVE_CLEANUP_PREPROOF_SHA256")
        let target = try required("READER_PHYSICAL_TARGET_UDID")
        let runID = try required("READER_NATIVE_CLEANUP_RUN_ID")
        func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
        func isSHA(_ value: String) -> Bool { value.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil }
        let bytes = Data(raw.utf8)
        guard bytes.count <= 16 * 1024, isSHA(expectedSHA), digest(bytes) == expectedSHA else {
            XCTFail("Require exact fresh external original-library preproof bytes before launching App")
            throw Prerequisite.invalid("isolated native cleanup preproof digest")
        }
        let proof = try JSONDecoder().decode(Preproof.self, from: bytes)
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let captured = formatter.date(from: proof.capturedAtUTC) ?? ISO8601DateFormatter().date(from: proof.capturedAtUTC)
        let age = captured.map { Date().timeIntervalSince($0) }
        let sourceSHA = "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322"
        let pendingOperationID = "0ad35be2-67cd-43a0-b4b4-34e98814e40d"
        let pendingSourceID = "https://dushu.baidu.com/"
        let pendingBookID = "https://boxnovel.baidu.com/boxnovel/wiseapi/chapterList?bookid=4345127024&pageNum=1&order=asc&site="
        let pendingCommandSHA = "b8da0dd291ca82d63ba2afb88a9e371a280cfd130317c6d7e5e167f0e93a8f82"
        let descriptorSHA = "f8eb6db590458d31ac5a60cbccdc2ef43b703867fc055d61acdd306701f61855"
        let preparationCommandSHA = "c3feb8f93a79776d5402763d8187b8730ff04b269272339d27fef810f08d8c67"
        // The external preproof policy changes independently of the unchanged
        // DEBUG harness protocol; this launch still opens only its UUID library.
        let harnessMode = "physical-isolated-native-cleanup-v1"
        guard proof.schemaVersion == 2, proof.policy == "physical-isolated-native-cleanup-v2",
              let age, (0...1800).contains(age),
              let run = UUID(uuidString: runID), run.uuidString.lowercased() == runID, proof.runID == runID,
              target.range(of: #"^(?:[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{40})$"#, options: .regularExpression) != nil,
              proof.targetUDID == target, proof.bundleID == "io.reader.minliny.free",
              ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == nil,
              isSHA(proof.originalSnapshotSHA256), isSHA(proof.originalLibraryIdentitySHA256),
              proof.sourcePackageSHA256 == sourceSHA, proof.sourcePackageBytes == 5606,
              proof.completedTaskCount == 50, proof.failedTaskCount == 1, proof.physicalBodyCount == 57,
              proof.oldHostCommandCount == 581,
              proof.pendingOperationCount == 1, proof.pendingOperationIDs == [pendingOperationID],
              proof.descriptorSHA256 == descriptorSHA,
              proof.preparationCommandSHA256 == preparationCommandSHA,
              proof.corePreparationPayloadSHA256 == "ab54a2fef0655eecb8209bb023159e984597fd3258ca423a6b3fe63bfaa93f00",
              proof.pendingOperations.count == 1, proof.pendingOperations.allSatisfy({ pending in
                  pending.operationID == pendingOperationID && pending.method == "bookshelf.add"
                      && pending.scope == "shelf-add:" + pendingSourceID + "|" + pendingBookID
                      && pending.commandSHA256 == pendingCommandSHA
                      && !pending.completed && !pending.resultPresent && !pending.failurePresent
                      && pending.sourceId == pendingSourceID && pending.bookId == pendingBookID
                      && pending.title == "等到鸢尾纯白"
              }),
              proof.stoppedPhysicalApp, proof.preserveDataUpdateVerified, proof.originalFilesReadOnlySnapshot else {
            XCTFail("Require the exact preserved physical free-bundle library and its fresh external snapshot retaining only the original unknown add and its raw command bytes")
            throw Prerequisite.invalid("isolated native cleanup external identity")
        }
        facts(["preproofSHA256": expectedSHA, "runID": runID, "bundleID": proof.bundleID,
               "originalSnapshotSHA256": proof.originalSnapshotSHA256,
               "originalLibraryIdentitySHA256": proof.originalLibraryIdentitySHA256,
               "protectedCompletedTasks": String(proof.completedTaskCount), "protectedFailedTasks": String(proof.failedTaskCount),
               "protectedBodies": String(proof.physicalBodyCount), "protectedHostCommands": String(proof.oldHostCommandCount),
               "protectedPendingOperationID": pendingOperationID, "protectedPendingCommandSHA256": pendingCommandSHA,
               "protectedDescriptorSHA256": descriptorSHA,
               "protectedPreparationCommandSHA256": preparationCommandSHA,
               "protectedCorePreparationPayloadSHA256": proof.corePreparationPayloadSHA256,
               "boundary": "Root must independently compare the original full library after termination; this selector never opens it"],
              name: "physical-isolated-native-cleanup-external-preproof")
        let app = XCUIApplication(bundleIdentifier: proof.bundleID)
        guard app.state == .notRunning else {
            XCTFail("The original App must remain stopped after its external snapshot")
            throw Prerequisite.invalid("isolated native cleanup cold prerequisite")
        }
        app.launchEnvironment = ["READER_NATIVE_CLEANUP_MODE": harnessMode,
                                 "READER_NATIVE_CLEANUP_RUN_ID": runID]
        app.launch()
        defer { if app.state != .notRunning { app.terminate() } } // Retain failed UUID data for inspection.
        let readyIDs = ["native-cleanup-ready-identity", "native-cleanup-ready-source", "native-cleanup-ready-inventory"]
        let finalIDs = ["native-cleanup-finished-result", "native-cleanup-finished-isolation"]
        func compactProof(_ ids: [String], keys: Set<String>) -> [String: Any]? {
            var combined: [String: Any] = [:]
            for id in ids {
                let element = exact(id, app: app)
                guard element.exists, let data = element.label.data(using: .utf8), data.count <= 256,
                      let fields = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
                for (key, value) in fields {
                    guard combined.updateValue(value, forKey: key) == nil else { return nil }
                }
            }
            return Set(combined.keys) == keys ? combined : nil
        }
        let readyKeys: Set<String> = ["r", "m", "bundle", "e", "o", "d", "s", "n", "src", "t", "b", "summary", "title", "detail"]
        let finalKeys: Set<String> = ["r", "n", "b", "a", "c", "p", "e", "h", "z", "x", "o", "removed"]
        func proofDiagnostics(_ ids: [String], stage: String) {
            let details = ids.map { id -> String in
                let element = exact(id, app: app)
                return id + ": exists=" + String(element.exists) + "; label=" + (element.exists ? element.label : "<missing>")
            }.joined(separator: "\n")
            let attachment = XCTAttachment(string: "stage=" + stage + "\n" + details + "\n" + app.debugDescription)
            attachment.name = "physical-isolated-native-cleanup-" + stage + "-compact-proof-diagnostic"
            attachment.lifetime = .keepAlways; add(attachment)
        }
        func unsignedInteger(_ value: Any?) -> UInt64? {
            guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
                  number.stringValue.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil else { return nil }
            return UInt64(number.stringValue)
        }
        func attachProof(_ proof: [String: Any], _ name: String) throws {
            let data = try JSONSerialization.data(withJSONObject: proof, options: [.sortedKeys])
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        let stopped = app.staticTexts["隔离取证已停止"]
        let phaseElement = app.staticTexts["native-cleanup-harness-phase"]
        func harnessPhase() -> String? { phaseElement.exists ? phaseElement.label : nil }
        func hasStopped() -> Bool { harnessPhase() == "failed" || stopped.exists }
        func requireNotStopped(_ stage: String) throws {
            guard hasStopped() else { return }
            keep(app, name: "physical-isolated-native-cleanup-" + stage + "-failed")
            proofDiagnostics(readyIDs + finalIDs, stage: stage + "-failed")
            XCTFail("The isolated harness stopped during " + stage)
            throw Prerequisite.invalid("isolated native cleanup stopped during " + stage)
        }
        let open = app.buttons["native-cleanup-harness-open"]
        wait("Real source/catalog/body/download preparation must settle without a fixture fallback", timeout: 240) {
            let phase = harnessPhase()
            return phase == "ready" || phase == "failed" || stopped.exists
        }
        try requireNotStopped("preparation")
        var readyProof: [String: Any]?
        wait("Read a complete compact proof from this ready UUID before opening the production panel", timeout: 10) {
            guard harnessPhase() == "ready", open.exists && open.isHittable else { return false }
            readyProof = compactProof(readyIDs, keys: readyKeys)
            return readyProof != nil
        }
        guard let before = readyProof else {
            keep(app, name: "physical-isolated-native-cleanup-ready-proof-unavailable")
            proofDiagnostics(readyIDs, stage: "ready")
            throw Prerequisite.invalid("isolated native cleanup compact ready proof unavailable")
        }
        try attachProof(before, "physical-isolated-native-cleanup-ready-proof")
        guard before["r"] as? String == runID, before["m"] as? String == harnessMode,
              before["bundle"] as? String == proof.bundleID, isSHA(before["e"] as? String ?? ""),
              before["o"] as? String == proof.originalLibraryIdentitySHA256,
              before["d"] as? Bool == true,
              before["s"] as? String == sourceSHA, before["n"] as? Int == 5606,
              before["src"] as? String == "https://dushu.baidu.com/", before["t"] as? String == "剑来",
              let cleanableBytes = unsignedInteger(before["b"]), cleanableBytes > 0,
              let expectedSummary = before["summary"] as? String,
              let expectedTitle = before["title"] as? String,
              let expectedDetail = before["detail"] as? String else {
            XCTFail("The genuine isolated prerequisites failed; keep its evidence and do not fall back to the original library")
            throw Prerequisite.invalid("isolated native cleanup real admission")
        }
        XCTAssertFalse(app.buttons["更多书架操作"].exists)
        XCTAssertFalse(app.textViews["reading-body"].exists)
        XCTAssertTrue(open.isHittable); open.tap()
        let cleanup = app.buttons["清理自动缓存"]
        XCTAssertTrue(cleanup.waitForExistence(timeout: 20))
        let scroll = app.scrollViews["online-download-scroll"]
        for _ in 0..<6 {
            if cleanup.isHittable { break }
            scroll.swipeDown()
        }
        guard cleanup.isHittable, cleanup.isEnabled, app.staticTexts[expectedSummary].exists,
              !exact("online-cache-cleanup-result", app: app).exists else {
            XCTFail("Require the actual enabled production cleanup button and complete real inventory")
            throw Prerequisite.invalid("isolated native cleanup production inventory")
        }
        cleanup.tap()
        let alert = app.alerts["清理自动缓存？"]
        guard alert.waitForExistence(timeout: 10), app.alerts.count == 1,
              alert.staticTexts["保留当前章和已完成下载；书架、阅读位置及原书不变。"].exists,
              alert.buttons["清理"].isHittable, alert.buttons["取消"].exists else {
            XCTFail("Require the exact production native confirmation before its only confirm tap")
            throw Prerequisite.invalid("isolated native cleanup native alert")
        }
        keep(app, name: "physical-isolated-native-cleanup-before-confirm")
        alert.buttons["清理"].tap() // Exactly one real native confirm; no retry.
        let result = exact("online-cache-cleanup-result", app: app)
        wait("The production owner must show the original cleanup ACK result", timeout: 45) {
            !alert.exists && result.exists && app.staticTexts[expectedTitle].exists && app.staticTexts[expectedDetail].exists
        }
        XCTAssertEqual(expectedTitle, "自动缓存清理完成")
        func visibleResultText(_ element: XCUIElement) -> Bool {
            let frame = element.frame, visible = frame.intersection(app.frame)
            return element.exists && !frame.isNull && !frame.isInfinite && frame.width > 0 && frame.height > 0 &&
                !visible.isNull && visible.width > 0 && visible.height >= min(frame.height, 14)
        }
        for _ in 0..<6 {
            if visibleResultText(app.staticTexts[expectedTitle]) && visibleResultText(app.staticTexts[expectedDetail]) { break }
            scroll.swipeUp()
        }
        guard visibleResultText(app.staticTexts[expectedTitle]), visibleResultText(app.staticTexts[expectedDetail]) else {
            XCTFail("Require the actual result title and original-ACK detail on screen before the screenshot")
            throw Prerequisite.invalid("isolated native cleanup visible result")
        }
        keep(app, name: "physical-isolated-native-cleanup-native-result")
        let close = app.buttons["online-download-close"]
        XCTAssertTrue(close.isHittable); close.tap()
        let finish = app.buttons["native-cleanup-harness-finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 10)); XCTAssertTrue(finish.isHittable); finish.tap()
        wait("Read the exact original command, verify preservation, close, and remove only this UUID library", timeout: 45) {
            let phase = harnessPhase()
            return phase == "finished" || phase == "failed" || app.staticTexts["隔离原生清理取证已核对"].exists || stopped.exists
        }
        try requireNotStopped("finish")
        var finalProof: [String: Any]?
        wait("Read the complete compact final proof for this UUID", timeout: 10) {
            guard harnessPhase() == "finished" else { return false }
            finalProof = compactProof(finalIDs, keys: finalKeys)
            return finalProof != nil
        }
        guard let after = finalProof else {
            keep(app, name: "physical-isolated-native-cleanup-final-proof-unavailable")
            proofDiagnostics(finalIDs, stage: "finished")
            throw Prerequisite.invalid("isolated native cleanup compact final proof unavailable")
        }
        try attachProof(after, "physical-isolated-native-cleanup-finished-proof")
        guard after["r"] as? String == runID, isSHA(after["e"] as? String ?? ""),
              after["n"] as? Int == 1, unsignedInteger(after["b"]) == cleanableBytes,
              after["a"] as? Bool == true, after["c"] as? Bool == true,
              after["p"] as? Bool == true,
              after["h"] as? Bool == true,
              after["z"] as? Bool == true, after["removed"] as? Bool == true,
              after["x"] as? Int == 2,
              after["o"] as? Bool == true else {
            XCTFail("Native result alone cannot pass original ACK, isolation or exact temporary teardown checks")
            throw Prerequisite.invalid("isolated native cleanup postconditions")
        }
        keep(app, name: "physical-isolated-native-cleanup-finished")
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        facts(["runID": runID, "nativeConfirmTapCount": "1", "nativeResultScreenshotCaptured": "true",
               "externalPostproofRequired": "All original bodies/tasks/progress/source bytes/Host commands/ledger/preferences and the entire exact original unknown pending set with its raw command bytes must be compared after App termination; no new original-library Host command is permitted",
               "boundary": "Production native confirm execution and result only in a real isolated library; not original-library cleanup or complete V4 acceptance"],
              name: "physical-isolated-native-cleanup-evidence-boundary")
    }

    /// Opens the production native cleanup confirmation, then cancels it.
    /// Root must bind a fresh original-library preproof and compare every
    /// protected cache/body/task/source/progress row after the App stops.
    /// This method never confirms the global cleanup against that library.
    func testPhysicalOriginalLibraryNativeCleanupConfirmationCancelWithoutDispatch() throws {
        struct Preproof: Decodable {
            let schemaVersion: Int
            let policy: String
            let capturedAtUTC: String
            let targetUDID: String
            let bundleID: String
            let sourceId: String
            let bookId: String
            let title: String
            let ledgerSHA256: String
            let progressSHA256: String
            let completedTaskCount: Int
            let failedTaskCount: Int
            let physicalBodyCount: Int
            let oldHostCommandCount: Int
            let pendingOperationCount: Int
            let originalChapterIndex: UInt32
        }
        #if targetEnvironment(simulator)
        XCTFail("This selector requires the original physical iPhone library")
        throw Prerequisite.invalid("physical cleanup confirmation target")
        #endif
        let raw = try required("READER_PHYSICAL_CLEANUP_CANCEL_PREPROOF_JSON")
        let expectedSHA = try required("READER_PHYSICAL_CLEANUP_CANCEL_PREPROOF_SHA256")
        let target = try required("READER_PHYSICAL_TARGET_UDID")
        let book = Book(source: try required("READER_ONLINE_SOURCE_ID"), id: try required("READER_ONLINE_BOOK_ID"),
                        title: try required("READER_ONLINE_BOOK_TITLE"))
        let bytes = Data(raw.utf8)
        func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
        func isSHA(_ value: String) -> Bool { value.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil }
        guard bytes.count <= 16 * 1024, isSHA(expectedSHA), digest(bytes) == expectedSHA else {
            XCTFail("Bind the exact fresh external original-library preproof bytes before any App launch")
            throw Prerequisite.invalid("physical cleanup preproof digest")
        }
        let proof = try JSONDecoder().decode(Preproof.self, from: bytes)
        let timestamp = ISO8601DateFormatter()
        timestamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let captured = timestamp.date(from: proof.capturedAtUTC) ?? ISO8601DateFormatter().date(from: proof.capturedAtUTC)
        let age = captured.map { Date().timeIntervalSince($0) }
        guard proof.schemaVersion == 1, proof.policy == "physical-original-cleanup-confirmation-cancel-v1",
              let age, (0...1800).contains(age),
              target.range(of: #"^(?:[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{40})$"#, options: .regularExpression) != nil,
              proof.targetUDID == target, proof.bundleID == "io.reader.minliny.free",
              ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == nil,
              proof.sourceId == "https://dushu.baidu.com/", proof.sourceId == book.source,
              proof.bookId == book.id, proof.title == book.title,
              isSHA(proof.ledgerSHA256), isSHA(proof.progressSHA256),
              proof.completedTaskCount == 50, proof.failedTaskCount == 1,
              proof.physicalBodyCount == 57, proof.oldHostCommandCount == 569,
              proof.pendingOperationCount == 0, proof.originalChapterIndex == 40 else {
            XCTFail("Require the fresh exact original physical free-bundle library and settled protected inventory")
            throw Prerequisite.invalid("physical cleanup original-library identity")
        }
        facts(["preproofSHA256": expectedSHA, "targetUDID": target, "bundleID": proof.bundleID,
               "bookIdentity": book.identity, "ledgerSHA256": proof.ledgerSHA256,
               "progressSHA256": proof.progressSHA256,
               "protectedCompletedTasks": String(proof.completedTaskCount),
               "protectedFailedTasks": String(proof.failedTaskCount),
               "protectedPhysicalBodies": String(proof.physicalBodyCount),
               "protectedOldHostCommands": String(proof.oldHostCommandCount),
               "boundary": "The native confirmation will be cancelled; Root compares the original data and absence of a new cache.storage.cleanup command externally"],
              name: "physical-original-cleanup-cancel-preproof")

        let app = XCUIApplication(bundleIdentifier: proof.bundleID)
        guard app.state == .notRunning else {
            XCTFail("Root must stop the original App before its fresh snapshot and this cold launch")
            throw Prerequisite.invalid("physical cleanup cold prerequisite")
        }
        app.launch()
        openEntry(book, app: app)
        XCTAssertEqual(try currentChapter(book, app: app), proof.originalChapterIndex)
        downloads(app)
        let expectedSummary = "已完成 50 · 缓存 0 · 失败 0 · 暂停 0"
        let cleanup = app.buttons["清理自动缓存"]
        revealTop(cleanup, app: app)
        guard app.staticTexts[expectedSummary].exists, cleanup.isEnabled, cleanup.isHittable,
              !exact("online-cache-cleanup-result", app: app).exists else {
            XCTFail("The retained real download status must be settled with no prior cleanup result")
            throw Prerequisite.invalid("physical cleanup native inventory")
        }
        cleanup.tap()
        let alert = app.alerts["清理自动缓存？"]
        guard alert.waitForExistence(timeout: 10), app.alerts.count == 1,
              alert.staticTexts["保留当前章和已完成下载；书架、阅读位置及原书不变。"].exists,
              alert.buttons["清理"].exists, alert.buttons["取消"].isHittable else {
            XCTFail("Require the exact native cleanup confirmation and its non-destructive cancel action")
            throw Prerequisite.invalid("physical cleanup native confirmation")
        }
        keep(app, name: "physical-original-cleanup-native-confirmation-before-cancel")
        alert.buttons["取消"].tap()
        wait("Cancel the exact native cleanup confirmation without dispatch", timeout: 10) { !alert.exists }
        XCTAssertFalse(exact("online-cache-cleanup-result", app: app).exists)
        XCTAssertTrue(app.staticTexts[expectedSummary].exists)
        keep(app, name: "physical-original-cleanup-native-confirmation-cancelled")
        app.buttons["online-download-close"].tap()
        XCTAssertEqual(try currentChapter(book, app: app), proof.originalChapterIndex)
        leave(app)
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        facts(["confirmationOpened": "true", "nativeCancelTapped": "true", "cleanupConfirmTapped": "false",
               "cleanupResultShown": "false", "originalChapterAfterCancel": String(proof.originalChapterIndex),
               "externalPostproofRequired": "No new cache.storage.cleanup original Host command; all 57 original physical bodies, 50+1 task rows, source JSON bytes, old 569 commands and progress must remain exact",
               "openBoundary": "The production native confirmation execution and result are not exercised on the original library"],
              name: "physical-original-cleanup-cancel-evidence-boundary")
    }

    func testActualFiniteDownloadPauseResumeCancelAndColdRetention() throws {
        struct Preproof: Decodable {
            let schemaVersion: Int
            let policy: String
            let selector: String
            let capturedAtUTC: String
            let targetUDID: String
            let bundleID: String
            let runnerBundleID: String
            let sourceId: String
            let bookId: String
            let bookTitle: String
            let sourceVersion: String
            let firstIndex: UInt32
            let chapterCount: UInt32
            let splitIndex: UInt32
            let existingCompletedIndexes: [UInt32]
            let currentChapter: UInt32
            let selectedLeafSHA256: String
            let originalUnknownAddSHA256: String
            let originalPendingOperationIDs: [String]
            let originalHostCommandCount: Int
            let prelaunchHostCommandCount: Int
            let baseline588SHA256: String
            let artifactBindingSHA256: String
            let sourceFreezeSHA256: String
            let signedAppTreeSHA256: String
            let signedRunnerTreeSHA256: String
            let signedTestBinarySHA256: String
            let runnerExecutableSHA256: String
            let runnerInstalledPath: String
            let runnerBundleVersion: String
            let snapshotSHA256: String
            let physical: Bool
            let wired: Bool
            let bothProcessesAbsentBeforeCopy: Bool
            let historicalAudit: Bool
        }
        #if targetEnvironment(simulator)
        XCTFail("This finite selector requires the externally bound original physical iPhone library")
        throw Prerequisite.invalid("physical finite download target")
        #endif
        let raw = try required("READER_FINITE_DOWNLOAD_PREPROOF_JSON")
        let proofSHA = try required("READER_FINITE_DOWNLOAD_PREPROOF_SHA256")
        let artifactSHA = try required("READER_FINITE_DOWNLOAD_ARTIFACT_BINDING_SHA256")
        let target = try required("READER_PHYSICAL_TARGET_UDID")
        let proofBytes = Data(raw.utf8)
        func digest(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
        func isSHA(_ value: String) -> Bool { value.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil }
        guard proofBytes.count <= 64 * 1024, isSHA(proofSHA), digest(proofBytes) == proofSHA else {
            XCTFail("Require the exact fresh external r11 finite preproof bytes before launching the App")
            throw Prerequisite.invalid("finite preproof digest")
        }
        let proof = try JSONDecoder().decode(Preproof.self, from: proofBytes)
        let timestamp = ISO8601DateFormatter()
        timestamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let captured = timestamp.date(from: proof.capturedAtUTC) ?? ISO8601DateFormatter().date(from: proof.capturedAtUTC)
        let age = captured.map { Date().timeIntervalSince($0) }
        let book = Book(source: try required("READER_ONLINE_SOURCE_ID"), id: try required("READER_ONLINE_BOOK_ID"),
                        title: try required("READER_ONLINE_BOOK_TITLE"))
        let first = try unsigned("READER_ONLINE_CONTROL_FIRST_INDEX")
        let count = try unsigned("READER_ONLINE_CONTROL_CHAPTER_COUNT")
        let originalPendingID = "0ad35be2-67cd-43a0-b4b4-34e98814e40d"
        guard proof.schemaVersion == 5, proof.policy == "physical-real-finite-download-r11-627-v5",
              proof.selector == "ReaderOnlineDownloadControlJourneyTests/testActualFiniteDownloadPauseResumeCancelAndColdRetention",
              let age, (0...1800).contains(age), proof.physical, proof.wired,
              proof.bothProcessesAbsentBeforeCopy, !proof.historicalAudit,
              ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == nil,
              UIDevice.current.userInterfaceIdiom == .phone,
              target.range(of: #"^(?:[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{40})$"#, options: .regularExpression) != nil,
              proof.targetUDID == target, proof.bundleID == "io.reader.minliny.free",
              proof.runnerBundleID == "io.reader.minliny.free.xctrunner",
              proof.sourceId == "https://dushu.baidu.com/", proof.sourceId == book.source,
              proof.bookId == book.id, proof.bookTitle == book.title,
              proof.sourceVersion == "47ff0e3312f354175e488ce582fcf699d0dc7a486a6f69903a0bb2b7f5894ce3",
              proof.firstIndex == first, proof.chapterCount == count, first == 14, count == 12,
              proof.splitIndex == 22,
              proof.currentChapter == 0, proof.existingCompletedIndexes == Array(UInt32(3)...UInt32(13)),
              proof.originalHostCommandCount == 588, proof.prelaunchHostCommandCount == 627,
              proof.originalPendingOperationIDs == [originalPendingID],
              proof.originalUnknownAddSHA256 == "b8da0dd291ca82d63ba2afb88a9e371a280cfd130317c6d7e5e167f0e93a8f82",
              proof.baseline588SHA256 == "fefbc0ec559976e660778954d0bda0311fb37f257a3a19809aa628628449c4fd",
              isSHA(artifactSHA), proof.artifactBindingSHA256 == artifactSHA,
              [proof.selectedLeafSHA256, proof.sourceFreezeSHA256, proof.snapshotSHA256,
               proof.signedAppTreeSHA256, proof.signedRunnerTreeSHA256,
               proof.signedTestBinarySHA256, proof.runnerExecutableSHA256].allSatisfy(isSHA) else {
            XCTFail("Require this fresh physical free-bundle installation, original 588 commands, sole historical unknown add and exact real missing selection")
            throw Prerequisite.invalid("finite physical installation and selection identity")
        }
        let runnerBundle = Bundle.main
        let testBundle = Bundle(for: ReaderOnlineDownloadControlJourneyTests.self)
        guard runnerBundle.bundleIdentifier == proof.runnerBundleID,
              runnerBundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String == proof.runnerBundleVersion,
              runnerBundle.bundleURL.resolvingSymlinksInPath().standardizedFileURL.path
                == URL(fileURLWithPath: proof.runnerInstalledPath).resolvingSymlinksInPath().standardizedFileURL.path,
              let runnerExecutable = runnerBundle.executableURL, let testExecutable = testBundle.executableURL,
              digest(try Data(contentsOf: runnerExecutable)) == proof.runnerExecutableSHA256,
              digest(try Data(contentsOf: testExecutable)) == proof.signedTestBinarySHA256 else {
            XCTFail("The executing installed Runner and selected XCTest bytes must match the externally verified same-source App/Runner pair")
            throw Prerequisite.invalid("finite executing signed Runner identity")
        }
        guard (8...12).contains(count), UInt64(first) + UInt64(count) <= UInt64(UInt32.max) else {
            XCTFail("Select only 8–12 actual missing readable canonical chapters, not a whole-book timing workaround")
            throw Prerequisite.invalid("finite original range")
        }
        let chosenRange = first..<(first + count)
        let oldCompleted = try existingCompletedIndexes()
        guard oldCompleted == Set(proof.existingCompletedIndexes) else {
            XCTFail("Existing completed indexes must match the exact prelaunch selection proof")
            throw Prerequisite.invalid("finite completed selection identity")
        }
        guard oldCompleted.allSatisfy({ !chosenRange.contains($0) }), !oldCompleted.isEmpty || count >= 9 else {
            XCTFail("Existing completed chapters must be outside the new batch; without one, reserve one of 9–12 new chapters as a completed baseline and leave at least eight for controls")
            throw Prerequisite.invalid("completed protection prerequisite")
        }

        let app = XCUIApplication(bundleIdentifier: proof.bundleID)
        // Register before any possible launch, including a later failure or
        // natural-completion XCTSkip. Only this exact free App is stopped.
        addTeardownBlock {
            if app.state != .notRunning { app.terminate() }
            XCTAssertTrue(app.wait(for: .notRunning, timeout: 10),
                          "Stop the exact finite-download App for independent postproof after every outcome")
        }
        // External stopped-copy proof remains mandatory. XCTest can itself
        // observe a suspended startup App after that capture, as in r6. Use
        // state-only diagnostics (the r6 app:nil boundary), never AX/screenshot
        // diagnostics that could launch or activate the App before this stop.
        let startupState = app.state
        let startupNormalizationAttempted = startupState != .notRunning
        if startupNormalizationAttempted { app.terminate() }
        guard app.wait(for: .notRunning, timeout: 10) else {
            XCTFail("Stop only XCTest's exact startup App before the explicit finite cold launch")
            throw Prerequisite.invalid("finite cold launch prerequisite")
        }
        facts(["preproofSHA256": proofSHA, "artifactBindingSHA256": artifactSHA,
               "sourceFreezeSHA256": proof.sourceFreezeSHA256, "snapshotSHA256": proof.snapshotSHA256,
               "originalHostCommandCount": String(proof.originalHostCommandCount),
               "originalPendingCount": String(proof.originalPendingOperationIDs.count),
               "firstIndex": String(first), "chapterCount": String(count), "splitIndex": String(proof.splitIndex),
               "startupAppState": String(describing: startupState),
               "startupNormalizationAttempted": String(startupNormalizationAttempted),
               "boundary": "External installation receipts and metadata bind the App; this Runner independently hashes its own executable and XCTest bytes. Installed App binary readback is unavailable. Exact post-run original data and ACK attribution remain required."],
              name: "physical-finite-download-prelaunch-preproof")
        app.launch(); openEntry(book, app: app)
        let originalChapter = try currentChapter(book, app: app)
        XCTAssertEqual(originalChapter, proof.currentChapter)
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
        let split = proof.splitIndex
        guard split > controlStart, split < chosenRange.upperBound else {
            XCTFail("The fresh r11 proof must bind both exact genuine missing chapter batches")
            throw Prerequisite.invalid("finite split identity")
        }
        let firstBatch = controlStart..<split
        let secondBatch = split..<chosenRange.upperBound
        XCTAssertGreaterThanOrEqual(firstBatch.count, 4); XCTAssertGreaterThanOrEqual(secondBatch.count, 4)
        let pauseIndex = firstBatch.upperBound - 1
        let cancelIndex = secondBatch.upperBound - 1

        dispatch(firstBatch, app: app)
        let pausedState = state(pauseIndex, book: book, app: app)
        let beforePause = try tapLiveFiniteControlOrSkip("pause", index: pauseIndex,
                                                        batch: firstBatch, book: book, app: app)
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
        // The task row can become Completed before its :acquire and resume
        // parent release their action owners. Observe the existing canClear
        // binding; never tap it or launch the next batch against that window.
        let resumedRow = exact("online-download-attempt:" + book.identity + ":" + String(pauseIndex) + ":" + String(resumed.attempts), app: app)
        let clearResumed = resumedRow.buttons["清除此章下载"]
        wait("The original Continue acquisition must release its action owner before the next finite batch", timeout: 300) {
            clearResumed.exists && clearResumed.isEnabled
        }
        keep(app, name: "actual-finite-download-resumed-and-completed")

        dispatch(secondBatch, app: app)
        let cancelledState = state(cancelIndex, book: book, app: app)
        let beforeCancel = try tapLiveFiniteControlOrSkip("cancel", index: cancelIndex,
                                                         batch: secondBatch, book: book, app: app)
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
        app.terminate(); app.launch(); openEntry(book, app: app)
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

    /// r12 consumes a new stopped physical snapshot. Existing completed rows
    /// and the full new batch are compared externally, never replayed in UI.
    func testActualFiniteDownloadCancelAndColdRetention() throws {
        struct Preproof: Decodable {
            let schemaVersion: Int
            let policy: String
            let selector: String
            let runID: String
            let capturedAtUTC: String
            let targetUDID: String
            let bundleID: String
            let runnerBundleID: String
            let sourceId: String
            let bookId: String
            let bookTitle: String
            let sourceVersion: String
            let firstIndex: UInt32
            let chapterCount: UInt32
            let cancelIndex: UInt32
            let existingCompletedIndexes: [UInt32]
            let currentChapter: UInt32
            let selectedLeafSHA256: String
            let originalUnknownAddSHA256: String
            let originalPendingOperationIDs: [String]
            let originalHostCommandCount: Int
            let prelaunchHostCommandCount: Int
            let baseline588SHA256: String
            let baseline667SHA256: String
            let artifactBindingSHA256: String
            let sourceFreezeSHA256: String
            let signedAppTreeSHA256: String
            let signedRunnerTreeSHA256: String
            let signedTestBinarySHA256: String
            let runnerExecutableSHA256: String
            let runnerInstalledPath: String
            let runnerBundleVersion: String
            let snapshotSHA256: String
            let physical: Bool
            let wired: Bool
            let bothProcessesAbsentBeforeCopy: Bool
            let historicalAudit: Bool
        }
        #if targetEnvironment(simulator)
        XCTFail("This cancel selector requires the externally bound original physical iPhone library")
        throw Prerequisite.invalid("physical finite cancel target")
        #endif
        let raw = try required("READER_FINITE_DOWNLOAD_PREPROOF_JSON")
        let proofSHA = try required("READER_FINITE_DOWNLOAD_PREPROOF_SHA256")
        let artifactSHA = try required("READER_FINITE_DOWNLOAD_ARTIFACT_BINDING_SHA256")
        let target = try required("READER_PHYSICAL_TARGET_UDID")
        let proofBytes = Data(raw.utf8)
        func digest(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
        func isSHA(_ value: String) -> Bool { value.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil }
        guard proofBytes.count <= 64 * 1024, isSHA(proofSHA), digest(proofBytes) == proofSHA else {
            XCTFail("Require exact fresh external r12 cancel preproof bytes before launching the App")
            throw Prerequisite.invalid("finite cancel preproof digest")
        }
        let proof = try JSONDecoder().decode(Preproof.self, from: proofBytes)
        let timestamp = ISO8601DateFormatter()
        timestamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let captured = timestamp.date(from: proof.capturedAtUTC) ?? ISO8601DateFormatter().date(from: proof.capturedAtUTC)
        let age = captured.map { Date().timeIntervalSince($0) }
        let book = Book(source: try required("READER_ONLINE_SOURCE_ID"), id: try required("READER_ONLINE_BOOK_ID"),
                        title: try required("READER_ONLINE_BOOK_TITLE"))
        let first = try unsigned("READER_ONLINE_CONTROL_FIRST_INDEX")
        let count = try unsigned("READER_ONLINE_CONTROL_CHAPTER_COUNT")
        let oldCompleted = try existingCompletedIndexes()
        guard proof.schemaVersion == 6, proof.policy == "physical-real-finite-cancel-r12-667-v6",
              proof.selector == "ReaderOnlineDownloadControlJourneyTests/testActualFiniteDownloadCancelAndColdRetention",
              UUID(uuidString: proof.runID)?.uuidString.lowercased() == proof.runID,
              let age, (0...1800).contains(age), proof.physical, proof.wired,
              proof.bothProcessesAbsentBeforeCopy, !proof.historicalAudit,
              ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == nil,
              UIDevice.current.userInterfaceIdiom == .phone,
              target.range(of: #"^(?:[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{40})$"#, options: .regularExpression) != nil,
              proof.targetUDID == target, proof.bundleID == "io.reader.minliny.free",
              proof.runnerBundleID == "io.reader.minliny.free.xctrunner",
              proof.sourceId == "https://dushu.baidu.com/", proof.sourceId == book.source,
              proof.bookId == book.id, proof.bookTitle == book.title,
              proof.sourceVersion == "47ff0e3312f354175e488ce582fcf699d0dc7a486a6f69903a0bb2b7f5894ce3",
              proof.firstIndex == first, first == 26, proof.chapterCount == count, count == 12,
              proof.cancelIndex == 37, proof.currentChapter == 0,
              proof.existingCompletedIndexes == Array(UInt32(3)...UInt32(25)),
              oldCompleted == Set(proof.existingCompletedIndexes),
              proof.originalHostCommandCount == 588, proof.prelaunchHostCommandCount == 667,
              proof.originalPendingOperationIDs == ["0ad35be2-67cd-43a0-b4b4-34e98814e40d"],
              proof.originalUnknownAddSHA256 == "b8da0dd291ca82d63ba2afb88a9e371a280cfd130317c6d7e5e167f0e93a8f82",
              proof.baseline588SHA256 == "fefbc0ec559976e660778954d0bda0311fb37f257a3a19809aa628628449c4fd",
              proof.baseline667SHA256 == "575532f73d5b68fde335695eb389412336e67bc8d57c940e44d3fcc7c46a1f55",
              isSHA(artifactSHA), proof.artifactBindingSHA256 == artifactSHA,
              [proof.selectedLeafSHA256, proof.sourceFreezeSHA256, proof.snapshotSHA256,
               proof.signedAppTreeSHA256, proof.signedRunnerTreeSHA256,
               proof.signedTestBinarySHA256, proof.runnerExecutableSHA256].allSatisfy(isSHA) else {
            XCTFail("Require fresh physical r12 installation, exact 667 original commands, sole historical unknown add and genuinely missing [26,38)")
            throw Prerequisite.invalid("finite cancel physical installation and selection identity")
        }
        let runnerBundle = Bundle.main
        let testBundle = Bundle(for: ReaderOnlineDownloadControlJourneyTests.self)
        guard runnerBundle.bundleIdentifier == proof.runnerBundleID,
              runnerBundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String == proof.runnerBundleVersion,
              runnerBundle.bundleURL.resolvingSymlinksInPath().standardizedFileURL.path
                == URL(fileURLWithPath: proof.runnerInstalledPath).resolvingSymlinksInPath().standardizedFileURL.path,
              let runnerExecutable = runnerBundle.executableURL, let testExecutable = testBundle.executableURL,
              digest(try Data(contentsOf: runnerExecutable)) == proof.runnerExecutableSHA256,
              digest(try Data(contentsOf: testExecutable)) == proof.signedTestBinarySHA256 else {
            XCTFail("The executing installed Runner and selected XCTest bytes must match the externally verified r12 artifact")
            throw Prerequisite.invalid("finite cancel executing signed Runner identity")
        }
        let app = XCUIApplication(bundleIdentifier: proof.bundleID)
        addTeardownBlock {
            if app.state != .notRunning { app.terminate() }
            XCTAssertTrue(app.wait(for: .notRunning, timeout: 10),
                          "Stop the exact r12 App for independent stopped-copy postproof after every outcome")
        }
        let startupState = app.state
        if startupState != .notRunning { app.terminate() }
        guard app.wait(for: .notRunning, timeout: 10) else {
            XCTFail("Stop only XCTest's exact startup App before the explicit r12 cold launch")
            throw Prerequisite.invalid("finite cancel cold launch prerequisite")
        }
        facts(["runID": proof.runID, "preproofSHA256": proofSHA, "artifactBindingSHA256": artifactSHA,
               "sourceFreezeSHA256": proof.sourceFreezeSHA256, "snapshotSHA256": proof.snapshotSHA256,
               "prelaunchHostCommandCount": String(proof.prelaunchHostCommandCount),
               "baseline667SHA256": proof.baseline667SHA256, "firstIndex": String(first),
               "chapterCount": String(count), "cancelIndex": String(proof.cancelIndex),
               "startupAppState": String(describing: startupState),
               "boundary": "Fresh external capture proves missing chapters and all retained original rows; no per-chapter UI preflight. Exact postproof and original ACK attribution remain required."],
              name: "physical-finite-cancel-r12-prelaunch-preproof")
        app.launch(); open(book, app: app)
        let originalChapter = try currentChapter(book, app: app)
        XCTAssertEqual(originalChapter, proof.currentChapter)
        hideControls(app)
        let originalProgress = app.staticTexts["reading-progress"].label
        let originalAnchor = try anchor(app)
        downloads(app)
        let batch = first..<(first + count)
        let cancelIndex = proof.cancelIndex
        dispatch(batch, app: app)

        func waitForOriginalBatchOwner() throws {
            // Read the original model.actions binding without scrolling or
            // invoking another operation; bound this r12 opportunity to 120s.
            let barrier = app.buttons["整本下载"]
            let released = { barrier.exists && barrier.isEnabled }
            if released() { return }
            let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in released() }, object: nil)
            guard XCTWaiter.wait(for: [expectation], timeout: 120) == .completed else {
                XCTFail("The original r12 finite batch owner did not settle within 120 seconds")
                throw Prerequisite.invalid("finite cancel original batch owner")
            }
        }
        // This dedicated branch never invokes the old natural-completion
        // helper, whose whole-batch row scan is irrelevant to this attempt.
        func skipIfCompletedBeforeCancel(_ observed: Observation) throws {
            guard observed.state == "已完成", observed.attempts > 0 else { return }
            facts(["chapterIndex": String(cancelIndex), "observedState": observed.state,
                   "attempts": String(observed.attempts), "issued": "false", "confirmed": "false",
                   "range": "26..<38", "externalPostproofRequired": "Confirm the entire genuine batch completed and every new original owner settled; no cancel ACK is expected"],
                  name: "actual-finite-cancel-r12-natural-completion")
            try waitForOriginalBatchOwner()
            keep(app, name: "actual-finite-cancel-r12-not-issued")
            throw XCTSkip("The genuine r12 endpoint completed before cancel was issued; cancellation remains unvalidated.")
        }
        revealFiniteControlAfterDispatch("cancel", index: cancelIndex, book: book, app: app)
        let states = app.staticTexts.matching(NSPredicate(format: "identifier == %@",
            "online-download-state:" + book.identity + ":" + String(cancelIndex)))
        let buttons = app.buttons.matching(NSPredicate(format: "identifier == %@",
            "online-download-cancel:" + book.identity + ":" + String(cancelIndex)))
        let rowState = states.firstMatch, cancel = buttons.firstMatch
        let live = ["排队中", "下载中"]
        let ready = {
            rowState.exists && (["已完成", "失败", "已暂停", "已取消"].contains(rowState.label)
                || live.contains(rowState.label) && cancel.exists && cancel.isEnabled)
        }
        if !ready() {
            wait("The original r12 endpoint must expose its actual live or terminal state", timeout: 30, ready)
        }
        if rowState.exists, live.contains(rowState.label), cancel.exists, cancel.isEnabled, !cancel.isHittable {
            revealFiniteControlAfterDispatch("cancel", index: cancelIndex, book: book, app: app)
        }
        let beforeCancel = try readObservation(cancelIndex, book: book, app: app)
        try skipIfCompletedBeforeCancel(beforeCancel)
        guard live.contains(beforeCancel.state), states.count == 1, buttons.count == 1,
              rowState.isHittable, cancel.exists, cancel.isEnabled, cancel.isHittable,
              live.contains(rowState.label) else {
            let latest = try readObservation(cancelIndex, book: book, app: app)
            try skipIfCompletedBeforeCancel(latest)
            facts(["chapterIndex": String(cancelIndex), "observedState": latest.state,
                   "attempts": String(latest.attempts), "issued": "false", "confirmed": "false"],
                  name: "actual-finite-cancel-r12-prerequisite-failed")
            XCTFail("The exact r12 endpoint did not expose a unique live enabled hittable cancel control")
            throw Prerequisite.invalid("finite cancel live opportunity")
        }
        cancel.tap()
        let continueCancelled = control("resume", index: cancelIndex, book: book, app: app)
        wait("The exact r12 task must reach cancelled and release its original control owner", timeout: 90) {
            rowState.exists && rowState.label == "已取消" && continueCancelled.exists && continueCancelled.isEnabled
        }
        let cancelled = try readObservation(cancelIndex, book: book, app: app)
        facts(["chapterIndex": String(cancelIndex), "observedLiveState": beforeCancel.state,
               "observedLiveAttempts": String(beforeCancel.attempts), "cancelledAttempts": String(cancelled.attempts),
               "issued": "true", "controlOwnerReleasedInUI": "true",
               "boundary": "UI observations require independent matching original cache.download.cancel ACK; they do not prove transport cancellation"],
              name: "actual-finite-cancel-r12-original-task")
        try waitForOriginalBatchOwner()
        XCTAssertEqual(try observe(cancelIndex, book: book, app: app), cancelled,
                       "The original batch's later completion must retain its cancelled endpoint")
        keep(app, name: "actual-finite-cancel-r12-original-owners-settled")
        app.buttons["online-download-close"].tap()
        XCTAssertEqual(try currentChapter(book, app: app), originalChapter)
        hideControls(app)
        try visible(originalAnchor, app: app, name: "actual-finite-cancel-r12-preserved-body")
        XCTAssertEqual(app.staticTexts["reading-progress"].label, originalProgress)
        leave(app)
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10), "Cold retention must start a new App process")
        app.launch(); open(book, app: app)
        XCTAssertEqual(try currentChapter(book, app: app), originalChapter)
        hideControls(app)
        try visible(originalAnchor, app: app, name: "actual-finite-cancel-r12-cold-body")
        XCTAssertEqual(app.staticTexts["reading-progress"].label, originalProgress)
        downloads(app)
        let cold = try observe(cancelIndex, book: book, app: app)
        XCTAssertEqual(cold, cancelled, "Cold startup must retain this exact cancelled task and its Core attempt counter")
        facts(["runID": proof.runID, "chapterIndex": String(cancelIndex), "state": cold.state,
               "attempts": String(cold.attempts), "originalChapter": String(originalChapter),
               "externalPostproofRequired": "All 667 original raw Host commands, sole historical unknown pending, original progress/bodies/tasks and unrelated books; exact [26,38) prefetch, chapter37 cancel ACK, original materialization/settle lineage and released leases. No per-row UI claims for the other chapters.",
               "openBoundaries": "Transport cancellation, whole V4-05, production Keychain and user acceptance"],
              name: "actual-finite-cancel-r12-cold-retention-boundary")
        keep(app, name: "actual-finite-cancel-r12-cold-target")
        app.buttons["online-download-close"].tap(); leave(app)
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
        let app = XCUIApplication(); app.launch(); openEntry(book, app: app)
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
        leave(app); app.terminate(); app.launch(); openEntry(book, app: app)
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

    /// Consumes only the already completed original 0..<50 request. Root must
    /// verify a fresh same-library preproof before this method can launch App.
    /// Normal reading may add acknowledged reading-time/history receipts.
    /// Neither this method nor a zero cache miss proves OS network unavailability.
    func testExistingOriginalWholeCompletionSummaryAndSecondColdRetentionWithoutRedispatch() throws {
        struct TaskProof: Decodable {
            let chapterIndex: UInt32
            let state: String
            let attempts: UInt32
        }
        struct PositionProof: Decodable {
            let chapterIndex: UInt32
            let chapterOffset: UInt64
            let chapterProgress: Double
            let locationRevision: String
        }
        struct RootChecks: Decodable {
            let readOnlySnapshot: Bool
            let capturedAfterInstallBeforeLaunch: Bool
            let sameOriginalLibrary: Bool
            let exactOriginalWholeAnd50ReportACKsSettled: Bool
            let all50OriginalTasksUnchanged: Bool
            let all50CachedBodiesAndResourcesMatchOriginal: Bool
            let originalCanonicalCatalogUnchanged: Bool
            let originalPositionUnchanged: Bool
            let rawFilesAndOtherSourcesPreserved: Bool
            let noPendingOperationsOrLeases: Bool
        }
        struct Preproof: Decodable {
            let schemaVersion: Int
            let policy: String
            let capturedAtUTC: String
            let targetUDID: String
            let bundleID: String
            let originalAuditSHA256: String
            let originalAfterSnapshotSHA256: String
            let originalWholeHostID: String
            let originalWholeCoreID: String
            let libraryIdentitySHA256: String
            let sourceId: String
            let bookId: String
            let title: String
            let expectedChapterCount: UInt32
            let canonicalRowsSHA256: String
            let originalTaskRowsSHA256: String
            let currentTaskRowsSHA256: String
            let taskProjectionSHA256: String
            let originalMaterializationReportCount: Int
            let physicalCachedBodyCount: Int
            let position: PositionProof
            let tasks: [TaskProof]
            let checks: RootChecks
        }
        let raw = try required("READER_WHOLE_COMPLETION_PREPROOF_JSON")
        let rawSHA = try required("READER_WHOLE_COMPLETION_PREPROOF_SHA256")
        let bytes = Data(raw.utf8)
        guard bytes.count <= 32 * 1024,
              rawSHA.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil,
              SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == rawSHA else {
            XCTFail("The exact Root-verified preproof bytes and digest are required before launching App")
            throw Prerequisite.invalid("original whole-completion preproof binding")
        }
        let proof = try JSONDecoder().decode(Preproof.self, from: bytes)
        let book = Book(source: try required("READER_ONLINE_SOURCE_ID"), id: try required("READER_ONLINE_BOOK_ID"),
                        title: try required("READER_ONLINE_BOOK_TITLE"))
        let originalBookID = "https://boxnovel.baidu.com/boxnovel/wiseapi/chapterList?bookid=4305547728&pageNum=1&order=asc&site="
        let expectedLocation = "reader-location-v1:" + originalBookID + ":3:0"
        let checks = proof.checks
        guard proof.schemaVersion == 1, proof.policy == "existing-original-whole-completion-readonly-v1",
              !proof.capturedAtUTC.isEmpty,
              proof.targetUDID == "EEA74BB1-5DFA-479A-ACAA-460503AD0F6B", proof.bundleID == "io.reader.minliny",
              proof.originalAuditSHA256 == "a0e6f3439eb461ae72abad29badcc694cd8a6c78708a1cf2476caff7681c42d0",
              proof.originalAfterSnapshotSHA256 == "bb69fa45431ef3c764982ca26b5d0830390a04350dad8fd952398599ff15f9b2",
              proof.originalWholeHostID == "5991536b-f56a-438a-a217-379026cf43ca",
              proof.originalWholeCoreID == "47d385db-48a3-f4a0-db34-8c118e47cd2d/3",
              proof.libraryIdentitySHA256 == "5d64bdadcf224edbb8287c1867e2b1d0efd565232dc17286d29dca47d9f8cba2",
              proof.sourceId == "https://dushu.baidu.com/", proof.bookId == originalBookID, proof.title == "剑来",
              book.source == proof.sourceId, book.id == proof.bookId, book.title == proof.title,
              proof.expectedChapterCount == 50, proof.originalMaterializationReportCount == 50, proof.physicalCachedBodyCount == 50,
              proof.canonicalRowsSHA256 == "56eebfc67199ba0fa856091b63e5517e291d2a0dbc6635414947a2e5aec5b7dc",
              proof.originalTaskRowsSHA256 == "bc18833bcba77080d201d7038be86f98c6326c4f41b3c28e7ee2ef69329487e1",
              proof.currentTaskRowsSHA256 == proof.originalTaskRowsSHA256,
              proof.taskProjectionSHA256 == "9aff8d8ae9c5e5e9013561e792f9b135827cd4552894e786da5346ef130e2834",
              proof.position.chapterIndex == 3, proof.position.chapterOffset == 0, proof.position.chapterProgress == 0,
              proof.position.locationRevision == expectedLocation,
              proof.tasks.map(\.chapterIndex) == Array(UInt32(0)..<UInt32(50)),
              proof.tasks.allSatisfy({ $0.state == "completed" && $0.attempts > 0 }),
              checks.readOnlySnapshot, checks.capturedAfterInstallBeforeLaunch, checks.sameOriginalLibrary,
              checks.exactOriginalWholeAnd50ReportACKsSettled, checks.all50OriginalTasksUnchanged,
              checks.all50CachedBodiesAndResourcesMatchOriginal, checks.originalCanonicalCatalogUnchanged,
              checks.originalPositionUnchanged, checks.rawFilesAndOtherSourcesPreserved, checks.noPendingOperationsOrLeases else {
            XCTFail("Require the exact original whole request, all 50 settled tasks and original chapter-3 scalar-0 location; a current read never substitutes for an ACK")
            throw Prerequisite.invalid("original whole-completion proof identity")
        }
        let projection: [[String: Any]] = proof.tasks.map {
            ["chapterIndex": $0.chapterIndex, "state": $0.state, "attempts": $0.attempts]
        }
        let projectionBytes = try JSONSerialization.data(withJSONObject: projection, options: [.sortedKeys])
        guard SHA256.hash(data: projectionBytes).map({ String(format: "%02x", $0) }).joined() == proof.taskProjectionSHA256 else {
            XCTFail("Every original task index/state/attempt must match the byte-bound original mapping")
            throw Prerequisite.invalid("original task projection")
        }
        facts(["preproofSHA256": rawSHA, "capturedAtUTC": proof.capturedAtUTC,
               "originalWholeHostID": proof.originalWholeHostID, "originalWholeCoreID": proof.originalWholeCoreID,
               "scope": "Existing original completion only; no original download intent is replayed",
               "scalarBoundary": "Root's actual preproof establishes chapter 3/scalar 0; the footer is a percentage, not a scalar measurement",
               "networkBoundary": "OS network availability is not changed or accepted by this method"], name: "existing-whole-completion-original-proof-binding")

        let app = XCUIApplication(); app.launch(); open(book, app: app)
        XCTAssertEqual(try currentChapter(book, app: app), proof.position.chapterIndex)
        hideControls(app)
        let warmProgress = app.staticTexts["reading-progress"]
        XCTAssertTrue(warmProgress.waitForExistence(timeout: 5))
        let originalProgress = warmProgress.label
        XCTAssertEqual(originalProgress, "0%")
        // This anchor is captured from the real body just opened by this
        // method. It is never synthesized from an old snapshot or cache text.
        let originalAnchor = try anchor(app)
        let summary = "已完成 50 · 缓存 0 · 失败 0 · 暂停 0"
        for cold in [false, true] {
            if cold {
                app.terminate(); app.launch(); open(book, app: app)
                XCTAssertEqual(try currentChapter(book, app: app), proof.position.chapterIndex)
                hideControls(app)
                try visible(originalAnchor, app: app, name: "existing-whole-second-cold-original-visible-body")
                let coldProgress = app.staticTexts["reading-progress"]
                XCTAssertTrue(coldProgress.waitForExistence(timeout: 5))
                XCTAssertEqual(coldProgress.label, originalProgress)
            }
            downloads(app)
            let summaryLabel = app.staticTexts[summary]
            revealTop(summaryLabel, app: app)
            wait("The original 50 completed tasks must remain in their mutually exclusive completed bucket", timeout: 30) { summaryLabel.exists }
            XCTAssertEqual(app.textFields["末章"].value as? String, String(proof.expectedChapterCount),
                           "Read the original canonical extent without editing a range or refreshing its catalog")
            for expected in proof.tasks {
                let actual = try observe(expected.chapterIndex, book: book, app: app)
                XCTAssertEqual(actual.state, "已完成")
                XCTAssertEqual(actual.attempts, expected.attempts, "Retain this exact original task's Core counter, not a new request")
            }
            revealTop(summaryLabel, app: app); XCTAssertTrue(summaryLabel.exists)
            keep(app, name: cold ? "existing-whole-second-cold-original-task-retention" : "existing-whole-original-completion-summary")
            app.buttons["online-download-close"].tap()
            XCTAssertEqual(try currentChapter(book, app: app), proof.position.chapterIndex)
            hideControls(app)
            try visible(originalAnchor, app: app, name: cold ? "existing-whole-second-cold-returned-original-body" : "existing-whole-summary-returned-original-body")
            let returnedProgress = app.staticTexts["reading-progress"]
            XCTAssertTrue(returnedProgress.waitForExistence(timeout: 5))
            XCTAssertEqual(returnedProgress.label, originalProgress)
            leave(app) // Existing normal reader exit and save barrier.
        }
        facts(["originalTasksAndAttemptsRetained": "50", "summary": summary,
               "newDownloadOrControlIntentRequested": "false", "originalOCRAnchorSource": "actual visible body opened in this method",
               "allowedNewRecords": "Normal acknowledged reading-time/progress/history receipts; never claim whole-DB byte equality",
               "openBoundaries": "OS offline, original whole version-origin, pause/continue/cancel remain OPEN"],
              name: "existing-whole-completion-tail-boundary")
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
        return try readObservation(index, book: book, app: app)
    }
    private func readObservation(_ index: UInt32, book: Book, app: XCUIApplication) throws -> Observation {
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
    private func tapLiveFiniteControlOrSkip(_ action: String, index: UInt32,
                                            batch: Range<UInt32>, book: Book,
                                            app: XCUIApplication) throws -> Observation {
        // Production relocates this exact requested endpoint beside the range
        // controls and omits its old list position. Reach that original row
        // without scanning the canonical list during the real live window.
        revealFiniteControlAfterDispatch(action, index: index, book: book, app: app)
        let stateID = "online-download-state:" + book.identity + ":" + String(index)
        let buttonID = "online-download-" + action + ":" + book.identity + ":" + String(index)
        let states = app.staticTexts.matching(NSPredicate(format: "identifier == %@", stateID))
        let buttons = app.buttons.matching(NSPredicate(format: "identifier == %@", buttonID))
        let rowState = states.firstMatch
        let button = buttons.firstMatch
        let live = ["排队中", "下载中"]
        let terminal = ["已完成", "失败", "已暂停", "已取消"]
        let isReady = {
            rowState.exists && (terminal.contains(rowState.label)
                || live.contains(rowState.label) && button.exists && button.isEnabled)
        }
        // XCTest's predicate waiter can defer its first evaluation. A genuine
        // queued/in-progress control already present needs no polling interval.
        let result: XCTWaiter.Result
        if isReady() { result = .completed }
        else {
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in isReady() }, object: nil)
            result = XCTWaiter.wait(for: [ready], timeout: 30)
        }
        if result == .completed, rowState.exists, live.contains(rowState.label),
           button.exists, button.isEnabled, !button.isHittable {
            // A fresh queued row can gain its control below the prior state's
            // frame. Position the actual button before reading and issuing it.
            revealFiniteControlAfterDispatch(action, index: index, book: book, app: app)
        }
        // The row is already positioned. Do not repeat revealChapter and its
        // AX/scroll work between observing the original task and tapping it.
        let before = try readObservation(index, book: book, app: app)
        try skipNaturallyCompletedFiniteBatchIfNeeded(action, index: index, before: before,
                                                     batch: batch, book: book, app: app)
        guard result == .completed, live.contains(before.state), states.count == 1, buttons.count == 1,
              rowState.isHittable, button.exists, button.isEnabled, button.isHittable,
              live.contains(rowState.label) else {
            // The real task may finish between its counter read and the final
            // tappability check. Re-read only on this failed gate, before any
            // action, so a now-completed original task still takes strict SKIP.
            let latest = try readObservation(index, book: book, app: app)
            try skipNaturallyCompletedFiniteBatchIfNeeded(action, index: index, before: latest,
                                                         batch: batch, book: book, app: app)
            facts(["action": action, "chapterIndex": String(index), "observedState": latest.state,
                   "attempts": String(latest.attempts), "issued": "false", "confirmed": "false",
                   "reason": "No actual live enabled control opportunity; task did not naturally complete"],
                  name: "actual-finite-" + action + "-prerequisite-failed")
            keep(app, name: "actual-finite-" + action + "-not-issued")
            XCTFail("The exact finite task did not expose a live " + action + " control or naturally complete")
            throw Prerequisite.invalid("finite " + action + " control")
        }
        button.tap()
        return before
    }
    private func skipNaturallyCompletedFiniteBatchIfNeeded(_ action: String, index: UInt32,
                                                           before: Observation, batch: Range<UInt32>,
                                                           book: Book, app: XCUIApplication) throws {
        if before.state == "已完成" && before.attempts > 0 {
            facts(["action": action, "chapterIndex": String(index), "observedState": before.state,
                   "attempts": String(before.attempts), "issued": "false", "confirmed": "false",
                   "reason": "The genuine task completed before a live control was issued"],
                  name: "actual-finite-" + action + "-natural-completion")
            keep(app, name: "actual-finite-" + action + "-not-issued")
            // A Completed row can precede release of the original finite
            // batch owner. Do not exit the UI method with this new operation
            // still pending merely because no live control was available.
            let barrier = app.buttons["整本下载"]
            revealTop(barrier, app: app)
            let released = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                barrier.exists && barrier.isEnabled
            }, object: nil)
            guard XCTWaiter.wait(for: [released], timeout: 300) == .completed else {
                XCTFail("The naturally completed finite task's original batch owner did not settle")
                throw Prerequisite.invalid("finite batch owner")
            }
            for member in batch {
                let observed = try observe(member, book: book, app: app)
                guard observed.state == "已完成" && observed.attempts > 0 else {
                    XCTFail("The naturally settled finite batch also has an incomplete or failed original task")
                    throw Prerequisite.invalid("finite batch task " + String(member))
                }
            }
            throw XCTSkip("The genuine finite download completed before the " + action
                          + " control could be issued; this run does not validate " + action + ".")
        }
    }
    private func revealFiniteControlAfterDispatch(_ action: String, index: UInt32,
                                                  book: Book, app: XCUIApplication) {
        let scroll = app.scrollViews["online-download-scroll"]
        XCTAssertTrue(scroll.exists)
        let value = state(index, book: book, app: app)
        let button = control(action, index: index, book: book, app: app)
        let directlyReachable = {
            value.exists && value.isHittable && (!button.exists || button.isHittable)
        }
        if directlyReachable() { return }
        XCTAssertTrue(value.waitForExistence(timeout: 30), "Production must expose the exact requested endpoint")
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            if directlyReachable() { return }
            let target = button.exists ? button : value
            let frame = target.frame
            let viewport = scroll.frame.intersection(app.frame)
            // A partially visible original row needs no gesture when its exact
            // state/control is hittable. Scroll only from this target's native
            // geometry; absence or an occluded in-viewport control is no reason
            // to guess a direction or issue a coordinate tap.
            if !frame.isNull, !frame.isInfinite, frame.width > 0, frame.height > 0,
               !viewport.isNull, viewport.width > 0, viewport.height > 0 {
                if frame.minY < viewport.minY { scroll.swipeDown(); continue }
                if frame.maxY > viewport.maxY { scroll.swipeUp(); continue }
            }
            wait("The exact directly presented finite control must become natively hittable", timeout: 30,
                 directlyReachable)
            return
        }
        XCTFail("Reach only the exact directly presented finite task and any present control.\n" + app.debugDescription)
    }
    private func revealTop(_ target: XCUIElement, app: XCUIApplication) {
        let scroll = app.scrollViews["online-download-scroll"]
        guard scroll.exists else {
            XCTFail("The native download scroll view is missing")
            return
        }
        let deadline = Date().addingTimeInterval(30)
        for _ in 0..<32 where Date() < deadline {
            if target.exists && target.isHittable { return }
            scroll.swipeDown()
        }
        XCTAssertTrue(target.exists && target.isHittable,
                      "The exact top control was not reachable within 30 seconds or 32 swipes.\n" + app.debugDescription)
    }
    private func revealChapter(_ index: UInt32, book: Book, app: XCUIApplication) {
        let target = state(index, book: book, app: app), scroll = app.scrollViews["online-download-scroll"]
        XCTAssertTrue(scroll.exists)
        let prefix = "online-download-state:" + book.identity + ":"
        let deadline = Date().addingTimeInterval(30)
        var visited = Set<String>()
        var trace: [String] = []
        for _ in 0..<32 where Date() < deadline {
            if target.exists && target.isHittable { return }
            let scrollFrame = scroll.frame
            let viewport = scrollFrame.intersection(app.frame).insetBy(dx: 4, dy: 8)
            guard !viewport.isNull, !viewport.isInfinite, viewport.width > 20, viewport.height > 40,
                  let snapshot = try? scroll.snapshot() else { break }
            // One frozen AX tree supplies both identity and geometry. Re-reading
            // every lazy row's live isHittable/identifier can race a refresh.
            var nodes: [XCUIElementSnapshot] = []
            var pending: [XCUIElementSnapshot] = [snapshot]
            while let node = pending.popLast() {
                nodes.append(node)
                pending.append(contentsOf: node.children.reversed())
            }
            let rows = nodes.compactMap { node -> (index: UInt32, frame: CGRect)? in
                guard node.elementType == .staticText, node.identifier.hasPrefix(prefix),
                      let value = UInt32(node.identifier.dropFirst(prefix.count)),
                      !node.frame.isNull, !node.frame.isInfinite,
                      node.frame.width > 0, node.frame.height > 0 else { return nil }
                return (value, node.frame)
            }
            let visibleRows = rows.filter { $0.frame.intersects(viewport) }
            let signature = visibleRows.map {
                String($0.index) + ":" + String(Int(($0.frame.minY / 4).rounded()))
            }.joined(separator: ",")
            trace.append(signature)
            guard visited.insert(signature).inserted else { break }

            let later: Bool
            var distance = viewport.height * 0.55
            if let actual = rows.first(where: { $0.index == index }) {
                // The endpoint can be presented above the canonical list.
                // Its actual frame takes priority over its chapter number.
                if actual.frame.minY < viewport.minY {
                    later = false
                    distance = viewport.minY - actual.frame.minY + actual.frame.height
                } else if actual.frame.maxY > viewport.maxY {
                    later = true
                    distance = actual.frame.maxY - viewport.maxY + actual.frame.height
                } else {
                    break // In-viewport occlusion is not a scrolling direction.
                }
            } else {
                // Production relocates one original endpoint ahead of chapter
                // zero. In r11 its index 25 was the sole hittable row at the top;
                // min(hittable indexes) sent chapter 22 upward forever. Remove
                // that out-of-order prefix before using canonical list order.
                var canonical = rows[...]
                if rows.count > 1,
                   let restart = (1..<rows.count).first(where: { rows[$0].index < rows[$0 - 1].index }) {
                    canonical = rows[restart...]
                }
                let inputVisible = nodes.contains {
                    $0.elementType == .textField && ($0.label == "起章" || $0.label == "末章"
                        || $0.placeholderValue == "起章" || $0.placeholderValue == "末章")
                        && $0.frame.intersects(viewport)
                }
                let visibleCanonical = canonical.filter { $0.frame.intersects(viewport) }
                let ordered = visibleCanonical.isEmpty ? Array(canonical) : visibleCanonical
                if inputVisible {
                    later = true // An absent canonical row is below the inputs.
                } else if let first = ordered.map(\.index).min(), index < first {
                    later = false
                } else if let last = ordered.map(\.index).max(), index > last {
                    later = true
                } else {
                    break // No native AX evidence supports a guessed gesture.
                }
            }
            // A bounded drag avoids flinging past a nearby row and oscillating
            // between two viewports. No coordinate tap selects a task/control.
            distance = min(viewport.height * 0.55, max(24, distance))
            let startY = later ? viewport.maxY - 8 : viewport.minY + 8
            let endY = startY + (later ? -distance : distance)
            let origin = scroll.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: viewport.midX - scrollFrame.minX,
                                                   dy: startY - scrollFrame.minY))
            let end = origin.withOffset(CGVector(dx: viewport.midX - scrollFrame.minX,
                                                 dy: endY - scrollFrame.minY))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(target.exists && target.isHittable,
                      "Reach exact chapter \(index) within 30 seconds/32 progressing viewports; stop on a repeated viewport.\n"
                        + trace.joined(separator: "\n") + "\n" + app.debugDescription)
    }
    private func open(_ book: Book, app: XCUIApplication) {
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 25))
        if app.textFields["shelf-filter"].exists { app.buttons["bookshelf-filter-close"].tap() }
        let rows = app.buttons.matching(NSPredicate(format: "identifier == %@", "book-" + book.id))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 20)); XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(rows.firstMatch.isHittable); rows.firstMatch.tap()
        XCTAssertTrue(app.textViews["reading-body"].waitForExistence(timeout: 180))
        controls(app)
        let title = exact("reading-book:" + book.identity, type: .staticText, app: app)
        XCTAssertTrue(title.exists); XCTAssertEqual(title.label, book.title)
    }
    private func openEntry(_ book: Book, app: XCUIApplication) {
        if ProcessInfo.processInfo.environment["READER_ONLINE_OPEN_CONTINUE_CARD"] == "1" {
            XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 25))
            let card = app.buttons["shelf-continue-card"]
            XCTAssertTrue(card.waitForExistence(timeout: 20), "The admitted shelf book must retain its continue card")
            XCTAssertTrue(card.isHittable); card.tap()
            XCTAssertTrue(app.textViews["reading-body"].waitForExistence(timeout: 180))
            controls(app)
            let title = exact("reading-book:" + book.identity, type: .staticText, app: app)
            XCTAssertTrue(title.exists); XCTAssertEqual(title.label, book.title)
        } else {
            open(book, app: app)
        }
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
        var anchor = ""
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let actual = try? self.ocr(app), actual.count >= 4 else { return false }
            lines = actual
            // Real chapters can begin with several short paragraphs. Ignore
            // the possibly clipped first row, then consume consecutive rows
            // from this same viewport without weakening the 18-character floor.
            anchor = String(self.normalize(actual.dropFirst().joined()).prefix(24))
            return anchor.count >= 18
        }, object: nil)
        let result = XCTWaiter.wait(for: [ready], timeout: 30)
        facts(["visibleOCRAnchor": anchor, "visibleOCRLines": lines.joined(separator: "\n"),
               "anchorCharacterCount": String(anchor.count)],
              name: "actual-download-original-visible-body")
        keep(app, name: "actual-download-original-visible-body")
        guard result == .completed, (18...24).contains(anchor.count) else {
            XCTFail("The real visible online body must supply an 18–24-character anchor before controlling unrelated downloads")
            throw Prerequisite.invalid("actual visible-body anchor")
        }
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
