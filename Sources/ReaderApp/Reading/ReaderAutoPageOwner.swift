import Foundation
import Combine

/// Thin platform scheduler for Host33f7 ReaderAutoPageCoordinator semantics:
/// pause preserves both remaining deadlines; another page starts only after
/// the native page/layout commit. No timer tick is treated as saved progress.
@MainActor
final class ReaderAutoPageOwner: ObservableObject {
    enum Phase: Equatable { case stopped, running, waitingForPage, paused }
    @Published private(set) var phase: Phase = .stopped
    @Published private(set) var turnID: UUID?
    @Published private(set) var progress: Double = 0
    @Published private(set) var remainingSession: Double = 900
    private var clock: Task<Void, Never>?
    private var generation = UUID()
    private var seconds: Double = 8
    private var pageRemaining: Double = 8
    private var pageDeadline: TimeInterval = 0
    private var sessionDeadline: TimeInterval = 0
    private var sessionDuration: Double = 900
    private var pendingChapter: UInt32?
    var nativePagingEnabled: Bool { phase == .running || phase == .waitingForPage }

    func start(seconds: Double, duration: Double = 900) {
        let resuming = phase == .paused
        self.seconds = max(2, min(20, seconds.rounded()))
        if !resuming {
            sessionDuration = max(0, min(10_859, duration))
            remainingSession = sessionDuration
            pageRemaining = self.seconds
        }
        pendingChapter = nil
        schedule(resetPage: !resuming)
    }
    func setSpeed(_ seconds: Double) {
        self.seconds = max(2, min(20, seconds.rounded()))
        pageRemaining = self.seconds
        if phase == .running { schedule(resetPage: true) }
    }
    func pause() {
        guard phase == .running || phase == .waitingForPage else { return }
        captureRemaining()
        retireClock(); pendingChapter = nil; turnID = nil
        if sessionDuration > 0, remainingSession <= 0 { stop() } else { phase = .paused }
    }
    func stop() {
        retireClock(); pendingChapter = nil; turnID = nil; phase = .stopped
        pageRemaining = seconds; progress = 0; remainingSession = sessionDuration
    }
    func committed(_ id: UUID) {
        guard phase == .waitingForPage, turnID == id, pendingChapter == nil else { return }
        captureRemaining(); schedule(resetPage: true)
    }
    func waitingForChapter(_ index: UInt32, turn id: UUID) {
        guard phase == .waitingForPage, turnID == id else { return }
        pendingChapter = index
    }
    func isWaitingForChapter(_ index: UInt32, turn id: UUID) -> Bool {
        phase == .waitingForPage && turnID == id && pendingChapter == index
    }
    func layoutReady(chapterIndex: UInt32) {
        guard phase == .waitingForPage, pendingChapter == chapterIndex else { return }
        pendingChapter = nil
        captureRemaining(); schedule(resetPage: true)
    }
    private func captureRemaining() {
        let now = ProcessInfo.processInfo.systemUptime
        if phase == .running { pageRemaining = max(0, pageDeadline - now) }
        if nativePagingEnabled, sessionDuration > 0 { remainingSession = max(0, sessionDeadline - now) }
    }
    private func schedule(resetPage: Bool) {
        retireClock()
        if sessionDuration > 0, remainingSession <= 0 { stop(); return }
        if resetPage || pageRemaining <= 0 { pageRemaining = seconds }
        let now = ProcessInfo.processInfo.systemUptime
        pageDeadline = now + pageRemaining
        sessionDeadline = now + remainingSession
        let current = generation
        turnID = nil; progress = max(0, min(1, 1 - pageRemaining / seconds)); phase = .running
        clock = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, generation == current, nativePagingEnabled {
                let now = ProcessInfo.processInfo.systemUptime
                if sessionDuration > 0 {
                    remainingSession = max(0, sessionDeadline - now)
                    if remainingSession <= 0 { stop(); return }
                }
                if phase == .running {
                    pageRemaining = max(0, pageDeadline - now)
                    progress = max(0, min(1, 1 - pageRemaining / seconds))
                    if pageRemaining <= 0 { phase = .waitingForPage; turnID = UUID() }
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }
    private func retireClock() { generation = UUID(); clock?.cancel(); clock = nil }
}

enum ReaderNativePageOutcome { case advanced, chapterEnd, cancelled }
