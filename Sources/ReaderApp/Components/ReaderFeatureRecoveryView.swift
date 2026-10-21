import SwiftUI

/// Global task/recovery host, scoped to Runtime operation IDs. Closing this
/// sheet dismisses only presentation. It never cancels or repeats a new write.
struct ReaderFeatureRecoveryEntry: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var owner: ReaderFeatureRecoveryOwner
    @State private var presented = false
    var body: some View {
        Group {
            if model.reader == nil, !owner.operations.isEmpty || owner.failure != nil {
                ReaderRecoveryNotice(message: owner.failure == nil ? "\(owner.operations.count) 项原操作待核对" : "原操作列表待核对",
                    busy: false, title: "原操作待核对", actionTitle: "查看") { presented = true }
                    .frame(maxWidth: 520).padding(.horizontal, 16)
            }
        }.sheet(isPresented: $presented) {
            ReaderFeatureRecoveryList(model: model, owner: owner)
        }.onChange(of: model.reader?.id) { _, value in if value != nil { presented = false } }
    }
}

private struct ReaderFeatureRecoveryList: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var owner: ReaderFeatureRecoveryOwner
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("关闭") { dismiss() }; Spacer()
                Text("原操作核对").font(ReaderTypography.font(.controlHeader)); Spacer()
                Button("刷新") { Task { await owner.reload() } }.disabled(owner.loading || owner.busyID != nil)
            }
            if let failure = owner.failure {
                ReaderPageState(title: "列表尚未核对", detail: failure, actionTitle: "重试") { Task { await owner.reload() } }
            } else if owner.loading, owner.operations.isEmpty { ReaderPageState(title: "正在核对原操作", loading: true) }
            else if owner.operations.isEmpty {
                ReaderPageState(title: owner.lastResult.map { $0.status == .completed ? "原操作结果已确认" : "原操作已明确结束" } ?? "没有待核对的原操作",
                                detail: owner.lastResult?.message ?? "")
            }
            else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(owner.operations, id: \.id) { operation in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(owner.label(for: operation)).font(ReaderTypography.font(.controlHeader))
                                Text(owner.details[operation.id] ?? (operation.acknowledged ? "已取得原回执，后续处理仍待核对" : "原操作结果尚待确认"))
                                    .font(ReaderTypography.font(.caption))
                                Button(owner.busyID == operation.id ? "正在核对" : "继续核对原操作") { resume(operation.id) }
                                    .frame(minHeight: 44).disabled(owner.busyID != nil || model.actions.busy ||
                                        (model.actions.hasPending && model.actions.pendingOperationID != operation.id))
                                    .accessibilityIdentifier("resume-feature-\(operation.id)")
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
                                .background(ReaderPalette(scheme).card, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }.padding(20).background(ReaderPalette(scheme).paper).task { await owner.reload() }
    }
    private func resume(_ id: String) {
        guard model.reader == nil else { return }
        Task {
            // A live in-memory owner retains its typed closure and cleanup.
            if model.readingTime.pendingOperationID == id {
                await model.readingTime.resumeOriginal()
                await owner.reload()
            } else if model.actions.pendingOperationID == id {
                _ = await model.actions.resumeOriginal()
                await owner.reload(); await model.reloadLibrary()
            } else {
                guard !model.actions.hasPending else { return }
                if let result = await owner.resume(id), !result.remaining {
                    await model.reloadLibrary()
                    model.showFeedback(result.message ?? (result.status == .completed ? "原操作结果已确认" : "原操作已明确结束"))
                }
            }
        }
    }
}
