import SwiftUI
import ReaderCoreModels

/// 书源详情 Sheet — NavigationStack 包裹，专用于 .sheet(item:) 展示
public struct BookSourceDetailSheet: View {
    let source: BookSource
    @State private var testState: String?

    public init(source: BookSource) {
        self.source = source
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("基本信息") {
                    LabeledContent("名称", value: source.bookSourceName)
                    if let group = source.bookSourceGroup {
                        LabeledContent("分组", value: group)
                    }
                    LabeledContent("URL", value: source.bookSourceUrl ?? "无")
                }

                Section("状态") {
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

                Section("规则摘要") {
                    Text("搜索规则：\(source.bookSourceName) 标准搜索")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("详情规则：\(source.bookSourceName) 标准详情")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("目录规则：\(source.bookSourceName) 标准目录")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section {
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
            .navigationTitle("书源详情")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func runLocalMockTest() {
        Task {
            testState = "测试中..."
            try? await Task.sleep(nanoseconds: 800_000_000)
            testState = Bool.random() ? "测试成功（本地模拟）" : "⚠️ 测试失败（本地模拟）"
        }
    }
}
