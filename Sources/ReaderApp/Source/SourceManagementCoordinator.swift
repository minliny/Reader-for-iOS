import Foundation
import ReaderCoreBridge
import ReaderHost

struct SourceImportPreview: Sendable {
    let params: M2SourceImportParams
    let existing: M2SourceListEntry?
}

struct GroupedSourceImportPreview: Sendable {
    let revision: Int64
    let candidates: [M2SourceImportParams]
    let existing: Set<String>
}

@MainActor
final class SourceManagementCoordinator {
    enum Failure: Error {
        case invalidDraft
        case invalidSubscription
        case importPreviewChanged
        case operationInFlight
        case conditionalEditUnavailable
        case loginUnavailable
        case loginHostUnavailable
        case originalUnresolved(M2RulesMutationApplyParams, any Error)
        case loginCleanup(host: (any Error)?, report: (any Error)?)
    }

    let runtime: CoreRuntimeActor
    let network: NetworkAndWebHost?
    private var mutating = false
    private(set) var pendingMutation: M2RulesMutationApplyParams?

    init(runtime: CoreRuntimeActor, network: NetworkAndWebHost? = nil) {
        self.runtime = runtime
        self.network = network
    }

    func list(_ params: M2SourceListParams = .init()) async throws -> M2SourceListData {
        try await runtime.request(ReaderM2.sourceList, params).value
    }

    func groups() async throws -> M2SourceGroupCatalogData {
        try await runtime.request(ReaderM2.sourceGroupCatalog, .init()).value
    }

    func filter(groupId: String, enabledOnly: Bool = false) async throws -> [M2SourceListEntry] {
        let memberships = try await groups().memberships
        let ids = Set(memberships.filter { $0.groupId == groupId }.map(\.sourceId))
        return try await list(.init(enabledOnly: enabledOnly)).sources.filter { ids.contains($0.sourceId) }
    }

    func previewImport(_ params: M2SourceImportParams) async throws -> SourceImportPreview {
        let admitted = try importCandidate(params)
        return .init(params: admitted, existing: try await list(.init(sourceId: admitted.sourceId)).sources.first)
    }

    func confirmImport(_ preview: SourceImportPreview) async throws -> M2RulesMutationReceipt {
        guard preview.existing == nil, preview.params.expectedVersion == nil else {
            throw Failure.importPreviewChanged
        }
        return try await apply(.sourceImport(.init(params: preview.params))) {
            guard try await self.list(.init(sourceId: preview.params.sourceId)).sources.isEmpty
            else { throw Failure.importPreviewChanged }
        }
    }

    /// Step one decodes a source document and asks Core for the current group revision.
    func previewGroupedImport(_ document: Data) async throws -> GroupedSourceImportPreview {
        let parsed = try JSONDecoder().decode(ReaderM1JSONValue.self, from: document)
        let items: [ReaderM1JSONValue]
        switch parsed {
        case .array(let entries): items = entries
        case .object: items = [parsed]
        default: throw Failure.invalidDraft
        }
        guard (1...10_000).contains(items.count) else { throw Failure.invalidDraft }
        let candidates = try items.map { value in
            guard case .object(let source) = value else { throw Failure.invalidDraft }
            return try importCandidate(.init(bookSource: source))
        }
        let existing = Set(try await list().sources.map(\.sourceId))
        return .init(revision: try await groups().revision, candidates: candidates, existing: existing)
    }

    /// Steps two and three consume the explicit selection and grouping strategy.
    /// Core verifies the revision and applies the selected items in the original operation.
    func confirmGroupedImport(_ preview: GroupedSourceImportPreview, selected: Set<String>,
                              strategy: M2SourceGroupedImportParamsStrategy,
                              targetGroupId: String? = nil, targetGroupName: String? = nil) async throws
        -> M2RulesMutationReceipt {
        let items = preview.candidates.filter { $0.sourceId.map(selected.contains) == true }
        guard !items.isEmpty, items.count == selected.count else {
            throw Failure.invalidDraft
        }
        guard selected.isDisjoint(with: preview.existing) else { throw Failure.conditionalEditUnavailable }
        return try await apply(.sourceImportGrouped(.init(params: .init(
            expectedRevision: preview.revision, strategy: strategy, targetGroupId: targetGroupId,
            targetGroupName: targetGroupName, items: items
        )))) {
            let current = Set(try await self.list().sources.map(\.sourceId))
            guard selected.isDisjoint(with: current) else { throw Failure.importPreviewChanged }
        }
    }

    private func importCandidate(_ params: M2SourceImportParams) throws -> M2SourceImportParams {
        let name = params.name ?? string(params.bookSource?["bookSourceName"])
        let rawURL = params.baseUrl ?? string(params.bookSource?["bookSourceUrl"])
        let id = params.sourceId ?? rawURL
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let id, !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Failure.invalidDraft
        }
        return .init(sourceId: id, name: params.name, baseUrl: params.baseUrl, rules: params.rules,
                     bookSource: params.bookSource, useSourceReplacement: params.useSourceReplacement,
                     expectedVersion: params.expectedVersion)
    }

    func saveEdit(_ params: M2SourceImportParams, expectedVersion: String) async throws -> M2RulesMutationReceipt {
        guard let sourceId = params.sourceId, !sourceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              expectedVersion.wholeMatch(of: /[a-f0-9]{64}/) != nil,
              params.expectedVersion == nil || params.expectedVersion == expectedVersion else {
            throw Failure.invalidDraft
        }
        let info = try await runtime.request(ReaderM1.coreInfo, .init()).value
        guard info.capabilities.contains("source.import.conditional.v1") else { throw Failure.conditionalEditUnavailable }
        let original = M2SourceImportParams(sourceId: sourceId, name: params.name,
            baseUrl: params.baseUrl, rules: params.rules, bookSource: params.bookSource,
            useSourceReplacement: params.useSourceReplacement, expectedVersion: expectedVersion)
        return try await apply(.sourceImport(.init(params: original)))
    }

    func updateEnabled(_ params: M2SourceUpdateParams) async throws -> M2RulesMutationReceipt {
        let receipt = try await apply(.sourceUpdate(.init(params: params)))
        if case .sourceUpdate(let result) = receipt, !result.data.source.enabled {
            let id = result.data.source.sourceId
            network?.revokeLogin(sourceId: id)
            if let loginURL = string(result.data.source.bookSource?["loginUrl"]), !loginURL.isEmpty,
               let base = URL(string: result.data.source.baseUrl) {
                _ = try await clearLogin(sourceId: id, url: base)
            }
        }
        return receipt
    }

    func updateEnabled(sourceIds: [String], enabled: Bool) async throws -> [M2RulesMutationReceipt] {
        var receipts: [M2RulesMutationReceipt] = []
        for id in sourceIds {
            receipts.append(try await updateEnabled(.init(sourceId: id, enabled: enabled)))
        }
        return receipts
    }

    func mutateGroup(_ params: M2SourceGroupMutateParams) async throws -> M2RulesMutationReceipt {
        try await apply(.sourceGroupMutate(.init(params: params)))
    }

    func delete(_ params: M2SourceDeleteParams) async throws -> M2RulesMutationReceipt {
        let receipt = try await apply(.sourceDelete(.init(params: params)))
        if case .sourceDelete = receipt {
            for id in params.sourceIds { network?.revokeLogin(sourceId: id) }
        }
        return receipt
    }

    func check(_ params: M2SourceCheckRunParams) async throws -> M2SourceCheckResultData {
        try await runtime.request(ReaderM2.sourceCheckRun, params).value
    }

    func checkLegacy(_ params: M2SourceCheckParams) async throws -> M2SourceCheckResultData {
        try await runtime.request(ReaderM2.sourceCheck, params).value
    }

    func checkDraft(_ params: M2SourceCheckEphemeralRunParams) async throws -> M2SourceCheckResultData {
        try await runtime.request(ReaderM2.sourceCheckEphemeralRun, params).value
    }

    func reports(for sourceId: String) async throws -> [M2SourceCheckHistoryEntry] {
        try await list(.init(includeCheckReports: true, checkReportVersion: .v2, sourceId: sourceId))
            .sources.first?.checkReports ?? []
    }

    func beginLogin(sourceId: String, timeout: Duration = .seconds(60)) async throws -> SourceLoginSession {
        guard let network else { throw Failure.loginHostUnavailable }
        let source = try await list(.init(sourceId: sourceId)).sources.first
        guard let source, source.sourceId == sourceId, source.enabled,
              let rawLogin = string(source.bookSource?["loginUrl"]), !rawLogin.isEmpty,
              let base = URL(string: source.baseUrl),
              let url = URL(string: rawLogin, relativeTo: base)?.absoluteURL,
              url.host != nil, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            throw Failure.loginUnavailable
        }
        return try await network.beginLogin(sourceId: sourceId, url: url, timeout: timeout)
    }

    func clearLogin(sourceId: String, url: URL) async throws -> M2SourceCheckReportClearData {
        var hostFailure: (any Error)?
        do {
            guard let network else { throw Failure.loginHostUnavailable }
            try await network.clearLogin(sourceId: sourceId, baseURL: url)
        } catch { hostFailure = error }

        let report: M2SourceCheckReportClearData
        do {
            report = try await runtime.request(ReaderM2.sourceCheckReportClear, .init(sourceIds: [sourceId])).value
            guard report.sourceIds == [sourceId] else { throw CoreBridgeFailure.endpointMismatch }
        } catch {
            throw Failure.loginCleanup(host: hostFailure, report: error)
        }
        if let hostFailure { throw Failure.loginCleanup(host: hostFailure, report: nil) }
        return report
    }

    func subscriptions() async throws -> M2RuleSubListData {
        try await runtime.request(ReaderM2.ruleSubList, .init()).value
    }

    func subscription(_ params: M2RuleSubKeyParams) async throws -> M2RuleSubGetData {
        try await runtime.request(ReaderM2.ruleSubGet, params).value
    }

    func putSubscription(_ params: M2RuleSubPutParams) async throws -> M2RulesMutationReceipt {
        try await apply(.ruleSubPut(.init(params: params)))
    }

    func deleteSubscription(_ params: M2RuleSubKeyParams) async throws -> M2RulesMutationReceipt {
        try await apply(.ruleSubDelete(.init(params: params)))
    }

    func previewSubscription(_ params: M2RuleSubUpdatePreviewParams) async throws -> M2RuleSubUpdatePreviewData {
        try await runtime.request(ReaderM2.ruleSubUpdatePreviewV1, params).value
    }

    func fetchSubscriptionPreview(_ sub: M2RuleSubData) async throws -> M2RuleSubUpdatePreviewData {
        guard sub.type == 3 else { throw Failure.invalidSubscription }
        guard let network else { throw Failure.loginHostUnavailable }
        let head = try await runtime.request(ReaderM2.rulesMutationQuery, .init()).value.head
        let response = try await network.fetch(.init(timeoutMs: 30_000, url: sub.url))
        let expectation = M2RuleSubUpdatePreviewExpected(
            subscription: .init(id: sub.id, name: sub.name, url: sub.url, type: sub.type,
                                customOrder: sub.customOrder, autoUpdate: sub.autoUpdate, update: sub.update),
            rulesHead: head.map { .init(operationId: $0.operationId, sequence: $0.sequence,
                                       payloadFingerprint: $0.payloadFingerprint) }
        )
        return try await previewSubscription(.init(subscriptionId: sub.id, remoteJson: response.body,
                                                  expected: expectation))
    }

    func confirmSubscription(_ preview: M2RuleSubUpdatePreviewData, sourceIds: [String]) async throws
        -> M2RulesMutationReceipt {
        let selectable = Set(preview.changes.filter {
            $0.kind == .added || $0.kind == .update
        }.map(\.sourceId))
        guard !sourceIds.isEmpty, Set(sourceIds).count == sourceIds.count,
              Set(sourceIds).isSubset(of: selectable) else { throw Failure.importPreviewChanged }
        return try await apply(.ruleSubUpdateApplyV1(.init(params: .init(
            planId: preview.planId, sourceIds: sourceIds
        ))))
    }

    func query(_ original: M2RulesMutationApplyParams) async throws -> M2RulesMutationQueryData {
        try await runtime.request(ReaderM2.rulesMutationQuery,
                                  .init(operationId: original.operationId, expected: original)).value
    }

    func verifyPending() async throws -> M2RulesMutationReceipt? {
        guard !mutating else { throw Failure.operationInFlight }
        guard let original = pendingMutation else { return nil }
        let receipt = try await query(original).receipt
        if receipt != nil { pendingMutation = nil }
        return receipt
    }

    private func apply(_ mutation: M2RulesMutation,
                       admission: () async throws -> Void = {}) async throws -> M2RulesMutationReceipt {
        guard !mutating, pendingMutation == nil else { throw Failure.operationInFlight }
        mutating = true
        defer { mutating = false }
        let head = try await runtime.request(ReaderM2.rulesMutationQuery, .init()).value.head
        try await admission()
        let sequence = (head?.sequence ?? 0) + 1
        let original = M2RulesMutationApplyParams(operationId: "\(UUID().uuidString.lowercased())/\(sequence)",
                                                 sequence: sequence, mutation: mutation)
        pendingMutation = original
        do {
            let receipt = try await runtime.request(ReaderM2.rulesMutationApply, original).value
            pendingMutation = nil
            return receipt
        } catch {
            if let observed = try? await query(original), let receipt = observed.receipt {
                pendingMutation = nil
                return receipt
            }
            throw Failure.originalUnresolved(original, error)
        }
    }

    private func string(_ value: ReaderM1JSONValue?) -> String? {
        guard case .string(let string) = value else { return nil }
        return string
    }
}
