import Foundation
import ReaderCoreModels

/// 跨平台 Route 枚举
/// 真源：Reader-Core docs/cross-platform-ui/CROSS_PLATFORM_ROUTE_MATRIX.md
///
/// 主底栏目标：书架 / 发现 / 书源 / 我的
/// - 阅读不是主底栏模块（从书籍/历史/继续阅读进入）
/// - 设置归入"我的" tab，不是一级主底栏
public enum Route: Hashable {
    // MARK: - App Shell
    case home

    // MARK: - Bookshelf（书架）
    case bookshelf
    case bookshelfGroups
    case bookshelfImport

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
    case rssDetail(rssID: String)
    case rssSubscriptions

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
        case .rssDetail: return "RSS 详情"
        case .rssSubscriptions: return "订阅管理"
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
