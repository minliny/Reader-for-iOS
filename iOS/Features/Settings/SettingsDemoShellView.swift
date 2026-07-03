import SwiftUI

struct SettingsDemoShellView: View {
    private let state: SettingsDemoRouteState

    init(demoRoute: String) {
        self.state = SettingsDemoRouteState(route: demoRoute)
    }

    var body: some View {
        DemoBackScreen(title: state.title) {
            SettingsDemoHero(state: state)

            if !state.metrics.isEmpty {
                SettingsDemoMetricGrid(metrics: state.metrics)
            }

            if let searchPlaceholder = state.searchPlaceholder {
                SettingsDemoSearchField(placeholder: searchPlaceholder)
            }

            ForEach(state.chipRows) { row in
                SettingsDemoChipRow(row: row)
            }

            ForEach(state.sections) { section in
                SettingsDemoSectionView(section: section)
            }

            if !state.sourceRows.isEmpty {
                SettingsDemoSourceListView(title: state.sourceListTitle, rows: state.sourceRows, mode: state.sourceListMode)
            }

            if !state.infoItems.isEmpty {
                SettingsDemoInfoGrid(items: state.infoItems)
            }

            if !state.codeLines.isEmpty {
                SettingsDemoCodeBlock(lines: state.codeLines)
            }

            if state.presentation == .deleteDialog {
                SettingsDemoDeleteDialog()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !state.actions.isEmpty {
                SettingsDemoBottomActions(actions: state.actions)
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
}

private enum SettingsDemoPresentation: Equatable {
    case settings
    case restore
    case source
    case discoverSource
    case deleteDialog
}

private enum SettingsDemoTone: Equatable {
    case normal
    case good
    case warn
    case info
    case muted
    case danger

    var foreground: SwiftUI.Color {
        switch self {
        case .normal:
            return ReaderDesignTokens.Color.primaryDark
        case .good:
            return SwiftUI.Color(red: 0.11, green: 0.42, blue: 0.24)
        case .warn:
            return SwiftUI.Color(red: 0.66, green: 0.38, blue: 0.08)
        case .info:
            return ReaderDesignTokens.Color.primary
        case .muted:
            return SwiftUI.Color.secondary
        case .danger:
            return SwiftUI.Color(red: 0.72, green: 0.16, blue: 0.14)
        }
    }

    var background: SwiftUI.Color {
        switch self {
        case .normal:
            return ReaderDesignTokens.Color.chipBackground
        case .good:
            return SwiftUI.Color(red: 0.78, green: 0.92, blue: 0.82, opacity: 0.78)
        case .warn:
            return SwiftUI.Color(red: 1.0, green: 0.88, blue: 0.63, opacity: 0.82)
        case .info:
            return SwiftUI.Color(red: 0.72, green: 0.86, blue: 0.94, opacity: 0.78)
        case .muted:
            return SwiftUI.Color(red: 0.88, green: 0.85, blue: 0.80, opacity: 0.82)
        case .danger:
            return SwiftUI.Color(red: 1.0, green: 0.79, blue: 0.76, opacity: 0.86)
        }
    }
}

private struct SettingsDemoRouteState {
    let route: String
    let title: String
    let subtitle: String
    let icon: ReaderAssetIcon
    let status: String?
    let statusTone: SettingsDemoTone
    let presentation: SettingsDemoPresentation
    let metrics: [SettingsDemoMetric]
    let searchPlaceholder: String?
    let chipRows: [SettingsDemoChipRowData]
    let sections: [SettingsDemoSection]
    let sourceRows: [SettingsDemoSourceRow]
    let sourceListTitle: String
    let sourceListMode: SettingsDemoSourceListMode
    let infoItems: [SettingsDemoInfoItem]
    let codeLines: [String]
    let actions: [SettingsDemoAction]

    init(route: String) {
        let normalizedRoute = route.isEmpty ? "settings-general" : route
        switch normalizedRoute {
        case "discover-rule-test":
            self = Self.discoverRuleTest(route: normalizedRoute)
        case "discover-source-bulk":
            self = Self.discoverSourceBulk(route: normalizedRoute)
        case "settings-general":
            self = Self.settingsGeneral(route: normalizedRoute)
        case "bookshelf-search-settings":
            self = Self.bookshelfSearch(route: normalizedRoute)
        case "about-feedback":
            self = Self.aboutFeedback(route: normalizedRoute)
        case "sync-backup":
            self = Self.syncBackup(route: normalizedRoute)
        case "webdav-config":
            self = Self.webdavConfig(route: normalizedRoute)
        case "restore-confirm", "restore-progress", "restore-conflict", "restore-result":
            self = Self.restore(route: normalizedRoute)
        case "source-management":
            self = Self.sourceManagement(route: normalizedRoute)
        case "source-import-options":
            self = Self.sourceImportOptions(route: normalizedRoute)
        case "source-import-preview":
            self = Self.sourceImportPreview(route: normalizedRoute)
        case "source-batch":
            self = Self.sourceBatch(route: normalizedRoute)
        case "source-groups":
            self = Self.sourceGroups(route: normalizedRoute)
        case "source-detail":
            self = Self.sourceDetail(route: normalizedRoute)
        case "source-detect":
            self = Self.sourceDetect(route: normalizedRoute)
        case "source-rule-edit", "source-edit-debug":
            self = Self.sourceRuleEdit(route: normalizedRoute)
        case "source-debug":
            self = Self.sourceDebug(route: normalizedRoute)
        case "source-debug-search-result", "source-debug-detail-result", "source-debug-catalog-result":
            self = Self.sourceDebugResult(route: normalizedRoute)
        case "source-debug-content-log":
            self = Self.sourceDebugContentLog(route: normalizedRoute)
        case "source-logs":
            self = Self.sourceLogs(route: normalizedRoute)
        case "source-code-view":
            self = Self.sourceCodeView(route: normalizedRoute)
        case "source-delete-confirm":
            self = Self.sourceDeleteConfirm(route: normalizedRoute)
        default:
            self = Self.settingsGeneral(route: normalizedRoute)
        }
    }

    private init(
        route: String,
        title: String,
        subtitle: String,
        icon: ReaderAssetIcon,
        status: String? = nil,
        statusTone: SettingsDemoTone = .normal,
        presentation: SettingsDemoPresentation = .settings,
        metrics: [SettingsDemoMetric] = [],
        searchPlaceholder: String? = nil,
        chipRows: [SettingsDemoChipRowData] = [],
        sections: [SettingsDemoSection] = [],
        sourceRows: [SettingsDemoSourceRow] = [],
        sourceListTitle: String = "书源列表",
        sourceListMode: SettingsDemoSourceListMode = .plain,
        infoItems: [SettingsDemoInfoItem] = [],
        codeLines: [String] = [],
        actions: [SettingsDemoAction] = []
    ) {
        self.route = route
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.status = status
        self.statusTone = statusTone
        self.presentation = presentation
        self.metrics = metrics
        self.searchPlaceholder = searchPlaceholder
        self.chipRows = chipRows
        self.sections = sections
        self.sourceRows = sourceRows
        self.sourceListTitle = sourceListTitle
        self.sourceListMode = sourceListMode
        self.infoItems = infoItems
        self.codeLines = codeLines
        self.actions = actions
    }

    private static func settingsGeneral(route: String) -> Self {
        Self(
            route: route,
            title: "通用设置",
            subtitle: "App 主题、语言、启动页、反馈与系统权限",
            icon: .gear,
            status: "SettingsShell",
            sections: [
                SettingsDemoSection(title: "基础偏好", rows: [
                    row(.palette, "App 主题", "跟随系统"),
                    row(.globe, "语言", "简体中文"),
                    row(.home, "启动时打开", "书架")
                ]),
                SettingsDemoSection(title: "行为与反馈", rows: [
                    switchRow(.refresh, "自动检查更新", enabled: true),
                    switchRow(.top, "点击当前底栏回顶部", enabled: true),
                    switchRow(.motion, "减少动态效果", enabled: true),
                    row(.bug, "崩溃日志", "已开启", tone: .good),
                    row(.play, "动画效果", "标准"),
                    row(.trash, "缓存清理", "清理缓存", tone: .danger)
                ]),
                SettingsDemoSection(title: "系统权限", rows: [
                    row(.folder, "文件访问", "已授权", tone: .good),
                    row(.bell, "通知权限", "未授权", tone: .warn),
                    row(.battery, "电池优化", "受系统管理", tone: .info)
                ])
            ],
            actions: [
                SettingsDemoAction(icon: .refresh, title: "恢复默认", tone: .danger)
            ]
        )
    }

    private static func bookshelfSearch(route: String) -> Self {
        Self(
            route: route,
            title: "书架与搜索",
            subtitle: "书架展示、排序筛选和搜索历史偏好",
            icon: .bookshelf,
            status: "route state",
            sections: [
                SettingsDemoSection(title: "书架", rows: [
                    row(.grid, "默认展示", "封面"),
                    row(.columns, "封面列数", "3 列"),
                    row(.folder, "默认分组", "全部"),
                    switchRow(.badge, "显示更新标记", enabled: true)
                ]),
                SettingsDemoSection(title: "排序与筛选", rows: [
                    row(.sort, "书架排序", "最近更新"),
                    row(.list, "展示范围", "全部"),
                    row(.refresh, "更新状态", "不限")
                ]),
                SettingsDemoSection(title: "搜索", rows: [
                    row(.search, "搜索范围", "全局"),
                    row(.sort, "结果排序", "相关度"),
                    switchRow(.people, "合并同名同作者", enabled: true),
                    switchRow(.clock, "搜索历史", enabled: true),
                    row(.list, "搜索历史数量", "20 条")
                ])
            ],
            actions: [
                SettingsDemoAction(icon: .trash, title: "清空搜索历史", tone: .danger)
            ]
        )
    }

    private static func aboutFeedback(route: String) -> Self {
        Self(
            route: route,
            title: "关于与反馈",
            subtitle: "版本、源码、开源许可和贡献入口",
            icon: .info,
            status: "1.0.0",
            sections: [
                SettingsDemoSection(title: "项目信息", rows: [
                    row(.refresh, "检查更新", "已是最新", tone: .good),
                    row(.code, "源码仓库", "GitHub"),
                    row(.link, "开源许可", "查看"),
                    row(.mail, "参与贡献", "反馈与提交")
                ])
            ]
        )
    }

    private static func syncBackup(route: String) -> Self {
        Self(
            route: route,
            title: "同步与备份",
            subtitle: "WebDAV 配置、备份记录和恢复入口",
            icon: .sync,
            status: "6 records",
            metrics: [
                SettingsDemoMetric(icon: .cloud, value: "12.8 MB", label: "最新备份"),
                SettingsDemoMetric(icon: .clock, value: "08:00", label: "自动备份"),
                SettingsDemoMetric(icon: .bookshelf, value: "128", label: "书架书籍")
            ],
            sections: [
                webdavSection(title: "WebDAV 配置"),
                SettingsDemoSection(title: "恢复数据", rows: backupRows)
            ],
            actions: [
                SettingsDemoAction(icon: .refresh, title: "测试网络"),
                SettingsDemoAction(icon: .check, title: "保存配置")
            ]
        )
    }

    private static func webdavConfig(route: String) -> Self {
        Self(
            route: route,
            title: "WebDAV 配置",
            subtitle: "服务器地址、账号、密码和同步目录",
            icon: .cloud,
            status: "config",
            sections: [
                webdavSection(title: "连接信息")
            ],
            actions: [
                SettingsDemoAction(icon: .refresh, title: "测试网络"),
                SettingsDemoAction(icon: .check, title: "保存配置")
            ]
        )
    }

    private static func restore(route: String) -> Self {
        switch route {
        case "restore-progress":
            return Self(
                route: route,
                title: "恢复进度",
                subtitle: "WebDAV · 2026-06-23 08:00 · 完整备份",
                icon: .refresh,
                status: "68%",
                statusTone: .warn,
                presentation: .restore,
                metrics: [
                    SettingsDemoMetric(icon: .download, value: "完成", label: "下载备份"),
                    SettingsDemoMetric(icon: .check, value: "完成", label: "校验文件"),
                    SettingsDemoMetric(icon: .sync, value: "进行中", label: "合并数据")
                ],
                sections: [
                    SettingsDemoSection(title: "阶段", rows: [
                        progressRow(.download, "下载备份", "12.8 MB · WebDAV", "100%", .good),
                        progressRow(.check, "校验文件", "manifest、hash、版本兼容", "100%", .good),
                        progressRow(.sync, "合并数据", "书架 128 本 · 进度 96 条", "68%", .warn),
                        progressRow(.settings, "写入设置", "等待合并完成", "0%", .muted)
                    ])
                ],
                actions: [
                    SettingsDemoAction(icon: .warning, title: "处理冲突"),
                    SettingsDemoAction(icon: .info, title: "查看结果")
                ]
            )
        case "restore-conflict":
            return Self(
                route: route,
                title: "恢复冲突",
                subtitle: "本地和备份均有更新，需要逐项选择",
                icon: .warning,
                status: "3 项冲突",
                statusTone: .warn,
                presentation: .restore,
                sections: [
                    SettingsDemoSection(title: "冲突项", rows: [
                        row(.folder, "分组：玄幻连载", "本地 42 本 · 远程 46 本", detail: "备份", tone: .warn),
                        row(.clock, "阅读进度：长夜余火", "本地第 32 章 · 远程第 35 章", detail: "远程", tone: .warn),
                        row(.palette, "阅读设置：浅色主题", "本地字号 18 · 远程字号 17", detail: "备份", tone: .warn)
                    ])
                ],
                actions: [
                    SettingsDemoAction(icon: .back, title: "返回进度"),
                    SettingsDemoAction(icon: .check, title: "应用选择")
                ]
            )
        case "restore-result":
            return Self(
                route: route,
                title: "恢复结果",
                subtitle: "恢复完成，1 条旧版规则字段被跳过",
                icon: .check,
                status: "部分成功",
                statusTone: .warn,
                presentation: .restore,
                metrics: [
                    SettingsDemoMetric(icon: .book, value: "128", label: "恢复书籍"),
                    SettingsDemoMetric(icon: .folder, value: "12", label: "恢复分组"),
                    SettingsDemoMetric(icon: .clock, value: "96", label: "恢复进度"),
                    SettingsDemoMetric(icon: .warning, value: "1", label: "跳过项目")
                ],
                sections: [
                    SettingsDemoSection(title: "结果明细", rows: [
                        row(.check, "书架与分组", "已恢复 128 本书和 12 个分组", detail: "成功", tone: .good),
                        row(.check, "阅读进度", "已恢复 96 条进度记录", detail: "成功", tone: .good),
                        row(.warning, "书源配置", "1 条旧版规则字段不兼容", detail: "跳过", tone: .warn)
                    ])
                ],
                actions: [
                    SettingsDemoAction(icon: .log, title: "查看日志"),
                    SettingsDemoAction(icon: .sync, title: "返回同步页")
                ]
            )
        default:
            return Self(
                route: route,
                title: "恢复确认",
                subtitle: "WebDAV · 2026-06-23 08:00 · 完整备份",
                icon: .database,
                status: "待确认",
                statusTone: .warn,
                presentation: .restore,
                sections: [
                    SettingsDemoSection(title: "恢复摘要", rows: [
                        row(.cloud, "备份来源", "WebDAV · 2026-06-23 08:00 · 完整备份"),
                        row(.list, "恢复范围", "书架与分组、阅读进度、设置、书源配置"),
                        row(.warning, "预计影响", "128 本书 · 12 个分组 等 4 项", tone: .warn),
                        row(.database, "可回退点", "恢复前自动生成本地快照", tone: .good)
                    ]),
                    SettingsDemoSection(title: "选择恢复范围", rows: [
                        switchRow(.bookshelf, "书架与分组", subtitle: "恢复书架书籍、分组和排序", enabled: true),
                        switchRow(.clock, "阅读进度", subtitle: "恢复章节位置和阅读进度", enabled: true),
                        switchRow(.settings, "阅读与 App 设置", subtitle: "恢复主题、排版和通用设置", enabled: true),
                        switchRow(.source, "书源配置", subtitle: "恢复书源、分组和启用状态", enabled: true)
                    ])
                ],
                actions: [
                    SettingsDemoAction(icon: .close, title: "取消"),
                    SettingsDemoAction(icon: .refresh, title: "开始恢复")
                ]
            )
        }
    }

    private static func sourceManagement(route: String) -> Self {
        sourceState(
            route: route,
            title: "书源管理",
            subtitle: "搜索、筛选、启停、检测和批量入口",
            status: "12 个书源",
            metrics: sourceMetrics,
            searchPlaceholder: "搜索书源名称或域名",
            chipRows: sourceFilterRows,
            sourceRows: sourceItems,
            actions: [
                SettingsDemoAction(icon: .list, title: "批量管理"),
                SettingsDemoAction(icon: .add, title: "新增书源")
            ]
        )
    }

    private static func sourceImportOptions(route: String) -> Self {
        sourceState(
            route: route,
            title: "添加书源",
            subtitle: "网络、本地、剪贴板或手动新建",
            status: "bottom sheet",
            sections: [
                SettingsDemoSection(title: "添加方式", rows: [
                    row(.cloud, "网络导入", "从 URL 拉取书源包", detail: "预览"),
                    row(.folder, "本地导入", "选择本地 JSON 或 TXT 文件", detail: "预览"),
                    row(.file, "剪贴板导入", "解析剪贴板中的书源内容", detail: "预览"),
                    row(.edit, "手动新建", "进入空白书源编辑页", detail: "编辑")
                ])
            ],
            actions: [
                SettingsDemoAction(icon: .close, title: "取消")
            ]
        )
    }

    private static func sourceImportPreview(route: String) -> Self {
        sourceState(
            route: route,
            title: "导入书源",
            subtitle: "https://example.com/booksource.json",
            status: "24 个",
            sections: [
                SettingsDemoSection(title: "冲突处理", rows: [
                    row(.replace, "重复处理", "跳过重复"),
                    row(.folder, "导入到分组", "保持原分组")
                ])
            ],
            sourceRows: [
                sourceRow("起点中文网", "qidian.com · 起点导入", "新增", .good, true, false),
                sourceRow("晋江文学城", "jjwx.example · 起点导入", "重复", .muted, true, false),
                sourceRow("轻小说文库", "lightnovel.example · 测试书源", "新增", .good, true, false),
                sourceRow("失效示例源", "dead.example · 测试书源", "异常", .warn, false, false)
            ],
            actions: [
                SettingsDemoAction(icon: .close, title: "取消"),
                SettingsDemoAction(icon: .check, title: "确认导入")
            ]
        )
    }

    private static func sourceBatch(route: String) -> Self {
        sourceState(
            route: route,
            title: "已选 3 个",
            subtitle: "批量启用、禁用、检测、分组或删除",
            status: "batch",
            searchPlaceholder: "搜索书源名称或域名",
            chipRows: sourceFilterRows,
            sourceRows: sourceItems,
            sourceListMode: .selection,
            actions: [
                SettingsDemoAction(icon: .check, title: "启用"),
                SettingsDemoAction(icon: .close, title: "禁用"),
                SettingsDemoAction(icon: .activity, title: "检测"),
                SettingsDemoAction(icon: .folder, title: "分组"),
                SettingsDemoAction(icon: .trash, title: "删除", tone: .danger)
            ]
        )
    }

    private static func sourceGroups(route: String) -> Self {
        sourceState(
            route: route,
            title: "分组管理",
            subtitle: "分组用于筛选和批量整理书源",
            status: "6 groups",
            sections: [
                SettingsDemoSection(title: "分组", rows: [
                    row(.folder, "全部分组", "12 个书源"),
                    row(.folder, "玄幻书源", "4 个书源", detail: "当前筛选", tone: .info),
                    row(.folder, "起点导入", "3 个书源"),
                    row(.folder, "测试书源", "3 个书源"),
                    row(.folder, "自定义", "2 个书源"),
                    row(.folderOff, "未分组", "1 个书源")
                ])
            ],
            actions: [
                SettingsDemoAction(icon: .sourceSwitch, title: "批量移动"),
                SettingsDemoAction(icon: .add, title: "新增分组")
            ]
        )
    }

    private static func sourceDetail(route: String) -> Self {
        sourceState(
            route: route,
            title: "书源详情",
            subtitle: "笔趣阁 · biquge.example · 玄幻书源",
            status: "异常",
            statusTone: .warn,
            sections: [
                SettingsDemoSection(title: "模块状态", rows: [
                    row(.link, "站点", "200 OK", detail: "可访问", tone: .good),
                    row(.search, "搜索", "关键词返回 12 条", detail: "正常", tone: .good),
                    row(.info, "详情", "字段解析成功", detail: "正常", tone: .good),
                    row(.directory, "目录", "812 章", detail: "正常", tone: .good),
                    row(.text, "正文", "正文模块返回空内容", detail: "异常", tone: .warn),
                    row(.people, "登录", "未启用", detail: "未启用", tone: .muted)
                ])
            ],
            infoItems: [
                SettingsDemoInfoItem(label: "请求方式", value: "GET · UTF-8"),
                SettingsDemoInfoItem(label: "并发限制", value: "2 个请求"),
                SettingsDemoInfoItem(label: "Cookie", value: "未启用"),
                SettingsDemoInfoItem(label: "更新时间", value: "今天 10:12")
            ],
            actions: [
                SettingsDemoAction(icon: .activity, title: "检测此源"),
                SettingsDemoAction(icon: .edit, title: "编辑规则"),
                SettingsDemoAction(icon: .trash, title: "删除", tone: .danger)
            ]
        )
    }

    private static func sourceDetect(route: String) -> Self {
        sourceState(
            route: route,
            title: "书源检测",
            subtitle: "笔趣阁 · 5 项检测 · 4 项通过 · 1 项失败",
            status: "异常",
            statusTone: .warn,
            sections: [
                SettingsDemoSection(title: "检测步骤", rows: [
                    row(.link, "站点访问", "200 OK · 126ms", detail: "通过", tone: .good),
                    row(.search, "搜索规则", "关键词“斗破苍穹”返回 12 条", detail: "通过", tone: .good),
                    row(.info, "详情规则", "书名、作者、封面、简介均解析成功", detail: "通过", tone: .good),
                    row(.directory, "目录规则", "解析 812 章，章节 URL 有效", detail: "通过", tone: .good),
                    row(.text, "正文规则", "“#content@text”返回空内容", detail: "失败", tone: .warn)
                ]),
                SettingsDemoSection(title: "失败定位", rows: [
                    row(.warning, "正文请求成功", "正文选择器没有匹配到有效文本", tone: .warn),
                    row(.code, "下一步", "比较原始 HTML 与当前正文规则")
                ])
            ],
            actions: [
                SettingsDemoAction(icon: .refresh, title: "重新检测"),
                SettingsDemoAction(icon: .edit, title: "编辑正文规则")
            ]
        )
    }

    private static func sourceRuleEdit(route: String) -> Self {
        sourceState(
            route: route,
            title: "规则编辑",
            subtitle: "笔趣阁 · 正在编辑：正文规则",
            status: route == "source-edit-debug" ? "edit+debug" : "v3",
            chipRows: [
                SettingsDemoChipRowData(title: "模块", chips: ["基本", "搜索", "详情", "目录", "正文", "高级"], selected: "正文")
            ],
            sections: [
                SettingsDemoSection(title: "基础配置", rows: [
                    row(.source, "书源名称", "笔趣阁"),
                    row(.link, "书源地址", "https://biquge.example"),
                    row(.folder, "书源分组", "玄幻书源"),
                    row(.check, "启用状态", "已启用", tone: .good)
                ]),
                SettingsDemoSection(title: "请求配置", rows: [
                    row(.wifi, "请求方式", "GET"),
                    row(.typo, "字符编码", "UTF-8"),
                    row(.code, "请求头", "User-Agent / Referer"),
                    row(.shield, "Cookie", "未启用")
                ]),
                SettingsDemoSection(title: "解析规则", rows: [
                    row(.link, "正文页 URL", "{{chapterUrl}}"),
                    row(.text, "章节标题", ".chapter-title@text"),
                    row(.code, "正文内容", "#content@text", tone: .warn),
                    row(.chevron, "下一页", ".next@href")
                ]),
                SettingsDemoSection(title: "当前规则说明", rows: [
                    row(.info, "规则边界", "编辑的是解析表达式，不是 UI 显示规则"),
                    row(.play, "验证顺序", "修改后先调测当前模块，再保存")
                ])
            ],
            actions: [
                SettingsDemoAction(icon: .check, title: "保存规则"),
                SettingsDemoAction(icon: .bug, title: "调测当前模块")
            ]
        )
    }

    private static func sourceDebug(route: String) -> Self {
        sourceDebugPage(
            route: route,
            title: "正文模块调测",
            subtitle: "笔趣阁 · 第 128 章 风雨夜",
            badge: "失败",
            tone: .warn,
            active: "正文",
            request: "GET https://biquge.example/book/123/128.html · 200 OK · 412ms",
            inputs: [
                ("章节 URL", "/book/123/128.html"),
                ("正文规则", "#content@text")
            ],
            parsed: [
                ("章节标题", "第 128 章 风雨夜"),
                ("正文长度", "0 字"),
                ("匹配节点", "0 个"),
                ("错误原因", "正文选择器未命中")
            ],
            suggestion: "可尝试将正文内容规则改为“.chapter-content@text”后重新调测。"
        )
    }

    private static func sourceDebugResult(route: String) -> Self {
        switch route {
        case "source-debug-detail-result":
            return sourceDebugPage(
                route: route,
                title: "详情模块调测",
                subtitle: "笔趣阁 · /book/123/",
                badge: "通过",
                tone: .good,
                active: "详情",
                request: "GET https://biquge.example/book/123/ · 200 OK · 318ms",
                inputs: [("详情 URL", "/book/123/"), ("字段规则", "h1@text / .author@text")],
                parsed: [("书名", "斗破苍穹"), ("作者", "天蚕土豆"), ("封面", "cover.jpg · 200 OK"), ("简介", "186 字")],
                suggestion: "书名、作者、封面、简介均已解析，可继续目录模块调测。"
            )
        case "source-debug-catalog-result":
            return sourceDebugPage(
                route: route,
                title: "目录模块调测",
                subtitle: "笔趣阁 · /book/123/catalog",
                badge: "通过",
                tone: .good,
                active: "目录",
                request: "GET https://biquge.example/book/123/catalog · 200 OK · 366ms",
                inputs: [("目录 URL", "/book/123/catalog"), ("章节规则", ".chapter-list a")],
                parsed: [("章节数量", "812 章"), ("首章", "第 1 章 陨落的天才"), ("末章", "第 812 章 大结局"), ("URL 有效", "812/812")],
                suggestion: "章节名和章节 URL 已匹配，下一步应调测正文内容规则。"
            )
        default:
            return sourceDebugPage(
                route: route,
                title: "搜索模块调测",
                subtitle: "笔趣阁 · 关键词 斗破苍穹",
                badge: "通过",
                tone: .good,
                active: "搜索",
                request: "GET https://biquge.example/search?q=斗破苍穹 · 200 OK · 286ms",
                inputs: [("关键词", "斗破苍穹"), ("结果规则", ".book-list > li")],
                parsed: [("命中数量", "12 条"), ("书名字段", ".title@text · 12/12"), ("作者字段", ".author@text · 12/12"), ("详情 URL", "12/12 有效")],
                suggestion: "结果列表、书名、作者和详情 URL 均可用于下一步详情调测。"
            )
        }
    }

    private static func sourceDebugPage(
        route: String,
        title: String,
        subtitle: String,
        badge: String,
        tone: SettingsDemoTone,
        active: String,
        request: String,
        inputs: [(String, String)],
        parsed: [(String, String)],
        suggestion: String
    ) -> Self {
        sourceState(
            route: route,
            title: "书源调测",
            subtitle: subtitle,
            status: badge,
            statusTone: tone,
            chipRows: [
                SettingsDemoChipRowData(title: "调测模块", chips: ["搜索", "详情", "目录", "正文"], selected: active),
                SettingsDemoChipRowData(title: "结果视图", chips: ["解析结果", "源码", "日志"], selected: "解析结果")
            ],
            sections: [
                SettingsDemoSection(title: title, rows: inputs.map { label, value in row(.code, label, value) }),
                SettingsDemoSection(title: "请求", rows: [row(.wifi, request, nil, detail: badge, tone: tone)]),
                SettingsDemoSection(title: "解析结果", rows: parsed.map { label, value in row(.info, label, value) }),
                SettingsDemoSection(title: "修复建议", rows: [row(.warning, suggestion, nil, tone: tone)])
            ],
            actions: [
                SettingsDemoAction(icon: .refresh, title: "重新调测"),
                SettingsDemoAction(icon: .edit, title: "回到编辑")
            ]
        )
    }

    private static func sourceDebugContentLog(route: String) -> Self {
        sourceState(
            route: route,
            title: "正文模块日志",
            subtitle: "笔趣阁 · 第 128 章 风雨夜",
            status: "失败",
            statusTone: .warn,
            chipRows: [
                SettingsDemoChipRowData(title: "结果视图", chips: ["解析结果", "源码", "日志"], selected: "日志")
            ],
            sections: [
                SettingsDemoSection(title: "调测日志", rows: [
                    row(.wifi, "10:30:18.120 · 请求章节 HTML", "GET /book/123/128.html · 200 OK · 412ms"),
                    row(.code, "10:30:18.204 · 执行正文规则", "#content@text · 匹配节点 0 个", tone: .warn),
                    row(.replace, "10:30:18.226 · 执行净化规则", "未进入净化阶段，正文为空", tone: .warn),
                    row(.warning, "10:30:18.240 · 返回错误", "正文内容为空，建议检查选择器或源码结构", tone: .danger)
                ]),
                SettingsDemoSection(title: "定位结果", rows: [
                    row(.info, "源码提示", "正文位于“.chapter-content”容器"),
                    row(.edit, "修复动作", "回到规则编辑并改写正文规则")
                ])
            ],
            actions: [
                SettingsDemoAction(icon: .file, title: "复制日志"),
                SettingsDemoAction(icon: .bug, title: "回到解析"),
                SettingsDemoAction(icon: .edit, title: "回到编辑")
            ]
        )
    }

    private static func sourceLogs(route: String) -> Self {
        sourceState(
            route: route,
            title: "错误日志",
            subtitle: "书源异常、警告与检测记录",
            status: "5 条",
            searchPlaceholder: "搜索书源或错误内容",
            chipRows: [
                SettingsDemoChipRowData(title: "日志筛选", chips: ["全部", "异常", "警告", "今日"], selected: "全部")
            ],
            sections: [
                SettingsDemoSection(title: "日志列表", rows: [
                    row(.warning, "笔趣阁 · ERROR", "10:30 · 正文 · 正文规则返回空内容", tone: .danger),
                    row(.warning, "旧规则源 · ERROR", "10:22 · 搜索 · HTTP 403", tone: .danger),
                    row(.info, "本地导入源 · WARN", "09:50 · 目录 · 尚未检测", tone: .warn),
                    row(.warning, "失效示例源 · ERROR", "昨天 · 详情 · 详情页 URL 为空", tone: .danger)
                ])
            ],
            actions: [
                SettingsDemoAction(icon: .file, title: "复制全部"),
                SettingsDemoAction(icon: .activity, title: "重新检测异常")
            ]
        )
    }

    private static func sourceCodeView(route: String) -> Self {
        sourceState(
            route: route,
            title: "源码查看",
            subtitle: "正文模块 · 当前请求返回",
            status: "200 OK",
            statusTone: .good,
            chipRows: [
                SettingsDemoChipRowData(title: "结果视图", chips: ["解析结果", "源码", "日志"], selected: "源码")
            ],
            sections: [
                SettingsDemoSection(title: "请求", rows: [
                    row(.link, "章节 URL", "/book/123/128.html"),
                    row(.code, "正文规则", "#content@text"),
                    row(.wifi, "请求状态", "GET · 200 OK · 412ms", tone: .good)
                ])
            ],
            codeLines: [
                "<html>",
                "  <body>",
                "    <h1 class=\"chapter-title\">第 128 章 风雨夜</h1>",
                "    <main class=\"chapter-content\">",
                "      <p>雨声在檐下连成一片，旧街的灯光被水汽晕开。</p>",
                "      <p>他把地图折回怀里，终于确认了下一处坐标。</p>",
                "    </main>",
                "    <a class=\"next\" href=\"/book/123/129.html\">下一章</a>",
                "  </body>",
                "</html>"
            ],
            actions: [
                SettingsDemoAction(icon: .refresh, title: "重新请求"),
                SettingsDemoAction(icon: .bug, title: "回到调测")
            ]
        )
    }

    private static func sourceDeleteConfirm(route: String) -> Self {
        sourceState(
            route: route,
            title: "删除书源",
            subtitle: "将删除已选 3 个书源，不影响书架书籍",
            status: "确认",
            statusTone: .danger,
            presentation: .deleteDialog,
            sourceRows: sourceItems,
            sourceListMode: .selection,
            actions: []
        )
    }

    private static func discoverRuleTest(route: String) -> Self {
        Self(
            route: route,
            title: "发现规则测试",
            subtitle: "优书网 · 正在编辑：发现规则",
            icon: .code,
            status: "已启用发现",
            statusTone: .good,
            presentation: .discoverSource,
            chipRows: [
                SettingsDemoChipRowData(title: "书源规则模块", chips: ["基本", "搜索", "详情", "目录", "正文", "发现", "高级"], selected: "发现")
            ],
            sections: [
                SettingsDemoSection(title: "发现规则字段", rows: [
                    row(.link, "exploreUrl", "https://example.com/rank/{{page}}"),
                    row(.list, "bookList", ".rank-list li"),
                    row(.text, "name", ".title@text"),
                    row(.people, "author", ".author@text"),
                    row(.image, "coverUrl", "img@src"),
                    row(.link, "bookUrl", "a@href")
                ]),
                SettingsDemoSection(title: "测试输入", rows: [
                    row(.link, "入口 URL", "https://example.com/rank/allvisit_1.html"),
                    row(.code, "HTML 片段", "<li class=\"book\">长夜余火</li>"),
                    row(.play, "执行", "测试入口")
                ]),
                SettingsDemoSection(title: "测试结果", rows: [
                    row(.check, "生成 5 个入口", "排行榜、分类、完本、最新、书单", tone: .good),
                    row(.check, "解析到 18 本书", "首条：长夜余火 · 爱潜水的乌贼", tone: .good)
                ])
            ],
            actions: [
                SettingsDemoAction(icon: .play, title: "测试入口"),
                SettingsDemoAction(icon: .check, title: "保存")
            ]
        )
    }

    private static func discoverSourceBulk(route: String) -> Self {
        Self(
            route: route,
            title: "发现源管理",
            subtitle: "选择启用发现的书源，批量启用、禁用或刷新入口",
            icon: .sourceStack,
            status: "已选 3 个",
            presentation: .discoverSource,
            searchPlaceholder: "搜索书源名称或分组",
            chipRows: [
                SettingsDemoChipRowData(title: "发现源筛选", chips: ["已启用发现", "有发现未启用", "需登录", "异常"], selected: "已启用发现")
            ],
            sourceRows: [
                sourceRow("优书网", "默认分组 · 120ms · 已启用发现", "可用", .good, true, true),
                sourceRow("起点导入", "正版 · 180ms · 已启用发现", "可用", .good, true, true),
                sourceRow("轻小说文库", "需登录 · 发现可用", "需处理", .warn, true, true),
                sourceRow("本地聚合源", "维护中 · 暂停发现", "暂停", .muted, false, false),
                sourceRow("失效示例源", "解析失败 · exploreUrl 异常", "需处理", .warn, false, false)
            ],
            sourceListTitle: "发现源列表",
            sourceListMode: .selection,
            actions: [
                SettingsDemoAction(icon: .check, title: "启用"),
                SettingsDemoAction(icon: .clear, title: "禁用"),
                SettingsDemoAction(icon: .refresh, title: "刷新")
            ]
        )
    }

    private static func sourceState(
        route: String,
        title: String,
        subtitle: String,
        status: String? = nil,
        statusTone: SettingsDemoTone = .normal,
        presentation: SettingsDemoPresentation = .source,
        metrics: [SettingsDemoMetric] = [],
        searchPlaceholder: String? = nil,
        chipRows: [SettingsDemoChipRowData] = [],
        sections: [SettingsDemoSection] = [],
        sourceRows: [SettingsDemoSourceRow] = [],
        sourceListTitle: String = "书源列表",
        sourceListMode: SettingsDemoSourceListMode = .plain,
        infoItems: [SettingsDemoInfoItem] = [],
        codeLines: [String] = [],
        actions: [SettingsDemoAction] = []
    ) -> Self {
        Self(
            route: route,
            title: title,
            subtitle: subtitle,
            icon: .sourceStack,
            status: status,
            statusTone: statusTone,
            presentation: presentation,
            metrics: metrics,
            searchPlaceholder: searchPlaceholder,
            chipRows: chipRows,
            sections: sections,
            sourceRows: sourceRows,
            sourceListTitle: sourceListTitle,
            sourceListMode: sourceListMode,
            infoItems: infoItems,
            codeLines: codeLines,
            actions: actions
        )
    }

    private static func row(
        _ icon: ReaderAssetIcon,
        _ title: String,
        _ subtitle: String? = nil,
        detail: String? = nil,
        tone: SettingsDemoTone = .normal
    ) -> SettingsDemoRow {
        SettingsDemoRow(icon: icon, title: title, subtitle: subtitle, detail: detail, tone: tone)
    }

    private static func switchRow(
        _ icon: ReaderAssetIcon,
        _ title: String,
        subtitle: String? = nil,
        enabled: Bool
    ) -> SettingsDemoRow {
        SettingsDemoRow(icon: icon, title: title, subtitle: subtitle, detail: enabled ? "开" : "关", tone: enabled ? .good : .muted, showsSwitch: true, switchOn: enabled)
    }

    private static func progressRow(
        _ icon: ReaderAssetIcon,
        _ title: String,
        _ subtitle: String,
        _ detail: String,
        _ tone: SettingsDemoTone
    ) -> SettingsDemoRow {
        SettingsDemoRow(icon: icon, title: title, subtitle: subtitle, detail: detail, tone: tone, progress: progressValue(from: detail))
    }

    private static func progressValue(from text: String) -> Double? {
        guard let number = Double(text.replacingOccurrences(of: "%", with: "")) else { return nil }
        return min(max(number / 100.0, 0), 1)
    }

    private static func sourceRow(
        _ title: String,
        _ meta: String,
        _ status: String,
        _ tone: SettingsDemoTone,
        _ enabled: Bool,
        _ selected: Bool
    ) -> SettingsDemoSourceRow {
        SettingsDemoSourceRow(title: title, meta: meta, status: status, tone: tone, enabled: enabled, selected: selected)
    }

    private static func webdavSection(title: String) -> SettingsDemoSection {
        SettingsDemoSection(title: title, rows: [
            row(.link, "服务器地址", "https://dav.example.com/reader/backup"),
            row(.people, "账号", "reader@example.com"),
            row(.shield, "密码", "reader-demo-password"),
            row(.folder, "同步目录", "/ReaderBackup/ReaderAndroid")
        ])
    }

    private static let backupRows: [SettingsDemoRow] = [
        row(.cloud, "自动备份", "WebDAV · 2026-06-23 08:00 · 完整备份", detail: "最新", tone: .good),
        row(.folder, "手动备份", "本地 · 2026-06-23 10:30 · 完整备份", detail: "本机", tone: .info),
        row(.cloud, "夜间备份", "WebDAV · 2026-06-21 22:30 · 书架与设置", detail: "局部", tone: .warn),
        row(.clock, "阅读进度快照", "本地 · 2026-06-20 09:40 · 阅读进度", detail: "进度", tone: .muted)
    ]

    private static let sourceMetrics: [SettingsDemoMetric] = [
        SettingsDemoMetric(icon: .source, value: "12", label: "个书源"),
        SettingsDemoMetric(icon: .check, value: "8", label: "个启用"),
        SettingsDemoMetric(icon: .warning, value: "4", label: "个异常"),
        SettingsDemoMetric(icon: .clock, value: "10:30", label: "刚刚检测")
    ]

    private static let sourceFilterRows: [SettingsDemoChipRowData] = [
        SettingsDemoChipRowData(title: "状态", chips: ["全部", "已启用", "异常", "未检测", "自定义"], selected: "全部"),
        SettingsDemoChipRowData(title: "分组", chips: ["全部分组", "玄幻书源", "起点导入", "测试书源"], selected: "全部分组")
    ]

    private static let sourceItems: [SettingsDemoSourceRow] = [
        sourceRow("起点中文网", "qidian.com · 起点导入", "可用", .good, true, false),
        sourceRow("笔趣阁", "biquge.example · 玄幻书源", "异常", .warn, true, true),
        sourceRow("本地导入源", "本地文件导入 · 自定义", "未检测", .muted, false, false),
        sourceRow("测试书源", "test.example · 测试书源", "可用", .good, true, false),
        sourceRow("旧规则源", "old.example · 自定义", "异常", .warn, true, true),
        sourceRow("失效示例源", "dead.example · 测试书源", "异常", .warn, false, true)
    ]
}

private struct SettingsDemoMetric: Identifiable {
    let id: String
    let icon: ReaderAssetIcon
    let value: String
    let label: String

    init(icon: ReaderAssetIcon, value: String, label: String) {
        self.id = "\(value)-\(label)"
        self.icon = icon
        self.value = value
        self.label = label
    }
}

private struct SettingsDemoChipRowData: Identifiable {
    let id: String
    let title: String
    let chips: [String]
    let selected: String

    init(title: String, chips: [String], selected: String) {
        self.id = title
        self.title = title
        self.chips = chips
        self.selected = selected
    }
}

private struct SettingsDemoSection: Identifiable {
    let id: String
    let title: String
    let rows: [SettingsDemoRow]

    init(title: String, rows: [SettingsDemoRow]) {
        self.id = title
        self.title = title
        self.rows = rows
    }
}

private struct SettingsDemoRow: Identifiable {
    let id: String
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String?
    let detail: String?
    let tone: SettingsDemoTone
    let showsSwitch: Bool
    let switchOn: Bool
    let progress: Double?

    init(
        icon: ReaderAssetIcon,
        title: String,
        subtitle: String?,
        detail: String?,
        tone: SettingsDemoTone,
        showsSwitch: Bool = false,
        switchOn: Bool = false,
        progress: Double? = nil
    ) {
        self.id = "\(title)-\(subtitle ?? "")-\(detail ?? "")"
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.tone = tone
        self.showsSwitch = showsSwitch
        self.switchOn = switchOn
        self.progress = progress
    }
}

private enum SettingsDemoSourceListMode: Equatable {
    case plain
    case selection
}

private struct SettingsDemoSourceRow: Identifiable {
    let id: String
    let title: String
    let meta: String
    let status: String
    let tone: SettingsDemoTone
    let enabled: Bool
    let selected: Bool

    init(title: String, meta: String, status: String, tone: SettingsDemoTone, enabled: Bool, selected: Bool) {
        self.id = "\(title)-\(meta)"
        self.title = title
        self.meta = meta
        self.status = status
        self.tone = tone
        self.enabled = enabled
        self.selected = selected
    }
}

private struct SettingsDemoInfoItem: Identifiable {
    let id: String
    let label: String
    let value: String

    init(label: String, value: String) {
        self.id = label
        self.label = label
        self.value = value
    }
}

private struct SettingsDemoAction: Identifiable {
    let id: String
    let icon: ReaderAssetIcon
    let title: String
    let tone: SettingsDemoTone

    init(icon: ReaderAssetIcon, title: String, tone: SettingsDemoTone = .normal) {
        self.id = title
        self.icon = icon
        self.title = title
        self.tone = tone
    }
}

private struct SettingsDemoHero: View {
    let state: SettingsDemoRouteState

    var body: some View {
        ReaderCard {
            HStack(spacing: 12) {
                ReaderIcon(state.icon, size: 22, accessibilityLabel: state.title)
                    .frame(width: 42, height: 42)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(state.title)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .lineLimit(1)
                    Text(state.subtitle)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let status = state.status {
                    SettingsDemoBadge(text: status, tone: state.statusTone)
                }
            }
        }
    }
}

private struct SettingsDemoMetricGrid: View {
    let metrics: [SettingsDemoMetric]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 8)], spacing: 8) {
            ForEach(metrics) { metric in
                VStack(alignment: .leading, spacing: 6) {
                    ReaderIcon(metric.icon, size: 18, accessibilityLabel: metric.label)
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    Text(metric.value)
                        .font(.system(size: 16, weight: .heavy).monospacedDigit())
                        .lineLimit(1)
                    Text(metric.label)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                        .fill(ReaderDesignTokens.Color.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                                .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                        )
                )
            }
        }
    }
}

private struct SettingsDemoSearchField: View {
    let placeholder: String

    var body: some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            ReaderIcon(.search, size: 18, accessibilityLabel: "搜索")
                .frame(width: ReaderDesignTokens.settingsRowIconColumn)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            Text(placeholder)
                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.settingsSearchFieldHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(ReaderDesignTokens.Color.controlBackground)
        )
    }
}

private struct SettingsDemoChipRow: View {
    let row: SettingsDemoChipRowData

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(row.title)
                .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .heavy))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .lineLimit(1)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ReaderDesignTokens.rssModeRowGap) {
                    ForEach(row.chips, id: \.self) { chip in
                        PillChip(chip, isSelected: chip == row.selected)
                    }
                }
            }
        }
    }
}

private struct SettingsDemoSectionView: View {
    let section: SettingsDemoSection

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                Text(section.title)
                    .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .lineLimit(1)

                ForEach(section.rows) { row in
                    SettingsDemoRowView(row: row)
                }
            }
        }
    }
}

private struct SettingsDemoRowView: View {
    let row: SettingsDemoRow

    var body: some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            ReaderIcon(row.icon, size: 18, accessibilityLabel: row.title)
                .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)
                .foregroundColor(row.tone == .danger ? row.tone.foreground : ReaderDesignTokens.Color.primaryDark)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                    .foregroundColor(row.tone == .danger && row.subtitle == nil ? row.tone.foreground : .primary)
                    .lineLimit(2)
                if let subtitle = row.subtitle {
                    Text(subtitle)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let progress = row.progress {
                    ProgressView(value: progress)
                        .tint(row.tone.foreground)
                        .frame(maxWidth: 168)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if row.showsSwitch {
                SettingsDemoSwitch(isOn: row.switchOn)
            } else if let detail = row.detail {
                SettingsDemoBadge(text: detail, tone: row.tone)
            } else {
                ReaderIcon(.chevron, size: 14)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
        .frame(minHeight: ReaderDesignTokens.settingsRowMinHeight)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(ReaderDesignTokens.Color.controlBackground.opacity(row.tone == .danger ? 0.92 : 0.58))
        )
    }
}

private struct SettingsDemoSourceListView: View {
    let title: String
    let rows: [SettingsDemoSourceRow]
    let mode: SettingsDemoSourceListMode

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                ForEach(rows) { row in
                    SettingsDemoSourceRowView(row: row, mode: mode)
                }
            }
        }
    }
}

private struct SettingsDemoSourceRowView: View {
    let row: SettingsDemoSourceRow
    let mode: SettingsDemoSourceListMode

    var body: some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            if mode == .selection {
                SettingsDemoSelectionMark(isSelected: row.selected)
            } else {
                ReaderIcon(.sourceStack, size: 18, accessibilityLabel: row.title)
                    .frame(width: ReaderDesignTokens.settingsRowIconColumn)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                    .lineLimit(1)
                Text(row.meta)
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SettingsDemoBadge(text: row.status, tone: row.tone)
            SettingsDemoSwitch(isOn: row.enabled)
        }
        .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
        .frame(minHeight: ReaderDesignTokens.sourceRowMinHeight)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(row.selected ? ReaderDesignTokens.Color.primary.opacity(0.10) : ReaderDesignTokens.Color.controlBackground.opacity(0.58))
        )
    }
}

private struct SettingsDemoInfoGrid: View {
    let items: [SettingsDemoInfoItem]

    var body: some View {
        ReaderCard {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 8) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.label)
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.secondary)
                        Text(item.value)
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm)
                            .fill(ReaderDesignTokens.Color.controlBackground)
                    )
                }
            }
        }
    }
}

private struct SettingsDemoCodeBlock: View {
    let lines: [String]

    var body: some View {
        ReaderCard {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text("\(String(format: "%02d", index + 1))  \(line)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct SettingsDemoDeleteDialog: View {
    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ReaderIcon(.trash, size: 24, accessibilityLabel: "删除")
                        .foregroundColor(SettingsDemoTone.danger.foreground)
                    Text("删除书源？")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(SettingsDemoTone.danger.foreground)
                }

                Text("将删除已选 3 个书源。不会删除书架书籍，但这些书源将不再参与搜索、发现和换源。")
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)

                SettingsDemoRowView(
                    row: SettingsDemoRow(
                        icon: .log,
                        title: "同时清除相关检测日志",
                        subtitle: nil,
                        detail: "可选",
                        tone: .warn
                    )
                )

                HStack(spacing: 10) {
                    SettingsDemoActionButton(action: SettingsDemoAction(icon: .close, title: "取消"))
                    SettingsDemoActionButton(action: SettingsDemoAction(icon: .trash, title: "删除", tone: .danger))
                }
            }
        }
    }
}

private struct SettingsDemoBottomActions: View {
    let actions: [SettingsDemoAction]

    var body: some View {
        if actions.count == 2, let first = actions.first, let second = actions.dropFirst().first {
            BottomFixedActionRow {
                SettingsDemoActionButton(action: first)
            } trailing: {
                SettingsDemoActionButton(action: second)
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ReaderDesignTokens.rssModeRowGap) {
                    ForEach(actions) { action in
                        SettingsDemoActionButton(action: action)
                            .frame(minWidth: 86, minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
                    }
                }
                .padding(.horizontal, ReaderDesignTokens.cardPadding)
                .frame(minHeight: ReaderDesignTokens.bottomFixedActionRowMinHeight)
            }
            .background(
                LinearGradient(
                    colors: [
                        ReaderDesignTokens.Color.paperSolid.opacity(0),
                        ReaderDesignTokens.Color.paperSolid
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

private struct SettingsDemoActionButton: View {
    let action: SettingsDemoAction

    var body: some View {
        Button {} label: {
            HStack(spacing: 6) {
                ReaderIcon(action.icon, size: 16, accessibilityLabel: action.title)
                Text(action.title)
                    .font(.system(size: 12, weight: .heavy))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
            .foregroundColor(action.tone == .danger ? .white : ReaderDesignTokens.Color.primaryDark)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(action.tone == .danger ? SettingsDemoTone.danger.foreground : ReaderDesignTokens.Color.chipBackground)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsDemoBadge: View {
    let text: String
    let tone: SettingsDemoTone

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .lineLimit(1)
            .foregroundColor(tone.foreground)
            .padding(.horizontal, 8)
            .frame(minHeight: 24)
            .background(Capsule().fill(tone.background))
    }
}

private struct SettingsDemoSwitch: View {
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
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : [.isButton])
    }
}

private struct SettingsDemoSelectionMark: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.chipBackground)
            if isSelected {
                ReaderIcon(.check, size: 14, accessibilityLabel: "已选")
                    .foregroundColor(.white)
            }
        }
        .frame(width: 24, height: 24)
    }
}
