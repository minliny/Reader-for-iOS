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
    var continuation: ReaderOnlineAdmissionContinuation?
    var completionKind: String?
}

/// Frozen witnesses authorize exactly one separate explicit Host command.
/// This marker and its child ACK never rewrite the original add's unknown ACK.
private struct ReaderOnlineAdmissionContinuation: Codable, Equatable {
    let operationID: String
    let parameters: Data
    let preparationIntent: Data
    let catalog: Data
    let sourceVersion: String
    let cachedChapterFingerprint: String
}

private struct ReaderOnlineAdmissionContinuationBlocked: LocalizedError {
    let message: String
    var errorDescription: String? { message }
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
            add = admissionAddParameters(for: book)
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
                try await prepareAdmissionDocument(for: book, chapterIndex: firstTarget.chapterIndex)
            }
            let target = try await resolveDirectoryTarget(node, in: snapshot)
            guard target.directoryTargetProof.url == record.chapterURL else { throw ReaderLibraryError.operationPending(operationID) }
            _ = try await onlineContent(for: book, chapterIndex: record.chapterIndex,
                directoryTargetProof: try object(JSONEncoder().encode(target.directoryTargetProof)), preparationRevision: revision)
            // A cached chapter.content reply supplies text but does not publish
            // the normalized reader document required by strict bookshelf.add.
            // Prepare the real cached chapter before creating any add command.
            try await prepareAdmissionDocument(for: book, chapterIndex: record.chapterIndex)
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
        try admissionRecords().first(where: { $0.operationID == operationID || $0.preparationOperationID == operationID ||
            $0.continuation?.operationID == operationID })?.operationID
    }

    /// Recovery of the original intent is observational. It may consume its
    /// retained ACK, but never starts preparation, an old add, or continuation.
    func reconcileOnlineAdmission(_ operationID: String) async throws -> ReaderFeatureRecoveryResult {
        guard var record = try admissionRecord(operationID) else { throw ReaderLibraryError.invalidResponse("online admission owner missing") }
        if record.completionKind == "continued" {
            guard try completedAdmissionContinuation(originalID: operationID,
                parameters: record.continuation?.parameters ?? Data(), scope: "shelf-add:" + record.book.id) != nil else {
                return .init(operationID: operationID, status: .pending, message: "续办记录尚未核对，原操作回执仍未知。")
            }
            return continuedAdmissionResult(operationID)
        }
        if record.completedBook != nil { return .init(operationID: operationID, status: .completed) }
        if let rejection = record.rejection { return .init(operationID: operationID, status: .rejected, message: rejection.error.localizedDescription) }
        if try existingCoreParameters(operationID: operationID, method: "bookshelf.add") == nil,
           let rejection = try retainedPreparationRejection(record) {
            record.rejection = rejection
            try saveAdmission(record)
            return .init(operationID: operationID, status: .rejected, message: rejection.error.localizedDescription)
        }
        do {
            guard let original = try existingCoreParameters(operationID: operationID, method: "bookshelf.add"),
                  original["sourceId"] as? String == record.book.sourceId,
                  original["bookId"] as? String == record.book.bookId else { throw ReaderLibraryError.operationPending(operationID) }
            let receipt = try object(await reconcileCoreCommand(operationID: operationID))
            guard receipt["sourceId"] as? String == record.book.sourceId,
                  receipt["bookId"] as? String == record.book.bookId else { throw ReaderLibraryError.operationPending(operationID) }
            record.addAcknowledged = true
            try saveAdmission(record)
            try await finishCoreOperation(operationID)
            guard let book = try await bookDetails(for: record.book) else { throw ReaderLibraryError.operationPending(operationID) }
            record.completedBook = book; try saveAdmission(record)
            return .init(operationID: operationID, status: .completed)
        } catch {
            if let rejection = ReaderOnlineAdmissionRejection(error) {
                record.rejection = rejection; try saveAdmission(record)
                return .init(operationID: operationID, status: .rejected, message: error.localizedDescription)
            }
            return .init(operationID: operationID, status: .pending,
                message: record.continuation == nil ? "原操作回执仍未知；核对没有重新派发入库。" : "原操作回执仍未知；续办结果须通过继续完成入库核对。")
        }
    }

    /// Called only by the explicit second recovery action. A journaled child,
    /// including a send whose reply was lost, is reconciled and never replayed.
    public func continuePendingOnlineAdmission(_ operationID: String) async throws -> ReaderFeatureRecoveryResult {
        guard var record = try admissionRecord(operationID) else { throw ReaderLibraryError.invalidResponse("online admission owner missing") }
        if record.completionKind == "continued" { return try await reconcileOnlineAdmission(operationID) }
        if let rejection = record.rejection {
            return .init(operationID: operationID, status: .rejected, message: rejection.error.localizedDescription)
        }
        guard record.completedBook == nil, record.rejection == nil, record.addAcknowledged != true,
              onlineAdmissionContinuationsInFlight.insert(operationID).inserted else {
            return .init(operationID: operationID, status: .pending, message: "当前入库操作尚不能续办，原记录已保留。")
        }
        defer { onlineAdmissionContinuationsInFlight.remove(operationID) }
        let childID = operationID + ":continuation:v1"
        let scope = "online-admission-continuation:" + operationID
        do {
            if try existingCoreParameters(operationID: operationID, method: "bookshelf.add") == nil {
                // The preparation's definite failure can be durable before
                // the admission catches it. Both recovery actions project
                // that same original ACK without trying preparation again.
                if let rejection = try retainedPreparationRejection(record) {
                    record.rejection = rejection
                    try saveAdmission(record)
                    return .init(operationID: operationID, status: .rejected, message: rejection.error.localizedDescription)
                }
                try await requireAcknowledgedPreparationBeforeFirstAdd(record)
                do {
                    _ = try await resumeOnlineAdmission(operationID)
                    return .init(operationID: operationID, status: .completed, message: "原入库操作已继续并确认。")
                } catch {
                    if let rejection = try admissionRecord(operationID)?.rejection {
                        return .init(operationID: operationID, status: .rejected, message: rejection.error.localizedDescription)
                    }
                    throw error
                }
            }
            let frozen = try coldUnknownCoreParameters(operationID: operationID, method: "bookshelf.add", scope: "shelf-add:" + record.book.id)
            let parameters = try object(frozen)
            guard parameters["sourceId"] as? String == record.book.sourceId,
                  parameters["bookId"] as? String == record.book.bookId else { throw continuationBlocked("原入库身份已变化") }
            let data: Data
            if let child = try recordedCoreCommandParameters(operationID: childID, method: "bookshelf.add", scope: scope) {
                guard let marker = record.continuation, marker.operationID == childID, marker.parameters == frozen, child == frozen else {
                    throw continuationBlocked("续办操作与原记录不一致")
                }
                data = try await reconcileCoreCommand(operationID: childID)
            } else {
                let witness = try await continuationWitness(record, parameters: frozen)
                if let marker = record.continuation {
                    guard marker == witness else { throw continuationBlocked("书源、准备记录、目录或缓存正文已变化") }
                } else {
                    record.continuation = witness
                    try saveAdmission(record) // Durable before preparation or child send.
                }
                try await prepareAdmissionDocument(for: record.book, chapterIndex: record.chapterIndex)
                guard try await continuationWitness(record, parameters: frozen) == witness else {
                    throw continuationBlocked("准备期间书源、目录或缓存正文已变化")
                }
                // No suspension between the final Host owner checks and the
                // child journal/send reservation inside coreMutation.
                guard try coldUnknownCoreParameters(operationID: operationID, method: "bookshelf.add", scope: "shelf-add:" + record.book.id) == frozen,
                      try admissionRecord(operationID)?.continuation == witness else { throw continuationBlocked("原操作身份已变化") }
                data = try await coreMutation("bookshelf.add", parameters, operationID: childID, scope: scope)
            }
            let receipt = try object(data)
            guard receipt["created"] as? Bool == true, receipt["sourceId"] as? String == record.book.sourceId,
                  receipt["bookId"] as? String == record.book.bookId else { throw continuationBlocked("续办没有返回匹配的新入库回执") }
            try await finishCoreOperation(childID)
            record.completedBook = record.book
            record.completionKind = "continued"
            // addAcknowledged belongs only to the original command and stays nil.
            try saveAdmission(record)
            return continuedAdmissionResult(operationID)
        } catch {
            let detail = (error as? ReaderOnlineAdmissionContinuationBlocked)?.message
            return .init(operationID: operationID, status: .pending, message: detail.map { $0 + "，已停止续办；原操作回执仍未知。" } ??
                "续办结果尚未确认，已停止再次派发；原操作回执仍未知。")
        }
    }

    /// A historical unknown command may stop occupying the new-add scope only
    /// after its own marker and the separate child's exact durable ACK agree.
    func completedAdmissionContinuation(originalID: String, parameters: Data, scope: String) throws -> String? {
        guard let record = try admissionRecord(originalID), record.completionKind == "continued",
              record.addAcknowledged != true, record.completedBook?.id == record.book.id,
              scope == "shelf-add:" + record.book.id, let marker = record.continuation,
              marker.operationID == originalID + ":continuation:v1", marker.parameters == parameters,
              try coldUnknownCoreParameters(operationID: originalID, method: "bookshelf.add", scope: scope) == parameters else { return nil }
        let child = try completedCoreCommand(operationID: marker.operationID, method: "bookshelf.add", scope: "online-admission-continuation:" + originalID)
        let receipt = try object(child.result)
        guard child.parameters == parameters, receipt["created"] as? Bool == true,
              receipt["sourceId"] as? String == record.book.sourceId,
              receipt["bookId"] as? String == record.book.bookId else { return nil }
        return marker.operationID
    }

    /// Blocks another same-book owner while continuation is prepared/in flight.
    /// Its private scope bypasses only the one registered unknown original.
    func requireOnlineAdmissionDispatchOwner(operationID: String, parameters: Data, scope: String) throws {
        let params = try object(parameters)
        guard params["sourceId"] as? String != "local" else { return }
        for record in try admissionRecords() where record.completedBook == nil && record.rejection == nil &&
            record.book.sourceId == params["sourceId"] as? String && record.book.bookId == params["bookId"] as? String {
            if operationID == record.operationID && record.continuation == nil { continue }
            guard let marker = record.continuation, marker.operationID == operationID,
                  operationID == record.operationID + ":continuation:v1", marker.parameters == parameters,
                  scope == "online-admission-continuation:" + record.operationID,
                  try coldUnknownCoreParameters(operationID: record.operationID, method: "bookshelf.add", scope: "shelf-add:" + record.book.id) == parameters,
                  !(try hasOtherUnfinishedShelfAdd(sourceID: record.book.sourceId, bookID: record.book.bookId, excluding: [record.operationID])) else {
                throw ReaderLibraryError.operationPending(record.operationID)
            }
        }
    }

    private func continuedAdmissionResult(_ id: String) -> ReaderFeatureRecoveryResult {
        .init(operationID: id, status: .continued, message: "已通过续办操作完成入库；原操作回执仍未知。")
    }
    private func continuationBlocked(_ message: String) -> ReaderOnlineAdmissionContinuationBlocked { .init(message: message) }

    private func retainedPreparationRejection(_ record: ReaderOnlineAdmission) throws -> ReaderOnlineAdmissionRejection? {
        guard let failure = try definiteCoreCommandRejection(operationID: record.preparationOperationID,
            method: "reading.preparation", scope: "online-preparation:" + record.book.id) else { return nil }
        return ReaderOnlineAdmissionRejection(failure)
    }

    private func admissionAddParameters(for book: ReaderBook) -> [String: Any] {
        var add: [String: Any] = ["sourceId": book.sourceId, "bookId": book.bookId,
            "title": book.title, "author": book.author, "requireReadable": true]
        if let cover = book.coverUrl { add["coverUrl"] = cover }
        if let intro = book.intro { add["intro"] = intro }
        if let kind = book.kind { add["kind"] = kind }
        return add
    }

    /// Before any add was journaled, a confirmed preparation ACK can resume
    /// the original operation. An unknown preparation ACK cannot authorize it.
    private func requireAcknowledgedPreparationBeforeFirstAdd(_ record: ReaderOnlineAdmission) async throws {
        let book = record.book
        guard record.continuation == nil, record.preparationOperationID == record.operationID + ":preparation",
              !(try hasOtherUnfinishedShelfAdd(sourceID: book.sourceId, bookID: book.bookId, excluding: [])) else {
            throw continuationBlocked("原入库阶段或同书操作不满足首次续办条件")
        }
        let prepared = try acknowledgedCoreCommand(operationID: record.preparationOperationID,
            method: "reading.preparation", scope: "online-preparation:" + book.id)
        let parameters = try object(prepared.parameters)
        let expectedAdd = admissionAddParameters(for: book)
        guard parameters["action"] as? String == "begin", parameters["reason"] as? String == "add",
              parameters["sourceId"] as? String == book.sourceId, parameters["bookId"] as? String == book.bookId,
              let pendingAdd = parameters["pendingAdd"] as? [String: Any],
              try admissionJSON(pendingAdd) == admissionJSON(expectedAdd),
              let originalIntents = try object(prepared.result)["intents"] as? [[String: Any]],
              originalIntents.count == 1 else { throw continuationBlocked("原准备回执未确认或身份不一致") }
        let original = originalIntents[0]
        guard original["sourceId"] as? String == book.sourceId, original["bookId"] as? String == book.bookId,
              original["reason"] as? String == "add", original["state"] as? String == "active",
              let revision = original["revision"] as? NSNumber, revision.int64Value > 0,
              let version = original["sourceVersion"] as? String, !version.isEmpty else {
            throw continuationBlocked("原准备回执未确认或身份不一致")
        }
        let status = try object(await coreRead("reading.preparation", ["action": "status", "sourceId": book.sourceId,
            "bookId": book.bookId]))
        guard let intents = status["intents"] as? [[String: Any]], intents.count == 1 else {
            throw continuationBlocked("当前准备记录未确认")
        }
        let current = intents[0]
        guard let originalPending = original["pendingAdd"] as? [String: Any],
              let statusPending = current["pendingAdd"] as? [String: Any],
              try admissionJSON(originalPending) == admissionJSON(statusPending) else {
            throw continuationBlocked("当前准备记录已变化")
        }
        var currentPending = statusPending
        if (currentPending["sortIndex"] as? NSNumber)?.int64Value == 0 { currentPending.removeValue(forKey: "sortIndex") }
        guard current["sourceId"] as? String == book.sourceId, current["bookId"] as? String == book.bookId,
              current["reason"] as? String == "add", current["state"] as? String == "active",
              current["revision"] as? NSNumber == revision, current["sourceVersion"] as? String == version,
              try admissionJSON(currentPending) == admissionJSON(expectedAdd),
              current["entryChapterIndex"] as? NSNumber == original["entryChapterIndex"] as? NSNumber else {
            throw continuationBlocked("当前准备记录已变化")
        }
        let sources = try object(await coreRead("source.list", ["sourceId": book.sourceId]))
        guard let rows = sources["sources"] as? [[String: Any]], rows.count == 1,
              rows[0]["sourceId"] as? String == book.sourceId, rows[0]["enabled"] as? Bool == true,
              rows[0]["sourceVersion"] as? String == version else { throw continuationBlocked("原书源已变化或不可用") }
        let shelf = try object(await coreRead("bookshelf.get", ["sourceId": book.sourceId, "bookId": book.bookId]))
        guard shelf["book"] is NSNull else { throw continuationBlocked("当前书架状态不满足首次续办条件") }
    }

    private func continuationWitness(_ record: ReaderOnlineAdmission, parameters: Data) async throws -> ReaderOnlineAdmissionContinuation {
        let book = record.book, add = try object(parameters)
        guard book.sourceId != "local", add["sourceId"] as? String == book.sourceId, add["bookId"] as? String == book.bookId,
              add["title"] as? String == book.title, add["author"] as? String == book.author,
              add["requireReadable"] as? Bool == true,
              let revision = add["preparationRevision"] as? NSNumber, revision.int64Value > 0,
              !(try hasOtherUnfinishedShelfAdd(sourceID: book.sourceId, bookID: book.bookId, excluding: [record.operationID])) else {
            throw continuationBlocked("原入库参数或同书操作不满足续办条件")
        }
        let prepared = try completedCoreCommand(operationID: record.preparationOperationID, method: "reading.preparation", scope: "online-preparation:" + book.id)
        let prepParams = try object(prepared.parameters)
        var initialAdd = add; initialAdd.removeValue(forKey: "preparationRevision")
        guard prepParams["action"] as? String == "begin", prepParams["reason"] as? String == "add",
              prepParams["sourceId"] as? String == book.sourceId, prepParams["bookId"] as? String == book.bookId,
              let pendingAdd = prepParams["pendingAdd"] as? [String: Any], try admissionJSON(pendingAdd) == admissionJSON(initialAdd),
              let originalIntents = try object(prepared.result)["intents"] as? [[String: Any]], originalIntents.count == 1 else {
            throw continuationBlocked("原准备回执与入库参数不一致")
        }
        let originalIntent = originalIntents[0]
        guard originalIntent["sourceId"] as? String == book.sourceId, originalIntent["bookId"] as? String == book.bookId,
              originalIntent["reason"] as? String == "add", originalIntent["state"] as? String == "active",
              originalIntent["revision"] as? NSNumber == revision,
              let version = originalIntent["sourceVersion"] as? String, !version.isEmpty else { throw continuationBlocked("原准备身份或版本不一致") }
        let status = try object(await coreRead("reading.preparation", ["action": "status", "sourceId": book.sourceId, "bookId": book.bookId]))
        guard let intents = status["intents"] as? [[String: Any]], intents.count == 1 else { throw continuationBlocked("原准备记录已变化") }
        let intent = intents[0]
        guard intent["sourceId"] as? String == book.sourceId, intent["bookId"] as? String == book.bookId,
              intent["state"] as? String == "active", intent["reason"] as? String == "add",
              intent["revision"] as? NSNumber == revision, intent["sourceVersion"] as? String == version,
              let originalPending = originalIntent["pendingAdd"] as? [String: Any], let currentPending = intent["pendingAdd"] as? [String: Any],
              try admissionJSON(originalPending) == admissionJSON(currentPending) else { throw continuationBlocked("原准备记录已变化") }
        var normalizedPending = currentPending
        if (normalizedPending["sortIndex"] as? NSNumber)?.int64Value == 0 { normalizedPending.removeValue(forKey: "sortIndex") }
        guard try admissionJSON(normalizedPending) == admissionJSON(initialAdd),
              intent["entryChapterIndex"] as? NSNumber == originalIntent["entryChapterIndex"] as? NSNumber else {
            throw continuationBlocked("原准备书籍或章节已变化")
        }
        let sources = try object(await coreRead("source.list", ["sourceId": book.sourceId]))
        guard let rows = sources["sources"] as? [[String: Any]], rows.count == 1,
              rows[0]["sourceId"] as? String == book.sourceId, rows[0]["enabled"] as? Bool == true,
              rows[0]["sourceVersion"] as? String == version else { throw continuationBlocked("书源已改变或不可用") }
        let catalog = try object(await coreRead("cache.book.status", ["sourceId": book.sourceId, "bookId": book.bookId,
            "includeGlobalStats": false, "includeChapterStates": true]))
        guard catalog["sourceId"] as? String == book.sourceId, catalog["bookId"] as? String == book.bookId,
              catalog["sourceVersion"] as? String == version, catalog["tocAvailable"] as? Bool == true,
              let chapters = catalog["chapters"] as? [[String: Any]],
              let first = chapters.first(where: { $0["navigable"] as? Bool != false }),
              (first["chapterIndex"] as? NSNumber)?.uint64Value == UInt64(record.chapterIndex),
              first["url"] as? String == record.chapterURL, first["title"] as? String == record.chapterTitle,
              ["cached", "completed"].contains(first["state"] as? String ?? ""),
              (first["cachedBytes"] as? NSNumber)?.uint64Value ?? 0 > 0 else { throw continuationBlocked("原首章目录或缓存已变化") }
        let shelf = try object(await coreRead("bookshelf.get", ["sourceId": book.sourceId, "bookId": book.bookId]))
        guard shelf["book"] is NSNull else { throw continuationBlocked("当前书架状态不满足续办条件") }
        let body = try object(await coreRead("chapter.content", ["sourceId": book.sourceId, "bookId": book.bookId,
            "chapterIndex": record.chapterIndex, "cacheOnly": true]))
        guard body["sourceId"] as? String == book.sourceId, body["bookId"] as? String == book.bookId,
              body["via"] as? String == "cache", let text = body["content"] as? String, !text.isEmpty,
              let bodyVersion = body["bodyVersion"] as? String, !bodyVersion.isEmpty,
              let processingVersion = body["processingVersion"] as? String, !processingVersion.isEmpty,
              body["contentRefreshRequired"] as? Bool != true, body["sourceCorrectionRequired"] as? Bool != true else {
            throw continuationBlocked("原首章没有可用的当前缓存正文")
        }
        let fingerprint = SHA256.hash(data: try admissionJSON(body)).map { String(format: "%02x", $0) }.joined()
        var catalogIdentity: [String: Any] = ["sourceId": book.sourceId, "bookId": book.bookId, "sourceVersion": version, "chapter": first]
        for key in ["catalogVersion", "contextVersion", "catalogAt"] { catalogIdentity[key] = catalog[key] }
        return .init(operationID: record.operationID + ":continuation:v1", parameters: parameters,
            preparationIntent: try admissionJSON(intent), catalog: try admissionJSON(catalogIdentity), sourceVersion: version,
            cachedChapterFingerprint: fingerprint)
    }
    private func admissionJSON(_ value: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) }
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

    private func prepareAdmissionDocument(for book: ReaderBook, chapterIndex: UInt32) async throws {
        let data = try await coreRead("reading.entry.prepare", ["sourceId": book.sourceId,
            "bookId": book.bookId, "chapterIndex": chapterIndex, "neighborOffset": 0])
        let receipt = try object(data)
        guard receipt["kind"] as? String == "ready",
              receipt["sourceId"] as? String == book.sourceId,
              receipt["bookId"] as? String == book.bookId,
              (receipt["chapterIndex"] as? NSNumber)?.int64Value == Int64(chapterIndex) else {
            throw ReaderLibraryError.operationPending("reading.entry.prepare")
        }
    }
}
