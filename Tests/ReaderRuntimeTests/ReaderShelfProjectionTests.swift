import CryptoKit
import Foundation
import XCTest
@testable import Reader
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#endif

@MainActor
final class ReaderShelfProjectionTests: XCTestCase {
    /// Actual Core/service metadata CRUD in a private store. These rows have
    /// no body and establish filter semantics, not real-novel acceptance.
    func testShelfGroupOptionsRetainActualLabelsAcrossDefinitionCRUDWithoutInventingGroups() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderShelfGroupOptions-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
                                               sourceURL: root.appendingPathComponent("Sources"))
        do {
            func seed(_ id: String, group: String? = nil) async throws -> ReaderBook {
                let operation = UUID().uuidString
                var params: [String: Any] = ["sourceId": "shelf-group-options", "bookId": id,
                    "title": "Owned metadata " + id, "author": ""]
                if let group { params["group"] = group }
                _ = try await service.coreMutation("bookshelf.add", params, operationID: operation, scope: "shelf-options-setup")
                try await service.finishCoreOperation(operation)
                let stored = try await service.bookDetails(for:
                    ReaderBook(sourceId: "shelf-group-options", bookId: id, title: "Owned metadata " + id))
                return try XCTUnwrap(stored)
            }
            let first = try await seed("first")
            _ = try await seed("z", group: "z-tag")
            _ = try await seed("a", group: "a-tag")
            let ungrouped = try await seed("ungrouped")
            let original = try await service.createGroup(name: "original-label", operationID: UUID().uuidString)
            _ = try await service.assignGroup(original, to: first, operationID: UUID().uuidString)
            let model = ReaderApplicationModel(service: service, readingTimeStorageURL: root.appendingPathComponent("ReadingTime/ledger.json"))
            let presentation = ReaderShelfPresentation()
            func refresh() async {
                await model.reloadLibrary()
                await presentation.reload(model: model, keyword: "")
            }
            await refresh()
            XCTAssertNil(presentation.group)
            XCTAssertEqual(presentation.groupNameOptions(model: model), ["original-label", "a-tag", "z-tag"])
            presentation.group = original.groupName
            await presentation.reload(model: model, keyword: "")
            XCTAssertEqual(presentation.books(for: presentation.key(model: model, keyword: ""))?.map(\.id), [first.id])
            XCTAssertEqual(presentation.groupNameOptions(model: model), ["original-label", "a-tag", "z-tag"],
                           "A filtered subset cannot hide other confirmed shelf labels")

            var renamed = original
            renamed.groupName = "renamed-definition"
            _ = try await service.updateGroup(renamed, operationID: UUID().uuidString)
            await refresh()
            XCTAssertEqual(presentation.groups, [renamed])
            XCTAssertEqual(presentation.group, "original-label")
            XCTAssertEqual(presentation.groupNameOptions(model: model), ["renamed-definition", "a-tag", "original-label", "z-tag"])
            let retained = try await service.bookDetails(for: first)
            XCTAssertEqual(retained?.group, "original-label", "Group CRUD must preserve the existing free-label contract")
            let renamedMembers = try await service.listBooks(query: .init(sourceId: nil, group: renamed.groupName))
            XCTAssertTrue(renamedMembers.isEmpty)
            XCTAssertEqual(presentation.books(for: presentation.key(model: model, keyword: ""))?.map(\.id), [first.id])

            try await service.deleteGroup(renamed, operationID: UUID().uuidString)
            await refresh()
            XCTAssertTrue(presentation.groups.isEmpty)
            XCTAssertEqual(presentation.group, "original-label")
            XCTAssertEqual(presentation.groupNameOptions(model: model), ["a-tag", "original-label", "z-tag"])
            XCTAssertEqual(presentation.books(for: presentation.key(model: model, keyword: ""))?.map(\.id), [first.id])

            let definedSecond = try await service.createGroup(name: "defined-2", operationID: UUID().uuidString)
            let definedFirst = try await service.createGroup(name: "defined-1", operationID: UUID().uuidString)
            let duplicate = try await service.createGroup(name: "defined-2", operationID: UUID().uuidString)
            let blank = try await service.createGroup(name: "  \n", operationID: UUID().uuidString)
            await refresh()
            XCTAssertEqual(presentation.groups, [definedSecond, definedFirst, duplicate, blank],
                           "Filter deduplication must not merge or invent actual group entities")
            XCTAssertEqual(presentation.groupNameOptions(model: model), ["defined-2", "defined-1", "a-tag", "original-label", "z-tag"])
            presentation.group = "selected-no-row"
            await presentation.reload(model: model, keyword: "")
            XCTAssertTrue(try XCTUnwrap(presentation.books(for: presentation.key(model: model, keyword: ""))).isEmpty)
            XCTAssertEqual(presentation.group, "selected-no-row")
            XCTAssertEqual(presentation.groupNameOptions(model: model),
                           ["defined-2", "defined-1", "a-tag", "original-label", "selected-no-row", "z-tag"])
            presentation.group = ""
            await presentation.reload(model: model, keyword: "")
            XCTAssertEqual(presentation.group, "")
            XCTAssertEqual(presentation.books(for: presentation.key(model: model, keyword: ""))?.map(\.id), [ungrouped.id])
            XCTAssertEqual(presentation.groupNameOptions(model: model), ["defined-2", "defined-1", "a-tag", "original-label", "z-tag"])
            presentation.group = nil
            await presentation.reload(model: model, keyword: "")
            XCTAssertNil(presentation.group)
            XCTAssertEqual(presentation.books(for: presentation.key(model: model, keyword: ""))?.count, 4)
            let finalGroups = try await service.groups()
            XCTAssertEqual(finalGroups, [definedSecond, definedFirst, duplicate, blank])
            try await service.close()
        } catch {
            try? await service.close()
            throw error
        }
    }

    /// Both inputs are the user's byte-identical provisioned originals. The
    /// normal Reader service owns this test's temporary Core store; there is
    /// no mock response, generated novel or alternative shelf business store.
    func testTwoRealOriginalsRejectStaleShelfProjectionWhenQueryGroupSortOrLibrarySnapshotChanges() async throws {
        let firstDigest = "aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5"
        let secondDigest = "ebe4b6535def1853e2d4d039f14981035fbfba8dcd6864fa6d0ecb2174e23952"
        let firstURL = try ReaderLocalFormatsTests.originalURL(format: "txt", byteCount: 8_871_723, digest: firstDigest)
        let secondURL = try ReaderLocalFormatsTests.originalURL(format: "txt", byteCount: 3_131_250, digest: secondDigest)
        let firstBytes = try Data(contentsOf: firstURL, options: .mappedIfSafe)
        let secondBytes = try Data(contentsOf: secondURL, options: .mappedIfSafe)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderRealShelfProjection-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
                                               sourceURL: root.appendingPathComponent("Sources"))
        do {
            let firstImport = try await service.importBook(at: firstURL)
            let secondImport = try await service.importBook(at: secondURL)
            XCTAssertTrue(firstImport.created); XCTAssertFalse(firstImport.finalizationPending)
            XCTAssertTrue(secondImport.created); XCTAssertFalse(secondImport.finalizationPending)
            let first = firstImport.book, second = secondImport.book
            XCTAssertEqual(first.bookId, "local:" + firstDigest)
            XCTAssertEqual(second.bookId, "local:" + secondDigest)
            XCTAssertTrue(first.title.contains("仙子请听我解释"))
            XCTAssertTrue(second.title.contains("湛蓝权杖"))
            let firstRetained = try await service.retainedSourceURL(for: first)
            let secondRetained = try await service.retainedSourceURL(for: second)
            let model = ReaderApplicationModel(service: service)
            await model.reloadLibrary()
            XCTAssertEqual(Set(model.books.map(\.bookId)), [first.bookId, second.bookId])
            let presentation = ReaderShelfPresentation()

            var keyword = "湛蓝"
            let filteredKey = presentation.key(model: model, keyword: keyword)
            XCTAssertNil(presentation.books(for: filteredKey))
            await presentation.reload(model: model, keyword: keyword, grid: false)
            XCTAssertNil(presentation.failure(for: filteredKey))
            XCTAssertEqual(presentation.books(for: filteredKey)?.map(\.bookId), [second.bookId])

            // This is the synchronous interval before SwiftUI can start its
            // replacement .task. The old subset must already be unavailable.
            keyword = ""
            let allKey = presentation.key(model: model, keyword: keyword)
            XCTAssertNotEqual(allKey, filteredKey)
            XCTAssertNil(presentation.books(for: allKey))
            XCTAssertNil(presentation.failure(for: allKey))
            await presentation.reload(model: model, keyword: keyword, grid: true)
            let all = try XCTUnwrap(presentation.books(for: allKey))
            XCTAssertEqual(Set(all.map(\.bookId)), [first.bookId, second.bookId])
            let refresh = Task { await presentation.reload(model: model, keyword: keyword, grid: true) }
            await Task.yield()
            XCTAssertEqual(presentation.books(for: allKey), all, "A same-key refresh keeps confirmed contents visible")
            await refresh.value
            XCTAssertEqual(presentation.books(for: allKey), all)

            presentation.group = ""
            let ungroupedKey = presentation.key(model: model, keyword: keyword)
            XCTAssertNotEqual(ungroupedKey, allKey, "All groups and ungrouped are different Core predicates")
            XCTAssertNil(presentation.books(for: ungroupedKey))
            await presentation.reload(model: model, keyword: keyword)
            XCTAssertEqual(Set(try XCTUnwrap(presentation.books(for: ungroupedKey)).map(\.bookId)), [first.bookId, second.bookId])

            presentation.sort = .title; presentation.descending = false
            let ascendingKey = presentation.key(model: model, keyword: keyword)
            XCTAssertNotEqual(ascendingKey, ungroupedKey)
            XCTAssertNil(presentation.books(for: ascendingKey))
            await presentation.reload(model: model, keyword: keyword)
            XCTAssertEqual(presentation.books(for: ascendingKey)?.map(\.bookId), [first.bookId, second.bookId])
            presentation.descending = true
            let descendingKey = presentation.key(model: model, keyword: keyword)
            XCTAssertNotEqual(descendingKey, ascendingKey)
            XCTAssertNil(presentation.books(for: descendingKey))
            await presentation.reload(model: model, keyword: keyword)
            XCTAssertEqual(presentation.books(for: descendingKey)?.map(\.bookId), [second.bookId, first.bookId])

            // A real acknowledged Core membership change alters the model's
            // snapshot even though the UI query fields have not changed.
            let group = try await service.createGroup(name: "真实原书投影", operationID: UUID().uuidString)
            _ = try await service.assignGroup(group, to: second, operationID: UUID().uuidString)
            await model.reloadLibrary()
            let changedSnapshotKey = presentation.key(model: model, keyword: keyword)
            XCTAssertEqual(changedSnapshotKey.query, descendingKey.query)
            XCTAssertNotEqual(changedSnapshotKey.librarySnapshot, descendingKey.librarySnapshot)
            XCTAssertNil(presentation.books(for: changedSnapshotKey))
            await presentation.reload(model: model, keyword: keyword)
            XCTAssertEqual(presentation.books(for: changedSnapshotKey)?.map(\.bookId), [first.bookId])
            presentation.group = group.groupName
            let namedKey = presentation.key(model: model, keyword: keyword)
            XCTAssertNil(presentation.books(for: namedKey))
            await presentation.reload(model: model, keyword: keyword)
            XCTAssertEqual(presentation.books(for: namedKey)?.map(\.bookId), [second.bookId])

            XCTAssertEqual(Set(model.books.map(\.bookId)), [first.bookId, second.bookId])
            XCTAssertEqual(try Data(contentsOf: firstURL), firstBytes)
            XCTAssertEqual(try Data(contentsOf: secondURL), secondBytes)
            XCTAssertEqual(try Data(contentsOf: firstRetained), firstBytes)
            XCTAssertEqual(try Data(contentsOf: secondRetained), secondBytes)
            XCTAssertEqual(sha(try Data(contentsOf: firstRetained)), firstDigest)
            XCTAssertEqual(sha(try Data(contentsOf: secondRetained)), secondDigest)
            try await service.close()
        } catch {
            try? await service.close()
            throw error
        }
    }

    private func sha(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
