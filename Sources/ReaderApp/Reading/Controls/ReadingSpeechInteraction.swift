import Observation
import ReaderDesign
import SwiftUI

@MainActor
@Observable
final class ReadingSpeechInteraction {
    var panel = false
    private(set) var busy = false
    private(set) var engineTitle = "系统音色"
    private(set) var message: String?
    private var pending: UUID?

    func openOrStart(_ model: ReadingSessionCoordinator) async {
        if let snapshot = model.speechSession?.snapshot, snapshot.state == .playing || snapshot.state == .paused {
            panel = true
        } else {
            await start(model)
        }
    }

    func run(_ action: SpeechPlaybackAction, model: ReadingSessionCoordinator) async {
        if case .stop = action {
            retirePresentation()
            model.speechSession?.retire()
            return
        }
        guard !busy, let speech = model.speechSession else { return }
        if case .timer(let minutes) = action {
            speech.armTimer(minutes)
            return
        }
        if case .toggle = action, speech.snapshot?.state == .completed || speech.snapshot?.state == .stopped {
            await start(model)
            return
        }
        let configuration = SpeechConfiguration(runtime: model.runtime)
        await execute(model) { isCurrent in
            switch action {
            case .toggle:
                if speech.snapshot?.state == .playing { try await speech.pause() }
                else { try await speech.resume() }
            case .previous: try await speech.previous()
            case .next: try await speech.next()
            case .rate(let requested):
                let rate = try await configuration.changeRate(requested)
                guard isCurrent() else { throw CancellationError() }
                try await speech.changeRate(rate)
            case .configuration, .stop, .timer: break
            }
        }
    }

    func select(_ selection: SpeechConfiguration.Selection, model: ReadingSessionCoordinator) async {
        guard let speech = model.speechSession,
              let snapshot = speech.snapshot, [.playing, .paused].contains(snapshot.state) else { return }
        let anchor = speech.highlight?.scalarRange.lowerBound ?? model.position
        let wasPaused = snapshot.state == .paused
        await execute(model) { isCurrent in
            try await model.startSpeech(engine: selection.choice.engine, ratePercent: selection.ratePercent, anchor: anchor)
            guard isCurrent() else { throw CancellationError() }
            engineTitle = selection.title
            if wasPaused { try await model.speechSession?.pause() }
        }
    }

    func retirePresentation() {
        panel = false
        busy = false
        pending = nil
        message = nil
    }

    private func start(_ model: ReadingSessionCoordinator) async {
        guard model.canStartSpeech else { return }
        await execute(model) { isCurrent in
            let selection = try await SpeechConfiguration(runtime: model.runtime).activeSelection()
            guard isCurrent(), model.canStartSpeech else { throw CancellationError() }
            try await model.startSpeech(engine: selection.choice.engine, ratePercent: selection.ratePercent)
            if isCurrent() { engineTitle = selection.title }
        }
    }

    private func execute(_ model: ReadingSessionCoordinator,
                         action: @MainActor (_ isCurrent: @MainActor () -> Bool) async throws -> Void) async {
        guard !busy else { return }
        let token = UUID()
        let expected = model.generation
        pending = token
        busy = true
        message = nil
        defer {
            if pending == token {
                pending = nil
                busy = false
            }
        }
        do { try await action { pending == token && model.generation == expected } } catch is CancellationError {
            return
        } catch {
            guard pending == token, expected == model.generation else { return }
            message = "暂时无法朗读，请检查引擎设置后重试。"
            if !panel, let message { model.feedback(message, key: "speech-playback") }
        }
    }
}

struct ReadingSpeechOverlay: View {
    let model: ReadingSessionCoordinator
    @Bindable var interaction: ReadingSpeechInteraction
    @State private var showingConfiguration = false

    var body: some View {
        Group {
            if let snapshot = model.speechSession?.snapshot {
                SpeechCapsule(title: snapshot.chapter.chapterTitle ?? "朗读",
                              playing: snapshot.state == .playing,
                              toggle: { perform(.toggle) }, expand: { interaction.panel = true }, onAction: perform)
                    .padding(.vertical, 6)
                    .padding(.trailing, CGFloat(ReaderDesignMetrics.screenInset))
            }
        }
        .sheet(isPresented: $interaction.panel, onDismiss: { showingConfiguration = false }) {
            NavigationStack {
                playbackPanel
                    .navigationTitle("朗读播控")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") { interaction.panel = false }
                                .accessibilityIdentifier("reader-tts-panel-close")
                        }
                    }
                    .navigationDestination(isPresented: $showingConfiguration) {
                        SpeechConfigurationScreen(configuration: SpeechConfiguration(runtime: model.runtime)) { selection in
                            await interaction.select(selection, model: model)
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .onChange(of: model.speechSession?.snapshot?.state) { _, state in
                if state == nil, !interaction.busy, !showingConfiguration { interaction.panel = false }
            }
        }
    }

    @ViewBuilder private var playbackPanel: some View {
        if let speech = model.speechSession, let snapshot = speech.snapshot {
            SpeechPlaybackPanel(state: .init(title: snapshot.chapter.chapterTitle ?? "当前章节",
                engineTitle: interaction.engineTitle, playing: snapshot.state == .playing,
                sliceIndex: snapshot.currentSliceIndex.flatMap(Int.init(exactly:)),
                totalSlices: Int(clamping: snapshot.totalSlices), ratePercent: speech.activeRate ?? 100,
                timerMinutes: speech.timerMinutes,
                message: interaction.message ?? (speech.failure == nil ? nil : "此段朗读失败，可重试或更换引擎。")),
                onAction: perform)
        } else {
            ProgressView("正在准备朗读").frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func perform(_ action: SpeechPlaybackAction) {
        if case .configuration = action {
            showingConfiguration = true
        } else {
            Task { await interaction.run(action, model: model) }
        }
    }
}
