import SwiftUI
import ReaderCoreModels
import ReaderAppPersistence

/// 书源详情 Sheet — ScrollView+VStack，避免 NavigationStack+List 在 sheet 中空白
public struct BookSourceDetailSheet: View {
    let source: BookSource
    @State private var testState: String?
    @State private var validationResult: BookSourceValidationResult?

    public init(source: BookSource) {
        self.source = source
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 来源标识
                if isImportedSource {
                    HStack(spacing: 6) {
                        Label("本地导入", systemImage: "square.and.arrow.down")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(6)
                        Spacer()
                    }
                }

                // 标题
                Text("书源详情")
                    .font(.title2).fontWeight(.bold)

                // 基本信息
                VStack(alignment: .leading, spacing: 8) {
                    Text("基本信息").font(.headline)
                    Divider()
                    detailRow("名称", source.bookSourceName)
                    detailRow("分组", source.bookSourceGroup ?? "未分组")
                    detailRow("URL", source.bookSourceUrl ?? "无")
                }

                // 状态
                VStack(alignment: .leading, spacing: 8) {
                    Text("状态").font(.headline)
                    Divider()
                    HStack {
                        Text("启用状态")
                        Spacer()
                        Text(source.enabled ? "已启用" : "已禁用")
                            .foregroundStyle(source.enabled ? .green : .secondary)
                    }
                    if let validation = validationResult {
                        capabilityDetailRow("搜索", validation.searchCapability, hint: searchHint(for: validation.searchCapability))
                        capabilityDetailRow("详情", validation.detailCapability, hint: detailHint(for: validation.detailCapability))
                        capabilityDetailRow("目录", validation.tocCapability, hint: tocHint(for: validation.tocCapability))
                        capabilityDetailRow("正文", validation.contentCapability, hint: contentHint(for: validation.contentCapability))
                    } else {
                        HStack {
                            Text("功能支持")
                            Spacer()
                            Text("加载中...")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let msg = testState {
                        HStack {
                            Text("测试结果")
                            Spacer()
                            Text(msg)
                                .foregroundStyle(msg.contains("成功") ? .green : .orange)
                        }
                    }
                }

                // 操作区
                VStack(spacing: 12) {
                    Button {
                        runLocalMockTest()
                    } label: {
                        HStack {
                            if testState == "测试中..." {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "play.circle")
                            }
                            Text(testState == nil ? "本地模拟测试" : "重新测试")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(testState == "测试中...")

                    Text("离线模式 — 不会访问真实网络")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
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

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline).foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value).font(.subheadline)
            Spacer()
        }
    }

    private func capabilityDetailRow(_ label: String, _ status: CapabilityStatus, hint: String?) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(status.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(status == .ready ? .green : .orange)
                if let hint = hint {
                    Text(hint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
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
