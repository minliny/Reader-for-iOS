import Foundation
import ReaderUIContract

/// Explicit SwiftUI renderer families for the 35 routes added by Reader UI 2.5.
///
/// These are domain-shaped renderers, not a generic catch-all. Every family is consumed by an
/// exhaustive switch in `ReaderContract25RouteScreen` and uses the canonical shell for the route.
enum ReaderContract25Renderer: String, CaseIterable, Sendable {
    case readerWorkspaceState
    case readerReplacementState
    case sourceSwitchState
    case readerContentState
    case localImportState

    /// These three ReaderShell families share the production full-page reading surface. Their
    /// background is owned by the Host-injected ReaderThemePalette, never by route fixture state.
    var usesHostReadingBackground: Bool {
        switch self {
        case .readerWorkspaceState, .readerReplacementState, .readerContentState:
            return true
        case .sourceSwitchState, .localImportState:
            return false
        }
    }
}

struct ReaderContract25RouteAction: Equatable, Sendable {
    let label: String
    let target: ReaderUIContract.RouteId
}

struct ReaderContract25RoutePage: Equatable, Identifiable, Sendable {
    let routeId: ReaderUIContract.RouteId
    let title: String
    let shell: ReaderUIContract.RouteShell
    let renderer: ReaderContract25Renderer
    let message: String
    let actions: [ReaderContract25RouteAction]

    var id: ReaderUIContract.RouteId { routeId }
}

enum ReaderContract25RouteRegistry {
    private static func action(
        _ label: String,
        _ target: ReaderUIContract.RouteId
    ) -> ReaderContract25RouteAction {
        ReaderContract25RouteAction(label: label, target: target)
    }

    private static func page(
        _ routeId: ReaderUIContract.RouteId,
        _ title: String,
        _ shell: ReaderUIContract.RouteShell,
        _ renderer: ReaderContract25Renderer,
        _ message: String,
        _ actions: [ReaderContract25RouteAction]
    ) -> ReaderContract25RoutePage {
        ReaderContract25RoutePage(
            routeId: routeId,
            title: title,
            shell: shell,
            renderer: renderer,
            message: message,
            actions: actions
        )
    }

    /// Authored 1:1 against generated `RouteId` cases. A rename/removal is therefore a compile
    /// failure, while exact membership tests catch a newly generated case that lacks a renderer.
    static let all: [ReaderContract25RoutePage] = [
        page(.readerFontImportConfirm, "字体导入确认", .readerShell, .readerWorkspaceState,
             "确认导入所选字体；应用后阅读排版会重新计算。",
             [action("取消", .readerFullFont), action("确认导入", .readerFullFont)]),
        page(.readerFontDeleteConfirm, "字体删除确认", .readerShell, .readerWorkspaceState,
             "删除字体后不可恢复；正在使用该字体的主题会回退到默认字体。",
             [action("取消", .readerFullFont), action("确认删除", .readerFullFont)]),
        page(.readerFontFallback, "字体失效回退", .readerShell, .readerWorkspaceState,
             "当前字体文件不可用，已安全回退到系统字体并保留排版参数。",
             [action("返回字体管理", .readerFullFont)]),
        page(.readerThemeNew, "新建主题", .readerShell, .readerWorkspaceState,
             "从当前阅读背景、文字颜色和亮度参数创建自定义主题。",
             [action("返回", .readerFullTheme), action("从编辑器创建", .readerFullThemeEdit)]),
        page(.readerThemeDeleteConfirm, "主题删除确认", .readerShell, .readerWorkspaceState,
             "确认删除自定义主题；当前阅读会切换到内置主题。",
             [action("取消", .readerFullTheme), action("确认删除", .readerFullTheme)]),
        page(.readerTypographyResetConfirm, "排版恢复默认确认", .readerShell, .readerWorkspaceState,
             "字号、行距、段距和页边距将恢复默认值。",
             [action("取消", .readerFullLayout), action("恢复默认", .readerFullLayout)]),

        page(.readerReplaceDeleteConfirm, "删除替换规则确认", .readerShell, .readerReplacementState,
             "删除后不可恢复；其他替换规则和原始正文不会被修改。",
             [action("取消", .contentReplacement), action("确认删除", .contentReplacement)]),
        page(.readerReplaceApplyResult, "替换规则应用结果", .readerShell, .readerReplacementState,
             "已按规则顺序应用到当前正文，可返回管理或继续阅读。",
             [action("返回规则管理", .contentReplacement), action("继续阅读", .immersiveReading)]),
        page(.readerReplaceImportExport, "替换规则导入导出", .readerShell, .readerReplacementState,
             "以 JSON 预览、导入或导出替换规则，并在提交前校验规则格式。",
             [action("返回规则管理", .contentReplacement)]),
        page(.readerReplacePage, "内容替换规则管理", .readerShell, .readerReplacementState,
             "管理规则顺序、启用状态、作用范围，并预览原文与替换后正文。",
             [action("详细预览", .readerReplacePreview), action("返回阅读", .immersiveReading)]),
        page(.readerReplacePreview, "替换规则预览", .readerShell, .readerReplacementState,
             "并排对比原文与替换后正文，展示本次应用的规则列表。",
             [action("返回规则管理", .contentReplacement), action("继续阅读", .immersiveReading)]),

        page(.sourceSwitchEmpty, "换源空结果", .flowShell, .sourceSwitchState,
             "没有找到可用候选书源；可重新加载或返回阅读。",
             [action("重新加载", .sourceSwitch), action("返回阅读", .reader)]),
        page(.sourceSwitchError, "换源加载失败", .flowShell, .sourceSwitchState,
             "候选书源加载失败，请检查网络或书源状态。",
             [action("重试加载", .sourceSwitch), action("返回阅读", .reader)]),
        page(.sourceSwitchTimeout, "换源超时", .flowShell, .sourceSwitchState,
             "候选书源请求超时，可能是网络延迟或来源响应过慢。",
             [action("重试加载", .sourceSwitch), action("返回阅读", .reader)]),
        page(.sourceSwitchLoading, "换源切换中", .flowShell, .sourceSwitchState,
             "正在重新拉取目录与正文，当前阅读位置保持不变。",
             [action("取消切换", .sourceSwitchRollback)]),
        page(.sourceSwitchRollback, "换源失败回滚", .flowShell, .sourceSwitchState,
             "目标书源切换失败，已回滚到原书源并保留阅读进度。",
             [action("重新选择书源", .sourceSwitch), action("返回阅读", .reader)]),
        page(.sourceSwitchPreview, "换源预览", .flowShell, .sourceSwitchState,
             "预览候选书源的最新章节、正文片段和延迟后再确认切换。",
             [action("返回列表", .sourceSwitch), action("确认换源", .sourceSwitchLoading)]),

        page(.readerTocLoading, "目录加载中", .readerShell, .readerContentState,
             "正在从书源拉取章节列表。", [action("返回控制层", .reader)]),
        page(.readerTocOffline, "目录离线", .readerShell, .readerContentState,
             "当前网络不可用，无法更新目录。",
             [action("重试", .tocBookmarks), action("返回控制层", .reader)]),
        page(.readerTocError, "目录解析错误", .readerShell, .readerContentState,
             "书源返回的章节列表无法解析，可重试或更换书源。",
             [action("重试", .tocBookmarks), action("返回控制层", .reader)]),
        page(.readerContentLoading, "正文加载中", .readerShell, .readerContentState,
             "正在加载正文，并保持当前章节上下文。", [action("返回控制层", .reader)]),
        page(.readerContentOffline, "正文离线", .readerShell, .readerContentState,
             "当前网络不可用，无法拉取本章正文。",
             [action("重试", .immersiveReading), action("返回控制层", .reader)]),
        page(.readerContentError, "正文解析错误", .readerShell, .readerContentState,
             "本章正文解析失败，可能是编码或来源异常。",
             [action("重试", .immersiveReading), action("返回控制层", .reader)]),
        page(.readerPageBoundaryFirst, "首章首页边界", .readerShell, .readerContentState,
             "已是第一章，没有更早的章节。",
             [action("返回控制层", .reader), action("继续阅读", .immersiveReading)]),
        page(.readerPageBoundaryLast, "末章末页边界", .readerShell, .readerContentState,
             "已是最后一章，没有更多正文。",
             [action("返回控制层", .reader), action("回到首页", .immersiveReading)]),
        page(.readerProgressRestore, "阅读进度恢复", .readerShell, .readerContentState,
             "已恢复到上次阅读章节、字符锚点和分页签名。",
             [action("继续阅读", .immersiveReading), action("从控制层开始", .reader)]),
        page(.readerBackgroundRestore, "后台恢复", .readerShell, .readerContentState,
             "应用从后台恢复；可重载正文并保留当前位置。",
             [action("立即重载", .immersiveReading), action("返回控制层", .reader)]),

        page(.importPermissionDenied, "导入权限拒绝", .libraryShell, .localImportState,
             "存储权限被拒绝，需要授权读取所选 EPUB / TXT 文件。",
             [action("退出导入", .bookshelf), action("去设置开启", .localImport)]),
        page(.importFormatUnsupported, "导入格式不支持", .libraryShell, .localImportState,
             "所选文件格式不受支持；当前支持 EPUB 与 TXT。",
             [action("取消", .bookshelf), action("重新选择", .localImport)]),
        page(.importEmptyFile, "导入空文件", .libraryShell, .localImportState,
             "文件为空或不可读，请检查文件内容与访问权限。",
             [action("取消", .bookshelf), action("重新选择", .localImport)]),
        page(.importParsing, "导入解析中", .libraryShell, .localImportState,
             "正在读取文件、解析元数据并识别章节结构。",
             [action("取消导入", .localImport), action("下一步", .importDuplicate)]),
        page(.importDuplicate, "导入重复项", .libraryShell, .localImportState,
             "逐项选择保留原书、覆盖或跳过重复书籍。",
             [action("上一步", .importParsing), action("下一步", .importConflictResolve)]),
        page(.importConflictResolve, "导入冲突处理", .libraryShell, .localImportState,
             "对本地文件与库内书籍的差异选择覆盖、跳过或保留两份。",
             [action("上一步", .importDuplicate), action("应用并导入", .importParsing)]),
        page(.importPartialSuccess, "导入部分成功", .libraryShell, .localImportState,
             "3 本成功、1 本失败；可重试失败项或查看完整结果。",
             [action("查看详情", .importResultDetail), action("返回书架", .bookshelf)]),
        page(.importResultDetail, "导入结果详情", .libraryShell, .localImportState,
             "按成功、失败和跳过分组展示本次导入明细。",
             [action("再次导入", .localImport), action("返回书架", .bookshelf)])
    ]

    private static let byRouteId: [ReaderUIContract.RouteId: ReaderContract25RoutePage] = {
        let pages = Dictionary(uniqueKeysWithValues: all.map { ($0.routeId, $0) })
        precondition(pages.count == all.count, "Reader UI 2.5 route registry contains duplicates")
        return pages
    }()

    static var routeIds: Set<ReaderUIContract.RouteId> { Set(byRouteId.keys) }

    static func page(for routeId: ReaderUIContract.RouteId) -> ReaderContract25RoutePage? {
        byRouteId[routeId]
    }

    static func renderer(for routeId: ReaderUIContract.RouteId) -> ReaderContract25Renderer? {
        byRouteId[routeId]?.renderer
    }
}

/// Native shell lookup extends the generated motion-policy table with the 2.5 route additions.
/// The generated table remains authoritative for the original routes; only the explicitly typed
/// 35-route registry fills its currently missing shell metadata.
enum ReaderNativeRouteShellLookup {
    static func shell(for routeId: String) -> ReaderUIContract.RouteShell? {
        if let generatedRouteId = ReaderUIContract.RouteId(rawValue: routeId) {
            if let page = ReaderContract30RouteRegistry.page(for: generatedRouteId) {
                return page.shell
            }
            if let page = ReaderContract25RouteRegistry.page(for: generatedRouteId) {
                return page.shell
            }
        }
        return ReaderUIContract.RouteShellLookup.shell(for: routeId)
    }
}

enum ReaderContract25NavigationOutcome: Equatable, Sendable {
    case rendered(ReaderUIContract.RouteId)
    case external(ReaderUIContract.RouteId)
}

/// Small value-state navigator shared by the production SwiftUI view and route-action tests.
struct ReaderContract25RouteNavigation: Equatable, Sendable {
    private(set) var currentRouteId: ReaderUIContract.RouteId

    init(initialRouteId: ReaderUIContract.RouteId) {
        precondition(ReaderContract25RouteRegistry.page(for: initialRouteId) != nil)
        self.currentRouteId = initialRouteId
    }

    mutating func perform(_ action: ReaderContract25RouteAction) -> ReaderContract25NavigationOutcome {
        if ReaderContract25RouteRegistry.page(for: action.target) != nil {
            currentRouteId = action.target
            return .rendered(action.target)
        }
        return .external(action.target)
    }
}
