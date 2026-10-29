import Foundation
import XCTest
#if canImport(ReaderCoreClient)
import ReaderCoreClient
#endif
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

/// Scripted read-only Core pages exercise the Host snapshot adapter only.
/// They contain metadata, not novel bodies, mutation receipts or real-source acceptance evidence.
final class ReaderSourceSwitchCandidateSnapshotTests: XCTestCase {
    func testCompletePageLocalSourceFactsPreserveOpaquePayloadAndCanonicalMetadataOwnerBoundary() async throws {
        let original = candidateSnapshotOriginal()
        let proof: [String: Any] = ["schemaVersion": 1, "sourceVersion": "a-rule-version", "field": "search",
                                    "raw": "@Writer", "label": "Writer", "rule": "author-nickname-at-v1"]
        let opaque: [String: Any] = ["raw": ["unchanged", 7, true], "nested": ["key": "\u{00e9}e\u{0301}"]]
        let variables = ["requestToken": "opaque-search-input", "rawValue": "@Writer|\n"]
        let oldProof: [String: Any] = ["schemaVersion": 1, "sourceVersion": "earlier-rule-version", "field": "search",
                                       "raw": "@Earlier author", "label": "Earlier author", "rule": "author-nickname-at-v1"]
        let rawA: [String: Any] = ["bookId": "candidate-a", "sourceId": "a", "title": "Earlier display",
            "author": "@Earlier author", "coverUrl": "old-cover", "variables": variables,
            "opaqueBoundary": opaque, "authorIdentity": oldProof]
        let rawB: [String: Any] = ["bookId": "candidate-b", "title": "Earlier display",
            "author": "@Earlier author", "variables": variables, "authorIdentity": oldProof]
        let a = ReaderOnlineCandidate(sourceId: "a", bookId: "candidate-a", title: "Earlier display",
            author: "@Earlier author", coverUrl: "old-cover", coreBook: try candidateSnapshotJSON(rawA))
        let b = ReaderOnlineCandidate(sourceId: "b", bookId: "candidate-b", title: "Earlier display",
            author: "@Earlier author", coreBook: try candidateSnapshotJSON(rawB))
        let current = ReaderOnlineCandidate(sourceId: original.sourceId, bookId: original.bookId, title: original.title)
        let unrelated = ReaderOnlineCandidate(sourceId: "not-in-snapshot", bookId: "unconfirmed", title: "Unconfirmed metadata")
        let pages = [
            candidateSnapshotPage(rows: [candidateSnapshotRow("current", "current-book"),
                                        candidateSnapshotRow("a", "candidate-a", proof: proof)],
                                  sources: [candidateSnapshotSource("current", enabled: false), candidateSnapshotSource("a")],
                                  complete: false, next: "page-2"),
            candidateSnapshotPage(rows: [candidateSnapshotRow("b", "candidate-b", cover: "canonical-cover")],
                                  sources: [candidateSnapshotSource("current", enabled: false), candidateSnapshotSource("b")], complete: true)
        ]
        let fixture = try CandidateSnapshotReadFixture(pages: pages)
        defer { fixture.remove() }
        let admitted = try await fixture.service.sourceSwitchCandidates(for: original, among: [b, a, a, current, unrelated])
        XCTAssertEqual(admitted.map(\.id), [b.id, a.id], "Only confirmed identities survive, in discovery order without duplicates or the current book")
        XCTAssertEqual(admitted.map(\.title), ["Canonical metadata", "Canonical metadata"])
        XCTAssertEqual(admitted.map(\.author), ["@Writer", "@Writer"])
        let admittedA = try XCTUnwrap(admitted.first { $0.id == a.id })
        let admittedB = try XCTUnwrap(admitted.first { $0.id == b.id })
        XCTAssertEqual(admittedB.coverUrl, "canonical-cover")
        XCTAssertNil(admittedA.coverUrl, "A missing canonical cover removes the prior display value")
        let payloadA = try candidateSnapshotObject(try XCTUnwrap(admittedA.coreBook))
        let payloadB = try candidateSnapshotObject(try XCTUnwrap(admittedB.coreBook))
        XCTAssertEqual(try candidateSnapshotJSON(try XCTUnwrap(payloadA["variables"])), try candidateSnapshotJSON(variables))
        XCTAssertEqual(try candidateSnapshotJSON(try XCTUnwrap(payloadA["opaqueBoundary"])), try candidateSnapshotJSON(opaque))
        XCTAssertEqual(try candidateSnapshotJSON(try XCTUnwrap(payloadA["authorIdentity"])), try candidateSnapshotJSON(proof))
        XCTAssertEqual(payloadA["title"] as? String, "Canonical metadata")
        XCTAssertEqual(payloadA["author"] as? String, "@Writer")
        XCTAssertNil(payloadA["coverUrl"])
        XCTAssertNil(payloadB["authorIdentity"], "Absent canonical proof cannot inherit an older search proof")
        XCTAssertEqual(payloadB["coverUrl"] as? String, "canonical-cover")
        let requests = fixture.client.parameters
        XCTAssertEqual(requests.count, 2)
        for request in requests {
            XCTAssertEqual(request["mode"] as? String, "sourceSwitchCandidates")
            XCTAssertEqual(request["limit"] as? Int, 128)
            let identity = try XCTUnwrap(request["identity"] as? [String: String])
            XCTAssertEqual(identity, ["sourceId": original.sourceId, "bookId": original.bookId])
        }
        XCTAssertNil(requests.first?["cursor"])
        XCTAssertEqual(requests.last?["cursor"] as? String, "page-2")
    }

    func testStaleConflictingIncompleteAndMissingCurrentSnapshotsFailWithoutPartialReturnOwnerBoundary() async throws {
        let original = candidateSnapshotOriginal()
        let candidate = ReaderOnlineCandidate(sourceId: "a", bookId: "candidate-a", title: "Earlier display")
        let first = candidateSnapshotPage(rows: [candidateSnapshotRow("current", "current-book"), candidateSnapshotRow("a", "candidate-a")],
            sources: [candidateSnapshotSource("current"), candidateSnapshotSource("a")], complete: false, next: "page-2")
        let last = candidateSnapshotPage(rows: [candidateSnapshotRow("b", "candidate-b")],
            sources: [candidateSnapshotSource("current"), candidateSnapshotSource("b")], complete: true)
        var stale = last; stale["snapshotRevision"] = "later-snapshot"
        var conflictingVersion = last
        conflictingVersion["sourceVersions"] = [candidateSnapshotSource("current", version: "changed-version"), candidateSnapshotSource("b")]
        var conflictingEnabled = last
        conflictingEnabled["sourceVersions"] = [candidateSnapshotSource("current", enabled: false), candidateSnapshotSource("b")]
        var changedRelation = last
        var changedRow = candidateSnapshotRow("b", "candidate-b"); changedRow["relationRevision"] = "changed-relation"
        changedRelation["books"] = [changedRow]
        let missingCurrent = candidateSnapshotPage(rows: [candidateSnapshotRow("a", "candidate-a")],
            sources: [candidateSnapshotSource("a")], complete: true)
        var missingCursor = first; missingCursor.removeValue(forKey: "nextCursor")
        var missingComplete = first; missingComplete.removeValue(forKey: "complete")
        var repeatedCursor = last; repeatedCursor["complete"] = false; repeatedCursor["nextCursor"] = "page-2"
        let scenarios: [(String, [[String: Any]])] = [
            ("stale snapshot", [first, stale]), ("conflicting source version", [first, conflictingVersion]),
            ("conflicting source enabled fact", [first, conflictingEnabled]), ("changed relation", [first, changedRelation]),
            ("missing original identity", [missingCurrent]), ("partial without cursor", [missingCursor]),
            ("missing completion fact", [missingComplete]), ("repeated cursor", [first, repeatedCursor])
        ]
        for (name, pages) in scenarios {
            let fixture = try CandidateSnapshotReadFixture(pages: pages)
            defer { fixture.remove() }
            var returned: [ReaderOnlineCandidate]?
            do {
                returned = try await fixture.service.sourceSwitchCandidates(for: original, among: [candidate])
                XCTFail("\(name) must fail before publishing any candidate subset")
            } catch let failure as ReaderLibraryError {
                guard case .invalidResponse = failure else { XCTFail("Unexpected \(name) failure: \(failure)"); continue }
            }
            XCTAssertNil(returned, name)
            XCTAssertEqual(fixture.client.parameters.count, pages.count, "\(name) must stop at the invalid page without another read")
        }
    }
}

private func candidateSnapshotOriginal() -> ReaderBook {
    .init(sourceId: "current", bookId: "current-book", title: "Canonical metadata", author: "@Writer")
}
private func candidateSnapshotSource(_ id: String, version: String? = nil, enabled: Bool = true) -> [String: Any] {
    ["sourceId": id, "sourceVersion": version ?? "\(id)-rule-version", "enabled": enabled]
}
private func candidateSnapshotRow(_ source: String, _ book: String, cover: String? = nil,
                                  proof: [String: Any]? = nil) -> [String: Any] {
    var row: [String: Any] = ["origin": source, "bookUrl": book, "name": "Canonical metadata", "author": "@Writer",
                              "relationKey": "source-switch-relation", "relationRevision": "relation-revision"]
    if let cover { row["coverUrl"] = cover }
    if let proof { row["acquisition"] = ["authorIdentity": proof] }
    return row
}
private func candidateSnapshotPage(rows: [[String: Any]], sources: [[String: Any]], complete: Bool,
                                   next: String? = nil) -> [String: Any] {
    var page: [String: Any] = ["books": rows, "sourceVersions": sources, "snapshotRevision": "snapshot-revision", "complete": complete]
    if let next { page["nextCursor"] = next }
    return page
}
private func candidateSnapshotJSON(_ value: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed])
}
private func candidateSnapshotObject(_ data: Data) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private struct CandidateSnapshotReadFixture {
    let root: URL
    let client: CandidateSnapshotReadClient
    let service: ReaderLibraryService
    init(pages: [[String: Any]]) throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderCandidateSnapshotBoundary-" + UUID().uuidString)
        client = CandidateSnapshotReadClient(pages: pages)
        service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
            sourceURL: root.appendingPathComponent("Sources"), client: client, timing: .live)
    }
    func remove() { client.destroy(); try? FileManager.default.removeItem(at: root) }
}

/// Request-specific read terminals only. No mutation or HTTP method has a reply.
private final class CandidateSnapshotReadClient: ReaderCoreEventClient, @unchecked Sendable {
    private let lock = NSLock()
    private var pages: [[String: Any]]
    private var recorded: [[String: Any]] = []
    private var replies: [UInt64: ReaderCoreEvent] = [:]
    init(pages: [[String: Any]]) { self.pages = pages }
    var parameters: [[String: Any]] { lock.withLock { recorded } }
    func send(method: String, requestId: UInt64, params: [String: Any]) throws -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        guard method == "search-book.related" else { throw ReaderLibraryError.invalidResponse("Unselected candidate read method: " + method) }
        recorded.append(params)
        guard !pages.isEmpty else { throw ReaderLibraryError.invalidResponse("Unexpected extra candidate page") }
        let page = pages.removeFirst()
        replies[requestId] = try ReaderCoreEvent(data: candidateSnapshotJSON([
            "protocolVersion": ReaderCoreClient.protocolVersion, "requestId": requestId, "type": "result", "data": page
        ]))
        return requestId
    }
    func pollEvent(requestId: UInt64) -> Result<ReaderCoreEvent, ReaderCoreClientError>? {
        lock.withLock { replies.removeValue(forKey: requestId).map { .success($0) } }
    }
    func cancel(requestId: UInt64) throws { throw ReaderLibraryError.invalidResponse("Unselected candidate read cancellation") }
    func retireReadRequest(requestId: UInt64) { lock.withLock { _ = replies.removeValue(forKey: requestId) } }
    func destroy() { lock.withLock { replies.removeAll(); pages.removeAll() } }
}
