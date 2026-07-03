import SwiftUI
import ReaderAppSupport

struct ReaderSourceSwitchFlowView: View {
    private let bookURL: String
    private let candidates: [SourceSwitchCandidate]
    @State private var selectedSource: String

    init(bookURL: String) {
        self.bookURL = bookURL
        let candidates = SourceSwitchCandidate.demoCandidates.sortedByLatency()
        self.candidates = candidates
        self._selectedSource = State(initialValue: candidates.first(where: { $0.state == "当前" })?.source ?? candidates.first?.source ?? "")
    }

    private var selectedCandidate: SourceSwitchCandidate {
        candidates.first { $0.source == selectedSource } ?? candidates.first ?? SourceSwitchCandidate.fallback
    }

    var body: some View {
        DemoFlowShell(title: "换源") {
            ReaderContinuitySlot(bookURL: bookURL)
        } comparisonRegion: {
            SourceSwitchWindow(
                candidates: candidates,
                selectedSource: $selectedSource
            )
        } resultRegion: {
            SourceSwitchResultCard(candidate: selectedCandidate)
        }
    }
}

private struct SourceSwitchCandidate: Identifiable, Hashable {
    let source: String
    let chapter: String
    let latestChapter: String
    let speed: String
    let updated: String
    let state: String
    let match: String
    let checkDone: Int

    var id: String { source }

    var isCurrent: Bool {
        state == "当前"
    }

    var canSwitch: Bool {
        !isCurrent && state != "落后" && state != "失效"
    }

    var rank: Double {
        let digits = speed.filter { $0.isNumber || $0 == "." }
        if let value = Double(digits) {
            return value
        }
        if speed == "离线" {
            return 900
        }
        return 9_999
    }

    static let fallback = SourceSwitchCandidate(
        source: "优书网",
        chapter: "第 32 章 雨夜",
        latestChapter: "第 32 章 雨夜",
        speed: "120 ms",
        updated: "刚刚",
        state: "当前",
        match: "100% 匹配",
        checkDone: 3
    )

    static let demoCandidates: [SourceSwitchCandidate] = [
        SourceSwitchCandidate(source: "优书网", chapter: "第 32 章 雨夜", latestChapter: "第 32 章 雨夜", speed: "120 ms", updated: "刚刚", state: "当前", match: "100% 匹配", checkDone: 3),
        SourceSwitchCandidate(source: "笔趣阁镜像", chapter: "第 32 章 雨夜", latestChapter: "第 32 章 雨夜", speed: "180 ms", updated: "2 分钟前", state: "可切换", match: "98% 匹配", checkDone: 3),
        SourceSwitchCandidate(source: "轻小说书站", chapter: "第 32 章 雨夜", latestChapter: "第 32 章 雨夜", speed: "210 ms", updated: "4 分钟前", state: "可切换", match: "97% 匹配", checkDone: 3),
        SourceSwitchCandidate(source: "云端书库", chapter: "第 32 章 雨夜", latestChapter: "第 32 章 雨夜", speed: "260 ms", updated: "7 分钟前", state: "可切换", match: "96% 匹配", checkDone: 3),
        SourceSwitchCandidate(source: "聚合书源一", chapter: "第 32 章 雨夜", latestChapter: "第 32 章 雨夜", speed: "320 ms", updated: "11 分钟前", state: "可切换", match: "95% 匹配", checkDone: 3),
        SourceSwitchCandidate(source: "聚合书源二", chapter: "第 32 章 雨夜", latestChapter: "第 32 章 雨夜", speed: "390 ms", updated: "18 分钟前", state: "可切换", match: "94% 匹配", checkDone: 3),
        SourceSwitchCandidate(source: "备用线路 A", chapter: "第 32 章 雨夜", latestChapter: "第 32 章 雨夜", speed: "510 ms", updated: "25 分钟前", state: "可切换", match: "93% 匹配", checkDone: 3),
        SourceSwitchCandidate(source: "备用线路 B", chapter: "第 32 章 雨夜", latestChapter: "第 32 章 雨夜", speed: "680 ms", updated: "42 分钟前", state: "可切换", match: "92% 匹配", checkDone: 3),
        SourceSwitchCandidate(source: "章节同步源", chapter: "第 32 章 雨夜", latestChapter: "第 32 章 雨夜", speed: "760 ms", updated: "1 小时前", state: "可切换", match: "91% 匹配", checkDone: 3),
        SourceSwitchCandidate(source: "本地缓存", chapter: "第 32 章 雨夜", latestChapter: "第 32 章 雨夜", speed: "离线", updated: "昨天 23:15", state: "可切换", match: "已缓存", checkDone: 2),
        SourceSwitchCandidate(source: "旧源备份", chapter: "第 31 章 归途", latestChapter: "第 31 章 归途", speed: "超时", updated: "3 天前", state: "落后", match: "章节落后", checkDone: 1)
    ]
}

private extension Array where Element == SourceSwitchCandidate {
    func sortedByLatency() -> [SourceSwitchCandidate] {
        enumerated()
            .sorted { left, right in
                let rankDelta = left.element.rank - right.element.rank
                if rankDelta != 0 {
                    return rankDelta < 0
                }
                return left.offset < right.offset
            }
            .map(\.element)
    }
}

private struct ReaderContinuitySlot: View {
    let bookURL: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SwiftUI.Color(red: 1.0, green: 0.97, blue: 0.91),
                    SwiftUI.Color(red: 0.96, green: 0.90, blue: 0.82)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                SourceSwitchReaderTop(bookURL: bookURL)
                    .padding(.horizontal, ReaderDesignTokens.readerTopSideInset)
                    .padding(.top, ReaderDesignTokens.readerTopTopInset)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 15) {
                Text(DemoReaderFixture.chapterTitle)
                    .font(ReaderTypography.demoSerif(size: 23, weight: .bold))
                    .lineLimit(1)
                ForEach(DemoReaderFixture.readingText.prefix(3), id: \.self) { paragraph in
                    Text(paragraph)
                        .font(ReaderTypography.demoSerif(size: ReaderDesignTokens.immersiveBodyFontSize))
                        .lineSpacing(ReaderDesignTokens.immersiveBodyFontSize * (ReaderDesignTokens.immersiveBodyLineHeight - 1))
                        .foregroundColor(SwiftUI.Color(red: 0.20, green: 0.17, blue: 0.14))
                        .lineLimit(4)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, ReaderDesignTokens.immersiveReadingLayerTopInset)
            .padding(.horizontal, 24)
            .padding(.bottom, 156)

            VStack(spacing: 8) {
                Spacer(minLength: 0)
                SourceSwitchControlSheet()
                    .padding(.horizontal, ReaderDesignTokens.readerControlSheetSideInset)
                SourceSwitchModuleNav()
                    .padding(.horizontal, ReaderDesignTokens.readerModuleNavSideInset)
                    .padding(.bottom, 18)
            }
        }
        .frame(minHeight: 560)
        .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xl)
                .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
        )
    }
}

private struct SourceSwitchReaderTop: View {
    let bookURL: String

    var body: some View {
        HStack(spacing: 10) {
            ReaderIcon(.back, size: 18, accessibilityLabel: "返回")
                .frame(width: 34, height: 34)
                .background(Circle().fill(ReaderDesignTokens.Color.surface.opacity(0.72)))
            VStack(alignment: .leading, spacing: 2) {
                Text(DemoReaderFixture.title)
                    .font(.system(size: ReaderDesignTokens.readerTopTitleFontSize, weight: .heavy))
                    .lineLimit(1)
                Text(DemoReaderFixture.sourceLine)
                    .font(.system(size: ReaderDesignTokens.readerTopSubtitleFontSize, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ReaderIcon(.sourceSwitch, size: 18, accessibilityLabel: "换源")
                .frame(width: 34, height: 34)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
        }
        .padding(.horizontal, 10)
        .frame(minHeight: ReaderDesignTokens.readerTopMinHeight)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.readerTopCornerRadius)
                .fill(ReaderDesignTokens.Color.surface.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.readerTopCornerRadius)
                        .stroke(ReaderDesignTokens.Color.mainNavBorder.opacity(0.72), lineWidth: 1)
                )
        )
    }
}

private struct SourceSwitchControlSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SourceSwitchMiniButton(icon: .directory, title: "目录")
                SourceSwitchMiniButton(icon: .sourceSwitch, title: "换源", isPrimary: true)
                SourceSwitchMiniButton(icon: .readerModuleAppearance, title: "界面")
                SourceSwitchMiniButton(icon: .readerModuleSettings, title: "设置")
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("当前书源")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.secondary)
                HStack {
                    Text("优书网")
                        .font(.system(size: 15, weight: .heavy))
                    Spacer(minLength: 0)
                    Text("120 ms")
                        .font(.system(size: 12, weight: .heavy).monospacedDigit())
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                }
                Text("已同步到第 32 章 雨夜。换源窗口保持阅读控制层可见。")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                    .fill(ReaderDesignTokens.Color.controlBackground)
            )
        }
        .padding(ReaderDesignTokens.cardPadding)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
                .fill(ReaderDesignTokens.Color.readerModuleNavBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
                        .stroke(ReaderDesignTokens.Color.readerModuleNavBorder, lineWidth: 1)
                )
        )
    }
}

private struct SourceSwitchModuleNav: View {
    private let modules: [(ReaderAssetIcon, String)] = [
        (.readerModuleDirectory, "目录"),
        (.readerModuleTts, "朗读"),
        (.readerModuleAppearance, "界面"),
        (.readerModuleSettings, "设置")
    ]

    var body: some View {
        HStack(spacing: ReaderDesignTokens.readerModuleNavGap) {
            ForEach(Array(modules.enumerated()), id: \.offset) { index, module in
                VStack(spacing: ReaderDesignTokens.readerModuleGap) {
                    ReaderIcon(module.0, size: 22, accessibilityLabel: module.1)
                        .frame(width: ReaderDesignTokens.readerModuleIconShellSize, height: ReaderDesignTokens.readerModuleIconShellSize)
                        .foregroundColor(index == 0 ? .white : ReaderDesignTokens.Color.primary)
                        .background(Circle().fill(index == 0 ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.readerModuleIconShellBackground))
                    Text(module.1)
                        .font(.system(size: ReaderDesignTokens.readerModuleFontSize, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.readerModuleTextColor)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(ReaderDesignTokens.readerModuleNavPadding)
        .frame(minHeight: ReaderDesignTokens.readerModuleNavMinHeight)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.readerModuleNavCornerRadius)
                .fill(ReaderDesignTokens.Color.readerModuleNavBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.readerModuleNavCornerRadius)
                        .stroke(ReaderDesignTokens.Color.readerModuleNavBorder, lineWidth: 1)
                )
        )
    }
}

private struct SourceSwitchMiniButton: View {
    let icon: ReaderAssetIcon
    let title: String
    var isPrimary = false

    var body: some View {
        HStack(spacing: 5) {
            ReaderIcon(icon, size: 15, accessibilityLabel: title)
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 34)
        .foregroundColor(isPrimary ? .white : ReaderDesignTokens.Color.primaryDark)
        .background(
            Capsule()
                .fill(isPrimary ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.chipBackground)
        )
    }
}

private struct SourceSwitchWindow: View {
    let candidates: [SourceSwitchCandidate]
    @Binding var selectedSource: String

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.sourceSwitchResultGap) {
                HStack(spacing: 8) {
                    ReaderIcon(.sourceSwitch, size: 18, accessibilityLabel: "换源")
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("换源")
                            .font(.system(size: 16, weight: .heavy))
                            .lineLimit(1)
                        Text("按延迟排序")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    ReaderIcon(.close, size: 16, accessibilityLabel: "关闭换源窗口")
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.secondary)
                        .background(
                            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                                .fill(ReaderDesignTokens.Color.chipBackground.opacity(0.72))
                        )
                }

                VStack(spacing: 0) {
                    ForEach(candidates) { candidate in
                        SourceSwitchCandidateRow(
                            candidate: candidate,
                            isSelected: selectedSource == candidate.source
                        ) {
                            selectedSource = candidate.source
                        }
                        if candidate.id != candidates.last?.id {
                            Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                        }
                    }
                }
            }
        }
    }
}

private struct SourceSwitchCandidateRow: View {
    let candidate: SourceSwitchCandidate
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: ReaderDesignTokens.sourceSwitchCandidateRowGap) {
                    Text(candidate.source)
                        .font(.system(size: 13, weight: .heavy))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(candidate.speed)
                        .font(.system(size: 11, weight: .heavy).monospacedDigit())
                        .foregroundColor(candidate.canSwitch || candidate.isCurrent ? ReaderDesignTokens.Color.primaryDark : .secondary)
                        .lineLimit(1)
                    Text(candidate.latestChapter)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(minWidth: 86, alignment: .trailing)
                }
                HStack(spacing: 6) {
                    SourceSwitchStatusBadge(text: candidate.state, isWarn: !candidate.canSwitch && !candidate.isCurrent)
                    Text(candidate.match)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\(candidate.checkDone)/3 检测")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.sourceSwitchCandidateRowMinHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                    .fill(isSelected ? ReaderDesignTokens.Color.primary.opacity(0.10) : SwiftUI.Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("选择 \(candidate.source)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}

private struct SourceSwitchResultCard: View {
    let candidate: SourceSwitchCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.sourceSwitchResultGap) {
            ReaderIcon(.check, size: 20, accessibilityLabel: "确认")
                .frame(width: ReaderDesignTokens.sourceSwitchResultIconSize, height: ReaderDesignTokens.sourceSwitchResultIconSize)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

            Text(candidate.source)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(SwiftUI.Color(red: 0.20, green: 0.17, blue: 0.14))
                .lineLimit(1)

            Text("\(candidate.state) · \(candidate.speed) · \(candidate.latestChapter)")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text("确认后保持当前阅读位置，仅替换正文来源与章节解析结果。")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .lineLimit(4)

            Spacer(minLength: 0)

            Button {} label: {
                Text("确认换源")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.sourceSwitchResultButtonMinHeight)
                    .background(
                        Capsule()
                            .fill(ReaderDesignTokens.Color.primaryDark)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!candidate.canSwitch && !candidate.isCurrent)
        }
        .padding(ReaderDesignTokens.sourceSwitchResultPadding)
        .frame(maxWidth: .infinity, minHeight: 248, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xl)
                .fill(ReaderDesignTokens.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xl)
                        .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                )
        )
    }
}

private struct SourceSwitchStatusBadge: View {
    let text: String
    let isWarn: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .lineLimit(1)
            .foregroundColor(isWarn ? SwiftUI.Color(red: 0.66, green: 0.38, blue: 0.08) : ReaderDesignTokens.Color.primaryDark)
            .padding(.horizontal, 7)
            .frame(minHeight: 22)
            .background(
                Capsule()
                    .fill(isWarn ? SwiftUI.Color(red: 1.0, green: 0.88, blue: 0.63, opacity: 0.82) : ReaderDesignTokens.Color.chipBackground)
            )
    }
}
