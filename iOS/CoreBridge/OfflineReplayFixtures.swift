import Foundation
import ReaderCoreModels

/// Phase 4B: Offline Replay Fixtures — 模拟真实网络响应但不接网络
public enum OfflineReplayFixtures {

    // MARK: - Book Source

    public static let bookSource: BookSource = BookSource(
        id: "replay-source-001",
        bookSourceName: "离线书源示例",
        bookSourceUrl: "https://offline.example.com",
        bookSourceGroup: "离线书源",
        enabled: true
    )

    // MARK: - Search Results

    public static let searchResults: [SearchResultItem] = [
        SearchResultItem(
            title: "凡人修仙传",
            detailURL: "offline://book/fanren-xiuxian-zhuan",
            author: "忘语",
            intro: "一个普通的山村少年韩立，机缘巧合之下踏入修仙界，历经千难万险，最终飞升仙界。这是一个关于坚持、智慧和勇气的故事。"
        ),
        SearchResultItem(
            title: "仙逆",
            detailURL: "offline://book/xianni",
            author: "耳根",
            intro: "道在人为，少年王林以平庸资质，凭借坚韧心智逆天改命，一步步踏入修真巅峰。"
        ),
        SearchResultItem(
            title: "一念永恒",
            detailURL: "offline://book/yinian-yongheng",
            author: "耳根",
            intro: "白小纯，一个惜命如金的少年，如何在修真界生存下去？"
        )
    ]

    // MARK: - Book Detail (返回 search result 的第一个)

    public static let bookDetail: SearchResultItem = searchResults[0]

    // MARK: - TOC

    public static let tocItems: [TOCItem] = [
        TOCItem(chapterTitle: "第一章 山村少年", chapterURL: "offline://chapter/1", chapterIndex: 0),
        TOCItem(chapterTitle: "第二章 仙缘",     chapterURL: "offline://chapter/2", chapterIndex: 1),
        TOCItem(chapterTitle: "第三章 修炼入门", chapterURL: "offline://chapter/3", chapterIndex: 2),
        TOCItem(chapterTitle: "第四章 宗门大选", chapterURL: "offline://chapter/4", chapterIndex: 3),
        TOCItem(chapterTitle: "第五章 初入灵泉", chapterURL: "offline://chapter/5", chapterIndex: 4),
    ]

    // MARK: - Chapter Content (≥ 2 chapters)

    public static func contentPage(for chapterURL: String) -> ContentPage? {
        chapters[chapterURL]
    }

    private static let chapters: [String: ContentPage] = [
        "offline://chapter/1": ContentPage(
            title: "第一章 山村少年",
            content: """
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
            """,
            chapterURL: "offline://chapter/1",
            nextChapterURL: "offline://chapter/2"
        ),
        "offline://chapter/2": ContentPage(
            title: "第二章 仙缘",
            content: """
            那日之后，韩立再也不敢独自进山了。

            但命运似乎注定要与他相遇。一天夜里，韩立被一阵奇异的光芒惊醒。他悄悄爬起身，发现光芒来自村后的悬崖方向。

            好奇心驱使着他，趁着夜色溜出了村子。

            悬崖边，一位白发老者盘膝而坐，周身环绕着淡淡的青光。韩立从未见过如此景象，一时间竟看呆了。

            "小娃娃，深夜不睡，跑到这荒郊野岭作甚？"老者的声音不高，却清晰地传入韩立耳中。

            韩立一惊，连忙跪下行礼："前辈恕罪！晚辈只是被光芒引来，无意打扰。"

            老者睁开眼，打量了他片刻，忽然露出一丝笑意："根骨尚可，心性倒也纯良。小娃娃，你可想修仙？"

            韩立愣住了。修仙？那是传说中的事啊！
            """,
            chapterURL: "offline://chapter/2",
            nextChapterURL: "offline://chapter/3"
        ),
        "offline://chapter/3": ContentPage(
            title: "第三章 修炼入门",
            content: """
            三年后。

            韩立盘膝坐在一间石室中，双手结印，面色平静。周围的灵气以肉眼可见的速度向他汇聚。

            这三年来，他跟随那位自称"青云子"的老者，踏入了修仙之路。

            "气沉丹田，意守灵台。"青云子的声音在耳边响起。

            韩立依言而行，只觉体内灵力如溪流般缓缓运转。片刻后，他睁开眼，吐出一口浊气。

            "不错，已经到了练气三层。"青云子满意地点点头，"虽是散修，但你根基扎实，日后未必不能筑基。"

            韩立恭敬地道："多谢师尊教导。"

            "修仙之路漫漫，为师也只能引你入门。接下来的路，要靠你自己了。"青云子叹了口气，"为师寿元将近，再过两年便要坐化了。"
            """,
            chapterURL: "offline://chapter/3",
            nextChapterURL: "offline://chapter/4"
        ),
        "offline://chapter/4": ContentPage(
            title: "第四章 宗门大选",
            content: """
            青云子坐化后，韩立独自修炼了半年，深感散修之路艰难。

            一日，他在坊市中听说了"黄枫谷"十年一度的宗门大选即将开始。若能通过测试，便可成为宗门弟子，获得功法传承和修炼资源。

            韩立心中一动，决定前往一试。

            黄枫谷位于万里之外的苍茫山脉中。韩立跋涉了三个月，终于来到了山门前。

            只见山门处人山人海，足有数千人聚集于此，都是前来参加宗门大选的散修。其中不乏修为比韩立高出许多的人。

            "练气三层也想参加大选？"旁边一个壮汉嗤笑道，"不如回家种田算了。"

            韩立拳心紧握，但没有争辩。他知道，修仙之路从来不是靠嘴上功夫。
            """,
            chapterURL: "offline://chapter/4",
            nextChapterURL: "offline://chapter/5"
        ),
        "offline://chapter/5": ContentPage(
            title: "第五章 初入灵泉",
            content: """
            出乎所有人意料，韩立通过了宗门大选的第一轮测试。

            不是凭借修为，而是凭借青云子传授的一门奇特的敛息术，让他在幻阵中保持了清醒。

            第二轮是灵根测试。韩立的灵根资质并不出众——四属性杂灵根，在黄枫谷中只能算是外门弟子的最低标准。

            但青云子曾告诉他：资质差不可怕，可怕的是没有恒心。

            韩立被分配到了外门弟子居住的灵泉山。这里灵气稀薄，远不如内门弟子的修炼环境。但韩立并不气馁。

            他每日黎明即起，在灵泉边打坐修炼。日复一日，从未间断。

            一个月后，他的修为突破了练气四层。
            """,
            chapterURL: "offline://chapter/5",
            nextChapterURL: nil
        ),
    ]
}
