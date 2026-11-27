import Foundation
import Observation
import ReaderCoreBridge
import ReaderDesign
import ReaderHost
import SwiftUI
import UniformTypeIdentifiers

struct SourceImportChoice: Identifiable {
    let id: String
    let name: String
    let group: String?
    let preview: SourceImportPreview

    var exists: Bool { preview.existing != nil }
}

@MainActor
@Observable
final class SourceImportBatch {
    private(set) var running = false
    private(set) var total = 0
    private(set) var completed = 0
    private(set) var failed = 0
    private(set) var unresolved = false

    func start(_ items: [SourceImportChoice], coordinator: SourceManagementCoordinator) {
        guard !running, !items.isEmpty else { return }
        total = items.count
        completed = 0
        failed = 0
        unresolved = false
        running = true
        Task {
            defer { running = false }
            for item in items {
                do {
                    let receipt = try await coordinator.confirmImport(item.preview)
                    if case .sourceImport = receipt { completed += 1 }
                    else { failed += 1 }
                } catch {
                    if coordinator.pendingMutation != nil {
                        unresolved = true
                        break
                    }
                    failed += 1
                }
            }
        }
    }
}

struct SourceImportScreen: View {
    let coordinator: SourceManagementCoordinator
    let onCommitted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.readerTheme) private var theme
    @State private var mode: Input = .text
    @State private var document = ""
    @State private var urlText = ""
    @State private var file: URL?
    @State private var choosingFile = false
    @State private var items: [SourceImportChoice]?
    @State private var selected: Set<String> = []
    @State private var busy = false
    @State private var error: String?
    @State private var submitted = false
    @State private var confirm = false

    private enum Input: String, CaseIterable {
        case text = "文本", file = "文件", url = "网址"
    }

    private var step: Int { submitted ? 3 : (items == nil ? 1 : 2) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceMedium)) {
                steps
                if let error {
                    Text(error).readerTypography(ReaderDesignMetrics.rowDetail)
                        .foregroundStyle(theme.danger)
                        .accessibilityIdentifier("source.import.error")
                }
                if submitted { results }
                else if let items { preview(items) }
                else { input }
            }
            .padding(CGFloat(ReaderDesignMetrics.screenInset))
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle("导入书源")
        .navigationBarTitleDisplayMode(.inline)
        .readerNavigationBar()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
        }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.json, .plainText]) { result in
            if case .success(let url) = result { file = url }
        }
        .alert("确认导入书源？", isPresented: $confirm) {
            Button("取消", role: .cancel) {}
            Button("确认导入") { submit() }
                .accessibilityIdentifier("source.import.apply")
        } message: {
            Text("将导入 \(selected.count) 条书源，并保留书源文档中原有的分组。")
        }
        .onChange(of: coordinator.importBatch.running) { _, running in
            if submitted && !running { onCommitted() }
        }
    }

    private var steps: some View {
        HStack {
            ForEach(Array(["输入", "预览", "导入"].enumerated()), id: \.offset) { index, title in
                HStack(spacing: CGFloat(ReaderDesignMetrics.rowBlockSpacing)) {
                    Text("\(index + 1)")
                        .readerTypography(ReaderDesignMetrics.sourceTransferBadgeText)
                        .frame(width: CGFloat(ReaderDesignMetrics.sourceImportStepDiameter),
                               height: CGFloat(ReaderDesignMetrics.sourceImportStepDiameter))
                        .background(step == index + 1 ? theme.accentTint : theme.mutedFill, in: Circle())
                    Text(title).readerTypography(ReaderDesignMetrics.rowLabel)
                }
                .foregroundStyle(step == index + 1 ? theme.accent : theme.secondaryText)
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityLabel("第 \(step) 步")
    }

    private var input: some View {
        VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
            Picker("导入方式", selection: $mode) {
                ForEach(Input.allCases, id: \.self) { option in Text(option.rawValue).tag(option) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("source.import.mode")

            switch mode {
            case .text:
                Text("在下方粘贴书源 JSON。")
                    .readerTypography(ReaderDesignMetrics.rowDetail)
                    .foregroundStyle(theme.secondaryText)
                TextEditor(text: $document)
                    .readerTypography(ReaderDesignMetrics.sourceFilterFieldText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: CGFloat(ReaderDesignMetrics.sourceImportPasteHeight))
                    .padding(CGFloat(ReaderDesignMetrics.spaceExtraSmall))
                    .background(theme.field, in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.inputRadius)))
                    .accessibilityLabel("书源 JSON")
                    .accessibilityIdentifier("source.import.text")
            case .file:
                Button {
                    choosingFile = true
                } label: {
                    Label { Text(file?.lastPathComponent ?? "选取文件") }
                    icon: { ReaderIcon(ReaderIconRegistry.openDocument) }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("source.import.file")
            case .url:
                TextField("https://", text: $urlText)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .readerTypography(ReaderDesignMetrics.sourceFilterFieldText)
                    .padding(.horizontal, CGFloat(ReaderDesignMetrics.spaceSmall))
                    .frame(minHeight: CGFloat(ReaderDesignMetrics.sourceFormFieldHeight))
                    .background(theme.field, in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.inputRadius)))
                    .accessibilityIdentifier("source.import.url")
            }
            accentButton(busy ? "正在读取" : "预览书源", action: prepare)
                .disabled(busy || !ready)
                .accessibilityIdentifier("source.import.preview")
        }
    }

    private var ready: Bool {
        switch mode {
        case .text: !document.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .file: file != nil
        case .url: urlText.sourceDocumentURL != nil
        }
    }

    private func preview(_ items: [SourceImportChoice]) -> some View {
        VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
            Text("可导入 \(items.filter { !$0.exists }.count) 条 · 已存在 \(items.filter(\.exists).count) 条")
                .readerTypography(ReaderDesignMetrics.rowDetail)
                .foregroundStyle(theme.secondaryText)
            ForEach(items) { item in
                Toggle(isOn: Binding(get: { selected.contains(item.id) }, set: { active in
                    if active { selected.insert(item.id) } else { selected.remove(item.id) }
                })) {
                    VStack(alignment: .leading) {
                        Text(item.name).readerTypography(ReaderDesignMetrics.sourceRowTitle)
                        Text(item.group ?? item.id)
                            .readerTypography(ReaderDesignMetrics.sourceStatusText)
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(1)
                        if item.exists { SourceStatusBadge(label: "已存在", tone: .neutral) }
                    }
                }
                .disabled(item.exists)
                .padding(CGFloat(ReaderDesignMetrics.cardPadding))
                .background(theme.surface, in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
                .accessibilityIdentifier("source.import.choice.\(item.id)")
            }
            HStack {
                Button("返回修改") { self.items = nil }
                    .buttonStyle(.bordered)
                accentButton("确认导入") { confirm = true }
                    .disabled(selected.isEmpty || coordinator.importBatch.running)
                    .accessibilityIdentifier("source.import.confirm")
            }
        }
    }

    private var results: some View {
        let batch = coordinator.importBatch
        return VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
            ReaderTaskProgress(title: batch.running ? "正在导入书源" : "书源导入结果",
                               completed: batch.completed, failed: batch.failed, total: batch.total - (batch.unresolved ? 1 : 0))
                .accessibilityIdentifier("source.import.result")
            if batch.unresolved {
                Text("1 项等待原操作回执。可返回书源列表核对。")
                    .readerTypography(ReaderDesignMetrics.rowDetail)
                    .foregroundStyle(theme.secondaryText)
            }
            if !batch.running {
                accentButton("完成") { onCommitted(); dismiss() }
                    .accessibilityIdentifier("source.import.done")
            }
        }
    }

    private func accentButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).foregroundStyle(theme.onAccent) }
            .buttonStyle(.borderedProminent)
            .tint(theme.accentFill)
    }

    private func prepare() {
        guard !busy, ready else { return }
        error = nil
        busy = true
        let inputMode = mode
        let text = document
        let file = file
        let url = urlText.sourceDocumentURL
        Task {
            defer { busy = false }
            do {
                let data: Data
                switch inputMode {
                case .text:
                    data = Data(text.utf8)
                case .file:
                    guard let file else { return }
                    data = try await SourceDocumentFile.read(file)
                case .url:
                    guard let url, let network = coordinator.network else { throw SourceManagementCoordinator.Failure.loginHostUnavailable }
                    let result = try await network.fetch(.init(timeoutMs: 30_000, url: url.absoluteString))
                    data = Data(result.body.utf8)
                }
                guard data.count <= 8 * 1_024 * 1_024 else { throw SourceDocumentFile.Failure.exceedsLimit }
                let values = try await coordinator.previewUngroupedImport(data)
                items = values
                selected = Set(values.filter { !$0.exists }.map(\.id))
            } catch {
                self.error = "未能读取书源。请核对 JSON 格式、文件大小或链接后重试。"
            }
        }
    }

    private func submit() {
        guard let items, !coordinator.importBatch.running else { return }
        guard coordinator.pendingMutation == nil else {
            error = "已有书源操作等待原回执，请返回书源列表核对。"
            return
        }
        let chosen = items.filter { selected.contains($0.id) && !$0.exists }
        guard !chosen.isEmpty else { return }
        submitted = true
        coordinator.importBatch.start(chosen, coordinator: coordinator)
    }
}

extension String {
    var sourceDocumentURL: URL? {
        let input = trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: input),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              let host = components.host, !host.isEmpty, components.user == nil, components.password == nil else { return nil }
        return components.url
    }
}
