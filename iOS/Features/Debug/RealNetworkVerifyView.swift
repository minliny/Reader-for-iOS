import SwiftUI
import ReaderShellValidation

#if DEBUG

/// 真实网络验证工具 — 对星星小说网执行 controlledOnline search
@MainActor
struct RealNetworkVerifyView: View {
    @State private var status = "就绪"
    @State private var results: [String] = []
    @State private var isRunning = false

    var body: some View {
        List {
            Section("状态") {
                Text(status).font(.subheadline)
                if isRunning { ProgressView() }
            }

            Section("操作") {
                Button("执行真实搜索（星星小说网）") {
                    runVerify()
                }
                .disabled(isRunning)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

                Button("重置 Provider 为 Mock") {
                    ReaderCoreServiceProvider.shared.setMode(.mock)
                    status = "已重置为 mock"
                    results = []
                }
                .disabled(isRunning)
            }

            if !results.isEmpty {
                Section("搜索结果 (\(results.count) 条)") {
                    ForEach(results, id: \.self) { r in
                        Text(r).font(.caption)
                    }
                }
            }

            Section("说明") {
                Text("此工具通过 controlledOnline 模式对星星小说网执行真实搜索。Provider 默认仍为 mock，不影响正常使用。")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("真实网络验证")
    }

    private func runVerify() {
        isRunning = true
        status = "正在创建服务..."
        results = []

        Task {
            let provider = ReaderCoreServiceProvider.shared

            // 1. 创建 real services
            let ready = provider.prepareControlledOnlineAllServices()
            guard ready else {
                status = "失败：无法创建 real services（NetworkAccessController denied）"
                isRunning = false
                return
            }

            // 2. 切换模式
            provider.enableControlledOnline()
            status = "正在搜索星星小说网..."

            // 3. 执行搜索
            let state = await provider.searchBooks(keyword: "凡人", page: 1)
            switch state {
            case .loaded(let items):
                status = "搜索成功！\(items.count) 条结果"
                results = items.map { "\($0.title) | \($0.author ?? "?") | \($0.detailURL)" }
            case .empty:
                status = "搜索返回空"
            case .failed(let err):
                status = "搜索失败：\(err.message)"
            default:
                status = "意外状态：\(state)"
            }

            isRunning = false
        }
    }
}

#endif
