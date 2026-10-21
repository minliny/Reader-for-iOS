import Foundation
import CryptoKit
import XCTest
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

@MainActor
final class ReaderLibraryFeatureTests: XCTestCase {
    /// Uses the byte-identical Downloads original provisioned by the native
    /// journey. No generated novel is substituted for the real-book boundary.
    func testRealBookBatchGroupingBookmarkAndRemovalPreserveTheSelectedOriginal() async throws {
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let input = documents.appendingPathComponent("仙子请听我解释.txt")
        let original = try Data(contentsOf: input)
        XCTAssertEqual(original.count, 8_871_723)
        let hash = SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hash, "aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderFeatures-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
        do {
            let batch = await service.importBooks(at: [input, root.appendingPathComponent("missing.txt"), input])
            XCTAssertEqual(batch.count, 3)
            XCTAssertTrue(try XCTUnwrap(batch[0].result).created)
            XCTAssertNotNil(batch[1].failure)
            XCTAssertFalse(try XCTUnwrap(batch[2].result).created)
            let book = try XCTUnwrap(batch[0].result).book
            XCTAssertEqual(book.bookId, "local:" + hash)
            XCTAssertEqual(book.chapterCount, 948)
            let detail = try await service.bookDetails(for: book)
            XCTAssertEqual(detail?.bookId, book.bookId)
            let groupOperation = UUID().uuidString
            let group = try await service.createGroup(name: "真实原书", operationID: groupOperation)
            let originalGroup = try await service.createGroup(name: "真实原书", operationID: groupOperation)
            XCTAssertEqual(group, originalGroup, "A consumed original create ACK must remain replayable without a second create")
            let assigned = try await service.assignGroup(group, to: book, operationID: UUID().uuidString)
            XCTAssertEqual(assigned.group, group.groupName)
            let filtered = try await service.listBooks(query: ReaderShelfQuery(group: group.groupName, sortBy: .title, descending: false))
            XCTAssertEqual(filtered.map(\.bookId), [book.bookId])
            let chapters = try await service.chapters(for: book)
            let chapter = try XCTUnwrap(chapters.first { $0.title.hasPrefix("第一章") })
            let body = try await service.content(for: book, chapterIndex: chapter.index)
            let observed = try await service.progress(for: book)
            let saved = try await service.saveProgress(for: book, content: body, scalarOffset: 20,
                                                       expectedRevision: observed.progressRevision)
            let markOperation = UUID().uuidString
            let mark = try await service.createBookmark(for: book, content: body, scalarOffset: 20,
                text: String(body.content.unicodeScalars.prefix(30)), note: "原位置", operationID: markOperation)
            let repeatedMark = try await service.createBookmark(for: book, content: body, scalarOffset: 20,
                text: String(body.content.unicodeScalars.prefix(30)), note: "原位置", operationID: markOperation)
            XCTAssertEqual(repeatedMark, mark)
            let marks = try await service.bookmarks(for: book)
            XCTAssertEqual(marks.map(\.time), [mark.time])
            XCTAssertEqual(mark.positionScope?.bookId, book.bookId)
            XCTAssertEqual(mark.scalarOffset, saved.progress?.chapterOffset)
            let updated = try await service.updateBookmark(mark, note: "已编辑", operationID: UUID().uuidString)
            XCTAssertEqual(updated.content, "已编辑")
            try await service.deleteBookmark(updated, operationID: UUID().uuidString)
            let afterMarks = try await service.bookmarks(for: book)
            XCTAssertTrue(afterMarks.isEmpty)
            let selectedSource = try await service.retainedSourceURL(for: book)
            XCTAssertEqual(try Data(contentsOf: selectedSource), original)
            let removalID = UUID().uuidString
            let removal = try await service.removeBooks([book, book], operationID: removalID)
            XCTAssertEqual(removal.requestedCount, 2)
            XCTAssertEqual(removal.removedTargets, [ReaderBookIdentity(book)])
            XCTAssertEqual(removal.duplicateTargets, [ReaderBookIdentity(book)])
            XCTAssertFalse(FileManager.default.fileExists(atPath: selectedSource.path))
            let repeatedRemoval = try await service.removeBooks([book, book], operationID: removalID)
            XCTAssertEqual(repeatedRemoval, removal)
            XCTAssertEqual(try Data(contentsOf: input), original)
            let pending = try await service.pendingCoreCommands()
            XCTAssertTrue(pending.isEmpty)
            try await service.close()
        } catch {
            try? await service.close()
            throw error
        }
    }

    func testOperationIdentityCannotBeReusedForDifferentParameters() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderOperationIdentity-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
        let operation = UUID().uuidString
        let group = try await service.createGroup(name: "原操作", operationID: operation)
        do {
            _ = try await service.createGroup(name: "另一操作", operationID: operation)
            XCTFail("An old operation ID must never be rebound to another payload")
        } catch ReaderLibraryError.invalidResponse(_) {}
        let groups = try await service.groups()
        XCTAssertEqual(groups.map(\.groupId), [group.groupId])
        XCTAssertEqual(groups.map(\.groupName), ["原操作"])
        try await service.close()
    }
}
