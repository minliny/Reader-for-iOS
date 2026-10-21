import SwiftUI
import Foundation
import Combine

private struct ReaderSubscriptionDraft: Codable, Equatable {
    var isPresent = false
    var id: Int64 = 0
    var name = ""
    var url = ""
    var type: Int32 = 0
    var order = "0"
    var autoUpdate = false
    var update: Int64 = 0

    init() {}
    init(_ subscription: ReaderSourceSubscription) {
        isPresent = true
        id = subscription.id; name = subscription.name; url = subscription.url
        type = subscription.type; order = String(subscription.customOrder)
        autoUpdate = subscription.autoUpdate; update = subscription.update
    }

    func subscription() throws -> ReaderSourceSubscription {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ReaderSubscriptionPanelError.invalidDraft("请填写订阅名称") }
        guard let components = URLComponents(string: address),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty, components.url != nil else {
            throw ReaderSubscriptionPanelError.invalidDraft("请填写完整的 HTTP 或 HTTPS 订阅地址")
        }
        guard let customOrder = Int32(order.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ReaderSubscriptionPanelError.invalidDraft("排序值须为有效整数")
        }
        return ReaderSourceSubscription(id: id, name: name, url: address, type: type,
            customOrder: customOrder, autoUpdate: autoUpdate, update: update)
    }
}

private enum ReaderSubscriptionMutation: Codable {
    case save(ReaderSourceSubscription)
    case delete(ReaderSourceSubscription)
    case apply(ReaderSubscriptionPlan, [String])

    var subscriptionID: Int64 {
        switch self {
        case .save(let value), .delete(let value): return value.id
        case .apply(let plan, _): return plan.subscriptionId
        }
    }
}

private struct ReaderSubscriptionIntent: Codable {
    let operationID: String
    let label: String
    let mutation: ReaderSubscriptionMutation
    var scope: String { "rule-subscriptions/\(mutation.subscriptionID)" }
}

private enum ReaderSubscriptionPanelError: LocalizedError {
    case invalidDraft(String), intentNotSaved
    var errorDescription: String? {
        switch self {
        case .invalidDraft(let message): return message
        case .intentNotSaved: return "原操作记录未能保存，尚未提交订阅变更"
        }
    }
}

/// One source-management host. Read/check callbacks belong to its presentation
/// generation. Accepted writes belong to immutable subscription/plan identities;
/// closing the host cancels reads, never the write or its original operation ID.
@MainActor
private final class ReaderRuleSubscriptionPanelModel: ObservableObject {
    @Published private(set) var subscriptions: [ReaderSourceSubscription] = []
    @Published private(set) var loading = false
    @Published private(set) var listFailure: String?
    @Published private(set) var loaded = false
    @Published private(set) var checkingID: Int64?
    @Published private(set) var checkedID: Int64?
    @Published private(set) var checkFailure: String?
    @Published private(set) var plan: ReaderSubscriptionPlan?
    @Published var selectedSourceIDs = Set<String>()
    @Published private(set) var applied: ReaderSubscriptionApplied?
    @Published private(set) var appliedPlan: ReaderSubscriptionPlan?
    @Published private(set) var pendingIntent: ReaderSubscriptionIntent?
    @Published private(set) var journalFailure: String?
    @Published var editorPresented = false
    @Published var draftFailure: String?
    @Published var draft: ReaderSubscriptionDraft {
        didSet {
            draftFailure = nil
            if !draft.isPresent { defaults.removeObject(forKey: Self.draftKey) }
            else if let data = try? JSONEncoder().encode(draft) { defaults.set(data, forKey: Self.draftKey) }
        }
    }

    let actions = ReaderLibraryActionOwner()
    private let service: any ReaderRuleSubscriptionServing
    private let defaults: UserDefaults
    private static let draftKey = "reader.ruleSubscriptions.draft.v1"
    private static let intentKey = "reader.ruleSubscriptions.intent.v1"
    private var active = false
    private var readGeneration = UUID()
    private var checkGeneration = UUID()
    private var readTask: Task<Void, Never>?
    private var checkTask: Task<Void, Never>?
    private var actionObservation: AnyCancellable?
    private var ownerOperationID: String?

    var canMutate: Bool { !actions.hasPending && !actions.busy && pendingIntent == nil && journalFailure == nil }
    var statusScope: String { actions.scope ?? "rule-subscriptions" }
    var safeChanges: [ReaderSubscriptionChange] { plan?.changes.filter(\.safeToApply) ?? [] }
    var planExpired: Bool { plan.map { $0.expiresAt <= Self.now } ?? false }
    private static var now: Int64 { Int64(Date().timeIntervalSince1970 * 1_000) }

    init(service: any ReaderRuleSubscriptionServing, defaults: UserDefaults = .standard) {
        self.service = service; self.defaults = defaults
        if let data = defaults.data(forKey: Self.draftKey),
           let restored = try? JSONDecoder().decode(ReaderSubscriptionDraft.self, from: data) { draft = restored }
        else { draft = ReaderSubscriptionDraft() }
        readIntent()
        actions.pendingChecker = { [weak self] id in
            guard let self, let features = self.service as? any ReaderLibraryFeatures else { return nil }
            let originalID = self.pendingIntent?.operationID ?? id
            do { return try await features.pendingFeatureOperations().contains { $0.id == originalID } }
            catch { return nil }
        }
        actionObservation = actions.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.ownerDidChange() }
        }
    }

    func activate() {
        active = true
        refresh()
        if let intent = pendingIntent, !actions.hasPending, !actions.busy {
            Task { await resumeAccepted(intent) }
        }
    }

    func retire() {
        active = false
        readGeneration = UUID(); checkGeneration = UUID()
        readTask?.cancel(); checkTask?.cancel()
        loading = false; checkingID = nil
        actions.clearFeedback()
    }

    func refresh() {
        readTask?.cancel()
        let generation = UUID(); readGeneration = generation
        loading = true; listFailure = nil
        readTask = Task {
            do {
                let rows = try await service.ruleSubscriptions()
                guard active, readGeneration == generation, !Task.isCancelled else { return }
                subscriptions = rows.sorted {
                    $0.customOrder == $1.customOrder ? $0.id < $1.id : $0.customOrder < $1.customOrder
                }
                loaded = true; loading = false
            } catch {
                guard active, readGeneration == generation, !Task.isCancelled else { return }
                listFailure = error.localizedDescription; loading = false
            }
        }
    }

    func newOrContinueDraft() {
        guard canMutate else { return }
        if !draft.isPresent {
            var value = ReaderSubscriptionDraft()
            value.isPresent = true
            value.id = Self.now
            while subscriptions.contains(where: { $0.id == value.id }) { value.id += 1 }
            draft = value
        }
        draftFailure = nil; editorPresented = true
    }

    func edit(_ subscription: ReaderSourceSubscription) {
        guard canMutate else { return }
        if !draft.isPresent || draft.id != subscription.id { draft = ReaderSubscriptionDraft(subscription) }
        draftFailure = nil; editorPresented = true
    }

    func discardDraft(_ captured: ReaderSubscriptionDraft) {
        guard canMutate, draft == captured else { return }
        draft = ReaderSubscriptionDraft(); editorPresented = false
    }

    func saveDraft() {
        guard canMutate else { return }
        do { begin("保存订阅", mutation: .save(try draft.subscription())) }
        catch { draftFailure = error.localizedDescription }
    }

    func delete(_ subscription: ReaderSourceSubscription) { begin("删除订阅", mutation: .delete(subscription)) }

    func check(_ subscription: ReaderSourceSubscription) {
        guard canMutate else { return }
        stopCheck()
        let generation = UUID(); checkGeneration = generation
        checkedID = subscription.id; checkingID = subscription.id
        checkFailure = nil; plan = nil; applied = nil; appliedPlan = nil; selectedSourceIDs = []
        checkTask = Task {
            do {
                let value = try await service.checkRuleSubscription(subscription)
                guard active, checkGeneration == generation, !Task.isCancelled else { return }
                plan = value
                selectedSourceIDs = Set(value.changes.filter(\.safeToApply).map(\.sourceId))
                checkingID = nil
            } catch {
                guard active, checkGeneration == generation, !Task.isCancelled else { return }
                checkFailure = error.localizedDescription; checkingID = nil
            }
        }
    }

    func stopCheck() {
        checkGeneration = UUID(); checkTask?.cancel(); checkTask = nil; checkingID = nil
    }

    func applySelection() {
        guard canMutate, let plan else { return }
        guard !planExpired else { checkFailure = "更新计划已过期，请重新检查订阅"; return }
        let selection = plan.changes.filter { $0.safeToApply && selectedSourceIDs.contains($0.sourceId) }.map(\.sourceId)
        guard !selection.isEmpty else { return }
        begin("应用订阅更新", mutation: .apply(plan, selection))
    }

    func rereadIntent() {
        guard !actions.busy, !actions.hasPending else { return }
        readIntent()
        if let intent = pendingIntent { Task { await resumeAccepted(intent) } }
    }

    private func begin(_ label: String, mutation: ReaderSubscriptionMutation) {
        guard canMutate else { return }
        stopCheck()
        Task {
            let succeeded = await actions.perform(label, scope: "rule-subscriptions/\(mutation.subscriptionID)") { [self] id in
                ownerOperationID = id
                let accepted = ReaderSubscriptionIntent(operationID: id, label: label, mutation: mutation)
                try retain(accepted)
                try await execute(accepted)
            }
            settle(succeeded)
        }
    }

    private func resumeAccepted(_ accepted: ReaderSubscriptionIntent) async {
        // The ActionOwner still owns presentation/retry. Its new envelope must
        // never replace the already accepted Runtime operation's original ID.
        let succeeded = await actions.perform(accepted.label, scope: accepted.scope) { [self] _ in
            ownerOperationID = accepted.operationID
            try await execute(accepted)
        }
        settle(succeeded)
    }

    private func settle(_ succeeded: Bool) {
        if !actions.hasPending, !actions.busy, let operationID = ownerOperationID {
            clearRetainedIntent(operationID)
            ownerOperationID = nil
        }
        if succeeded, active { refresh() }
    }

    private func retain(_ accepted: ReaderSubscriptionIntent) throws {
        let data = try JSONEncoder().encode(accepted)
        defaults.set(data, forKey: Self.intentKey)
        guard defaults.data(forKey: Self.intentKey) == data else { throw ReaderSubscriptionPanelError.intentNotSaved }
        pendingIntent = accepted
    }

    private func execute(_ accepted: ReaderSubscriptionIntent) async throws {
        switch accepted.mutation {
        case .save(let subscription):
            let saved = try await service.saveRuleSubscription(subscription, operationID: accepted.operationID)
            if let current = try? draft.subscription(), current == subscription {
                draft = ReaderSubscriptionDraft()
                if active { editorPresented = false }
            }
            if plan?.subscriptionId == saved.id { plan = nil; selectedSourceIDs = [] }
        case .delete(let subscription):
            try await service.deleteRuleSubscription(subscription, operationID: accepted.operationID)
            if checkedID == subscription.id { checkedID = nil; plan = nil; checkFailure = nil; selectedSourceIDs = [] }
            if let current = try? draft.subscription(), current == subscription { draft = ReaderSubscriptionDraft() }
        case .apply(let capturedPlan, let identities):
            let receipt = try await service.applyRuleSubscription(capturedPlan, sourceIDs: identities, operationID: accepted.operationID)
            if active { applied = receipt; appliedPlan = capturedPlan; checkedID = capturedPlan.subscriptionId }
            if plan?.planId == capturedPlan.planId { plan = nil; selectedSourceIDs = [] }
        }
        // Only the typed Runtime ACK clears the accepted write. A list refresh
        // lives outside this action and cannot turn an ACK into another write.
        clearRetainedIntent(accepted.operationID)
    }

    private func ownerDidChange() {
        objectWillChange.send()
        // ReaderOperationStatus invokes the same owner's retry directly. A
        // confirmed rejection on that path also retires the Host intent, while
        // the owner's unknown/pending state must retain it unchanged.
        if !actions.hasPending, !actions.busy, let operationID = ownerOperationID {
            clearRetainedIntent(operationID)
            ownerOperationID = nil
        }
    }

    private func clearRetainedIntent(_ operationID: String) {
        if pendingIntent?.operationID == operationID { pendingIntent = nil }
        guard let data = defaults.data(forKey: Self.intentKey),
              let current = try? JSONDecoder().decode(ReaderSubscriptionIntent.self, from: data),
              current.operationID == operationID else { return }
        defaults.removeObject(forKey: Self.intentKey)
    }

    private func readIntent() {
        guard let data = defaults.data(forKey: Self.intentKey) else { pendingIntent = nil; journalFailure = nil; return }
        do {
            let value = try JSONDecoder().decode(ReaderSubscriptionIntent.self, from: data)
            guard UUID(uuidString: value.operationID) != nil else { throw ReaderSubscriptionPanelError.intentNotSaved }
            pendingIntent = value; journalFailure = nil
        } catch { journalFailure = "原操作记录无法读取，记录已保留；尚未提交新的订阅变更" }
    }
}

struct ReaderRuleSubscriptionPanel: View {
    @StateObject private var state: ReaderRuleSubscriptionPanelModel
    @StateObject private var confirmation = ReaderNativeAlertOwner()
    @StateObject private var editorConfirmation = ReaderNativeAlertOwner()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    private var palette: ReaderPalette { ReaderPalette(scheme) }
    private let kinds = ["added", "update", "unchanged", "localOnly", "conflict", "removedRemote"]

    init(service: any ReaderRuleSubscriptionServing) {
        _state = StateObject(wrappedValue: ReaderRuleSubscriptionPanelModel(service: service))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ReaderIconAction(icon: .close, label: "关闭订阅管理") { dismiss() }
                Text("规则订阅").font(ReaderTypography.font(.controlHeader))
                Spacer(minLength: 8)
                Button(state.draft.isPresent ? "继续草稿" : "添加", action: state.newOrContinueDraft)
                    .frame(minHeight: 44).disabled(!state.canMutate)
                    .accessibilityIdentifier("subscription-add")
            }.padding(.horizontal, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    operationStatus
                    if let failure = state.journalFailure {
                        ReaderPageState(title: "原操作待核对", detail: failure,
                            actionTitle: "重新读取原操作", action: state.rereadIntent)
                    }
                    if state.loading { ReaderPageState(title: "正在读取订阅", loading: true) }
                    if let failure = state.listFailure {
                        ReaderPageState(title: "订阅列表读取失败", detail: failure, actionTitle: "重试", action: state.refresh)
                    } else if state.loaded, state.subscriptions.isEmpty, !state.loading {
                        ReaderPageState(title: "还没有规则订阅", detail: "添加书源包地址后，可手动检查差异并选择安全更新。",
                            actionTitle: "添加订阅", action: state.newOrContinueDraft)
                    }
                    ForEach(state.subscriptions) { subscription in subscriptionCard(subscription) }
                }.padding(20)
            }.accessibilityIdentifier("subscription-scroll")
        }.foregroundStyle(palette.ink).background(palette.paper)
            .onAppear(perform: state.activate).onDisappear(perform: state.retire)
            .readerConfirmation(confirmation)
            .sheet(isPresented: $state.editorPresented) { editor }
    }

    private var operationStatus: some View {
        VStack(spacing: 10) {
            if state.actions.busy { ReaderPageState(title: "正在核对订阅操作", loading: true) }
            ReaderOperationStatus(owner: state.actions, scope: state.statusScope, completed: state.refresh)
        }
    }

    private func subscriptionCard(_ subscription: ReaderSourceSubscription) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(subscription.name.isEmpty ? "未命名订阅" : subscription.name).font(ReaderTypography.font(.controlHeader))
                .accessibilityIdentifier("subscription:\(subscription.id)")
            Text(subscription.url).font(ReaderTypography.font(.caption)).foregroundStyle(palette.muted).textSelection(.enabled)
                .accessibilityIdentifier("subscription-url:\(subscription.id)")
            Text(subscription.autoUpdate ? "已允许自动更新" : "手动更新")
                .font(ReaderTypography.font(.caption)).foregroundStyle(palette.muted)
            if subscription.update > 0 {
                HStack(spacing: 4) {
                    Text("上次更新")
                    Text(Date(timeIntervalSince1970: Double(subscription.update) / 1_000), style: .date)
                    Text(Date(timeIntervalSince1970: Double(subscription.update) / 1_000), style: .time)
                }.font(ReaderTypography.font(.caption)).foregroundStyle(palette.muted)
            }
            HStack(spacing: 18) {
                Button("编辑") { edit(subscription) }.disabled(!state.canMutate)
                Button("检查更新") { state.check(subscription) }.disabled(!state.canMutate)
                    .accessibilityIdentifier("subscription-check:\(subscription.id)")
                Spacer(minLength: 0)
                Button("删除", role: .destructive) {
                    confirmation.confirm("删除订阅？", message: "仅移除“\(subscription.name)”的订阅地址，已导入的书源与书籍保留。",
                        actionTitle: "删除", destructive: true) { state.delete(subscription) }
                }.disabled(!state.canMutate)
            }.font(ReaderTypography.font(.action)).frame(minHeight: 44)
            if state.checkingID == subscription.id {
                ReaderPageState(title: "正在检查订阅", loading: true, actionTitle: "停止检查", action: state.stopCheck)
            } else if state.checkedID == subscription.id {
                if let failure = state.checkFailure {
                    ReaderPageState(title: "订阅检查未完成", detail: failure, actionTitle: "重新检查") { state.check(subscription) }
                }
                if let plan = state.plan, plan.subscriptionId == subscription.id { planContent(plan) }
                if let applied = state.applied, applied.subscriptionId == subscription.id {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        Text("本次已应用 \(applied.appliedSourceIds.count) 项，跳过 \(applied.skippedSourceIds.count) 项")
                            .accessibilityIdentifier("subscription-apply-result")
                        ForEach(applied.appliedSourceIds, id: \.self) { id in
                            Text("已应用 · " + appliedName(id))
                                .accessibilityIdentifier("subscription-applied-source:\(subscription.id):\(id)")
                        }
                        ForEach(applied.skippedSourceIds, id: \.self) { id in Text("已跳过 · " + appliedName(id)) }
                    }.font(ReaderTypography.font(.caption))
                }
            }
        }.padding(16).background(palette.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(palette.border, lineWidth: 1))
    }

    private func planContent(_ plan: ReaderSubscriptionPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("更新差异").font(ReaderTypography.font(.controlHeader))
            ForEach(kinds, id: \.self) { kind in
                HStack { Text(kindName(kind)); Spacer(); Text("\(plan.changes.filter { $0.kind == kind }.count)") }
                    .font(ReaderTypography.font(.caption)).foregroundStyle(palette.muted)
            }
            Text("仅新增和可安全更新的书源可选；冲突、仅本机及远端移除项保留。本机已删除的书源不会被强制恢复。")
                .font(ReaderTypography.font(.caption)).foregroundStyle(palette.muted)
            if state.planExpired { Text("更新计划已过期，请重新检查订阅").font(ReaderTypography.font(.caption)).foregroundStyle(palette.muted) }
            HStack(spacing: 14) {
                Button("选中安全项") { state.selectedSourceIDs = Set(state.safeChanges.map(\.sourceId)) }
                Button("全部不选") { state.selectedSourceIDs = [] }
                    .accessibilityIdentifier("subscription-select-none")
            }.font(ReaderTypography.font(.caption)).frame(minHeight: 44).disabled(!state.canMutate || state.planExpired)
            Button("应用所选 \(state.selectedSourceIDs.count) 项", action: state.applySelection)
                .buttonStyle(ReaderPrimaryButtonStyle())
                .disabled(!state.canMutate || state.selectedSourceIDs.isEmpty || state.planExpired)
                .accessibilityIdentifier("subscription-apply-selection")
            if plan.changes.isEmpty { ReaderPageState(title: "订阅没有变更") }
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(plan.changes) { change in changeRow(change, subscriptionID: plan.subscriptionId) }
            }
        }
    }

    @ViewBuilder private func changeRow(_ change: ReaderSubscriptionChange, subscriptionID: Int64) -> some View {
        if change.safeToApply {
            Toggle(isOn: Binding(get: { state.selectedSourceIDs.contains(change.sourceId) }, set: { selected in
                guard state.canMutate else { return }
                if selected { state.selectedSourceIDs.insert(change.sourceId) }
                else { state.selectedSourceIDs.remove(change.sourceId) }
            })) {
                changeLabel(change, subscriptionID: subscriptionID)
            }.disabled(!state.canMutate || state.planExpired)
                .accessibilityIdentifier("subscription-change:\(subscriptionID):\(change.kind):\(change.sourceId)")
        } else {
            HStack {
                changeLabel(change, subscriptionID: subscriptionID)
                Spacer(); Text("保留").font(ReaderTypography.font(.caption)).foregroundStyle(palette.muted)
            }.frame(minHeight: 44)
        }
    }

    private func changeLabel(_ change: ReaderSubscriptionChange, subscriptionID: Int64) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(change.name.isEmpty ? change.sourceId : change.name)
            Text(kindName(change.kind)).font(ReaderTypography.font(.caption)).foregroundStyle(palette.muted)
                .accessibilityIdentifier("subscription-change-kind:\(subscriptionID):\(change.kind):\(change.sourceId)")
        }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            HStack {
                Button("保留草稿并关闭") { state.editorPresented = false }.frame(minHeight: 44)
                Spacer(minLength: 8)
                Button("保存", action: state.saveDraft).frame(minHeight: 44).disabled(!state.canMutate)
                    .accessibilityIdentifier("subscription-save")
            }.padding(.horizontal, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("订阅地址").font(ReaderTypography.font(.controlHeader))
                    TextField("订阅名称", text: $state.draft.name).readerField().accessibilityIdentifier("subscription-name")
                    TextField("完整 HTTP / HTTPS 地址", text: $state.draft.url)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).readerField()
                        .accessibilityIdentifier("subscription-url")
                    Text(state.draft.type == 0 ? "书源包" : "现有包类型 \(state.draft.type)")
                        .font(ReaderTypography.font(.caption)).foregroundStyle(palette.muted)
                    TextField("排序值", text: $state.draft.order).keyboardType(.numbersAndPunctuation).readerField()
                    Toggle("允许自动更新", isOn: $state.draft.autoUpdate)
                    if let failure = state.draftFailure { ReaderPageState(title: "草稿尚未保存", detail: failure) }
                    operationStatus
                    Button("放弃草稿", role: .destructive) {
                        let captured = state.draft
                        editorConfirmation.confirm("放弃这个草稿？", message: "已保存的订阅不受影响。", actionTitle: "放弃", destructive: true) {
                            state.discardDraft(captured)
                        }
                    }.frame(minHeight: 44).disabled(!state.canMutate)
                }.padding(20)
            }
        }.foregroundStyle(palette.ink).background(palette.paper)
            .font(ReaderTypography.font(.body)).tint(palette.accent)
            .readerConfirmation(editorConfirmation)
    }

    private func edit(_ subscription: ReaderSourceSubscription) {
        guard state.canMutate else { return }
        if state.draft.isPresent, state.draft.id != subscription.id {
            confirmation.confirm("替换当前草稿？", message: "尚未保存的草稿将被替换，已保存的订阅不受影响。", actionTitle: "替换") {
                state.edit(subscription)
            }
        } else { state.edit(subscription) }
    }

    private func kindName(_ kind: String) -> String {
        switch kind {
        case "added": return "新增"
        case "update": return "可更新"
        case "unchanged": return "未改变"
        case "localOnly": return "仅本机"
        case "conflict": return "存在冲突"
        case "removedRemote": return "远端已移除"
        default: return "未识别变更，保留本机"
        }
    }

    private func appliedName(_ sourceID: String) -> String {
        guard let name = state.appliedPlan?.changes.first(where: { $0.sourceId == sourceID })?.name,
              !name.isEmpty else { return sourceID }
        return name
    }
}
