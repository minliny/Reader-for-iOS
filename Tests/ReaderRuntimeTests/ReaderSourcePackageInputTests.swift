import Foundation
import CryptoKit
import XCTest
@testable import Reader

/// Actual package/Core validation and draft ownership, not a picker UI journey.
@MainActor
final class ReaderSourcePackageInputTests: XCTestCase {
    private enum InputError: Error { case originalIdentity, missingConfirmation }

    func testRealProvisionedSourcePackageBoundedUTF8ValidationAndFaultCopiesPreserveDraft() async throws {
        let expectedDigest = "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322"
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let input = documents.appendingPathComponent("Reader-real-sources.json")
        // Missing input or a different package is a failure, never a skip or
        // a generated replacement definition.
        let facts = try input.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard facts.isRegularFile == true, facts.fileSize == 5_606 else {
            XCTFail("The required original source package is missing or has a different size/type")
            throw InputError.originalIdentity
        }
        let original = try Data(contentsOf: input)
        guard original.count == 5_606, digest(original) == expectedDigest else {
            XCTFail("Provision the original Reader-real-sources.json: 5606 bytes with the required SHA256")
            throw InputError.originalIdentity
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderRealSourceInput-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = "ReaderRealSourceInput." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let actions = ReaderLibraryActionOwner()
        let owner = ReaderSourceEditorDraftOwner(actions: actions, defaults: defaults)
        owner.activate(); owner.resumeDraft()
        defer { owner.retire() }
        let storage = root.appendingPathComponent("Core")
        let gate = try StagingCoreGate(storage: storage)
        defer { gate.release(); gate.destroy() }
        let service = try ReaderLibraryService(storageURL: storage, sourceURL: root.appendingPathComponent("Sources"),
                                               client: gate, timing: gate.timing)
        do {
            let savedBefore = try await service.onlineSources()
            XCTAssertTrue(savedBefore.isEmpty, "The validation library is isolated from all user sources")
            let text = try await ReaderSourcePackageInput.readUTF8File(at: input)
            XCTAssertEqual(Data(text.utf8), original)
            XCTAssertEqual(digest(Data(text.utf8)), expectedDigest)
            let validation = try await service.validateSources(Data(text.utf8))
            XCTAssertEqual(validation.count, 2)
            XCTAssertTrue(validation.allSatisfy(\.succeeded))
            XCTAssertEqual(gate.count("import.parse"), 2, "Both real definitions reach the actual pinned Core parser")

            // This is the same actual package with one formatting-only draft
            // edit. It creates no new source definition or business write.
            owner.updateDraft(text + "\n")
            let draftBefore = owner.draft
            let metadataBefore = try XCTUnwrap(defaults.data(forKey: "reader.source-editor.draft.metadata.v1"))
            XCTAssertTrue(owner.hasUnsavedInput)
            let request = try XCTUnwrap(owner.beginRead())
            guard case .confirmation(let confirmation) = owner.finishRead(request, target: .imported(text, label: input.lastPathComponent)) else {
                XCTFail("A valid file read must not overwrite a different unsaved draft")
                throw InputError.missingConfirmation
            }
            owner.dismissConfirmation()
            XCTAssertFalse(owner.confirm(confirmation), "Dismissing the original confirmation does not apply its candidate")
            XCTAssertEqual(owner.draft, draftBefore)
            XCTAssertEqual(defaults.data(forKey: "reader.source-editor.draft.metadata.v1"), metadataBefore)

            let invalidUTF8 = root.appendingPathComponent("invalid-utf8.json")
            try FileManager.default.copyItem(at: input, to: invalidUTF8)
            do {
                let handle = try FileHandle(forWritingTo: invalidUTF8)
                defer { try? handle.close() }
                _ = try handle.seekToEnd()
                try handle.write(contentsOf: Data([0xff]))
            }
            let oversized = root.appendingPathComponent("oversized.json")
            try FileManager.default.copyItem(at: input, to: oversized)
            do {
                let handle = try FileHandle(forWritingTo: oversized)
                defer { try? handle.close() }
                try handle.truncate(atOffset: UInt64(ReaderSourcePackageInput.maximumBytes) + 1)
            }
            let faults: [(URL, CocoaError.Code)] = [
                (invalidUTF8, .fileReadInapplicableStringEncoding),
                (oversized, .fileReadTooLarge)
            ]
            for (url, expectedCode) in faults {
                let failedRequest = try XCTUnwrap(owner.beginRead())
                do {
                    _ = try await ReaderSourcePackageInput.readUTF8File(at: url)
                    XCTFail("The actual fault copy must fail before a draft candidate is offered")
                } catch { assertCocoa(error, code: expectedCode) }
                owner.cancelRead()
                XCTAssertFalse(owner.accepts(failedRequest))
                // The Runtime boundary independently rejects programmatic input
                // before JSONSerialization or another actual import.parse call.
                let faultBytes = try Data(contentsOf: url, options: .mappedIfSafe)
                do {
                    _ = try await service.validateSources(faultBytes)
                    XCTFail("The source service must reject the fault before JSON parsing")
                } catch { assertCocoa(error, code: expectedCode) }
                XCTAssertEqual(gate.count("import.parse"), 2)
                XCTAssertEqual(owner.draft, draftBefore)
                XCTAssertEqual(defaults.string(forKey: "reader.source-editor.draft"), draftBefore)
                XCTAssertEqual(defaults.data(forKey: "reader.source-editor.draft.metadata.v1"), metadataBefore)
                XCTAssertTrue(owner.hasUnsavedInput)
                XCTAssertTrue(owner.presented)
                XCTAssertNil(owner.acceptedOperationID)
                XCTAssertNil(actions.pendingOperationID)
            }
            let savedAfter = try await service.onlineSources()
            XCTAssertEqual(savedAfter, savedBefore)
            XCTAssertEqual(gate.count("rules.mutation.apply"), 0)
            XCTAssertEqual(gate.count("source.import"), 0)
            XCTAssertEqual(try Data(contentsOf: input), original)
            XCTAssertEqual(digest(try Data(contentsOf: input)), expectedDigest)
            owner.retire()
            let restored = ReaderSourceEditorDraftOwner(actions: ReaderLibraryActionOwner(), defaults: defaults)
            restored.activate(); restored.resumeDraft()
            XCTAssertEqual(restored.draft, draftBefore)
            XCTAssertTrue(restored.hasUnsavedInput)
            XCTAssertNil(restored.acceptedOperationID)
            XCTAssertEqual(defaults.data(forKey: "reader.source-editor.draft.metadata.v1"), metadataBefore)
            restored.retire()
            try await service.close()
        } catch {
            try? await service.close()
            throw error
        }
    }

    private func assertCocoa(_ error: Error, code: CocoaError.Code,
                             file: StaticString = #filePath, line: UInt = #line) {
        let actual = error as NSError
        XCTAssertEqual(actual.domain, NSCocoaErrorDomain, file: file, line: line)
        XCTAssertEqual(actual.code, code.rawValue, "The exact admission error distinguishes rejection before JSON parsing", file: file, line: line)
    }
    private func digest(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
