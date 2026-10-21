import Foundation
import CryptoKit

public struct ReaderPendingCoreCommand: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let method: String
    public let scope: String
    public let acknowledged: Bool
}

/// Durable Host coordination only. Business facts and original receipt queries
/// stay Core-owned; a new read can never confirm a dispatched unknown mutation.
private struct ReaderHostCommand: Codable {
    let id: String
    let method: String
    let scope: String
    let parameters: Data
    var result: Data?
    var completed: Bool = false
    var failure: ReaderHostCommandFailure? = nil
    init(id: String, method: String, scope: String, parameters: Data, result: Data?) {
        self.id = id; self.method = method; self.scope = scope; self.parameters = parameters; self.result = result
    }
    private enum CodingKeys: String, CodingKey { case id, method, scope, parameters, result, completed, failure }
    init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        id = try v.decode(String.self, forKey: .id)
        method = try v.decode(String.self, forKey: .method)
        scope = try v.decode(String.self, forKey: .scope)
        parameters = try v.decode(Data.self, forKey: .parameters)
        result = try v.decodeIfPresent(Data.self, forKey: .result)
        completed = try v.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        failure = try v.decodeIfPresent(ReaderHostCommandFailure.self, forKey: .failure)
    }
}
private struct ReaderHostCommandFailure: Codable {
    let code: String
    let message: String
    let retryable: Bool
    let reason: String?
    init?(_ error: Error) {
        guard case ReaderLibraryError.core(let code, let message, let retryable, let reason) = error else { return nil }
        self.code = code; self.message = message; self.retryable = retryable; self.reason = reason
    }
    var error: ReaderLibraryError { .core(code: code, message: message, retryable: retryable, reason: reason) }
}

/// Only an error carried inside Core's exact original receipt may settle a
/// cold write as rejected. Failure of the receipt query itself cannot do so.
private struct ReaderOriginalCommandRejection: Error { let error: ReaderLibraryError }

/// A terminal transport response describing a retained Core job, rather than
/// a rejection or completion of that job. Its durable Host intent stays open.
struct ReaderCoreOriginalOperationPending: Error {}

extension ReaderLibraryService {
    func coreRead(_ method: String, _ parameters: [String: Any], timeout: TimeInterval = 30) async throws -> Data {
        try await request(method, parameters, timeout: timeout)
    }

    func coreMutation(_ method: String, _ parameters: [String: Any], operationID: String, scope: String,
                      timeout: TimeInterval = 30) async throws -> Data {
        guard !operationID.isEmpty, !scope.isEmpty else { throw ReaderLibraryError.invalidResponse("mutation identity") }
        let encoded = try JSONSerialization.data(withJSONObject: parameters, options: [.sortedKeys])
        if let original = try commandRecord(operationID) {
            guard original.method == method, original.parameters == encoded, original.scope == scope else {
                throw ReaderLibraryError.invalidResponse("operation identity reused for another mutation")
            }
            return try await reconcileCoreCommand(operationID: operationID)
        }
        // This scope remains occupied across suspension and process restart.
        guard try commandRecords().allSatisfy({ $0.completed || $0.scope != scope }) else { throw ReaderLibraryError.operationPending(scope) }
        try Task.checkCancellation()
        var record = ReaderHostCommand(id: operationID, method: method, scope: scope, parameters: encoded, result: nil)
        try storeCommand(record)
        do {
            let result = try await request(method, parameters, mutation: true, timeout: timeout, owner: .command(operationID))
            record.result = result
            try storeCommand(record)
            finishMutation(.command(operationID))
            return result
        } catch {
            if error is ReaderCoreOriginalOperationPending {
                finishMutation(.command(operationID))
                throw ReaderLibraryError.operationPending(operationID)
            }
            if Self.isDefiniteMutationRejection(error) {
                record.failure = ReaderHostCommandFailure(error)
                record.completed = true
                try storeCommand(record)
                finishMutation(.command(operationID))
            }
            if Self.isDefiniteMutationRejection(error) { throw error }
            throw ReaderLibraryError.operationPending(operationID)
        }
    }

    public func performCoreCommand(method: String, parameters: Data, operationID: String? = nil,
                                   scope: String? = nil) async throws -> Data {
        let object = try self.object(parameters)
        if let operationID {
            guard let scope else { throw ReaderLibraryError.invalidResponse("mutation scope") }
            return try await coreMutation(method, object, operationID: operationID, scope: scope)
        }
        return try await coreRead(method, object)
    }

    public func pendingCoreCommands() throws -> [ReaderPendingCoreCommand] {
        try commandRecords().filter { !$0.completed }.map { ReaderPendingCoreCommand(id: $0.id, method: $0.method, scope: $0.scope, acknowledged: $0.result != nil) }
    }

    func isCoreOperationCompleted(_ operationID: String) throws -> Bool { try commandRecord(operationID)?.completed == true }

    /// Internal phase commands remain attached to their original feature
    /// owner. Matching uses both the registered stage ID and original binding.
    func pendingFeatureCommands() throws -> [ReaderPendingCoreCommand] {
        let records = try commandRecords()
        var owners: [String: ReaderPendingCoreCommand] = [:]
        for record in records where !record.completed {
            // The admission journal owns preparation and add together. Its
            // registered stage IDs, rather than a suffix guess, define that
            // boundary; neither child can bypass its remaining body check.
            if try onlineAdmissionOwnerID(forCoreOperationID: record.id) != nil { continue }
            let owner = try featureParent(of: record, records: records) ?? record
            owners[owner.id] = .init(id: owner.id, method: owner.method, scope: owner.scope, acknowledged: owner.result != nil)
        }
        return owners.values.sorted { $0.id < $1.id }
    }

    public func resumePendingFeatureOperation(_ operationID: String) async throws -> ReaderFeatureRecoveryResult {
        guard !operationID.isEmpty else { throw ReaderLibraryError.invalidResponse("feature recovery identity") }
        if let result = try await resumeLocalReprocessOperation(operationID) { return result }
        if let admissionID = try onlineAdmissionOwnerID(forCoreOperationID: operationID) {
            do {
                _ = try await resumeOnlineAdmission(admissionID)
                return .init(operationID: admissionID, status: .completed)
            } catch {
                if let rejection = try onlineAdmissionRejection(admissionID) {
                    return .init(operationID: admissionID, status: .rejected, message: rejection.localizedDescription)
                }
                // This owner also observes canonical content and the shelf.
                // A failed read cannot classify either original Core write.
                return .init(operationID: admissionID, status: .pending, message: error.localizedDescription)
            }
        }
        let records = try commandRecords()
        guard let selected = records.first(where: { $0.id == operationID }) else {
            return .init(operationID: operationID, status: .pending, message: "未找到原操作记录，尚不能确认结果。")
        }
        let original = try featureParent(of: selected, records: records) ?? selected
        guard try registeredFeatureCommand(original) else {
            return .init(operationID: operationID, status: .pending, message: "此原操作尚无可用的恢复入口，已保留记录。")
        }
        if let failure = original.failure {
            return .init(operationID: operationID, status: .rejected, message: failure.error.localizedDescription)
        }
        if original.completed {
            if try completedFeatureWasRejected(original, records: records) {
                return .init(operationID: operationID, status: .rejected, message: "原操作未完成，已保留确认结果。")
            }
            return .init(operationID: operationID, status: .completed)
        }
        do {
            try await resumeRegisteredFeature(original)
            return .init(operationID: operationID, status: .completed)
        } catch let error as ReaderSourceSwitchRolledBack {
            return .init(operationID: operationID, status: .rejected, message: error.localizedDescription)
        } catch let error as ReaderSourceSwitchRefreshRequired {
            return .init(operationID: operationID, status: .refreshRequired, message: error.localizedDescription)
        } catch {
            // A failed receipt *query* is not a rejection of the original
            // business write. Only an original retained terminal proves that.
            if let current = try commandRecord(original.id), let failure = current.failure {
                return .init(operationID: operationID, status: .rejected, message: failure.error.localizedDescription)
            }
            if let current = try commandRecord(original.id), current.completed,
               let data = current.result, let receipt = try? object(data), receipt["outcome"] as? String == "rejected" {
                return .init(operationID: operationID, status: .rejected, message: error.localizedDescription)
            }
            return .init(operationID: operationID, status: .pending, message: error.localizedDescription)
        }
    }

    private func completedFeatureWasRejected(_ record: ReaderHostCommand, records: [ReaderHostCommand]) throws -> Bool {
        if ["bookshelf.management.mutation.apply", "rules.mutation.apply"].contains(record.method),
           let data = record.result, try object(data)["outcome"] as? String == "rejected" { return true }
        guard record.method == "source.switch.commit",
              let rollback = records.first(where: { $0.id == record.id + ":rollback" && $0.method == "source.switch.rollback" && $0.completed }),
              let result = rollback.result else { return false }
        let original = try object(record.parameters), params = try object(rollback.parameters), terminal = try object(result)
        // These are retained original terminals, not a fresh phase observation.
        return params["transactionId"] as? String == original["operationId"] as? String &&
            terminal["transactionId"] as? String == original["operationId"] as? String &&
            terminal["phase"] as? String == "rolledBack" && terminal["changed"] is Bool
    }

    private func registeredFeatureCommand(_ record: ReaderHostCommand) throws -> Bool {
        let params = try object(record.parameters)
        if record.method == "bookshelf.management.mutation.apply" {
            return ["book-group.create", "book-group.update", "book-group.delete", "bookshelf.group.assign",
                    "bookshelf.remove", "bookshelf.removeBatch"].contains((params["mutation"] as? [String: Any])?["method"] as? String ?? "")
        }
        if record.method == "rules.mutation.apply" {
            return ["reading.directory.rules.apply.v2", "replace.persist", "txt-toc-rule.create", "txt-toc-rule.update",
                    "txt-toc-rule.delete", "dict-rule.put", "dict-rule.delete", "rule-sub.put", "rule-sub.delete",
                    "rule-sub.update.apply.v1", "rule-bundle.import", "reader.chinese-conversion.put",
                    "source.import", "source.update", "source.delete"].contains((params["mutation"] as? [String: Any])?["method"] as? String ?? "")
        }
        if record.method == "cache.book.prefetch" { return params["contentKind"] as? String == "text" }
        if record.method == "cache.storage.cleanup" { return params["contentScope"] as? String == "text" }
        return ["bookmark.create", "bookmark.delete", "bookmark.update", "book-highlight.create", "book-highlight.update",
                "book-highlight.delete", "read-record.accumulate", "read-record.deleteByBook",
                "reading.directory.rules.prepare.v2", "source.switch.commit", "cache.download.pause",
                "cache.download.resume", "cache.download.cancel", "cache.clear"].contains(record.method)
    }

    private func resumeRegisteredFeature(_ record: ReaderHostCommand) async throws {
        let params = try object(record.parameters)
        switch record.method {
        case "bookshelf.management.mutation.apply":
            guard let mutation = params["mutation"] as? [String: Any], let method = mutation["method"] as? String,
                  let business = mutation["params"] as? [String: Any] else { throw ReaderLibraryError.operationPending(record.id) }
            if ["bookshelf.remove", "bookshelf.removeBatch"].contains(method) {
                guard !assetMutationInFlight, !importInFlight, !recovering else { throw ReaderLibraryError.busy }
                assetMutationInFlight = true
                defer { assetMutationInFlight = false }
                let data = try await shelfMutation(method, business, operationID: record.id)
                if method == "bookshelf.removeBatch" {
                    guard let targets = business["targets"] as? [[String: Any]] else { throw ReaderLibraryError.operationPending(record.id) }
                    let identities = try targets.map { try recoveryBookIdentity($0) }
                    let receipt = try decode(ReaderRemovalReceipt.self, data)
                    guard receipt.requestedCount == UInt64(identities.count),
                          Set(receipt.removedTargets + receipt.missingTargets) == Set(identities),
                          receipt.removedTargets.allSatisfy({ identities.contains($0) }) else {
                        throw ReaderLibraryError.operationPending(record.id)
                    }
                    try cleanupRemovedLocalSources(receipt.removedTargets)
                } else {
                    let identity = try recoveryBookIdentity(business)
                    let receipt = try object(data)
                    guard let removed = receipt["removed"] as? Bool else { throw ReaderLibraryError.operationPending(record.id) }
                    if removed { try cleanupRemovedLocalSources([identity]) }
                }
            } else { _ = try await shelfMutation(method, business, operationID: record.id) }
        case "rules.mutation.apply":
            guard let mutation = params["mutation"] as? [String: Any], let method = mutation["method"] as? String,
                  let business = mutation["params"] as? [String: Any] else { throw ReaderLibraryError.operationPending(record.id) }
            _ = try await rulesMutation(method, business, operationID: record.id)
        case "source.switch.commit":
            guard let from = params["from"] as? [String: Any], let target = params["target"] as? [String: Any],
                  let chapter = (params["currentChapterIndex"] as? NSNumber)?.uint32Value,
                  let title = params["currentChapterTitle"] as? String, let targetTitle = target["title"] as? String else {
                throw ReaderLibraryError.operationPending(record.id)
            }
            let origin = try recoveryBookIdentity(from)
            let destination = try recoveryBookIdentity(target)
            _ = try await switchOnlineBook(from: ReaderBook(sourceId: origin.sourceId, bookId: origin.bookId, title: ""),
                currentChapterIndex: chapter, currentChapterTitle: title,
                candidate: ReaderOnlineCandidate(sourceId: destination.sourceId, bookId: destination.bookId,
                    title: targetTitle, author: target["author"] as? String ?? "", coverUrl: target["coverUrl"] as? String), operationID: record.id)
            return
        case "cache.book.prefetch":
            let book = try recoveryBook(params)
            guard let range = params["chapterRange"] as? [UInt32], range.count == 2, range[0] < range[1] else {
                throw ReaderLibraryError.operationPending(record.id)
            }
            _ = try await downloadChapters(book, range: range[0]..<range[1], operationID: record.id)
            return
        case "cache.download.pause", "cache.download.resume", "cache.download.cancel":
            let book = try recoveryBook(params)
            guard let chapter = (params["chapterIndex"] as? NSNumber)?.uint32Value else { throw ReaderLibraryError.operationPending(record.id) }
            if record.method == "cache.download.pause" { _ = try await pauseDownload(book, chapterIndex: chapter, operationID: record.id) }
            else if record.method == "cache.download.resume" { _ = try await resumeDownload(book, chapterIndex: chapter, operationID: record.id) }
            else { _ = try await cancelDownload(book, chapterIndex: chapter, operationID: record.id) }
            return
        case "cache.clear":
            let book = try recoveryBook(params)
            guard params["scope"] as? String == "chapter", let chapter = (params["chapterIndex"] as? NSNumber)?.uint32Value else {
                throw ReaderLibraryError.operationPending(record.id)
            }
            try await clearDownloadedChapter(book, chapterIndex: chapter, operationID: record.id)
            return
        default:
            // Registered metadata-only owners have no Host asset side effect.
            // Receipt reconciliation itself never redispatches an unknown write.
            _ = try await reconcileCoreCommand(operationID: record.id)
        }
        try await finishCoreOperation(record.id)
    }

    private func recoveryBookIdentity(_ params: [String: Any]) throws -> ReaderBookIdentity {
        guard let source = params["sourceId"] as? String, !source.isEmpty,
              let book = params["bookId"] as? String, !book.isEmpty else { throw ReaderLibraryError.invalidResponse("recovery book identity") }
        return .init(sourceId: source, bookId: book)
    }

    private func recoveryBook(_ params: [String: Any]) throws -> ReaderBook {
        let identity = try recoveryBookIdentity(params)
        return .init(sourceId: identity.sourceId, bookId: identity.bookId, title: params["title"] as? String ?? "")
    }

    private func featureParent(of child: ReaderHostCommand, records: [ReaderHostCommand]) throws -> ReaderHostCommand? {
        var current = child
        var seen: Set<String> = [child.id]
        while let parent = try directFeatureParent(of: current, records: records) {
            guard seen.insert(parent.id).inserted else { throw ReaderLibraryError.invalidResponse("feature owner cycle") }
            current = parent
        }
        return current.id == child.id ? nil : current
    }

    private func directFeatureParent(of child: ReaderHostCommand, records: [ReaderHostCommand]) throws -> ReaderHostCommand? {
        let params = try object(child.parameters)
        for parent in records where !parent.completed && parent.id != child.id {
            let original = try object(parent.parameters)
            if child.method == "bookmark.operation.settle", ["bookmark.create", "bookmark.delete"].contains(parent.method),
               child.id == parent.id + "-settlement", params["operationId"] as? String == original["operationId"] as? String,
               (params["sequence"] as? NSNumber) == (original["sequence"] as? NSNumber) { return parent }
            if ["source.switch.finalize", "source.switch.rollback", "reading.progress.update"].contains(child.method), parent.method == "source.switch.commit",
               child.id == parent.id + (child.method == "source.switch.finalize" ? ":finalize" : child.method == "source.switch.rollback" ? ":rollback" : ":canonical"),
               params["transactionId"] as? String == original["operationId"] as? String { return parent }
            if child.method == "cache.book.prefetch", parent.method == "cache.download.resume", child.id == parent.id + ":acquire",
               params["sourceId"] as? String == original["sourceId"] as? String,
               params["bookId"] as? String == original["bookId"] as? String,
               let chapter = (original["chapterIndex"] as? NSNumber)?.uint32Value, chapter < UInt32.max,
               params["chapterRange"] as? [UInt32] == [chapter, chapter + 1] { return parent }
            if child.method == "cache.chapter.materialization.report", parent.method == "cache.book.prefetch",
               params["sourceId"] as? String == original["sourceId"] as? String,
               params["bookId"] as? String == original["bookId"] as? String,
               let chapter = (params["chapterIndex"] as? NSNumber)?.uint32Value,
               child.id == parent.id + ":materialize:" + String(chapter),
               let payload = parent.result, let result = try? object(payload),
               let leases = result["materializations"] as? [[String: Any]],
               leases.contains(where: { ($0["chapterIndex"] as? NSNumber)?.uint32Value == chapter &&
                   $0["token"] as? String == params["token"] as? String }) { return parent }
            if ["cache.download.operation.settle", "cache.clear.operation.settle"].contains(child.method),
               child.id == parent.id + ":settle",
               params["operationId"] as? String == original["operationId"] as? String,
               params["sequence"] as? NSNumber == original["sequence"] as? NSNumber { return parent }
        }
        return nil
    }

    /// Resume the exact original payload, including sequence and timestamp.
    /// This is Host coordination metadata, never evidence of a Core ACK.
    func existingCoreParameters(operationID: String, method: String) throws -> [String: Any]? {
        guard let record = try commandRecord(operationID) else { return nil }
        guard record.method == method else { throw ReaderLibraryError.invalidResponse("operation method identity") }
        return try object(record.parameters)
    }

    /// Core finite lineages require UUID/sequence. Host UI operation IDs stay
    /// unchanged in the journal; the complete Core tuple is frozen before send.
    func coreLineageID(_ operationID: String, sequence: UInt64) -> String {
        let digest = SHA256.hash(data: Data(operationID.utf8)).map { String(format: "%02x", $0) }.joined()
        let hex = Array(digest.prefix(32))
        let uuid = [String(hex[0..<8]), String(hex[8..<12]), String(hex[12..<16]), String(hex[16..<20]), String(hex[20..<32])].joined(separator: "-")
        return uuid + "/" + String(sequence)
    }

    public func reconcileCoreCommand(operationID: String) async throws -> Data {
        guard var record = try commandRecord(operationID) else { throw ReaderLibraryError.invalidResponse("unknown operation identity") }
        if let failure = record.failure { throw failure.error }
        if let result = record.result { return result }
        let owner = PendingMutationOwner.command(operationID)
        try drainUnresolvedReplies(owner: owner)
        if let (id, pending) = unresolvedWrites.first(where: { $0.value.owner == owner }) {
            guard !activeRequests.contains(id), let terminal = pending.terminal else { throw ReaderLibraryError.operationPending(operationID) }
            do {
                record.result = try responseData(terminal, method: pending.method, requestID: id)
                try storeCommand(record)
                finishMutation(owner)
                return record.result!
            } catch {
                if error is ReaderCoreOriginalOperationPending {
                    // The response itself has terminated. The original job
                    // remains in Core and may only continue by exact query.
                    finishMutation(owner)
                } else {
                    if Self.isDefiniteMutationRejection(error) {
                        record.failure = ReaderHostCommandFailure(error)
                        record.completed = true
                        try storeCommand(record)
                        finishMutation(owner)
                    }
                    if Self.isDefiniteMutationRejection(error) { throw error }
                    throw ReaderLibraryError.operationPending(operationID)
                }
            }
        }
        // Across a process boundary only an exact finite Core receipt can settle
        // this original command. An absent receipt never authorizes redispatch.
        do {
            if let receipt = try await exactCommandReceipt(record) {
                record.result = receipt
                try storeCommand(record)
                return receipt
            }
        } catch let rejection as ReaderOriginalCommandRejection {
            record.failure = ReaderHostCommandFailure(rejection.error)
            record.completed = true
            try storeCommand(record)
            throw rejection.error
        } catch {
            // This is failure of a receipt read, not the original mutation.
            throw ReaderLibraryError.operationPending(operationID)
        }
        throw ReaderLibraryError.operationPending(operationID)
    }

    func finishCoreOperation(_ operationID: String) async throws {
        guard var record = try commandRecord(operationID), record.result != nil else {
            throw ReaderLibraryError.operationPending(operationID)
        }
        if record.completed { return }
        // Core bookmark lineage must be settled using its original binding.
        if ["bookmark.create", "bookmark.delete"].contains(record.method),
           let params = try? object(record.parameters), params["operationId"] != nil {
            let action = record.method == "bookmark.create" ? "create" : "delete"
            let queried = try object(await coreRead("bookmark.operation.query", [
                "operationId": params["operationId"]!, "expected": ["action": action, "params": params]
            ]))
            guard let receipt = queried["receipt"] as? [String: Any],
                  let binding = receipt["binding"] as? [String: Any], binding["operationId"] as? String == params["operationId"] as? String else {
                throw ReaderLibraryError.operationPending(operationID)
            }
            let settlementID = operationID + "-settlement"
            _ = try await coreMutation("bookmark.operation.settle", binding, operationID: settlementID, scope: "bookmark-settlement")
            try await finishCoreOperation(settlementID)
        }
        try await settleDownloadCommand(method: record.method, parameters: try object(record.parameters), operationID: record.id)
        record.completed = true
        try storeCommand(record)
        finishMutation(.command(operationID))
    }

    /// Wrapper for the finite, Core-owned shelf lineage. Sequence comes from
    /// its real head; a repeated Host ID always keeps its original parameters.
    func shelfMutation(_ method: String, _ parameters: [String: Any], operationID: String) async throws -> Data {
        let wrapper = "bookshelf.management.mutation.apply"
        let mutation: [String: Any] = ["method": method, "params": parameters]
        let expected = try JSONSerialization.data(withJSONObject: mutation, options: [.sortedKeys])
        let original: [String: Any]
        if let record = try commandRecord(operationID) {
            original = try object(record.parameters)
            guard record.method == wrapper, let old = original["mutation"],
                  try JSONSerialization.data(withJSONObject: old, options: [.sortedKeys]) == expected else {
                throw ReaderLibraryError.invalidResponse("shelf operation identity")
            }
        } else {
            let head = try object(await coreRead("bookshelf.management.mutation.query", [:]))["head"] as? [String: Any]
            let sequence = (head?["sequence"] as? NSNumber)?.uint64Value ?? 0
            guard sequence < 9_007_199_254_740_991 else { throw ReaderLibraryError.invalidResponse("shelf sequence exhausted") }
            original = ["operationId": coreLineageID(operationID, sequence: sequence + 1), "sequence": sequence + 1, "mutation": mutation]
        }
        let data = try object(await coreMutation(wrapper, original, operationID: operationID, scope: "shelf-management"))
        guard data["method"] as? String == method,
              let binding = data["binding"] as? [String: Any], binding["operationId"] as? String == original["operationId"] as? String,
              (binding["sequence"] as? NSNumber) == (original["sequence"] as? NSNumber),
              let payload = data["data"] as? [String: Any] else { throw ReaderLibraryError.invalidResponse("shelf receipt") }
        if data["outcome"] as? String == "rejected" {
            try await finishCoreOperation(operationID)
            let failure = payload["error"] as? [String: Any] ?? [:]
            throw ReaderLibraryError.core(code: failure["code"] as? String ?? "INVALID_PARAMS",
                message: failure["message"] as? String ?? "书架操作未执行", retryable: false, reason: nil)
        }
        guard data["outcome"] as? String == "applied" else { throw ReaderLibraryError.invalidResponse("shelf outcome") }
        return try JSONSerialization.data(withJSONObject: payload)
    }

    /// All rule/source collection writes share Core's finite lineage. Calling
    /// a legacy collection writer after this lineage opens is not permitted.
    func rulesMutation(_ method: String, _ parameters: [String: Any], operationID: String) async throws -> Data {
        let wrapper = "rules.mutation.apply"
        let mutation: [String: Any] = ["method": method, "params": parameters]
        let expected = try JSONSerialization.data(withJSONObject: mutation, options: [.sortedKeys])
        let original: [String: Any]
        if let record = try commandRecord(operationID) {
            original = try object(record.parameters)
            guard record.method == wrapper, let old = original["mutation"],
                  try JSONSerialization.data(withJSONObject: old, options: [.sortedKeys]) == expected else {
                throw ReaderLibraryError.invalidResponse("rules operation identity")
            }
        } else {
            let head = try object(await coreRead("rules.mutation.query", [:]))["head"] as? [String: Any]
            let sequence = (head?["sequence"] as? NSNumber)?.uint64Value ?? 0
            guard sequence < 9_007_199_254_740_991 else { throw ReaderLibraryError.invalidResponse("rules sequence exhausted") }
            original = ["operationId": coreLineageID(operationID, sequence: sequence + 1), "sequence": sequence + 1, "mutation": mutation]
        }
        let response = try object(await coreMutation(wrapper, original, operationID: operationID, scope: "rules-mutation", timeout: 120))
        guard response["method"] as? String == method,
              let binding = response["binding"] as? [String: Any], binding["operationId"] as? String == original["operationId"] as? String,
              (binding["sequence"] as? NSNumber) == (original["sequence"] as? NSNumber),
              let payload = response["data"] as? [String: Any] else {
            throw ReaderLibraryError.operationPending(operationID)
        }
        if response["outcome"] as? String == "rejected" {
            try await finishCoreOperation(operationID)
            let failure = payload["error"] as? [String: Any] ?? [:]
            let details = failure["details"] as? [String: Any]
            throw ReaderLibraryError.core(code: failure["code"] as? String ?? "INVALID_PARAMS",
                message: failure["message"] as? String ?? "规则操作未执行", retryable: false,
                reason: details?["reason"] as? String)
        }
        guard response["outcome"] as? String == "applied" else { throw ReaderLibraryError.operationPending(operationID) }
        return try JSONSerialization.data(withJSONObject: payload)
    }

    func bookmarkMutation(_ method: String, _ parameters: [String: Any], operationID: String) async throws -> Data {
        var params = parameters
        if let record = try commandRecord(operationID) {
            let old = try object(record.parameters)
            var business = old; business.removeValue(forKey: "operationId"); business.removeValue(forKey: "sequence")
            guard record.method == method,
                  try JSONSerialization.data(withJSONObject: business, options: [.sortedKeys]) == JSONSerialization.data(withJSONObject: parameters, options: [.sortedKeys]) else {
                throw ReaderLibraryError.invalidResponse("bookmark operation identity")
            }
            params = old
        } else {
            let query = try object(await coreRead("bookmark.operation.query", [:]))
            let head = query["head"] as? [String: Any]
            let sequence = (head?["sequence"] as? NSNumber)?.uint64Value ?? 0
            guard sequence < 9_007_199_254_740_991 else { throw ReaderLibraryError.invalidResponse("bookmark sequence exhausted") }
            params["operationId"] = coreLineageID(operationID, sequence: sequence + 1); params["sequence"] = sequence + 1
        }
        return try await coreMutation(method, params, operationID: operationID, scope: "bookmarks")
    }

    private func exactCommandReceipt(_ record: ReaderHostCommand) async throws -> Data? {
        let params = try object(record.parameters)
        if isDownloadCommand(record.method) {
            return try await exactDownloadCommandReceipt(method: record.method, parameters: params, operationID: record.id)
        }
        if record.method == "read-record.accumulate" {
            let query = try object(await coreRead("read-record.accumulate-receipt", [:]))
            guard let receipt = query["receipt"] as? [String: Any],
                  let accumulated = receipt["record"] as? [String: Any] else { return nil }
            var original = receipt
            original.removeValue(forKey: "record")
            guard try JSONSerialization.data(withJSONObject: original, options: [.sortedKeys]) == record.parameters else { return nil }
            return try JSONSerialization.data(withJSONObject: ["record": accumulated, "receipt": receipt])
        }
        if record.method == "source.switch.commit" {
            let query = try object(await coreRead("source.switch.transaction.query", [
                "operationId": params["operationId"] ?? record.id, "expected": params
            ]))
            guard let receipt = query["transaction"] as? [String: Any],
                  receipt["operationId"] as? String == params["operationId"] as? String,
                  (receipt["sequence"] as? NSNumber) == (params["sequence"] as? NSNumber),
                  let commit = receipt["originalCommit"] as? [String: Any],
                  commit["transactionId"] as? String == params["operationId"] as? String,
                  commit["phase"] as? String == "pending" else { return nil }
            return try JSONSerialization.data(withJSONObject: commit)
        }
        if ["source.switch.finalize", "source.switch.rollback"].contains(record.method) {
            guard let transactionID = params["transactionId"] as? String,
                  let operationID = params["operationId"] as? String,
                  let sequence = params["sequence"] as? NSNumber else { return nil }
            let query = try object(await coreRead("source.switch.transaction.query", [
                "operationId": transactionID, "expectedStage": ["method": record.method, "params": params]
            ]))
            guard let transaction = query["transaction"] as? [String: Any],
                  transaction["operationId"] as? String == transactionID,
                  let receipt = transaction["stage"] as? [String: Any],
                  receipt["operationId"] as? String == operationID,
                  receipt["sequence"] as? NSNumber == sequence,
                  receipt["method"] as? String == record.method else { return nil }
            if let failure = receipt["error"] as? [String: Any] {
                guard receipt["result"] == nil, let code = failure["code"] as? String,
                      let message = failure["message"] as? String, let retryable = failure["retryable"] as? Bool else {
                    throw ReaderLibraryError.invalidResponse("source switch original stage error")
                }
                throw ReaderOriginalCommandRejection(error: .core(code: code, message: message, retryable: retryable,
                    reason: (failure["details"] as? [String: Any])?["reason"] as? String))
            }
            guard let result = receipt["result"] as? [String: Any], result["transactionId"] as? String == transactionID else { return nil }
            return try JSONSerialization.data(withJSONObject: result)
        }
        if record.method == "reading.progress.update", let transactionID = params["transactionId"] as? String {
            let query = try object(await coreRead("source.switch.transaction.query", [
                "operationId": transactionID, "expectedCanonical": params
            ]))
            guard let transaction = query["transaction"] as? [String: Any], transaction["operationId"] as? String == transactionID,
                  let receipt = transaction["canonicalProgress"] as? [String: Any],
                  receipt["transactionId"] as? String == transactionID, receipt["sourceSwitchFinalized"] as? Bool == true,
                  receipt["sourceId"] as? String == params["sourceId"] as? String,
                  receipt["bookId"] as? String == params["bookId"] as? String else { return nil }
            return try JSONSerialization.data(withJSONObject: receipt)
        }
        if ["bookshelf.management.mutation.apply", "rules.mutation.apply"].contains(record.method) {
            let queryMethod = record.method == "rules.mutation.apply" ? "rules.mutation.query" : "bookshelf.management.mutation.query"
            let query = try object(await coreRead(queryMethod, ["operationId": params["operationId"] ?? record.id, "expected": params]))
            guard let receipt = query["receipt"] as? [String: Any],
                  let binding = receipt["binding"] as? [String: Any], binding["operationId"] as? String == params["operationId"] as? String,
                  (binding["sequence"] as? NSNumber) == (params["sequence"] as? NSNumber) else { return nil }
            return try JSONSerialization.data(withJSONObject: receipt)
        }
        if ["bookmark.create", "bookmark.delete"].contains(record.method), params["operationId"] != nil {
            let action = record.method == "bookmark.create" ? "create" : "delete"
            let query = try object(await coreRead("bookmark.operation.query", ["operationId": params["operationId"] ?? record.id, "expected": ["action": action, "params": params]]))
            guard let receipt = query["receipt"] as? [String: Any],
                  let binding = receipt["binding"] as? [String: Any], binding["operationId"] as? String == params["operationId"] as? String,
                  (binding["sequence"] as? NSNumber) == (params["sequence"] as? NSNumber),
                  let outcome = receipt["outcome"] as? [String: Any], outcome["action"] as? String == action,
                  let result = outcome["result"] as? [String: Any] else { return nil }
            return try JSONSerialization.data(withJSONObject: result)
        }
        if record.method == "bookmark.operation.settle" {
            let query = try object(await coreRead("bookmark.operation.query", ["operationId": params["operationId"] ?? record.id]))
            guard let receipt = query["receipt"] as? [String: Any], receipt["phase"] as? String == "settled",
                  let binding = receipt["binding"] as? [String: Any],
                  try JSONSerialization.data(withJSONObject: binding, options: [.sortedKeys]) == record.parameters else { return nil }
            return try JSONSerialization.data(withJSONObject: receipt)
        }
        return nil
    }

    func hasPendingAssetRemoval() throws -> Bool {
        try commandRecords().contains { record in
            guard !record.completed, record.method == "bookshelf.management.mutation.apply",
                  let parameters = try? object(record.parameters),
                  let mutation = parameters["mutation"] as? [String: Any],
                  let method = mutation["method"] as? String else { return false }
            return method == "bookshelf.remove" || method == "bookshelf.removeBatch"
        }
    }

    private func commandDirectory() throws -> URL {
        let directory = operationsURL.appendingPathComponent("commands", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
    private func commandURL(_ id: String) throws -> URL {
        let hash = SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
        return try commandDirectory().appendingPathComponent(hash + ".json")
    }
    private func commandRecord(_ id: String) throws -> ReaderHostCommand? {
        let url = try commandURL(id)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let record = try JSONDecoder().decode(ReaderHostCommand.self, from: Data(contentsOf: url))
        guard record.id == id else { throw ReaderLibraryError.invalidResponse("Host command identity") }
        return record
    }
    private func commandRecords() throws -> [ReaderHostCommand] {
        try FileManager.default.contentsOfDirectory(at: commandDirectory(), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.map { try JSONDecoder().decode(ReaderHostCommand.self, from: Data(contentsOf: $0)) }
    }
    private func storeCommand(_ record: ReaderHostCommand) throws {
        try JSONEncoder().encode(record).write(to: commandURL(record.id), options: .atomic)
    }
    private func removeCommand(_ id: String) throws { try FileManager.default.removeItem(at: commandURL(id)) }
}
