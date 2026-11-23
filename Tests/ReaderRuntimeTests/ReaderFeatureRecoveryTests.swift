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
#if !canImport(ReaderRuntime)
    func testLateNativeDismissalRetiresOnlyTheOriginalConfirmation() async throws {
        let owner = ReaderNativeAlertOwner()
        var actions: [String] = []
        owner.confirm("原确认", message: "原操作") { actions.append("original") }
        let originalID = try XCTUnwrap(owner.request?.id)
        let oldDismissal = try XCTUnwrap(owner.dismissFromPresentation())
        owner.request = nil // The obsolete presentation was explicitly retired.
        owner.confirm("新确认", message: "新操作") { actions.append("replacement") }
        let replacementID = try XCTUnwrap(owner.request?.id)
        XCTAssertNotEqual(originalID, replacementID)
        await oldDismissal.value
        XCTAssertEqual(owner.request?.id, replacementID)
        XCTAssertTrue(actions.isEmpty, "Presentation retirement must not invoke business actions")
        owner.request?.action()
        XCTAssertEqual(actions, ["replacement"])
        let currentDismissal = try XCTUnwrap(owner.dismissFromPresentation())
        await currentDismissal.value
        XCTAssertNil(owner.request)
        XCTAssertNil(owner.dismissFromPresentation())
    }
#endif

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

    func testMatchedSourceSwitchKeepsNonzeroAnchorForIdenticalBodies() async throws {
        let fixture = try FeatureRecoveryFixture.gutenberg()
        defer { fixture.cleanUp() }
        let intent = try await fixture.seedOriginalSwitch(replayTargetCatalog: true)
        let original = try await fixture.service.content(for: intent.original, chapterIndex: 0)
        let before = try await fixture.service.progress(for: intent.original)
        let originalOffset = try XCTUnwrap(before.progress?.chapterOffset)
        XCTAssertEqual(originalOffset, 20)

        let switched = try await fixture.switchSeededBook(from: intent.original, to: intent.target,
            content: original, operationID: intent.operation)
        XCTAssertEqual(switched.content.chapterTitle, original.chapterTitle)
        XCTAssertEqual(Data(switched.content.content.utf8), Data(original.content.utf8))
        let targetOffset = try XCTUnwrap(switched.progressSnapshot.progress?.chapterOffset)
        let status = XCTAttachment(string: "identicalBody=true\nmatchedChapter=\(switched.content.chapterIndex)\noriginalScalar=\(originalOffset)\ntargetScalar=\(targetOffset)")
        status.name = "identical-body-nonzero-source-switch"
        status.lifetime = .keepAlways
        add(status)
        XCTAssertNil(switched.positionNotice)
        try await verifyTargetSwitchPosition(switched, target: intent.target, offset: originalOffset, service: fixture.service)
        try await fixture.service.close()
    }

    func testMatchedSourceSwitchRelocatesUniqueAnchorInChangedBody() async throws {
        let fixture = try FeatureRecoveryFixture.gutenberg()
        defer { fixture.cleanUp() }
        let intent = try await fixture.seedOriginalSwitch(replayTargetCatalog: true) { excerpt in
            String(excerpt.unicodeScalars.dropFirst(250).prefix(80)) + "\n" + excerpt
        }
        let original = try await fixture.service.content(for: intent.original, chapterIndex: 0)
        let switched = try await fixture.switchSeededBook(from: intent.original, to: intent.target,
            content: original, operationID: intent.operation)
        let newText = switched.content.content
        XCTAssertNotEqual(newText, original.content)
        let originalLeadingText = String(original.content.unicodeScalars.prefix(44))
        let insertedPrefix = try XCTUnwrap(newText.range(of: originalLeadingText, options: .literal))
        XCTAssertNil(newText.range(of: originalLeadingText, options: .literal, range: insertedPrefix.upperBound..<newText.endIndex))
        let distance = newText.unicodeScalars.distance(from: newText.unicodeScalars.startIndex, to: insertedPrefix.lowerBound)
        XCTAssertGreaterThan(distance, 0)
        XCTAssertNil(switched.positionNotice)
        try await verifyTargetSwitchPosition(switched, target: intent.target, offset: UInt64(distance) + 20, service: fixture.service)
        try await fixture.service.close()
    }

    func testMatchedSourceSwitchUsesChapterStartForAmbiguousAnchor() async throws {
        let fixture = try FeatureRecoveryFixture.gutenberg()
        defer { fixture.cleanUp() }
        let intent = try await fixture.seedOriginalSwitch(replayTargetCatalog: true) { excerpt in
            excerpt + "\n" + excerpt
        }
        let original = try await fixture.service.content(for: intent.original, chapterIndex: 0)
        let switched = try await fixture.switchSeededBook(from: intent.original, to: intent.target,
            content: original, operationID: intent.operation)
        let newText = switched.content.content
        XCTAssertNotEqual(newText, original.content)
        let originalLeadingText = String(original.content.unicodeScalars.prefix(44))
        let first = try XCTUnwrap(newText.range(of: originalLeadingText, options: .literal))
        XCTAssertNotNil(newText.range(of: originalLeadingText, options: .literal, range: first.upperBound..<newText.endIndex))
        XCTAssertEqual(switched.positionNotice, "无法在新书源确认原阅读位置，已从匹配章节的开头继续。")
        try await verifyTargetSwitchPosition(switched, target: intent.target, offset: 0, service: fixture.service)
        try await fixture.service.close()
    }

    func testColdMatchedSourceSwitchRecoversOriginalCommitACKAndKeepsAnchor() async throws {
        try await verifyColdMatchedSourceSwitch(holdingCanonicalACK: false)
    }

    func testColdMatchedSourceSwitchRecoversOriginalCanonicalACKAndKeepsAnchor() async throws {
        try await verifyColdMatchedSourceSwitch(holdingCanonicalACK: true)
    }

    private func verifyTargetSwitchPosition(_ switched: ReaderOnlineSwitchResult, target: ReaderBook,
                                            offset: UInt64, service: ReaderLibraryService) async throws {
        XCTAssertEqual(switched.book.id, target.id)
        XCTAssertEqual(switched.content.sourceId, target.sourceId)
        XCTAssertEqual(switched.content.bookId, target.bookId)
        XCTAssertEqual(switched.content.chapterIndex, 0)
        let progress = try XCTUnwrap(switched.progressSnapshot.progress)
        XCTAssertTrue(switched.progressSnapshot.found)
        XCTAssertEqual(progress.sourceId, target.sourceId)
        XCTAssertEqual(progress.bookId, target.bookId)
        XCTAssertEqual(progress.chapterIndex, switched.content.chapterIndex)
        XCTAssertEqual(progress.chapterOffset, offset)
        XCTAssertEqual(progress.chapterProgress, Double(offset) / Double(switched.content.scalarCount), accuracy: 0.000_001)
        XCTAssertEqual(progress.bodyVersion, try XCTUnwrap(switched.content.bodyVersion))
        XCTAssertEqual(progress.processingVersion, try XCTUnwrap(switched.content.processingVersion))
        let persisted = try await service.progress(for: target)
        XCTAssertEqual(persisted, switched.progressSnapshot)
    }

    private func verifyColdMatchedSourceSwitch(holdingCanonicalACK: Bool) async throws {
        let fixture = try FeatureRecoveryFixture.gutenberg()
        defer { fixture.cleanUp() }
        let intent = try await fixture.seedOriginalSwitch(replayTargetCatalog: true)
        let original = try await fixture.service.content(for: intent.original, chapterIndex: 0)
        let before = try await fixture.service.progress(for: intent.original)
        XCTAssertEqual(before.progress?.chapterOffset, 20)
        let heldMethod = holdingCanonicalACK ? "reading.progress.update" : "source.switch.commit"
        let priorWrites = fixture.client.count("reading.progress.update")
        fixture.client.hold(heldMethod)
        do {
            _ = try await fixture.switchSeededBook(from: intent.original, to: intent.target,
                content: original, operationID: intent.operation)
            XCTFail("The actual Core terminal for \(heldMethod) was withheld")
        } catch ReaderLibraryError.operationPending(let operationID) {
            XCTAssertEqual(operationID, intent.operation)
        }
        XCTAssertEqual(fixture.client.count("source.switch.commit"), 1)
        XCTAssertEqual(fixture.client.count("source.switch.finalize"), 0)
        XCTAssertEqual(fixture.client.count("reading.progress.update"), priorWrites + (holdingCanonicalACK ? 1 : 0))
        let commit = try XCTUnwrap(fixture.client.lastParameters("source.switch.commit"))
        let transactionID = try XCTUnwrap(commit["operationId"] as? String)
        let held = try XCTUnwrap(fixture.client.terminal)
        XCTAssertEqual(held.type, "result")
        let terminal = try XCTUnwrap(held.data)
        XCTAssertEqual(terminal["transactionId"] as? String, transactionID)
        let originalCanonical: [String: Any]?
        if holdingCanonicalACK {
            originalCanonical = try XCTUnwrap(fixture.client.lastParameters("reading.progress.update"))
            XCTAssertEqual((originalCanonical?["chapterOffset"] as? NSNumber)?.uint64Value, 20)
            XCTAssertEqual((terminal["chapterOffset"] as? NSNumber)?.uint64Value, 20)
            XCTAssertEqual(terminal["sourceSwitchFinalized"] as? Bool, true)
        } else {
            originalCanonical = nil
            XCTAssertEqual(terminal["phase"] as? String, "pending")
        }

        try fixture.reopen()
        let recovered = try await fixture.service.resumePendingFeatureOperation(intent.operation)
        XCTAssertEqual(recovered.status, .completed, recovered.message ?? heldMethod)
        XCTAssertEqual(fixture.client.count("source.switch.commit"), 0)
        XCTAssertEqual(fixture.client.count("reading.progress.update"), holdingCanonicalACK ? 0 : 1)
        XCTAssertEqual(fixture.client.count("source.switch.finalize"), 1)
        XCTAssertEqual(fixture.client.count("source.switch.rollback"), 0)
        XCTAssertEqual(fixture.client.count("book.detail"), 0)
        XCTAssertEqual(fixture.client.count("book.toc"), 0)
        if let originalCanonical {
            let queried = try XCTUnwrap(fixture.client.canonicalQuery)
            XCTAssertEqual(try JSONSerialization.data(withJSONObject: queried, options: .sortedKeys),
                           try JSONSerialization.data(withJSONObject: originalCanonical, options: .sortedKeys))
        }
        let body = try await fixture.service.content(for: intent.target, chapterIndex: 0)
        XCTAssertEqual(Data(body.content.utf8), Data(original.content.utf8))
        let position = try await fixture.service.progress(for: intent.target)
        try await verifyTargetSwitchPosition(.init(book: intent.target, content: body, progressSnapshot: position),
            target: intent.target, offset: 20, service: fixture.service)

        let later = try await fixture.service.saveProgress(for: intent.target, content: body, scalarOffset: 31,
            expectedRevision: position.progressRevision)
        XCTAssertEqual(later.progress?.chapterOffset, 31)
        let repeated = try await fixture.service.resumePendingFeatureOperation(intent.operation)
        XCTAssertEqual(repeated.status, .completed, repeated.message ?? heldMethod)
        XCTAssertEqual(fixture.client.count("source.switch.commit"), 0)
        XCTAssertEqual(fixture.client.count("reading.progress.update"), holdingCanonicalACK ? 1 : 2)
        XCTAssertEqual(fixture.client.count("source.switch.finalize"), 1)
        let positionAfterRepeat = try await fixture.service.progress(for: intent.target)
        XCTAssertEqual(positionAfterRepeat, later)
        if let originalCanonical {
            let data = try await fixture.service.coreRead("source.switch.transaction.query", [
                "operationId": transactionID, "expectedCanonical": originalCanonical
            ])
            let query = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let transaction = try XCTUnwrap(query["transaction"] as? [String: Any])
            let originalReceipt = try XCTUnwrap(transaction["canonicalProgress"] as? [String: Any])
            XCTAssertEqual(try JSONSerialization.data(withJSONObject: originalReceipt, options: .sortedKeys),
                           try JSONSerialization.data(withJSONObject: terminal, options: .sortedKeys))
        }
        try await fixture.service.close()
    }

    func testColdSwitchRollbackRecoversOriginalStageACKAndRefreshesRestoredRevision() async throws {
        try await verifyColdSwitchRollback(FeatureRecoveryFixture(), checkInitialRestoration: false)
    }

    /// Uses an unchanged public original through the real Core, with
    /// isolated surrogate sources and an intentionally withheld transport ACK.
    func testColdSwitchRollbackWithGutenbergOriginalRestoresExactBodyAndPosition() async throws {
        let fixture = try FeatureRecoveryFixture(name: "pg25332.txt", bytes: 99_898,
            digest: "997442c1d041cc731d57bd164078a1dd6e98a5fe0eb9b6ec8b202edc3d0a5a38")
        try await verifyColdSwitchRollback(fixture, checkInitialRestoration: true)
    }

    private func verifyColdSwitchRollback(_ fixture: FeatureRecoveryFixture, checkInitialRestoration: Bool) async throws {
        let exactRow: (Data) throws -> Data = { data in
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            object.removeValue(forKey: "progressRevision")
            return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        }
        defer { fixture.cleanUp() }
        let intent = try await fixture.seedOriginalSwitch()
        let identifiers = ["sourceId": intent.original.sourceId, "bookId": intent.original.bookId]
        var beforeRollback: (body: ReaderChapterContent, position: Data)?
        if checkInitialRestoration {
            let body = try await fixture.service.content(for: intent.original, chapterIndex: 0)
            XCTAssertGreaterThan(body.scalarCount, 31)
            let position = try exactRow(await fixture.service.coreRead("reading.progress.get", identifiers))
            beforeRollback = (body, position)
        }
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
        if let beforeRollback {
            let terminal = try XCTUnwrap(fixture.client.terminal, "Hold an actual Core terminal rather than injecting a result")
            let receipt = try XCTUnwrap(terminal.data)
            let restoredBook = try XCTUnwrap(receipt["restoredBook"] as? [String: Any])
            XCTAssertEqual(terminal.type, "result")
            XCTAssertEqual(receipt["phase"] as? String, "rolledBack")
            XCTAssertEqual(receipt["transactionId"] as? String, intent.parameters["operationId"] as? String)
            XCTAssertEqual(receipt["changed"] as? Bool, true)
            XCTAssertEqual(restoredBook["sourceId"] as? String, intent.original.sourceId)
            XCTAssertEqual(restoredBook["bookId"] as? String, intent.original.bookId)
            XCTAssertEqual(body, beforeRollback.body)
            XCTAssertEqual(observed.progress?.chapterOffset, 20)
            let restoredPosition = try exactRow(await fixture.service.coreRead("reading.progress.get", identifiers))
            XCTAssertEqual(restoredPosition, beforeRollback.position, "The original rollback restores the complete pre-switch position")
            let shelf = try await fixture.service.listBooks()
            XCTAssertTrue(shelf.contains { $0.id == intent.original.id })
            XCTAssertFalse(shelf.contains { $0.id == intent.target.id })
        }
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
        if let beforeRollback { XCTAssertEqual(currentBody, beforeRollback.body) }
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
    static func gutenberg() throws -> FeatureRecoveryFixture {
        try FeatureRecoveryFixture(name: "pg25332.txt", bytes: 99_898,
            digest: "997442c1d041cc731d57bd164078a1dd6e98a5fe0eb9b6ec8b202edc3d0a5a38")
    }
    init(name: String = "仙子请听我解释.txt", bytes: Int = 8_871_723,
         digest: String = "aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5") throws {
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        input = documents.appendingPathComponent(name)
        original = try Data(contentsOf: input)
        XCTAssertEqual(original.count, bytes)
        XCTAssertEqual(SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined(), digest)
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
                          body: String, replayCatalog: Bool = false) async throws -> (book: ReaderBook, chapter: ReaderChapter) {
        let definition: [String: Any] = ["bookSourceUrl": source, "bookSourceName": "Core恢复方法测试", "bookSourceType": 0, "enabled": true,
            "ruleBookInfo": ["name": "h1@text", "author": "span.author@text", "tocUrl": "a.toc@href"],
            "ruleToc": ["chapterList": "ol.toc li", "chapterName": "a@text", "chapterUrl": "a@href"],
            "ruleContent": ["content": "div.content@html"]]
        let importID = UUID().uuidString
        _ = try await service.rulesMutation("source.import", ["sourceId": source, "bookSource": definition], operationID: importID)
        try await service.finishCoreOperation(importID)
        let bookID = source + "/book/real-downloads"
        let detailResponse = "<h1>\(html(title))</h1><span class='author'>\(html(author))</span><a class='toc' href='\(source)/toc'>目录</a>"
        let tocResponse = "<ol class='toc'><li><a href='\(source)/chapter/0'>\(html(chapterTitle))</a></li></ol>"
        _ = try await service.coreRead("book.detail", ["sourceId": source,
            "book": ["bookId": bookID, "title": title, "author": author],
            "detailResponse": detailResponse])
        let tocData = try await service.coreRead("book.toc", ["sourceId": source, "bookId": bookID,
            "tocResponse": tocResponse])
        struct Toc: Decodable { let toc: [ReaderChapter] }
        let chapter = try XCTUnwrap(JSONDecoder().decode(Toc.self, from: tocData).toc.first)
        _ = try await service.coreRead("chapter.content", ["sourceId": source, "bookId": bookID, "chapterIndex": chapter.index,
            "chapterTitle": chapter.title, "chapterUrl": chapter.url, "chapterResponse": "<div class='content'>\(html(body))</div>"])
        if replayCatalog { client.replayCatalog(sourceID: source, bookID: bookID, detail: detailResponse, toc: tocResponse) }
        return (.init(sourceId: source, bookId: bookID, title: title, author: author, chapterCount: 1), chapter)
    }
    func seedOriginalSwitch(replayTargetCatalog: Bool = false, targetBody: (String) -> String = { $0 }) async throws
        -> (operation: String, parameters: [String: Any], original: ReaderBook, target: ReaderBook) {
        let local = try await service.importBook(at: input).book
        let chapters = try await service.chapters(for: local)
        let chapter = try XCTUnwrap(chapters.first { $0.title.hasPrefix("第一章") })
        let genuine = try await service.content(for: local, chapterIndex: chapter.index)
        let excerpt = String(genuine.content.unicodeScalars.prefix(500))
        let first = try await seedCachedRemote(source: "https://reader-stage-a.invalid", title: local.title,
            author: local.author, chapterTitle: chapter.title, body: excerpt)
        let second = try await seedCachedRemote(source: "https://reader-stage-b.invalid", title: local.title,
            author: local.author, chapterTitle: chapter.title, body: targetBody(excerpt), replayCatalog: replayTargetCatalog)
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

    func switchSeededBook(from original: ReaderBook, to target: ReaderBook, content: ReaderChapterContent,
                          operationID: String) async throws -> ReaderOnlineSwitchResult {
        try await service.switchOnlineBook(from: original, currentChapterIndex: content.chapterIndex,
            currentChapterTitle: content.chapterTitle, candidate: .init(sourceId: target.sourceId, bookId: target.bookId,
                title: target.title, author: target.author), operationID: operationID)
    }

    private func html(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }
    func cleanUp() { client.destroy(); try? FileManager.default.removeItem(at: root) }
}

private final class FeatureRecoveryGate: ReaderHeldTerminalClient, @unchecked Sendable {
    private var invalidQuery = false
    private var catalog: (sourceID: String, bookID: String, detail: String, toc: String)?
    private var queriedCanonical: [String: Any]?
    var canonicalQuery: [String: Any]? { withHeldLock { queriedCanonical } }
    init(storage: URL) throws {
        super.init(base: try ReaderCoreClient(configJSON: JSONSerialization.data(withJSONObject: ["dataDirectory": storage.path])))
    }
    func invalidateNextReceiptQuery() { withHeldLock { invalidQuery = true } }
    // Only supply the private target's saved HTTP input. Core still performs
    // the real detail, catalog, chapter, and source-switch operations.
    func replayCatalog(sourceID: String, bookID: String, detail: String, toc: String) {
        withHeldLock { catalog = (sourceID, bookID, detail, toc) }
    }
    override func forwardedParameters(method: String, params: [String: Any]) -> [String: Any] {
        var forwarded = params
        if method == "source.switch.transaction.query", let expected = params["expectedCanonical"] as? [String: Any] {
            queriedCanonical = expected
        }
        if method == "bookshelf.management.mutation.query", invalidQuery, var expected = params["expected"] as? [String: Any] {
            expected["sequence"] = ((expected["sequence"] as? NSNumber)?.uint64Value ?? 0) + 1
            forwarded["expected"] = expected
            invalidQuery = false
        }
        if let catalog, params["sourceId"] as? String == catalog.sourceID {
            switch method {
            case "book.detail" where (params["book"] as? [String: Any])?["bookId"] as? String == catalog.bookID
                && params["detailResponse"] == nil:
                forwarded["detailResponse"] = catalog.detail
            case "book.toc" where params["bookId"] as? String == catalog.bookID && params["tocResponse"] == nil:
                forwarded["tocResponse"] = catalog.toc
            default: break
            }
        }
        return forwarded
    }
}
