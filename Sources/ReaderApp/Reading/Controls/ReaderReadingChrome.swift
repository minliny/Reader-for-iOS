import ReaderDesign
import SwiftUI

/// Native counterpart of the HarmonyOS reading chrome. It keeps the paper
/// palette as the single source for status and control surfaces.
struct ReaderReadingTopBar: View {
    let title: String
    let subtitle: String
    let paper: ReaderPaper
    let sourceEnabled: Bool
    let onBack: () -> Void
    let onSource: () -> Void
    let onMore: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                ReaderIcon(ReaderIconRegistry.back, squareSize: 24)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("返回")
            VStack(alignment: .leading, spacing: 2) {
                Text(title).readerTypography(ReaderDesignMetrics.readerControlBookTitle, relativeTo: .headline)
                    .lineLimit(1)
                Text(subtitle).readerTypography(ReaderDesignMetrics.readerControlChapterSource, relativeTo: .caption)
                    .foregroundStyle(paper.statusForeground.opacity(0.72)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onSource) {
                Text("换源").readerTypography(ReaderDesignMetrics.rowDetail, relativeTo: .caption)
                    .frame(minWidth: 44, minHeight: 36)
            }
            .disabled(!sourceEnabled).opacity(sourceEnabled ? 1 : 0.45)
            .accessibilityLabel("换源")
            Button(action: onMore) {
                ReaderIcon(ReaderIconRegistry.more, squareSize: 22).frame(width: 44, height: 44)
            }
            .accessibilityLabel("阅读更多操作")
        }
        .foregroundStyle(paper.statusForeground)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(paper.statusBackground, in: Capsule())
        .overlay(Capsule().stroke(paper.statusForeground.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
        .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
        .padding(.top, 6)
        .accessibilityIdentifier("reader-top-bar")
    }
}

struct ReaderReadingControlIsland: View {
    let state: ReadingControls
    let title: String
    var chapterTitle: String? = nil
    var chapterNumber: Int? = nil
    var chapterCount: Int? = nil
    let preferences: ReadingPreferences
    let onAction: (ReadingControlAction) -> Void
    let speechAvailable: Bool
    @Environment(\.readerTheme) private var theme

    var body: some View {
        VStack(spacing: 10) {
            Capsule().fill(preferences.paper.foreground.opacity(0.35)).frame(width: 38, height: 4)
            HStack {
                Text(state == .full ? "阅读设置" : title).readerTypography(ReaderDesignMetrics.readerControlBookTitle, relativeTo: .headline)
                Spacer()
                Button { onAction(state == .full ? .quick : .expand) } label: {
                    Text(state == .full ? "收起" : "展开").readerTypography(ReaderDesignMetrics.rowDetail)
                        .padding(.horizontal, 10).frame(minHeight: 32)
                        .background(preferences.paper.foreground.opacity(0.08), in: Capsule())
                }
                Button { onAction(.dismiss) } label: {
                    ReaderIcon(ReaderIconRegistry.close, squareSize: 18).frame(width: 36, height: 36)
                }
            }
            if state == .full { ReaderAppearanceSummary(preferences: preferences, onAction: onAction) }
            ReaderReadingQuickGrid(onAction: onAction, speechAvailable: speechAvailable)
            ReaderReadingProgressCard(
                chapterTitle: chapterTitle,
                chapterNumber: chapterNumber,
                chapterCount: chapterCount,
                preferences: preferences,
                onAction: onAction
            )
            ReaderReadingModuleNavigation(selected: state == .full ? "界面" : "翻页", onAction: onAction)
        }
        .foregroundStyle(preferences.paper.foreground)
        .padding(CGFloat(ReaderDesignMetrics.cardPadding))
        .background(preferences.paper.controlBackground, in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
        .shadow(color: .black.opacity(0.17), radius: 18, y: 5)
        .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
        .padding(.bottom, 10)
        .accessibilityIdentifier(state == .full ? "reader-controls-full" : "reader-controls-quick")
    }
}

private struct ReaderReadingQuickGrid: View {
    let onAction: (ReadingControlAction) -> Void
    let speechAvailable: Bool
    var body: some View {
        HStack(spacing: 8) {
            quick("目录", ReaderIconRegistry.directory, .directory)
            quick("书签", ReaderIconRegistry.bookmark, .bookmarks)
            quick("上一章", ReaderIconRegistry.previousChapter, .previous)
            quick("下一章", ReaderIconRegistry.nextChapter, .next)
            if speechAvailable { quick("朗读", ReaderIconRegistry.ttsHeadphones, .speech) }
        }
    }
    private func quick(_ title: String, _ icon: ReaderIconMapping, _ action: ReadingControlAction) -> some View {
        Button { onAction(action) } label: {
            VStack(spacing: 3) { ReaderIcon(icon, squareSize: 19); Text(title).readerTypography(ReaderDesignMetrics.readerControlChapterSource, relativeTo: .caption2) }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct ReaderReadingProgressCard: View {
    var chapterTitle: String? = nil
    var chapterNumber: Int? = nil
    var chapterCount: Int? = nil
    let preferences: ReadingPreferences
    let onAction: (ReadingControlAction) -> Void

    private var progressValue: Double {
        guard let chapterNumber, let chapterCount, chapterNumber > 0, chapterCount > 0 else { return 0 }
        return min(1, max(0, Double(chapterNumber) / Double(chapterCount)))
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack { Button("‹") { onAction(.previous) }; Spacer(); Text(chapterTitle ?? "当前章节").lineLimit(1); Spacer(); Button("›") { onAction(.next) } }
            HStack {
                if let chapterNumber, let chapterCount, chapterNumber > 0, chapterCount > 0 {
                    Text("第 \(chapterNumber) / 共 \(chapterCount) 章").readerTypography(ReaderDesignMetrics.rowDetail)
                }
                Spacer()
                Button("加书签") { onAction(.addBookmark) }.buttonStyle(.bordered)
            }
            ProgressView(value: progressValue).tint(preferences.paper.foreground)
        }
        .padding(10).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ReaderReadingModuleNavigation: View {
    let selected: String
    let onAction: (ReadingControlAction) -> Void
    var body: some View {
        HStack(spacing: 8) {
            module("翻页", ReaderIconRegistry.directory, selected == "翻页") { onAction(.quick) }
            module("朗读", ReaderIconRegistry.ttsHeadphones, selected == "朗读") { onAction(.speech) }
            module("界面", ReaderIconRegistry.readingAppearance, selected == "界面") { onAction(.expand) }
            module("设置", ReaderIconRegistry.settings, selected == "设置") { onAction(.expand) }
        }
    }
    private func module(_ title: String, _ icon: ReaderIconMapping, _ active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { VStack(spacing: 2) { ReaderIcon(icon, squareSize: 18); Text(title).readerTypography(ReaderDesignMetrics.readerControlChapterSource, relativeTo: .caption2) }.frame(maxWidth: .infinity, minHeight: 44).background(active ? Color.white.opacity(0.2) : .clear, in: Circle()) }
    }
}

private struct ReaderAppearanceSummary: View {
    let preferences: ReadingPreferences
    let onAction: (ReadingControlAction) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("主题库").readerTypography(ReaderDesignMetrics.sectionHeading, relativeTo: .subheadline)
            PaperControls(selected: preferences.paperId) { onAction(.paper($0)) }
            Text("排版库").readerTypography(ReaderDesignMetrics.sectionHeading, relativeTo: .subheadline)
            HStack { Text("字号 \(Int(preferences.fontSize))"); Spacer(); Button("−") { onAction(.size(-1)) }; Button("+") { onAction(.size(1)) } }
            HStack { Text("行距 \(preferences.lineSpacing, specifier: "%.1f")"); Spacer(); Button("−") { onAction(.spacing(-0.1)) }; Button("+") { onAction(.spacing(0.1)) } }
            HStack { Text("字距 \(preferences.letterSpacing, specifier: "%.1f")"); Spacer(); Button("−") { onAction(.tracking(-0.25)) }; Button("+" ) { onAction(.tracking(0.25)) } }
        }
    }
}
