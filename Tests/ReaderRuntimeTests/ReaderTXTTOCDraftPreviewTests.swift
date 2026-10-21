import CryptoKit
import Foundation
import XCTest
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

final class ReaderTXTTOCDraftPreviewTests: XCTestCase {
    func testRealOriginalDraftPreviewUsesWholeRulePriorityAndPreservesSourceRulesAndProgress() async throws {
        // Provisioned byte-for-byte from the user's Downloads original. Never
        // generate a book, rewrite this input or stage an import as a preview.
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let input = documents.appendingPathComponent("仙子请听我解释.txt")
        let original = try Data(contentsOf: input)
        let digest = "aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5"
        XCTAssertEqual(original.count, 8_871_723)
        XCTAssertEqual(sha(original), digest)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderRealTXTDraftPreview-" + UUID().uuidString)
        let library = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
                                               sourceURL: root.appendingPathComponent("Sources"))
        do {
            let imported = try await library.importBook(at: input)
            let book = imported.book
            XCTAssertTrue(imported.created); XCTAssertEqual(book.bookId, "local:" + digest)
            let retained = try await library.retainedSourceURL(for: book)
            let canonicalChapters = try await library.chapters(for: book)
            XCTAssertEqual(canonicalChapters.count, 948)
            let chapter = try XCTUnwrap(canonicalChapters.first { $0.index == 1 })
            let content = try await library.content(for: book, chapterIndex: chapter.index)
            XCTAssertGreaterThan(content.scalarCount, 37)
            let head = try await library.progress(for: book)
            let savedProgress = try await library.saveProgress(for: book, content: content, scalarOffset: 37,
                                                               expectedRevision: head.progressRevision)

            // Derive patterns only from genuine canonical titles returned by
            // Core. Foundation escapes literals; it never scans or splits TXT.
            let realTitles = canonicalChapters.dropFirst().prefix(128).map(\.title)
            XCTAssertEqual(realTitles.count, 128)
            let pattern = "^(?:" + realTitles.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|") + ")$"
            XCTAssertLessThanOrEqual(pattern.utf8.count, 16 * 1024)
            let saved = try await library.createTXTTOCRule(
                ReaderTXTTOCRuleDraft(name: "真实原文已保存优先规则", rule: pattern, serialNumber: -10),
                operationID: UUID().uuidString)
            let rulesBefore = try await library.txtTOCRules()
            XCTAssertEqual(rulesBefore, [saved])
            let tocBefore = try await library.coreRead("local_book.toc", ["bookId": book.bookId])
            let metadataBefore = try await library.bookDetails(for: book)
            let pendingBefore = try await library.pendingFeatureOperations()
            XCTAssertTrue(pendingBefore.isEmpty)

            let lowerDraft = ReaderTXTTOCRuleDraft(name: "尚未保存的真实目录草稿", rule: pattern, serialNumber: 5)
            let shadowed = try await library.previewTXTTOCRule(for: book, draft: lowerDraft, editingRuleID: nil, limit: 20)
            assertIdentity(shadowed, book: book, digest: digest, limit: 20)
            XCTAssertEqual(shadowed.draftStatus, .shadowed); XCTAssertFalse(shadowed.draftSelected)
            XCTAssertEqual(shadowed.selectedRule?.kind, .saved); XCTAssertEqual(shadowed.selectedRule?.ruleId, saved.id)
            XCTAssertGreaterThanOrEqual(shadowed.draftMatchCount, 4)
            XCTAssertFalse(shadowed.automaticFallback)

            var earlierDraft = lowerDraft; earlierDraft.serialNumber = -20
            let selected = try await library.previewTXTTOCRule(for: book, draft: earlierDraft, editingRuleID: nil, limit: 64)
            assertIdentity(selected, book: book, digest: digest, limit: 64)
            XCTAssertEqual(selected.draftStatus, .selected); XCTAssertTrue(selected.draftSelected)
            XCTAssertEqual(selected.selectedRule?.kind, .draft); XCTAssertNil(selected.selectedRule?.ruleId,
                "The simulated max-ID-plus-one must never become a saved identity")
            XCTAssertFalse(selected.automaticFallback)
            XCTAssertGreaterThan(selected.chapterCount, 64); XCTAssertEqual(selected.chapters.count, 64)
            XCTAssertTrue(selected.truncated)
            XCTAssertEqual(selected.savedRulesSha256, shadowed.savedRulesSha256)
            XCTAssertNotEqual(selected.draftSha256, shadowed.draftSha256)
            XCTAssertNotEqual(selected.effectiveRulesSha256, shadowed.effectiveRulesSha256)
            let one = try await library.previewTXTTOCRule(for: book, draft: earlierDraft, editingRuleID: nil, limit: 1)
            assertIdentity(one, book: book, digest: digest, limit: 1)
            XCTAssertEqual(one.draftSha256, selected.draftSha256, "Limit is not part of the immutable draft/editing identity")
            XCTAssertEqual(one.chapters, Array(selected.chapters.prefix(1)), "Changing the ceiling must preserve the actual Core scalar ranges")

            let edited = try await library.previewTXTTOCRule(for: book, draft: saved.draft, editingRuleID: saved.id, limit: 20)
            assertIdentity(edited, book: book, digest: digest, limit: 20)
            XCTAssertEqual(edited.draftStatus, .selected); XCTAssertEqual(edited.selectedRule?.kind, .draft)
            XCTAssertEqual(edited.selectedRule?.ruleId, saved.id)
            XCTAssertEqual(edited.savedRulesSha256, edited.effectiveRulesSha256,
                           "Editing the identical saved value substitutes its original ID rather than appending a second rule")

            // Replacing the only saved candidate in the simulated snapshot
            // also proves automatic fallback separately from draft matching.
            var disabledInvalid = saved.draft; disabledInvalid.rule = "("; disabledInvalid.enable = false
            let disabled = try await library.previewTXTTOCRule(for: book, draft: disabledInvalid, editingRuleID: saved.id, limit: 20)
            assertIdentity(disabled, book: book, digest: digest, limit: 20)
            XCTAssertEqual(disabled.draftStatus, .disabled); XCTAssertFalse(disabled.draftSelected)
            XCTAssertNotNil(disabled.regexError, "Disabled drafts retain the Core regex diagnostic")
            XCTAssertTrue(disabled.automaticFallback); XCTAssertNil(disabled.selectedRule)
            XCTAssertEqual(disabled.chapterCount, UInt32(canonicalChapters.count))
            XCTAssertEqual(disabled.chapters.map(\.title), canonicalChapters.prefix(20).map(\.title))
            var invalid = disabledInvalid; invalid.enable = true
            let invalidResult = try await library.previewTXTTOCRule(for: book, draft: invalid, editingRuleID: saved.id, limit: 20)
            assertIdentity(invalidResult, book: book, digest: digest, limit: 20)
            XCTAssertEqual(invalidResult.draftStatus, .invalidRegex); XCTAssertNotNil(invalidResult.regexError)
            XCTAssertTrue(invalidResult.automaticFallback)
            var empty = saved.draft; empty.rule = ""
            let emptyResult = try await library.previewTXTTOCRule(for: book, draft: empty, editingRuleID: saved.id, limit: 20)
            assertIdentity(emptyResult, book: book, digest: digest, limit: 20)
            XCTAssertEqual(emptyResult.draftStatus, .emptyPattern); XCTAssertEqual(emptyResult.draftMatchCount, 0)
            XCTAssertTrue(emptyResult.automaticFallback)
            var unmatched = saved.draft; unmatched.rule = "^" + UUID().uuidString + "$"
            let unmatchedResult = try await library.previewTXTTOCRule(for: book, draft: unmatched, editingRuleID: saved.id, limit: 20)
            assertIdentity(unmatchedResult, book: book, digest: digest, limit: 20)
            XCTAssertEqual(unmatchedResult.draftStatus, .noMatch); XCTAssertEqual(unmatchedResult.draftMatchCount, 0)
            XCTAssertTrue(unmatchedResult.automaticFallback)
            var oneTitle = saved.draft; oneTitle.rule = "^" + NSRegularExpression.escapedPattern(for: chapter.title) + "$"
            let insufficient = try await library.previewTXTTOCRule(for: book, draft: oneTitle, editingRuleID: saved.id, limit: 20)
            assertIdentity(insufficient, book: book, digest: digest, limit: 20)
            XCTAssertEqual(insufficient.draftStatus, .insufficientMatches)
            XCTAssertTrue((1...3).contains(insufficient.draftMatchCount)); XCTAssertTrue(insufficient.automaticFallback)

            let rulesAfter = try await library.txtTOCRules()
            let tocAfter = try await library.coreRead("local_book.toc", ["bookId": book.bookId])
            let metadataAfter = try await library.bookDetails(for: book)
            let progressAfter = try await library.progress(for: book)
            let pendingAfter = try await library.pendingFeatureOperations()
            XCTAssertEqual(rulesAfter, rulesBefore, "Every simulated edit/new/invalid draft must leave saved priorities and IDs unchanged")
            XCTAssertEqual(try canonicalJSON(tocAfter), try canonicalJSON(tocBefore))
            XCTAssertEqual(metadataAfter, metadataBefore)
            XCTAssertEqual(progressAfter.progress, savedProgress.progress, "Compare the actual complete Core progress row, not a preview fingerprint")
            XCTAssertEqual(pendingAfter, pendingBefore, "Preview must not create or settle a write, import preparation or reprocess intent")
            XCTAssertEqual(try Data(contentsOf: input), original)
            XCTAssertEqual(try Data(contentsOf: retained), original)
            let evidence = XCTAttachment(data: try JSONEncoder().encode(selected), uniformTypeIdentifier: "public.json")
            evidence.name = "Actual-TXT-draft-preview-Core-identity-and-ranges"; evidence.lifetime = .keepAlways; add(evidence)
            try await library.close()
            try FileManager.default.removeItem(at: root)
        } catch {
            try? await library.close()
            let evidence = XCTAttachment(string: root.path + "\n" + String(describing: error))
            evidence.name = "Original-TXT-draft-preview-failure-library"; evidence.lifetime = .keepAlways; add(evidence)
            throw error
        }
    }
    private func assertIdentity(_ result: ReaderTXTTOCRulePreview, book: ReaderBook, digest: String, limit: UInt32,
                                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(result.sourceId, "local", file: file, line: line)
        XCTAssertEqual(result.bookId, book.bookId, file: file, line: line)
        XCTAssertEqual(result.sourceSha256, digest, file: file, line: line)
        XCTAssertEqual(result.chapters.count, Int(min(result.chapterCount, limit)), file: file, line: line)
        XCTAssertEqual(result.truncated, result.chapterCount > limit, file: file, line: line)
        for value in result.chapters { XCTAssertLessThan(value.startScalar, value.endScalar, file: file, line: line) }
        for hash in [result.draftSha256, result.savedRulesSha256, result.effectiveRulesSha256] {
            XCTAssertEqual(hash.utf8.count, 64, file: file, line: line)
        }
    }
    private func sha(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func canonicalJSON(_ data: Data) throws -> Data {
        try JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: data), options: [.sortedKeys])
    }
}
