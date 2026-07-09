import SwiftUI

/// 对齐 web demo `contractStaticRouteScreen`（`render-runtime.js` line 7800）：
/// 静态合同信息页，用于 RouteId 已纳入 canonical demo 但平台实现待落地的路由。
/// 渲染 MainTabShell 顶栏 + 合同信息卡（icon/title/summary/rows/actions）。
struct ContractStaticRouteScreen: View {
    let route: String
    let title: String
    let shell: String
    let activeType: String
    let iconName: String
    let summary: String
    let rows: [(label: String, value: String)]
    let actions: [(label: String, route: String?)]

    init(
        route: String,
        title: String,
        shell: String = "MainTabShell",
        activeType: String = "bookshelf",
        iconName: String = "more",
        summary: String,
        rows: [(label: String, value: String)] = [
            ("RouteId", ""),
            ("Shell", ""),
            ("Source", "frontend-demo-optimized/route-contract.js"),
            ("Boundary", "静态 demo/handoff，不替代平台设备证据")
        ],
        actions: [(label: String, route: String?)] = []
    ) {
        self.route = route
        self.title = title
        self.shell = shell
        self.activeType = activeType
        self.iconName = iconName
        self.summary = summary
        // 填充 RouteId / Shell 默认值
        self.rows = rows.enumerated().map { (index, row) in
            var r = row
            if r.value.isEmpty {
                switch r.label {
                case "RouteId": r.value = route
                case "Shell": r.value = shell
                default: break
                }
            }
            return r
        }
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: 0) {
            DemoTopBar(title: title) {
                EmptyView()
            }

            DemoPaperScreen {
                contractStaticContent
            }
        }
        .background(ReaderDesignTokens.Color.paperSolidAlt.ignoresSafeArea())
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(.container, edges: .top)
#endif
    }

    private var contractStaticContent: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
            // icon + title
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: iconName == "more" ? "ellipsis.circle" : "info.circle")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .frame(width: 32, height: 32)

                Text(title)
                    .font(ReaderTypography.demoSerif(size: 22, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.ink)
            }

            // summary
            Text(summary)
                .font(.system(size: 14))
                .foregroundColor(ReaderDesignTokens.Color.muted)
                .fixedSize(horizontal: false, vertical: true)

            // contract info grid（对齐 .fd-reader-debug-grid）
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(rows.indices, id: \.self) { index in
                    let row = rows[index]
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.label)
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(ReaderDesignTokens.Color.muted)
                        Text(row.value)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(ReaderDesignTokens.Color.ink)
                    }
                    .padding(12)
                    .background(ReaderDesignTokens.Color.paperSolidAlt)
                    .cornerRadius(ReaderDesignTokens.Radius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm)
                            .stroke(ReaderDesignTokens.Color.muted.opacity(0.2), lineWidth: 1)
                    )
                }
            }

            // actions（对齐 .fd-action-row）
            if !actions.isEmpty {
                HStack(spacing: 12) {
                    ForEach(actions.indices, id: \.self) { index in
                        let action = actions[index]
                        Text(action.label)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(ReaderTokenAdapter.color(named: "--fd-ds-color-surface") ?? ReaderDesignTokens.Color.surface)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(ReaderDesignTokens.Color.primaryDark)
                            .cornerRadius(ReaderDesignTokens.Radius.pill)
                    }
                }
            }
        }
        .padding(ReaderDesignTokens.cardPadding)
        .background(ReaderDesignTokens.Color.paperSolidAlt)
        .cornerRadius(ReaderDesignTokens.Radius.lg)
    }
}
