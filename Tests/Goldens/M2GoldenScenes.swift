import ReaderCoreBridge
import ReaderDesign
import SwiftUI
@testable import ReaderApp

@MainActor
enum M2GoldenScenes {
    static let ids: Set<String> = [
        "m2-source-management", "m2-source-report", "m2-source-report-detail", "m2-subscription-diff", "m2-global-search",
        "m2-online-detail", "m2-source-switch", "m2-downloads", "m2-source-login",
    ]

    @ViewBuilder
    static func view(_ id: String, browser: UIImage?) -> some View {
        switch id {
        case "m2-source-management":
            NavigationStack {
                SourceCatalogContent(
                    sources: sources, groups: groups, query: .constant(""), groupID: .constant(nil),
                    selection: .constant([]), selecting: false, onAction: { _ in }
                )
                .navigationTitle("书源管理")
                .navigationBarTitleDisplayMode(.inline)
                .readerNavigationBar()
            }
        case "m2-source-report":
            NavigationStack {
                SourceReportContent(rows: reports, filter: .constant(.all), onSelect: { _ in })
                    .navigationTitle("批量检测报告")
                    .navigationBarTitleDisplayMode(.inline)
                    .readerNavigationBar()
            }
        case "m2-source-report-detail":
            NavigationStack { SourceDiagnosticScreen(row: reports[1]) }
        case "m2-subscription-diff":
            NavigationStack {
                SourceSubscriptionPreviewContent(
                    preview: subscription, selected: .constant([sources[0].sourceId, sources[1].sourceId]),
                    committing: false, confirm: {}
                )
                .navigationTitle("订阅差异预览")
                .navigationBarTitleDisplayMode(.inline)
                .readerNavigationBar()
            }
        case "m2-global-search":
            NavigationStack {
                GlobalSearchContent(query: .constant("沿河"), history: ["沿河", "山间来信"], rows: books)
                    .navigationTitle("全局搜索")
                    .navigationBarTitleDisplayMode(.inline)
                    .readerNavigationBar()
            }
        case "m2-online-detail":
            NavigationStack {
                OnlineBookDetailContent(book: books[0])
                    .navigationTitle("书籍详情")
                    .navigationBarTitleDisplayMode(.inline)
                    .readerNavigationBar()
            }
        case "m2-source-switch":
            GoldenSourceSwitchPresentation(book: books[0], candidates: alternatives)
        case "m2-downloads":
            NavigationStack {
                DownloadManagementContent(books: [
                    .init(book: books[0], total: 4, chapters: [
                        .init(index: 0, title: "第一章 旧桥", state: .completed),
                        .init(index: 1, title: "第二章 上岸", state: .inProgress),
                        .init(index: 2, title: "第三章 雨声", state: .failed),
                        .init(index: 3, title: "第四章 灯火", state: .missing),
                    ], active: true),
                ], storage: .init(totalBytes: 75_000, retainedBytes: 50_000, automaticBytes: 25_000,
                                  cleanableBytes: 25_000, protectedChapters: [], removedChapters: [],
                                  hasMore: false, removedContentBytes: 0, completedQueueChapters: [],
                                  completedQueueHasMore: false))
                .navigationTitle("下载管理")
                .navigationBarTitleDisplayMode(.inline)
                .readerNavigationBar()
            }
        case "m2-source-login":
            SourceBrowserContent(
                title: "沿河书屋", address: "https://reader.example.test/login", secure: true,
                canGoBack: true, canGoForward: false, loading: false, progress: 1, onAction: { _ in }
            ) {
                if let browser {
                    ScrollView {
                        Image(uiImage: browser).resizable().scaledToFit().accessibilityHidden(true)
                    }
                    .background(.white)
                }
            }
        default:
            fatalError("Unknown M2 golden scene \(id)")
        }
    }

    private static let sources: [M2SourceListEntry] = [
        .init(sourceId: "https://river.example.test", name: "沿河书屋", baseUrl: "https://river.example.test",
              enabled: true, enabledExplore: false, bookSource: ["bookSourceGroup": .string("小说")]),
        .init(sourceId: "https://mountain.example.test", name: "山间读本", baseUrl: "https://mountain.example.test",
              enabled: true, enabledExplore: false, bookSource: ["bookSourceGroup": .string("小说")]),
        .init(sourceId: "https://letters.example.test", name: "旧信集", baseUrl: "https://letters.example.test",
              enabled: false, enabledExplore: false, bookSource: ["bookSourceGroup": .string("散文")]),
    ]

    private static let groups = M2SourceGroupCatalogData(
        revision: 0, groups: [.init(groupId: "novel", name: "小说"), .init(groupId: "essay", name: "散文")],
        memberships: sources.enumerated().map {
            .init(sourceId: $0.element.sourceId, groupId: $0.offset == 2 ? "essay" : "novel", locallyAssigned: false)
        }
    )

    private static let reports: [SourceReportRow] = sources.enumerated().map { item in
        let steps = M2SourceCheckReportStepsItemLevel.allCases.enumerated().map { step in
            let status: M2SourceCheckReportStepsItemStatus =
                item.offset == 0 || step.offset < 2 ? .pass : step.offset == 2 ? .fail : .blocked
            return M2SourceCheckReportStepsItem(
                level: step.element, requested: true, executed: status != .blocked, status: status,
                durationMs: status == .blocked ? 0 : Int64(step.offset + 1) * 19,
                reason: status == .fail ? "TIMEOUT" : nil
            )
        }
        return .init(
            sourceId: item.element.sourceId, name: item.element.name,
            report: item.offset == 2 ? nil :
                .init(version: .v2, mode: .search, traceId: "golden-\(item.offset)", inputDigest: "sample", steps: steps)
        )
    }

    private static let subscription = M2RuleSubUpdatePreviewData(
        planId: "golden-subscription", subscriptionId: 91, remoteDigest: "sample", expiresAt: 1_796_000_000_000,
        changes: [
            .init(sourceId: sources[0].sourceId, name: sources[0].name, kind: .added),
            .init(sourceId: sources[1].sourceId, name: sources[1].name, kind: .update),
            .init(sourceId: sources[2].sourceId, name: sources[2].name, kind: .conflict),
        ]
    )

    private static let books: [OnlineBookReference] = [
        .init(sourceId: sources[0].sourceId, bookId: "river", title: "沿河旧事", author: "林溪",
              intro: "一册沿河行走的手记。清晨、桥与远处的灯火，在此连成一条小路。",
              lastChapter: "第四章 灯火", sourceName: sources[0].name),
        .init(sourceId: sources[1].sourceId, bookId: "letters", title: "沿河来信", author: "许山",
              intro: "给远行读者留下的三封短笺。", lastChapter: "第三章 归来", sourceName: sources[1].name),
    ]

    private static let alternatives: [SourceSwitchCandidate] = [
        .init(book: .init(sourceId: sources[1].sourceId, bookId: "river-next", title: "沿河旧事",
                         author: "林溪", lastChapter: "第四章 灯火", sourceName: sources[1].name)),
        .init(book: .init(sourceId: sources[2].sourceId, bookId: "river-full", title: "沿河旧事",
                         author: "林溪", lastChapter: "第五章 归来", sourceName: sources[2].name)),
    ]
}

private struct GoldenSourceSwitchPresentation: View {
    let book: OnlineBookReference
    let candidates: [SourceSwitchCandidate]
    @State private var presented = false

    var body: some View {
        TextReaderPresentation(text: GoldenScenes.prose, chapterTitle: "第一章 旧桥", anchor: 0,
                               preferences: .init(paperId: "day"), controls: .hidden)
            .sheet(isPresented: $presented) {
                NavigationStack {
                    SourceSwitchContent(title: book.title, currentSource: book.displaySource, rows: candidates)
                        .navigationBarTitleDisplayMode(.inline)
                        .readerNavigationBar()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("关闭") { presented = false }
                            }
                        }
                }
                .presentationCornerRadius(CGFloat(ReaderDesignMetrics.sourceSwitchDrawerRadius))
            }
            .task { presented = true }
    }
}
