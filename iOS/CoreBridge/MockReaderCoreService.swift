import Foundation
import ReaderCoreModels

public enum MockScenario {
    case success
    case partial(warning: String)
    case unsupported(reason: String)
    case empty
    case parserFailure
    case networkFailure
    case jsRequired
    case loginRequired
}

public final class MockReaderCoreService {
    public static let shared = MockReaderCoreService()

    private var scenario: MockScenario = .success
    private let scenarioLock = NSLock()

    private init() {}

    public func setScenario(_ scenario: MockScenario) {
        scenarioLock.lock()
        defer { scenarioLock.unlock() }
        self.scenario = scenario
    }

    public func reset() {
        scenarioLock.lock()
        defer { scenarioLock.unlock() }
        self.scenario = .success
    }

    public func validateBookSource(from data: Data) async -> LoadState<BookSource> {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return processScenario(for: BookSource(
            id: "mock",
            bookSourceName: "Mock Source",
            bookSourceUrl: "https://example.com"
        ))
    }

    public func searchBooks(keyword: String, page: Int) async -> LoadState<[SearchResultItem]> {
        try? await Task.sleep(nanoseconds: 300_000_000)

        switch scenario {
        case .success:
            return .loaded(Self.mockSearchResults)

        case .partial(let warning):
            return .partial(Self.mockSearchResults, warning: warning)

        case .unsupported(let reason):
            return .unsupported(reason)

        case .empty:
            return .empty

        case .parserFailure:
            return .failed(AppReaderError(
                code: .parser,
                message: "Mock parser failure",
                stage: "SEARCH"
            ))

        case .networkFailure:
            return .failed(AppReaderError(
                code: .network,
                message: "Mock network failure",
                stage: "SEARCH"
            ))

        case .jsRequired:
            return .failed(AppReaderError(
                code: .jsRequired,
                message: "JS required but disabled",
                stage: "SEARCH"
            ))

        case .loginRequired:
            return .failed(AppReaderError(
                code: .loginRequired,
                message: "Login required",
                stage: "SEARCH"
            ))
        }
    }

    public func getBookDetail(bookURL: String) async -> LoadState<SearchResultItem> {
        try? await Task.sleep(nanoseconds: 200_000_000)

        switch scenario {
        case .success:
            return .loaded(Self.mockSearchResults[0])

        case .partial(let warning):
            return .partial(Self.mockSearchResults[0], warning: warning)

        case .unsupported(let reason):
            return .unsupported(reason)

        case .empty:
            return .empty

        case .parserFailure:
            return .failed(AppReaderError(
                code: .parser,
                message: "Mock parser failure",
                stage: "DETAIL"
            ))

        case .networkFailure:
            return .failed(AppReaderError(
                code: .network,
                message: "Mock network failure",
                stage: "DETAIL"
            ))

        case .jsRequired:
            return .failed(AppReaderError(
                code: .jsRequired,
                message: "JS required but disabled",
                stage: "DETAIL"
            ))

        case .loginRequired:
            return .failed(AppReaderError(
                code: .loginRequired,
                message: "Login required",
                stage: "DETAIL"
            ))
        }
    }

    public func getChapterList(bookURL: String) async -> LoadState<[TOCItem]> {
        try? await Task.sleep(nanoseconds: 200_000_000)

        switch scenario {
        case .success:
            return .loaded(Self.mockTOCItems)

        case .partial(let warning):
            return .partial(Self.mockTOCItems, warning: warning)

        case .unsupported(let reason):
            return .unsupported(reason)

        case .empty:
            return .empty

        case .parserFailure:
            return .failed(AppReaderError(
                code: .parser,
                message: "Mock parser failure",
                stage: "TOC"
            ))

        case .networkFailure:
            return .failed(AppReaderError(
                code: .network,
                message: "Mock network failure",
                stage: "TOC"
            ))

        case .jsRequired:
            return .failed(AppReaderError(
                code: .jsRequired,
                message: "JS required but disabled",
                stage: "TOC"
            ))

        case .loginRequired:
            return .failed(AppReaderError(
                code: .loginRequired,
                message: "Login required",
                stage: "TOC"
            ))
        }
    }

    public func getChapterContent(chapterURL: String) async -> LoadState<ContentPage> {
        try? await Task.sleep(nanoseconds: 300_000_000)

        switch scenario {
        case .success:
            return .loaded(Self.mockContentPage)

        case .partial(let warning):
            return .partial(Self.mockContentPage, warning: warning)

        case .unsupported(let reason):
            return .unsupported(reason)

        case .empty:
            return .empty

        case .parserFailure:
            return .failed(AppReaderError(
                code: .parser,
                message: "Mock parser failure",
                stage: "CONTENT"
            ))

        case .networkFailure:
            return .failed(AppReaderError(
                code: .network,
                message: "Mock network failure",
                stage: "CONTENT"
            ))

        case .jsRequired:
            return .failed(AppReaderError(
                code: .jsRequired,
                message: "JS required but disabled",
                stage: "CONTENT"
            ))

        case .loginRequired:
            return .failed(AppReaderError(
                code: .loginRequired,
                message: "Login required",
                stage: "CONTENT"
            ))
        }
    }

    private func processScenario<T>(for value: T) -> LoadState<T> {
        switch scenario {
        case .success, .empty:
            return .loaded(value)
        case .partial(let warning):
            return .partial(value, warning: warning)
        case .unsupported(let reason):
            return .unsupported(reason)
        case .parserFailure:
            return .failed(AppReaderError(code: .parser, message: "Mock parser failure", stage: nil))
        case .networkFailure:
            return .failed(AppReaderError(code: .network, message: "Mock network failure", stage: nil))
        case .jsRequired:
            return .failed(AppReaderError(code: .jsRequired, message: "JS required but disabled", stage: nil))
        case .loginRequired:
            return .failed(AppReaderError(code: .loginRequired, message: "Login required", stage: nil))
        }
    }

    public static let mockSearchResults: [SearchResultItem] = [
        SearchResultItem(
            title: "凡人修仙传",
            detailURL: "https://example.com/book/1",
            author: "忘语"
        ),
        SearchResultItem(
            title: "仙逆",
            detailURL: "https://example.com/book/2",
            author: "耳根"
        ),
        SearchResultItem(
            title: "一念永恒",
            detailURL: "https://example.com/book/3",
            author: "耳根"
        )
    ]

    public static let mockTOCItems: [TOCItem] = [
        TOCItem(
            chapterTitle: "第一章 山村少年",
            chapterURL: "https://example.com/book/1/chapter/1",
            chapterIndex: 0
        ),
        TOCItem(
            chapterTitle: "第二章 仙缘",
            chapterURL: "https://example.com/book/1/chapter/2",
            chapterIndex: 1
        ),
        TOCItem(
            chapterTitle: "第三章 修炼入门",
            chapterURL: "https://example.com/book/1/chapter/3",
            chapterIndex: 2
        ),
        TOCItem(
            chapterTitle: "第四章 宗门大选",
            chapterURL: "https://example.com/book/1/chapter/4",
            chapterIndex: 3
        ),
        TOCItem(
            chapterTitle: "第五章 初入灵泉",
            chapterURL: "https://example.com/book/1/chapter/5",
            chapterIndex: 4
        )
    ]

    public static let mockContentPage: ContentPage = ContentPage(
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
        chapterURL: "https://example.com/book/1/chapter/1",
        nextChapterURL: "https://example.com/book/1/chapter/2"
    )
}
