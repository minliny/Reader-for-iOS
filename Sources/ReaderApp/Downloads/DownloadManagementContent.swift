import Foundation
import ReaderCoreBridge
import ReaderDesign
import ReaderHost
import SwiftUI

struct DownloadChapterPresentation: Identifiable, Sendable {
    let index: Int64
    let title: String
    let state: M2CacheChapterState
    var navigable: Bool = true

    var id: Int64 { index }
}

struct DownloadBookPresentation: Identifiable, Sendable {
    let book: OnlineBookReference
    let total: Int
    let chapters: [DownloadChapterPresentation]
    var active = false
    var recovering = false

    var id: OnlineBookReference.Identity { book.id }
    var completed: Int { chapters.count { $0.state == .completed } }
    var failed: Int { chapters.count { $0.state == .failed } }
    var unexecuted: Int { chapters.count { $0.state == .missing || $0.state == .queued } }
    var canStart: Bool {
        !active && !recovering && chapters.contains { $0.navigable && [.missing, .cached, .failed, .cancelled].contains($0.state) }
    }
}

enum DownloadChapterControl: String {
    case pause, resume, cancel

    var title: String {
        switch self {
        case .pause: "暂停"
        case .resume: "继续"
        case .cancel: "取消"
        }
    }

    var icon: ReaderIconMapping {
        switch self {
        case .pause: ReaderIconRegistry.pause
        case .resume: ReaderIconRegistry.resume
        case .cancel: ReaderIconRegistry.stop
        }
    }
}

struct DownloadManagementContent: View {
    let books: [DownloadBookPresentation]
    var storage: M2CacheStorageData? = nil
    var stage: ReaderPageState = .empty("书架暂无在线下载")
    var expandedByDefault = true
    var onStart: (DownloadBookPresentation) -> Void = { _ in }
    var onControl: (DownloadBookPresentation, DownloadChapterPresentation, DownloadChapterControl) -> Void = { _, _, _ in }
    var onStorageCleanup: () -> Void = {}
    var onPrepare: ((OnlineBookReference) -> Void)? = nil
    var onRetry: (Int) -> Void = { _ in }
    var network: NetworkAndWebHost? = nil
    @Environment(\.readerTheme) private var theme
    @State private var collapsed: Set<OnlineBookReference.Identity> = []
    @State private var expanded: Set<OnlineBookReference.Identity> = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceMedium)) {
                if let storage { cacheSummary(storage) }
                if books.isEmpty {
                    PageState(state: stage, onRetry: onRetry)
                        .frame(minHeight: 220)
                }
                ForEach(Array(books.enumerated()), id: \.element.id) { offset, item in
                    book(item, offset: offset)
                }
            }
            .padding(CGFloat(ReaderDesignMetrics.screenInset))
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("m2-download-page")
    }

    private func cacheSummary(_ storage: M2CacheStorageData) -> some View {
        HStack(alignment: .center, spacing: CGFloat(ReaderDesignMetrics.controlInlineSpacing)) {
            ReaderIcon(ReaderIconRegistry.storage).foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.rowBlockSpacing)) {
                Text("正文缓存").readerTypography(ReaderDesignMetrics.downloadSectionLabel)
                let total = ByteCountFormatter.string(fromByteCount: storage.totalBytes, countStyle: .file)
                let available = ByteCountFormatter.string(fromByteCount: storage.cleanableBytes, countStyle: .file)
                Text("共 \(total) · 可清理 \(available)").readerTypography(ReaderDesignMetrics.downloadMetadata)
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer(minLength: 0)
            Button("清理", action: onStorageCleanup)
                .readerTypography(ReaderDesignMetrics.downloadControl)
                .frame(minHeight: CGFloat(ReaderDesignMetrics.minimumActionTarget))
                .disabled(storage.cleanableBytes <= 0)
                .accessibilityIdentifier("m2-download-cleanup")
        }
        .padding(.horizontal, CGFloat(ReaderDesignMetrics.cardPadding))
        .padding(.vertical, CGFloat(ReaderDesignMetrics.spaceExtraSmall))
        .background(theme.elevated, in: .rect(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
    }

    private func book(_ item: DownloadBookPresentation, offset: Int) -> some View {
        let showingChapters = expandedByDefault ? !collapsed.contains(item.id) : expanded.contains(item.id)
        return VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
            HStack(alignment: .center, spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
                OnlineBookCover(book: item.book, width: CGFloat(ReaderDesignMetrics.downloadCoverWidth),
                                height: CGFloat(ReaderDesignMetrics.downloadCoverHeight),
                                radius: CGFloat(ReaderDesignMetrics.downloadCoverRadius), network: network)
                VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.rowBlockSpacing)) {
                    Text(item.book.title).readerTypography(ReaderDesignMetrics.downloadSheetTitle)
                        .accessibilityAddTraits(.isHeader).lineLimit(2)
                    Text(item.book.displaySource).readerTypography(ReaderDesignMetrics.downloadMetadata)
                        .foregroundStyle(theme.secondaryText).lineLimit(2)
                    Text(item.recovering ? "原任务待核对" : item.active ? "下载进行中" : "\(item.total) 章")
                        .readerTypography(ReaderDesignMetrics.downloadSectionLabel)
                        .foregroundStyle(item.recovering ? theme.warning : theme.accent)
                }
                Spacer(minLength: 0)
                Button {
                    if expandedByDefault {
                        if showingChapters { collapsed.insert(item.id) } else { collapsed.remove(item.id) }
                    } else if showingChapters {
                        expanded.remove(item.id)
                    } else {
                        expanded.insert(item.id)
                    }
                } label: {
                    ReaderIcon(showingChapters ? ReaderIconRegistry.collapse : ReaderIconRegistry.expand)
                        .foregroundStyle(theme.accent)
                        .frame(width: CGFloat(ReaderDesignMetrics.minimumActionTarget),
                               height: CGFloat(ReaderDesignMetrics.minimumActionTarget))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showingChapters ? "收起章节任务" : "展开章节任务")
            }
            if item.total > 0 { DownloadProgressSurface(total: item.total, completed: item.completed, failed: item.failed, unexecuted: item.unexecuted) }
            if item.canStart {
                Button {
                    onStart(item)
                } label: {
                    Label { Text("开始下载") } icon: { ReaderIcon(ReaderIconRegistry.download) }
                        .readerTypography(ReaderDesignMetrics.downloadControl)
                        .frame(minHeight: CGFloat(ReaderDesignMetrics.minimumActionTarget))
                        .padding(.horizontal, CGFloat(ReaderDesignMetrics.spaceSmall))
                        .foregroundStyle(theme.onAccent)
                        .background(theme.accentFill, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("m2-download-start-\(offset)")
            }
            if item.chapters.isEmpty, let onPrepare {
                Button("查看章节下载") { onPrepare(item.book) }
                    .readerTypography(ReaderDesignMetrics.downloadControl)
                    .frame(minHeight: CGFloat(ReaderDesignMetrics.minimumActionTarget))
                    .accessibilityIdentifier("m2-download-prepare-\(offset)")
            }
            if showingChapters {
                if item.chapters.isEmpty {
                    Text("暂无可下载的目录").readerTypography(ReaderDesignMetrics.downloadMetadata)
                        .foregroundStyle(theme.secondaryText)
                } else {
                    VStack(spacing: 0) {
                        ForEach(item.chapters) { chapter in
                            row(chapter, book: item)
                        }
                    }
                }
            }
        }
        .padding(CGFloat(ReaderDesignMetrics.cardPadding))
        .background(theme.surface, in: .rect(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
    }

    private func row(_ chapter: DownloadChapterPresentation, book: DownloadBookPresentation) -> some View {
        let actions = controls(for: chapter.state)
        return VStack(spacing: 0) {
            Divider()
            HStack(spacing: CGFloat(ReaderDesignMetrics.rowBlockSpacing)) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(chapter.title)
                        .readerTypography(ReaderDesignMetrics.downloadChapterTitle)
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(2)
                    Text(status(chapter.state))
                        .readerTypography(ReaderDesignMetrics.downloadMetadata)
                        .foregroundStyle(chapter.state == .failed ? theme.danger : theme.secondaryText)
                        .accessibilityIdentifier("m2-download-state-\(chapter.index)")
                }
                Spacer(minLength: 0)
                ForEach(actions, id: \.self) { action in
                    Button {
                        onControl(book, chapter, action)
                    } label: {
                        ReaderIcon(action.icon)
                            .frame(width: CGFloat(ReaderDesignMetrics.minimumActionTarget),
                                   height: CGFloat(ReaderDesignMetrics.minimumActionTarget))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(action == .cancel ? theme.danger : theme.accent)
                    .accessibilityLabel("\(action.title)《\(chapter.title)》")
                    .accessibilityIdentifier("m2-download-\(action.rawValue)-\(chapter.index)")
                }
            }
            .frame(minHeight: CGFloat(ReaderDesignMetrics.downloadChapterRowHeight))
        }
    }

    private func controls(for state: M2CacheChapterState) -> [DownloadChapterControl] {
        switch state {
        case .queued, .inProgress: [.pause, .cancel]
        case .paused: [.resume, .cancel]
        case .failed, .cancelled: [.resume]
        case .completed, .cached, .missing: []
        }
    }

    private func status(_ state: M2CacheChapterState) -> String {
        switch state {
        case .missing: "未执行"
        case .queued: "排队中"
        case .paused: "已暂停"
        case .inProgress: "下载中"
        case .cached: "已有正文缓存"
        case .completed: "已完成"
        case .failed: "失败"
        case .cancelled: "已取消"
        }
    }
}

private struct DownloadProgressSurface: View {
    let total: Int
    let completed: Int
    let failed: Int
    let unexecuted: Int
    @Environment(\.readerTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.rowBlockSpacing)) {
            GeometryReader { geometry in
                let progress = min(1, Double(completed + failed) / Double(max(1, total)))
                let completedFraction = min(progress, Double(completed) / Double(max(1, total)))
                let radius = CGFloat(ReaderDesignMetrics.downloadProgressTrackRadius)
                ZStack(alignment: .leading) {
                    theme.progressTrack
                    theme.danger.frame(width: geometry.size.width * progress)
                    theme.accentFill.frame(width: geometry.size.width * completedFraction)
                }
                .clipShape(.rect(cornerRadius: radius))
            }
            .frame(height: CGFloat(ReaderDesignMetrics.downloadProgressTrackHeight))
            Text("已完成 \(completed) · 失败 \(failed) · 未执行 \(unexecuted)")
                .readerTypography(ReaderDesignMetrics.downloadMetadata)
                .foregroundStyle(theme.secondaryText)
                .accessibilityIdentifier("m2-download-progress-counts")
        }
        .accessibilityElement(children: .contain)
    }
}
