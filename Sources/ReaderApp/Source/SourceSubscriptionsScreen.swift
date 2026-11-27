import Foundation
import Observation
import ReaderCoreBridge
import ReaderDesign
import SwiftUI

struct SourceSubscriptionsScreen: View {
    let coordinator: SourceManagementCoordinator
    @State private var stored: [M2RuleSubData]?
    @State private var loadFailed = false
    @State private var busy = false
    @State private var active: Surface?
    @State private var pendingDelete: M2RuleSubData?
    @State private var feedback = SourceSubscriptionFeedback()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.readerTheme) private var theme
    @Environment(\.scenePhase) private var phase

    private var frontmost: Bool { active == nil && pendingDelete == nil }
    private var actionBlocked: Bool { busy || feedback.recovery != nil }

    private enum Surface: Identifiable {
        case add, edit(M2RuleSubData), preview(M2RuleSubUpdatePreviewData)

        var id: String {
            switch self {
            case .add: "add"
            case .edit(let sub): "edit-\(sub.id)"
            case .preview(let preview): preview.planId
            }
        }
    }

    var body: some View {
        Group {
            if let stored {
                let subscriptions = stored.filter { $0.type == 3 }
                if subscriptions.isEmpty {
                    PageState(state: .empty("还没有规则订阅"))
                } else {
                    ScrollView {
                        LazyVStack(spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
                            ForEach(subscriptions, id: \.id, content: row)
                        }
                        .padding(CGFloat(ReaderDesignMetrics.screenInset))
                    }
                    .refreshable { await reload() }
                }
            } else {
                PageState(state: loadFailed ? .failed("无法读取规则订阅", actionGeneration: 0) : .loading) { _ in
                    Task { await reload() }
                }
            }
        }
        .background(theme.background)
        .navigationTitle("规则订阅")
        .navigationBarTitleDisplayMode(.inline)
        .readerNavigationBar()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }.accessibilityIdentifier("source.subscription.close")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { active = .add } label: { ReaderIcon(ReaderIconRegistry.add) }
                    .accessibilityLabel("新增订阅")
                    .accessibilityIdentifier("source.subscription.add")
                    .disabled(actionBlocked || stored == nil)
            }
        }
        .task { await reload() }
        .modifier(SourceSubscriptionNotices(feedback: feedback, coordinator: coordinator, frontmost: frontmost) { receipt in
            await reload()
            if case .rejected = receipt { notify("Core 未应用上一次订阅操作。", key: "verify.rejected") }
        })
        .sheet(item: $active, onDismiss: { Task { await reload() } }) { value in
            NavigationStack {
                switch value {
                case .add: SourceSubscriptionEditor(sub: nil, coordinator: coordinator)
                case .edit(let sub): SourceSubscriptionEditor(sub: sub, coordinator: coordinator)
                case .preview(let preview): SourceSubscriptionPreviewScreen(preview: preview, coordinator: coordinator)
                }
            }
        }
        .alert("删除规则订阅？", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        ), presenting: pendingDelete) { sub in
            Button("取消", role: .cancel) {}
            Button("删除订阅", role: .destructive) { delete(sub) }
        } message: { _ in
            Text("只删除此订阅。此前已经导入的书源会保留。")
        }
    }

    private func row(_ sub: M2RuleSubData) -> some View {
        VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceExtraSmall)) {
            HStack {
                ReaderIcon(ReaderIconRegistry.sourceSubscription)
                Text(sub.name).readerTypography(ReaderDesignMetrics.sourceRowTitle)
                Spacer()
                Menu {
                    Button("编辑订阅") { active = .edit(sub) }
                        .accessibilityIdentifier("source.subscription.edit.\(sub.id)")
                    Button("删除订阅", role: .destructive) { pendingDelete = sub }
                } label: {
                    ReaderIcon(ReaderIconRegistry.more)
                        .frame(width: CGFloat(ReaderDesignMetrics.minimumActionTarget), height: CGFloat(ReaderDesignMetrics.minimumActionTarget))
                }
                .accessibilityLabel("\(sub.name)的更多操作")
                .accessibilityIdentifier("source.subscription.more.\(sub.id)")
                .disabled(actionBlocked)
            }
            Text(sub.url)
                .readerTypography(ReaderDesignMetrics.sourceStatusText)
                .foregroundStyle(theme.secondaryText)
                .lineLimit(2)
            Button { preview(sub) } label: {
                Label {
                    Text("预览版本差异").readerTypography(ReaderDesignMetrics.sourceFilterFieldText)
                } icon: {
                    ReaderIcon(ReaderIconRegistry.refresh)
                }
            }
            .buttonStyle(.bordered)
            .disabled(actionBlocked)
            .accessibilityIdentifier("source.subscription.preview.\(sub.id)")
        }
        .padding(CGFloat(ReaderDesignMetrics.cardPadding))
        .background(theme.surface, in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("source.subscription.row.\(sub.id)")
    }

    private func reload() async {
        defer { feedback.track(coordinator.pendingMutation) }
        do {
            stored = try await coordinator.subscriptions().subs
            loadFailed = false
        } catch {
            if stored == nil { loadFailed = true }
            else { notify("暂时无法刷新订阅，已保留原列表。", key: "list.refresh") }
        }
    }

    private func preview(_ sub: M2RuleSubData) {
        guard !actionBlocked else { return }
        busy = true
        Task {
            defer { busy = false }
            do { active = .preview(try await coordinator.fetchSubscriptionPreview(sub)) }
            catch { notify("暂时无法预览订阅版本。请核对链接后重试。", key: "list.preview") }
        }
    }

    private func delete(_ sub: M2RuleSubData) {
        guard !actionBlocked else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                let receipt = try await coordinator.deleteSubscription(.init(id: sub.id))
                guard case .ruleSubDelete = receipt else { throw SourceManagementCoordinator.Failure.invalidSubscription }
                await reload()
            } catch SourceManagementCoordinator.Failure.originalUnresolved(let original, _) {
                feedback.track(original)
            } catch {
                notify("订阅删除未完成，已保留原列表。", key: "list.delete")
            }
        }
    }

    private func notify(_ message: String, key: String) {
        feedback.toast.show(message: message, key: key, feedbackEnabled: frontmost, sceneActive: phase == .active)
    }
}

struct SourceSubscriptionEditor: View {
    let sub: M2RuleSubData?
    let coordinator: SourceManagementCoordinator
    @State private var name: String
    @State private var url: String
    @State private var feedback = SourceSubscriptionFeedback()
    @State private var saving = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase

    init(sub: M2RuleSubData?, coordinator: SourceManagementCoordinator) {
        self.sub = sub
        self.coordinator = coordinator
        _name = State(initialValue: sub?.name ?? "")
        _url = State(initialValue: sub?.url ?? "")
    }

    var body: some View {
        Form {
            Section("订阅信息") {
                TextField("订阅名称", text: $name)
                    .readerTypography(ReaderDesignMetrics.rowLabel)
                    .accessibilityIdentifier("source.subscription.name")
                TextField("规则包网址", text: $url)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .readerTypography(ReaderDesignMetrics.rowLabel)
                    .accessibilityIdentifier("source.subscription.url")
            }
        }
        .disabled(saving || feedback.recovery != nil)
        .navigationTitle(sub == nil ? "新增规则订阅" : "编辑规则订阅")
        .navigationBarTitleDisplayMode(.inline)
        .readerNavigationBar()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(saving ? "保存中" : "保存") { save() }
                    .disabled(saving || feedback.recovery != nil
                        || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || url.sourceDocumentURL == nil)
                    .accessibilityIdentifier("source.subscription.save")
            }
        }
        .modifier(SourceSubscriptionNotices(feedback: feedback, coordinator: coordinator) { receipt in
            if case .ruleSubPut = receipt { dismiss() }
            else { showSaveFailure() }
        })
    }

    private func save() {
        guard !saving, feedback.recovery == nil, let address = url.sourceDocumentURL else { return }
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        saving = true
        Task {
            defer { saving = false }
            do {
                let receipt = try await coordinator.saveSourceSubscription(name: title, url: address, existing: sub)
                guard case .ruleSubPut = receipt else { throw SourceManagementCoordinator.Failure.invalidSubscription }
                dismiss()
            } catch SourceManagementCoordinator.Failure.originalUnresolved(let original, _) {
                feedback.track(original)
            } catch {
                showSaveFailure()
            }
        }
    }

    private func showSaveFailure() {
        feedback.toast.show(message: "订阅保存未完成，已保留编辑内容。", key: "editor.save",
                            feedbackEnabled: true, sceneActive: phase == .active)
    }
}

struct SourceSubscriptionPreviewContent: View {
    let preview: M2RuleSubUpdatePreviewData
    @Binding var selected: Set<String>
    let committing: Bool
    let confirm: () -> Void
    @Environment(\.readerTheme) private var theme

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
                HStack {
                    Text("版本差异").readerTypography(ReaderDesignMetrics.pageTitle)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("已选 \(selected.count) 项")
                        .readerTypography(ReaderDesignMetrics.sourceStatusText)
                        .foregroundStyle(theme.secondaryText)
                }
                if preview.changes.isEmpty {
                    PageState(state: .empty("没有发现版本差异")).frame(minHeight: 165)
                }
                ForEach(preview.changes, id: \.sourceId, content: change)
            }
            .padding(CGFloat(ReaderDesignMetrics.screenInset))
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .safeAreaInset(edge: .bottom) {
            Button(action: confirm) {
                Text(committing ? "正在应用" : "应用所选规则")
                    .foregroundStyle(theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: CGFloat(ReaderDesignMetrics.minimumActionTarget))
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accentFill)
            .disabled(selected.isEmpty || committing)
            .padding(CGFloat(ReaderDesignMetrics.screenInset))
            .background(theme.surface)
            .accessibilityIdentifier("source.subscription.apply")
        }
    }

    private func change(_ item: M2RuleSubUpdateChange) -> some View {
        HStack(spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
            VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.rowBlockSpacing)) {
                Text(item.name)
                    .readerTypography(ReaderDesignMetrics.sourceRowTitle)
                    .lineLimit(2)
                Text(item.sourceId)
                    .readerTypography(ReaderDesignMetrics.sourceStatusText)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            SourceStatusBadge(label: item.kind.label, tone: item.kind.tone)
            if item.kind.canApply {
                Toggle("选择\(item.name)", isOn: Binding(
                    get: { selected.contains(item.sourceId) },
                    set: { value in
                        if value { selected.insert(item.sourceId) } else { selected.remove(item.sourceId) }
                    }
                ))
                .labelsHidden()
                .tint(theme.accentFill)
            }
        }
        .padding(CGFloat(ReaderDesignMetrics.cardPadding))
        .background(theme.surface, in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
    }
}

struct SourceSubscriptionPreviewScreen: View {
    let preview: M2RuleSubUpdatePreviewData
    let coordinator: SourceManagementCoordinator
    @State private var selected: Set<String>
    @State private var committing = false
    @State private var confirming = false
    @State private var feedback = SourceSubscriptionFeedback()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase

    init(preview: M2RuleSubUpdatePreviewData, coordinator: SourceManagementCoordinator) {
        self.preview = preview
        self.coordinator = coordinator
        _selected = State(initialValue: Set(preview.changes.filter { $0.kind.canApply }.map(\.sourceId)))
    }

    var body: some View {
        SourceSubscriptionPreviewContent(preview: preview, selected: $selected, committing: committing) { confirming = true }
            .disabled(feedback.recovery != nil)
            .navigationTitle("订阅差异预览")
            .navigationBarTitleDisplayMode(.inline)
            .readerNavigationBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
            .modifier(SourceSubscriptionNotices(feedback: feedback, coordinator: coordinator, frontmost: !confirming) { receipt in
                if case .ruleSubUpdateApplyV1 = receipt { dismiss() }
                else { showApplyFailure() }
            })
            .alert("应用订阅规则？", isPresented: $confirming) {
                Button("取消", role: .cancel) {}
                Button("确认应用") { commit() }
                    .accessibilityIdentifier("source.subscription.confirm")
            } message: {
                Text("将按预览应用 \(selected.count) 条新增或更新的规则。")
            }
    }

    private func commit() {
        guard !committing, feedback.recovery == nil, !selected.isEmpty else { return }
        committing = true
        let selection = selected.sorted()
        Task {
            defer { committing = false }
            do {
                let response = try await coordinator.confirmSubscription(preview, sourceIds: selection)
                guard case .ruleSubUpdateApplyV1 = response else { throw SourceManagementCoordinator.Failure.invalidSubscription }
                dismiss()
            } catch SourceManagementCoordinator.Failure.originalUnresolved(let original, _) {
                feedback.track(original)
            } catch {
                showApplyFailure()
            }
        }
    }

    private func showApplyFailure() {
        feedback.toast.show(message: "应用未完成。若版本已变化，请关闭后重新预览。", key: "preview.apply",
                            feedbackEnabled: !confirming, sceneActive: phase == .active)
    }
}

@MainActor
@Observable
private final class SourceSubscriptionFeedback {
    struct Recovery: Equatable {
        let operationId: String
        let generation: Int
    }

    let toast = ReaderToastPresenter()
    private(set) var recovery: Recovery?
    private var generation = 0
    var verifying = false

    func track(_ original: M2RulesMutationApplyParams?) {
        switch original?.mutation {
        case .ruleSubPut, .ruleSubDelete, .ruleSubUpdateApplyV1: setRecovery(for: original?.operationId)
        default: setRecovery(for: nil)
        }
    }

    private func setRecovery(for operationId: String?) {
        guard recovery?.operationId != operationId else { return }
        generation += 1
        recovery = operationId.map { .init(operationId: $0, generation: generation) }
    }
}

private struct SourceSubscriptionNotices: ViewModifier {
    let feedback: SourceSubscriptionFeedback
    let coordinator: SourceManagementCoordinator
    var frontmost = true
    let onReceipt: (M2RulesMutationReceipt) async -> Void
    @Environment(\.scenePhase) private var phase

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let recovery = feedback.recovery {
                    RecoveryNotice(title: "需要核对订阅操作", message: "上一次变更尚无可核对回执。可核对原操作的结果。",
                                   generation: recovery.generation,
                                   action: feedback.verifying ? nil : .init(title: "核对原操作", generation: recovery.generation),
                                   availability: frontmost) { generation, actionGeneration in
                        guard generation == recovery.generation, actionGeneration == generation else { return }
                        verify(recovery)
                    }
                    .padding(CGFloat(ReaderDesignMetrics.spaceSmall))
                }
            }
            .overlay(alignment: .bottom) {
                if active, let message = feedback.toast.message {
                    TransientToast(message: message).padding(CGFloat(ReaderDesignMetrics.spaceSmall))
                }
            }
            .onChange(of: active) { _, visible in if !visible { feedback.toast.dismiss() } }
            .onDisappear { feedback.toast.dismiss() }
    }

    private var active: Bool { frontmost && phase == .active }

    private func verify(_ recovery: SourceSubscriptionFeedback.Recovery) {
        guard active, !feedback.verifying, feedback.recovery == recovery else { return }
        feedback.verifying = true
        Task {
            defer { feedback.verifying = false }
            do {
                let receipt = try await coordinator.verifyPending(expectedOperationId: recovery.operationId)
                guard feedback.recovery == recovery else { return }
                if let receipt {
                    feedback.track(nil)
                    await onReceipt(receipt)
                } else if coordinator.pendingMutation?.operationId != recovery.operationId {
                    feedback.track(nil)
                } else {
                    notifyUnresolved()
                }
            } catch {
                if feedback.recovery == recovery { notifyUnresolved() }
            }
        }
    }

    private func notifyUnresolved() {
        feedback.toast.show(message: "原操作尚无可核对回执。", key: "verify.pending",
                            feedbackEnabled: frontmost, sceneActive: phase == .active)
    }
}

extension M2RuleSubUpdateChangeKind {
    var canApply: Bool { self == .added || self == .update }

    var label: String {
        switch self {
        case .added: "新增"
        case .update: "更新"
        case .unchanged: "不变"
        case .localOnly: "本机独有"
        case .conflict: "冲突"
        case .removedRemote: "远端移除"
        }
    }

    var tone: SourceStatusBadge.Tone {
        switch self {
        case .added: .success
        case .update: .warning
        case .conflict, .removedRemote: .failure
        case .unchanged, .localOnly: .neutral
        }
    }
}
