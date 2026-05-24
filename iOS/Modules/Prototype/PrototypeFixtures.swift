import Foundation

/// Prototype Gallery 全部 fixture 数据——不接真实网络/WebDAV/RSS
public enum PrototypeFixtures {

    // MARK: - Bookshelf

    public static let bookshelfBooks: [FixtureBook] = [
        FixtureBook(id: "b1", title: "凡人修仙传", author: "忘语", cover: "book.circle",
                    progress: 0.72, lastChapter: "第一千二百章 飞升", source: "千帆小说",
                    group: "仙侠"),
        FixtureBook(id: "b2", title: "仙逆", author: "耳根", cover: "book.circle.fill",
                    progress: 1.0, lastChapter: "终章", source: "笔趣阁",
                    group: "仙侠"),
        FixtureBook(id: "b3", title: "一剑独尊", author: "青鸾峰上", cover: "book.closed",
                    progress: 0.35, lastChapter: "第五百章 剑道", source: "全本书屋",
                    group: "玄幻"),
        FixtureBook(id: "b4", title: "诡秘之主", author: "爱潜水的乌贼", cover: "text.book.closed",
                    progress: 0.88, lastChapter: "第八章 神国", source: "起点",
                    group: "奇幻"),
        FixtureBook(id: "b5", title: "大王饶命", author: "会说话的肘子", cover: "book",
                    progress: 0.50, lastChapter: "第三百章 灵气复苏", source: "起点",
                    group: "都市"),
        FixtureBook(id: "b6", title: "全球高武", author: "老鹰吃小鸡", cover: "book.circle",
                    progress: 0.15, lastChapter: "第五十章 武者", source: "笔趣阁",
                    group: "都市"),
    ]

    // MARK: - Search

    public static let searchResults: [FixtureSearchResult] = [
        FixtureSearchResult(title: "凡人修仙传", author: "忘语",
                            intro: "一个普通的山村少年，机缘巧合之下踏入修仙界...",
                            sourceName: "千帆小说", sourceCount: 3),
        FixtureSearchResult(title: "凡人修仙传之仙界篇", author: "忘语",
                            intro: "韩立飞升仙界之后的全新冒险...",
                            sourceName: "笔趣阁", sourceCount: 5),
        FixtureSearchResult(title: "凡人修仙", author: "佚名",
                            intro: "...", sourceName: "无名书源", sourceCount: 1),
    ]

    public static let searchHistory: [String] = ["凡人修仙传", "仙逆", "剑来", "诡秘之主", "大王饶命"]

    // MARK: - Book Detail

    public static let bookDetail: FixtureBookDetail = FixtureBookDetail(
        title: "凡人修仙传", author: "忘语",
        cover: "book.circle", intro: "一个普通的山村少年韩立，机缘巧合之下踏入修仙界，历经千难万险，最终飞升仙界。这是一个关于坚持、智慧和勇气的故事。",
        sourceName: "千帆小说", latestChapter: "第一千二百零五章 仙界重逢",
        tocCount: 1205, lastUpdated: "2026-05-20"
    )

    // MARK: - Reader Content

    public static let readerContent: String = """
    夕阳西下，余晖洒落在这个偏僻的小山村里。

    在村东头的一间破旧茅屋内，一个十六七岁的少年正趴在桌上，借着昏暗的油灯灯光，一笔一划地写着什么。

    这个少年名叫韩立，是这个韩家村少有的几个适龄孩子之一。

    "韩立，天色不早了，你怎么还在写字？"一个中年妇人的声音从门外传来，"快来吃饭了！"

    "娘，来了！"韩立应了一声，放下毛笔，站起身来。

    他知道，家里的生活并不宽裕，能让他上学读书，已经是父母极大的付出了。

    "韩立啊，你也不小了，该为家里分担些了。"饭桌上，父亲韩铸叹了口气说道。

    韩立默默地点了点头。

    就在这时，屋外突然传来一阵喧哗声，接着一个气喘吁吁的声音响起："韩铸，不好了！你家韩立被山里的野狼给盯上了！"

    韩立一听，顿时脸色大变。
    """

    public static let chapterTitle: String = "第一章 山村少年"
    public static let batteryText: String = "82%"
    public static let timeText: String = "22:41"

    public static let tocItems: [FixtureTOCItem] = [
        FixtureTOCItem(title: "第一章 山村少年", level: 0, isCurrent: true, hasBookmark: false),
        FixtureTOCItem(title: "第二章 仙缘", level: 0, isCurrent: false, hasBookmark: true),
        FixtureTOCItem(title: "第三章 修炼入门", level: 0, isCurrent: false, hasBookmark: false),
        FixtureTOCItem(title: "第四章 宗门大选", level: 0, isCurrent: false, hasBookmark: false),
        FixtureTOCItem(title: "　　第一节 入门考核", level: 1, isCurrent: false, hasBookmark: false),
        FixtureTOCItem(title: "　　第二节 灵根测试", level: 1, isCurrent: false, hasBookmark: false),
        FixtureTOCItem(title: "第五章 初入灵泉", level: 0, isCurrent: false, hasBookmark: false),
        FixtureTOCItem(title: "第六章 灵泉修炼", level: 0, isCurrent: false, hasBookmark: false),
    ]

    public static let replaceRules: [FixtureReplaceRule] = [
        FixtureReplaceRule(pattern: "韩立", replacement: "主角", enabled: true),
        FixtureReplaceRule(pattern: "韩家村", replacement: "山村", enabled: false),
    ]

    // MARK: - Sources

    public static let sources: [FixtureSource] = [
        FixtureSource(id: "s1", name: "千帆小说", url: "https://www.qianfanxs.com",
                      enabled: true, lastTest: .success, group: "默认"),
        FixtureSource(id: "s2", name: "笔趣阁", url: "https://www.biquge.com",
                      enabled: true, lastTest: .success, group: "默认"),
        FixtureSource(id: "s3", name: "全本书屋", url: "https://www.qb5.tw",
                      enabled: false, lastTest: .failure("连接超时"), group: "备用"),
        FixtureSource(id: "s4", name: "无名书源", url: "https://example.com",
                      enabled: false, lastTest: .failure("解析失败"), group: "备用"),
    ]

    // MARK: - Discover

    public static let discoverSections: [FixtureDiscoverSection] = [
        FixtureDiscoverSection(title: "热门推荐", items: [
            FixtureDiscoverItem(title: "凡人修仙传", author: "忘语", tag: "仙侠"),
            FixtureDiscoverItem(title: "仙逆", author: "耳根", tag: "仙侠"),
            FixtureDiscoverItem(title: "剑来", author: "烽火戏诸侯", tag: "仙侠"),
        ]),
        FixtureDiscoverSection(title: "新书上架", items: [
            FixtureDiscoverItem(title: "龙王传说", author: "唐家三少", tag: "玄幻"),
            FixtureDiscoverItem(title: "星空之上", author: "辰东", tag: "科幻"),
        ]),
        FixtureDiscoverSection(title: "完本精选", items: [
            FixtureDiscoverItem(title: "斗罗大陆", author: "唐家三少", tag: "玄幻"),
            FixtureDiscoverItem(title: "盘龙", author: "我吃西红柿", tag: "奇幻"),
        ]),
    ]

    // MARK: - RSS

    public static let rssFeeds: [FixtureRSSFeed] = [
        FixtureRSSFeed(id: "r1", name: "起点中文网", url: "rss://example.com/qidian",
                       lastUpdate: "2026-05-23 10:30", unreadCount: 5, enabled: true),
        FixtureRSSFeed(id: "r2", name: "纵横中文网", url: "rss://example.com/zongheng",
                       lastUpdate: "2026-05-23 08:15", unreadCount: 0, enabled: true),
        FixtureRSSFeed(id: "r3", name: "17K小说网", url: "rss://example.com/17k",
                       lastUpdate: "2026-05-21 22:00", unreadCount: 12, enabled: false),
    ]

    public static let rssArticles: [FixtureRSSArticle] = [
        FixtureRSSArticle(title: "凡人修仙传更新至1205章", feedName: "起点中文网",
                          summary: "韩立飞升仙界后的新篇章...", date: "2026-05-23", isRead: false),
        FixtureRSSArticle(title: "仙逆番外发布", feedName: "纵横中文网",
                          summary: "耳根发布仙逆十周年番外...", date: "2026-05-22", isRead: true),
        FixtureRSSArticle(title: "一剑独尊最新章节", feedName: "17K小说网",
                          summary: "第五百零一章更新...", date: "2026-05-21", isRead: false),
    ]

    // MARK: - WebDAV

    public static let webdavConfig: FixtureWebDAVConfig = FixtureWebDAVConfig(
        serverURL: "https://dav.example.com/reader", username: "reader_user",
        isConnected: false
    )

    public static let remoteBooks: [FixtureRemoteBook] = [
        FixtureRemoteBook(name: "凡人修仙传.txt", size: "5.2 MB", status: .notDownloaded),
        FixtureRemoteBook(name: "仙逆.epub", size: "3.8 MB", status: .downloaded),
        FixtureRemoteBook(name: "剑来.txt", size: "8.1 MB", status: .downloading(progress: 0.6)),
    ]

    // MARK: - Sync

    public static let syncProgress: FixtureSyncProgress = FixtureSyncProgress(
        localProgress: "1205/1205 章", remoteProgress: "1200/1205 章",
        hasConflict: true, lastSync: "2026-05-22 20:00"
    )
}

// MARK: - Fixture Types

public struct FixtureBook: Identifiable {
    public let id: String; public let title: String; public let author: String
    public let cover: String; public let progress: Double; public let lastChapter: String
    public let source: String; public let group: String
}

public struct FixtureSearchResult: Identifiable {
    public let id = UUID(); public let title: String; public let author: String
    public let intro: String; public let sourceName: String; public let sourceCount: Int
}

public struct FixtureBookDetail {
    public let title: String; public let author: String; public let cover: String
    public let intro: String; public let sourceName: String; public let latestChapter: String
    public let tocCount: Int; public let lastUpdated: String
}

public struct FixtureTOCItem: Identifiable {
    public let id = UUID(); public let title: String; public let level: Int
    public let isCurrent: Bool; public let hasBookmark: Bool
}

public struct FixtureReplaceRule: Identifiable {
    public let id = UUID(); public let pattern: String; public let replacement: String
    public let enabled: Bool
}

public enum SourceTestStatus { case notRun, success, failure(String) }

public struct FixtureSource: Identifiable {
    public let id: String; public let name: String; public let url: String
    public let enabled: Bool; public let lastTest: SourceTestStatus; public let group: String
}

public struct FixtureDiscoverSection: Identifiable {
    public let id = UUID(); public let title: String; public let items: [FixtureDiscoverItem]
}

public struct FixtureDiscoverItem: Identifiable {
    public let id = UUID(); public let title: String; public let author: String; public let tag: String
}

public struct FixtureRSSFeed: Identifiable {
    public let id: String; public let name: String; public let url: String
    public let lastUpdate: String; public let unreadCount: Int; public let enabled: Bool
}

public struct FixtureRSSArticle: Identifiable {
    public let id = UUID(); public let title: String; public let feedName: String
    public let summary: String; public let date: String; public let isRead: Bool
}

public struct FixtureWebDAVConfig {
    public let serverURL: String; public let username: String; public let isConnected: Bool
}

public enum RemoteBookStatus { case notDownloaded, downloaded, downloading(progress: Double) }

public struct FixtureRemoteBook: Identifiable {
    public let id = UUID(); public let name: String; public let size: String
    public let status: RemoteBookStatus
}

public struct FixtureSyncProgress {
    public let localProgress: String; public let remoteProgress: String
    public let hasConflict: Bool; public let lastSync: String
}
