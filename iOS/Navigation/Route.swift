import Foundation
import ReaderCoreModels

public enum Route: Hashable {
    case home
    case bookSourceImport
    case search
    case toc(bookTitle: String, bookAuthor: String?)
    case content(chapterTitle: String)
    case webdavSettings
    case bookshelf
    case bookSources

    public var title: String {
        switch self {
        case .home:
            return "首页"
        case .bookSourceImport:
            return "导入书源"
        case .search:
            return "搜索"
        case .toc(let bookTitle, _):
            return bookTitle
        case .content(let chapterTitle):
            return chapterTitle
        case .webdavSettings:
            return "WebDAV 备份"
        case .bookshelf:
            return "书架"
        case .bookSources:
            return "书源管理"
        }
    }
}
