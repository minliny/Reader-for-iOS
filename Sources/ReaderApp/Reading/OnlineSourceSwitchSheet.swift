import Foundation
import ReaderCoreBridge
import ReaderDesign
import SwiftUI

struct SourceSwitchCandidate: Identifiable, Sendable {
    let book: OnlineBookReference
    var responseMillis: Int64? = nil
    var id: OnlineBookReference.Identity { book.id }
}

struct OnlineSourceSwitchSheet: View {
    let book: OnlineBookReference
    let session: M2AppSession
    let onChoose: (SourceSwitchCandidate) async throws -> Void

    @State private var candidates: [SourceSwitchCandidate] = []
    @State private var busy = false
    @State private var writing = false
    @State private var didFail = false
    @State private var hasLoaded = false
    @State private var generation = 0
    @State private var toast = ReaderToastPresenter()
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SourceSwitchContent(title: book.title, currentSource: book.displaySource, rows: candidates, busy: busy || writing,
                hasLoaded: hasLoaded, failed: didFail, onRefresh: { Task { await reload() } }, onChoose: choose)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { dismiss() }.disabled(writing)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .readerNavigationBar()
                .overlay(alignment: .bottom) {
                    if let message = toast.message, phase == .active {
                        TransientToast(message: message).padding(CGFloat(ReaderDesignMetrics.spaceMedium))
                    }
                }
                .task { await reload() }
                .onDisappear {
                    generation += 1
                    toast.dismiss()
                }
        }
        .presentationCornerRadius(CGFloat(ReaderDesignMetrics.sourceSwitchDrawerRadius))
        .interactiveDismissDisabled(writing)
    }

    private func reload() async {
        guard !busy, !writing else { return }
        busy = true
        defer { busy = false }
        generation += 1
        let current = generation
        do {
            let sources = try await session.sources.list(.init(enabledOnly: true)).sources
            let names = Dictionary(sources.map { ($0.sourceId, $0.name) }, uniquingKeysWith: { first, _ in first })
            let ids = sources.filter { source in
                guard source.sourceId != book.sourceId else { return false }
                if case .integer(2) = source.bookSource?["bookSourceType"] { return book.isManga }
                return !book.isManga
            }.map(\.sourceId)
            let response: [M2ChangeBookSourceCandidate]
            if ids.isEmpty { response = [] }
            else {
                let online = OnlineReadingCoordinator(runtime: session.sources.runtime)
                response = try await online.switchCandidates(.init(sourceId: book.sourceId, bookId: book.bookId,
                    keyword: book.title, sourceIds: ids)).candidates
            }
            guard !Task.isCancelled, current == generation else { return }
            var seen = Set<OnlineBookReference.Identity>()
            candidates = response.filter { names[$0.sourceId] != nil }.map { candidate in
                let reference = OnlineBookReference(sourceId: candidate.sourceId, bookId: candidate.bookUrl,
                    title: candidate.bookName, author: candidate.authorIdentity?.label ?? candidate.author,
                    coverURL: candidate.coverUrl, sourceName: names[candidate.sourceId], isManga: book.isManga)
                return SourceSwitchCandidate(book: reference)
            }.filter { seen.insert($0.id).inserted }
            hasLoaded = true
            didFail = false
        } catch {
            guard current == generation else { return }
            hasLoaded = true
            didFail = true
            if !candidates.isEmpty {
                toast.show(message: "未取得新候选，已保留本页书源", key: "switch-reload",
                           feedbackEnabled: true, sceneActive: phase == .active)
            }
        }
    }

    private func choose(_ candidate: SourceSwitchCandidate) {
        guard !busy, !writing else { return }
        writing = true
        Task {
            defer { writing = false }
            do {
                try await onChoose(candidate)
                dismiss()
            } catch OnlineReadingCoordinator.Failure.switchUnresolved {
                dismiss()
            } catch {
                toast.show(message: "换源未完成，已保留当前阅读", key: "switch-failed",
                           feedbackEnabled: true, sceneActive: phase == .active)
            }
        }
    }
}

struct SourceSwitchContent: View {
    let title: String
    let currentSource: String
    let rows: [SourceSwitchCandidate]
    var busy = false
    var hasLoaded = true
    var failed = false
    var onRefresh: () -> Void = {}
    var onChoose: (SourceSwitchCandidate) -> Void = { _ in }
    @Environment(\.readerTheme) private var theme

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceMedium)) {
                heading
                if rows.isEmpty {
                    if busy || !hasLoaded { PageState(state: .loading) }
                    else if failed { PageState(state: .failed("暂时无法查找候选书源。", actionGeneration: 0)) { _ in onRefresh() } }
                    else { PageState(state: .empty("暂无可切换的书源")) }
                } else {
                    candidates(narrow: geometry.size.width < CGFloat(ReaderDesignMetrics.narrowBreakpoint))
                }
            }
            .padding(CGFloat(ReaderDesignMetrics.screenInset))
            .frame(maxWidth: CGFloat(ReaderDesignMetrics.sourceSwitchDrawerMaxWidth))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(theme.background)
    }

    private var heading: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.rowBlockSpacing)) {
                Text("切换书源").readerTypography(ReaderDesignMetrics.sourceSwitchHeading)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("m2-switch-sheet")
                Text(title).readerTypography(ReaderDesignMetrics.sourceSwitchBookTitle).lineLimit(2)
                Text("当前书源 · \(currentSource)").readerTypography(ReaderDesignMetrics.rowDetail)
                    .foregroundStyle(theme.secondaryText).lineLimit(2)
            }
            Spacer()
            Button(action: onRefresh) {
                ReaderIcon(ReaderIconRegistry.refresh)
                    .frame(width: CGFloat(ReaderDesignMetrics.minimumActionTarget),
                           height: CGFloat(ReaderDesignMetrics.minimumActionTarget))
                    .background(theme.elevated, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("重新查找书源")
            .accessibilityIdentifier("m2-switch-refresh")
            .disabled(busy)
        }
    }

    private func candidates(narrow: Bool) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { offset, row in
                    Button { onChoose(row) } label: {
                        HStack(spacing: CGFloat(ReaderDesignMetrics.controlInlineSpacing)) {
                            VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.rowBlockSpacing)) {
                                Text(row.book.displaySource)
                                    .readerTypography(ReaderDesignMetrics.sourceSwitchCandidateName)
                                    .lineLimit(2)
                                if let author = row.book.author, !author.isEmpty {
                                    Text(author).readerTypography(ReaderDesignMetrics.rowDetail)
                                        .foregroundStyle(theme.secondaryText).lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                            if let millis = row.responseMillis {
                                Text("\(millis) ms").readerTypography(ReaderDesignMetrics.rowDetail)
                                    .foregroundStyle(theme.secondaryText)
                                    .frame(width: CGFloat(narrow ? ReaderDesignMetrics.sourceSwitchNarrowTimingColumnWidth :
                                                                ReaderDesignMetrics.sourceSwitchTimingColumnWidth), alignment: .trailing)
                            }
                            ReaderIcon(ReaderIconRegistry.drillIn).foregroundStyle(theme.accent)
                        }
                        .padding(.horizontal, CGFloat(ReaderDesignMetrics.cardPadding))
                        .frame(minHeight: CGFloat(ReaderDesignMetrics.sourceSwitchRowHeight))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)
                    .accessibilityIdentifier("m2-switch-candidate-\(offset)")
                    if offset != rows.count - 1 { Divider().padding(.horizontal, CGFloat(ReaderDesignMetrics.cardPadding)) }
                }
            }
            .background(theme.surface, in: .rect(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
        }
    }
}
