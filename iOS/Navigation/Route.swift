import Foundation
import ReaderCoreModels

/// 跨平台 Route 枚举
/// 真源：Reader-Core docs/cross-platform-ui/CROSS_PLATFORM_ROUTE_MATRIX.md
///
/// 主底栏目标（契约 `CROSS_PLATFORM_UI_BASELINE.md`）：书架 / 发现 / RSS / 设置
/// - 阅读 / 搜索 / 书源管理都不是主底栏模块
/// - 书源管理、WebDAV、备份等归入「设置」Tab
/// - 沉浸阅读（immersive-reading）由 `ReaderContext` 承载语义，
///   `reader.entry.coverToImmersive` / `reader.entry.actionToImmersive` 入口见
///   `AppNavigationState.enterImmersiveReading`。
public enum Route: Hashable {
    // MARK: - App Shell
    case home

    // MARK: - Bookshelf（书架）
    case bookshelf
    case bookshelfGroups
    case bookshelfImport
    case bookBatchManagement

    // MARK: - Discover（发现）
    case discover

    // MARK: - Search（搜索）
    case search
    case searchResults(query: String)

    // MARK: - Book Detail（书籍详情）
    case bookDetail(bookURL: String, title: String, author: String?)
    case bookDetailToc(bookURL: String, title: String)
    case sourceSwitch(bookURL: String)

    // MARK: - Reader（阅读 - 非主底栏模块）
    case reader(bookID: String, chapterURL: String, chapterTitle: String)

    // MARK: - Chapter Content
    case content(chapterTitle: String)

    // MARK: - Source Management（书源管理）
    case bookSources
    case bookSourceImport
    case sourceDetail(sourceID: String)
    case sourceAdd
    case sourceEdit(sourceID: String)
    case sourceTestResult(sourceID: String)

    // MARK: - TOC
    case toc(bookTitle: String, bookAuthor: String?)

    // MARK: - RSS
    case rssList
    case rssSearch
    case rssDetail(rssID: String)
    case rssOriginal(url: String, title: String, sourceTitle: String)
    case rssOriginalBrowser(url: String, title: String, sourceTitle: String)
    case rssSubscriptions
    case rssSourceActions(sourceID: String, title: String?)
    case rssSourceEdit(sourceID: String, title: String?)
    case rssSourceDebug(sourceID: String, title: String?)
    case rssSourceVars(sourceID: String, title: String?)
    case rssSourceLogin(sourceID: String, title: String?)
    case rssSourceLoginWeb(sourceID: String, title: String?)
    case rssSourceLoginCookie(sourceID: String, title: String?)
    case rssSourceLoginClear(sourceID: String, title: String?)
    case rssSourceGroups
    case rssSourceGroupEdit(groupID: String, title: String?)
    case rssSourceBatch
    case rssSourceExport
    case rssSourceExportDetail(sourceID: String, title: String?)
    case rssSourceExportResult
    case rssSourcePin(sourceID: String, title: String?)
    case rssSourceDisable(sourceID: String, title: String?)
    case rssSourceBatchDisable
    case rssSourceImport
    case rssSourceImportDetail(sourceID: String, title: String?)
    case rssSourceImportResult
    case rssReadRecord(sourceID: String?, title: String?)
    case rssRecordClear
    case rssRuleSubscription
    case rssRuleSubscriptionDetail(subscriptionID: String, title: String?)
    case rssRuleSubscriptionEdit(subscriptionID: String, title: String?)
    case rssRuleSubscriptionTest(subscriptionID: String, title: String?)
    case rssRuleSubscriptionApply
    case rssFavoriteGroups
    case rssFavoriteGroupEdit(groupID: String, title: String?)
    case rssFavoriteClear
    case rssEmpty
    case rssError

    // MARK: - WebDAV / Sync
    case webdavSettings
    case webdavBooks
    case backupSettings
    case syncProgress

    // MARK: - Settings（归入"我的" tab）
    case settings
    case settingsReading
    case settingsAbout

    // MARK: - State Pages
    case stateError(message: String)
    case stateOffline
    case statePermission(permission: String)

    // MARK: - Debug / Prototype
    case prototypeGallery

    // MARK: - Display Title

    public var title: String {
        switch self {
        case .home: return "首页"
        case .bookshelf: return "书架"
        case .bookshelfGroups: return "分组管理"
        case .bookshelfImport: return "导入书籍"
        case .bookBatchManagement: return "批量管理"
        case .discover: return "发现"
        case .search: return "搜索"
        case .searchResults: return "搜索结果"
        case .bookDetail(_, let title, _): return title
        case .bookDetailToc: return "目录预览"
        case .sourceSwitch: return "换源"
        case .reader: return "阅读"
        case .content(let t): return t
        case .bookSources: return "书源管理"
        case .bookSourceImport: return "导入书源"
        case .sourceDetail: return "书源详情"
        case .sourceAdd: return "添加书源"
        case .sourceEdit: return "编辑书源"
        case .sourceTestResult: return "测试结果"
        case .toc(let title, _): return title
        case .rssList: return "RSS 订阅"
        case .rssSearch: return "RSS 搜索"
        case .rssDetail: return "RSS 阅读"
        case .rssOriginal: return "原文页面"
        case .rssOriginalBrowser: return "系统浏览器"
        case .rssSubscriptions: return "RSS 订阅管理"
        case .rssSourceActions: return "源操作"
        case .rssSourceEdit: return "RSS 源编辑"
        case .rssSourceDebug: return "规则调试"
        case .rssSourceVars: return "源变量"
        case .rssSourceLogin: return "源登录"
        case .rssSourceLoginWeb: return "网页登录"
        case .rssSourceLoginCookie: return "Cookie 提取"
        case .rssSourceLoginClear: return "清除登录"
        case .rssSourceGroups: return "RSS 分组"
        case .rssSourceGroupEdit: return "编辑 RSS 分组"
        case .rssSourceBatch: return "批量管理"
        case .rssSourceExport: return "导出订阅源"
        case .rssSourceExportDetail: return "导出预览"
        case .rssSourceExportResult: return "导出完成"
        case .rssSourcePin: return "置顶订阅源"
        case .rssSourceDisable: return "禁用订阅源"
        case .rssSourceBatchDisable: return "批量禁用"
        case .rssSourceImport: return "导入订阅源"
        case .rssSourceImportDetail: return "导入详情"
        case .rssSourceImportResult: return "导入完成"
        case .rssReadRecord: return "RSS 阅读记录"
        case .rssRecordClear: return "清空阅读记录"
        case .rssRuleSubscription: return "RSS 规则订阅"
        case .rssRuleSubscriptionDetail: return "规则订阅详情"
        case .rssRuleSubscriptionEdit: return "规则订阅编辑"
        case .rssRuleSubscriptionTest: return "规则订阅测试"
        case .rssRuleSubscriptionApply: return "应用订阅更新"
        case .rssFavoriteGroups: return "RSS 收藏分组"
        case .rssFavoriteGroupEdit: return "编辑收藏分组"
        case .rssFavoriteClear: return "清空收藏分组"
        case .rssEmpty: return "RSS 空状态"
        case .rssError: return "RSS 错误状态"
        case .webdavSettings: return "WebDAV 备份"
        case .webdavBooks: return "远程书籍"
        case .backupSettings: return "备份设置"
        case .syncProgress: return "同步进度"
        case .settings: return "设置"
        case .settingsReading: return "阅读设置"
        case .settingsAbout: return "关于"
        case .stateError: return "错误"
        case .stateOffline: return "离线"
        case .statePermission: return "权限"
        case .prototypeGallery: return "[DEBUG] Prototype Gallery"
        }
    }
}
