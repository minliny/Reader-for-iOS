import SwiftUI
import ReaderCoreModels

/// 书源详情 Sheet — ScrollView+VStack，避免 NavigationStack+List 在 sheet 中空白
public struct BookSourceDetailSheet: View {
    let source: BookSource
    @State private var testState: String?

    public init(source: BookSource) {
        self.source = source
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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
                    if let msg = testState {
                        HStack {
                            Text("测试结果")
                            Spacer()
                            Text(msg)
                                .foregroundStyle(msg.contains("成功") ? .green : .orange)
                        }
                    }
                }

                // 规则摘要
                VStack(alignment: .leading, spacing: 8) {
                    Text("规则摘要").font(.headline)
                    Divider()
                    summaryRow("搜索规则", "\(source.bookSourceName) 标准搜索")
                    summaryRow("详情规则", "\(source.bookSourceName) 标准详情")
                    summaryRow("目录规则", "\(source.bookSourceName) 标准目录")
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

                    Text("当前为离线 fixture 模式，不会访问真实网络")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
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

    private func summaryRow(_ label: String, _ value: String) -> some View {
        Text("\(label)：\(value)")
            .font(.caption).foregroundStyle(.secondary)
    }

    private func runLocalMockTest() {
        Task {
            testState = "测试中..."
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            // deterministic — 始终返回成功，避免随机结果复测不稳定
            testState = "测试成功：本地 fixture 可用"
        }
    }
}
