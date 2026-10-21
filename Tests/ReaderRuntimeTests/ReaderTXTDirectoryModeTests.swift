import CryptoKit
import Foundation
import XCTest
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

final class ReaderTXTDirectoryModeTests: XCTestCase {
    func testRealTXTCanonicalDirectoryThenExplicitPreparationUsesCoreTargetProofAndPreservesTheBook() async throws {
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let input = documents.appendingPathComponent("仙子请听我解释.txt")
        let original = try Data(contentsOf: input)
        XCTAssertEqual(original.count, 8_871_723)
        XCTAssertEqual(SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined(),
                       "aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderRealTXTDirectory-" + UUID().uuidString)
        let library = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
                                               sourceURL: root.appendingPathComponent("Sources"))
        do {
            let imported = try await library.importBook(at: input)
            XCTAssertTrue(imported.created)
            let book = imported.book
            let kind = try await library.localPresentationKind(for: book)
            XCTAssertEqual(kind.kind, .text); XCTAssertFalse(kind.reimportRequired)
            let chapters = try await library.chapters(for: book)
            XCTAssertEqual(chapters.count, 948)
            let chapter = try XCTUnwrap(chapters.first { $0.index == 1 })
            let body = try await library.content(for: book, chapterIndex: chapter.index)
            XCTAssertFalse(body.content.isEmpty)
            let observation = try await library.progress(for: book)
            let saved = try await library.saveProgress(for: book, content: body, scalarOffset: 37,
                                                       expectedRevision: observation.progressRevision)
            let tocBefore = try await library.coreRead("local_book.toc", ["bookId": book.bookId])
            let metadataBefore = try await library.bookDetails(for: book)
            let canonical = try await library.directory(for: book)
            XCTAssertEqual(canonical.sourceId, book.sourceId); XCTAssertEqual(canonical.bookId, book.bookId)
            XCTAssertEqual(canonical.status, "canonical")
            XCTAssertNil(canonical.reason); XCTAssertNil(canonical.viewId)
            XCTAssertNil(canonical.catalogRevision); XCTAssertNil(canonical.structureRevision)
            XCTAssertTrue(canonical.nodes.isEmpty, "Flat mode must not fabricate a Core navigation manifest or target proof")
            let repeated = try await library.directory(for: book, query: "第一章", descending: true)
            XCTAssertEqual(repeated.status, "canonical")
            let readsOnly = try await library.pendingCoreCommands()
            XCTAssertTrue(readsOnly.isEmpty, "Reading the default directory must not create a preparation write owner")

            let operationID = UUID().uuidString
            let prepared = try await library.prepareDirectoryRules(for: book, operationID: operationID)
            XCTAssertEqual(prepared.status, "unavailable")
            XCTAssertEqual(prepared.reason, "NoStructure", "This real TXT has no default grouping; retain its actual completed result")
            let acknowledged = try await library.isCoreOperationCompleted(operationID)
            XCTAssertTrue(acknowledged, "Only the explicit preparation's original ACK finishes this operation")
            let stillCanonical = try await library.directory(for: book)
            XCTAssertEqual(stillCanonical.status, "canonical")
            let rules = [ReaderDirectoryHierarchyRule(
                pattern: "^" + NSRegularExpression.escapedPattern(for: chapter.title) + "$", level: 1, boundary: .title)]
            let preview = try await library.previewDirectoryRules(for: book, rules: rules)
            XCTAssertEqual(preview.status, "ready", "Explicit preview uses the original Core chapter title, not generated book content")
            let afterPreview = try await library.directory(for: book)
            XCTAssertEqual(afterPreview.status, "canonical", "Preview cannot publish display authority")
            let applyID = UUID().uuidString
            let applied = try await library.applyDirectoryRules(for: book, rules: rules, operationID: applyID)
            XCTAssertEqual(applied.status, "ready")
            let applyAcknowledged = try await library.isCoreOperationCompleted(applyID)
            XCTAssertTrue(applyAcknowledged)
            let ready = try await library.directory(for: book)
            XCTAssertEqual(ready.status, "ready", "The existing Core hierarchy must take precedence over canonical Host mode")
            XCTAssertNotNil(ready.viewId); XCTAssertNotNil(ready.catalogRevision); XCTAssertNotNil(ready.structureRevision)
            let node = try XCTUnwrap(ready.nodes.first { $0.navigable && $0.chapterIndex == chapter.index })
            let target = try await library.resolveDirectoryTarget(node, in: ready)
            XCTAssertEqual(target.directoryTargetProof.sourceId, book.sourceId)
            XCTAssertEqual(target.directoryTargetProof.bookId, book.bookId)
            XCTAssertEqual(target.directoryTargetProof.catalogRevision, ready.catalogRevision)
            XCTAssertEqual(target.directoryTargetProof.structureRevision, ready.structureRevision)
            XCTAssertEqual(target.directoryTargetProof.nodeId, node.nodeId)
            XCTAssertEqual(target.directoryTargetProof.chapterIndex, chapter.index)
            XCTAssertEqual(target.directoryTargetProof.url, chapter.url)
            let provenBody = try await library.content(for: book, target: target)
            XCTAssertEqual(provenBody, body)
            let afterChapters = try await library.chapters(for: book)
            XCTAssertEqual(afterChapters, chapters)
            let tocAfter = try await library.coreRead("local_book.toc", ["bookId": book.bookId])
            XCTAssertEqual(try canonicalJSON(tocAfter), try canonicalJSON(tocBefore))
            let afterMetadata = try await library.bookDetails(for: book)
            XCTAssertEqual(afterMetadata, metadataBefore)
            let afterProgress = try await library.progress(for: book)
            XCTAssertTrue(afterProgress.found)
            XCTAssertEqual(afterProgress.progress, saved.progress, "Directory display preparation cannot alter the actual saved position or metadata")
            XCTAssertEqual(try Data(contentsOf: input), original)
            let retained = try await library.retainedSourceURL(for: book)
            XCTAssertEqual(try Data(contentsOf: retained), original)
            try await library.close()
            try FileManager.default.removeItem(at: root)
        } catch {
            // Retain an unresolved explicit original preparation if it failed;
            // never remove the library while a Core write still owns it.
            try? await library.close()
            let evidence = XCTAttachment(string: root.path + "\n" + String(describing: error))
            evidence.name = "Original-TXT-directory-failure-library"; evidence.lifetime = .keepAlways; add(evidence)
            throw error
        }
    }

    private func canonicalJSON(_ data: Data) throws -> Data {
        try JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: data), options: [.sortedKeys])
    }
}
