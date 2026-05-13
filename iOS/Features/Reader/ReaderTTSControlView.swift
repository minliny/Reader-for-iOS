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
        VStack(spacing: 12) {
            HStack {
                Text("TTS Player")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(stateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                Slider(
                    value: Binding(
                        get: { Double(player.speechRate) },
                        set: { player.speechRate = Float($0) }
                    ),
                    in: 0.25...2.0,
                    step: 0.25
                )
                Text(String(format: "%.2fx", player.speechRate))
                    .font(.caption.monospacedDigit())
                    .frame(width: 48)
            }

            HStack(spacing: 24) {
                Button(action: { player.stop() }) {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                }
                .disabled(player.playbackState == .idle || player.playbackState == .finished)

                Button(action: { player.togglePlayPause(text: contentText) }) {
                    Image(systemName: playPauseIcon)
                        .font(.title)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var playPauseIcon: String {
        switch player.playbackState {
        case .playing:
            return "pause.circle.fill"
        case .paused, .idle, .finished:
            return "play.circle.fill"
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
