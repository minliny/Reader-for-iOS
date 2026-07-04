import SwiftUI
import ReaderCoreModels

struct RSSManagementSource: Hashable, Identifiable {
    enum Tone: String {
        case good
        case warn
        case muted
    }

    let id: String
    let name: String
    let group: String
    let unread: Int
    let latest: String
    let status: String
    let tone: Tone
    let enabled: Bool
    let categories: Int
    let articleStyle: String
    let rule: String
    let loginRequired: Bool
    let singleURL: Bool

    var sourceMeta: String {
        "\(group) · \(categories) 个入口 · \(articleStyle) · \(rule)"
    }

    var listMeta: String {
        "\(group) · \(unread > 0 ? "\(unread) 条未读" : "无未读") · \(latest) · \(articleStyle)"
    }

    static let demoSources: [RSSManagementSource] = [
        RSSManagementSource(
            id: "github-releases",
            name: "GitHub Releases",
            group: "开源项目",
            unread: 6,
            latest: "10:18",
            status: "正常",
            tone: .good,
            enabled: true,
            categories: 3,
            articleStyle: "列表",
            rule: "默认 RSS",
            loginRequired: false,
            singleURL: false
        ),
        RSSManagementSource(
            id: "reader-discussions",
            name: "阅读器版本讨论",
            group: "社区",
            unread: 12,
            latest: "09:42",
            status: "有更新",
            tone: .good,
            enabled: true,
            categories: 4,
            articleStyle: "图文",
            rule: "自定义列表",
            loginRequired: false,
            singleURL: false
        ),
        RSSManagementSource(
            id: "source-maintenance",
            name: "书源维护公告",
            group: "维护",
            unread: 2,
            latest: "昨天",
            status: "需登录",
            tone: .warn,
            enabled: true,
            categories: 2,
            articleStyle: "紧凑",
            rule: "正文规则",
            loginRequired: true,
            singleURL: false
        ),
        RSSManagementSource(
            id: "local-system",
            name: "本地系统通知",
            group: "系统",
            unread: 0,
            latest: "周二",
            status: "暂停",
            tone: .muted,
            enabled: false,
            categories: 1,
            articleStyle: "列表",
            rule: "单 URL",
            loginRequired: false,
            singleURL: true
        )
    ]

    static func from(_ sources: [RSSSource]) -> [RSSManagementSource] {
        sources.map { source in
            RSSManagementSource(
                id: source.url,
                name: source.name?.nonEmpty ?? source.url,
                group: source.sourceGroup?.nonEmpty ?? "未分组",
                unread: 0,
                latest: source.lastFetchedAt.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .short) } ?? "未刷新",
                status: source.enabled ? (source.loginUrl?.nonEmpty == nil ? "正常" : "需登录") : "暂停",
                tone: source.enabled ? (source.loginUrl?.nonEmpty == nil ? .good : .warn) : .muted,
                enabled: source.enabled,
                categories: source.sortUrl?.nonEmpty == nil ? 1 : 2,
                articleStyle: source.articleStyle == 0 ? "列表" : "图文",
                rule: source.ruleContent?.nonEmpty == nil ? (source.singleUrl ? "单 URL" : "默认 RSS") : "正文规则",
                loginRequired: source.loginUrl?.nonEmpty != nil,
                singleURL: source.singleUrl
            )
        }
    }

    static func fallback(sourceID: String, title: String?) -> RSSManagementSource {
        if let source = demoSources.first(where: { $0.id == sourceID || $0.name == title }) {
            return source
        }
        return RSSManagementSource(
            id: sourceID,
            name: title?.nonEmpty ?? "GitHub Releases",
            group: "RSS",
            unread: 0,
            latest: "未刷新",
            status: "正常",
            tone: .good,
            enabled: true,
            categories: 1,
            articleStyle: "列表",
            rule: "默认 RSS",
            loginRequired: false,
            singleURL: false
        )
    }
}

private enum RSSManagementRoute {
    case sourceActions(RSSManagementSource)
    case sourceEdit(RSSManagementSource)
    case sourceDebug(RSSManagementSource)
    case sourceVars(RSSManagementSource)
    case sourceLogin(RSSManagementSource)
    case sourceLoginWeb(RSSManagementSource)
    case sourceLoginCookie(RSSManagementSource)
    case sourceLoginClear(RSSManagementSource)
    case sourceGroups
    case sourceGroupEdit(groupID: String, title: String?)
    case sourceBatch
    case sourceExport
    case sourceExportDetail(sourceID: String, title: String)
    case sourceExportResult
    case sourceImport
    case sourceImportDetail(sourceID: String, title: String)
    case sourceImportResult
    case sourcePin(RSSManagementSource)
    case sourceDisable(RSSManagementSource)
    case sourceBatchDisable
    case ruleSubscription
    case readRecord(RSSManagementSource?)
}

private struct RSSManagementNavigateKey: EnvironmentKey {
    static let defaultValue: (RSSManagementRoute) -> Void = { _ in }
}

private struct RSSManagementPopKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

private extension EnvironmentValues {
    var rssManagementNavigate: (RSSManagementRoute) -> Void {
        get { self[RSSManagementNavigateKey.self] }
        set { self[RSSManagementNavigateKey.self] = newValue }
    }

    var rssManagementPop: () -> Void {
        get { self[RSSManagementPopKey.self] }
        set { self[RSSManagementPopKey.self] = newValue }
    }
}

private struct RSSManagementRouteHost<Root: View>: View {
    @State private var routeStack: [RSSManagementRoute] = []
    @SwiftUI.Environment(\.dismiss) private var dismiss
    let onRootExit: (() -> Void)?
    let root: Root

    init(onRootExit: (() -> Void)?, @ViewBuilder root: () -> Root) {
        self.onRootExit = onRootExit
        self.root = root()
    }

    var body: some View {
        ZStack {
            if let route = routeStack.last {
                routeView(for: route)
            } else {
                root
            }
        }
        .environment(\.rssManagementNavigate, { route in
            routeStack.append(route)
        })
        .environment(\.rssManagementPop, closeTopRoute)
    }

    @ViewBuilder
    private func routeView(for route: RSSManagementRoute) -> some View {
        switch route {
        case .sourceActions(let source):
            RSSSourceActionsView(source: source)
        case .sourceEdit(let source):
            RSSSourceEditView(source: source)
        case .sourceDebug(let source):
            RSSSourceDebugView(source: source)
        case .sourceVars(let source):
            RSSSourceVarsView(source: source)
        case .sourceLogin(let source):
            RSSSourceLoginView(source: source)
        case .sourceLoginWeb(let source):
            RSSSourceLoginWebView(source: source)
        case .sourceLoginCookie(let source):
            RSSSourceLoginCookieView(source: source)
        case .sourceLoginClear(let source):
            RSSSourceLoginClearView(source: source)
        case .sourceGroups:
            RSSSourceGroupsView()
        case .sourceGroupEdit(let groupID, let title):
            RSSSourceGroupEditView(groupID: groupID, title: title)
        case .sourceBatch:
            RSSSourceBatchView()
        case .sourceExport:
            RSSSourceExportView()
        case .sourceExportDetail(let sourceID, let title):
            RSSSourceExportDetailView(sourceID: sourceID, title: title)
        case .sourceExportResult:
            RSSSourceExportResultView()
        case .sourceImport:
            RSSSourceImportView()
        case .sourceImportDetail(let sourceID, let title):
            RSSSourceImportDetailView(sourceID: sourceID, title: title)
        case .sourceImportResult:
            RSSSourceImportResultView()
        case .sourcePin(let source):
            RSSSourcePinConfirmView(source: source)
        case .sourceDisable(let source):
            RSSSourceDisableConfirmView(source: source)
        case .sourceBatchDisable:
            RSSSourceBatchDisableConfirmView()
        case .ruleSubscription:
            RSSRuleSubscriptionView(onExit: closeTopRoute)
        case .readRecord(let source):
            RSSReadRecordView(source: source, onExit: closeTopRoute)
        }
    }

    private func closeTopRoute() {
        if routeStack.isEmpty {
            if let onRootExit {
                onRootExit()
            } else {
                dismiss()
            }
        } else {
            routeStack.removeLast()
        }
    }
}

private struct RSSManagementRouteButton<Label: View>: View {
    let route: RSSManagementRoute
    let label: Label
    @SwiftUI.Environment(\.rssManagementNavigate) private var navigate

    init(route: RSSManagementRoute, @ViewBuilder label: () -> Label) {
        self.route = route
        self.label = label()
    }

    var body: some View {
        Button {
            navigate(route)
        } label: {
            label
        }
        .buttonStyle(.plain)
    }
}

struct RSSSubscriptionManagementView: View {
    private let sources: [RSSManagementSource]
    private let onExit: (() -> Void)?
    @State private var selectedFilter = "全部"
    @State private var autoRefreshEnabled = true
    @State private var unreadReminderEnabled = true

    init(sources: [RSSSource] = [], onExit: (() -> Void)? = nil) {
        let mapped = RSSManagementSource.from(sources)
        self.sources = mapped.isEmpty ? RSSManagementSource.demoSources : mapped
        self.onExit = onExit
    }

    init(managementSources: [RSSManagementSource], onExit: (() -> Void)? = nil) {
        self.sources = managementSources.isEmpty ? RSSManagementSource.demoSources : managementSources
        self.onExit = onExit
    }

    var body: some View {
        RSSManagementRouteHost(onRootExit: onExit) {
            DemoBackScreen(title: "RSS 订阅管理", onBack: onExit) {
                RSSManageActionsRow()
                RSSManageFilterRow(selectedFilter: $selectedFilter)
                RSSSourceList(sources: filteredSources)
                RSSManageBatchRow(selectedCount: min(2, filteredSources.count))
                RSSSourceSettingsPanel(
                    autoRefreshEnabled: $autoRefreshEnabled,
                    unreadReminderEnabled: $unreadReminderEnabled
                )
            }
        }
    }

    private var filteredSources: [RSSManagementSource] {
        switch selectedFilter {
        case "已启用":
            return sources.filter(\.enabled)
        case "需登录":
            return sources.filter(\.loginRequired)
        case "无分组":
            return sources.filter { $0.group == "未分组" || $0.group.isEmpty }
        case "暂停":
            return sources.filter { !$0.enabled }
        default:
            return sources
        }
    }
}

struct RSSSourceActionsView: View {
    let source: RSSManagementSource
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    init(source: RSSManagementSource = RSSManagementSource.demoSources[0]) {
        self.source = source
    }

    init(sourceID: String, title: String? = nil) {
        self.source = RSSManagementSource.fallback(sourceID: sourceID, title: title)
    }

    var body: some View {
        DemoBackScreen(title: "源操作") {
            RSSActionSourceCard(source: source)
            RSSActionGrid(source: source)
        } bottomActionHost: {
            BottomFixedActionRow {
                RSSSourceActionBottomButton(title: "返回源", isPrimary: false) {
                    dismiss()
                }
            } trailing: {
                RSSSourceActionBottomButton(title: "管理全部", isPrimary: true) {
                    dismiss()
                }
            }
        }
    }
}

struct RSSSourceEditView: View {
    let source: RSSManagementSource
    @State private var selectedGroup = "基础"
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    init(source: RSSManagementSource = RSSManagementSource.demoSources[0]) {
        self.source = source
    }

    init(sourceID: String, title: String? = nil) {
        self.source = RSSManagementSource.fallback(sourceID: sourceID, title: title)
    }

    var body: some View {
        DemoBackScreen(title: "RSS 源编辑") {
            RSSSourceEditTabs(selectedGroup: $selectedGroup)
            RSSEditFieldList(fields: fields)
        } bottomActionHost: {
            BottomFixedActionRow {
                RSSManagementRouteButton(route: .sourceDebug(source)) {
                    RSSSourceActionBottomLabel(title: "调试规则", isPrimary: false)
                }
            } trailing: {
                RSSSourceActionBottomButton(title: "保存", isPrimary: true) {
                    dismiss()
                }
            }
        }
    }

    private var fields: [RSSEditField] {
        [
            RSSEditField(group: "基础", label: "源名称", value: source.name),
            RSSEditField(group: "基础", label: "源地址", value: source.id.hasPrefix("http") ? source.id : "https://github.com/minliny/Reader-UI/releases.atom"),
            RSSEditField(group: "基础", label: "分组", value: source.group),
            RSSEditField(group: "基础", label: "分类 URL", value: source.categories > 1 ? "Releases::/releases.atom && Issues::/issues.atom" : "默认入口"),
            RSSEditField(group: "请求", label: "请求头", value: "User-Agent: Reader UI"),
            RSSEditField(group: "请求", label: "并发率", value: "2/1000"),
            RSSEditField(group: "列表", label: "文章列表", value: source.rule),
            RSSEditField(group: "列表", label: "下一页", value: "PAGE"),
            RSSEditField(group: "列表", label: "标题 / 时间 / 链接", value: "title / pubDate / link"),
            RSSEditField(group: "WebView", label: "正文规则", value: source.rule == "正文规则" ? "content:encoded || article" : "content:encoded"),
            RSSEditField(group: "WebView", label: "注入 JS / CSS", value: "图片宽度、夜间样式、跳转拦截"),
            RSSEditField(group: "WebView", label: "白名单 / 黑名单", value: "过滤广告资源")
        ].filter { selectedGroup == "全部" || $0.group == selectedGroup }
    }
}

struct RSSSourceDebugView: View {
    let source: RSSManagementSource
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    init(source: RSSManagementSource = RSSManagementSource.demoSources[0]) {
        self.source = source
    }

    init(sourceID: String, title: String? = nil) {
        self.source = RSSManagementSource.fallback(sourceID: sourceID, title: title)
    }

    var body: some View {
        DemoBackScreen(title: "规则调试") {
            RSSDebugPanel(source: source)
        } bottomActionHost: {
            BottomFixedActionRow {
                RSSManagementRouteButton(route: .sourceEdit(source)) {
                    RSSSourceActionBottomLabel(title: "编辑规则", isPrimary: false)
                }
            } trailing: {
                RSSSourceActionBottomButton(title: "完成", isPrimary: true) {
                    dismiss()
                }
            }
        }
    }
}

struct RSSSourceVarsView: View {
    let source: RSSManagementSource
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    init(source: RSSManagementSource = RSSManagementSource.demoSources[0]) {
        self.source = source
    }

    init(sourceID: String, title: String? = nil) {
        self.source = RSSManagementSource.fallback(sourceID: sourceID, title: title)
    }

    var body: some View {
        DemoBackScreen(title: "源变量") {
            RSSSourceHeaderPanel(
                icon: .code,
                title: source.name,
                subtitle: "变量作用于请求头、分类 URL、正文规则和 WebView 注入脚本"
            )
            RSSEditFieldList(fields: variables)
        } bottomActionHost: {
            BottomFixedActionRow {
                RSSManagementRouteButton(route: .sourceDebug(source)) {
                    RSSSourceActionBottomLabel(title: "测试变量", isPrimary: false)
                }
            } trailing: {
                RSSSourceActionBottomButton(title: "完成", isPrimary: true) {
                    dismiss()
                }
            }
        }
    }

    private var variables: [RSSEditField] {
        [
            RSSEditField(group: "请求变量", label: "{{page}}", value: "当前分页，从 1 开始递增，用于列表和下一页规则。"),
            RSSEditField(group: "请求变量", label: "{{sourceUrl}}", value: "当前订阅源地址，调试和跳转拦截时可引用。"),
            RSSEditField(group: "登录变量", label: "{{cookie}}", value: "网页登录后写入，刷新订阅源和打开原文时共用。"),
            RSSEditField(group: "登录变量", label: "{{token}}", value: "从登录页脚本提取，过期后进入登录子页面刷新。"),
            RSSEditField(group: "设备变量", label: "{{userAgent}}", value: "Reader UI WebView UA，必要时覆盖为移动端 UA。")
        ]
    }
}

struct RSSSourceLoginView: View {
    let source: RSSManagementSource
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    init(source: RSSManagementSource = RSSManagementSource.demoSources[2]) {
        self.source = source
    }

    init(sourceID: String, title: String? = nil) {
        self.source = RSSManagementSource.fallback(sourceID: sourceID, title: title)
    }

    var body: some View {
        DemoBackScreen(title: "源登录") {
            RSSSourceInfoPanel(
                icon: .shield,
                title: source.name,
                subtitle: "网页登录 · Cookie 保存 · 登录态检测",
                rows: loginRows
            )
            RSSLoginActionGrid(source: source)
        } bottomActionHost: {
            BottomFixedActionRow {
                RSSSourceActionBottomButton(title: "返回操作", isPrimary: false) {
                    dismiss()
                }
            } trailing: {
                RSSSourceActionBottomButton(title: "完成", isPrimary: true) {
                    dismiss()
                }
            }
        }
    }

    private var loginRows: [RSSDebugRowModel] {
        [
            RSSDebugRowModel(title: "登录地址", body: "https://example.com/login?from=rss", isWarning: false),
            RSSDebugRowModel(title: "Cookie 状态", body: source.loginRequired ? "reader_session=•••••• · 2 天后过期 · 已关联当前订阅源" : "当前源未要求登录，可在需要时保存 Cookie。", isWarning: false),
            RSSDebugRowModel(title: "检测方式", body: "刷新前请求个人中心，401/403 时提示重新登录。", isWarning: false)
        ]
    }
}

struct RSSSourceLoginWebView: View {
    let source: RSSManagementSource

    init(source: RSSManagementSource = RSSManagementSource.demoSources[2]) {
        self.source = source
    }

    init(sourceID: String, title: String? = nil) {
        self.source = RSSManagementSource.fallback(sourceID: sourceID, title: title)
    }

    var body: some View {
        DemoBackScreen(title: "网页登录") {
            RSSSourceHeaderPanel(
                icon: .shield,
                title: "example.com/login",
                subtitle: "来自 \(source.name) · 登录完成后回写 Cookie"
            )
            RSSLoginWebPreview()
        } bottomActionHost: {
            BottomFixedActionRow {
                RSSManagementRouteButton(route: .sourceLogin(source)) {
                    RSSSourceActionBottomLabel(title: "返回登录", isPrimary: false)
                }
            } trailing: {
                RSSManagementRouteButton(route: .sourceLoginCookie(source)) {
                    RSSSourceActionBottomLabel(title: "登录完成", isPrimary: true)
                }
            }
        }
    }
}

struct RSSSourceLoginCookieView: View {
    let source: RSSManagementSource
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    init(source: RSSManagementSource = RSSManagementSource.demoSources[2]) {
        self.source = source
    }

    init(sourceID: String, title: String? = nil) {
        self.source = RSSManagementSource.fallback(sourceID: sourceID, title: title)
    }

    var body: some View {
        DemoBackScreen(title: "Cookie 提取") {
            RSSSourceInfoPanel(
                icon: .file,
                title: "已提取登录凭据",
                subtitle: "只作用于当前 RSS 源，不覆盖其他订阅源",
                rows: credentialRows
            )
        } bottomActionHost: {
            BottomFixedActionRow {
                RSSManagementRouteButton(route: .sourceLogin(source)) {
                    RSSSourceActionBottomLabel(title: "返回", isPrimary: false)
                }
            } trailing: {
                RSSSourceActionBottomButton(title: "保存凭据", isPrimary: true) {
                    dismiss()
                }
            }
        }
    }

    private var credentialRows: [RSSDebugRowModel] {
        [
            RSSDebugRowModel(title: "Cookie", body: "reader_session=••••••; expires=2026-06-28; path=/", isWarning: false),
            RSSDebugRowModel(title: "Token", body: "从 localStorage.reader_token 提取，刷新源时自动附加。", isWarning: false),
            RSSDebugRowModel(title: "检测结果", body: "个人中心返回 200，下一次刷新不会进入登录错误状态。", isWarning: false)
        ]
    }
}

struct RSSSourceLoginClearView: View {
    let source: RSSManagementSource
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    init(source: RSSManagementSource = RSSManagementSource.demoSources[2]) {
        self.source = source
    }

    init(sourceID: String, title: String? = nil) {
        self.source = RSSManagementSource.fallback(sourceID: sourceID, title: title)
    }

    var body: some View {
        DemoBackScreen(title: "清除登录") {
            RSSSourceConfirmCard(
                icon: .trash,
                heading: "清除当前源登录信息？",
                copy: "清除后该 RSS 源下次刷新会重新进入登录流程，不影响其他订阅源和已缓存文章。",
                detail: source.name
            )
        } bottomActionHost: {
            BottomFixedActionRow {
                RSSManagementRouteButton(route: .sourceLogin(source)) {
                    RSSSourceActionBottomLabel(title: "取消", isPrimary: false)
                }
            } trailing: {
                RSSSourceActionBottomButton(title: "确认清除", isPrimary: true) {
                    dismiss()
                }
            }
        }
    }
}

struct RSSSourceGroupsView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    var body: some View {
        DemoBackScreen(title: "RSS 分组") {
            RSSManagementIconList(rows: RSSManagementIconRow.groupRows)
            RSSInlineActionWrap {
                RSSManagementRouteButton(route: .sourceGroupEdit(groupID: "open-source", title: "开源项目")) {
                    RSSInlineActionLabel(icon: .add, title: "新增分组")
                }

                RSSManagementRouteButton(route: .sourceGroupEdit(groupID: "open-source", title: "开源项目")) {
                    RSSInlineActionLabel(icon: .edit, title: "重命名")
                }
            }
        } bottomActionHost: {
            BottomFixedActionRow {
                RSSSourceActionBottomButton(title: "取消", isPrimary: false) {
                    dismiss()
                }
            } trailing: {
                RSSSourceActionBottomButton(title: "保存", isPrimary: true) {
                    dismiss()
                }
            }
        }
    }
}

struct RSSSourceGroupEditView: View {
    private let groupID: String
    private let title: String?
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    init(groupID: String = "open-source", title: String? = "开源项目") {
        self.groupID = groupID
        self.title = title
    }

    var body: some View {
        DemoBackScreen(title: "编辑 RSS 分组") {
            RSSEditFieldList(fields: fields)
        } bottomActionHost: {
            BottomFixedActionRow {
                RSSManagementRouteButton(route: .sourceGroups) {
                    RSSSourceActionBottomLabel(title: "取消", isPrimary: false)
                }
            } trailing: {
                RSSSourceActionBottomButton(title: "保存", isPrimary: true) {
                    dismiss()
                }
            }
        }
    }

    private var fields: [RSSEditField] {
        [
            RSSEditField(group: "分组配置", label: "分组名称", value: title?.nonEmpty ?? groupID),
            RSSEditField(group: "分组配置", label: "默认展开", value: "开启"),
            RSSEditField(group: "分组配置", label: "排序规则", value: "未读优先，其次最近更新"),
            RSSEditField(group: "分组配置", label: "适用订阅源", value: "GitHub Releases、社区 RSS 源合集")
        ]
    }
}

struct RSSSourceBatchView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    var body: some View {
        DemoBackScreen(title: "批量管理") {
            RSSBatchSummaryRow()
            RSSManagementIconList(rows: RSSManagementIconRow.batchRows)
        } bottomActionHost: {
            BottomFixedActionRow {
                RSSManagementRouteButton(route: .sourceExport) {
                    RSSSourceActionBottomLabel(title: "导出", isPrimary: false)
                }
            } trailing: {
                RSSManagementRouteButton(route: .sourceBatchDisable) {
                    RSSSourceActionBottomLabel(title: "禁用", isPrimary: true)
                }
            }
        }
    }
}

struct RSSSourceExportView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    var body: some View {
        DemoBackScreen(title: "导出订阅源") {
            RSSImportOptionPanel(
                icon: .download,
                label: "reader-rss-sources-20260626.json",
                options: [
                    RSSOptionChip(title: "已选源", isActive: true),
                    RSSOptionChip(title: "启用源", isActive: true),
                    RSSOptionChip(title: "包含登录配置", isActive: false),
                    RSSOptionChip(title: "包含分组", isActive: true)
                ]
            )
            RSSImportExportList(rows: RSSImportExportRow.exportRows, actionTitle: "预览")
        } bottomActionHost: {
            BottomFixedActionRow {
                RSSManagementRouteButton(route: .sourceBatch) {
                    RSSSourceActionBottomLabel(title: "返回", isPrimary: false)
                }
            } trailing: {
                RSSManagementRouteButton(route: .sourceExportResult) {
                    RSSSourceActionBottomLabel(title: "导出", isPrimary: true)
                }
            }
        }
    }
}

struct RSSSourceExportDetailView: View {
    private let source: RSSManagementSource

    init(source: RSSManagementSource = RSSManagementSource.demoSources[0]) {
        self.source = source
    }

    init(sourceID: String, title: String? = nil) {
        self.source = RSSManagementSource.fallback(sourceID: sourceID, title: title)
    }

    var body: some View {
        DemoBackScreen(title: "导出预览") {
            RSSSourceInfoPanel(
                icon: .download,
                title: source.name,
                subtitle: "导出项预览 · 不包含 Cookie",
                rows: [
                    RSSDebugRowModel(title: "基础字段", body: "名称、源地址、分组、启用状态、分类入口。", isWarning: false),
                    RSSDebugRowModel(title: "解析规则", body: "列表、下一页、正文、WebView 注入脚本和资源过滤规则。", isWarning: false),
                    RSSDebugRowModel(title: "安全字段", body: "登录 Cookie、Token 和本地账号信息不参与导出。", isWarning: false)
                ]
            )
        } bottomActionHost: {
            BottomFixedActionRow {
                RSSManagementRouteButton(route: .sourceExport) {
                    RSSSourceActionBottomLabel(title: "返回", isPrimary: false)
                }
            } trailing: {
                RSSManagementRouteButton(route: .sourceExportResult) {
                    RSSSourceActionBottomLabel(title: "导出此源", isPrimary: true)
                }
            }
        }
    }
}

struct RSSSourceExportResultView: View {
    var body: some View {
        RSSSourceConfirmationPage(
            title: "导出完成",
            icon: .check,
            heading: "已生成导出文件",
            copy: "reader-rss-sources-20260626.json 已生成，包含已选订阅源、分组、启用状态和规则配置。",
            detail: "登录 Cookie 和账号凭据没有写入导出文件。",
            cancelTitle: "返回导出",
            cancelDestination: { RSSSourceExportView() },
            confirmTitle: "完成"
        )
    }
}

struct RSSSourceImportView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    var body: some View {
        DemoBackScreen(title: "导入订阅源") {
            RSSImportOptionPanel(
                icon: .link,
                label: "https://example.com/rss-source.json",
                options: [
                    RSSOptionChip(title: "保留名称", isActive: true),
                    RSSOptionChip(title: "保留分组", isActive: true),
                    RSSOptionChip(title: "保留启用状态", isActive: true),
                    RSSOptionChip(title: "加入分组", isActive: false)
                ]
            )
            RSSImportExportList(rows: RSSImportExportRow.importRows, actionTitle: nil)
        } bottomActionHost: {
            BottomFixedActionRow {
                RSSSourceActionBottomButton(title: "取消", isPrimary: false) {
                    dismiss()
                }
            } trailing: {
                RSSManagementRouteButton(route: .sourceImportResult) {
                    RSSSourceActionBottomLabel(title: "导入 2 个", isPrimary: true)
                }
            }
        }
    }
}

struct RSSSourceImportDetailView: View {
    private let source: RSSManagementSource

    init(source: RSSManagementSource = RSSManagementSource.demoSources[2]) {
        self.source = source
    }

    init(sourceID: String, title: String? = nil) {
        self.source = RSSManagementSource.fallback(sourceID: sourceID, title: title)
    }

    var body: some View {
        DemoBackScreen(title: "导入详情") {
            RSSSourceInfoPanel(
                icon: .upload,
                title: source.name,
                subtitle: "更新 · 规则版本更高 · 需登录",
                rows: [
                    RSSDebugRowModel(title: "变更摘要", body: "正文规则从 content:encoded 改为 article.content，新增登录检测 URL。", isWarning: false),
                    RSSDebugRowModel(title: "冲突处理", body: "保留本地名称和分组，覆盖规则、请求头和分类入口。", isWarning: false),
                    RSSDebugRowModel(title: "登录态", body: "不导入 Cookie。更新后需要在源登录页重新授权。", isWarning: true)
                ]
            )
        } bottomActionHost: {
            BottomFixedActionRow {
                RSSManagementRouteButton(route: .sourceImport) {
                    RSSSourceActionBottomLabel(title: "返回", isPrimary: false)
                }
            } trailing: {
                RSSManagementRouteButton(route: .sourceImport) {
                    RSSSourceActionBottomLabel(title: "加入导入", isPrimary: true)
                }
            }
        }
    }
}

struct RSSSourceImportResultView: View {
    var body: some View {
        RSSSourceConfirmationPage(
            title: "导入完成",
            icon: .check,
            heading: "已导入 2 个订阅源",
            copy: "新增源已加入 RSS 订阅管理，冲突源保留本地名称、分组和启用状态。",
            detail: "需要登录的源不会自动导入 Cookie。",
            cancelTitle: "继续导入",
            cancelDestination: { RSSSourceImportView() },
            confirmTitle: "完成"
        )
    }
}

struct RSSSourcePinConfirmView: View {
    private let source: RSSManagementSource

    init(source: RSSManagementSource = RSSManagementSource.demoSources[0]) {
        self.source = source
    }

    init(sourceID: String, title: String? = nil) {
        self.source = RSSManagementSource.fallback(sourceID: sourceID, title: title)
    }

    var body: some View {
        RSSSourceConfirmationPage(
            title: "置顶订阅源",
            icon: .top,
            heading: "置顶 \(source.name)？",
            copy: "置顶后该订阅源会显示在源列表和快捷入口最前面，不影响刷新规则和分组。",
            detail: "适合高频阅读的发布源、公告源或需要优先查看的订阅源。",
            cancelTitle: "取消",
            cancelDestination: { RSSSourceActionsView(source: source) },
            confirmTitle: "确认置顶"
        )
    }
}

struct RSSSourceDisableConfirmView: View {
    private let source: RSSManagementSource

    init(source: RSSManagementSource = RSSManagementSource.demoSources[0]) {
        self.source = source
    }

    init(sourceID: String, title: String? = nil) {
        self.source = RSSManagementSource.fallback(sourceID: sourceID, title: title)
    }

    var body: some View {
        RSSSourceConfirmationPage(
            title: "禁用订阅源",
            icon: .offline,
            heading: "禁用已选订阅源？",
            copy: "禁用后不会参与自动刷新、未读提醒和 RSS 首页统计，已缓存条目和阅读记录会保留。",
            detail: "可以在订阅管理页重新启用。",
            cancelTitle: "取消",
            cancelDestination: { RSSSourceActionsView(source: source) },
            confirmTitle: "确认禁用"
        )
    }
}

struct RSSSourceBatchDisableConfirmView: View {
    var body: some View {
        RSSSourceConfirmationPage(
            title: "批量禁用",
            icon: .offline,
            heading: "禁用已选 2 个订阅源？",
            copy: "禁用后这些订阅源不会参与自动刷新、未读提醒和首页统计，已缓存条目和阅读记录会保留。",
            detail: "已选：GitHub Releases、阅读器版本讨论",
            cancelTitle: "返回批量",
            cancelDestination: { RSSSourceBatchView() },
            confirmTitle: "确认禁用"
        )
    }
}

private struct RSSManageActionsRow: View {
    private let actions: [(title: String, icon: ReaderAssetIcon)] = [
        ("新建", .add),
        ("导入", .upload),
        ("规则订阅", .sync),
        ("分组", .folder)
    ]

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: ReaderDesignTokens.rssManageActionGridGap), count: 4),
            spacing: ReaderDesignTokens.rssManageActionGridGap
        ) {
            ForEach(actions, id: \.title) { action in
                switch action.title {
                case "新建":
                    RSSManagementRouteButton(route: .sourceEdit(RSSManagementSource.demoSources[0])) {
                        RSSManageActionLabel(title: action.title, icon: action.icon)
                    }
                case "导入":
                    RSSManagementRouteButton(route: .sourceImport) {
                        RSSManageActionLabel(title: action.title, icon: action.icon)
                    }
                case "规则订阅":
                    RSSManagementRouteButton(route: .ruleSubscription) {
                        RSSManageActionLabel(title: action.title, icon: action.icon)
                    }
                case "分组":
                    RSSManagementRouteButton(route: .sourceGroups) {
                        RSSManageActionLabel(title: action.title, icon: action.icon)
                    }
                default:
                    Button {} label: {
                        RSSManageActionLabel(title: action.title, icon: action.icon)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct RSSManageActionLabel: View {
    let title: String
    let icon: ReaderAssetIcon

    var body: some View {
        HStack(spacing: 5) {
            ReaderIcon(icon, size: 14)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: .black))
        .foregroundColor(title == "新建" ? .white : ReaderDesignTokens.readerModuleTextColor)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssManageActionButtonMinHeight)
        .background(
            Capsule()
                .fill(title == "新建" ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.chipBackground)
        )
    }
}

private struct RSSManagementIconRow: Hashable {
    let title: String
    let meta: String
    let icon: ReaderAssetIcon
    let isSelected: Bool
    let isEnabled: Bool
    let tone: RSSManagementSource.Tone?

    static let groupRows: [RSSManagementIconRow] = [
        RSSManagementIconRow(title: "开源项目", meta: "2 个订阅源 · 默认展开", icon: .folder, isSelected: true, isEnabled: true, tone: nil),
        RSSManagementIconRow(title: "社区", meta: "1 个订阅源 · 有 12 条未读", icon: .folder, isSelected: true, isEnabled: true, tone: nil),
        RSSManagementIconRow(title: "维护", meta: "1 个订阅源 · 需要登录", icon: .folder, isSelected: true, isEnabled: true, tone: nil),
        RSSManagementIconRow(title: "系统", meta: "1 个订阅源 · 已暂停", icon: .folder, isSelected: false, isEnabled: false, tone: nil)
    ]

    static let batchRows: [RSSManagementIconRow] = RSSManagementSource.demoSources.enumerated().map { index, source in
        RSSManagementIconRow(
            title: source.name,
            meta: "\(source.group) · \(source.status) · \(source.unread > 0 ? "\(source.unread) 条未读" : "无未读")",
            icon: index < 2 ? .check : (source.enabled ? .rss : .offline),
            isSelected: index < 2,
            isEnabled: source.enabled,
            tone: source.enabled ? .good : .muted
        )
    }
}

private struct RSSManagementIconList: View {
    let rows: [RSSManagementIconRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element) { index, row in
                HStack(spacing: 8) {
                    ReaderIcon(row.icon, size: 15, accessibilityLabel: row.title)
                        .frame(
                            width: ReaderDesignTokens.rssImportListIconSize,
                            height: ReaderDesignTokens.rssImportListIconSize
                        )
                        .background(Circle().fill(row.isSelected ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.primary.opacity(0.10)))
                        .foregroundColor(row.isSelected ? .white : ReaderDesignTokens.Color.primaryDark)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                            .lineLimit(1)
                        Text(row.meta)
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let tone = row.tone {
                        RSSStatusBadge(tone: tone)
                    } else {
                        RSSStaticSwitch(isOn: row.isEnabled)
                    }
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .frame(minHeight: ReaderDesignTokens.rssManagementListRowMinHeight)
                .opacity(row.isEnabled ? 1 : 0.62)

                if index < rows.count - 1 {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                }
            }
        }
        .backgroundCard(cornerRadius: ReaderDesignTokens.Radius.md)
    }
}

private struct RSSStaticSwitch: View {
    let isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.chipBackground)
                .frame(width: ReaderDesignTokens.settingsSwitchTrackWidth, height: ReaderDesignTokens.settingsSwitchTrackHeight)
            Circle()
                .fill(.white)
                .frame(width: ReaderDesignTokens.settingsSwitchThumbSize, height: ReaderDesignTokens.settingsSwitchThumbSize)
                .padding(2)
        }
        .accessibilityHidden(true)
    }
}

private struct RSSInlineActionWrap<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 6) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RSSInlineActionLabel: View {
    let icon: ReaderAssetIcon
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            ReaderIcon(icon, size: 13)
            Text(title)
                .lineLimit(1)
        }
        .font(.system(size: ReaderDesignTokens.rssArticleRowBodyFontSize, weight: .black))
        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        .padding(.horizontal, 8)
        .frame(minHeight: ReaderDesignTokens.rssImportListActionMinHeight)
        .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
    }
}

private struct RSSBatchSummaryRow: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("已选 2 个订阅源")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: .black))
                .foregroundColor(ReaderDesignTokens.Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(["反选", "全选"], id: \.self) { title in
                Text(title)
                    .font(.system(size: ReaderDesignTokens.rssArticleRowBodyFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .padding(.horizontal, 8)
                    .frame(minHeight: ReaderDesignTokens.rssImportListActionMinHeight)
                    .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: ReaderDesignTokens.rssManageBatchRowMinHeight)
        .backgroundCard(cornerRadius: ReaderDesignTokens.Radius.md)
    }
}

private struct RSSOptionChip: Hashable {
    let title: String
    let isActive: Bool
}

private struct RSSImportOptionPanel: View {
    let icon: ReaderAssetIcon
    let label: String
    let options: [RSSOptionChip]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ReaderIcon(icon, size: 14)
                    .frame(width: 22)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                Text(label)
                    .font(.system(size: ReaderDesignTokens.chipFontSize, weight: .semibold))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssImportPanelLabelMinHeight, alignment: .leading)
            .background(Capsule().fill(ReaderDesignTokens.Color.chipBackground.opacity(0.72)))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(options, id: \.self) { option in
                    Text(option.title)
                        .font(.system(size: ReaderDesignTokens.rssArticleRowBodyFontSize, weight: .black))
                        .foregroundColor(option.isActive ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.ink)
                        .padding(.horizontal, 8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(minHeight: ReaderDesignTokens.rssImportListActionMinHeight)
                        .background(Capsule().fill(option.isActive ? ReaderDesignTokens.Color.primary.opacity(0.10) : ReaderDesignTokens.Color.chipBackground.opacity(0.84)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ReaderDesignTokens.rssImportPanelPadding)
        .backgroundCard(cornerRadius: ReaderDesignTokens.Radius.md)
    }
}

private struct RSSImportExportRow: Hashable {
    enum Destination: Hashable {
        case exportDetail(sourceID: String, title: String)
        case importDetail(sourceID: String, title: String)
    }

    let title: String
    let meta: String
    let icon: ReaderAssetIcon
    let isSelected: Bool
    let destination: Destination

    static let exportRows: [RSSImportExportRow] = [
        RSSImportExportRow(title: "GitHub Releases", meta: "JSON · 保留分组、启用状态和解析规则", icon: .check, isSelected: true, destination: .exportDetail(sourceID: "github-releases", title: "GitHub Releases")),
        RSSImportExportRow(title: "阅读器版本讨论", meta: "JSON · 保留分组、启用状态和解析规则", icon: .check, isSelected: true, destination: .exportDetail(sourceID: "reader-discussions", title: "阅读器版本讨论"))
    ]

    static let importRows: [RSSImportExportRow] = [
        RSSImportExportRow(title: "书源维护公告", meta: "更新 · 规则版本更高 · 需登录", icon: .check, isSelected: true, destination: .importDetail(sourceID: "source-maintenance", title: "书源维护公告")),
        RSSImportExportRow(title: "社区 RSS 源合集", meta: "新增 · 4 个分类入口 · 无需登录", icon: .check, isSelected: true, destination: .importDetail(sourceID: "community-bundle", title: "社区 RSS 源合集")),
        RSSImportExportRow(title: "本地系统通知", meta: "冲突 · 本地已存在 · 保留本地状态", icon: .rss, isSelected: false, destination: .importDetail(sourceID: "local-system", title: "本地系统通知"))
    ]
}

private struct RSSImportExportList: View {
    let rows: [RSSImportExportRow]
    let actionTitle: String?

        var body: some View {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element) { index, row in
                RSSManagementRouteButton(route: route(for: row.destination)) {
                    HStack(spacing: 8) {
                        ReaderIcon(row.icon, size: 15, accessibilityLabel: row.title)
                            .frame(
                                width: ReaderDesignTokens.rssImportListIconSize,
                                height: ReaderDesignTokens.rssImportListIconSize
                            )
                            .background(Circle().fill(row.isSelected ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.primary.opacity(0.10)))
                            .foregroundColor(row.isSelected ? .white : ReaderDesignTokens.Color.primaryDark)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                                .lineLimit(1)
                            Text(row.meta)
                                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                                .foregroundStyle(ReaderDesignTokens.Color.muted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(actionTitle ?? (row.isSelected ? "详情" : "查看"))
                            .font(.system(size: ReaderDesignTokens.rssArticleRowBodyFontSize, weight: .black))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                            .padding(.horizontal, 8)
                            .frame(minHeight: ReaderDesignTokens.rssImportListActionMinHeight)
                            .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .frame(minHeight: ReaderDesignTokens.rssEditListRowMinHeight)
                }

                if index < rows.count - 1 {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                }
            }
        }
        .backgroundCard(cornerRadius: ReaderDesignTokens.Radius.md)
    }

    private func route(for destination: RSSImportExportRow.Destination) -> RSSManagementRoute {
        switch destination {
        case .exportDetail(let sourceID, let title):
            return .sourceExportDetail(sourceID: sourceID, title: title)
        case .importDetail(let sourceID, let title):
            return .sourceImportDetail(sourceID: sourceID, title: title)
        }
    }
}

private struct RSSSourceConfirmationPage<CancelDestination: View>: View {
    let title: String
    let icon: ReaderAssetIcon
    let heading: String
    let copy: String
    let detail: String
    let cancelTitle: String
    let cancelDestination: () -> CancelDestination
    let confirmTitle: String
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction
    @SwiftUI.Environment(\.rssManagementPop) private var pop

    var body: some View {
        DemoBackScreen(title: title) {
            RSSSourceConfirmCard(icon: icon, heading: heading, copy: copy, detail: detail)
        } bottomActionHost: {
            BottomFixedActionRow {
                Button {
                    pop()
                } label: {
                    RSSSourceActionBottomLabel(title: cancelTitle, isPrimary: false)
                }
                .buttonStyle(.plain)
            } trailing: {
                RSSSourceActionBottomButton(title: confirmTitle, isPrimary: true) {
                    dismiss()
                }
            }
        }
    }
}

private struct RSSManageFilterRow: View {
    @Binding var selectedFilter: String
    private let filters = ["全部", "已启用", "需登录", "无分组", "暂停"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ReaderDesignTokens.rssModeRowGap) {
                ForEach(filters, id: \.self) { filter in
                    PillChip(filter, isSelected: selectedFilter == filter) {
                        selectedFilter = filter
                    }
                }
            }
        }
    }
}

private struct RSSSourceList: View {
    let sources: [RSSManagementSource]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                RSSSourceManagementRow(source: source)
                if index < sources.count - 1 {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                }
            }
        }
        .backgroundCard(cornerRadius: ReaderDesignTokens.Radius.md)
    }
}

private struct RSSSourceManagementRow: View {
    let source: RSSManagementSource

    var body: some View {
        HStack(spacing: 8) {
            ReaderIcon(source.enabled ? .rss : .offline, size: 18, accessibilityLabel: source.name)
                .frame(
                    width: ReaderDesignTokens.rssSourceListIconSize,
                    height: ReaderDesignTokens.rssSourceListIconSize
                )
                .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)

            VStack(alignment: .leading, spacing: 3) {
                Text(source.name)
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                    .lineLimit(1)
                Text(source.listMeta)
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            RSSStatusBadge(tone: source.tone)
                .frame(width: ReaderDesignTokens.rssSourceListStatusWidth)

            RSSManagementRouteButton(route: .sourceActions(source)) {
                ReaderIcon(.more, size: 16, accessibilityLabel: "\(source.name) 更多操作")
                    .frame(
                        width: ReaderDesignTokens.rssSourceListMoreButtonSize,
                        height: ReaderDesignTokens.rssSourceListMoreButtonSize
                    )
                    .background(Circle().fill(ReaderDesignTokens.Color.chipBackground.opacity(0.72)))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: ReaderDesignTokens.rssSourceListRowMinHeight)
        .opacity(source.enabled ? 1 : 0.62)
    }
}

private struct RSSStatusBadge: View {
    let tone: RSSManagementSource.Tone

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .frame(width: 24, height: 18)
            .background(Capsule().fill(color.opacity(0.14)))
            .accessibilityHidden(true)
    }

    private var color: SwiftUI.Color {
        switch tone {
        case .good:
            return ReaderDesignTokens.Color.Semantic.success
        case .warn:
            return ReaderDesignTokens.Color.Semantic.warning
        case .muted:
            return ReaderDesignTokens.Color.muted
        }
    }
}

private struct RSSManageBatchRow: View {
    let selectedCount: Int

    var body: some View {
        HStack(spacing: 6) {
            Text("已选 \(selectedCount) 个")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: .black))
                .foregroundColor(ReaderDesignTokens.Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(["批量", "禁用", "导出"], id: \.self) { title in
                switch title {
                case "批量":
                    RSSManagementRouteButton(route: .sourceBatch) {
                        RSSBatchInlineLabel(title: title)
                    }
                case "禁用":
                    RSSManagementRouteButton(route: .sourceBatchDisable) {
                        RSSBatchInlineLabel(title: title)
                    }
                default:
                    RSSManagementRouteButton(route: .sourceExport) {
                        RSSBatchInlineLabel(title: title)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: ReaderDesignTokens.rssManageBatchRowMinHeight)
        .backgroundCard(cornerRadius: ReaderDesignTokens.Radius.md)
    }
}

private struct RSSBatchInlineLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: ReaderDesignTokens.rssArticleRowBodyFontSize, weight: .black))
            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            .padding(.horizontal, 8)
            .frame(minHeight: ReaderDesignTokens.rssImportListActionMinHeight)
            .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
    }
}

private struct RSSSourceSettingsPanel: View {
    @Binding var autoRefreshEnabled: Bool
    @Binding var unreadReminderEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("刷新与提醒")
                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
                .padding(.bottom, 4)

            RSSSourceSettingRow(
                icon: .refresh,
                title: "自动刷新",
                subtitle: "Wi-Fi 下每 30 分钟刷新一次",
                isOn: $autoRefreshEnabled
            )
            Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
            RSSSourceSettingRow(
                icon: .bell,
                title: "未读提醒",
                subtitle: "只提醒重点订阅源",
                isOn: $unreadReminderEnabled
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .backgroundCard(cornerRadius: ReaderDesignTokens.Radius.md)
    }
}

private struct RSSSourceSettingRow: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            ReaderIcon(icon, size: 16)
                .frame(width: 26)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: .black))
                Text(subtitle)
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            RSSManageSwitch(isOn: $isOn)
        }
        .frame(minHeight: ReaderDesignTokens.rssSourceSettingsRowMinHeight)
    }
}

private struct RSSManageSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.chipBackground)
                    .frame(width: ReaderDesignTokens.settingsSwitchTrackWidth, height: ReaderDesignTokens.settingsSwitchTrackHeight)
                Circle()
                    .fill(.white)
                    .frame(width: ReaderDesignTokens.settingsSwitchThumbSize, height: ReaderDesignTokens.settingsSwitchThumbSize)
                    .padding(2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : [.isButton])
    }
}

private struct RSSActionSourceCard: View {
    let source: RSSManagementSource

    var body: some View {
        HStack(spacing: 8) {
            ReaderIcon(.rss, size: 20, accessibilityLabel: source.name)
                .frame(width: 34, height: 34)
                .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.12)))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)

            VStack(alignment: .leading, spacing: 3) {
                Text(source.name)
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                    .lineLimit(1)
                Text(source.sourceMeta)
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            RSSStatusBadge(tone: source.tone)
        }
        .padding(10)
        .frame(minHeight: ReaderDesignTokens.rssActionSourceCardMinHeight)
        .backgroundCard(cornerRadius: ReaderDesignTokens.Radius.md)
    }
}

private struct RSSActionGrid: View {
    let source: RSSManagementSource
    private let actions: [(title: String, icon: ReaderAssetIcon)] = [
        ("刷新入口", .refresh),
        ("编辑源", .edit),
        ("规则调试", .bug),
        ("阅读记录", .clock),
        ("源变量", .code),
        ("登录", .shield),
        ("置顶", .top),
        ("禁用", .offline)
    ]

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: ReaderDesignTokens.rssActionGridGap), count: ReaderDesignTokens.rssActionGridColumns),
            spacing: ReaderDesignTokens.rssActionGridGap
        ) {
            ForEach(actions, id: \.title) { action in
                switch action.title {
                case "编辑源":
                    RSSManagementRouteButton(route: .sourceEdit(source)) {
                        RSSActionGridLabel(title: action.title, icon: action.icon)
                    }
                case "规则调试":
                    RSSManagementRouteButton(route: .sourceDebug(source)) {
                        RSSActionGridLabel(title: action.title, icon: action.icon)
                    }
                case "阅读记录":
                    RSSManagementRouteButton(route: .readRecord(source)) {
                        RSSActionGridLabel(title: action.title, icon: action.icon)
                    }
                case "源变量":
                    RSSManagementRouteButton(route: .sourceVars(source)) {
                        RSSActionGridLabel(title: action.title, icon: action.icon)
                    }
                case "登录":
                    RSSManagementRouteButton(route: .sourceLogin(source)) {
                        RSSActionGridLabel(title: action.title, icon: action.icon)
                    }
                case "置顶":
                    RSSManagementRouteButton(route: .sourcePin(source)) {
                        RSSActionGridLabel(title: action.title, icon: action.icon)
                    }
                case "禁用":
                    RSSManagementRouteButton(route: .sourceDisable(source)) {
                        RSSActionGridLabel(title: action.title, icon: action.icon)
                    }
                default:
                    Button {} label: {
                        RSSActionGridLabel(title: action.title, icon: action.icon)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct RSSActionGridLabel: View {
    let title: String
    let icon: ReaderAssetIcon
    var minHeight = ReaderDesignTokens.rssActionGridButtonMinHeight

    var body: some View {
        VStack(spacing: 5) {
            ReaderIcon(icon, size: 18, accessibilityLabel: title)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        .frame(maxWidth: .infinity, minHeight: minHeight)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(ReaderDesignTokens.Color.surface)
                .shadow(
                    // demo `--reader-ds-shadow-soft`: 0 8px 26px rgba(89,70,50,0.1)
                    color: ReaderDesignTokens.Color.Shadow.soft,
                    radius: 26, x: 0, y: 8
                )
        )
    }
}

private struct RSSLoginActionGrid: View {
    let source: RSSManagementSource
    private let actions: [(title: String, icon: ReaderAssetIcon, destination: RSSLoginActionDestination)] = [
        ("网页登录", .globe, .web),
        ("提取 Cookie", .file, .cookie),
        ("测试登录态", .refresh, .debug),
        ("清除登录", .trash, .clear)
    ]

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: ReaderDesignTokens.rssActionGridGap), count: ReaderDesignTokens.rssActionGridColumns),
            spacing: ReaderDesignTokens.rssActionGridGap
        ) {
            ForEach(actions, id: \.title) { action in
                RSSManagementRouteButton(route: route(for: action.destination)) {
                    RSSActionGridLabel(
                        title: action.title,
                        icon: action.icon,
                        minHeight: ReaderDesignTokens.rssActionGridCompactButtonMinHeight
                    )
                }
            }
        }
    }

    private func route(for destination: RSSLoginActionDestination) -> RSSManagementRoute {
        switch destination {
        case .web:
            return .sourceLoginWeb(source)
        case .cookie:
            return .sourceLoginCookie(source)
        case .debug:
            return .sourceDebug(source)
        case .clear:
            return .sourceLoginClear(source)
        }
    }
}

private enum RSSLoginActionDestination {
    case web
    case cookie
    case debug
    case clear
}

private struct RSSEditField: Hashable {
    let group: String
    let label: String
    let value: String
}

private struct RSSSourceEditTabs: View {
    @Binding var selectedGroup: String
    private let groups = ["基础", "请求", "列表", "WebView"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ReaderDesignTokens.rssModeRowGap) {
                ForEach(groups, id: \.self) { group in
                    PillChip(group, isSelected: selectedGroup == group) {
                        selectedGroup = group
                    }
                    .frame(minHeight: ReaderDesignTokens.rssEditTabsMinHeight)
                }
            }
        }
    }
}

private struct RSSEditFieldList: View {
    let fields: [RSSEditField]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(fields.enumerated()), id: \.element) { index, field in
                VStack(alignment: .leading, spacing: 3) {
                    Text(field.group)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                    Text(field.label)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .lineLimit(1)
                    Text(field.value)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssEditListRowMinHeight, alignment: .leading)
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                if index < fields.count - 1 {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                }
            }
        }
        .backgroundCard(cornerRadius: ReaderDesignTokens.Radius.md)
    }
}

private struct RSSDebugPanel: View {
    let source: RSSManagementSource

    var body: some View {
        RSSSourceInfoPanel(
            icon: .bug,
            title: source.name,
            subtitle: "列表解析 · 正文解析 · WebView 拦截",
            rows: debugRows
        )
    }

    private var debugRows: [RSSDebugRowModel] {
        [
            RSSDebugRowModel(title: "1. 获取分类入口", body: "\(source.categories > 1 ? "Releases / Issues / Discussions" : "默认入口") 已解析，缓存命中 \(source.categories) 项。", isWarning: false),
            RSSDebugRowModel(title: "2. 获取文章列表", body: "\(source.rule) 命中 \(max(source.unread, 18)) 条，下一页规则 PAGE 可用。", isWarning: false),
            RSSDebugRowModel(title: "3. 正文规则测试", body: "content:encoded 命中正文，图片资源通过白名单。", isWarning: false),
            RSSDebugRowModel(title: "4. 跳转拦截", body: "外链将保留在原文 WebView，legado/yuedu 协议进入导入流程。", isWarning: true)
        ]
    }
}

private struct RSSSourceHeaderPanel: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String

    var body: some View {
        RSSSourceInfoPanel(icon: icon, title: title, subtitle: subtitle, rows: [])
    }
}

private struct RSSSourceInfoPanel: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String
    let rows: [RSSDebugRowModel]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ReaderIcon(icon, size: 16, accessibilityLabel: title)
                    .frame(width: ReaderDesignTokens.rssDebugHeaderIconSize, height: ReaderDesignTokens.rssDebugHeaderIconSize)
                    .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.12)))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, rows.isEmpty ? 0 : 8)

            ForEach(Array(rows.enumerated()), id: \.element.title) { index, row in
                RSSDebugRow(row: row)
                if index < rows.count - 1 {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                }
            }
        }
        .padding(ReaderDesignTokens.rssDebugPanelPadding)
        .backgroundCard(cornerRadius: ReaderDesignTokens.Radius.md)
    }
}

private struct RSSLoginWebPreview: View {
    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.rssOriginalPreviewGap) {
                Text("登录页面预览")
                    .font(.system(size: ReaderDesignTokens.rssOriginalWebPreviewTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .lineLimit(1)

                Text("实际应用中这里打开内置 WebView。登录成功后提取 Cookie、Token 和登录检测结果，返回源登录页。")
                    .font(.system(size: ReaderDesignTokens.rssOriginalWebPreviewBodyFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm)
                        .fill(ReaderDesignTokens.Color.primary.opacity(0.12))
                        .frame(width: 180, height: 12)
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm)
                        .fill(ReaderDesignTokens.Color.chipBackground)
                        .frame(maxWidth: .infinity, minHeight: 42)
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm)
                        .fill(ReaderDesignTokens.Color.chipBackground.opacity(0.72))
                        .frame(width: 220, height: 34)
                }
                .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssOriginalWebPreviewMinHeight - 94, alignment: .center)
            }
        }
    }
}

private struct RSSSourceConfirmCard: View {
    let icon: ReaderAssetIcon
    let heading: String
    let copy: String
    let detail: String

    var body: some View {
        VStack(spacing: ReaderDesignTokens.rssBrowserConfirmGap) {
            ReaderIcon(icon, size: 22, accessibilityLabel: heading)
                .frame(
                    width: ReaderDesignTokens.rssBrowserConfirmIconSize,
                    height: ReaderDesignTokens.rssBrowserConfirmIconSize
                )
                .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.12)))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)

            Text(heading)
                .font(.system(size: ReaderDesignTokens.rssBrowserConfirmTitleFontSize, weight: .heavy))
                .foregroundColor(ReaderDesignTokens.Color.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: ReaderDesignTokens.rssBrowserConfirmTextMaxWidth)

            Text(copy)
                .font(.system(size: ReaderDesignTokens.rssBrowserConfirmBodyFontSize))
                .lineSpacing(ReaderDesignTokens.rssBrowserConfirmBodyFontSize * 0.7)
                .foregroundColor(ReaderDesignTokens.Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: ReaderDesignTokens.rssBrowserConfirmTextMaxWidth)

            Text(detail)
                .font(.system(size: ReaderDesignTokens.rssBrowserConfirmDetailFontSize))
                .lineSpacing(ReaderDesignTokens.rssBrowserConfirmDetailFontSize * 0.55)
                .foregroundStyle(ReaderDesignTokens.Color.muted)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: ReaderDesignTokens.rssBrowserConfirmTextMaxWidth)
        }
        .padding(.vertical, ReaderDesignTokens.rssBrowserConfirmVerticalPadding)
        .padding(.horizontal, ReaderDesignTokens.rssBrowserConfirmHorizontalPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssBrowserConfirmCardMinHeight)
        .backgroundCard(cornerRadius: ReaderDesignTokens.Radius.md)
    }
}

private struct RSSDebugRowModel: Hashable {
    let title: String
    let body: String
    let isWarning: Bool
}

private struct RSSDebugRow: View {
    let row: RSSDebugRowModel

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(row.title)
                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                .lineLimit(1)
            Text(row.body)
                .font(.system(size: ReaderDesignTokens.rssBrowserConfirmDetailFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssEditListRowMinHeight, alignment: .leading)
        .padding(.horizontal, row.isWarning ? 9 : 0)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm)
                .fill(row.isWarning ? ReaderDesignTokens.Color.Semantic.warningTint : .clear)
        )
    }
}

private struct RSSSourceActionBottomLabel: View {
    let title: String
    let isPrimary: Bool

    var body: some View {
        Text(title)
            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
            .foregroundColor(isPrimary ? .white : ReaderDesignTokens.Color.primaryDark)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
            .background(
                Capsule()
                    .fill(isPrimary ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.surface)
            )
            .overlay(
                Capsule()
                    .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: isPrimary ? 0 : 1)
            )
    }
}

private struct RSSSourceActionBottomButton: View {
    let title: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RSSSourceActionBottomLabel(title: title, isPrimary: isPrimary)
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    func backgroundCard(cornerRadius: CGFloat) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(ReaderDesignTokens.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(ReaderDesignTokens.Color.mainNavBorder.opacity(0.72), lineWidth: 1)
                )
                .shadow(
                    // demo `--reader-ds-shadow-soft`: 0 8px 26px rgba(89,70,50,0.1)
                    color: ReaderDesignTokens.Color.Shadow.soft,
                    radius: 26,
                    x: 0,
                    y: 8
                )
        )
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
