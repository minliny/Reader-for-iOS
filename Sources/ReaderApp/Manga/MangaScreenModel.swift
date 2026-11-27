import CoreGraphics
import Foundation
import Observation
import ReaderCoreBridge
import ReaderHost

@MainActor @Observable
final class MangaScreenModel {
    let session: M2AppSession
    private(set) var book: OnlineBookReference
    private(set) var coordinator: MangaReadingCoordinator?
    private(set) var viewport: MangaReadingViewport?
    private(set) var chapter: M3MangaChapterWindow?
    private(set) var loadFailed = false
    private(set) var busy = false
    private(set) var anchor = CGPoint(x: 0.5, y: 0)
    private(set) var anchorRequest = 0
    private(set) var pendingSwitch: M3MangaSourceSwitchOperationParams?
    private var dirty = false
    private var closing = false
    private var saveTask: Task<Void, Never>?
    private var generation = 0

    var currentOrdinal: Int64? { viewport?.page.ordinal }

    init(book: OnlineBookReference, session: M2AppSession) {
        self.book = book
        self.session = session
        if let network = session.sources.network {
            coordinator = .init(runtime: session.sources.runtime, host: network)
        }
    }

    func open(chapterIndex: Int64? = nil, width: Int, keepingLocation: Bool = false) async {
        guard let coordinator, !busy, !closing, pendingSwitch == nil else {
            if self.coordinator == nil { loadFailed = true }
            return
        }
        busy = true
        defer { busy = false }
        let expected = generation
        let previous = chapter?.chapterIndex
        do {
            try await flush()
            let reference = book
            try await prepareDirectory(reference)
            try check(expected)
            try await coordinator.open(sourceId: reference.sourceId, bookId: reference.bookId, chapterIndex: chapterIndex)
            try check(expected)
            guard let loaded = coordinator.chapter else { throw CoreBridgeFailure.endpointMismatch }
            let location = coordinator.progress?.location
            let isSameChapter = location?.chapter.chapterId == loaded.manifest.chapter.chapterId
            let target = isSameChapter ? coordinator.targetOrdinal ?? 0 : 0
            chapter = loaded
            loadFailed = false
            let point = isSameChapter ? location.map { CGPoint(x: $0.x, y: $0.y) } : nil
            try await show(ordinal: target, anchor: point ?? Self.start, width: width, expected: expected,
                           markForSave: !keepingLocation && previous != nil && previous != loaded.chapterIndex)
        } catch is CancellationError {
            return
        } catch {
            loadFailed = true
        }
    }

    func move(by offset: Int, width: Int) async {
        guard let currentOrdinal, let chapter, !busy, !closing, pendingSwitch == nil else { return }
        let ordinal = currentOrdinal + Int64(offset)
        guard (0..<chapter.totalPages).contains(ordinal) else { return }
        busy = true
        defer { busy = false }
        let expected = generation
        do {
            try await flush()
            try await show(ordinal: ordinal, anchor: Self.start, width: width, expected: expected, markForSave: true)
        } catch is CancellationError {
            return
        } catch {
            loadFailed = true
        }
    }

    func retry(width: Int) async {
        guard let viewport, let coordinator, !busy, !closing else { return }
        busy = true
        defer { busy = false }
        let expected = generation
        do {
            let frame = try await coordinator.page(viewport.page, in: viewport.window, width: width)
            try check(expected)
            self.viewport = .init(window: viewport.window, frame: frame)
            anchorRequest += 1
        } catch is CancellationError {
            return
        } catch {
            loadFailed = true
        }
    }

    func relocate(_ position: CGPoint) {
        guard !closing, !busy, viewport != nil, pendingSwitch == nil else { return }
        anchor = position
        dirty = true
        guard !saving else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(350))
                try await self?.savePosition()
            } catch is CancellationError {
                return
            } catch {
                self?.loadFailed = true
            }
        }
    }

    func resetPosition() {
        relocate(Self.start)
        anchorRequest += 1
    }

    func flush() async throws {
        if !dirty {
            await saveTask?.value
            return
        }
        // An admitted write runs to its terminal before another owner can open.
        if saving { await saveTask?.value }
        else { saveTask?.cancel() }
        saveTask = nil
        try await savePosition()
    }

    func retire() async {
        guard !closing else { return }
        closing = true
        do { try await flush() } catch { loadFailed = true }
        generation += 1
        viewport = nil
        chapter = nil
        await coordinator?.retire()
    }

    private var saving = false

    private func savePosition() async throws {
        guard dirty, !saving, let coordinator, let viewport, !coordinator.recoveryRequired,
              pendingSwitch == nil else { return }
        let point = anchor
        dirty = false
        saving = true
        defer { saving = false }
        do {
            _ = try await coordinator.save(page: viewport.page, in: viewport.window, originalPoint: point)
        } catch {
            dirty = true
            throw error
        }
    }

    private func show(ordinal: Int64, anchor: CGPoint, width: Int, expected: Int, markForSave: Bool) async throws {
        guard let coordinator else { throw CoreBridgeFailure.closed }
        let window = try await coordinator.readWindow(start: ordinal, limit: 1)
        guard let page = window.manifest.pages.first, page.ordinal == ordinal else {
            throw CoreBridgeFailure.endpointMismatch
        }
        let frame = try await coordinator.page(page, in: window, width: width)
        try check(expected)
        viewport = MangaReadingViewport(window: window, frame: frame)
        self.anchor = anchor
        anchorRequest += 1
        dirty = markForSave
        if markForSave { try await savePosition() }
    }

    func prepareDirectory(_ reference: OnlineBookReference, refresh: Bool = false) async throws {
        let online = OnlineReadingCoordinator(runtime: session.sources.runtime)
        if !refresh, try await online.cachedDirectory(sourceId: reference.sourceId, bookId: reference.bookId) != nil {
            return
        }
        let detail = try await online.detail(reference.detailParams)
        _ = try await online.refreshDirectory(.init(sourceId: reference.sourceId, bookId: reference.bookId,
                                                    tocUrl: detail.tocUrl, variables: detail.variables))
    }

    /// Returns the absolute Core target. The switch owner keeps the original
    /// payload until Core can resolve a lost acknowledgement.
    func switchSource(_ candidate: OnlineBookReference, width: Int) async throws -> OnlineBookReference {
        guard let coordinator, let chapter, !busy, !closing, pendingSwitch == nil else {
            throw CoreBridgeFailure.endpointMismatch
        }
        try await flush()
        if coordinator.progress?.location == nil, let viewport {
            _ = try await coordinator.save(page: viewport.page, in: viewport.window, originalPoint: anchor)
        }
        let online = OnlineReadingCoordinator(runtime: coordinator.runtime)
        let detail = try await online.detail(candidate.detailParams)
        guard detail.contentKind == .manga, let sourceVersion = detail.sourceVersion else {
            throw CoreBridgeFailure.endpointMismatch
        }
        let target = OnlineBookReference(detail: detail, sourceName: candidate.sourceName)
        try await prepareDirectory(target)
        let directory = try await online.openDirectory(.init(bookId: target.bookId, sourceId: target.sourceId))
        let cached = try await online.cachedDirectory(sourceId: target.sourceId, bookId: target.bookId)
        guard let entry = cached?.chapters.first(where: { $0.title == chapter.chapterTitle })
                ?? cached?.chapters.first(where: { $0.index == chapter.chapterIndex }) else {
            throw CoreBridgeFailure.endpointMismatch
        }
        let proof = try await MangaDirectoryProof.find(entry.index, directory: directory, online: online,
                                                      sourceId: target.sourceId, bookId: target.bookId)
        let head = try await coordinator.runtime.request(ReaderM3.mangaSourceSwitchOperationQueryV1, .init()).value.head
        let sequence = (head?.sequence ?? 0) + 1
        let intent = try await coordinator.prepareSourceSwitch(target: proof, expectedSourceVersion: sourceVersion,
            operationId: "\(UUID().uuidString.lowercased())/\(sequence)", sequence: sequence)
        pendingSwitch = intent
        do {
            let receipt = try await coordinator.commitSourceSwitch(intent)
            try checkSwitch(receipt, target: target)
        } catch {
            if let receipt = try? await coordinator.querySourceSwitch(intent).receipt {
                try checkSwitch(receipt, target: target)
            } else if error is CoreRequestFailure {
                pendingSwitch = nil
                throw error
            } else {
                throw error
            }
        }
        await adopt(target, width: width)
        return target
    }

    func reconcileSwitch(width: Int) async throws -> OnlineBookReference? {
        guard let coordinator, let pendingSwitch else { return nil }
        let result = try await coordinator.querySourceSwitch(pendingSwitch)
        guard let receipt = result.receipt else { return nil }
        let identity = pendingSwitch.firstImage.chapter
        let target = OnlineBookReference(sourceId: identity.sourceId, bookId: identity.bookId, title: book.title, isManga: true)
        try checkSwitch(receipt, target: target)
        await adopt(target, width: width)
        return target
    }

    private func adopt(_ target: OnlineBookReference, width: Int) async {
        pendingSwitch = nil
        book = target
        chapter = nil
        viewport = nil
        dirty = false
        await open(width: width, keepingLocation: true)
    }

    private func checkSwitch(_ receipt: M3MangaSourceSwitchOperationReceipt, target: OnlineBookReference) throws {
        guard let current = pendingSwitch, receipt.binding.operationId == current.operationId,
              let location = receipt.progress.location, location.chapter.sourceId == target.sourceId,
              location.chapter.bookId == target.bookId else { throw CoreBridgeFailure.endpointMismatch }
    }

    private func check(_ expected: Int) throws {
        try Task.checkCancellation()
        guard expected == generation else { throw CancellationError() }
    }

    private static let start = CGPoint(x: 0.5, y: 0)
}

struct MangaReadingViewport {
    let window: M3MangaChapterWindow
    let frame: MangaPageFrame
    var page: M3MangaManifestPage { frame.page }
}
