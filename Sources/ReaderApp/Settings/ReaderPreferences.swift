import ReaderDesign
import SwiftUI

enum ReaderAppearance: String, CaseIterable {
    case system, day, night
    var label: String { switch self { case .system: "跟随系统"; case .day: "日间"; case .night: "夜间" } }
    var scheme: ColorScheme? { switch self { case .system: nil; case .day: .light; case .night: .dark } }
    func night(system: ColorScheme) -> Bool { (scheme ?? system) == .dark }
}

enum ShelfSort: String, CaseIterable {
    case added, read, title
    var label: String { switch self { case .added: "加入时间"; case .read: "最近阅读"; case .title: "书名" } }
}

enum ReadingMode: String, CaseIterable {
    case pages, scroll
    var label: String { self == .pages ? "分页" : "滚动" }
}

struct ReadingPreferences: Equatable {
    var paperId: String = ReaderPaper.all[0].id
    var fontSize: Double = ReaderDesignMetrics.readerBody.fontSize
    var lineSpacing: Double = ReaderDesignMetrics.readerBody.lineHeight / ReaderDesignMetrics.readerBody.fontSize
    var letterSpacing: Double = 0
    var mode: ReadingMode = .pages

    var paper: ReaderPaper { ReaderPaper(id: paperId) }
    var webStyle: EbookStyle {
        let lineHeight = fontSize * lineSpacing
        return EbookStyle(fontSize: fontSize, lineHeight: lineHeight,
                          background: paper.webBackground, foreground: paper.webForeground, dark: paper.isDark)
    }
}
