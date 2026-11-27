import Observation
import ReaderCoreBridge
import ReaderDesign
import ReaderHost
import SwiftUI

struct GlobalSearchScreen: View {
    let session: M2AppSession
    let files: FileAndAssetHost
    let refreshShelf: () async -> Void
    @State private var query = ""
    @State private var history: [String] = []
    @State private var sourceNames: [String: String] = [:]
    @State private var destination: OnlineBookReference?
    @State private var previousRows: [OnlineBookReference] = []
    @State private var searched: String?
    @State private var stopped = false
    @State private var settled = false
    @State private var failed = false
    @State private var presentationGeneration = 0
    @Environment(\.scenePhase) private var phase
    @State private var toast = ReaderToastPresenter()

    private var search: SearchCoordinator { session.search }

    private var results: [OnlineBookReference] {
        guard searched != nil else { return [] }
        var seen = Set<OnlineBookReference.Identity>()
        return search.globalResults.flatMap { candidate -> [OnlineBookReference] in
            guard case .success(let response) = candidate.terminal,
                  response.value.contentKind != .audio else { return [] }
            return response.value.books.map { book in
                .init(sourceId: candidate.sourceId, bookId: book.bookId, title: book.title,
                      author: book.authorIdentity?.label ?? book.author, coverURL: book.coverUrl,
                      intro: book.intro, lastChapter: book.lastChapter, sourceName: sourceNames[candidate.sourceId], kind: book.kind,
                      variables: book.variables, isManga: response.value.contentKind == .manga)
            }
        }.filter { seen.insert($0.id).inserted }
    }

    private var displayRows: [OnlineBookReference] {
        let refreshed = Set(search.globalResults.compactMap { item in
            if case .success = item.terminal { return item.sourceId }
            return nil
        })
        return results + previousRows.filter { !refreshed.contains($0.sourceId) }
    }

    var body: some View {
        GlobalSearchContent(query: $query, history: history, rows: displayRows,
                            busy: search.inFlight, stopped: stopped, hasSearched: settled,
                            failed: failed, onSearch: { begin($0, retry: false) },
                            onStop: stop, onRetry: { if let searched { begin(searched, retry: true) } },
                            onOpen: { destination = $0 }, network: session.sources.network)
            .navigationTitle("全局搜索")
            .navigationBarTitleDisplayMode(.inline)
            .readerNavigationBar()
            .navigationDestination(item: $destination) { book in
                OnlineBookDetailScreen(reference: book, session: session, files: files, refreshShelf: refreshShelf)
            }
            .overlay(alignment: .bottom) {
                if let message = toast.message, phase == .active, destination == nil {
                    TransientToast(message: message).padding(CGFloat(ReaderDesignMetrics.spaceMedium))
                }
            }
            .task {
                await loadHistory()
                if let survey = try? await session.sources.list(.init(enabledOnly: true)) {
                    sourceNames = Dictionary(survey.sources.map { ($0.sourceId, $0.name) }, uniquingKeysWith: { first, _ in first })
                }
            }
            .onDisappear {
                presentationGeneration += 1
                if search.inFlight { stop() }
                toast.dismiss()
            }
            .onChange(of: phase) { _, value in
                if value != .active { toast.dismiss() }
            }
    }

    private func stop() {
        search.stopDisplaying()
        stopped = true
    }

    private func begin(_ value: String, retry: Bool) {
        let keyword = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty, !search.inFlight else { return }
        do {
            let retained = keyword == searched ? displayRows : []
            let owner = try retry ? search.retryGlobal() : search.startGlobal(keyword: keyword)
            previousRows = retained
            query = keyword
            searched = keyword
            stopped = false
            failed = false
            settled = false
            presentationGeneration += 1
            let generation = presentationGeneration
            Task {
                let terminal = await owner.result
                guard generation == presentationGeneration else { return }
                settled = true
                guard !stopped else { await loadHistory(); return }
                switch terminal {
                case .success(let items):
                    let failures = items.filter {
                        if case .failure = $0.terminal { return true }
                        return false
                    }.count
                    failed = !items.isEmpty && failures == items.count && results.isEmpty
                    if failures > 0 && (!results.isEmpty || !previousRows.isEmpty) {
                        if results.isEmpty { failed = true }
                        feedback("有书源暂时无法返回结果", key: "search-partial")
                    } else if failures == 0 {
                        previousRows = []
                    }
                case .failure:
                    failed = true
                    if !previousRows.isEmpty { feedback("本次未取得新结果，已保留上次结果", key: "search-error") }
                }
                await loadHistory()
            }
        } catch {
            feedback("暂时无法发起搜索", key: "search-start")
        }
    }

    private func loadHistory() async {
        if let result = try? await search.history(limit: 24) { history = result.keywords }
    }

    private func feedback(_ message: String, key: String) {
        toast.show(message: message, key: key, feedbackEnabled: destination == nil, sceneActive: phase == .active)
    }
}
