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
/// A Host read observed a changed subscription/lineage during its check or write preparation.
/// This is not a Core rejection or a receipt for any accepted mutation.
public struct ReaderSubscriptionCheckChanged: Error, Sendable, LocalizedError {
    public var errorDescription: String? { "订阅配置已变化，请重新检查订阅" }
}

/// The original editor row is distinct from the user's editable values. A
/// missing baseline is legacy/unknown; `.absent` explicitly owns a new row.
public enum ReaderSubscriptionBaseline: Codable, Hashable, Sendable {
    case absent
    case existing(ReaderSourceSubscription)
}

extension ReaderSourceSubscription {
    func isDueForAutomaticUpdate(at now: Int64) -> Bool {
        guard autoUpdate else { return false }
        let (threshold, underflow) = now.subtractingReportingOverflow(24 * 60 * 60 * 1000)
        // Below Int64.min there is no representable timestamp old enough.
        // Preserve the imported value; clamping would admit Int64.min early.
        return !underflow && update <= threshold
    }

    func hasSameConfiguration(as other: ReaderSourceSubscription) -> Bool {
        id == other.id && name == other.name && url == other.url && type == other.type
            && customOrder == other.customOrder && autoUpdate == other.autoUpdate
    }
}

public protocol ReaderRuleSubscriptionServing: ReaderOnlineServing {
    func ruleSubscriptions() async throws -> [ReaderSourceSubscription]
    func saveRuleSubscription(_ subscription: ReaderSourceSubscription, operationID: String) async throws -> ReaderSourceSubscription
    func saveRuleSubscription(_ subscription: ReaderSourceSubscription, baseline: ReaderSubscriptionBaseline?, operationID: String) async throws -> ReaderSourceSubscription
    func deleteRuleSubscription(_ subscription: ReaderSourceSubscription, operationID: String) async throws
    func checkRuleSubscription(_ subscription: ReaderSourceSubscription) async throws -> ReaderSubscriptionPlan
    func applyRuleSubscription(_ plan: ReaderSubscriptionPlan, sourceIDs: [String], operationID: String) async throws -> ReaderSubscriptionApplied
    func checkDueRuleSubscriptions() async -> [String]
    func resumeRuleSubscriptionUpdates() async throws -> [ReaderSubscriptionApplied]
}
public extension ReaderRuleSubscriptionServing {
    // Older adapters retain source compatibility, but cannot silently downgrade
    // a guarded editor save to an unconditional upsert.
    func saveRuleSubscription(_ subscription: ReaderSourceSubscription, baseline: ReaderSubscriptionBaseline?, operationID: String) async throws -> ReaderSourceSubscription {
        throw ReaderSubscriptionCheckChanged()
    }
}

struct ReaderPreparedSubscriptionSave: Sendable {
    let subscription: ReaderSourceSubscription
    let nextSequence: UInt64
}

extension ReaderLibraryService: ReaderRuleSubscriptionServing {
    public func ruleSubscriptions() async throws -> [ReaderSourceSubscription] {
        struct Result: Decodable { let subs: [ReaderSourceSubscription] }
        return try decode(Result.self, await coreRead("rule-sub.list", [:])).subs
    }
    public func saveRuleSubscription(_ subscription: ReaderSourceSubscription, operationID: String) async throws -> ReaderSourceSubscription {
        try await finishRuleSubscriptionSave(subscription, operationID: operationID)
    }
    public func saveRuleSubscription(_ subscription: ReaderSourceSubscription, baseline: ReaderSubscriptionBaseline?, operationID: String) async throws -> ReaderSourceSubscription {
        // Once submitted, both Core's wrapper and the derived update timestamp
        // belong to that original journal. Even a legacy Host intent may only
        // consume its existing record; it must never rebase and submit anew.
        if let outer = try existingCoreParameters(operationID: operationID, method: "rules.mutation.apply") {
            guard let mutation = outer["mutation"] as? [String: Any],
                  mutation["method"] as? String == "rule-sub.put",
                  let params = mutation["params"] as? [String: Any] else {
                throw ReaderLibraryError.invalidResponse("subscription save identity")
            }
            let frozen = try decode(ReaderSourceSubscription.self, JSONSerialization.data(withJSONObject: params))
            guard frozen.hasSameConfiguration(as: subscription) else { throw ReaderLibraryError.invalidResponse("subscription save identity") }
            return try await finishGuardedRuleSubscriptionSave(frozen, operationID: operationID)
        }
        let prepared = try await prepareRuleSubscriptionSave(subscription, baseline: baseline)
        return try await finishGuardedRuleSubscriptionSave(prepared.subscription, operationID: operationID, nextSequence: prepared.nextSequence)
    }
    private func finishGuardedRuleSubscriptionSave(_ subscription: ReaderSourceSubscription, operationID: String, nextSequence: UInt64? = nil) async throws -> ReaderSourceSubscription {
        do {
            return try await finishRuleSubscriptionSave(subscription, operationID: operationID, nextSequence: nextSequence)
        } catch ReaderLibraryError.core(_, _, _, let reason) where reason == "rules_mutation_rejected" {
            // Core rejected the captured lineage before changing the row. The
            // editor keeps its input and uses its existing conflict owner.
            throw ReaderSubscriptionCheckChanged()
        }
    }
    func prepareRuleSubscriptionSave(_ subscription: ReaderSourceSubscription, baseline: ReaderSubscriptionBaseline?) async throws -> ReaderPreparedSubscriptionSave {
        struct Head: Decodable, Equatable {
            let operationId: String
            let sequence: UInt64
            let payloadFingerprint: String
        }
        struct Query: Decodable { let head: Head? }
        guard let baseline else { throw ReaderSubscriptionCheckChanged() }
        let before = try decode(Query.self, await coreRead("rules.mutation.query", [:])).head
        let current = try await ruleSubscriptions().first { $0.id == subscription.id }
        switch baseline {
        case .absent:
            guard current == nil else { throw ReaderSubscriptionCheckChanged() }
        case .existing(let original):
            guard original.id == subscription.id, let current,
                  current.hasSameConfiguration(as: original), current.update >= original.update else { throw ReaderSubscriptionCheckChanged() }
        }
        let after = try decode(Query.self, await coreRead("rules.mutation.query", [:])).head
        guard before == after else { throw ReaderSubscriptionCheckChanged() }
        let sequence = before?.sequence ?? 0
        guard sequence < 9_007_199_254_740_991 else { throw ReaderLibraryError.invalidResponse("rules sequence exhausted") }
        let frozen = ReaderSourceSubscription(id: subscription.id, name: subscription.name, url: subscription.url,
            type: subscription.type, customOrder: subscription.customOrder, autoUpdate: subscription.autoUpdate,
            update: current?.update ?? 0)
        return .init(subscription: frozen, nextSequence: sequence + 1)
    }
    private func finishRuleSubscriptionSave(_ subscription: ReaderSourceSubscription, operationID: String, nextSequence: UInt64? = nil) async throws -> ReaderSourceSubscription {
        struct Result: Decodable { let sub: ReaderSourceSubscription }
        let params = try object(JSONEncoder().encode(subscription))
        let saved = try decode(Result.self, await rulesMutation("rule-sub.put", params, operationID: operationID, nextSequence: nextSequence)).sub
        guard saved.id == subscription.id, saved.url == subscription.url else { throw ReaderLibraryError.operationPending(operationID) }
        try await finishCoreOperation(operationID)
        return saved
    }
    public func deleteRuleSubscription(_ subscription: ReaderSourceSubscription, operationID: String) async throws {
        // An accepted delete owns its original wrapper even when the row is now
        // absent. Recovery must consume that journal before any fresh row read.
        if try existingCoreParameters(operationID: operationID, method: "rules.mutation.apply") != nil {
            try await finishGuardedRuleSubscriptionDelete(subscription, operationID: operationID)
            return
        }
        let nextSequence = try await prepareRuleSubscriptionDelete(subscription)
        try await finishGuardedRuleSubscriptionDelete(subscription, operationID: operationID, nextSequence: nextSequence)
    }
    func prepareRuleSubscriptionDelete(_ subscription: ReaderSourceSubscription) async throws -> UInt64 {
        struct Head: Decodable, Equatable {
            let operationId: String
            let sequence: UInt64
            let payloadFingerprint: String
        }
        struct Query: Decodable { let head: Head? }
        let before = try decode(Query.self, await coreRead("rules.mutation.query", [:])).head
        guard let current = try await ruleSubscriptions().first(where: { $0.id == subscription.id }),
              current.hasSameConfiguration(as: subscription) else { throw ReaderSubscriptionCheckChanged() }
        // The apply clock is not a row version. Removing the same configuration
        // may follow an acknowledged update; an intervening write cannot rebase.
        let after = try decode(Query.self, await coreRead("rules.mutation.query", [:])).head
        guard before == after else { throw ReaderSubscriptionCheckChanged() }
        let sequence = before?.sequence ?? 0
        guard sequence < 9_007_199_254_740_991 else { throw ReaderLibraryError.invalidResponse("rules sequence exhausted") }
        return sequence + 1
    }
    private func finishGuardedRuleSubscriptionDelete(_ subscription: ReaderSourceSubscription, operationID: String, nextSequence: UInt64? = nil) async throws {
        do {
            _ = try await rulesMutation("rule-sub.delete", ["id": subscription.id], operationID: operationID, nextSequence: nextSequence)
            try await finishCoreOperation(operationID)
        } catch ReaderLibraryError.core(_, _, _, let reason) where reason == "rules_mutation_rejected" {
            throw ReaderSubscriptionCheckChanged()
        }
    }
    public func checkRuleSubscription(_ subscription: ReaderSourceSubscription) async throws -> ReaderSubscriptionPlan {
        try await checkRuleSubscription(subscription, fetch: { [self] url in try await onlineFetch(url) })
    }
    /// The fetch belongs to the caller's complete subscription snapshot. Core's
    /// preview snapshots the row only after HTTP returns, so its later apply CAS
    /// alone cannot identify a provider/configuration change during that fetch.
    func checkRuleSubscription(_ subscription: ReaderSourceSubscription,
                               fetch: @Sendable (URL) async throws -> Data) async throws -> ReaderSubscriptionPlan {
        struct Head: Codable, Equatable {
            let operationId: String
            let sequence: UInt64
            let payloadFingerprint: String
        }
        struct Query: Decodable { let head: Head? }
        let changed = ReaderSubscriptionCheckChanged()
        let before = try decode(Query.self, await coreRead("rules.mutation.query", [:])).head
        guard try await ruleSubscriptions().first(where: { $0.id == subscription.id }) == subscription else { throw changed }
        guard let url = URL(string: subscription.url) else { throw ReaderLibraryError.invalidResponse("subscription URL") }
        try Task.checkCancellation()
        let remote = try await fetch(url)
        try Task.checkCancellation()
        // Preview replaces Core's single plan slot for this subscription. Do
        // not let a stale fetch evict a newer configuration's current preview.
        guard try await ruleSubscriptions().first(where: { $0.id == subscription.id }) == subscription else { throw changed }
        let fetchedHead = try decode(Query.self, await coreRead("rules.mutation.query", [:])).head
        guard before == fetchedHead else { throw changed }
        guard let json = String(data: remote, encoding: .utf8) else { throw ReaderLibraryError.invalidResponse("subscription JSON encoding") }
        let rulesHead: Any
        if let before { rulesHead = try object(JSONEncoder().encode(before)) }
        else { rulesHead = NSNull() }
        // The final check and preview publication must share Core's guard:
        // another rules write can arrive after our last awaited head read.
        let expected: [String: Any] = ["subscription": try object(JSONEncoder().encode(subscription)),
            "rulesHead": rulesHead]
        let plan: ReaderSubscriptionPlan
        do {
            plan = try decode(ReaderSubscriptionPlan.self, await coreRead("rule-sub.update.preview.v1", [
                "subscriptionId": subscription.id, "remoteJson": json, "expected": expected
            ]))
        } catch ReaderLibraryError.core(_, _, _, let reason) where reason == "SUBSCRIPTION_CHECK_CHANGED" {
            throw changed
        }
        guard plan.subscriptionId == subscription.id else { throw ReaderLibraryError.invalidResponse("subscription plan identity") }
        guard try await ruleSubscriptions().first(where: { $0.id == subscription.id }) == subscription else { throw changed }
        // Every production rules mutation advances this Core-owned head in its
        // data transaction. Comparing it also catches A -> B -> A during the
        // fetch/preview window; comparing the final DTO alone would miss that.
        let after = try decode(Query.self, await coreRead("rules.mutation.query", [:])).head
        guard before == after else { throw changed }
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
            let due = try await ruleSubscriptions().filter { $0.isDueForAutomaticUpdate(at: now) }
            for subscription in due {
                do {
                    try Task.checkCancellation()
                    let plan = try await checkRuleSubscription(subscription)
                    try Task.checkCancellation()
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
