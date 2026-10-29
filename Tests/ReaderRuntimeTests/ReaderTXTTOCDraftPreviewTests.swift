import CryptoKit
import Foundation
import XCTest
import Combine
#if canImport(ReaderCoreClient)
import ReaderCoreClient
#endif
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif
#if canImport(Reader)
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
    func testRealGutenbergTXTDirectoryRuleReprocessDisableAndColdPreservesMigratedPosition() async throws {
        let initialFailureCount = testRun?.failureCount ?? 0
        let digest = "997442c1d041cc731d57bd164078a1dd6e98a5fe0eb9b6ec8b202edc3d0a5a38"
        let input = try ReaderLocalFormatsTests.originalURL(format: "txt", byteCount: 99_898, digest: digest)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderGutenbergTXTRule-" + UUID().uuidString)
        let core = root.appendingPathComponent("Core"), sources = root.appendingPathComponent("Sources")
        var library: ReaderLibraryService?, reopened: ReaderLibraryService?
        var stage = "create-isolated-library", observations: [[String: Any]] = []
        func require(_ condition: Bool, _ message: String) throws {
            guard condition else { throw ReaderLibraryError.invalidResponse("\(stage): \(message)") }
        }
        func attach(_ status: String, error: Error? = nil) throws {
            var facts: [String: Any] = ["status": status, "stage": stage, "library": root.path,
                "sourceSha256": digest, "sourceBytes": 99_898, "observations": observations,
                "scope": "ACTUAL_ISOLATED_CORE_HOST_CHAIN_NOT_NATIVE_UI"]
            if let error { facts["error"] = String(describing: error) }
            let value = XCTAttachment(data: try JSONSerialization.data(withJSONObject: facts, options: [.sortedKeys]),
                                      uniformTypeIdentifier: "public.json")
            value.name = "Actual-Gutenberg-TXT-rule-reprocess-position-stages"; value.lifetime = .keepAlways; add(value)
        }
        do {
            let active = try ReaderLibraryService(storageURL: core, sourceURL: sources); library = active
            stage = "import-original"
            let imported = try await active.importBook(at: input), book = imported.book
            try require(imported.created && !imported.finalizationPending && book.bookId == "local:" + digest, "original import ACK")
            let retained = try await active.retainedSourceURL(for: book)
            let chapters = try await active.chapters(for: book)
            try require(chapters.count == 10, "require the actual nine source headings plus intro")
            let headings = Array(chapters.dropFirst())
            try require(Set(headings.map(\.title)).count == 9, "source headings must be unique")
            let omitted = headings[headings.count / 2]
            let body = try await active.content(for: book, chapterIndex: omitted.index)
            try require(body.scalarCount >= 576, "the omitted middle chapter needs scalar512 plus a real64-scalar anchor")
            let anchor = String(body.content.unicodeScalars.dropFirst(512).prefix(64))
            let anchorSHA = sha(Data(anchor.utf8))
            let initial = try await active.progress(for: book)
            let saved = try await active.saveProgress(for: book, content: body, scalarOffset: 512,
                                                     expectedRevision: initial.progressRevision)
            let mark = try await active.createBookmark(for: book, content: body, scalarOffset: 512,
                text: anchor, note: "真实目录位置迁移", operationID: UUID().uuidString)
            let toc = try canonicalJSON(await active.coreRead("local_book.toc", ["bookId": book.bookId]))
            let initialRules = try await active.txtTOCRules()
            try require(initialRules.isEmpty, "the new isolated library must have no saved TXT rules")

            func observe(_ owner: ReaderLibraryService) async throws -> ReaderProgressSnapshot {
                let snapshot = try await owner.progress(for: book)
                let position = try XCTUnwrap(snapshot.progress)
                let current = try await owner.content(for: book, chapterIndex: position.chapterIndex)
                try require(snapshot.found && position.sourceId == book.sourceId && position.bookId == book.bookId,
                            "progress identity")
                try require(current.sourceId == book.sourceId && current.bookId == book.bookId &&
                    current.chapterIndex == position.chapterIndex && position.chapterOffset <= current.scalarCount &&
                    current.scalarCount - position.chapterOffset >= 64, "actual body range")
                try require(position.bodyVersion != nil && position.processingVersion != nil &&
                    position.bodyVersion == current.bodyVersion && position.processingVersion == current.processingVersion,
                    "progress versions must identify the actual body")
                let actual = String(current.content.unicodeScalars.dropFirst(Int(position.chapterOffset)).prefix(64))
                try require(actual == anchor, "same consecutive source64-scalar anchor at the migrated position")
                let marks = try await owner.bookmarks(for: book)
                let currentMark = try XCTUnwrap(marks.first { $0.time == mark.time })
                try require(currentMark.chapterIndex == Int32(position.chapterIndex) &&
                    currentMark.scalarOffset == position.chapterOffset && currentMark.bookText == anchor &&
                    currentMark.positionScope == (try ReaderContentPositionScope(book: book, content: current)),
                    "the original bookmark must migrate with the same actual position scope")
                observations.append(["stage": stage, "chapterIndex": position.chapterIndex,
                    "chapterTitle": current.chapterTitle, "scalarOffset": position.chapterOffset,
                    "bodyVersion": current.bodyVersion ?? "", "processingVersion": current.processingVersion ?? "",
                    "progress": try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)),
                    "bookmarkTime": mark.time, "anchorScalarCount": 64, "anchorSha256": anchorSHA])
                return snapshot
            }
            stage = "saved-original-position"
            try require(try await observe(active) == saved, "complete original progress receipt")
            // f322 scans the normalized original with a multiline regex, while
            // automatic titles trim their edges. Chapters2/7/9 have original
            // U+3000 indentation; preserve internal title bytes and allow only
            // horizontal edge whitespace, never consume a neighboring line.
            let titles = headings.filter { $0.index != omitted.index }.map(\.title)
            let pattern = "^[\\t \\u{3000}]*(?:" + titles.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|") + ")[\\t \\u{3000}]*$"
            let draft = ReaderTXTTOCRuleDraft(name: "阿Q真实中间章节边界合并", rule: pattern, serialNumber: -10)
            stage = "read-only-draft-preview"
            let preview = try await active.previewTXTTOCRule(for: book, draft: draft, editingRuleID: nil, limit: 64)
            observations.append(["stage": stage, "originalChapterCount": chapters.count, "omittedChapterIndex": omitted.index,
                "omittedChapterTitle": omitted.title, "draftMatchCount": preview.draftMatchCount,
                "previewChapterCount": preview.chapterCount, "draftStatus": preview.draftStatus.rawValue,
                "patternSha256": sha(Data(pattern.utf8))])
            try require(preview.sourceId == book.sourceId && preview.bookId == book.bookId && preview.sourceSha256 == digest &&
                preview.draftSelected && preview.draftStatus == .selected && preview.draftMatchCount >= 4 &&
                !preview.automaticFallback && !preview.truncated && preview.chapterCount < UInt32(chapters.count) &&
                !preview.chapters.contains(where: { $0.title == omitted.title }), "real draft must remove the intended boundary")
            try require(try canonicalJSON(await active.coreRead("local_book.toc", ["bookId": book.bookId])) == toc,
                        "preview must not change the actual directory")
            try require(try await active.progress(for: book) == saved, "preview must preserve the complete progress")
            try require(try await active.txtTOCRules() == initialRules, "preview must not save a rule")

            stage = "save-rule-without-reprocessing"
            let rule = try await active.createTXTTOCRule(draft, operationID: UUID().uuidString)
            observations.append(["stage": stage, "actualRuleID": rule.id])
            try require(rule.draft == draft, "actual saved rule ACK")
            try require(try await active.txtTOCRules() == [rule], "only this actual saved rule may exist")
            try require(try canonicalJSON(await active.coreRead("local_book.toc", ["bookId": book.bookId])) == toc,
                        "saving must not re-cut the directory")
            try require(try await observe(active) == saved, "saving alone must not move the original position")

            stage = "explicit-reprocess-migrates-position"
            let changed = try await active.reprocessLocalBook(book, operationID: UUID().uuidString)
            try require(!changed.created && !changed.finalizationPending && changed.book.id == book.id, "original reprocess ACK")
            let reparsed = try await active.chapters(for: book)
            try require(reparsed != chapters && reparsed.map(\.title) == preview.chapters.map(\.title),
                        "actual directory must match the preview over the same original and saved rule")
            let migrated = try await observe(active)
            let migratedPosition = try XCTUnwrap(migrated.progress)
            try require(migratedPosition.chapterIndex != omitted.index && migratedPosition.chapterOffset > 512,
                        "removing the saved position's boundary must actually move it into the preceding chapter")

            stage = "disable-original-rule-and-explicitly-restore"
            var disabled = rule.draft; disabled.enable = false
            let disabledRule = try await active.updateTXTTOCRule(id: rule.id, draft: disabled, operationID: UUID().uuidString)
            try require(disabledRule.id == rule.id && disabledRule.draft == disabled, "disable the original Core ID")
            let restored = try await active.reprocessLocalBook(book, operationID: UUID().uuidString)
            try require(!restored.created && !restored.finalizationPending && restored.book.id == book.id, "restore reprocess ACK")
            try require(try await active.chapters(for: book) == chapters, "automatic directory must be restored")
            try require(try canonicalJSON(await active.coreRead("local_book.toc", ["bookId": book.bookId])) == toc,
                        "the complete original automatic TOC must return")
            let restoredProgress = try await observe(active)
            try require(restoredProgress.progress?.chapterIndex == omitted.index && restoredProgress.progress?.chapterOffset == 512,
                        "the same source position must return to its original automatic chapter and offset")

            stage = "delete-only-owned-rule"
            try require(try await active.deleteTXTTOCRule(id: rule.id, operationID: UUID().uuidString), "actual delete ACK")
            try require(try await active.txtTOCRules().isEmpty, "the owned rule must be absent")
            try require(try await active.pendingImports().isEmpty, "no unfinished import or reprocess")
            try require(try await active.pendingFeatureOperations().isEmpty, "no unfinished feature operation")
            try await active.close()

            stage = "cold-reopen-independent-library"
            let cold = try ReaderLibraryService(storageURL: core, sourceURL: sources); reopened = cold
            try require(try await cold.listBooks().map(\.id) == [book.id], "the independent shelf contains only the real imported book")
            try require(try await cold.chapters(for: book) == chapters, "cold original directory")
            try require(try canonicalJSON(await cold.coreRead("local_book.toc", ["bookId": book.bookId])) == toc, "cold complete TOC")
            let coldProgress = try await observe(cold)
            // The CAS revision includes SqliteStorage's per-open epoch. Its
            // current token is distinct from the complete persisted position.
            try require(coldProgress.found == restoredProgress.found && coldProgress.progress == restoredProgress.progress,
                        "cold complete persisted progress row must remain unchanged")
            try require(coldProgress.progressRevision?.isEmpty == false, "cold current Core CAS token must be available")
            try require(try await cold.txtTOCRules().isEmpty, "deleted rule stays absent after reopening")
            try require(try await cold.pendingImports().isEmpty, "cold import pending must be empty")
            try require(try await cold.pendingFeatureOperations().isEmpty, "cold feature pending must be empty")
            let coldRetained = try await cold.retainedSourceURL(for: book)
            for url in [input, retained, coldRetained] {
                let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
                try require(bytes.count == 99_898 && sha(bytes) == digest, "original and retained raw bytes must be unchanged")
            }
            try await cold.close()
            stage = "completed"
            try require((testRun?.failureCount ?? initialFailureCount) == initialFailureCount,
                        "any XCTest assertion failure must preserve the owned library")
            try attach("PASS_REAL_CORE_HOST_CHAIN_ONLY")
            try FileManager.default.removeItem(at: root)
        } catch {
            if let library { try? await library.close() }
            if let reopened { try? await reopened.close() }
            try? attach("FAIL_PRESERVED_OWNED_LIBRARY", error: error)
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

#if canImport(Reader)
/// Controlled metadata exercises the production workspace's read identity.
/// These results are not generated books, provider inputs or format acceptance.
@MainActor
extension ReaderTXTTOCDraftPreviewTests {
    /// Exercises the production deletion/ActionOwner path with controlled
    /// service Bool/throw outcomes, not a Core receipt or native UI claim.
    func testConfirmedRuleDeletionPreservesLatestDraftAndRetiresOnlyItsEditor() async throws {
        for kind in [ReaderRuleWorkspace.Kind.replace, .txt] {
            for edit in 0..<3 {
                let domain = "ReaderRuleDeleteSuccess-" + UUID().uuidString
                let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
                defer { defaults.removePersistentDomain(forName: domain) }
                let (state, projection) = deletionWorkspace(kind: kind, defaults: defaults)
                let actions = ReaderLibraryActionOwner(), id: Int64 = kind == .replace ? 7 : 11
                let input = state.captureRuleDeletion(kind: kind, id: id)
                let entered = expectation(description: "Actual deletion adapter entered")
                var reply: CheckedContinuation<Bool, Error>?
                var calls = 0
                let task = Task { await state.deleteRule(input, actions: actions, scope: "controlled-rule-owner|controlled-chapter", label: "Controlled deletion") { actualKind, actualID, operationID in
                    XCTAssertEqual(actualKind, kind); XCTAssertEqual(actualID, id); XCTAssertFalse(operationID.isEmpty)
                    calls += 1
                    return try await withCheckedThrowingContinuation { reply = $0; entered.fulfill() }
                } }
                await fulfillment(of: [entered], timeout: 3)
                XCTAssertTrue(actions.hasPending)
                if edit != 0 {
                    if kind == .replace {
                        let name = state.replaceDraft.name; state.replaceDraft.name = "Latest unsaved input"
                        if edit == 2 { state.replaceDraft.name = name }
                    } else {
                        let name = state.txtDraft.name; state.txtDraft.name = "Latest unsaved input"
                        if edit == 2 { state.txtDraft.name = name }
                    }
                }
                let expected = try encodedRuleDrafts(state)
                try XCTUnwrap(reply).resume(returning: true)
                let confirmed = await task.value
                XCTAssertTrue(confirmed); XCTAssertFalse(actions.hasPending); XCTAssertEqual(calls, 1)
                XCTAssertEqual(state.editingReplace, kind == .replace ? nil : 7)
                XCTAssertEqual(state.editingTXT, kind == .txt ? nil : 11)
                XCTAssertEqual(try encodedRuleDrafts(state), expected)
                let cold = ReaderRuleWorkspace(identity: "controlled-rule-owner|controlled-chapter", defaults: defaults)
                XCTAssertEqual(cold.editingReplace, state.editingReplace); XCTAssertEqual(cold.editingTXT, state.editingTXT)
                XCTAssertEqual(try encodedRuleDrafts(cold), expected, "Latest draft survives after the deleted target retires")
                withExtendedLifetime(projection) {}
            }
        }
    }

    func testRuleDeletionRejectsFalseUnknownAndLateACKForChangedOrReopenedEditor() async throws {
        for kind in [ReaderRuleWorkspace.Kind.replace, .txt] {
            for boundary in 0..<9 {
                let domain = "ReaderRuleDeleteRetired-" + UUID().uuidString
                let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
                defer { defaults.removePersistentDomain(forName: domain) }
                let (state, projection) = deletionWorkspace(kind: kind, defaults: defaults)
                let actions = ReaderLibraryActionOwner(), id: Int64 = kind == .replace ? 7 : 11
                let input = state.captureRuleDeletion(kind: kind, id: id)
                // The confirmation retains the original identity even if its
                // editor is explicitly selected again before dispatch.
                if boundary == 8 {
                    if kind == .replace { state.editingReplace = id } else { state.editingTXT = id }
                }
                let entered = expectation(description: "Original delete service continuation entered")
                var reply: CheckedContinuation<Bool, Error>?, operationID = ""
                let task = Task { await state.deleteRule(input, actions: actions, scope: "controlled-rule-owner|controlled-chapter", label: "Controlled deletion") { actualKind, actualID, actualOperation in
                    XCTAssertEqual(actualKind, kind); XCTAssertEqual(actualID, id); operationID = actualOperation
                    return try await withCheckedThrowingContinuation { reply = $0; entered.fulfill() }
                } }
                await fulfillment(of: [entered], timeout: 3)
                switch boundary {
                case 3, 4:
                    if kind == .replace { state.editingReplace = 19; if boundary == 4 { state.editingReplace = id } }
                    else { state.editingTXT = 19; if boundary == 4 { state.editingTXT = id } }
                case 5:
                    if kind == .replace { state.editingReplace = id } else { state.editingTXT = id }
                case 6:
                    state.retireReplacementReader()
                    state.observeReplacementReader(projection.$reader, bookID: "controlled-rule-owner|controlled-chapter")
                case 7: state.kind = .dictionary; state.kind = kind
                default: break
                }
                let replacementID = state.editingReplace, txtID = state.editingTXT
                let persisted = defaults.data(forKey: "reader.toolDrafts.v1.controlled-rule-owner|controlled-chapter")
                let drafts = try encodedRuleDrafts(state), terminal = try XCTUnwrap(reply)
                if boundary == 1 { terminal.resume(throwing: ReplacementReadFailure.controlled) }
                else if boundary == 2 { terminal.resume(throwing: ReaderLibraryError.operationPending(operationID)) }
                else { terminal.resume(returning: boundary != 0) }
                let confirmed = await task.value
                XCTAssertEqual(confirmed, boundary != 1 && boundary != 2)
                XCTAssertEqual(state.editingReplace, replacementID); XCTAssertEqual(state.editingTXT, txtID)
                XCTAssertEqual(try encodedRuleDrafts(state), drafts)
                XCTAssertEqual(defaults.data(forKey: "reader.toolDrafts.v1.controlled-rule-owner|controlled-chapter"), persisted)
            }
        }
    }

    func testRuleDeletionOriginalActionResumeRetiresOnlyTheStillCurrentEditor() async throws {
        for kind in [ReaderRuleWorkspace.Kind.replace, .txt] {
            for reopen in [false, true] {
                let domain = "ReaderRuleDeleteResume-" + UUID().uuidString
                let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
                defer { defaults.removePersistentDomain(forName: domain) }
                let (state, projection) = deletionWorkspace(kind: kind, defaults: defaults)
                let actions = ReaderLibraryActionOwner(), id: Int64 = kind == .replace ? 7 : 11
                let input = state.captureRuleDeletion(kind: kind, id: id)
                var calls: [String] = []
                let initial = await state.deleteRule(input, actions: actions, scope: "controlled-rule-owner|controlled-chapter", label: "Controlled deletion") { actualKind, actualID, operationID in
                    XCTAssertEqual(actualKind, kind); XCTAssertEqual(actualID, id); calls.append(operationID)
                    if calls.count == 1 { throw ReaderLibraryError.operationPending(operationID) }
                    return true
                }
                XCTAssertFalse(initial); XCTAssertTrue(actions.hasPending)
                if reopen {
                    state.retireReplacementReader()
                    state.observeReplacementReader(projection.$reader, bookID: "controlled-rule-owner|controlled-chapter")
                }
                state.replaceDraft.name = "Latest replacement draft"; state.txtDraft.name = "Latest TXT draft"
                let drafts = try encodedRuleDrafts(state)
                let resumed = await actions.resumeOriginal()
                XCTAssertTrue(resumed); XCTAssertFalse(actions.hasPending)
                XCTAssertEqual(calls.count, 2); XCTAssertEqual(calls.first, calls.last)
                XCTAssertEqual(state.editingReplace, !reopen && kind == .replace ? nil : 7)
                XCTAssertEqual(state.editingTXT, !reopen && kind == .txt ? nil : 11)
                XCTAssertEqual(try encodedRuleDrafts(state), drafts)
            }
        }
    }

    private func deletionWorkspace(kind: ReaderRuleWorkspace.Kind, defaults: UserDefaults) -> (ReaderRuleWorkspace, ReplacementReaderProjection) {
        let state = ReaderRuleWorkspace(identity: "controlled-rule-owner|controlled-chapter", defaults: defaults)
        state.kind = kind; state.replaceDraft = replacementRule().draft
        state.txtDraft = .init(name: "Controlled TXT draft", rule: "^Chapter", example: "Metadata only", serialNumber: 3, enable: false)
        state.editingReplace = 7; state.editingTXT = 11
        let projection = ReplacementReaderProjection(replacementSession(replacementContext()))
        state.observeReplacementReader(projection.$reader, bookID: "controlled-rule-owner|controlled-chapter")
        return (state, projection)
    }

    private func encodedRuleDrafts(_ state: ReaderRuleWorkspace) throws -> [Data] {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return [try encoder.encode(state.replaceDraft), try encoder.encode(state.txtDraft), try encoder.encode(state.dictionaryDraft)]
    }

    func testReplacementPreviewBindsCurrentChapterVersionsAndInvalidatesChangedInputs() async throws {
        let domain = "ReaderReplacementPreviewBinding-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let state = ReaderRuleWorkspace(identity: "controlled-rule-owner", defaults: defaults)
        let context = replacementContext()
        let value = replacementValue(context)
        let invalidations: [(ReaderRuleWorkspace) -> Void] = [
            { $0.setReplacementContext(nil); $0.setReplacementContext(context) },
            { $0.setReplacementContext(self.replacementContext(chapter: 1)) },
            { $0.setReplacementContext(self.replacementContext(body: "body-b")) },
            { $0.setReplacementContext(self.replacementContext(processing: "processing-b")) },
            { $0.setReplacementContext(self.replacementContext(restoration: UUID())) },
            { $0.replaceDraft.pattern = "changed"; $0.replaceDraft.pattern = "" },
            { $0.editingReplace = 7; $0.editingReplace = nil },
            { $0.replaceRules = [self.replacementRule()]; $0.replaceRules = [] },
            { $0.kind = .txt; $0.kind = .replace }
        ]
        for invalidate in invalidations {
            await state.previewReplacement(context: context, read: { _ in value }, isCurrent: { true }).value
            XCTAssertEqual(state.replacementPreview, value)
            XCTAssertTrue(state.replacementPreviewBelongs(to: context))
            XCTAssertFalse(state.replacementPreviewBelongs(to: replacementContext(chapter: 1)))
            invalidate(state)
            XCTAssertNil(state.replacementPreview)
            XCTAssertNil(state.replacementPreviewInput)
            XCTAssertFalse(state.replacementPreviewLoading)
        }
        await state.previewReplacement(context: context, read: { _ in throw ReplacementReadFailure.controlled }, isCurrent: { true }).value
        XCTAssertNotNil(state.replacementPreviewFailure, "A current failed read must remain explicitly retryable")
        await state.previewReplacement(context: context, read: { _ in value }, isCurrent: { true }).value
        XCTAssertEqual(state.replacementPreview, value)
        XCTAssertNil(state.replacementPreviewFailure)
        let unversioned = replacementContext(body: nil)
        await state.previewReplacement(context: unversioned, read: { _ in
            XCTFail("Missing authoritative versions cannot dispatch another preview"); return value
        }, isCurrent: { true }).value
        XCTAssertNil(state.replacementPreview)
        XCTAssertNotNil(state.replacementPreviewFailure)
    }

    func testReplacementPreviewRetiresLateSuccessFailureAndABAAcrossReopenedReaderAndRules() async throws {
        for fails in [false, true] {
            for boundary in 0..<9 {
                let domain = "ReaderReplacementPreviewLate-" + UUID().uuidString
                let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
                defer { defaults.removePersistentDomain(forName: domain) }
                let state = ReaderRuleWorkspace(identity: "controlled-rule-owner", defaults: defaults)
                let context = replacementContext()
                let projection = ReplacementReaderProjection(replacementSession(context))
                state.observeReplacementReader(projection.$reader, bookID: "controlled-rule-owner|controlled-chapter")
                let oldValue = replacementValue(context)
                let entered = expectation(description: "The original replacement preview read entered")
                var reply: CheckedContinuation<ReaderReplacePreview, Error>?
                var current = true
                let original = state.previewReplacement(context: context, read: { _ in
                    try await withCheckedThrowingContinuation { reply = $0; entered.fulfill() }
                }, isCurrent: { current })
                await fulfillment(of: [entered], timeout: 3)
                let originalReply = try XCTUnwrap(reply)
                switch boundary {
                case 0:
                    state.retireReplacementReader()
                    state.observeReplacementReader(projection.$reader, bookID: "controlled-rule-owner|controlled-chapter")
                case 1:
                    projection.reader = replacementSession(replacementContext(chapter: 1))
                    projection.reader = replacementSession(context)
                case 2:
                    projection.reader = replacementSession(replacementContext(body: "body-b"))
                    projection.reader = replacementSession(context)
                case 3:
                    projection.reader = replacementSession(replacementContext(processing: "processing-b"))
                    projection.reader = replacementSession(context)
                case 4: state.replaceDraft.pattern = "changed"; state.replaceDraft.pattern = ""
                case 5: state.replaceRules = [replacementRule()]; state.replaceRules = []
                case 6: state.kind = .txt; state.kind = .replace
                case 7: current = false
                default:
                    await state.previewReplacement(context: context, read: { _ in oldValue }, isCurrent: { true }).value
                }
                if fails { originalReply.resume(throwing: ReplacementReadFailure.controlled) }
                else { originalReply.resume(returning: oldValue) }
                await original.value
                if boundary == 8 { XCTAssertEqual(state.replacementPreview, oldValue, "A retired read cannot remove its successor") }
                else { XCTAssertNil(state.replacementPreview) }
                XCTAssertNil(state.replacementPreviewFailure)
                XCTAssertFalse(state.replacementPreviewLoading)
                state.retireReplacementReader()
            }
        }
    }

    func testDictionaryQueryRetiresChangedInputsLateSuccessFailureABAAndReopenedPresentation() async throws {
        // Controlled transport terminals exercise the exact workspace entry
        // used by the panel. This is not a real dictionary/network result.
        for fails in [false, true] {
            for boundary in 0..<11 {
                let domain = "ReaderDictionaryReadOwner-" + UUID().uuidString
                let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
                defer { defaults.removePersistentDomain(forName: domain) }
                let context = replacementContext()
                let state = ReaderRuleWorkspace(identity: "controlled-rule-owner|controlled-chapter", defaults: defaults)
                let projection = ReplacementReaderProjection(replacementSession(context))
                state.kind = .dictionary
                state.dictionaryDraft = .init(name: "Controlled dictionary")
                state.dictionaryWord = "original word"
                state.observeReplacementReader(projection.$reader, bookID: "controlled-rule-owner|controlled-chapter")
                let initial = try XCTUnwrap(state.queryDictionary { _, _ in "confirmed definition" })
                await initial.value
                XCTAssertEqual(state.dictionaryResult, "confirmed definition")
                state.dictionaryWord = "other word"
                XCTAssertNil(state.dictionaryResult, "Editing the displayed word immediately retires its definition")
                state.dictionaryWord = "original word"

                let entered = expectation(description: "Original controlled dictionary read entered")
                var reply: CheckedContinuation<String, Error>?
                let original = try XCTUnwrap(state.queryDictionary { name, word in
                    XCTAssertEqual(name, "Controlled dictionary"); XCTAssertEqual(word, "original word")
                    return try await withCheckedThrowingContinuation { reply = $0; entered.fulfill() }
                })
                await fulfillment(of: [entered], timeout: 3)
                let originalReply = try XCTUnwrap(reply)
                var expectedResult: String?
                var expectedFailure: String?
                switch boundary {
                case 0: state.dictionaryWord = "other word"; state.dictionaryWord = "original word"
                case 1: state.dictionaryDraft.name = "other dictionary"; state.dictionaryDraft.name = "Controlled dictionary"
                case 2: state.dictionaryDraft.showRule = "changed raw rule"; state.dictionaryDraft.showRule = ""
                case 3:
                    state.dictionaryRules = [.init(name: "changed saved rule")]
                    state.dictionaryRules = []
                case 4: state.kind = .hierarchy; state.kind = .dictionary
                case 5:
                    state.retireReplacementReader()
                    state.observeReplacementReader(projection.$reader, bookID: "controlled-rule-owner|controlled-chapter")
                case 6:
                    projection.reader = replacementSession(replacementContext(chapter: 1))
                    projection.reader = replacementSession(context)
                case 7:
                    let successor = try XCTUnwrap(state.queryDictionary { _, _ in "new definition" })
                    await successor.value; expectedResult = "new definition"
                case 8:
                    let successor = try XCTUnwrap(state.queryDictionary { _, _ in
                        throw NSError(domain: "ControlledRuleRead", code: 2,
                                      userInfo: [NSLocalizedDescriptionKey: "Current dictionary failure"])
                    })
                    await successor.value; expectedFailure = "Current dictionary failure"
                case 9: state.invalidateRuleReadsForMutation()
                default: state.retireReplacementReader()
                }
                if fails {
                    originalReply.resume(throwing: NSError(domain: "ControlledRuleRead", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Retired dictionary failure"]))
                } else { originalReply.resume(returning: "retired definition") }
                await original.value
                XCTAssertEqual(state.dictionaryResult, expectedResult, "boundary=\(boundary), fails=\(fails)")
                XCTAssertEqual(state.dictionaryFailure, expectedFailure, "A retired failure cannot replace its successor")
                XCTAssertFalse(state.dictionaryLoading)
                if boundary == 10 {
                    XCTAssertNil(state.queryDictionary { _, _ in XCTFail("A retired presentation cannot dispatch"); return "" })
                }
            }
        }
    }

    func testHierarchyRuleReadPreservesDraftAcrossLateSuccessFailureABAAndReopenedPresentation() async throws {
        // Directory DTOs and held transport terminals are controlled owner
        // evidence. No Core parser, source book, device or network is exercised.
        for previewFirst in [false, true] {
            for fails in [false, true] {
                for boundary in 0..<10 {
                    let domain = "ReaderHierarchyReadOwner-" + UUID().uuidString
                    let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
                    defer { defaults.removePersistentDomain(forName: domain) }
                    let identity = "controlled-rule-owner|controlled-chapter", context = replacementContext()
                    let state = ReaderRuleWorkspace(identity: identity, defaults: defaults)
                    let projection = ReplacementReaderProjection(replacementSession(context))
                    state.kind = .hierarchy; state.hierarchyJSON = "[]"
                    state.observeReplacementReader(projection.$reader, bookID: identity)
                    let initial = try XCTUnwrap(state.previewHierarchy { self.hierarchyValue(context, pattern: "confirmed") })
                    await initial.value
                    XCTAssertNotNil(state.hierarchyPreview)
                    state.hierarchyJSON = "[ ]"
                    XCTAssertNil(state.hierarchyPreview, "Raw edits synchronously invalidate the displayed preview")
                    state.hierarchyJSON = "[]"

                    let entered = expectation(description: "Original controlled hierarchy read entered")
                    var reply: CheckedContinuation<ReaderDirectoryRulesResult, Error>?
                    let read: () async throws -> ReaderDirectoryRulesResult = {
                        try await withCheckedThrowingContinuation { reply = $0; entered.fulfill() }
                    }
                    let original = try XCTUnwrap(previewFirst ? state.previewHierarchy(read: read) : state.loadHierarchy(read: read))
                    await fulfillment(of: [entered], timeout: 3)
                    let originalReply = try XCTUnwrap(reply)
                    var expectedPreview: ReaderDirectoryRulesResult?
                    var expectedFailure: String?
                    switch boundary {
                    case 0: state.hierarchyJSON = "[ ]"; state.hierarchyJSON = "[]"
                    case 1: state.hierarchyJSON = "[] "; state.hierarchyJSON = "[]"
                    case 2: state.kind = .dictionary; state.kind = .hierarchy
                    case 3:
                        state.retireReplacementReader()
                        state.observeReplacementReader(projection.$reader, bookID: identity)
                    case 4:
                        projection.reader = replacementSession(replacementContext(chapter: 1))
                        projection.reader = replacementSession(context)
                    case 5:
                        let value = hierarchyValue(context, pattern: "new saved rule")
                        let successor = try XCTUnwrap(state.loadHierarchy { value })
                        await successor.value; expectedPreview = value
                        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                        XCTAssertEqual(state.hierarchyJSON, String(decoding: try encoder.encode(value.rules ?? []), as: UTF8.self))
                    case 6:
                        let value = hierarchyValue(context, pattern: "new preview")
                        let successor = try XCTUnwrap(state.previewHierarchy { value })
                        await successor.value; expectedPreview = value
                        XCTAssertEqual(state.hierarchyJSON, "[]", "Preview must not replace or persist the draft")
                    case 7:
                        let successor = try XCTUnwrap(state.loadHierarchy {
                            throw NSError(domain: "ControlledRuleRead", code: 2,
                                          userInfo: [NSLocalizedDescriptionKey: "Current hierarchy failure"])
                        })
                        await successor.value; expectedFailure = "Current hierarchy failure"
                    case 8: state.invalidateRuleReadsForMutation()
                    default: state.retireReplacementReader()
                    }
                    let expectedDraft = state.hierarchyJSON
                    let persisted = defaults.data(forKey: "reader.toolDrafts.v1." + identity)
                    if fails {
                        originalReply.resume(throwing: NSError(domain: "ControlledRuleRead", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Retired hierarchy failure"]))
                    } else { originalReply.resume(returning: hierarchyValue(context, pattern: "retired saved rule")) }
                    await original.value
                    XCTAssertEqual(state.hierarchyJSON, expectedDraft, "boundary=\(boundary), fails=\(fails), preview=\(previewFirst)")
                    XCTAssertEqual(defaults.data(forKey: "reader.toolDrafts.v1." + identity), persisted,
                                   "Neither a retired get nor preview may overwrite the persisted draft")
                    XCTAssertEqual(ReaderRuleWorkspace(identity: identity, defaults: defaults).hierarchyJSON, expectedDraft)
                    XCTAssertEqual(state.hierarchyPreview, expectedPreview)
                    XCTAssertEqual(state.hierarchyPreviewInput, expectedPreview == nil ? nil : expectedDraft)
                    XCTAssertEqual(state.hierarchyFailure, expectedFailure)
                    XCTAssertNil(state.failure, "Read failures belong to the current hierarchy request")
                    XCTAssertFalse(state.hierarchyLoading)
                    if boundary == 9 {
                        XCTAssertNil(state.loadHierarchy { XCTFail("A retired presentation cannot dispatch"); return self.hierarchyValue(context) })
                    }
                }
            }
        }
    }

    private func hierarchyValue(_ context: ReaderRuleWorkspace.ReplacementContext, pattern: String = "controlled") -> ReaderDirectoryRulesResult {
        .init(status: "ready", sourceId: context.sourceID, bookId: context.bookID, reason: nil,
              structureRevision: "controlled-structure", navigationRevision: "controlled-navigation", nodeCount: 0,
              readableChapterCount: 0, unmappedCount: 0, nodes: [], rules: [.init(pattern: pattern, level: 1, boundary: .title)])
    }

    func testRealOriginalReplacementPreviewRejectsStaleVersionsAndActualRulesHeadABAWithoutSourceChanges() async throws {
        let digest = "aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5"
        let input = try ReaderLocalFormatsTests.originalURL(format: "txt", byteCount: 8_871_723, digest: digest)
        let original = try Data(contentsOf: input, options: .mappedIfSafe)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderBoundReplacementPreview-" + UUID().uuidString)
        let gate = try StagingCoreGate(storage: root.appendingPathComponent("Core"))
        defer { gate.release(); gate.destroy(); try? FileManager.default.removeItem(at: root) }
        let library = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
            sourceURL: root.appendingPathComponent("Sources"), client: gate, timing: gate.timing)
        var previewTask: Task<ReaderReplacePreview, Error>?
        do {
            let book = try await library.importBook(at: input).book
            let content = try await library.content(for: book, chapterIndex: 0)
            let rules = try await library.replaceRules()
            XCTAssertTrue(rules.isEmpty)
            let preview = try await library.previewReplacement(for: book, content: content, expectedRules: rules, maxScalars: 2048)
            XCTAssertEqual(preview.sourceId, content.sourceId); XCTAssertEqual(preview.bookId, content.bookId)
            XCTAssertEqual(preview.chapterIndex, content.chapterIndex)
            let stale = ReaderChapterContent(sourceId: content.sourceId, bookId: content.bookId,
                chapterIndex: content.chapterIndex, chapterTitle: content.chapterTitle, content: content.content,
                bodyVersion: content.bodyVersion, processingVersion: (content.processingVersion ?? "") + "-stale", blocks: content.blocks)
            do {
                _ = try await library.previewReplacement(for: book, content: stale, expectedRules: rules, maxScalars: 2048)
                XCTFail("A real current Core chapter cannot admit a different supplied processing version")
            } catch is ReaderReplacementPreviewChanged { }

            let headBefore = try await library.coreRead("rules.mutation.query", [:])
            let entered = expectation(description: "The original actual Core preview terminal is retained")
            gate.hold("replace.preview", advanceObserverDeadline: false)
            gate.onHeld = { entered.fulfill() }
            let running = Task {
                try await library.previewReplacement(for: book, content: content, expectedRules: rules, maxScalars: 2048)
            }
            previewTask = running
            await fulfillment(of: [entered], timeout: 30)
            // Mutate the real pinned Core's rules head A -> B -> A. The rule is
            // disabled and cannot transform the genuine original's text.
            let added = try await library.createReplaceRule(.init(name: "Actual rules-lineage boundary",
                pattern: UUID().uuidString, isEnabled: false, isRegex: false), operationID: UUID().uuidString)
            _ = try await library.deleteReplaceRule(id: added.id, operationID: UUID().uuidString)
            let rulesAfter = try await library.replaceRules()
            XCTAssertEqual(rulesAfter, rules)
            let contentAfter = try await library.content(for: book, chapterIndex: content.chapterIndex)
            XCTAssertEqual(contentAfter.bodyVersion, content.bodyVersion,
                "The actual body version must remain unchanged so it cannot substitute for the head guard")
            XCTAssertEqual(contentAfter.processingVersion, content.processingVersion,
                "The actual processing version must remain unchanged so the rejection independently exercises the head")
            let headAfter = try await library.coreRead("rules.mutation.query", [:])
            XCTAssertNotEqual(try canonicalJSON(headAfter), try canonicalJSON(headBefore))
            gate.release()
            do {
                _ = try await running.value
                XCTFail("Matching final rules cannot re-admit a preview across the real intervening Core head")
            } catch is ReaderReplacementPreviewChanged { }
            let pending = try await library.pendingCoreCommands()
            XCTAssertTrue(pending.isEmpty)
            XCTAssertEqual(try Data(contentsOf: input), original)
            let retained = try await library.retainedSourceURL(for: book)
            XCTAssertEqual(try Data(contentsOf: retained), original)
            try await library.close()
        } catch {
            gate.release()
            if let previewTask { _ = try? await previewTask.value }
            try? await library.close()
            throw error
        }
    }

    private enum ReplacementReadFailure: Error { case controlled }
    private func replacementContext(chapter: UInt32 = 0, body: String? = "body-a", processing: String? = "processing-a",
                                    restoration: UUID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!) -> ReaderRuleWorkspace.ReplacementContext {
        .init(sessionID: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, restorationID: restoration,
            sourceID: "controlled-rule-owner", bookID: "controlled-chapter", chapterIndex: chapter,
            bodyVersion: body, processingVersion: processing)
    }
    private func replacementValue(_ context: ReaderRuleWorkspace.ReplacementContext) -> ReaderReplacePreview {
        .init(sourceId: context.sourceID, bookId: context.bookID, chapterIndex: context.chapterIndex,
            chapterTitle: "Controlled read identity", before: "Controlled original", after: "Controlled result", changed: true,
            truncated: false, storedRuleCount: 0, enabledRuleCount: 0)
    }
    private func replacementSession(_ context: ReaderRuleWorkspace.ReplacementContext) -> ReaderActiveSession {
        .init(id: context.sessionID,
            book: ReaderBook(sourceId: context.sourceID, bookId: context.bookID, title: "Controlled owner metadata"),
            chapters: [], content: .init(sourceId: context.sourceID, bookId: context.bookID, chapterIndex: context.chapterIndex,
                chapterTitle: "Controlled owner metadata", content: "", bodyVersion: context.bodyVersion, processingVersion: context.processingVersion),
            scalarOffset: 0, restorationID: context.restorationID)
    }
    private func replacementRule() -> ReaderReplaceRule {
        .init(id: 7, name: "Controlled saved rule", group: nil, pattern: "original", replacement: "result", scope: nil,
            scopeTitle: false, scopeSource: false, scopeContent: true, excludeScope: nil,
            isEnabled: true, isRegex: false, timeoutMillisecond: 3000, order: 0)
    }
}

@MainActor
private final class ReplacementReaderProjection: ObservableObject {
    @Published var reader: ReaderActiveSession?
    init(_ reader: ReaderActiveSession) { self.reader = reader }
}
#endif
