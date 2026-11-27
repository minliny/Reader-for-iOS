import Foundation
import Observation
import ReaderCoreBridge
import ReaderHost

@MainActor
@Observable
final class SpeechSessionCoordinator {
    enum Engine: Sendable {
        case system(locale: String?)
        case http(id: Int64)
    }

    enum Failure: Error {
        case anchorUnproven
        case platformUnavailable
    }

    struct Presentation {
        let chapter: M3TtsChapterRef
        let bodyVersion: String
        let processingVersion: String
        let scalarRange: Range<Int>
    }

    private struct Session {
        let id: UUID
        let plan: M3TtsSlicePlan
        let bodyVersion: String
        let processingVersion: String
        let engine: Engine
        let ratePercent: Int64
    }

    private struct SliceRun {
        let ticket: UUID
        let sessionId: UUID
        let slice: M3TtsSlice
        let map: ScalarCoordinates
    }

    private let runtime: CoreRuntimeActor
    private let media: SpeechAndMediaHost
    private var session: Session?
    private var slice: SliceRun?
    private var desired: UUID?
    @ObservationIgnored private var playback: Task<Void, Never>?
    @ObservationIgnored private var tail: Task<Void, Never>?

    private(set) var snapshot: M3TtsQueueSnapshot?
    private(set) var highlight: Presentation?
    private(set) var failure: (any Error)?
    private(set) var nativeRangeCount = 0

    init(runtime: CoreRuntimeActor, media: SpeechAndMediaHost) {
        self.runtime = runtime
        self.media = media
    }

    func start(chapter: M3TtsChapterRef, content: String, bodyVersion: String, processingVersion: String,
               title: String, scalar: Int, engine: Engine = .system(locale: "zh-CN"),
               ratePercent: Int64 = 100) async throws {
        let generation = UUID()
        desired = generation
        invalidatePhysicalPlayback()
        try await serial { [self] in
            try await stopCoreSession()
            guard desired == generation else { throw CancellationError() }
            failure = nil
            nativeRangeCount = 0
            let map = ScalarCoordinates(content)
            guard !bodyVersion.isEmpty, !processingVersion.isEmpty, (0..<map.scalarCount).contains(scalar),
                  (50...200).contains(ratePercent) else { throw Failure.anchorUnproven }
            let plan = try await runtime.request(ReaderM3.ttsSlice,
                                                 .init(chapter: chapter, content: content, strategy: .sentence)).value.plan
            guard desired == generation else { throw CancellationError() }
            guard plan.chapter.sourceId == chapter.sourceId, plan.chapter.bookId == chapter.bookId,
                  plan.chapter.chapterIndex == chapter.chapterIndex, plan.sourceCharCount == map.scalarCount,
                  !plan.slices.isEmpty, plan.slices.enumerated().allSatisfy({ ordinal, slice in
                      guard slice.index == ordinal,
                            let low = Int(exactly: slice.charStart), let high = Int(exactly: slice.charEnd),
                            low >= 0, low < high, high <= map.scalarCount,
                            let original = map.string(low..<high) else { return false }
                      let previous = ordinal == 0 ? 0 : plan.slices[ordinal - 1].charEnd
                      return slice.charStart >= previous && original.utf16.elementsEqual(slice.text.utf16)
                  }) else { throw Failure.anchorUnproven }
            let index = plan.slices.first { $0.charEnd > scalar }?.index ?? plan.slices[plan.slices.count - 1].index
            let started = try await runtime.request(ReaderM3.ttsQueuePlay, .init(plan: plan, startSliceIndex: index)).value
            guard desired == generation else {
                _ = try await runtime.request(ReaderM3.ttsQueueStop, .init(chapter: chapter))
                throw CancellationError()
            }
            session = Session(id: generation, plan: plan, bodyVersion: bodyVersion, processingVersion: processingVersion,
                              engine: engine, ratePercent: ratePercent)
            snapshot = started.snapshot
            do {
                try media.begin(session: generation, title: title, chapter: chapter.chapterTitle) { [weak self] action in
                    guard let self, self.desired == generation else { return }
                    Task { @MainActor in await self.remote(action, generation: generation) }
                }
                try playCurrent()
            } catch {
                invalidatePhysicalPlayback()
                try await stopCoreSession()
                throw error
            }
        }
    }

    /// Display-only transitions leave the chapter scalar range with its owner.
    func currentHighlight(chapter: M3TtsChapterRef, bodyVersion: String, processingVersion: String) -> Range<Int>? {
        guard let highlight, highlight.bodyVersion == bodyVersion, highlight.processingVersion == processingVersion,
              highlight.chapter.sourceId == chapter.sourceId, highlight.chapter.bookId == chapter.bookId,
              highlight.chapter.chapterIndex == chapter.chapterIndex else { return nil }
        return highlight.scalarRange
    }

    func retire() {
        desired = nil
        invalidatePhysicalPlayback()
        let previous = tail
        tail = Task { @MainActor in
            await previous?.value
            do { try await stopCoreSession() } catch { failure = error }
        }
    }

    func drainRetirement() async { await tail?.value }

    func pause() async throws { try await control(.pause) }
    func resume() async throws { try await control(.play) }

    private func remote(_ action: SpeechRemoteAction, generation: UUID) async {
        guard desired == generation else { return }
        do { try await control(action) } catch { if desired == generation { failure = error } }
    }

    private func control(_ action: SpeechRemoteAction) async throws {
        if case .stop = action {
            retire()
            await drainRetirement()
            return
        }
        let expected = desired
        try await serial { [self] in
            guard let session, expected == desired, session.id == desired, let previous = snapshot else { return }
            let chapter = session.plan.chapter
            let resolved = action == .toggle ? (previous.state == .playing ? .pause : .play) : action
            switch resolved {
            case .pause where previous.state == .playing:
                media.pause(session: session.id)
                let paused = try await runtime.request(ReaderM3.ttsQueuePause, .init(chapter: chapter)).value
                if desired == expected { snapshot = paused.snapshot }
            case .play where previous.state == .paused:
                let resumed = try await runtime.request(ReaderM3.ttsQueueResume, .init(chapter: chapter)).value
                guard desired == expected else { return }
                snapshot = resumed.snapshot
                // If a remote response finished while paused, restart just this slice.
                if (try? media.resume(session: session.id)) == nil { try playCurrent() }
            case .next:
                let next = try await runtime.request(ReaderM3.ttsQueueNext, .init(chapter: chapter)).value
                guard desired == expected else { return }
                snapshot = next.snapshot
                try playCurrent()
            case .previous:
                let previous = try await runtime.request(ReaderM3.ttsQueuePrev, .init(chapter: chapter)).value
                guard desired == expected else { return }
                snapshot = previous.snapshot
                try playCurrent()
            default:
                return
            }
        }
    }

    private func playCurrent() throws {
        playback?.cancel()
        playback = nil
        guard let session, session.id == desired else { return }
        media.stopSlice(session: session.id)
        self.slice = nil
        highlight = nil
        guard let snapshot, snapshot.state == .playing, let index = snapshot.currentSliceIndex,
              let selected = session.plan.slices.first(where: { $0.index == index }) else {
            if snapshot?.state == .completed || snapshot?.state == .stopped { media.retire(session: session.id) }
            return
        }
        let ticket = UUID()
        self.slice = SliceRun(ticket: ticket, sessionId: session.id, slice: selected, map: ScalarCoordinates(selected.text))
        let receive: @MainActor (UUID, SpeechPhysicalEvent) -> Void = { [weak self] ticket, event in
            self?.receive(ticket, event)
        }
        switch session.engine {
        case .system(let locale):
            try media.speak(session: session.id, token: ticket, text: selected.text, locale: locale,
                            ratePercent: session.ratePercent, receive: receive)
        case .http(let id):
            playback = Task { @MainActor [weak self, runtime, media] in
                do {
                    let request = try await runtime.request(ReaderM3.httpTtsBuildRequest,
                        .init(id: id, text: selected.text, ratePercent: session.ratePercent)).value
                    guard self?.desired == session.id, self?.slice?.ticket == ticket,
                          self?.snapshot?.state == .playing else { return }
                    try await media.playRemote(session: session.id, token: ticket, request: request, receive: receive)
                    guard self?.desired == session.id, self?.slice?.ticket == ticket else { return }
                    if self?.snapshot?.state == .paused { media.pause(session: session.id) }
                    receive(ticket, .range(NSRange(location: 0, length: selected.text.utf16.count)))
                } catch is CancellationError {
                    return
                } catch {
                    receive(ticket, .failed)
                }
            }
        }
    }

    private func receive(_ ticket: UUID, _ event: SpeechPhysicalEvent) {
        guard let session, let slice, desired == session.id, ticket == slice.ticket else { return }
        switch event {
        case .range(let range):
            guard range.location >= 0, range.length > 0, range.location <= slice.map.utf16Count,
                  range.length <= slice.map.utf16Count - range.location,
                  let low = slice.map.scalar(at: range.location),
                  let high = slice.map.scalar(at: range.location + range.length), low < high else { return }
            if case .system = session.engine { nativeRangeCount += 1 }
            let offset = Int(slice.slice.charStart)
            highlight = Presentation(chapter: session.plan.chapter, bodyVersion: session.bodyVersion,
                                     processingVersion: session.processingVersion, scalarRange: (offset + low)..<(offset + high))
        case .finished, .failed:
            Task { @MainActor in
                do {
                    try await serial { [self] in
                        guard self.slice?.ticket == ticket, desired == session.id, snapshot?.state == .playing else { return }
                        let status: M3TtsSliceStatus
                        if case .finished = event { status = .done } else { status = .failed }
                        let result = try await runtime.request(ReaderM3.ttsQueueReportCallback, .init(
                            chapter: session.plan.chapter, sliceIndex: slice.slice.index,
                            status: status, callbackId: ticket.uuidString, failurePolicy: .stop
                        )).value
                        guard self.slice?.ticket == ticket, desired == session.id else { return }
                        snapshot = result.snapshot
                        if status == .failed { failure = Failure.platformUnavailable }
                        try playCurrent()
                    }
                } catch {
                    guard desired == session.id else { return }
                    failure = error
                    invalidatePhysicalPlayback()
                }
            }
        }
    }

    private func invalidatePhysicalPlayback() {
        playback?.cancel()
        playback = nil
        slice = nil
        highlight = nil
        if let session { media.retire(session: session.id) }
    }

    private func stopCoreSession() async throws {
        guard let session else { return }
        self.session = nil
        snapshot = nil
        _ = try await runtime.request(ReaderM3.ttsQueueStop, .init(chapter: session.plan.chapter))
    }

    private func serial(_ action: @escaping @MainActor () async throws -> Void) async throws {
        let previous = tail
        let next = Task { @MainActor in
            await previous?.value
            try await action()
        }
        tail = Task { @MainActor in _ = await next.result }
        try await next.value
    }
}
