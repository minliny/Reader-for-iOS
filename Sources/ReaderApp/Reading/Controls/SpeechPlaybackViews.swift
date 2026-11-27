import ReaderDesign
import SwiftUI

struct SpeechPlaybackPresentation {
    let title: String
    let engineTitle: String
    let playing: Bool
    let sliceIndex: Int?
    let totalSlices: Int
    let ratePercent: Int64
    let timerMinutes: Int?
    var message: String?

    var progress: Double {
        guard let sliceIndex, totalSlices > 0 else { return 0 }
        return min(1, max(0, Double(sliceIndex + 1) / Double(totalSlices)))
    }

    var position: String {
        guard let sliceIndex, totalSlices > 0 else { return "等待朗读" }
        return "第 \(sliceIndex + 1) 句，共 \(totalSlices) 句"
    }
}

enum SpeechPlaybackAction {
    case toggle, previous, next, stop, configuration
    case rate(Int64)
    case timer(Int?)
}

struct SpeechCapsule: View {
    let title: String
    let playing: Bool
    let toggle: () -> Void
    let expand: () -> Void
    var onAction: ((SpeechPlaybackAction) -> Void)?
    @Environment(\.readerTheme) private var theme

    var body: some View {
        HStack(spacing: 2) {
            Button(action: expand) {
                HStack(spacing: 5) {
                    ReaderIcon(ReaderIconRegistry.ttsHeadphones,
                               squareSize: CGFloat(ReaderDesignMetrics.ttsCapsuleHeadphonesSize))
                    Text("听书").readerTypography(ReaderDesignMetrics.ttsCapsuleLabel, relativeTo: .caption)
                    Image(systemName: "chevron.down").font(.caption2).accessibilityHidden(true)
                }
                .foregroundStyle(theme.accent)
                .padding(.leading, 9)
                .frame(minHeight: CGFloat(ReaderDesignMetrics.ttsCapsuleMinTargetHeight))
                .contentShape(Rectangle())
            }
            .accessibilityLabel("打开朗读播控")
            .accessibilityIdentifier("reader-tts-open-panel")
            Button(action: toggle) {
                ReaderIcon(playing ? ReaderIconRegistry.ttsCapsulePause : ReaderIconRegistry.ttsCapsulePlay,
                           squareSize: CGFloat(ReaderDesignMetrics.ttsCapsuleTransportIconSize))
                    .frame(width: CGFloat(ReaderDesignMetrics.ttsCapsuleControlDiameter) + 4,
                           height: CGFloat(ReaderDesignMetrics.ttsCapsuleControlDiameter) + 4)
                    .background(theme.accentFill, in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(playing ? "暂停朗读" : "继续朗读")
            .accessibilityIdentifier("reader-tts-capsule-toggle")
        }
        .buttonStyle(.plain)
        .frame(minWidth: CGFloat(ReaderDesignMetrics.ttsCapsuleMinWidth))
        .background {
            Capsule()
                .fill(theme.surface)
                .overlay { Capsule().strokeBorder(theme.outline, lineWidth: 0.5) }
                .frame(height: CGFloat(ReaderDesignMetrics.ttsCapsulePaintMinHeight) + 8)
                .shadow(color: theme.shadow.opacity(0.18), radius: 6, y: 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityValue(playing ? "朗读中" : "朗读已暂停")
        .accessibilityIdentifier("reader-tts-capsule")
        .contextMenu {
            if let onAction {
                Button("上一段") { onAction(.previous) }
                Button("下一段") { onAction(.next) }
                Button("调整语速和定时") { expand() }
                Button("停止朗读", role: .destructive) { onAction(.stop) }
            }
        }
    }
}

struct SpeechPlaybackPanel: View {
    let state: SpeechPlaybackPresentation
    let onAction: (SpeechPlaybackAction) -> Void
    @Environment(\.readerTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                transport
                HStack(spacing: 8) {
                    rateMenu
                    timerMenu
                    Button { onAction(.configuration) } label: {
                        actionLabel("引擎", icon: ReaderIconRegistry.ttsSystemEngine)
                    }
                    .accessibilityIdentifier("reader-tts-configuration")
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: CGFloat(ReaderDesignMetrics.ttsConfigPanelMaxWidth))
            .padding(.horizontal, CGFloat(ReaderDesignMetrics.ttsConfigFormInlinePadding))
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .accessibilityIdentifier("reader-tts-panel")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 10) {
                ReaderIcon(ReaderIconRegistry.ttsHeadphones, squareSize: 22)
                    .frame(width: 44, height: 44)
                    .background(theme.accentTint, in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.title)
                        .readerTypography(ReaderDesignMetrics.ttsConfigManagerTitle, relativeTo: .headline)
                        .lineLimit(2)
                    Text(state.engineTitle)
                        .readerTypography(ReaderDesignMetrics.ttsPlaybackVoice, relativeTo: .caption)
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
                Text(state.playing ? "朗读中" : "已暂停")
                    .readerTypography(ReaderDesignMetrics.ttsPlaybackQuickLabel)
                    .foregroundStyle(theme.accent)
            }
            ProgressView(value: state.progress)
                .tint(theme.accent)
                .accessibilityLabel("当前章节朗读进度")
                .accessibilityValue(state.position)
            Text(state.message ?? state.position)
                .readerTypography(ReaderDesignMetrics.ttsPlaybackStatus, relativeTo: .caption)
                .foregroundStyle(state.message == nil ? theme.secondaryText : theme.danger)
                .frame(minHeight: CGFloat(ReaderDesignMetrics.ttsPlaybackStatusMinHeight), alignment: .leading)
        }
        .padding(14)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
    }

    private var transport: some View {
        HStack(spacing: CGFloat(ReaderDesignMetrics.ttsPlaybackActionGap)) {
            control("上一段", icon: ReaderIconRegistry.ttsPrevious, action: .previous, identifier: "previous")
            Button { onAction(.toggle) } label: {
                ReaderIcon(state.playing ? ReaderIconRegistry.ttsPause : ReaderIconRegistry.ttsPlay,
                           squareSize: 19)
                    .frame(width: 54, height: 54)
                    .background(theme.accentFill, in: Circle())
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(state.playing ? "暂停朗读" : "继续朗读")
            .accessibilityIdentifier("reader-tts-panel-toggle")
            control("下一段", icon: ReaderIconRegistry.ttsNext, action: .next, identifier: "next")
            control("停止", icon: ReaderIconRegistry.ttsStop, action: .stop, identifier: "stop")
        }
    }

    private func control(_ label: String, icon: ReaderIconMapping, action: SpeechPlaybackAction,
                         identifier: String) -> some View {
        Button { onAction(action) } label: {
            VStack(spacing: 5) {
                ReaderIcon(icon, squareSize: CGFloat(ReaderDesignMetrics.ttsPlaybackTransportIconSize))
                Text(label).readerTypography(ReaderDesignMetrics.ttsPlaybackStopLabel, relativeTo: .caption)
            }
            .foregroundStyle(identifier == "stop" ? theme.danger : theme.primaryText)
            .frame(maxWidth: .infinity, minHeight: CGFloat(ReaderDesignMetrics.ttsPlaybackMinActionTarget))
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("reader-tts-\(identifier)")
    }

    private var rateMenu: some View {
        Menu {
            ForEach([50, 75, 100, 125, 150, 175, 200] as [Int64], id: \.self) { rate in
                Button(Self.rateLabel(rate)) { onAction(.rate(rate)) }
                    .accessibilityAddTraits(rate == state.ratePercent ? .isSelected : [])
            }
        } label: { actionLabel(Self.rateLabel(state.ratePercent), icon: ReaderIconRegistry.ttsRate) }
            .accessibilityLabel("朗读语速")
            .accessibilityValue(Self.rateLabel(state.ratePercent))
            .accessibilityIdentifier("reader-tts-rate")
    }

    private var timerMenu: some View {
        Menu {
            Button("关闭定时") { onAction(.timer(nil)) }
            ForEach([15, 30, 45, 60], id: \.self) { minutes in
                Button("\(minutes) 分钟后停止") { onAction(.timer(minutes)) }
            }
        } label: {
            actionLabel(state.timerMinutes.map { "\($0) 分钟" } ?? "定时", icon: ReaderIconRegistry.ttsTimer)
        }
        .accessibilityIdentifier("reader-tts-timer")
    }

    private func actionLabel(_ title: String, icon: ReaderIconMapping) -> some View {
        HStack(spacing: 5) {
            ReaderIcon(icon, squareSize: 15)
            Text(title).readerTypography(ReaderDesignMetrics.ttsPlaybackPreset, relativeTo: .caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(theme.primaryText)
        .contentShape(Rectangle())
    }

    private static func rateLabel(_ rate: Int64) -> String {
        "\((Double(rate) / 100).formatted(.number.precision(.fractionLength(0...2))))×"
    }
}
