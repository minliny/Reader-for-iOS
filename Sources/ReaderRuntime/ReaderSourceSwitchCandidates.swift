import Foundation

/// Core owns same-book metadata, author proofs and source-version admission.
/// The Host only projects a complete Core snapshot onto discovered identities.
public protocol ReaderSourceSwitchCandidateServing: ReaderLibraryServing {
    func sourceSwitchCandidates(for book: ReaderBook,
                                among candidates: [ReaderOnlineCandidate]) async throws -> [ReaderOnlineCandidate]
}

private struct ReaderSwitchCandidateIdentity: Hashable {
    let source: Data
    let book: Data
    init(_ source: String, _ book: String) {
        self.source = Data(source.utf8); self.book = Data(book.utf8)
    }
}

extension ReaderLibraryService: ReaderSourceSwitchCandidateServing {
    public func sourceSwitchCandidates(for book: ReaderBook,
                                       among candidates: [ReaderOnlineCandidate]) async throws -> [ReaderOnlineCandidate] {
        guard book.sourceId != "local" else { throw ReaderLibraryError.invalidPosition }
        let original = ReaderSwitchCandidateIdentity(book.sourceId, book.bookId)
        let wanted = Set(candidates.map { ReaderSwitchCandidateIdentity($0.sourceId, $0.bookId) })
        var matched: [ReaderSwitchCandidateIdentity: [String: Any]] = [:]
        var originalFound = false
        var snapshot: String?
        var sourceFacts: [Data: (version: String, enabled: Bool)] = [:]
        var relation: (String, String)?
        var cursor: String?
        var visited = Set<String>()

        repeat {
            try Task.checkCancellation()
            var params: [String: Any] = [
                "mode": "sourceSwitchCandidates",
                "identity": ["sourceId": book.sourceId, "bookId": book.bookId], "limit": 128
            ]
            if let cursor { params["cursor"] = cursor }
            let page = try object(await coreRead("search-book.related", params))
            guard let rows = page["books"] as? [[String: Any]],
                  let versions = page["sourceVersions"] as? [[String: Any]],
                  let revision = page["snapshotRevision"] as? String, !revision.isEmpty,
                  let complete = page["complete"] as? Bool else {
                throw ReaderLibraryError.invalidResponse("source switch candidate snapshot")
            }
            if let snapshot {
                guard snapshot == revision else {
                    throw ReaderLibraryError.invalidResponse("source switch candidate snapshot changed")
                }
            } else { snapshot = revision }
            var enabled = Set<Data>()
            for source in versions {
                guard let id = source["sourceId"] as? String, !id.isEmpty,
                      let version = source["sourceVersion"] as? String, !version.isEmpty,
                      let active = source["enabled"] as? Bool else {
                    throw ReaderLibraryError.invalidResponse("source switch candidate source scope")
                }
                let identity = Data(id.utf8)
                if let previous = sourceFacts[identity],
                   previous.version != version || previous.enabled != active {
                    throw ReaderLibraryError.invalidResponse("source switch candidate source version changed")
                }
                sourceFacts[identity] = (version, active)
                if active { enabled.insert(Data(id.utf8)) }
            }
            for row in rows {
                guard let source = row["origin"] as? String, !source.isEmpty,
                      let id = row["bookUrl"] as? String, !id.isEmpty,
                      row["name"] is String, row["author"] is String,
                      let key = row["relationKey"] as? String, !key.isEmpty,
                      let revision = row["relationRevision"] as? String, !revision.isEmpty else {
                    throw ReaderLibraryError.invalidResponse("source switch candidate row scope")
                }
                if let relation {
                    guard relation.0 == key, relation.1 == revision else {
                        throw ReaderLibraryError.invalidResponse("source switch candidate relation changed")
                    }
                } else { relation = (key, revision) }
                let identity = ReaderSwitchCandidateIdentity(source, id)
                guard sourceFacts[Data(source.utf8)] != nil,
                      identity == original || enabled.contains(Data(source.utf8)) else {
                    throw ReaderLibraryError.invalidResponse("source switch candidate disabled target")
                }
                if identity == original { originalFound = true }
                if identity != original, wanted.contains(identity) {
                    guard matched.updateValue(row, forKey: identity) == nil else {
                        throw ReaderLibraryError.invalidResponse("duplicate source switch candidate identity")
                    }
                }
            }
            if complete {
                guard page["nextCursor"] == nil || page["nextCursor"] is NSNull else {
                    throw ReaderLibraryError.invalidResponse("completed source switch candidate cursor")
                }
                cursor = nil
            } else {
                guard let next = page["nextCursor"] as? String, !next.isEmpty,
                      visited.insert(next).inserted else {
                    throw ReaderLibraryError.invalidResponse("source switch candidate cursor")
                }
                cursor = next
            }
        } while cursor != nil

        guard originalFound else {
            throw ReaderLibraryError.invalidResponse("unconfirmed original source switch identity")
        }
        try Task.checkCancellation()
        var emitted = Set<ReaderSwitchCandidateIdentity>()
        return try candidates.compactMap { candidate in
            let identity = ReaderSwitchCandidateIdentity(candidate.sourceId, candidate.bookId)
            guard let row = matched[identity], emitted.insert(identity).inserted,
                  let title = row["name"] as? String, let author = row["author"] as? String else { return nil }
            // Preserve Core search variables and opaque fields. Refresh only
            // display metadata and author evidence from this canonical snapshot.
            var payload = try candidate.coreBook.map { try object($0) } ?? ["bookId": candidate.bookId]
            guard let payloadBook = payload["bookId"] as? String,
                  Data(payloadBook.utf8) == Data(candidate.bookId.utf8),
                  (payload["sourceId"] as? String).map({ Data($0.utf8) == Data(candidate.sourceId.utf8) }) ?? true else {
                throw ReaderLibraryError.invalidResponse("source switch candidate payload identity")
            }
            payload["title"] = title; payload["author"] = author
            if let acquisition = row["acquisition"] as? [String: Any],
               let proof = acquisition["authorIdentity"], !(proof is NSNull) {
                payload["authorIdentity"] = proof
            } else { payload.removeValue(forKey: "authorIdentity") }
            let cover = row["coverUrl"] as? String
            if let cover { payload["coverUrl"] = cover }
            else { payload.removeValue(forKey: "coverUrl") }
            return ReaderOnlineCandidate(sourceId: candidate.sourceId, bookId: candidate.bookId,
                title: title, author: author, coverUrl: cover,
                coreBook: try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]))
        }
    }
}
