import SwiftUI
import ReaderCoreModels

/// 书源详情 — fixture-only，不接真实网络
public struct BookSourceDetailView: View {
    let source: BookSource
    @State private var testState: String?

    public init(source: BookSource) {
        self.source = source
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 基本信息
                VStack(alignment: .leading, spacing: 8) {
                    Text("基本信息").font(.headline)
                    Divider()
                    detailRow("名称", source.bookSourceName)
                    if let group = source.bookSourceGroup {
                        detailRow("分组", group)
                    }
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
                    Text("搜索规则：\(source.bookSourceName) 标准搜索")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("详情规则：\(source.bookSourceName) 标准详情")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("目录规则：\(source.bookSourceName) 标准目录")
                        .font(.caption).foregroundStyle(.secondary)
                }

                // 操作
                VStack(spacing: 12) {
                    Button {
                        runLocalMockTest()
                    } label: {
                        HStack {
                            Image(systemName: "play.circle")
                            Text("本地模拟测试")
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
        .navigationTitle("书源详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.subheadline)
            Spacer()
        }
    }

    private func runLocalMockTest() {
        // 本地模拟测试 — 不触发真实网络
        Task {
            testState = "测试中..."
            try? await Task.sleep(nanoseconds: 800_000_000)
            testState = Bool.random() ? "测试成功（本地模拟）" : "⚠️ 测试失败（本地模拟）"
        }
    }
}
