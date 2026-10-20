import Foundation
import XCTest
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

final class ReaderLibraryServiceTests: XCTestCase {
    private func fixtureRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderRuntimeTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func service(_ root: URL) throws -> ReaderLibraryService {
        try ReaderLibraryService(storageURL: root.appendingPathComponent("Core", isDirectory: true),
                                 sourceURL: root.appendingPathComponent("Sources", isDirectory: true))
    }

    private func writeBook(_ root: URL, name: String = "本地阅读.txt") throws -> URL {
        let input = root.appendingPathComponent(name)
        let text = """
        第一章 初见
        甲🙂é乙。这是第一章的正文。重复的文字用于验证真实 Core 持久化和位置恢复。
        第二章 重逢
        再次打开时，目录和正文都应来自 Core。这里还有𠮷与家人👨‍👩‍👧‍👦。
        """
        try Data(text.utf8).write(to: input)
        return input
    }

    func testRealCoreImportShelfBodyAndProgressSurviveRuntimeReopen() async throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = try service(root)
        let input = try writeBook(root)
        let imported = try await library.importBook(at: input)
        XCTAssertTrue(imported.created)
        XCTAssertTrue(imported.book.bookId.hasPrefix("local:"))
        let chapters = try await library.chapters(for: imported.book)
        XCTAssertGreaterThanOrEqual(chapters.count, 2)
        let chapter = try XCTUnwrap(chapters.first)
        let body = try await library.content(for: imported.book, chapterIndex: chapter.index)
        XCTAssertTrue(body.content.contains("🙂"))
        let initial = try await library.progress(for: imported.book)
        XCTAssertFalse(initial.found)
        XCTAssertNotNil(initial.progressRevision)
        let emojiEnd = try XCTUnwrap(body.content.range(of: "🙂")).upperBound.utf16Offset(in: body.content)
        let offset = ReaderTextCoordinates.scalarOffset(in: body.content, utf16Offset: emojiEnd)
        XCTAssertEqual(ReaderTextCoordinates.utf16Offset(in: body.content, scalarOffset: offset), emojiEnd)
        let saved = try await library.saveProgress(for: imported.book, content: body, scalarOffset: offset,
                                                   expectedRevision: initial.progressRevision)
        XCTAssertEqual(saved.progress?.chapterOffset, offset)
        try await library.close()
        // Neither the selected external URL nor an in-memory import result is
        // available to the reopened runtime.
        try FileManager.default.removeItem(at: input)
        let reopened = try service(root)
        let shelf = try await reopened.listBooks()
        XCTAssertEqual(shelf.map(\.bookId), [imported.book.bookId])
        let restoredChapters = try await reopened.chapters(for: imported.book)
        XCTAssertEqual(restoredChapters, chapters)
        let restoredBody = try await reopened.content(for: imported.book, chapterIndex: chapter.index)
        XCTAssertEqual(restoredBody.content, body.content)
        let restored = try await reopened.progress(for: imported.book)
        XCTAssertEqual(restored.progress?.chapterIndex, chapter.index)
        XCTAssertEqual(restored.progress?.chapterOffset, offset)
        XCTAssertEqual(restored.progress?.bodyVersion, body.bodyVersion)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Core/reader-core.sqlite3").path))
        let originals = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Sources"),
                                                                   includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "source" }
        XCTAssertEqual(originals.count, 1)
        try await reopened.close()
    }

    func testFailedImportPreservesExistingShelfBodyAndProgress() async throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = try service(root)
        let imported = try await library.importBook(at: writeBook(root))
        let chapters = try await library.chapters(for: imported.book)
        let index = try XCTUnwrap(chapters.first).index
        let body = try await library.content(for: imported.book, chapterIndex: index)
        let observed = try await library.progress(for: imported.book)
        let saved = try await library.saveProgress(for: imported.book, content: body, scalarOffset: 3,
                                                   expectedRevision: observed.progressRevision)
        let invalid = root.appendingPathComponent("空文件.txt")
        try Data().write(to: invalid)
        do {
            _ = try await library.importBook(at: invalid)
            XCTFail("Empty input must not materialize a placeholder book")
        } catch {
            XCTAssertFalse(error is CancellationError)
        }
        let shelf = try await library.listBooks()
        XCTAssertEqual(shelf.map(\.bookId), [imported.book.bookId])
        let afterBody = try await library.content(for: imported.book, chapterIndex: index)
        XCTAssertEqual(afterBody.content, body.content)
        let after = try await library.progress(for: imported.book)
        XCTAssertEqual(after, saved)
        let pending = try await library.pendingImports()
        XCTAssertTrue(pending.isEmpty)
        try await library.close()
    }

    func testOldSessionRevisionCannotOverwriteNewProgress() async throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = try service(root)
        let imported = try await library.importBook(at: writeBook(root))
        let chapters = try await library.chapters(for: imported.book)
        let body = try await library.content(for: imported.book, chapterIndex: XCTUnwrap(chapters.first).index)
        let old = try await library.progress(for: imported.book)
        let saved = try await library.saveProgress(for: imported.book, content: body, scalarOffset: 4,
                                                   expectedRevision: old.progressRevision)
        do {
            _ = try await library.saveProgress(for: imported.book, content: body, scalarOffset: 1,
                                               expectedRevision: old.progressRevision)
            XCTFail("A stale observation must be rejected by Core")
        } catch ReaderLibraryError.core(_, _, _, let reason) {
            XCTAssertEqual(reason, "READING_PROGRESS_CHANGED")
        }
        let after = try await library.progress(for: imported.book)
        XCTAssertEqual(after, saved)
        try await library.close()
    }

    func testDuplicateContentReturnsExistingCoreBookWithoutResettingPosition() async throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = try service(root)
        let input = try writeBook(root)
        let first = try await library.importBook(at: input)
        let chapters = try await library.chapters(for: first.book)
        let body = try await library.content(for: first.book, chapterIndex: XCTUnwrap(chapters.first).index)
        let initial = try await library.progress(for: first.book)
        let saved = try await library.saveProgress(for: first.book, content: body, scalarOffset: 5,
                                                   expectedRevision: initial.progressRevision)
        let second = try await library.importBook(at: input)
        XCTAssertFalse(second.created)
        XCTAssertEqual(first.book.bookId, second.book.bookId)
        let after = try await library.progress(for: first.book)
        XCTAssertEqual(saved, after)
        try await library.close()
    }

    func testCancellationBeforeDispatchLeavesNoShelfOrStagedSource() async throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = try service(root)
        let input = try writeBook(root)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await library.importBook(at: input)
        }
        do {
            _ = try await task.value
            XCTFail("An already cancelled selection must not dispatch an import")
        } catch is CancellationError {}
        let shelf = try await library.listBooks()
        XCTAssertTrue(shelf.isEmpty)
        let staging = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Sources/.staging").path)
        XCTAssertTrue(staging.isEmpty)
        try await library.close()
    }
}
