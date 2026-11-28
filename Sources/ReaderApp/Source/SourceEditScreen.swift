import Foundation
import ReaderCoreBridge
import ReaderDesign
import SwiftUI

struct SourceEditScreen: View {
    let source: M2SourceListEntry
    let coordinator: SourceManagementCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.readerTheme) private var theme
    @State private var draftName: String
    @State private var draft: String
    @State private var saving = false
    @State private var issue: String?

    init(source: M2SourceListEntry, coordinator: SourceManagementCoordinator) {
        self.source = source
        self.coordinator = coordinator
        _draftName = State(initialValue: source.name)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        _draft = State(initialValue: source.bookSource.flatMap {
            try? encoder.encode(ReaderM1JSONValue.object($0))
        }.flatMap { String(data: $0, encoding: .utf8) } ?? "")
    }

    var body: some View {
        Form {
            Section("基本资料") {
                TextField("书源名称", text: $draftName)
                    .readerTypography(ReaderDesignMetrics.sourceRowTitle)
                    .accessibilityIdentifier("source.edit.name")
                Text(source.baseUrl)
                    .readerTypography(ReaderDesignMetrics.sourceStatusText)
                    .foregroundStyle(theme.secondaryText)
            }
            Section("书源规则") {
                TextEditor(text: $draft)
                    .readerTypography(ReaderDesignMetrics.sourceFilterFieldText)
                    .frame(minHeight: CGFloat(ReaderDesignMetrics.sourceImportPasteHeight))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("书源规则 JSON")
                    .accessibilityIdentifier("source.edit.rules")
            }
            if let message = issue {
                Section {
                    Text(message)
                        .readerTypography(ReaderDesignMetrics.rowDetail)
                        .foregroundStyle(theme.danger)
                        .accessibilityIdentifier("source.edit.conflict")
                }
            }
        }
        .navigationTitle("编辑书源")
        .navigationBarTitleDisplayMode(.inline)
        .readerNavigationBar()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(saving ? "保存中" : "保存") { save() }
                    .disabled(saving || source.sourceVersion == nil || draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("source.edit.save")
            }
        }
    }

    private func save() {
        guard !saving, let version = source.sourceVersion else { return }
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              case .object(var json) = try? JSONDecoder().decode(ReaderM1JSONValue.self, from: Data(draft.utf8)),
              json["bookSourceUrl"] == source.bookSource?["bookSourceUrl"] else {
            issue = "请检查书源名称、JSON 格式和原书源地址。"
            return
        }
        json["bookSourceName"] = .string(name)
        let params = M2SourceImportParams(sourceId: source.sourceId, baseUrl: source.baseUrl, bookSource: json)
        saving = true
        issue = nil
        Task {
            defer { saving = false }
            do {
                let receipt = try await coordinator.saveEdit(params, expectedVersion: version)
                switch receipt {
                case .sourceImport: dismiss()
                case .rejected(let result) where result.data.error.details?.reason == "sourceVersionConflict":
                    issue = "书源已被其他操作更新，当前草稿已保留，可复制后重新读取。"
                default:
                    issue = "未能保存此次修改，已保留草稿。"
                }
            } catch SourceManagementCoordinator.Failure.conditionalEditUnavailable {
                issue = "当前版本无法保存此修改，已保留草稿。"
            } catch {
                issue = "无法核对此次保存结果，已保留草稿。"
            }
        }
    }
}
