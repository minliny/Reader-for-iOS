import CryptoKit
import Foundation
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
final class ReaderDownloadReceiptTests: XCTestCase {
    /// Controlled Core presentation DTOs, not generated novels or a source
    /// acceptance test. Exercise the actual cached-catalog consumer as well as
    /// direct TOC/directory/download decoding, including explicit false flags.
    func testChapterPresentationSurvivesCachedCatalogWithoutChangingNavigationOrDownloadState() async throws {
        let flags: [(Bool?, Bool?)] = [(nil, nil), (false, nil), (true, nil),
            (nil, false), (nil, true), (false, false), (false, true), (true, false), (true, true)]
        var rows: [[String: Any]] = []
        for (index, values) in flags.enumerated() {
            var facts: [String: Any] = ["displayTitle": "１０１（上）", "contextTitle": "卷一"]
            if let vip = values.0 { facts["isVip"] = vip }
            if let paid = values.1 { facts["isPay"] = paid }
            let title = "正文", url = "https://example.invalid/chapter/\(index)"
            var toc = facts
            toc.merge(["index": index, "title": title, "url": url, "level": 2]) { _, new in new }
            let chapter = try JSONDecoder().decode(ReaderChapter.self, from: downloadCanonical(toc))
            XCTAssertEqual(chapter.index, UInt32(index)); XCTAssertEqual(chapter.id, UInt32(index))
            XCTAssertEqual(chapter.title, title); XCTAssertEqual(chapter.url, url); XCTAssertEqual(chapter.level, 2)
            XCTAssertEqual(chapter.displayTitle, "１０１（上）"); XCTAssertEqual(chapter.contextTitle, "卷一")
            XCTAssertEqual(chapter.isVip, values.0); XCTAssertEqual(chapter.isPay, values.1)
            let roundTrip = try JSONDecoder().decode(ReaderChapter.self, from: JSONEncoder().encode(chapter))
            XCTAssertEqual(roundTrip, chapter, "Explicit false and absent source facts must stay distinct")

            var node = facts
            node.merge(["nodeId": "node-\(index)", "depth": 1, "title": title, "kind": "target",
                "chapterIndex": index, "chapterOffsetScalar": 0, "hasChildren": false, "expanded": true]) { _, new in new }
            let directory = try JSONDecoder().decode(ReaderDirectoryNode.self, from: downloadCanonical(node))
            XCTAssertEqual(directory.id, "node-\(index)"); XCTAssertEqual(directory.chapterIndex, UInt32(index))
            XCTAssertEqual(directory.title, title); XCTAssertEqual(directory.displayTitle, chapter.displayTitle)
            XCTAssertEqual(directory.contextTitle, chapter.contextTitle)
            XCTAssertEqual(directory.isVip, values.0); XCTAssertEqual(directory.isPay, values.1)
            XCTAssertTrue(directory.navigable, "Source access labels are not a navigation authorization")
            node["kind"] = "group"; node.removeValue(forKey: "chapterIndex")
            XCTAssertFalse(try JSONDecoder().decode(ReaderDirectoryNode.self, from: downloadCanonical(node)).navigable)

            var cached = facts
            cached.merge(["chapterIndex": index, "title": title, "url": url, "level": 2,
                "navigable": true, "state": "completed", "attempts": 1, "maxAttempts": 3, "cachedBytes": 1]) { _, new in new }
            let download = try JSONDecoder().decode(ReaderDownloadChapter.self, from: downloadCanonical(cached))
            XCTAssertEqual(download.id, UInt32(index)); XCTAssertEqual(download.title, title)
            XCTAssertEqual(download.displayTitle, chapter.displayTitle); XCTAssertEqual(download.contextTitle, chapter.contextTitle)
            XCTAssertEqual(download.isVip, values.0); XCTAssertEqual(download.isPay, values.1)
            XCTAssertEqual(download.state, .completed); XCTAssertEqual(download.navigable, true)
            rows.append(cached)
        }
        rows.append(["chapterIndex": 99, "title": "卷二", "url": "", "navigable": false,
            "state": "missing", "isVip": true, "isPay": false])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderChapterPresentation-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let client = DownloadInventoryReplyFixture(pages: [["chapters": rows]], readMethod: "cache.book.status")
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
            sourceURL: root.appendingPathComponent("Sources"), client: client, timing: .live)
        let book = ReaderBook(sourceId: "method-source", bookId: "method-book", title: "Controlled metadata")
        let catalog = try await service.onlineChapters(for: book)
        XCTAssertEqual(catalog.map(\.index), Array(UInt32(0)..<UInt32(flags.count)), "Non-navigable groups remain excluded")
        for (chapter, values) in zip(catalog, flags) {
            XCTAssertEqual(chapter.title, "正文"); XCTAssertEqual(chapter.displayTitle, "１０１（上）")
            XCTAssertEqual(chapter.contextTitle, "卷一"); XCTAssertEqual(chapter.level, 2)
            XCTAssertEqual(chapter.isVip, values.0); XCTAssertEqual(chapter.isPay, values.1)
        }
        XCTAssertEqual(client.inventoryParameters.count, 1)
        XCTAssertEqual(client.inventoryParameters.first?["sourceId"] as? String, book.sourceId)
        XCTAssertEqual(client.inventoryParameters.first?["bookId"] as? String, book.bookId)
        try await service.close()
        #if !canImport(ReaderRuntime)
        XCTAssertNil(ReaderChapterSourceLabel.text(isVip: nil, isPay: nil))
        XCTAssertNil(ReaderChapterSourceLabel.text(isVip: false, isPay: false), "Unknown/free access must not be inferred")
        XCTAssertEqual(ReaderChapterSourceLabel.text(isVip: true, isPay: nil), "VIP")
        XCTAssertEqual(ReaderChapterSourceLabel.text(isVip: true, isPay: false), "VIP · 未购")
        XCTAssertEqual(ReaderChapterSourceLabel.text(isVip: true, isPay: true), "VIP · 已购")
        XCTAssertEqual(ReaderChapterSourceLabel.text(isVip: nil, isPay: true), "已购")
        #endif
    }

    /// Controlled protocol pages cover the Host consumer only. These identities
    /// are metadata fixtures, not real books, source usability or UI evidence.
    func testDownloadInventoryConsumesExactKeysetPagesAndRejectsIncoherentIdentityWithoutAssumingText() async throws {
        func item(_ source: String, _ book: String, kind: String = "text") -> [String: Any] {
            ["sourceId": source, "bookId": book, "onShelf": false, "sourceConfigured": false,
             "metadataSource": "unknown", "contentKind": kind, "contentKindSource": "unknown",
             "taskCount": 1, "queuedCount": 0, "inProgressCount": 0, "pausedCount": 0,
             "completedCount": 0, "failedCount": 1, "cancelledCount": 0, "latestUpdatedAt": 3]
        }
        func page(_ values: [[String: Any]], cursor: [String: String]? = nil) throws -> ReaderDownloadBooksPage {
            var object: [String: Any] = ["items": values, "hasMore": cursor != nil]
            if let cursor { object["nextCursor"] = cursor }
            return try JSONDecoder().decode(ReaderDownloadBooksPage.self, from: JSONSerialization.data(withJSONObject: object))
        }
        let first = item("a|b", "c", kind: "unknown")
        let second = item("a", "b|c", kind: "manga")
        // BINARY source key order is a, a|b. Ambiguous flat pipe identities
        // must still be separate entries and separate native row identifiers.
        let pages: [[String: Any]] = [
            ["items": [second], "hasMore": true, "nextCursor": ["sourceId": "a", "bookId": "b|c"]],
            ["items": [first], "hasMore": false]
        ]
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderDownloadInventory-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let client = DownloadInventoryReplyFixture(pages: pages)
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
            sourceURL: root.appendingPathComponent("Sources"), client: client, timing: .live)
        let inventory = try await service.readerDownloadBooks()
        XCTAssertEqual(inventory.count, 2)
        XCTAssertNotEqual(inventory[0].id, inventory[1].id)
        XCTAssertNotEqual(inventory[0].id.accessibilityKey, inventory[1].id.accessibilityKey)
        XCTAssertTrue(inventory.allSatisfy { !$0.onShelf && !$0.supportsTextControls })
        XCTAssertEqual(inventory.map(\.contentKind), ["manga", "unknown"])
        XCTAssertNil(inventory[0].title)
        XCTAssertEqual(inventory[0].displayTitle, "b|c")
        XCTAssertEqual(inventory[0].controlBook.bookId, "b|c")
        XCTAssertTrue(try page([item("z", "text-book")]).items[0].supportsTextControls)
        let parameters = client.inventoryParameters
        XCTAssertEqual(parameters.count, 2)
        XCTAssertNil(parameters[0]["after"])
        XCTAssertEqual((parameters[1]["after"] as? [String: String]), ["sourceId": "a", "bookId": "b|c"])
        XCTAssertTrue(parameters.allSatisfy { ($0["limit"] as? UInt32) == 50 && $0["operationId"] == nil })
        let pending = try await service.pendingCoreCommands()
        XCTAssertTrue(pending.isEmpty)

        let key = ReaderDownloadBookCursor(sourceId: "a|b", bookId: "c")
        XCTAssertThrowsError(try page([first, first]).validate(after: nil, limit: 50))
        XCTAssertThrowsError(try page([first]).validate(after: key, limit: 50), "Repeated cursor must never loop")
        XCTAssertThrowsError(try page([first, second]).validate(after: nil, limit: 50), "BINARY order must advance")
        XCTAssertThrowsError(try page([first], cursor: ["sourceId": "wrong", "bookId": "c"]).validate(after: nil, limit: 50))
        XCTAssertThrowsError(try page([], cursor: ["sourceId": "a", "bookId": "b"]).validate(after: nil, limit: 50))
        let finalWithCursor = try JSONDecoder().decode(ReaderDownloadBooksPage.self, from: JSONSerialization.data(withJSONObject: [
            "items": [first], "hasMore": false, "nextCursor": ["sourceId": "a|b", "bookId": "c"]
        ]))
        XCTAssertThrowsError(try finalWithCursor.validate(after: nil, limit: 50))
        var overflow = first
        overflow["taskCount"] = UInt64.max; overflow["queuedCount"] = UInt64.max
        XCTAssertThrowsError(try page([overflow]).validate(after: nil, limit: 50))
        var incoherent = first; incoherent["taskCount"] = 2
        XCTAssertThrowsError(try page([incoherent]).validate(after: nil, limit: 50))
        let composed = ReaderDownloadBookCursor(sourceId: "\u{00e9}", bookId: "same")
        let decomposed = ReaderDownloadBookCursor(sourceId: "e\u{0301}", bookId: "same")
        XCTAssertNotEqual(composed, decomposed, "SQLite BINARY keys preserve original UTF-8")
        XCTAssertTrue(decomposed.precedes(composed))
        var firstUnicode = item(composed.sourceId, "same"); firstUnicode["sourceName"] = "Composed source"
        var secondUnicode = item(decomposed.sourceId, "same"); secondUnicode["sourceName"] = "Decomposed source"
        let unicodeItems = try page([secondUnicode, firstUnicode]).items
        let presentation = ReaderDownloadManagementPresentation()
        let options = presentation.sourceOptions(unicodeItems)
        XCTAssertEqual(options.count, 2, "Source options must preserve SQLite BINARY identities too")
        XCTAssertEqual(options.map(\.title), ["Decomposed source", "Composed source"])
        XCTAssertNotEqual(options[0].id, options[1].id)
        for option in options {
            presentation.sourceKey = option.id
            let selected = presentation.visible(unicodeItems)
            XCTAssertEqual(selected.count, 1)
            XCTAssertEqual(selected.first?.id, ReaderDownloadBookCursor(sourceId: option.sourceId, bookId: "same"))
        }
        try await service.close()
    }

    /// Controlled Core terminals exercise only Host payload/owner handling.
    /// Real Core task transitions are covered by cache_download_receipts.rs;
    /// no source, HTTP response, production library or device is used here.
    func testResumeAcquisitionFreezesOriginalBindingAndConsumesOnlyExactNonExecution() async throws {
        for reason in [nil, "resume_superseded", "resume_unproven", "unrelated_rejection"] as [String?] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderResumeBinding-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let client = ResumeAcquisitionReplyFixture(rejection: reason)
            let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
                sourceURL: root.appendingPathComponent("Sources"), client: client, timing: .live)
            let book = ReaderBook(sourceId: "method-source", bookId: "method-book", title: "Host method boundary")
            let operationID = UUID().uuidString
            let shouldRemainPending = reason == "unrelated_rejection"
            do {
                let result = try await service.resumeDownload(book, chapterIndex: 0, operationID: operationID)
                XCTAssertFalse(shouldRemainPending)
                XCTAssertEqual(result.status, "failed", "A child disposition cannot replace the historical resume ACK")
            } catch {
                XCTAssertTrue(shouldRemainPending, String(describing: error))
            }
            let acquired = try XCTUnwrap(client.parameters("cache.book.prefetch"))
            let expected = try XCTUnwrap(acquired["expectedResume"] as? [String: Any])
            let settled = try XCTUnwrap(client.parameters("cache.download.operation.settle", action: "resume"))
            for key in ["operationId", "sequence", "payloadFingerprint"] {
                XCTAssertEqual(try downloadCanonical(expected[key]!), try downloadCanonical(settled[key]!))
            }
            let original = try await service.acknowledgedCoreCommand(operationID: operationID,
                method: "cache.download.resume", scope: "download-resume:" + book.id + ":0")
            XCTAssertEqual(try downloadCanonical(JSONSerialization.jsonObject(with: original.result)),
                           try downloadCanonical(client.resumeACK))
            let pending = try await service.pendingCoreCommands()
            XCTAssertEqual(pending.map(\.id), shouldRemainPending ? [operationID] : [])
            let beforeReplay = client.count("cache.book.prefetch")
            do { _ = try await service.resumeDownload(book, chapterIndex: 0, operationID: operationID) }
            catch { XCTAssertTrue(shouldRemainPending) }
            XCTAssertEqual(client.count("cache.book.prefetch"), beforeReplay)
            let frozenAcquisition = try await service.existingCoreParameters(operationID: operationID + ":acquire", method: "cache.book.prefetch")
            XCTAssertEqual(try downloadCanonical(XCTUnwrap(frozenAcquisition)), try downloadCanonical(acquired))
            try await service.close()
            let coldClient = ResumeAcquisitionReplyFixture(rejection: nil)
            let reopened = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
                sourceURL: root.appendingPathComponent("Sources"), client: coldClient, timing: .live)
            do { _ = try await reopened.resumeDownload(book, chapterIndex: 0, operationID: operationID) }
            catch { XCTAssertTrue(shouldRemainPending) }
            XCTAssertEqual(coldClient.totalSends, 0, "Cold replay must consume retained original receipts, including a retained child rejection")
            let coldOriginal = try await reopened.acknowledgedCoreCommand(operationID: operationID,
                method: "cache.download.resume", scope: "download-resume:" + book.id + ":0")
            XCTAssertEqual(coldOriginal.result, original.result)
            try await reopened.close()
        }
    }

    func testLegacyResumeAndAcquisitionJournalsNeverInventBindingOrRedispatchUnknownChild() async throws {
        let book = ReaderBook(sourceId: "method-source", bookId: "method-book", title: "Host legacy boundary")
        for pendingChild in [false, true] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderLegacyAcquire-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let client = ResumeAcquisitionReplyFixture(rejection: nil, pendingPrefetch: pendingChild)
            let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
                sourceURL: root.appendingPathComponent("Sources"), client: client, timing: .live)
            let operationID = UUID().uuidString
            do { _ = try await service.downloadChapters(book, range: 0..<1, operationID: operationID + ":acquire") }
            catch { XCTAssertTrue(pendingChild) }
            let oldParameters = try await service.existingCoreParameters(operationID: operationID + ":acquire", method: "cache.book.prefetch")
            let old = try XCTUnwrap(oldParameters)
            XCTAssertNil(old["expectedResume"])
            do { _ = try await service.resumeDownload(book, chapterIndex: 0, operationID: operationID) }
            catch { XCTAssertTrue(pendingChild) }
            XCTAssertEqual(client.count("cache.book.prefetch"), 1)
            let replayedParameters = try await service.existingCoreParameters(operationID: operationID + ":acquire", method: "cache.book.prefetch")
            let replayed = try XCTUnwrap(replayedParameters)
            XCTAssertEqual(try downloadCanonical(old), try downloadCanonical(replayed), "Never retrofit a grant into an old accepted child")
            try await service.close()
        }
        // Persist the exact old unbound Host format. Its successful old ACK
        // remains an ACK, but cannot authorize creating a fresh acquisition.
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderUnboundResume-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let operationID = UUID().uuidString
        let directory = root.appendingPathComponent("Sources/.operations/commands")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let parameters = try JSONSerialization.data(withJSONObject: ["sourceId": book.sourceId, "bookId": book.bookId, "chapterIndex": 0], options: [.sortedKeys])
        let ack = try JSONSerialization.data(withJSONObject: ["sourceId": book.sourceId, "bookId": book.bookId, "chapterIndex": 0, "status": "pending", "attempts": 0, "maxAttempts": 3])
        let bytes = try JSONSerialization.data(withJSONObject: ["id": operationID, "method": "cache.download.resume",
            "scope": "download-resume:" + book.id + ":0", "parameters": parameters.base64EncodedString(),
            "result": ack.base64EncodedString(), "completed": false], options: [.sortedKeys])
        let name = SHA256.hash(data: Data(operationID.utf8)).map { String(format: "%02x", $0) }.joined() + ".json"
        let file = directory.appendingPathComponent(name)
        try bytes.write(to: file)
        let client = ResumeAcquisitionReplyFixture(rejection: nil)
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
            sourceURL: root.appendingPathComponent("Sources"), client: client, timing: .live)
        let actions = ReaderLibraryActionOwner()
        actions.pendingChecker = { id in
            do { return try await service.pendingCoreCommands().contains { $0.id == id } }
            catch { return nil }
        }
        XCTAssertTrue(actions.restoreAccepted(id: operationID, label: "更改下载任务", scope: book.id) { id in
            _ = try await service.resumeDownload(book, chapterIndex: 0, operationID: id)
        })
        let resumed = await actions.resumeOriginal()
        XCTAssertFalse(resumed, "The historical ACK does not mean a new download was started")
        XCTAssertFalse(actions.hasPending, "A confirmed legacy parent must not hold an impossible recovery owner")
        XCTAssertTrue(actions.feedback?.contains("请重新选择继续或下载章节") == true)
        XCTAssertEqual(client.totalSends, 0)
        let completed = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        XCTAssertEqual(completed["completed"] as? Bool, true)
        XCTAssertEqual(completed["parameters"] as? String, parameters.base64EncodedString())
        XCTAssertEqual(completed["result"] as? String, ack.base64EncodedString(), "Retain the original ACK without fabricating acquisition")
        let child = try await service.existingCoreParameters(operationID: operationID + ":acquire", method: "cache.book.prefetch")
        XCTAssertNil(child)
        let pending = try await service.pendingCoreCommands()
        XCTAssertTrue(pending.isEmpty)
        let retained = try Data(contentsOf: file)
        try await service.close()
        let coldClient = ResumeAcquisitionReplyFixture(rejection: nil)
        let reopened = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
            sourceURL: root.appendingPathComponent("Sources"), client: coldClient, timing: .live)
        do {
            _ = try await reopened.resumeDownload(book, chapterIndex: 0, operationID: operationID)
            XCTFail("Cold recovery cannot invent an acquisition grant")
        } catch { XCTAssertTrue(error.localizedDescription.contains("请重新选择继续或下载章节")) }
        XCTAssertEqual(coldClient.totalSends, 0)
        XCTAssertEqual(try Data(contentsOf: file), retained)
        let coldPending = try await reopened.pendingCoreCommands()
        XCTAssertTrue(coldPending.isEmpty)
        try await reopened.close()

        let recoveryRoot = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderUnboundFeatureRecovery-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: recoveryRoot) }
        let recoveryDirectory = recoveryRoot.appendingPathComponent("Sources/.operations/commands")
        try FileManager.default.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
        let recoveryFile = recoveryDirectory.appendingPathComponent(name)
        try bytes.write(to: recoveryFile)
        let recoveryClient = ResumeAcquisitionReplyFixture(rejection: nil)
        let recoveryService = try ReaderLibraryService(storageURL: recoveryRoot.appendingPathComponent("Core"),
            sourceURL: recoveryRoot.appendingPathComponent("Sources"), client: recoveryClient, timing: .live)
        let recovered = try await recoveryService.resumePendingFeatureOperation(operationID)
        XCTAssertEqual(recovered.status, .completed, "This completes only the retained resume ACK")
        XCTAssertFalse(recovered.remaining)
        XCTAssertTrue(recovered.message?.contains("请重新选择继续或下载章节") == true)
        let recoveryPending = try await recoveryService.pendingCoreCommands()
        XCTAssertTrue(recoveryPending.isEmpty)
        XCTAssertEqual(recoveryClient.totalSends, 0)
        let recoveryRecord = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: recoveryFile)) as? [String: Any])
        XCTAssertEqual(recoveryRecord["parameters"] as? String, parameters.base64EncodedString())
        XCTAssertEqual(recoveryRecord["result"] as? String, ack.base64EncodedString())
        try await recoveryService.close()
    }

    func testInvalidResumeChapterIsRejectedBeforeCoreMutation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderInvalidResume-" + UUID().uuidString)
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
                                               sourceURL: root.appendingPathComponent("Sources"))
        defer { try? FileManager.default.removeItem(at: root) }
        let book = ReaderBook(sourceId: "real-source", bookId: "real-book", title: "真实书目")
        let operationID = UUID().uuidString
        do {
            _ = try await service.resumeDownload(book, chapterIndex: UInt32.max, operationID: operationID)
            XCTFail("The reserved chapter index must be rejected before dispatch")
        } catch ReaderLibraryError.invalidPosition {
            // Expected deterministic validation boundary.
        }
        let pending = try await service.pendingCoreCommands()
        XCTAssertTrue(pending.isEmpty,
                      "An invalid resume must not create a Core operation or journal entry")
        let commandDirectory = root.appendingPathComponent("Sources/.operations/commands")
        let files = try? FileManager.default.contentsOfDirectory(at: commandDirectory, includingPropertiesForKeys: nil)
        XCTAssertTrue(files?.isEmpty ?? true, "No resume journal should be written for invalid input")
        try await service.close()
    }

    func testOriginalPendingTerminalPreservesTheCommandAndConsumesExactReceiptWithoutRedispatch() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderOriginalPending-" + UUID().uuidString)
        let storage = root.appendingPathComponent("Core")
        let sources = root.appendingPathComponent("Sources")
        try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
        let client = try OriginalPendingReplyDecorator(storage: storage)
        defer {
            client.destroy()
            try? FileManager.default.removeItem(at: root)
        }
        let service = try ReaderLibraryService(storageURL: storage, sourceURL: sources, client: client, timing: .live)
        let operationID = UUID().uuidString
        do {
            _ = try await service.createGroup(name: "保留原请求", operationID: operationID)
            XCTFail("A terminal describing the retained original job cannot confirm or reject that job")
        } catch ReaderLibraryError.operationPending(let originalID) {
            XCTAssertEqual(originalID, operationID)
        }
        XCTAssertEqual(client.replacementCount, 1)
        XCTAssertEqual(client.count("bookshelf.management.mutation.apply"), 1)
        let originalACK = try XCTUnwrap(client.originalACK)
        XCTAssertEqual(originalACK.type, "result", "The decorator replaces only a successful real Core terminal")
        XCTAssertEqual(originalACK.data?["outcome"] as? String, "applied")
        let originalData = try XCTUnwrap(originalACK.data?["data"] as? [String: Any])
        let originalGroup = try XCTUnwrap(originalData["group"] as? [String: Any])
        let groupID = try XCTUnwrap(originalGroup["groupId"] as? NSNumber).int64Value

        let pending = try await service.pendingCoreCommands()
        XCTAssertEqual(pending.map(\.id), [operationID])
        XCTAssertEqual(pending.first?.acknowledged, false)
        let completedBeforeRecovery = try await service.isCoreOperationCompleted(operationID)
        XCTAssertFalse(completedBeforeRecovery)
        let commandDirectory = sources.appendingPathComponent(".operations/commands", isDirectory: true)
        let commandFiles = try FileManager.default.contentsOfDirectory(at: commandDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        XCTAssertEqual(commandFiles.count, 1)
        let journalFile = try XCTUnwrap(commandFiles.first)
        let journalObject = try JSONSerialization.jsonObject(with: Data(contentsOf: journalFile))
        let journal = try XCTUnwrap(journalObject as? [String: Any])
        XCTAssertEqual(journal["id"] as? String, operationID)
        XCTAssertEqual(journal["completed"] as? Bool, false)
        XCTAssertNil(journal["failure"], "The durable original intent must not become a rejected tombstone")
        XCTAssertNil(journal["result"])
        XCTAssertEqual(client.count("book-group.list"), 0, "No fresh business projection may acknowledge this write")

        let queriesBeforeRecovery = client.count("bookshelf.management.mutation.query")
        let recovered = try await service.resumePendingFeatureOperation(operationID)
        XCTAssertEqual(recovered.status, .completed, recovered.message ?? "The real exact receipt must resolve the retained original")
        XCTAssertFalse(recovered.remaining)
        XCTAssertEqual(client.count("bookshelf.management.mutation.apply"), 1)
        XCTAssertGreaterThan(client.count("bookshelf.management.mutation.query"), queriesBeforeRecovery)
        let originalParameters = try XCTUnwrap(client.originalParameters)
        let exactQuery = try XCTUnwrap(client.exactQuery)
        XCTAssertEqual(exactQuery["operationId"] as? String, originalParameters["operationId"] as? String)
        let expected = try XCTUnwrap(exactQuery["expected"] as? [String: Any])
        XCTAssertEqual(try JSONSerialization.data(withJSONObject: expected, options: [.sortedKeys]),
                       try JSONSerialization.data(withJSONObject: originalParameters, options: [.sortedKeys]))
        XCTAssertEqual(client.count("book-group.list"), 0)
        let afterRecovery = try await service.pendingCoreCommands()
        XCTAssertTrue(afterRecovery.isEmpty)
        let replayed = try await service.createGroup(name: "保留原请求", operationID: operationID)
        XCTAssertEqual(replayed.groupId, groupID)
        XCTAssertEqual(client.count("bookshelf.management.mutation.apply"), 1)
        // Only after the original exact receipt completed, inspect the real
        // business projection. This list is never used to settle the write.
        let groups = try await service.groups()
        XCTAssertEqual(groups.map(\.groupId), [groupID])
        XCTAssertEqual(groups.map(\.groupName), ["保留原请求"])

        let flagged = try downloadReceiptErrorEvent(requestID: 9_001, code: "INVALID_PARAMS", originalPending: true)
        do {
            _ = try await service.responseData(.success(flagged), method: "cache.book.prefetch", requestID: 9_001)
            XCTFail("originalPending must take precedence over the transport error code")
        } catch {
            XCTAssertTrue(error is ReaderCoreOriginalOperationPending)
            XCTAssertFalse(ReaderLibraryService.isDefiniteMutationRejection(error))
        }
        let validation = try downloadReceiptErrorEvent(requestID: 9_002, code: "INVALID_PARAMS", originalPending: nil)
        do {
            _ = try await service.responseData(.success(validation), method: "cache.book.prefetch", requestID: 9_002)
            XCTFail("A genuine validation rejection must remain an error")
        } catch {
            XCTAssertFalse(error is ReaderCoreOriginalOperationPending)
            XCTAssertTrue(ReaderLibraryService.isDefiniteMutationRejection(error))
        }
        try await service.close()
    }
}

private func downloadCanonical(_ value: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed])
}

/// Scripted read-only Core pages; unexpected mutation/metadata methods fail.
private final class DownloadInventoryReplyFixture: ReaderCoreEventClient, @unchecked Sendable {
    private let lock = NSLock()
    private var pages: [[String: Any]]
    private var replies: [UInt64: ReaderCoreEvent] = [:]
    private var parameters: [[String: Any]] = []
    private let readMethod: String
    init(pages: [[String: Any]], readMethod: String = "cache.download.books.list") {
        self.pages = pages; self.readMethod = readMethod
    }
    var inventoryParameters: [[String: Any]] { lock.lock(); defer { lock.unlock() }; return parameters }
    func send(method: String, requestId: UInt64, params: [String: Any]) throws -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        let data: [String: Any]
        switch method {
        case readMethod:
            guard !pages.isEmpty else { throw ReaderLibraryError.invalidResponse("Unexpected inventory page") }
            parameters.append(params); data = pages.removeFirst()
        case "runtime.storage.flush": data = [:]
        default: throw ReaderLibraryError.invalidResponse("Inventory must not mutate or fetch metadata: " + method)
        }
        replies[requestId] = try ReaderCoreEvent(data: JSONSerialization.data(withJSONObject: [
            "protocolVersion": ReaderCoreClient.protocolVersion, "type": "result", "requestId": requestId, "data": data
        ]))
        return requestId
    }
    func pollEvent(requestId: UInt64) -> Result<ReaderCoreEvent, ReaderCoreClientError>? {
        lock.lock(); defer { lock.unlock() }
        return replies.removeValue(forKey: requestId).map { .success($0) }
    }
    func cancel(requestId: UInt64) throws {}
    func destroy() {}
}

/// A scripted Core protocol boundary, not a Core task/receipt implementation.
/// Only the Host's immutable payload and retained original handling is tested.
private final class ResumeAcquisitionReplyFixture: ReaderCoreEventClient, @unchecked Sendable {
    private let lock = NSLock()
    private let rejection: String?
    private let pendingPrefetch: Bool
    private var replies: [UInt64: ReaderCoreEvent] = [:]
    private var sent: [(String, [String: Any])] = []
    private var originals: [String: ([String: Any], [String: Any])] = [:]
    private var settled = Set<String>()
    let resumeACK: [String: Any] = ["sourceId": "method-source", "bookId": "method-book", "chapterIndex": 0,
        "status": "failed", "attempts": 1, "maxAttempts": 3, "acquisitionToken": String(repeating: "b", count: 64)]
    init(rejection: String?, pendingPrefetch: Bool = false) { self.rejection = rejection; self.pendingPrefetch = pendingPrefetch }
    var totalSends: Int { lock.lock(); defer { lock.unlock() }; return sent.count }
    func count(_ method: String) -> Int { lock.lock(); defer { lock.unlock() }; return sent.filter { $0.0 == method }.count }
    func parameters(_ method: String, action: String? = nil) -> [String: Any]? {
        lock.lock(); defer { lock.unlock() }
        return sent.first { $0.0 == method && (action == nil || $0.1["action"] as? String == action) }?.1
    }
    private func binding(_ params: [String: Any], action: String) -> [String: Any] {
        ["operationId": params["operationId"]!, "sequence": params["sequence"]!,
         "payloadFingerprint": String(repeating: action == "resume" ? "a" : "c", count: 64)]
    }
    @discardableResult
    func send(method: String, requestId: UInt64, params: [String: Any]) throws -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        sent.append((method, params))
        let data: [String: Any]
        var error: [String: Any]?
        switch method {
        case "runtime.storage.flush":
            data = [:] // Normal service close only; no business receipt is fabricated.
        case "cache.book.status":
            data = ["sourceId": "method-source", "bookId": "method-book", "tocAvailable": true, "chapterCount": 1,
                "chapters": [["chapterIndex": 0, "state": "failed"]], "cachedCount": 0, "queuedCount": 0,
                "inProgressCount": 0, "completedCount": 0, "failedCount": 1, "cancelledCount": 0, "missingCount": 0]
        case "cache.download.resume":
            data = resumeACK; originals["resume"] = (params, data)
        case "cache.book.prefetch":
            data = ["sourceId": "method-source", "bookId": "method-book", "chapterRange": params["chapterRange"]!,
                "chapterCount": 1, "prefetchedCount": 0, "queuedIndexes": [], "alreadyQueuedIndexes": [],
                "skippedCachedIndexes": [], "materializations": []]
            if pendingPrefetch {
                error = ["code": "BUSY", "message": "method original child unresolved", "retryable": true,
                    "details": ["reason": "original_job_retained", "originalPending": true]]
            } else if let rejection {
                error = ["code": "INVALID_PARAMS", "message": "method acquisition not executed", "retryable": false,
                    "details": ["reason": rejection, "nonExecution": true]]
            } else { originals["prefetch"] = (params, data) }
        case "cache.download.operation.query":
            let action = params["action"] as? String ?? ""
            if let original = originals[action] {
                let bound = binding(original.0, action: action)
                data = ["head": bound, "receipt": ["binding": bound, "action": action,
                    "phase": settled.contains(action) ? "settled" : "committed", "data": original.1], "canResumeOriginal": false]
            } else { data = ["head": NSNull(), "receipt": NSNull(), "canResumeOriginal": false] }
        case "cache.download.operation.settle":
            let action = params["action"] as? String ?? ""
            settled.insert(action)
            data = ["binding": binding(params, action: action), "phase": "settled", "action": action,
                "data": originals[action]?.1 ?? [:]]
        default: throw ReaderLibraryError.invalidResponse("Unexpected Host method fixture call: " + method)
        }
        var envelope: [String: Any] = ["protocolVersion": ReaderCoreClient.protocolVersion,
            "type": error == nil ? "result" : "error", "requestId": requestId]
        if let error { envelope["error"] = error } else { envelope["data"] = data }
        replies[requestId] = try ReaderCoreEvent(data: JSONSerialization.data(withJSONObject: envelope))
        return requestId
    }
    func pollEvent(requestId: UInt64) -> Result<ReaderCoreEvent, ReaderCoreClientError>? {
        lock.lock(); defer { lock.unlock() }
        return replies.removeValue(forKey: requestId).map { .success($0) }
    }
    func cancel(requestId: UInt64) throws {}
    func retireReadRequest(requestId: UInt64) {}
    func destroy() {}
}

private func downloadReceiptErrorEvent(requestID: UInt64, code: String, originalPending: Bool?) throws -> ReaderCoreEvent {
    var details: [String: Any] = ["reason": originalPending == true ? "original_job_retained" : "invalid_fixture_parameter"]
    if let originalPending { details["originalPending"] = originalPending }
    return try ReaderCoreEvent(data: JSONSerialization.data(withJSONObject: [
        "protocolVersion": ReaderCoreClient.protocolVersion, "type": "error", "requestId": requestID,
        "error": ["code": code, "message": "Exact original operation status probe", "retryable": false, "details": details]
    ]))
}

/// Real Core performs the group mutation. Only that one delivered terminal is
/// replaced; the immutable original receipt and its query remain Core-owned.
private final class OriginalPendingReplyDecorator: ReaderCoreEventClient, @unchecked Sendable {
    private let native: ReaderCoreClient
    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    private var selectedRequestID: UInt64?
    private var savedOriginalACK: ReaderCoreEvent?
    private var savedParameters: [String: Any]?
    private var savedExactQuery: [String: Any]?
    private var replacements = 0

    init(storage: URL) throws {
        native = try ReaderCoreClient(configJSON: JSONSerialization.data(withJSONObject: ["dataDirectory": storage.path]))
    }
    var replacementCount: Int { lock.lock(); defer { lock.unlock() }; return replacements }
    var originalACK: ReaderCoreEvent? { lock.lock(); defer { lock.unlock() }; return savedOriginalACK }
    var originalParameters: [String: Any]? { lock.lock(); defer { lock.unlock() }; return savedParameters }
    var exactQuery: [String: Any]? { lock.lock(); defer { lock.unlock() }; return savedExactQuery }
    func count(_ method: String) -> Int { lock.lock(); defer { lock.unlock() }; return counts[method, default: 0] }

    @discardableResult
    func send(method: String, requestId: UInt64, params: [String: Any]) throws -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        let id = try native.send(method: method, requestId: requestId, params: params)
        counts[method, default: 0] += 1
        if method == "bookshelf.management.mutation.apply", selectedRequestID == nil,
           (params["mutation"] as? [String: Any])?["method"] as? String == "book-group.create" {
            selectedRequestID = requestId
            savedParameters = params
        }
        if method == "bookshelf.management.mutation.query", params["expected"] != nil { savedExactQuery = params }
        return id
    }

    func pollEvent(requestId: UInt64) -> Result<ReaderCoreEvent, ReaderCoreClientError>? {
        lock.lock(); defer { lock.unlock() }
        guard let reply = native.pollEvent(requestId: requestId) else { return nil }
        guard requestId == selectedRequestID, replacements == 0,
              case .success(let event) = reply, event.type == "result" else { return reply }
        do {
            let replacement = try downloadReceiptErrorEvent(requestID: requestId, code: "BUSY", originalPending: true)
            savedOriginalACK = event
            replacements += 1
            return .success(replacement)
        } catch { return .failure(.invalidEventJSON) }
    }

    func cancel(requestId: UInt64) throws { lock.lock(); defer { lock.unlock() }; try native.cancel(requestId: requestId) }
    func retireReadRequest(requestId: UInt64) { lock.lock(); defer { lock.unlock() }; native.retireReadRequest(requestId: requestId) }
    func destroy() { lock.lock(); defer { lock.unlock() }; native.destroy() }
}
