import Foundation
import ReaderCoreBridge
import ReaderHost
import XCTest
@testable import ReaderApp

@MainActor
extension M2BusinessJourneyTests {
    @objc func test05ConditionalSourceEditConflictsAndPreservesRules() async throws {
        let root = try m2Support().appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let (library, network) = try await m2Open(root, fresh: true)
        let runtime = library.runtime
        let input = M2BusinessFixture.Source(suite: "edits", edition: "primary")
        let manager = SourceManagementCoordinator(runtime: runtime, network: network)
        _ = try await m2Import(input, with: manager)
        let original = try await manager.list(.init(sourceId: input.id))
        let source = try XCTUnwrap(original.sources.first)
        let originalRevision = try XCTUnwrap(source.sourceVersion)
        let revisionName = "回环来源修订"
        let staleName = "旧编辑窗口不可覆盖"
        let new = try editParams(source, name: revisionName)
        do {
            _ = try await manager.saveEdit(new, expectedVersion: "invalid")
            XCTFail("Malformed expectedVersion must not reserve an original operation")
        } catch SourceManagementCoordinator.Failure.invalidDraft {
            XCTAssertNil(manager.pendingMutation)
        }
        let applied = try await manager.saveEdit(new, expectedVersion: originalRevision)
        guard case .sourceImport(let receipt) = applied else {
            XCTFail("Conditional source.import should return its applied receipt")
            throw M2BusinessFixture.Failure.incorrectProtocolVariant
        }
        let exactEdit = try await querySourceEdit(manager, params: new, expectedVersion: originalRevision, binding: receipt.binding)
        guard case .sourceImport(let replay)? = exactEdit else {
            XCTFail("Exact readback did not find original applied source edit")
            throw M2BusinessFixture.Failure.incorrectProtocolVariant
        }
        XCTAssertEqual(receipt.ackFingerprint, replay.ackFingerprint)
        let current = try await manager.list(.init(sourceId: input.id))
        let updated = try XCTUnwrap(current.sources.first)
        let revised = try XCTUnwrap(updated.sourceVersion)
        XCTAssertEqual(updated.name, revisionName)
        XCTAssertNotEqual(revised, originalRevision)
        XCTAssertEqual(updated.bookSource?["ruleSearch"], source.bookSource?["ruleSearch"])
        XCTAssertEqual(updated.bookSource?["ruleContent"], source.bookSource?["ruleContent"])

        let stale = try editParams(source, name: staleName)
        let rejected = try await manager.saveEdit(stale, expectedVersion: originalRevision)
        guard case .rejected(let conflict) = rejected else {
            XCTFail("Stale source edit unexpectedly entered the store")
            throw M2BusinessFixture.Failure.incorrectProtocolVariant
        }
        XCTAssertEqual(conflict.method, .sourceImport)
        XCTAssertEqual(conflict.data.error.code, .invalidParams)
        XCTAssertEqual(conflict.data.error.details?.reason, "sourceVersionConflict")
        let exactConflict = try await querySourceEdit(manager, params: stale,
            expectedVersion: originalRevision, binding: conflict.binding)
        guard case .rejected(let retained)? = exactConflict else {
            XCTFail("Exact query did not replay the original edit rejection")
            throw M2BusinessFixture.Failure.incorrectProtocolVariant
        }
        XCTAssertEqual(retained.ackFingerprint, conflict.ackFingerprint)
        let readback = try await manager.list(.init(sourceId: input.id))
        XCTAssertEqual(readback.sources.first?.sourceVersion, revised)
        XCTAssertEqual(readback.sources.first?.name, revisionName)
        XCTAssertEqual(readback.sources.first?.bookSource, updated.bookSource)
        let search = try SearchCoordinator(runtime: runtime).start(.init(sourceId: input.id, keyword: input.title))
        let checked = try await search.value
        XCTAssertEqual(checked.value.books.first?.bookId, input.bookID)
        print("M2_SOURCE_EDIT old=\(originalRevision) new=\(revised) applied=\(receipt.binding.operationId) stale=\(conflict.binding.operationId) reason=\(conflict.data.error.details?.reason ?? "-") exactReplay=verified")
        await runtime.close()
    }

    private func editParams(_ source: M2SourceListEntry, name: String) throws -> M2SourceImportParams {
        var rules = try XCTUnwrap(source.bookSource)
        rules["bookSourceName"] = .string(name)
        return .init(sourceId: source.sourceId, name: name, baseUrl: source.baseUrl, bookSource: rules)
    }

    private func querySourceEdit(
        _ manager: SourceManagementCoordinator, params: M2SourceImportParams,
        expectedVersion: String, binding: M2RulesMutationBinding
    ) async throws -> M2RulesMutationReceipt? {
        let guarded = M2SourceImportParams(sourceId: params.sourceId, name: params.name, baseUrl: params.baseUrl,
            rules: params.rules, bookSource: params.bookSource, useSourceReplacement: params.useSourceReplacement,
            expectedVersion: expectedVersion)
        return try await manager.query(.init(operationId: binding.operationId, sequence: binding.sequence,
            mutation: .sourceImport(.init(params: guarded)))).receipt
    }
}
