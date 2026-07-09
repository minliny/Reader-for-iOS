import Foundation
import ReaderCoreModels

/// Bookshelf fixture translated from `Reader UI/frontend-demo-optimized/fixture.js`.
///
/// This is development/demo data, not production sync state. It exists so the
/// native prototype can render the same default content state as the canonical
/// HTML demo when the local bookshelf store is empty.
public enum DemoBookshelfFixture {
    public static let sourceID = "frontend-demo"
    public static let sourceName = "Frontend Demo"

    public static let items: [BookshelfItem] = [
        item("long-night", "长夜余火", "爱潜水的乌贼", "第 32 章 雨夜", 0.38, "longNight", offset: 11),
        item("mystery-lord", "诡秘之主", "爱潜水的乌贼", "第 1426 章", 0.58, "mysteryLord", offset: 10),
        item("bright-moon", "明朝那些事儿", "当年明月", "第 218 章", 0.58, "brightMoon", offset: 9),
        item("three-body", "三体", "刘慈欣", "65%", 0.65, "threeBody", offset: 8),
        item("renjian-cihua", "人间词话", "王国维", "卷上 · 境界", 0.24, "renjian", offset: 7),
        item("android-notes", "Android 开发笔记", "本地文档", "Compose Shell 结构", 0.12, "androidNotes", sourceID: "local-book", sourceName: "本地文档", offset: 6),
        item("old-echo", "旧日回响", "离线书库", "第 18 章", 0.41, "longNight", sourceID: "offline-library", sourceName: "离线书库", offset: 5),
        item("between-stars", "群星之间", "本地导入", "第 7 章", 0.16, "threeBody", sourceID: "local-book", sourceName: "本地导入", offset: 4),
        item("lighthouse-fog", "灯塔与雾", "书源同步", "第 51 章", 0.73, "brightMoon", sourceID: "source-sync", sourceName: "书源同步", offset: 3),
        item("paper-city", "纸上城市", "默认分组", "第 12 章", 0.33, "mysteryLord", offset: 2),
        item("long-title", "长标题测试：这本书的名字很长需要两行截断", "排版样本", "很长的章节名称需要保持单行省略", 0.08, "renjian", offset: 1)
    ]

    private static func item(
        _ id: String,
        _ title: String,
        _ author: String,
        _ chapter: String,
        _ progress: Double,
        _ coverKey: String,
        sourceID: String = DemoBookshelfFixture.sourceID,
        sourceName: String = DemoBookshelfFixture.sourceName,
        offset: TimeInterval
    ) -> BookshelfItem {
        let added = Date(timeIntervalSince1970: 1_800_000_000 - offset * 600)
        let updated = Date(timeIntervalSince1970: 1_800_010_000 + offset * 600)
        return BookshelfItem(
            id: "demo-\(id)",
            sourceID: sourceID,
            sourceName: sourceName,
            bookURL: "demo://book/\(id)",
            title: title,
            author: author,
            coverURL: "demo-cover://\(coverKey)",
            latestChapter: chapter,
            addedAt: added,
            updatedAt: updated,
            lastReadChapterTitle: chapter,
            lastReadChapterURL: "demo://book/\(id)/chapter/current",
            readingProgress: progress,
            localChapterList: chapters(for: id)
        )
    }

    private static func chapters(for id: String) -> [TOCItem] {
        [
            TOCItem(chapterTitle: "第 30 章 旧日", chapterURL: "demo://book/\(id)/chapter/30", chapterIndex: 0),
            TOCItem(chapterTitle: "第 31 章 归途", chapterURL: "demo://book/\(id)/chapter/31", chapterIndex: 1),
            TOCItem(chapterTitle: "第 32 章 雨夜", chapterURL: "demo://book/\(id)/chapter/current", chapterIndex: 2),
            TOCItem(chapterTitle: "第 33 章 灯塔", chapterURL: "demo://book/\(id)/chapter/33", chapterIndex: 3)
        ]
    }
}
