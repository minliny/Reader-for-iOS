import SwiftUI
import ReaderCoreModels
import ReaderAppPersistence

/// 书源详情 Sheet — 使用 demo paper/card 结构展示书源能力和本地测试状态。
public struct BookSourceDetailSheet: View {
    let source: BookSource
    @State private var testState: String?
    @State private var validationResult: BookSourceValidationResult?
    @SwiftUI.Environment(\.dismiss) private var dismiss

    public init(source: BookSource) {
        self.source = source
    }

    public var body: some View {
        VStack(spacing: 0) {
            DemoBackBar(title: "书源详情", onBack: { dismiss() })

            DemoPaperScreen {
                headerCard
                detailInfoCard
                capabilityCard
                testActionCard
            }
        }
        .background(ReaderDesignTokens.Color.paperSolid.ignoresSafeArea())
        .onAppear { loadValidation() }
    }

    private var isImportedSource: Bool {
        // Imported sources have IDs starting with "m6-verify-" or not in fixture list
        let fixtureIDs = ["candidate-xingxingxsw", "fixture-001", "fixture-002", "fixture-003", "fixture-004", "fixture-005"]
        return source.id != nil && !fixtureIDs.contains(source.id!)
    }

    private func loadValidation() {
        let validator = BookSourceImportValidator()
        validationResult = validator.validate(source)
    }

    private var headerCard: some View {
        ReaderCard {
            HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(.source, size: ReaderDesignTokens.rssSourceListIconSize, accessibilityLabel: source.bookSourceName)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(source.bookSourceName)
                            .font(.system(size: ReaderDesignTokens.rssReaderTitleFontSize, weight: .heavy))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                            .lineLimit(2)

                        if isImportedSource {
                            importedSourceChip
                        }
                    }

                    Text(source.bookSourceUrl ?? "无")
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var importedSourceChip: some View {
        HStack(spacing: 4) {
            ReaderIcon(.download, size: 11, accessibilityLabel: "本地导入")
            Text("本地导入")
                .font(.system(size: 10, weight: .heavy))
        }
        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        .padding(.horizontal, 8)
        .frame(minHeight: 22)
        .background(Capsule().fill(ReaderDesignTokens.Color.chipBackground))
    }

    private var detailInfoCard: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsRowGap) {
                sectionTitle("基本信息")
                detailRow("名称", source.bookSourceName)
                detailRow("分组", source.bookSourceGroup ?? "未分组")
                detailRow("URL", source.bookSourceUrl ?? "无")
            }
        }
    }

    private var capabilityCard: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsRowGap) {
                sectionTitle("状态")
                detailRow("启用状态", source.enabled ? "已启用" : "已禁用")

                if let validation = validationResult {
                    capabilityDetailRow("搜索", validation.searchCapability, hint: searchHint(for: validation.searchCapability))
                    capabilityDetailRow("详情", validation.detailCapability, hint: detailHint(for: validation.detailCapability))
                    capabilityDetailRow("目录", validation.tocCapability, hint: tocHint(for: validation.tocCapability))
                    capabilityDetailRow("正文", validation.contentCapability, hint: contentHint(for: validation.contentCapability))
                } else {
                    detailRow("功能支持", "加载中...")
                }

                if let testState {
                    detailRow("测试结果", testState)
                }
            }
        }
    }

    private var testActionCard: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                Button {
                    runLocalMockTest()
                } label: {
                    HStack(spacing: 8) {
                        ReaderIcon(testState == "测试中..." ? .refresh : .play, size: 16, accessibilityLabel: "本地模拟测试")
                        Text(testState == nil ? "本地模拟测试" : "重新测试")
                            .font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssImportPanelLabelMinHeight)
                    .background(Capsule().fill(ReaderDesignTokens.Color.primaryDark))
                }
                .buttonStyle(.plain)
                .disabled(testState == "测试中...")
                .accessibilityLabel(testState == nil ? "本地模拟测试" : "重新测试")

                Text("离线模式，不会访问真实网络。")
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
            Text(label)
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .leading)
            Text(value)
                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .bold))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func capabilityDetailRow(_ label: String, _ status: CapabilityStatus, hint: String?) -> some View {
        HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
            Text(label)
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .leading)

            VStack(alignment: .trailing, spacing: 3) {
                Text(status.rawValue)
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .heavy))
                    .foregroundColor(status == .ready ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.primary)
                if let hint {
                    Text(hint)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func searchHint(for status: CapabilityStatus) -> String? {
        switch status {
        case .ready: return "支持搜索"
        case .missing: return "仅支持搜索测试"
        case .invalid: return "搜索规则异常"
        }
    }

    private func detailHint(for status: CapabilityStatus) -> String? {
        switch status {
        case .ready: return "支持获取详情"
        case .missing: return "详情功能不可用"
        case .invalid: return "详情规则异常"
        }
    }

    private func tocHint(for status: CapabilityStatus) -> String? {
        switch status {
        case .ready: return "支持获取目录"
        case .missing: return "目录功能不可用"
        case .invalid: return "目录规则异常"
        }
    }

    private func contentHint(for status: CapabilityStatus) -> String? {
        switch status {
        case .ready: return "支持阅读正文"
        case .missing: return "正文功能不可用"
        case .invalid: return "正文规则异常"
        }
    }

    private func runLocalMockTest() {
        Task {
            testState = "测试中..."
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            testState = "测试成功：本地 fixture 可用"
        }
    }
}
