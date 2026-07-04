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
        DemoBackScreen(title: "真实网络验证") {
            ReaderStateBanner(
                icon: statusIcon,
                title: "星星小说网 controlledOnline",
                messages: [status]
            )

            RealNetworkSection(title: "操作") {
                RealNetworkActionButton(
                    icon: .wifi,
                    title: "执行真实搜索（星星小说网）",
                    subtitle: "关键词：凡人，page=1",
                    isPrimary: true,
                    isDisabled: isRunning
                ) {
                    runVerify()
                }

                RealNetworkActionButton(
                    icon: .refresh,
                    title: "重置 Provider 为 Mock",
                    subtitle: "清空结果并恢复默认 mock 模式",
                    isPrimary: false,
                    isDisabled: isRunning
                ) {
                    ReaderCoreServiceProvider.shared.setMode(.mock)
                    status = "已重置为 mock"
                    results = []
                }
            }

            if isRunning {
                RealNetworkSection(title: "运行状态") {
                    HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                        // demo `.fd-discover-bottom-loading i`：14×14 旋转圆。
                        DemoLoadingSpinner(size: .inline)
                        Text("正在等待 ReaderCoreServiceProvider 返回结果")
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    }
                    .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
                    .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.settingsRowMinHeight, alignment: .leading)
                }
            }

            if !results.isEmpty {
                RealNetworkSection(title: "搜索结果 (\(results.count) 条)") {
                    ForEach(results, id: \.self) { r in
                        DemoIconRow(icon: .bookOpen, title: resultTitle(from: r), subtitle: r, detail: nil)
                    }
                }
            }

            RealNetworkSection(title: "说明") {
                DemoIconRow(
                    icon: .info,
                    title: "真实网络验证边界",
                    subtitle: "此工具通过 controlledOnline 模式对星星小说网执行真实搜索。Provider 默认仍为 mock，不影响正常使用。",
                    detail: nil
                )
            }
        }
    }

    private var statusIcon: ReaderAssetIcon {
        if status.contains("成功") { return .check }
        if status.contains("失败") { return .warning }
        if isRunning { return .wifi }
        return .info
    }

    private func resultTitle(from raw: String) -> String {
        raw.components(separatedBy: "|").first?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "搜索结果"
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

private struct RealNetworkSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                VStack(spacing: 0) {
                    content
                }
            }
        }
    }
}

private struct RealNetworkActionButton: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String
    let isPrimary: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(icon, size: 17, accessibilityLabel: title)
                    .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.settingsRowMinHeight, alignment: .leading)
            .foregroundColor(isPrimary ? .white : ReaderDesignTokens.Color.primaryDark)
            .background(
                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                    .fill(isPrimary ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.chipBackground)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

#endif
