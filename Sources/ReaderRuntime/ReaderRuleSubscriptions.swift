import Foundation

public struct ReaderSubscriptionChange: Codable, Hashable, Sendable, Identifiable {
    public let sourceId: String
    public let name: String
    public let kind: String
    public var id: String { sourceId }
    public var safeToApply: Bool { kind == "added" || kind == "update" }
}
public struct ReaderSubscriptionPlan: Codable, Hashable, Sendable {
    public let planId: String
    public let subscriptionId: Int64
    public let remoteDigest: String
    public let expiresAt: Int64
    public let changes: [ReaderSubscriptionChange]
}
public struct ReaderSubscriptionApplied: Codable, Hashable, Sendable {
    public let subscriptionId: Int64
    public let remoteDigest: String
    public let appliedSourceIds: [String]
    public let skippedSourceIds: [String]
    public let updatedAt: Int64
}
/// A preview may be retired only after its own frozen apply has an exact
/// completed Rejected receipt. Unknown results retain their original owner.
public struct ReaderSubscriptionPreviewRejected: Error, Sendable, LocalizedError {
    public let operationID: String
    public let planID: String
    public let originalError: ReaderLibraryError
    public var errorDescription: String? { originalError.errorDescription }
}

public protocol ReaderRuleSubscriptionServing: ReaderOnlineServing {
    func ruleSubscriptions() async throws -> [ReaderSourceSubscription]
    func saveRuleSubscription(_ subscription: ReaderSourceSubscription, operationID: String) async throws -> ReaderSourceSubscription
    func deleteRuleSubscription(_ subscription: ReaderSourceSubscription, operationID: String) async throws
    func checkRuleSubscription(_ subscription: ReaderSourceSubscription) async throws -> ReaderSubscriptionPlan
    func applyRuleSubscription(_ plan: ReaderSubscriptionPlan, sourceIDs: [String], operationID: String) async throws -> ReaderSubscriptionApplied
    func checkDueRuleSubscriptions() async -> [String]
    func resumeRuleSubscriptionUpdates() async throws -> [ReaderSubscriptionApplied]
}
extension ReaderLibraryService: ReaderRuleSubscriptionServing {
    public func ruleSubscriptions() async throws -> [ReaderSourceSubscription] {
        struct Result: Decodable { let subs: [ReaderSourceSubscription] }
        return try decode(Result.self, await coreRead("rule-sub.list", [:])).subs
    }
    public func saveRuleSubscription(_ subscription: ReaderSourceSubscription, operationID: String) async throws -> ReaderSourceSubscription {
        struct Result: Decodable { let sub: ReaderSourceSubscription }
        let params = try object(JSONEncoder().encode(subscription))
        let saved = try decode(Result.self, await rulesMutation("rule-sub.put", params, operationID: operationID)).sub
        guard saved.id == subscription.id, saved.url == subscription.url else { throw ReaderLibraryError.operationPending(operationID) }
        try await finishCoreOperation(operationID)
        return saved
    }
    public func deleteRuleSubscription(_ subscription: ReaderSourceSubscription, operationID: String) async throws {
        _ = try await rulesMutation("rule-sub.delete", ["id": subscription.id], operationID: operationID)
        try await finishCoreOperation(operationID)
    }
    public func checkRuleSubscription(_ subscription: ReaderSourceSubscription) async throws -> ReaderSubscriptionPlan {
        guard let url = URL(string: subscription.url) else { throw ReaderLibraryError.invalidResponse("subscription URL") }
        let remote = try await onlineFetch(url)
        guard let json = String(data: remote, encoding: .utf8) else { throw ReaderLibraryError.invalidResponse("subscription JSON encoding") }
        let plan = try decode(ReaderSubscriptionPlan.self, await coreRead("rule-sub.update.preview.v1", ["subscriptionId": subscription.id, "remoteJson": json]))
        guard plan.subscriptionId == subscription.id else { throw ReaderLibraryError.invalidResponse("subscription plan identity") }
        return plan
    }
    public func applyRuleSubscription(_ plan: ReaderSubscriptionPlan, sourceIDs: [String], operationID: String) async throws -> ReaderSubscriptionApplied {
        let safe = Set(plan.changes.filter(\.safeToApply).map(\.sourceId))
        guard Set(sourceIDs).isSubset(of: safe), Set(sourceIDs).count == sourceIDs.count else { throw ReaderLibraryError.invalidResponse("unsafe subscription selection") }
        do {
            let result = try decode(ReaderSubscriptionApplied.self, await rulesMutation("rule-sub.update.apply.v1", ["planId": plan.planId, "sourceIds": sourceIDs], operationID: operationID))
            guard result.subscriptionId == plan.subscriptionId, result.remoteDigest == plan.remoteDigest,
                  Set(result.appliedSourceIds).isSubset(of: Set(sourceIDs)) else { throw ReaderLibraryError.operationPending(operationID) }
            try await finishCoreOperation(operationID)
            return result
        } catch {
            if let original = try? confirmedRuleSubscriptionRejection(operationID: operationID,
                planID: plan.planId, sourceIDs: sourceIDs) {
                throw ReaderSubscriptionPreviewRejected(operationID: operationID, planID: plan.planId,
                    originalError: original)
            }
            throw error
        }
    }
    /// Called only in an actual foreground or OS-granted background window.
    /// No keep-alive timer; all safe decisions and local-conflict CAS are Core-owned.
    public func checkDueRuleSubscriptions() async -> [String] {
        var failures: [String] = []
        do {
            _ = try await resumeRuleSubscriptionUpdates()
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let due = try await ruleSubscriptions().filter { $0.autoUpdate && now - $0.update >= 24 * 60 * 60 * 1000 }
            for subscription in due {
                do {
                    try Task.checkCancellation()
                    let plan = try await checkRuleSubscription(subscription)
                    _ = try await applyRuleSubscription(plan, sourceIDs: plan.changes.filter(\.safeToApply).map(\.sourceId), operationID: UUID().uuidString.lowercased())
                    if plan.changes.contains(where: { $0.kind == "conflict" }) { failures.append(subscription.name + "：本机修改已保留，存在待处理差异") }
                } catch is CancellationError { break }
                catch { failures.append(subscription.name + "：" + error.localizedDescription) }
            }
        } catch { failures.append(error.localizedDescription) }
        return failures
    }
    public func resumeRuleSubscriptionUpdates() async throws -> [ReaderSubscriptionApplied] {
        var applied: [ReaderSubscriptionApplied] = []
        for pending in try pendingCoreCommands() where pending.method == "rules.mutation.apply" {
            guard let outer = try existingCoreParameters(operationID: pending.id, method: pending.method),
                  let mutation = outer["mutation"] as? [String: Any],
                  mutation["method"] as? String == "rule-sub.update.apply.v1",
                  let parameters = mutation["params"] as? [String: Any] else { continue }
            let original = try decode(ReaderSubscriptionApplied.self, await rulesMutation("rule-sub.update.apply.v1", parameters, operationID: pending.id))
            try await finishCoreOperation(pending.id)
            applied.append(original)
        }
        return applied
    }
}
