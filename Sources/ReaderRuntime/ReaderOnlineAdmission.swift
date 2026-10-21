import CryptoKit
import Foundation

/// Original user intent, not another catalog or business store. Only one
/// selected Core chapter identity and phase IDs are retained for recovery.
private struct ReaderOnlineAdmission: Codable {
    let operationID: String
    let book: ReaderBook
    let chapterIndex: UInt32
    let chapterURL: String
    let chapterTitle: String
    let preparationOperationID: String
    var completedBook: ReaderBook?
    var addAcknowledged: Bool?
    var rejection: ReaderOnlineAdmissionRejection?
}

private struct ReaderOnlineAdmissionRejection: Codable {
    let code: String
    let message: String
    let retryable: Bool
    let reason: String?
    init?(_ error: Error) {
        guard ReaderLibraryService.isDefiniteMutationRejection(error),
              case ReaderLibraryError.core(let code, let message, let retryable, let reason) = error else { return nil }
        self.code = code; self.message = message; self.retryable = retryable; self.reason = reason
    }
    var error: ReaderLibraryError { .core(code: code, message: message, retryable: retryable, reason: reason) }
}

extension ReaderLibraryService {
    func beginOnlineAdmission(_ detail: ReaderOnlineDetail, chapterIndex: UInt32, operationID: String) async throws -> ReaderBook {
        guard !operationID.isEmpty, detail.book.sourceId != "local",
              let chapter = detail.chapters.first(where: { $0.index == chapterIndex }), !chapter.url.isEmpty else { throw ReaderLibraryError.invalidPosition }
        if let original = try admissionRecord(operationID) {
            guard original.book.id == detail.book.id, original.chapterIndex == chapterIndex,
                  original.chapterURL == chapter.url else { throw ReaderLibraryError.invalidResponse("online admission operation identity") }
        } else {
            guard try admissionRecords().allSatisfy({ $0.completedBook != nil || $0.rejection != nil || $0.book.id != detail.book.id }) else { throw ReaderLibraryError.operationPending("online admission") }
            try Task.checkCancellation()
            try saveAdmission(ReaderOnlineAdmission(operationID: operationID, book: detail.book, chapterIndex: chapterIndex,
                chapterURL: chapter.url, chapterTitle: chapter.title, preparationOperationID: operationID + ":preparation", completedBook: nil))
        }
        return try await resumeOnlineAdmission(operationID)
    }

    func resumeOnlineAdmission(_ operationID: String) async throws -> ReaderBook {
        guard var record = try admissionRecord(operationID) else { throw ReaderLibraryError.invalidResponse("online admission owner missing") }
        if let completed = record.completedBook { return completed }
        if let rejection = record.rejection { throw rejection.error }
        let book = record.book
        var add: [String: Any]
        if let original = try existingCoreParameters(operationID: operationID, method: "bookshelf.add") {
            guard original["sourceId"] as? String == book.sourceId, original["bookId"] as? String == book.bookId else { throw ReaderLibraryError.invalidResponse("online admission ACK identity") }
            add = original
        } else {
            // A genuine existing shelf entry satisfies a new add intent without
            // rewriting metadata, group or progress. It never settles an old add.
            if try existingCoreParameters(operationID: record.preparationOperationID, method: "reading.preparation") == nil,
               let existing = try await listBooks().first(where: { $0.id == book.id }) {
                record.completedBook = existing; try saveAdmission(record); return existing
            }
            add = ["sourceId": book.sourceId, "bookId": book.bookId, "title": book.title, "author": book.author, "requireReadable": true]
            if let cover = book.coverUrl { add["coverUrl"] = cover }
            if let intro = book.intro { add["intro"] = intro }
            if let kind = book.kind { add["kind"] = kind }
            let preparationData: Data
            do {
                preparationData = try await coreMutation("reading.preparation", ["action": "begin", "reason": "add", "sourceId": book.sourceId,
                    "bookId": book.bookId, "pendingAdd": add], operationID: record.preparationOperationID, scope: "online-preparation:" + book.id)
            } catch {
                if let rejection = ReaderOnlineAdmissionRejection(error) { record.rejection = rejection; try saveAdmission(record) }
                throw error
            }
            let prepared = try object(preparationData)
            guard let intent = (prepared["intents"] as? [[String: Any]])?.first,
                  intent["sourceId"] as? String == book.sourceId, intent["bookId"] as? String == book.bookId,
                  intent["reason"] as? String == "add", intent["state"] as? String == "active",
                  let revision = (intent["revision"] as? NSNumber)?.int64Value else { throw ReaderLibraryError.operationPending(operationID) }
            try await finishCoreOperation(record.preparationOperationID)
            let canonical = try await onlineChapters(for: book)
            guard canonical.contains(where: { $0.index == record.chapterIndex && $0.url == record.chapterURL && $0.title == record.chapterTitle }) else {
                throw ReaderLibraryError.operationPending(operationID)
            }
            let snapshot = try await directory(for: book)
            guard let node = snapshot.nodes.first(where: { $0.navigable && $0.chapterIndex == record.chapterIndex }) else { throw ReaderLibraryError.operationPending(operationID) }
            // Core admission proves one of its first three readable chapters.
            // A deep selected landing chapter does not replace that proof.
            // Acquisition never writes a reading position.
            guard let first = snapshot.nodes.first(where: { $0.navigable }) else { throw ReaderLibraryError.operationPending(operationID) }
            if first.chapterIndex != record.chapterIndex {
                let firstTarget = try await resolveDirectoryTarget(first, in: snapshot)
                _ = try await onlineContent(for: book, chapterIndex: firstTarget.chapterIndex,
                    directoryTargetProof: try object(JSONEncoder().encode(firstTarget.directoryTargetProof)), preparationRevision: revision)
            }
            let target = try await resolveDirectoryTarget(node, in: snapshot)
            guard target.directoryTargetProof.url == record.chapterURL else { throw ReaderLibraryError.operationPending(operationID) }
            _ = try await onlineContent(for: book, chapterIndex: record.chapterIndex,
                directoryTargetProof: try object(JSONEncoder().encode(target.directoryTargetProof)), preparationRevision: revision)
            add["preparationRevision"] = revision
        }
        let addData: Data
        do {
            addData = try await coreMutation("bookshelf.add", add, operationID: operationID, scope: "shelf-add:" + book.id)
        } catch {
            if let rejection = ReaderOnlineAdmissionRejection(error) { record.rejection = rejection; try saveAdmission(record) }
            throw error
        }
        let response = try object(addData)
        guard response["sourceId"] as? String == book.sourceId, response["bookId"] as? String == book.bookId else { throw ReaderLibraryError.operationPending(operationID) }
        record.addAcknowledged = true
        try saveAdmission(record)
        try await finishCoreOperation(operationID)
        // The saved original terminal above is the ACK; a fresh read only
        // projects the already confirmed shelf for the returning screen.
        guard let added = try await listBooks().first(where: { $0.id == book.id }) else { throw ReaderLibraryError.operationPending(operationID) }
        record.completedBook = added
        try saveAdmission(record)
        return added
    }

    func pendingOnlineAdmissions() throws -> [ReaderPendingCoreCommand] {
        try admissionRecords().filter { $0.completedBook == nil && $0.rejection == nil }.map { .init(id: $0.operationID, method: "online.admission", scope: $0.book.id, acknowledged: $0.addAcknowledged == true) }
    }
    func onlineAdmissionRejection(_ operationID: String) throws -> ReaderLibraryError? { try admissionRecord(operationID)?.rejection?.error }
    func hasOnlineAdmission(_ operationID: String) throws -> Bool { try admissionRecord(operationID) != nil }
    func onlineAdmissionOwnerID(forCoreOperationID operationID: String) throws -> String? {
        try admissionRecords().first(where: { $0.operationID == operationID || $0.preparationOperationID == operationID })?.operationID
    }
    private func admissionDirectory() throws -> URL {
        let directory = operationsURL.appendingPathComponent("online-admissions", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
    private func admissionURL(_ id: String) throws -> URL {
        let hash = SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
        return try admissionDirectory().appendingPathComponent(hash + ".json")
    }
    private func admissionRecord(_ id: String) throws -> ReaderOnlineAdmission? {
        let url = try admissionURL(id)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let record = try JSONDecoder().decode(ReaderOnlineAdmission.self, from: Data(contentsOf: url))
        guard record.operationID == id else { throw ReaderLibraryError.invalidResponse("online admission journal identity") }
        return record
    }
    private func admissionRecords() throws -> [ReaderOnlineAdmission] {
        try FileManager.default.contentsOfDirectory(at: admissionDirectory(), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.map { try JSONDecoder().decode(ReaderOnlineAdmission.self, from: Data(contentsOf: $0)) }
    }
    private func saveAdmission(_ record: ReaderOnlineAdmission) throws {
        try JSONEncoder().encode(record).write(to: admissionURL(record.operationID), options: .atomic)
    }
}
