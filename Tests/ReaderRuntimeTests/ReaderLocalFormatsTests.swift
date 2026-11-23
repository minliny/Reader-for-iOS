import Combine
import CryptoKit
import Foundation
import XCTest
@testable import Reader

/// These exact user-owned originals are provisioned into App Documents by the
/// delivery owner. Missing or changed input fails; no generated format fixture
/// or renamed substitute can satisfy its original-format SHA identity.
final class ReaderLocalFormatsTests: XCTestCase {
    private static let xiYouJiMobiSHA = "38291a2da031cfeeedb8fd39edf53a41fd3603fdf5ca8d0428f6f3a4fb2267a7"

    @MainActor
    func testRealZhongSongEpubUserLineHeightOverridesOriginalParagraphsAndPreservesScalar() async throws {
        try await ReaderEbookRealWebKitProbe.verifyLineHeight(in: self)
    }

    @MainActor
    func testRealZhongSongEpubWebKitPresentationRestoresScalarAndLoadsReaderFonts() async throws {
        try await ReaderEbookRealWebKitProbe.verify(in: self, format: "epub", byteCount: 7_406_795,
            digest: "5d6d9dd26bbea9ed0db4e4f7a127a538dfe439f5694c3370a30ac33503db9d67")
    }

    @MainActor
    func testRealFuHanMobiWebKitPresentationRestoresScalarAndLoadsReaderFonts() async throws {
        try await ReaderEbookRealWebKitProbe.verify(in: self, format: "mobi", byteCount: 8_522_384,
            digest: "a25dcde710240f9c2c03d7b7b98aa09277d83392f3dc0da9779f6bc78e7c0cef")
    }

    func testRealZhongSongEpubOriginalPresentationAndColdRecovery() async throws {
        try await verifyOriginal(format: "epub", byteCount: 7_406_795,
            digest: "5d6d9dd26bbea9ed0db4e4f7a127a538dfe439f5694c3370a30ac33503db9d67")
    }

    func testRealFuHanMobiOriginalPresentationAndColdRecovery() async throws {
        try await verifyOriginal(format: "mobi", byteCount: 8_522_384,
            digest: "a25dcde710240f9c2c03d7b7b98aa09277d83392f3dc0da9779f6bc78e7c0cef")
    }

    func testRealHongYueMobiOriginalPresentationAndColdRecovery() async throws {
        try await verifyOriginal(format: "mobi", byteCount: 8_916_557,
            digest: "96a6a97444428ff61fed1b5144ade91b45b66f5492dfaa4caa6a6a1a0fe0d0f3")
    }

    func testRealGutenbergXiYouJiMobiOriginalPresentationAndColdRecovery() async throws {
        // Public Gutenberg original retained by Eruditio at c5175043.
        try await verifyOriginal(format: "mobi", byteCount: 2_118_430, digest: Self.xiYouJiMobiSHA)
    }

    @MainActor
    func testRealGutenbergXiYouJiMobiWebKitShowsLongOriginalAtSavedScalar() async throws {
        try await ReaderEbookRealWebKitProbe.verifyLongOriginalMobi(in: self, byteCount: 2_118_430,
            digest: Self.xiYouJiMobiSHA)
    }

    @MainActor
    func testRealEbookTruncationAndUnsupportedFileReachImportFeedback() async throws {
        let epubSHA = "5d6d9dd26bbea9ed0db4e4f7a127a538dfe439f5694c3370a30ac33503db9d67"
        let rulesSHA = "664149381e86b68f388a127c9f8531bf1753d0388f5d8c453375a322437a0734"
        let epub = try Self.originalURL(format: "epub", byteCount: 7_406_795, digest: epubSHA)
        let mobi = try Self.originalURL(format: "mobi", byteCount: 2_118_430, digest: Self.xiYouJiMobiSHA)
        let unsupported = try Self.originalURL(format: "json", byteCount: 6_531, digest: rulesSHA)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderFormatFeedback-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let truncatedEpub = root.appendingPathComponent("truncated.epub")
        let truncatedMobi = root.appendingPathComponent("truncated.mobi")

        // Keep the original signatures to select the real format parsers.
        // Only the two disposable copies are truncated.
        let epubPrefix = try Data(contentsOf: epub, options: .mappedIfSafe).prefix(160)
        let mobiPrefix = try Data(contentsOf: mobi, options: .mappedIfSafe).prefix(108)
        XCTAssertTrue(epubPrefix.starts(with: [0x50, 0x4b, 0x03, 0x04]))
        XCTAssertEqual(Data(mobiPrefix.dropFirst(60).prefix(8)), Data("BOOKMOBI".utf8))
        try epubPrefix.write(to: truncatedEpub)
        try mobiPrefix.write(to: truncatedMobi)

        let library = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
                                               sourceURL: root.appendingPathComponent("Sources"))
        let model = ReaderApplicationModel(service: library, readingTimeStorageURL: root.appendingPathComponent("reading-time.json"))
        let rejected = expectation(description: "Production import result displays the three rejected inputs")
        let emptyShelf = expectation(description: "The empty shelf reloads without any failed input")
        let resultObservation = model.$importOperation.compactMap { $0 }.first(where: { $0.phase == .failed })
            .sink { _ in rejected.fulfill() }
        let shelfObservation = model.$libraryState.first(where: { $0 == .empty }).sink { _ in emptyShelf.fulfill() }
        defer {
            resultObservation.cancel()
            shelfObservation.cancel()
        }
        let selected = [truncatedEpub, truncatedMobi, unsupported]
        do {
            model.importFiles(selected)
            await fulfillment(of: [rejected, emptyShelf], timeout: 30)
            let result = try XCTUnwrap(model.importOperation)
            XCTAssertEqual(result.phase, .failed)
            XCTAssertEqual(result.message, "已完成 0 项，失败 3 项，未执行 0 项")
            XCTAssertEqual(result.items.map(\.filename), selected.map(\.lastPathComponent))
            XCTAssertTrue(result.items.allSatisfy { $0.phase == .failed && $0.originalOperationID == nil })
            let messages = result.items.map(\.message)
            XCTAssertEqual(messages.count, 3)
            XCTAssertTrue(messages.first?.contains("epub_zip_open") == true, "The actual EPUB parser error must reach import feedback")
            XCTAssertTrue(messages.dropFirst().first?.contains("libmobi_decode_failed") == true,
                          "The actual MOBI parser error must reach import feedback")
            XCTAssertEqual(messages.last, ReaderLibraryError.unsupportedFile.localizedDescription)
            let shelf = try await library.listBooks()
            let pending = try await library.pendingImports()
            XCTAssertTrue(shelf.isEmpty)
            XCTAssertTrue(pending.isEmpty)
            XCTAssertEqual(try Self.digest(Data(contentsOf: epub, options: .mappedIfSafe)), epubSHA)
            XCTAssertEqual(try Self.digest(Data(contentsOf: mobi, options: .mappedIfSafe)), Self.xiYouJiMobiSHA)
            XCTAssertEqual(try Self.digest(Data(contentsOf: unsupported)), rulesSHA)
            try await library.close()
        } catch {
            try? await library.close()
            throw error
        }
    }

    @MainActor
    func testRealZhongSongEpubMissingImageKeepsOriginalProseAndPosition() async throws {
        try await ReaderEbookRealWebKitProbe.verify(in: self, format: "epub", byteCount: 7_406_795,
            digest: "5d6d9dd26bbea9ed0db4e4f7a127a538dfe439f5694c3370a30ac33503db9d67", checkMissingImage: true)
    }

    private struct Evidence: Equatable {
        let chapterIndex: UInt32
        let bodyVersion: String?
        let processingVersion: String?
        let bodyDigest: String
        let entryPath: String
        let entryDigest: String
        let documentDigest: String
        let startScalar: UInt64
        let endScalar: UInt64
    }

    static func originalURL(format: String, byteCount: Int, digest: String) throws -> URL {
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let files = try FileManager.default.contentsOfDirectory(at: documents,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey])
            .filter { $0.pathExtension.lowercased() == format }
        for url in files {
            let facts = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard facts.isRegularFile == true, facts.fileSize == byteCount else { continue }
            if Self.digest(try Data(contentsOf: url, options: .mappedIfSafe)) == digest { return url }
        }
        XCTFail("Provision the original \(format.uppercased()) into App Documents: \(byteCount) bytes, SHA256 \(digest). Available: \(files.map(\.lastPathComponent))")
        throw ReaderLibraryError.invalidResponse("required real \(format) original is missing or changed")
    }

    private func verifyOriginal(format: String, byteCount: Int, digest: String) async throws {
        let input = try Self.originalURL(format: format, byteCount: byteCount, digest: digest)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderRealFormat-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let core = root.appendingPathComponent("Core", isDirectory: true)
        let sources = root.appendingPathComponent("Sources", isDirectory: true)
        let library = try ReaderLibraryService(storageURL: core, sourceURL: sources)
        var reopened: ReaderLibraryService?
        do {
            let imported = try await library.importBook(at: input)
            XCTAssertTrue(imported.created)
            XCTAssertFalse(imported.finalizationPending)
            let book = imported.book
            XCTAssertEqual(book.bookId, "local:" + digest)
            let kind = try await library.localPresentationKind(for: book)
            XCTAssertEqual(kind.kind, .ebook)
            XCTAssertEqual(kind.format, format)
            XCTAssertFalse(kind.reimportRequired, "Every canonical chapter needs an original-format locator")
            let chapters = try await library.chapters(for: book)
            let readable = chapters.filter { !$0.url.isEmpty }
            XCTAssertFalse(readable.isEmpty)
            let first = try XCTUnwrap(readable.first)
            let indexes = Array(Set([first.index, readable[readable.count / 2].index, try XCTUnwrap(readable.last).index])).sorted()
            let retained = try await library.retainedSourceURL(for: book)
            XCTAssertEqual(try Self.digest(Data(contentsOf: retained, options: .mappedIfSafe)), digest)
            let before = try await library.progress(for: book)
            var evidence: [Evidence] = []
            for index in indexes { evidence.append(try await presentationEvidence(library, book: book, index: index, retained: retained)) }
            let afterRead = try await library.progress(for: book)
            XCTAssertEqual(afterRead, before, "Descriptor and resource reads cannot move progress")
            let body = try await library.content(for: book, chapterIndex: first.index)
            let offset = min(UInt64(37), body.scalarCount)
            let saved = try await library.saveProgress(for: book, content: body, scalarOffset: offset, expectedRevision: before.progressRevision)
            XCTAssertEqual(saved.progress?.chapterOffset, offset)
            try await library.close()

            let cold = try ReaderLibraryService(storageURL: core, sourceURL: sources)
            reopened = cold
            let shelf = try await cold.listBooks()
            XCTAssertEqual(shelf.map(\.bookId), [book.bookId])
            let restoredChapters = try await cold.chapters(for: book)
            XCTAssertEqual(restoredChapters, chapters)
            let restoredKind = try await cold.localPresentationKind(for: book)
            XCTAssertEqual(restoredKind, kind)
            let restoredProgress = try await cold.progress(for: book)
            XCTAssertEqual(restoredProgress.progress, saved.progress)
            let coldRetained = try await cold.retainedSourceURL(for: book)
            for expected in evidence {
                let actual = try await presentationEvidence(cold, book: book, index: expected.chapterIndex, retained: coldRetained)
                XCTAssertEqual(actual, expected)
            }
            XCTAssertEqual(try Self.digest(Data(contentsOf: coldRetained, options: .mappedIfSafe)), digest)
            let afterColdRead = try await cold.progress(for: book)
            XCTAssertEqual(afterColdRead, restoredProgress)
            try await cold.close()
        } catch {
            try? await library.close()
            if let reopened { try? await reopened.close() }
            throw error
        }
        XCTAssertEqual(try input.resourceValues(forKeys: [.fileSizeKey]).fileSize, byteCount)
        XCTAssertEqual(try Self.digest(Data(contentsOf: input, options: .mappedIfSafe)), digest)
    }

    private func presentationEvidence(_ library: ReaderLibraryService, book: ReaderBook, index: UInt32, retained: URL) async throws -> Evidence {
        let content = try await library.content(for: book, chapterIndex: index)
        let document = try await library.ebookPresentation(for: book, chapterIndex: index)
        try document.validate(content: content)
        let reference = document.documentCanonicalContent.unicodeScalars
        let lower = reference.index(reference.startIndex, offsetBy: Int(document.chapterStartScalar))
        let upper = reference.index(reference.startIndex, offsetBy: Int(document.chapterEndScalar))
        // The descriptor authenticates the original indexed window. Current
        // content has already passed Core's processing pipeline (including
        // normalization and user rules), and owns the returned scalar scope.
        let original = String(reference[lower..<upper])
        let edits: [ReaderEbookTextEdits.Edit]
        do {
            edits = try ReaderEbookTextEdits.changes(original: original, processed: content.content)
        } catch ReaderEbookError.resourceLimit {
            let source = original.unicodeScalars
            let target = content.content.unicodeScalars
            let prefix = zip(source, target).prefix { $0.0 == $0.1 }.count
            let sourceTail = source.reversed().prefix(source.count - prefix)
            let targetTail = target.reversed().prefix(target.count - prefix)
            let suffix = zip(sourceTail, targetTail).prefix { $0.0 == $0.1 }.count
            XCTFail("DOM edit limit for chapter \(index): indexed=\(source.count), processed=\(target.count), commonPrefix=\(prefix), commonSuffix=\(suffix)")
            throw ReaderEbookError.resourceLimit
        }
        var processed = Array(original.unicodeScalars)
        for edit in edits.reversed() {
            XCTAssertLessThanOrEqual(edit.startScalar, edit.endScalar)
            XCTAssertLessThanOrEqual(edit.endScalar, UInt64(processed.count))
            processed.replaceSubrange(Int(edit.startScalar)..<Int(edit.endScalar), with: edit.text.unicodeScalars)
        }
        XCTAssertEqual(processed.map(String.init).joined(), content.content)
        XCTAssertEqual(UInt64(processed.count), content.scalarCount)
        let reader = ReaderEbookArchiveReader(sourceURL: retained, bookID: book.bookId)
        let originalEntry = try await reader.readEntry(document.entryPath, maximumBytes: 32 * 1024 * 1024)
        XCTAssertFalse(originalEntry.isEmpty)
        XCTAssertNotNil(String(data: originalEntry, encoding: .utf8), "Original normalized XHTML stays UTF-8")
        return Evidence(chapterIndex: index, bodyVersion: content.bodyVersion, processingVersion: content.processingVersion,
            bodyDigest: Self.digest(Data(content.content.utf8)), entryPath: document.entryPath, entryDigest: Self.digest(originalEntry),
            documentDigest: Self.digest(Data(document.documentCanonicalContent.utf8)),
            startScalar: document.chapterStartScalar, endScalar: document.chapterEndScalar)
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
