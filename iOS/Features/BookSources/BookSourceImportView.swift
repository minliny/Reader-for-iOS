import SwiftUI
import ReaderShellValidation

public struct BookSourceImportView: View {
    public init() {}

    public var body: some View {
        DemoBackScreen(title: "导入书源") {
            BookSourceImportContent()
        }
    }
}

struct BookSourceImportContent: View {
    @StateObject private var viewModel = BookSourceViewModel()

    var body: some View {
        importInputCard
        importStateView
    }

    private var isImportButtonDisabled: Bool {
        viewModel.jsonInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var importInputCard: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                HStack(alignment: .center, spacing: ReaderDesignTokens.settingsRowGap) {
                    ReaderIcon(.file, size: ReaderDesignTokens.rssImportListIconSize, accessibilityLabel: "书源 JSON")
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("粘贴 Legado 书源 JSON")
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        Text("导入前会执行本地结构校验。")
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                TextEditor(text: $viewModel.jsonInput)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .frame(minHeight: 168)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                            .fill(ReaderDesignTokens.Color.paperSolid)
                            .overlay(
                                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                                    .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                            )
                    )

                Button {
                    Task { await viewModel.importFromText() }
                } label: {
                    HStack(spacing: 8) {
                        ReaderIcon(.upload, size: 16, accessibilityLabel: "从文本导入")
                        Text("从文本导入")
                            .font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundColor(isImportButtonDisabled ? ReaderDesignTokens.Color.primaryDark : .white)
                    .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssImportPanelLabelMinHeight)
                    .background(
                        Capsule()
                            .fill(isImportButtonDisabled ? ReaderDesignTokens.Color.chipBackground : ReaderDesignTokens.Color.primaryDark)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isImportButtonDisabled)
                .accessibilityLabel("从文本导入书源")
            }
        }
    }

    @ViewBuilder
    private var importStateView: some View {
        switch viewModel.importState {
        case .idle:
            ReaderStateBanner(
                icon: .source,
                title: "等待导入",
                messages: ["粘贴 JSON 后可以导入；当前不会访问真实网络。"]
            )

        case .loading:
            ReaderStateBanner(
                icon: .refresh,
                title: "导入中",
                messages: ["正在解析书源并执行本地校验。"]
            )

        case .success(let source):
            ReaderStateCard(
                icon: .check,
                title: "导入成功",
                subtitle: "已保存 \(source.displayName)。"
            )

        case .failed(let message):
            ReaderStateBanner(
                icon: .warning,
                title: "导入失败",
                messages: [message]
            )

        case .unsupported(let reason):
            ReaderStateBanner(
                icon: .warning,
                title: "不支持该书源",
                messages: [reason]
            )

        case .partial(let source, let warnings):
            ReaderStateBanner(
                icon: .warning,
                title: "部分导入",
                messages: [source.displayName] + warnings
            )
        }
    }
}
