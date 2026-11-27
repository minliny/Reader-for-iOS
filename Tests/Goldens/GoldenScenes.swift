import Foundation
import ReaderCoreBridge
import ReaderDesign
import SwiftUI
@testable import ReaderApp

@MainActor
enum GoldenScenes {
    static let books = [
        BookshelfEntryData(
            sourceName: "本地", sourceId: "local", bookId: "golden-river", title: "沿河旧事与很长的书架标题",
            author: "林溪", intro: "一册沿河行走的手记。清晨、桥与远处的灯火，在此连成一条小路。",
            kind: "txt", addedAt: 1_796_000_000_000, sortIndex: 0, contentKind: .text,
            currentChapterTitle: "第一章 旧桥", currentChapterIndex: 0, chapterCount: 3, readProgress: 37
        ),
        BookshelfEntryData(
            sourceName: "本地", sourceId: "local", bookId: "golden-window", title: "山间来信",
            author: "许山", intro: "给远行读者留下的三封短笺。", kind: "epub", addedAt: 1_796_000_000_000,
            sortIndex: 1, contentKind: .text, currentChapterTitle: "第二章 上山", currentChapterIndex: 1,
            chapterCount: 3, readProgress: 61
        ),
    ]

    static let chapters: [BookTocEntryData] = [
        .init(index: 0, title: "第一章 旧桥", url: "local:0"),
        .init(index: 1, title: "第二章 上山", url: "local:1"),
        .init(index: 2, title: "第三章 灯火", url: "local:2"),
    ]

    static let prose = """
    清晨，沿河的脚步声还很轻。旧桥通向远处，露水在石缝里泛着光。我们慢慢走过树影，用 𠀀、📚 和 Café 记下这一页。

    四下安静，水从桥洞穿过。岸边有人收了灯，把昨夜的雨声写进一封信。阳光照在青石上，下一页和这一页一样平展。

    桥的另一侧，还有一条走过很久的小路。脚步不急，文字一行行留在那里。
    """

    @ViewBuilder
    static func view(_ scene: GoldenScene) -> some View {
        switch scene.id {
        case "shelf-day", "shelf-night", "shelf-narrow-large", "shelf-wide":
            shelf(books)
        case "shelf-empty":
            shelf([], state: .empty("书架空空，添加一本本地书开始阅读"))
        case "shelf-recovery":
            shelf(books, recovery: .init(title: "导入待核对", message: "原书已保留。继续核对这次导入的结果。", generation: 1))
        case "book-detail":
            BookDetailContent(book: books[0], chapters: chapters, onRead: {}, onDirectory: {}, onRemove: {})
        case "book-directory":
            DirectoryContent(chapters: chapters, selected: 1, onSelect: { _ in })
        case "reader-light", "reader-dark", "reader-quick", "reader-full", "reader-light-status":
            let controls: ReadingControls = switch scene.id {
            case "reader-quick": .quick
            case "reader-full": .full
            default: .hidden
            }
            TextReaderPresentation(text: prose, chapterTitle: "第一章 旧桥", anchor: 0,
                                   preferences: .init(paperId: scene.paper ?? "day"), controls: controls)
        case "message-toast":
            shelf(books).overlay(alignment: .bottom) {
                TransientToast(message: "已加入书架").padding(24)
            }
        case "message-page-loading":
            shelf(nil, state: .loading)
        case "message-page-failed":
            shelf(nil, state: .failed("暂时无法读取书架", actionGeneration: 3))
        case "message-confirmation":
            GoldenAlertPresentation(content: shelf(books))
        case "message-progress":
            shelf(books).overlay(alignment: .bottom) {
                ReaderTaskProgress(title: "正在导入", completed: 1, failed: 1, total: 4).padding(24)
            }
        default:
            fatalError("Unknown golden scene \(scene.id)")
        }
    }

    private static func shelf(_ books: [BookshelfEntryData]?, state: ReaderPageState? = nil,
                              recovery: ShelfRecovery? = nil) -> some View {
        NavigationStack {
            BookshelfContent(books: books, state: state, recovery: recovery,
                             onOpen: { _ in }, onRemove: { _ in }, onRetry: {})
                .navigationTitle("书架")
        }
    }
}

private struct GoldenAlertPresentation<Content: View>: View {
    let content: Content
    @State private var confirmation: ReaderConfirmation?

    var body: some View {
        content
            .readerConfirmation($confirmation) { _ in }
            .task {
                confirmation = ReaderConfirmation(title: "从书架移除？",
                                                  message: "将从书架移除《沿河旧事与很长的书架标题》。",
                                                  confirmTitle: "移除", generation: 4)
            }
    }
}
