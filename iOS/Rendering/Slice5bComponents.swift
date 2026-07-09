import SwiftUI
import ReaderUIContract

// MARK: - Slice 5b Component Views（书源系列）
//
// 书源管理全链路的 18 个 component view。
// 真源：contracts/fixtures/view-state.fixtures.json 的 source-* RouteId
//
// 设计：
// - 大部分 source-* 子页：BackTopBar + 单一 Page view（BackTopBar 已在 Slice 2 注册）
// - source-switch / source-switch-results：仅 SourceSwitchFlowPage 单组件（无 BackTopBar）
// - SourceDebugResultPage 通过 variant 区分 catalog/detail/search
// - SourceRuleEditPage 通过 variant 区分 debug 模式
// - SourceDisabledState 无 fixture，contract 独立状态组件
// - 每个内容组件从 ViewStateComponent.props 解码为强类型 Props

// MARK: - 1. SourceDetailPage

struct SourceDetailPageView: View {
    let props: SourceDetailPageProps

    var body: some View {
        Form {
            Section("书源详情") {
                if let title = props.title {
                    LabeledRow(label: "名称", value: title)
                }
                Text("（Slice 5b 骨架占位）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - 2. SourceSwitchFlowPage

struct SourceSwitchFlowPageView: View {
    let props: SourceSwitchFlowPageProps

    var body: some View {
        VStack(spacing: ReaderDesignTokens.demoContentGap) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 36))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Text("换源")
                .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                .foregroundColor(ReaderDesignTokens.Color.ink)
            Text("（Slice 5b 骨架占位，后续 slice 接真实换源列表）")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - 3. SourceManagementPage

struct SourceManagementPageView: View {
    let props: SourceManagementPageProps

    var body: some View {
        Form {
            Section(props.title ?? "书源管理") {
                Text("（Slice 5b 骨架占位，后续 slice 接书源列表）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - 4. SourceImportOptionsPage

struct SourceImportOptionsPageView: View {
    let props: SourceImportOptionsPageProps

    var body: some View {
        Form {
            Section(props.title ?? "导入书源") {
                Text("从本地 / URL / OPML 导入（Slice 5b 占位）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - 5. SourceRuleEditPage

struct SourceRuleEditPageView: View {
    let props: SourceRuleEditPageProps

    var body: some View {
        Form {
            Section(props.title ?? "规则编辑") {
                if let variant = props.variant {
                    LabeledRow(label: "模式", value: variant)
                }
                Text("（Slice 5b 骨架占位，后续 slice 接规则编辑器）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - 6. SourceTestResultPage

struct SourceTestResultPageView: View {
    let props: SourceTestResultPageProps

    var body: some View {
        Form {
            Section(props.title ?? "测试结果") {
                Text("（Slice 5b 骨架占位）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - 7. SourceBatchPage

struct SourceBatchPageView: View {
    let props: SourceBatchPageProps

    var body: some View {
        Form {
            Section("批量管理") {
                Text("（Slice 5b 骨架占位）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - 8. SourceCodeViewPage

struct SourceCodeViewPageView: View {
    let props: SourceCodeViewPageProps

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
                Text("源码查看")
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .semibold))
                    .foregroundColor(ReaderDesignTokens.Color.ink)
                Text("（Slice 5b 骨架占位，后续 slice 接源码高亮显示）")
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - 9. SourceDebugPage

struct SourceDebugPageView: View {
    let props: SourceDebugPageProps

    var body: some View {
        Form {
            Section("书源调测") {
                Text("（Slice 5b 骨架占位，后续 slice 接调测入口）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - 10. SourceDebugResultPage

struct SourceDebugResultPageView: View {
    let props: SourceDebugResultPageProps

    var body: some View {
        Form {
            Section("调试结果") {
                if let variant = props.variant {
                    LabeledRow(label: "类型", value: variant)
                }
                Text("（Slice 5b 骨架占位）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - 11. SourceDebugContentLogPage

struct SourceDebugContentLogPageView: View {
    let props: SourceDebugContentLogPageProps

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
                Text("正文调试日志")
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .semibold))
                    .foregroundColor(ReaderDesignTokens.Color.ink)
                Text("（Slice 5b 骨架占位，后续 slice 接日志流）")
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - 12. SourceDebugRunningPage

struct SourceDebugRunningPageView: View {
    let props: SourceDebugRunningPageProps

    var body: some View {
        VStack(spacing: ReaderDesignTokens.demoContentGap) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("调试中…")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - 13. SourceDeleteConfirmPage

struct SourceDeleteConfirmPageView: View {
    let props: SourceDeleteConfirmPageProps

    var body: some View {
        VStack(spacing: ReaderDesignTokens.demoContentGap) {
            Image(systemName: "trash")
                .font(.system(size: 36))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Text("删除书源")
                .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .semibold))
                .foregroundColor(ReaderDesignTokens.Color.ink)
            Text("（Slice 5b 骨架占位，后续 slice 接确认对话框）")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - 14. SourceDetectPage

struct SourceDetectPageView: View {
    let props: SourceDetectPageProps

    var body: some View {
        Form {
            Section("书源检测") {
                Text("（Slice 5b 骨架占位，后续 slice 接批量检测）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - 15. SourceGroupsPage

struct SourceGroupsPageView: View {
    let props: SourceGroupsPageProps

    var body: some View {
        Form {
            Section("分组管理") {
                Text("（Slice 5b 骨架占位）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - 16. SourceImportPreviewPage

struct SourceImportPreviewPageView: View {
    let props: SourceImportPreviewPageProps

    var body: some View {
        Form {
            Section("导入书源") {
                Text("（Slice 5b 骨架占位，后续 slice 接预览列表）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - 17. SourceLogsPage

struct SourceLogsPageView: View {
    let props: SourceLogsPageProps

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
                Text("错误日志")
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .semibold))
                    .foregroundColor(ReaderDesignTokens.Color.ink)
                Text("（Slice 5b 骨架占位，后续 slice 接日志流）")
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - 18. SourceDisabledState

struct SourceDisabledStateView: View {
    let props: SourceDisabledStateProps

    var body: some View {
        VStack(spacing: ReaderDesignTokens.demoContentGap) {
            Image(systemName: "nosign")
                .font(.system(size: 36))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Text("书源已禁用")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Slice 5b Component Registration

extension ComponentRegistry {

    /// 注册 Slice 5b 的 18 个书源 component。
    /// 应在 App 启动时调用（如 ReaderApp.init），与 registerSlice2/3/4/5aComponents() 一起调用。
    public static func registerSlice5bComponents() {
        register([
            (.sourceDetailPage, { component in
                let props = SourceDetailPageProps(props: component.props) ?? SourceDetailPageProps(props: [:])!
                return AnyView(SourceDetailPageView(props: props))
            }),
            (.sourceSwitchFlowPage, { component in
                let props = SourceSwitchFlowPageProps(props: component.props) ?? SourceSwitchFlowPageProps(props: [:])!
                return AnyView(SourceSwitchFlowPageView(props: props))
            }),
            (.sourceManagementPage, { component in
                let props = SourceManagementPageProps(props: component.props) ?? SourceManagementPageProps(props: [:])!
                return AnyView(SourceManagementPageView(props: props))
            }),
            (.sourceImportOptionsPage, { component in
                let props = SourceImportOptionsPageProps(props: component.props) ?? SourceImportOptionsPageProps(props: [:])!
                return AnyView(SourceImportOptionsPageView(props: props))
            }),
            (.sourceRuleEditPage, { component in
                let props = SourceRuleEditPageProps(props: component.props) ?? SourceRuleEditPageProps(props: [:])!
                return AnyView(SourceRuleEditPageView(props: props))
            }),
            (.sourceTestResultPage, { component in
                let props = SourceTestResultPageProps(props: component.props) ?? SourceTestResultPageProps(props: [:])!
                return AnyView(SourceTestResultPageView(props: props))
            }),
            (.sourceBatchPage, { component in
                let props = SourceBatchPageProps(props: component.props) ?? SourceBatchPageProps(props: [:])!
                return AnyView(SourceBatchPageView(props: props))
            }),
            (.sourceCodeViewPage, { component in
                let props = SourceCodeViewPageProps(props: component.props) ?? SourceCodeViewPageProps(props: [:])!
                return AnyView(SourceCodeViewPageView(props: props))
            }),
            (.sourceDebugPage, { component in
                let props = SourceDebugPageProps(props: component.props) ?? SourceDebugPageProps(props: [:])!
                return AnyView(SourceDebugPageView(props: props))
            }),
            (.sourceDebugResultPage, { component in
                let props = SourceDebugResultPageProps(props: component.props) ?? SourceDebugResultPageProps(props: [:])!
                return AnyView(SourceDebugResultPageView(props: props))
            }),
            (.sourceDebugContentLogPage, { component in
                let props = SourceDebugContentLogPageProps(props: component.props) ?? SourceDebugContentLogPageProps(props: [:])!
                return AnyView(SourceDebugContentLogPageView(props: props))
            }),
            (.sourceDebugRunningPage, { component in
                let props = SourceDebugRunningPageProps(props: component.props) ?? SourceDebugRunningPageProps(props: [:])!
                return AnyView(SourceDebugRunningPageView(props: props))
            }),
            (.sourceDeleteConfirmPage, { component in
                let props = SourceDeleteConfirmPageProps(props: component.props) ?? SourceDeleteConfirmPageProps(props: [:])!
                return AnyView(SourceDeleteConfirmPageView(props: props))
            }),
            (.sourceDetectPage, { component in
                let props = SourceDetectPageProps(props: component.props) ?? SourceDetectPageProps(props: [:])!
                return AnyView(SourceDetectPageView(props: props))
            }),
            (.sourceGroupsPage, { component in
                let props = SourceGroupsPageProps(props: component.props) ?? SourceGroupsPageProps(props: [:])!
                return AnyView(SourceGroupsPageView(props: props))
            }),
            (.sourceImportPreviewPage, { component in
                let props = SourceImportPreviewPageProps(props: component.props) ?? SourceImportPreviewPageProps(props: [:])!
                return AnyView(SourceImportPreviewPageView(props: props))
            }),
            (.sourceLogsPage, { component in
                let props = SourceLogsPageProps(props: component.props) ?? SourceLogsPageProps(props: [:])!
                return AnyView(SourceLogsPageView(props: props))
            }),
            (.sourceDisabledState, { component in
                let props = SourceDisabledStateProps(props: component.props) ?? SourceDisabledStateProps(props: [:])!
                return AnyView(SourceDisabledStateView(props: props))
            }),
        ])
    }
}
