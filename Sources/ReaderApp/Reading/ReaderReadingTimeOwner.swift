import Foundation
import Combine

private struct ReaderMeasuredReadingTime: Codable {
    let book: ReaderBook
    var elapsedMillis: Int64
    var readAt: Int64
}

private struct ReaderAcceptedReadingTime: Codable {
    let operationID: String
    let deviceID: String
    let sequence: UInt64
    let interval: ReaderMeasuredReadingTime
}

private struct ReaderReadingTimeLedger: Codable {
    let version: Int
    let deviceID: String
    var lastAcknowledgedSequence: UInt64
    var measured: [ReaderMeasuredReadingTime]
    var accepted: ReaderAcceptedReadingTime?
}

private enum ReaderReadingTimeOwnerError: LocalizedError {
    case invalidLedger, sequenceUnavailable, sequenceExhausted, durationOverflow
    var errorDescription: String? {
        switch self {
        case .invalidLedger: return "阅读计时记录无法读取，原文件已保留"
        case .sequenceUnavailable: return "阅读计时原记录与当前记录不一致，已测量间隔已保留"
        case .sequenceExhausted: return "阅读计时序号已达到上限，已测量间隔已保留"
        case .durationOverflow: return "阅读计时间隔超出可记录范围，原间隔已保留"
        }
    }
}

/// Install exactly one owner beside the App's library service: Core owns one
/// global elapsed-time lineage, not a sequence for each reader or book. The host
/// supplies only foreground/body visibility and measured monotonic durations.
///
/// Message registration: `failure` is a reading-time local ReaderPageState;
/// `actions` is the common ReaderOperationStatus for `scope`. Neither message
/// owns timing, cancellation or retry identity. A disappearing reader only calls
/// setActive(false); accepted requests and already measured intervals survive it.
@MainActor
final class ReaderReadingTimeOwner: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var flushing = false
    @Published private(set) var queuedMilliseconds: Int64 = 0
    @Published private(set) var failure: String?
    @Published private(set) var latestRecord: ReaderReadingRecord?
    @Published private(set) var blockingOperationID: String?

    let actions = ReaderLibraryActionOwner()
    let scope = "reading-time"
    var pendingOperationID: String? { ledger.accepted?.operationID }
    var pendingSequence: UInt64? { ledger.accepted?.sequence }
    var deviceID: String { ledger.deviceID }
    var hasPending: Bool { ledger.accepted != nil || actions.hasPending || blockingOperationID != nil }

    private static let maximumSequence: UInt64 = 9_007_199_254_740_991
    private let service: any ReaderLibraryServing
    private let storageURL: URL
    private let uptime: () -> TimeInterval
    private let wallMilliseconds: () -> Int64
    private var ledger: ReaderReadingTimeLedger
    private var storageReady = false
    private var unpersisted: [ReaderMeasuredReadingTime] = []
    private var openInterval: (book: ReaderBook, uptime: TimeInterval)?
    private var checkpointTask: Task<Void, Never>?
    private var actionObservation: AnyCancellable?

    init(service: any ReaderLibraryServing) {
        self.service = service
        storageURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Reader/ReadingTime/ledger-v1.json")
        uptime = { ProcessInfo.processInfo.systemUptime }
        wallMilliseconds = { max(0, Int64(Date().timeIntervalSince1970 * 1_000)) }
        ledger = ReaderReadingTimeLedger(version: 1, deviceID: UUID().uuidString.lowercased(),
            lastAcknowledgedSequence: 0, measured: [], accepted: nil)
        loadStorage()
        actions.pendingChecker = { [weak self] envelopeID in
            guard let self, let features = self.service as? any ReaderLibraryFeatures else { return nil }
            let originalID = self.ledger.accepted?.operationID ?? envelopeID
            do { return try await features.pendingFeatureOperations().contains { $0.id == originalID } }
            catch { return nil }
        }
        actionObservation = actions.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.ownerDidChange() }
        }
    }

    deinit { checkpointTask?.cancel() }

    /// The caller must pass false for background/inactive scenes, full panels,
    /// loading/failure pages, another sheet, or any other obscured body surface.
    /// Chapter/position callbacks do not participate in this measurement.
    func setActive(_ active: Bool, book: ReaderBook?) {
        let incoming = active ? book.map(Self.timingBook) : nil
        if let incoming, let openInterval, Self.sameBook(incoming, openInterval.book) { return }
        checkpoint(restart: false)
        checkpointTask?.cancel(); checkpointTask = nil
        isActive = false
        if let incoming, storageReady, service is any ReaderReadingToolsServing,
           !incoming.title.isEmpty {
            openInterval = (incoming, uptime())
            isActive = true
            checkpointTask = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(nanoseconds: 15_000_000_000) } catch { return }
                    guard let self, self.isActive else { return }
                    // The wake-up is only a checkpoint. Its count is never time
                    // and it never advances a reading position or page.
                    await self.flush()
                }
            }
        } else if active, book != nil, !(service is any ReaderReadingToolsServing) {
            failure = "当前阅读服务不支持阅读时长记录"
        }
        Task { await flush() }
    }

    /// Ends/checkpoints the currently visible interval, then serially flushes
    /// measured facts. It never automatically retries an unresolved write.
    func flush() async {
        checkpoint(restart: isActive)
        guard !flushing else { return }
        flushing = true
        defer { flushing = false }
        guard storageReady else { return }
        guard let tools = service as? any ReaderReadingToolsServing else {
            if queuedMilliseconds > 0 { failure = "当前阅读服务不支持阅读时长记录，已测量间隔已保留" }
            return
        }
        do { try persistMeasuredFacts() }
        catch { failure = "阅读计时间隔尚未保存：" + error.localizedDescription; return }
        guard !actions.hasPending, !actions.busy else { return }

        while storageReady {
            if let accepted = ledger.accepted {
                let succeeded = await performAccepted(accepted, using: tools)
                guard succeeded, ledger.accepted == nil else { return }
            } else {
                guard !ledger.measured.isEmpty else { return }
                let head: ReaderReadingTimeHead?
                do {
                    head = try await tools.readReadingTimeHead()
                    blockingOperationID = nil
                } catch ReaderLibraryError.operationPending(let originalID) {
                    blockingOperationID = originalID
                    failure = "原阅读记录操作尚待确认，已测量间隔已保留"
                    return
                } catch {
                    failure = "阅读计时序号读取失败：" + error.localizedDescription
                    return
                }
                let sequence = head?.sequence ?? 0
                guard sequence >= ledger.lastAcknowledgedSequence else {
                    failure = ReaderReadingTimeOwnerError.sequenceUnavailable.localizedDescription; return
                }
                guard sequence < Self.maximumSequence else {
                    failure = ReaderReadingTimeOwnerError.sequenceExhausted.localizedDescription; return
                }
                // A visible interval may have checkpointed while the head read
                // was suspended. Capture the latest complete measured batch.
                guard let first = ledger.measured.first else { continue }
                let accepted = ReaderAcceptedReadingTime(operationID: UUID().uuidString.lowercased(),
                    deviceID: ledger.deviceID, sequence: sequence + 1, interval: first)
                var next = ledger
                next.measured.removeFirst(); next.accepted = accepted
                do { try persist(next) }
                catch { failure = "原阅读计时操作尚未保存，未提交新记录：" + error.localizedDescription; return }
                let succeeded = await performAccepted(accepted, using: tools)
                guard succeeded, ledger.accepted == nil else { return }
            }
            do { try persistMeasuredFacts() }
            catch { failure = "阅读计时间隔尚未保存：" + error.localizedDescription; return }
        }
    }

    /// A caller may use this as the local PageState retry. OperationStatus also
    /// retries the same captured action; the original Core UUID/tuple is retained
    /// even when this owner has been reconstructed after a process restart.
    func resumeOriginal() async {
        checkpoint(restart: isActive)
        if !storageReady { loadStorage() }
        guard storageReady, !flushing, !actions.busy else { return }
        if actions.hasPending {
            _ = await actions.resumeOriginal()
            if ledger.accepted == nil { await flush() }
        } else { await flush() }
    }

    private func performAccepted(_ accepted: ReaderAcceptedReadingTime,
                                 using tools: any ReaderReadingToolsServing) async -> Bool {
        failure = nil
        let succeeded = await actions.perform("记录《\(accepted.interval.book.title)》阅读时长", scope: scope) { [self] _ in
            let interval = accepted.interval
            let record = try await tools.accumulateReadingTime(for: interval.book,
                deviceID: accepted.deviceID, elapsedMillis: interval.elapsedMillis,
                readAt: interval.readAt, sequence: accepted.sequence, operationID: accepted.operationID)
            latestRecord = record
            guard ledger.accepted?.operationID == accepted.operationID else {
                throw ReaderReadingTimeOwnerError.invalidLedger
            }
            var next = ledger
            next.accepted = nil
            next.lastAcknowledgedSequence = accepted.sequence
            do { try persist(next) }
            catch {
                failure = "阅读记录已确认，本机状态尚未保存；原操作已保留"
                throw error
            }
            blockingOperationID = nil; failure = nil
        }
        if !succeeded, !actions.hasPending, failure == nil {
            failure = "阅读时长尚未入账，原操作与已测量间隔已保留"
        }
        return succeeded
    }

    private func checkpoint(restart: Bool) {
        guard let open = openInterval else { return }
        let now = uptime()
        openInterval = restart ? (open.book, now) : nil
        guard now.isFinite, open.uptime.isFinite, now >= open.uptime else {
            failure = "阅读计时时钟暂不可用，本次未推算时长"; return
        }
        let elapsed = ((now - open.uptime) * 1_000).rounded(.down)
        guard elapsed >= 1 else { return }
        guard elapsed < Double(Int64.max) else {
            failure = ReaderReadingTimeOwnerError.durationOverflow.localizedDescription; return
        }
        let measured = ReaderMeasuredReadingTime(book: open.book, elapsedMillis: Int64(elapsed), readAt: wallMilliseconds())
        unpersisted.append(measured)
        do { try persistMeasuredFacts() }
        catch { failure = "阅读计时间隔尚未保存：" + error.localizedDescription; updateProjection() }
    }

    private func persistMeasuredFacts() throws {
        guard !unpersisted.isEmpty else { return }
        var next = ledger
        for interval in unpersisted {
            if let last = next.measured.last, Self.sameBook(last.book, interval.book) {
                let (combined, overflow) = last.elapsedMillis.addingReportingOverflow(interval.elapsedMillis)
                guard !overflow else { throw ReaderReadingTimeOwnerError.durationOverflow }
                next.measured[next.measured.count - 1].elapsedMillis = combined
                next.measured[next.measured.count - 1].readAt = interval.readAt
            } else { next.measured.append(interval) }
        }
        try persist(next, project: false)
        unpersisted.removeAll()
        updateProjection()
    }

    private func persist(_ next: ReaderReadingTimeLedger, project: Bool = true) throws {
        try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(next).write(to: storageURL, options: .atomic)
        ledger = next
        if project { updateProjection() }
    }

    private func loadStorage() {
        do {
            if FileManager.default.fileExists(atPath: storageURL.path) {
                let value = try JSONDecoder().decode(ReaderReadingTimeLedger.self, from: Data(contentsOf: storageURL))
                guard value.version == 1, UUID(uuidString: value.deviceID) != nil,
                      value.lastAcknowledgedSequence <= Self.maximumSequence,
                      value.measured.allSatisfy(Self.validInterval) else { throw ReaderReadingTimeOwnerError.invalidLedger }
                if let accepted = value.accepted {
                    guard UUID(uuidString: accepted.operationID) != nil, accepted.deviceID == value.deviceID,
                          accepted.sequence > 0, accepted.sequence <= Self.maximumSequence,
                          accepted.sequence > value.lastAcknowledgedSequence,
                          Self.validInterval(accepted.interval) else { throw ReaderReadingTimeOwnerError.invalidLedger }
                }
                ledger = value
            } else { try persist(ledger) }
            storageReady = true; failure = nil; updateProjection()
        } catch {
            storageReady = false
            failure = "阅读计时记录无法读取或保存，原文件已保留：" + error.localizedDescription
        }
    }

    private func updateProjection() {
        let intervals = ledger.measured + unpersisted + (ledger.accepted.map { [$0.interval] } ?? [])
        queuedMilliseconds = intervals.reduce(Int64(0)) { total, interval in
            let (value, overflow) = total.addingReportingOverflow(interval.elapsedMillis)
            return overflow ? Int64.max : value
        }
    }

    private func ownerDidChange() {
        objectWillChange.send()
        if !actions.busy, !actions.hasPending, ledger.accepted != nil, failure == nil {
            failure = "原阅读计时操作尚未完成核对，已测量间隔已保留"
        }
        if !actions.busy, !actions.hasPending, ledger.accepted == nil,
           !ledger.measured.isEmpty || !unpersisted.isEmpty {
            Task { await flush() }
        }
    }

    nonisolated private static func validInterval(_ value: ReaderMeasuredReadingTime) -> Bool {
        value.elapsedMillis > 0 && value.readAt >= 0 && !value.book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    nonisolated private static func sameBook(_ lhs: ReaderBook, _ rhs: ReaderBook) -> Bool {
        lhs.sourceId == rhs.sourceId && lhs.bookId == rhs.bookId && lhs.title == rhs.title && lhs.author == rhs.author
    }

    nonisolated private static func timingBook(_ book: ReaderBook) -> ReaderBook {
        // Core's legacy reading record is keyed by deviceID + trimmed bookName.
        // Keep source/book IDs locally for interval ownership, without claiming
        // that the Core history is source-isolated or partitioned by calendar day.
        ReaderBook(sourceId: book.sourceId, bookId: book.bookId,
            title: book.title.trimmingCharacters(in: .whitespacesAndNewlines), author: book.author)
    }
}
