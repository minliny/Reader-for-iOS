import Foundation
import CryptoKit
import XCTest
#if canImport(ReaderCoreClient)
import ReaderCoreClient
#endif
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

@MainActor
final class ReaderFeatureRecoveryTests: XCTestCase {
    func testColdGroupAndRuleRecoveryConsumesExactOriginalReceiptsWithoutRedispatch() async throws {
        let fixture = try FeatureRecoveryFixture()
        defer { fixture.cleanUp() }
        let groupID = UUID().uuidString
        fixture.client.hold("bookshelf.management.mutation.apply")
        do { _ = try await fixture.service.createGroup(name: "原分组", operationID: groupID); XCTFail("Original Core ACK is held") }
        catch ReaderLibraryError.operationPending(_) {}
        try fixture.reopen()
        // A real Core rejection of this malformed *query* does not reject
        // the already committed original business write.
        fixture.client.invalidateNextReceiptQuery()
        let queryFailure = try await fixture.service.resumePendingFeatureOperation(groupID)
        XCTAssertEqual(queryFailure.status, .pending)
        let recoveredGroup = try await fixture.service.resumePendingFeatureOperation(groupID)
        XCTAssertEqual(recoveredGroup.status, .completed)
        XCTAssertFalse(recoveredGroup.remaining)
        XCTAssertEqual(fixture.client.count("bookshelf.management.mutation.apply"), 0)
        let groups = try await fixture.service.groups()
        XCTAssertEqual(groups.map(\.groupName), ["原分组"])
        let repeatedGroup = try await fixture.service.resumePendingFeatureOperation(groupID)
        XCTAssertEqual(repeatedGroup.status, .completed)
        let ruleID = UUID().uuidString
        fixture.client.hold("rules.mutation.apply")
        do {
            _ = try await fixture.service.createReplaceRule(.init(name: "原规则", pattern: "保留", replacement: "留存", isRegex: false), operationID: ruleID)
            XCTFail("Original Core rule ACK is held")
        } catch ReaderLibraryError.operationPending(_) {}
        try fixture.reopen()
        let recoveredRule = try await fixture.service.resumePendingFeatureOperation(ruleID)
        XCTAssertEqual(recoveredRule.status, .completed)
        XCTAssertEqual(fixture.client.count("rules.mutation.apply"), 0)
        let rules = try await fixture.service.replaceRules()
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules.first?.name, "原规则")
        let pending = try await fixture.service.pendingFeatureOperations()
        XCTAssertTrue(pending.isEmpty)
        try await fixture.service.close()
    }

    func testColdRemoveCleansOnlyItsOriginalAssetAndOldReceiptPreservesAReimport() async throws {
        let fixture = try FeatureRecoveryFixture()
        defer { fixture.cleanUp() }
        let book = try await fixture.service.importBook(at: fixture.input).book
        let initialUngrouped = try await fixture.service.listBooks(query: .init(group: ""))
        XCTAssertEqual(initialUngrouped.map(\.bookId), [book.bookId])
        let group = try await fixture.service.createGroup(name: "具名组", operationID: UUID().uuidString)
        _ = try await fixture.service.assignGroup(group, to: book, operationID: UUID().uuidString)
        let afterAssignment = try await fixture.service.listBooks(query: .init(group: ""))
        XCTAssertTrue(afterAssignment.isEmpty, "An empty group query must use Core hasGroup:false, never all books")
        let named = try await fixture.service.listBooks(query: .init(group: group.groupName))
        XCTAssertEqual(named.map(\.bookId), [book.bookId])
        let all = try await fixture.service.listBooks(query: .init(group: nil))
        XCTAssertEqual(all.map(\.bookId), [book.bookId])
        let source = try await fixture.service.retainedSourceURL(for: book)
        let operation = UUID().uuidString
        fixture.client.hold("bookshelf.management.mutation.apply")
        do { _ = try await fixture.service.removeBooks([book], operationID: operation); XCTFail("Original removal ACK is held") }
        catch ReaderLibraryError.operationPending(_) {}
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        try fixture.reopen()
        let result = try await fixture.service.resumePendingFeatureOperation(operation)
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(fixture.client.count("bookshelf.management.mutation.apply"), 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        let reimported = try await fixture.service.importBook(at: fixture.input).book
        let newSource = try await fixture.service.retainedSourceURL(for: reimported)
        XCTAssertTrue(FileManager.default.fileExists(atPath: newSource.path))
        let oldRecovery = try await fixture.service.resumePendingFeatureOperation(operation)
        XCTAssertEqual(oldRecovery.status, .completed)
        _ = try await fixture.service.removeBooks([book], operationID: operation)
        XCTAssertTrue(FileManager.default.fileExists(atPath: newSource.path), "An old completed ACK cannot unlink a newly owned same-SHA source")
        XCTAssertEqual(try Data(contentsOf: newSource), fixture.original)
        XCTAssertEqual(try Data(contentsOf: fixture.input), fixture.original)
        let shelf = try await fixture.service.listBooks()
        XCTAssertEqual(shelf.map(\.bookId), [book.bookId])
        try await fixture.service.close()
    }

    func testColdBookmarkRecoverySettlesOnlyTheOriginalCoreBinding() async throws {
        let fixture = try FeatureRecoveryFixture()
        defer { fixture.cleanUp() }
        let book = try await fixture.service.importBook(at: fixture.input).book
        let chapters = try await fixture.service.chapters(for: book)
        let chapter = try XCTUnwrap(chapters.first { $0.title.hasPrefix("第一章") })
        let content = try await fixture.service.content(for: book, chapterIndex: chapter.index)
        let operation = UUID().uuidString
        fixture.client.hold("bookmark.create")
        do {
            _ = try await fixture.service.createBookmark(for: book, content: content, scalarOffset: 20,
                text: String(content.content.unicodeScalars.prefix(60)), note: "原书签", operationID: operation)
            XCTFail("Original bookmark ACK is held")
        } catch ReaderLibraryError.operationPending(_) {}
        let original = try XCTUnwrap(fixture.client.lastParameters("bookmark.create"))
        try fixture.reopen()
        let result = try await fixture.service.resumePendingFeatureOperation(operation)
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(fixture.client.count("bookmark.create"), 0)
        XCTAssertEqual(fixture.client.count("bookmark.operation.settle"), 1)
        let settlement = try XCTUnwrap(fixture.client.lastParameters("bookmark.operation.settle"))
        XCTAssertEqual(settlement["operationId"] as? String, original["operationId"] as? String)
        XCTAssertEqual(settlement["sequence"] as? NSNumber, original["sequence"] as? NSNumber)
        let marks = try await fixture.service.bookmarks(for: book)
        XCTAssertEqual(marks.count, 1)
        XCTAssertEqual(marks.first?.content, "原书签")
        let repeated = try await fixture.service.resumePendingFeatureOperation(operation)
        XCTAssertEqual(repeated.status, .completed)
        XCTAssertEqual(fixture.client.count("bookmark.operation.settle"), 1)
        let pending = try await fixture.service.pendingFeatureOperations()
        XCTAssertTrue(pending.isEmpty)
        try await fixture.service.close()
    }

    func testUnregisteredColdWriteStaysPendingEvenWhenFreshRowsExist() async throws {
        let fixture = try FeatureRecoveryFixture()
        defer { fixture.cleanUp() }
        let operation = UUID().uuidString
        fixture.client.hold("book-group.create")
        do {
            _ = try await fixture.service.coreMutation("book-group.create", ["groupName": "旧无查询入口"], operationID: operation, scope: "legacy-group")
            XCTFail("The actual original legacy terminal is held")
        } catch ReaderLibraryError.operationPending(_) {}
        try fixture.reopen()
        let rows = try await fixture.service.groups()
        XCTAssertEqual(rows.count, 1)
        let recovered = try await fixture.service.resumePendingFeatureOperation(operation)
        XCTAssertEqual(recovered.status, .pending)
        XCTAssertTrue(recovered.remaining)
        XCTAssertEqual(fixture.client.count("book-group.create"), 0)
        let pending = try await fixture.service.pendingFeatureOperations()
        XCTAssertTrue(pending.contains { $0.id == operation && !$0.acknowledged })
        try await fixture.service.close()
    }

    func testColdReprocessOwnerWithoutOriginalReceiptRemainsPendingAndPreservesRawSource() async throws {
        let fixture = try FeatureRecoveryFixture()
        defer { fixture.cleanUp() }
        let book = try await fixture.service.importBook(at: fixture.input).book
        let operation = UUID().uuidString
        fixture.client.hold("import.persist")
        do { _ = try await fixture.service.reprocessLocalBook(book, operationID: operation); XCTFail("Original reprocess persist terminal is held") }
        catch ReaderLibraryError.operationPending(_) {}
        try fixture.reopen()
        let recovered = try await fixture.service.resumePendingFeatureOperation(operation)
        XCTAssertEqual(recovered.status, .pending)
        XCTAssertEqual(fixture.client.count("import.parse"), 0)
        XCTAssertEqual(fixture.client.count("import.persist"), 0)
        XCTAssertEqual(fixture.client.count("import.finalize"), 0)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)
        let retained = try await fixture.service.retainedSourceURL(for: book)
        XCTAssertEqual(try Data(contentsOf: retained), fixture.original)
        XCTAssertEqual(try Data(contentsOf: fixture.input), fixture.original)
        try await fixture.service.close()
    }

    func testColdSwitchCommitRecoveryUsesCoreMatchAndFinalizesAfterTheCachedTargetBody() async throws {
        let fixture = try FeatureRecoveryFixture()
        defer { fixture.cleanUp() }
        let local = try await fixture.service.importBook(at: fixture.input).book
        let localChapters = try await fixture.service.chapters(for: local)
        let localChapter = try XCTUnwrap(localChapters.first { $0.title.hasPrefix("第一章") })
        let genuineBody = try await fixture.service.content(for: local, chapterIndex: localChapter.index)
        // This is a method-level Core source descriptor, not evidence of a
        // live online source. Its body is a bounded excerpt of the actual
        // protected Downloads book, never generated novel text.
        let excerpt = String(genuineBody.content.unicodeScalars.prefix(500))
        let first = try await fixture.seedCachedRemote(source: "https://reader-recovery-a.invalid", title: local.title,
            author: local.author, chapterTitle: localChapter.title, body: excerpt)
        let second = try await fixture.seedCachedRemote(source: "https://reader-recovery-b.invalid", title: local.title,
            author: local.author, chapterTitle: localChapter.title, body: excerpt)
        _ = try await fixture.service.beginOnlineAdmission(.init(book: first.book, chapters: [first.chapter],
            firstReadableIndex: first.chapter.index), chapterIndex: first.chapter.index, operationID: UUID().uuidString)
        let oldContent = try await fixture.service.content(for: first.book, chapterIndex: first.chapter.index)
        let observed = try await fixture.service.progress(for: first.book)
        _ = try await fixture.service.saveProgress(for: first.book, content: oldContent, scalarOffset: 20,
            expectedRevision: observed.progressRevision)
        let operation = UUID().uuidString
        let coreID = await fixture.service.coreLineageID(operation, sequence: 1)
        let parameters: [String: Any] = ["operationId": coreID, "sequence": 1,
            "from": ["sourceId": first.book.sourceId, "bookId": first.book.bookId],
            "target": ["sourceId": second.book.sourceId, "bookId": second.book.bookId, "title": second.book.title, "author": second.book.author],
            "newToc": [["chapterId": second.chapter.url, "chapterTitle": second.chapter.title, "chapterUrl": second.chapter.url, "order": second.chapter.index]],
            "currentChapterTitle": first.chapter.title, "currentChapterIndex": first.chapter.index,
            "updatedAt": Int64(Date().timeIntervalSince1970)]
        fixture.client.hold("source.switch.commit")
        do {
            _ = try await fixture.service.coreMutation("source.switch.commit", parameters, operationID: operation, scope: "source-switch")
            XCTFail("The real original commit ACK is held")
        } catch ReaderLibraryError.operationPending(_) {}
        try fixture.reopen()
        let recovered = try await fixture.service.resumePendingFeatureOperation(operation)
        XCTAssertEqual(recovered.status, .completed, recovered.message ?? "cold switch recovery has no diagnostic")
        XCTAssertEqual(fixture.client.count("source.switch.commit"), 0)
        XCTAssertEqual(fixture.client.count("source.switch.finalize"), 1)
        XCTAssertEqual(fixture.client.count("source.switch.rollback"), 0)
        let content = try await fixture.service.content(for: second.book, chapterIndex: second.chapter.index)
        XCTAssertFalse(content.content.isEmpty)
        XCTAssertNotNil(content.bodyVersion)
        let removed = try await fixture.service.bookDetails(for: first.book)
        let active = try await fixture.service.bookDetails(for: second.book)
        XCTAssertNil(removed)
        XCTAssertNotNil(active)
        let pending = try await fixture.service.pendingFeatureOperations()
        XCTAssertFalse(pending.contains { $0.id == operation || $0.id == operation + ":finalize" })
        let repeated = try await fixture.service.resumePendingFeatureOperation(operation)
        XCTAssertEqual(repeated.status, .completed, repeated.message ?? "repeated cold switch recovery has no diagnostic")
        XCTAssertEqual(fixture.client.count("source.switch.finalize"), 1)
        XCTAssertEqual(try Data(contentsOf: fixture.input), fixture.original)
        try await fixture.service.close()
    }

    func testColdSwitchCanonicalAndFinalizeRecoverOnlyOriginalACKWithoutOverwritingLaterProgress() async throws {
        // runtime3 exposed an invalid cross-runtime CAS-token comparison.
        // Core hashes its per-runtime progress epoch together with the history
        // sequence/current row. Compare every wire row/metadata field instead.
        let exactRow: (Data) throws -> Data = { data in
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            object.removeValue(forKey: "progressRevision")
            return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        }
        for heldMethod in ["reading.progress.update", "source.switch.finalize"] {
            let fixture = try FeatureRecoveryFixture()
            defer { fixture.cleanUp() }
            let intent = try await fixture.seedOriginalSwitch()
            _ = try await fixture.service.coreMutation("source.switch.commit", intent.parameters,
                operationID: intent.operation, scope: "source-switch")
            let beforeDispatches = fixture.client.count(heldMethod)
            fixture.client.hold(heldMethod)
            let first = try await fixture.service.resumePendingFeatureOperation(intent.operation)
            XCTAssertEqual(first.status, .pending, first.message ?? heldMethod)
            XCTAssertEqual(fixture.client.count(heldMethod), beforeDispatches + 1)
            // The canonical mutation has already executed in Core. A newer
            // real position must survive later recovery of its withheld ACK.
            let body = try await fixture.service.content(for: intent.target, chapterIndex: 0)
            let observed = try await fixture.service.progress(for: intent.target)
            _ = try await fixture.service.saveProgress(for: intent.target, content: body, scalarOffset: 10,
                expectedRevision: observed.progressRevision)
            let newer = try await fixture.service.progress(for: intent.target)
            let newerRow = try exactRow(await fixture.service.coreRead("reading.progress.get", [
                "sourceId": intent.target.sourceId, "bookId": intent.target.bookId
            ]))
            try fixture.reopen()
            let recovered = try await fixture.service.resumePendingFeatureOperation(intent.operation)
            XCTAssertEqual(recovered.status, .completed, recovered.message ?? heldMethod)
            XCTAssertEqual(fixture.client.count("source.switch.commit"), 0)
            XCTAssertEqual(fixture.client.count("reading.progress.update"), 0, "The original canonical write must be queried, never redispatched")
            XCTAssertEqual(fixture.client.count("source.switch.finalize"), heldMethod == "source.switch.finalize" ? 0 : 1)
            XCTAssertEqual(fixture.client.count("source.switch.rollback"), 0)
            let restored = try await fixture.service.progress(for: intent.target)
            XCTAssertEqual(restored.found, newer.found)
            XCTAssertEqual(restored.progress, newer.progress, "Original stage recovery must preserve the complete later row and metadata")
            let restoredRow = try exactRow(await fixture.service.coreRead("reading.progress.get", [
                "sourceId": intent.target.sourceId, "bookId": intent.target.bookId
            ]))
            XCTAssertEqual(restoredRow, newerRow, "Including deviceId, timestamps, location/body/processing versions and any future Core fields")
            XCTAssertEqual(restored.progress?.chapterOffset, 10)
            let freshRevision = try XCTUnwrap(restored.progressRevision)
            XCTAssertNotEqual(freshRevision, newer.progressRevision, "A new runtime must fence a pre-reopen progress observer")
            let currentBody = try await fixture.service.content(for: intent.target, chapterIndex: 0)
            let saved = try await fixture.service.saveProgress(for: intent.target, content: currentBody,
                scalarOffset: 11, expectedRevision: freshRevision)
            XCTAssertTrue(saved.found)
            XCTAssertEqual(saved.progress?.sourceId, intent.target.sourceId)
            XCTAssertEqual(saved.progress?.bookId, intent.target.bookId)
            XCTAssertEqual(saved.progress?.chapterOffset, 11)
            XCTAssertEqual(saved.progress?.bodyVersion, currentBody.bodyVersion)
            XCTAssertEqual(saved.progress?.processingVersion, currentBody.processingVersion)
            XCTAssertNotEqual(saved.progressRevision, freshRevision)
            let afterSave = try await fixture.service.progress(for: intent.target)
            XCTAssertEqual(afterSave, saved, "The freshly observed runtime revision must admit and persist a real subsequent save")
            let repeated = try await fixture.service.resumePendingFeatureOperation(intent.operation)
            XCTAssertEqual(repeated.status, .completed, repeated.message ?? heldMethod)
            XCTAssertEqual(fixture.client.count("source.switch.commit"), 0)
            XCTAssertEqual(fixture.client.count("reading.progress.update"), 1, "Only the explicit new save may write progress")
            XCTAssertEqual(fixture.client.count("source.switch.finalize"), heldMethod == "source.switch.finalize" ? 0 : 1)
            XCTAssertEqual(fixture.client.count("source.switch.rollback"), 0)
            let afterRepeat = try await fixture.service.progress(for: intent.target)
            XCTAssertEqual(afterRepeat, afterSave, "Re-reading the original stage ACK cannot overwrite the fresh runtime's later save")
            let pending = try await fixture.service.pendingFeatureOperations()
            XCTAssertFalse(pending.contains { $0.id == intent.operation || $0.id.hasPrefix(intent.operation + ":") })
            XCTAssertEqual(try Data(contentsOf: fixture.input), fixture.original)
            try await fixture.service.close()
        }
    }

    func testColdSwitchRollbackRecoversOriginalStageACKAndRefreshesRestoredRevision() async throws {
        let exactRow: (Data) throws -> Data = { data in
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            object.removeValue(forKey: "progressRevision")
            return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        }
        let fixture = try FeatureRecoveryFixture()
        defer { fixture.cleanUp() }
        let intent = try await fixture.seedOriginalSwitch()
        _ = try await fixture.service.coreMutation("source.switch.commit", intent.parameters,
            operationID: intent.operation, scope: "source-switch")
        let rollbackID = intent.operation + ":rollback"
        fixture.client.hold("source.switch.rollback")
        do {
            _ = try await fixture.service.coreMutation("source.switch.rollback", [
                "transactionId": intent.parameters["operationId"]!,
                "operationId": await fixture.service.coreLineageID(rollbackID, sequence: 1), "sequence": 1
            ], operationID: rollbackID, scope: "source-switch-terminal")
            XCTFail("The actual original rollback ACK is withheld")
        } catch ReaderLibraryError.operationPending(_) {}
        let observed = try await fixture.service.progress(for: intent.original)
        let body = try await fixture.service.content(for: intent.original, chapterIndex: 0)
        _ = try await fixture.service.saveProgress(for: intent.original, content: body, scalarOffset: 30,
            expectedRevision: observed.progressRevision)
        let newer = try await fixture.service.progress(for: intent.original)
        let newerRow = try exactRow(await fixture.service.coreRead("reading.progress.get", [
            "sourceId": intent.original.sourceId, "bookId": intent.original.bookId
        ]))
        try fixture.reopen()
        let recovered = try await fixture.service.resumePendingFeatureOperation(intent.operation)
        XCTAssertEqual(recovered.status, .rejected, recovered.message ?? "rollback receipt missing")
        XCTAssertEqual(fixture.client.count("source.switch.commit"), 0)
        XCTAssertEqual(fixture.client.count("source.switch.rollback"), 0)
        XCTAssertEqual(fixture.client.count("source.switch.finalize"), 0)
        let restored = try await fixture.service.progress(for: intent.original)
        XCTAssertEqual(restored.found, newer.found)
        XCTAssertEqual(restored.progress, newer.progress)
        let restoredRow = try exactRow(await fixture.service.coreRead("reading.progress.get", [
            "sourceId": intent.original.sourceId, "bookId": intent.original.bookId
        ]))
        XCTAssertEqual(restoredRow, newerRow, "Original rollback recovery must preserve the complete later Core row, including all metadata")
        XCTAssertEqual(restored.progress?.chapterOffset, 30)
        let freshRevision = try XCTUnwrap(restored.progressRevision)
        XCTAssertNotEqual(freshRevision, newer.progressRevision, "Core's new-runtime epoch invalidates the old observer, not its persisted row")
        let currentBody = try await fixture.service.content(for: intent.original, chapterIndex: 0)
        let saved = try await fixture.service.saveProgress(for: intent.original, content: currentBody,
            scalarOffset: 31, expectedRevision: freshRevision)
        XCTAssertTrue(saved.found)
        XCTAssertEqual(saved.progress?.sourceId, intent.original.sourceId)
        XCTAssertEqual(saved.progress?.bookId, intent.original.bookId)
        XCTAssertEqual(saved.progress?.chapterOffset, 31)
        XCTAssertEqual(saved.progress?.bodyVersion, currentBody.bodyVersion)
        XCTAssertEqual(saved.progress?.processingVersion, currentBody.processingVersion)
        XCTAssertNotEqual(saved.progressRevision, freshRevision)
        let afterSave = try await fixture.service.progress(for: intent.original)
        XCTAssertEqual(afterSave, saved)
        let repeated = try await fixture.service.resumePendingFeatureOperation(intent.operation)
        XCTAssertEqual(repeated.status, .rejected)
        XCTAssertEqual(fixture.client.count("source.switch.commit"), 0)
        XCTAssertEqual(fixture.client.count("source.switch.rollback"), 0)
        XCTAssertEqual(fixture.client.count("source.switch.finalize"), 0)
        XCTAssertEqual(fixture.client.count("reading.progress.update"), 1, "Only the explicit fresh-revision save may write")
        let afterRepeat = try await fixture.service.progress(for: intent.original)
        XCTAssertEqual(afterRepeat, afterSave, "Repeated original rollback ACK recovery cannot restore over a newer real save")
        let pending = try await fixture.service.pendingFeatureOperations()
        XCTAssertFalse(pending.contains { $0.id == intent.operation || $0.id == rollbackID })
        XCTAssertEqual(try Data(contentsOf: fixture.input), fixture.original)
        try await fixture.service.close()
    }

    func testColdOnlineAdmissionRetainsItsRegisteredOwnerWithoutRedispatchingPreparation() async throws {
        let fixture = try FeatureRecoveryFixture()
        defer { fixture.cleanUp() }
        let local = try await fixture.service.importBook(at: fixture.input).book
        let chapters = try await fixture.service.chapters(for: local)
        let chapter = try XCTUnwrap(chapters.first { $0.title.hasPrefix("第一章") })
        let content = try await fixture.service.content(for: local, chapterIndex: chapter.index)
        let remote = try await fixture.seedCachedRemote(source: "https://reader-recovery-admission.invalid", title: local.title,
            author: local.author, chapterTitle: chapter.title, body: String(content.content.unicodeScalars.prefix(500)))
        let operation = UUID().uuidString
        fixture.client.hold("reading.preparation")
        do {
            _ = try await fixture.service.beginOnlineAdmission(.init(book: remote.book, chapters: [remote.chapter],
                firstReadableIndex: remote.chapter.index), chapterIndex: remote.chapter.index, operationID: operation)
            XCTFail("The genuine preparation terminal is held")
        } catch ReaderLibraryError.operationPending(_) {}
        let recordedOwner = try await fixture.service.onlineAdmissionOwnerID(forCoreOperationID: operation + ":preparation")
        let phaseID = try XCTUnwrap(recordedOwner)
        XCTAssertEqual(phaseID, operation)
        try fixture.reopen()
        let pending = try await fixture.service.pendingFeatureOperations()
        XCTAssertEqual(pending.filter { $0.method == "online.admission" }.map(\.id), [operation])
        XCTAssertFalse(pending.contains { $0.id == operation + ":preparation" })
        let original = try await fixture.service.resumePendingFeatureOperation(operation)
        XCTAssertEqual(original.status, .pending, "Core exposes no exact cold reading.preparation receipt")
        let child = try await fixture.service.resumePendingFeatureOperation(operation + ":preparation")
        XCTAssertEqual(child.operationID, operation)
        XCTAssertEqual(child.status, .pending)
        XCTAssertEqual(fixture.client.count("reading.preparation"), 0)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)
        XCTAssertEqual(try Data(contentsOf: fixture.input), fixture.original)
        try await fixture.service.close()
    }
}

@MainActor
private final class FeatureRecoveryFixture {
    let root: URL
    let input: URL
    let original: Data
    var client: FeatureRecoveryGate
    var service: ReaderLibraryService
    init() throws {
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        input = documents.appendingPathComponent("仙子请听我解释.txt")
        original = try Data(contentsOf: input)
        XCTAssertEqual(original.count, 8_871_723)
        XCTAssertEqual(SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined(),
            "aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5")
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderFeatureRecovery-" + UUID().uuidString)
        let core = root.appendingPathComponent("Core")
        try FileManager.default.createDirectory(at: core, withIntermediateDirectories: true)
        let gate = try FeatureRecoveryGate(storage: core)
        client = gate
        service = try ReaderLibraryService(storageURL: core, sourceURL: root.appendingPathComponent("Sources"), client: gate,
            timing: ReaderRequestTiming(now: { gate.now }, suspend: { await Task.yield() }))
    }
    func reopen() throws {
        client.destroy()
        let gate = try FeatureRecoveryGate(storage: root.appendingPathComponent("Core"))
        client = gate
        service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"), client: gate,
            timing: ReaderRequestTiming(now: { gate.now }, suspend: { await Task.yield() }))
    }
    func seedCachedRemote(source: String, title: String, author: String, chapterTitle: String,
                          body: String) async throws -> (book: ReaderBook, chapter: ReaderChapter) {
        let definition: [String: Any] = ["bookSourceUrl": source, "bookSourceName": "Core恢复方法测试", "bookSourceType": 0, "enabled": true,
            "ruleBookInfo": ["name": "h1@text", "author": "span.author@text", "tocUrl": "a.toc@href"],
            "ruleToc": ["chapterList": "ol.toc li", "chapterName": "a@text", "chapterUrl": "a@href"],
            "ruleContent": ["content": "div.content@html"]]
        let importID = UUID().uuidString
        _ = try await service.rulesMutation("source.import", ["sourceId": source, "bookSource": definition], operationID: importID)
        try await service.finishCoreOperation(importID)
        let bookID = source + "/book/real-downloads"
        _ = try await service.coreRead("book.detail", ["sourceId": source,
            "book": ["bookId": bookID, "title": title, "author": author],
            "detailResponse": "<h1>\(html(title))</h1><span class='author'>\(html(author))</span><a class='toc' href='\(source)/toc'>目录</a>"])
        let tocData = try await service.coreRead("book.toc", ["sourceId": source, "bookId": bookID,
            "tocResponse": "<ol class='toc'><li><a href='\(source)/chapter/0'>\(html(chapterTitle))</a></li></ol>"])
        struct Toc: Decodable { let toc: [ReaderChapter] }
        let chapter = try XCTUnwrap(JSONDecoder().decode(Toc.self, from: tocData).toc.first)
        _ = try await service.coreRead("chapter.content", ["sourceId": source, "bookId": bookID, "chapterIndex": chapter.index,
            "chapterTitle": chapter.title, "chapterUrl": chapter.url, "chapterResponse": "<div class='content'>\(html(body))</div>"])
        return (.init(sourceId: source, bookId: bookID, title: title, author: author, chapterCount: 1), chapter)
    }
    func seedOriginalSwitch() async throws -> (operation: String, parameters: [String: Any], original: ReaderBook, target: ReaderBook) {
        let local = try await service.importBook(at: input).book
        let chapters = try await service.chapters(for: local)
        let chapter = try XCTUnwrap(chapters.first { $0.title.hasPrefix("第一章") })
        let genuine = try await service.content(for: local, chapterIndex: chapter.index)
        let excerpt = String(genuine.content.unicodeScalars.prefix(500))
        let first = try await seedCachedRemote(source: "https://reader-stage-a.invalid", title: local.title,
            author: local.author, chapterTitle: chapter.title, body: excerpt)
        let second = try await seedCachedRemote(source: "https://reader-stage-b.invalid", title: local.title,
            author: local.author, chapterTitle: chapter.title, body: excerpt)
        _ = try await service.beginOnlineAdmission(.init(book: first.book, chapters: [first.chapter], firstReadableIndex: first.chapter.index),
            chapterIndex: first.chapter.index, operationID: UUID().uuidString)
        let body = try await service.content(for: first.book, chapterIndex: first.chapter.index)
        let observed = try await service.progress(for: first.book)
        _ = try await service.saveProgress(for: first.book, content: body, scalarOffset: 20,
            expectedRevision: observed.progressRevision)
        let operation = UUID().uuidString
        let coreID = await service.coreLineageID(operation, sequence: 1)
        return (operation, ["operationId": coreID, "sequence": 1,
            "from": ["sourceId": first.book.sourceId, "bookId": first.book.bookId],
            "target": ["sourceId": second.book.sourceId, "bookId": second.book.bookId, "title": second.book.title, "author": second.book.author],
            "newToc": [["chapterId": second.chapter.url, "chapterTitle": second.chapter.title, "chapterUrl": second.chapter.url, "order": second.chapter.index]],
            "currentChapterTitle": first.chapter.title, "currentChapterIndex": first.chapter.index,
            "updatedAt": Int64(Date().timeIntervalSince1970)], first.book, second.book)
    }

    private func html(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }
    func cleanUp() { client.destroy(); try? FileManager.default.removeItem(at: root) }
}

private final class FeatureRecoveryGate: ReaderCoreEventClient, @unchecked Sendable {
    private let native: ReaderCoreClient
    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    private var parameters: [String: [String: Any]] = [:]
    private var method: String?
    private var heldID: UInt64?
    private var held: Result<ReaderCoreEvent, ReaderCoreClientError>?
    private var clock: TimeInterval = 0
    private var invalidQuery = false
    init(storage: URL) throws { native = try ReaderCoreClient(configJSON: JSONSerialization.data(withJSONObject: ["dataDirectory": storage.path])) }
    var now: TimeInterval { lock.lock(); defer { lock.unlock() }; return clock }
    func count(_ method: String) -> Int { lock.lock(); defer { lock.unlock() }; return counts[method, default: 0] }
    func lastParameters(_ method: String) -> [String: Any]? { lock.lock(); defer { lock.unlock() }; return parameters[method] }
    func hold(_ method: String) { lock.lock(); defer { lock.unlock() }; self.method = method }
    func invalidateNextReceiptQuery() { lock.lock(); defer { lock.unlock() }; invalidQuery = true }
    @discardableResult
    func send(method: String, requestId: UInt64, params: [String: Any]) throws -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        var forwarded = params
        if method == "bookshelf.management.mutation.query", invalidQuery, var expected = params["expected"] as? [String: Any] {
            expected["sequence"] = ((expected["sequence"] as? NSNumber)?.uint64Value ?? 0) + 1
            forwarded["expected"] = expected
            invalidQuery = false
        }
        let id = try native.send(method: method, requestId: requestId, params: forwarded)
        counts[method, default: 0] += 1; parameters[method] = params
        if method == self.method && heldID == nil { heldID = requestId }
        return id
    }
    func pollEvent(requestId: UInt64) -> Result<ReaderCoreEvent, ReaderCoreClientError>? {
        lock.lock(); defer { lock.unlock() }
        guard requestId == heldID else { return native.pollEvent(requestId: requestId) }
        if held == nil, let reply = native.pollEvent(requestId: requestId) {
            if case .success(let event) = reply, ["result", "error"].contains(event.type) { held = reply; clock += 200 }
            else { return reply }
        }
        return nil
    }
    func cancel(requestId: UInt64) throws { lock.lock(); defer { lock.unlock() }; try native.cancel(requestId: requestId) }
    func destroy() { lock.lock(); defer { lock.unlock() }; native.destroy() }
}
