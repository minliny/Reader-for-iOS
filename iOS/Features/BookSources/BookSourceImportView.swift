import SwiftUI

public struct BookSourceImportView: View {
    private let onExit: (() -> Void)?

    public init(onExit: (() -> Void)? = nil) {
        self.onExit = onExit
    }

    public var body: some View {
        SettingsDemoShellView(demoRoute: "source-import-options", onExit: onExit)
    }
}

struct BookSourceImportContent: View {
    var onRoute: (String) -> Void = { _ in }

    private let items: [(ReaderAssetIcon, String, String, String)] = [
        (.cloud, "网络导入", "从 URL 拉取书源包", "source-import-preview"),
        (.folder, "本地导入", "选择本地 JSON 或 TXT 文件", "source-import-preview"),
        (.file, "剪贴板导入", "解析剪贴板中的书源内容", "source-import-preview"),
        (.edit, "手动新建", "进入空白书源编辑页", "source-rule-edit")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items, id: \.1) { item in
                Button {
                    onRoute(item.3)
                } label: {
                    HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                        ReaderIcon(item.0, size: 18, accessibilityLabel: item.1)
                            .frame(width: ReaderDesignTokens.settingsRowIconColumn)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.1)
                                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                            Text(item.2)
                                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                                .foregroundStyle(ReaderDesignTokens.Color.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        ReaderIcon(.chevron, size: 14)
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                            .fill(ReaderDesignTokens.Color.controlBackground.opacity(0.72))
                    )
                }
                .buttonStyle(DemoPressButtonStyle())
            }

            Button {
                onRoute("source-management")
            } label: {
                Text("取消")
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                            .fill(ReaderDesignTokens.Color.chipBackground.opacity(0.72))
                    )
            }
            .buttonStyle(DemoPressButtonStyle())
        }
    }
}
