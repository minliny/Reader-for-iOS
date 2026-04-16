import Foundation
import ReaderCoreModels

public enum Route: Hashable {
    case home
    case bookSourceImport
    case search
    case toc(bookTitle: String, bookAuthor: String?)
    case content(chapterTitle: String)

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
        }
    }
}
