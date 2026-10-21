import CryptoKit
import Foundation
import XCTest
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

final class ReaderReadingToolsTests: XCTestCase {
    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderReadingTools-" + UUID().uuidString,
                                                                                isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    private func service(_ root: URL) throws -> ReaderLibraryService {
        try ReaderLibraryService(storageURL: root.appendingPathComponent("Core", isDirectory: true),
                                 sourceURL: root.appendingPathComponent("Sources", isDirectory: true))
    }
    private func realBookURL() throws -> URL {
        let directory = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let url = directory.appendingPathComponent("仙子请听我解释.txt")
        let bytes = try Data(contentsOf: url)
        XCTAssertEqual(bytes.count, 8_871_723)
        XCTAssertEqual(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(),
                       "aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5")
        return url
    }

    func testRealBookSearchAndHighlightKeepCoreIdentityAndRejectAnotherBody() async throws {
        // This is the exact user-owned Downloads book provisioned by the native
        // journey. It is never rewritten or replaced with generated novel text.
        let original = try realBookURL()
        let originalBytes = try Data(contentsOf: original)
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = try service(root)
        do {
            let book = try await library.importBook(at: original).book
            let page = try await library.searchContent(for: book, keyword: "全成就", limit: 10, offset: 0)
            let hit = try XCTUnwrap(page.results.first)
            XCTAssertEqual(hit.sourceId, book.sourceId)
            XCTAssertEqual(hit.bookId, book.bookId)
            let body = try await library.content(for: book, chapterIndex: UInt32(hit.chapterIndex))
            let range = try hit.scalarRange(for: book, content: body)
            let begin = ReaderTextCoordinates.utf16Offset(in: body.content, scalarOffset: range.lowerBound)
            let end = ReaderTextCoordinates.utf16Offset(in: body.content, scalarOffset: range.upperBound)
            XCTAssertEqual((body.content as NSString).substring(with: NSRange(location: begin, length: end - begin)), "全成就")
            let highlightOperation = UUID().uuidString
            let created = try await library.createHighlight(for: book, content: body, range: range,
                                                            style: "underline", note: "真实原书坐标回归",
                                                            operationID: highlightOperation)
            let repeated = try await library.createHighlight(for: book, content: body, range: range,
                                                             style: "underline", note: "真实原书坐标回归",
                                                             operationID: highlightOperation)
            XCTAssertEqual(repeated.time, created.time)
            XCTAssertEqual(try created.scalarRange(for: book, content: body), range)
            let stored = try await library.highlights(for: book)
            XCTAssertEqual(stored.filter { $0.time == created.time }.count, 1)
            XCTAssertEqual(stored.count, 1)
            let changed = try await library.updateHighlight(created, note: "编辑后保留同一正文锚点", style: "highlight",
                                                            operationID: UUID().uuidString)
            XCTAssertEqual(changed.positionScope, created.positionScope)
            XCTAssertEqual(changed.chapterPos, created.chapterPos)
            XCTAssertEqual(changed.note, "编辑后保留同一正文锚点")
            let otherBook = ReaderBook(bookId: "local:other-content", title: book.title)
            XCTAssertThrowsError(try hit.scalarRange(for: otherBook, content: body))
            XCTAssertThrowsError(try changed.scalarRange(for: otherBook, content: body))
            let deleted = try await library.deleteHighlight(changed, operationID: UUID().uuidString)
            XCTAssertTrue(deleted)
            let remaining = try await library.highlights(for: book)
            XCTAssertTrue(remaining.isEmpty)
            try await library.close()
        } catch {
            try? await library.close()
            throw error
        }
        XCTAssertEqual(try Data(contentsOf: original), originalBytes)
    }

    func testRuleCollectionsRoundTripThroughActualCoreCommandsAndPortableBundle() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = try service(root)
        do {
            let replaceOperation = UUID().uuidString
            let replaceDraft = ReaderReplaceRuleDraft(name: "字面替换", pattern: "甲", replacement: "乙", isRegex: false)
            let replace = try await library.createReplaceRule(replaceDraft, operationID: replaceOperation)
            let repeatedReplace = try await library.createReplaceRule(replaceDraft, operationID: replaceOperation)
            XCTAssertEqual(repeatedReplace.id, replace.id)
            let validation = try await library.validateReplaceRule(replace.draft)
            XCTAssertTrue(validation.valid)
            let processed = try await library.processText("甲甲", for: ReaderBook(bookId: "rule-unit", title: "规则测试"), target: .chapter)
            XCTAssertEqual(processed.text, "乙乙")
            XCTAssertTrue(processed.changed)
            let toc = try await library.createTXTTOCRule(ReaderTXTTOCRuleDraft(name: "章节规则", rule: "^第.{1,12}章.*$"),
                                                        operationID: UUID().uuidString)
            let dictionary = try await library.putDictionaryRule(ReaderDictionaryRule(name: "本机词典规则", urlRule: "https://example.invalid/?q={{key}}", showRule: "body"),
                                                                  operationID: UUID().uuidString)
            let bundle = try await library.exportRuleBundle()
            XCTAssertEqual(bundle.schemaVersion, 1)
            XCTAssertEqual(bundle.counts.replaceRules, 1)
            XCTAssertEqual(bundle.counts.txtTocRules, 1)
            XCTAssertEqual(bundle.counts.dictRules, 1)
            var edit = replace.draft
            edit.replacement = "丙"
            edit.isEnabled = false
            let edited = try await library.updateReplaceRule(id: replace.id, draft: edit, operationID: UUID().uuidString)
            XCTAssertEqual(edited.replacement, "丙")
            XCTAssertFalse(edited.isEnabled)
            let imported = try await library.importRuleBundle(json: bundle.json, replaceExisting: true, operationID: UUID().uuidString)
            XCTAssertTrue(imported.replaceExisting)
            let restoredRules = try await library.replaceRules()
            XCTAssertEqual(restoredRules.first { $0.id == replace.id }?.replacement, "乙")
            let deletedReplace = try await library.deleteReplaceRule(id: replace.id, operationID: UUID().uuidString)
            let deletedTOC = try await library.deleteTXTTOCRule(id: toc.id, operationID: UUID().uuidString)
            let deletedDictionary = try await library.deleteDictionaryRule(name: dictionary.name, operationID: UUID().uuidString)
            XCTAssertTrue(deletedReplace)
            XCTAssertTrue(deletedTOC)
            XCTAssertTrue(deletedDictionary)
            let finalBundle = try await library.exportRuleBundle()
            XCTAssertEqual(finalBundle.counts.replaceRules, 0)
            XCTAssertEqual(finalBundle.counts.txtTocRules, 0)
            XCTAssertEqual(finalBundle.counts.dictRules, 0)
            try await library.close()
        } catch {
            try? await library.close()
            throw error
        }
    }

    func testReadingTimeOriginalOperationDoesNotCountTwiceAndRecordsRemainCoreOwned() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = try service(root)
        let book = ReaderBook(bookId: "reading-record-unit", title: "记录合同边界", author: "合同测试")
        let operation = UUID().uuidString
        do {
            let first = try await library.accumulateReadingTime(for: book, deviceID: "unit-device", elapsedMillis: 500,
                                                                readAt: 1000, sequence: 1, operationID: operation)
            let repeated = try await library.accumulateReadingTime(for: book, deviceID: "unit-device", elapsedMillis: 500,
                                                                   readAt: 1000, sequence: 1, operationID: operation)
            XCTAssertEqual(first, repeated)
            XCTAssertEqual(first.readTime, 500)
            let next = try await library.accumulateReadingTime(for: book, deviceID: "unit-device", elapsedMillis: 250,
                                                               readAt: 1200, sequence: 2, operationID: UUID().uuidString)
            XCTAssertEqual(next.readTime, 750)
            let summary = try await library.readingSummary(query: nil, sortBy: .readTime)
            XCTAssertEqual(summary.totalReadTime, 750)
            XCTAssertEqual(summary.books.first?.bookName, book.title)
            let deleted = try await library.deleteReadingRecords(bookName: book.title, operationID: UUID().uuidString)
            XCTAssertEqual(deleted, 1)
            let records = try await library.readingRecords(deviceID: nil)
            XCTAssertTrue(records.isEmpty)
            try await library.close()
        } catch {
            try? await library.close()
            throw error
        }
    }
}
