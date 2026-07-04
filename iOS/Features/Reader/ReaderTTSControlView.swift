import SwiftUI
import AVFoundation

public struct ReaderTTSControlView: View {
    @ObservedObject public var player: ReaderTTSPlayer
    public let contentText: String

    public init(player: ReaderTTSPlayer, contentText: String) {
        self.player = player
        self.contentText = contentText
    }

    public var body: some View {
        ReaderCard {
            VStack(spacing: ReaderDesignTokens.settingsSectionGap) {
                HStack(spacing: 8) {
                    ReaderIcon(.tts, size: ReaderDesignTokens.readerSessionCapsuleIconSize)
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    Text("TTS Player")
                        .font(.system(size: ReaderDesignTokens.readerModuleFontSize, weight: .black))
                    Spacer()
                    Text(stateLabel)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .black))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                }
                .frame(height: ReaderDesignTokens.readerSessionCapsuleHeight)

                HStack(spacing: 8) {
                    DemoRangeRail(
                        value: Binding(
                            get: { Double(player.speechRate) },
                            set: { player.speechRate = Float($0) }
                        ),
                        range: 0.25...2.0,
                        step: 0.25,
                        label: "朗读语速",
                        valueText: String(format: "%.2fx", player.speechRate)
                    )
                    Text(String(format: "%.2fx", player.speechRate))
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .black).monospacedDigit())
                        .frame(width: 48)
                }

                HStack(spacing: ReaderDesignTokens.rssModeRowGap) {
                    Button(action: { player.stop() }) {
                        ReaderIcon(.stop, size: 18, accessibilityLabel: "停止")
                            .frame(width: ReaderDesignTokens.readerSessionCapsuleIconSize, height: ReaderDesignTokens.readerSessionCapsuleIconSize)
                    }
                    .buttonStyle(.plain)
                    .disabled(player.playbackState == .idle || player.playbackState == .finished)

                    Button(action: { player.togglePlayPause(text: contentText) }) {
                        ReaderIcon(playPauseIcon, size: 18, accessibilityLabel: "播放或暂停")
                            .frame(width: ReaderDesignTokens.readerSessionCapsuleIconSize, height: ReaderDesignTokens.readerSessionCapsuleIconSize)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
    }

    private var playPauseIcon: ReaderAssetIcon {
        switch player.playbackState {
        case .playing:
            return .pause
        case .paused, .idle, .finished:
            return .play
        }
    }

    private var stateLabel: String {
        switch player.playbackState {
        case .idle: return "Ready"
        case .playing: return "Playing"
        case .paused: return "Paused"
        case .finished: return "Finished"
        }
    }
}
