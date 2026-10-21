import Foundation
import Combine
import UIKit

enum ReaderPageLoadState: Equatable {
    case loading
    case ready
    case empty
    case failed(String)
}

struct ReaderImportPresentation: Identifiable, Equatable {
    enum Phase: Equatable { case importing, completed, failed, unresolved }
    let id: UUID
    let filename: String
    var phase: Phase
    var message: String
    var items: [ReaderImportItemPresentation] = []
}

struct ReaderImportItemPresentation: Identifiable, Equatable {
    enum Phase: Equatable { case waiting, importing, completed, failed, unresolved, skipped }
    let id: UUID
    let filename: String
    var phase: Phase = .waiting
    var message = "等待导入"
}

struct ReaderTextSelection: Equatable {
    let sourceId: String
    let bookId: String
    let chapterIndex: UInt32
    let bodyVersion: String?
    let processingVersion: String?
    let start: UInt64
    let end: UInt64
    let text: String
}

struct ReaderActiveSession {
    let id: UUID
    let book: ReaderBook
    var chapters: [ReaderChapter]
    var catalogGeneration = UUID()
    var content: ReaderChapterContent
    var scalarOffset: UInt64
    var progressRevision: String?
    var restorationID: UUID
}

/// The model owns lease identity; this boundary only invokes UIApplication.
/// Keeping it injectable lets lifecycle tests deliver an obsolete expiration
/// after a later lease has begun without relying on a real OS timeout.
@MainActor
protocol ReaderBackgroundTaskManaging {
    func begin(name: String, expiration: @escaping @MainActor () -> Void) -> UIBackgroundTaskIdentifier
    func end(_ identifier: UIBackgroundTaskIdentifier)
}

@MainActor
private final class ReaderSystemBackgroundTasks: ReaderBackgroundTaskManaging {
    func begin(name: String, expiration: @escaping @MainActor () -> Void) -> UIBackgroundTaskIdentifier {
        UIApplication.shared.beginBackgroundTask(withName: name) {
            Task { @MainActor in expiration() }
        }
    }
    func end(_ identifier: UIBackgroundTaskIdentifier) { UIApplication.shared.endBackgroundTask(identifier) }
}

/// App-owned navigation and task projections. Core remains the only book/progress store.
@MainActor
final class ReaderApplicationModel: ObservableObject {
    let actions = ReaderLibraryActionOwner()
    let readingTime: ReaderReadingTimeOwner
    let featureRecovery: ReaderFeatureRecoveryOwner
    @Published private(set) var books: [ReaderBook] = []
    @Published private(set) var libraryState: ReaderPageLoadState = .loading
    @Published private(set) var reader: ReaderActiveSession?
    @Published private(set) var openingBookID: String?
    @Published private(set) var chapterLoading = false
    @Published private(set) var closingReader = false
    @Published private(set) var importOperation: ReaderImportPresentation?
    @Published var importResultVisible = false
    @Published private(set) var recoveryMessage: String?
    @Published private(set) var feedback: String?
    @Published private(set) var foreground = true
    @Published private(set) var reconcilingImports = false
    @Published private(set) var selection: ReaderTextSelection?
    @Published private(set) var highlights: [ReaderHighlight] = []

    private let service: any ReaderLibraryServing
    private let backgroundTasks: any ReaderBackgroundTaskManaging
    private var navigationGeneration = UUID()
    private var libraryGeneration = UUID()
    private var chapterGeneration = UUID()
    private var catalogGeneration = UUID()
    private var feedbackGeneration = UUID()
    private var flushGeneration = UUID()
    private var saveDebounce: Task<Void, Never>?
    private var saveDrain: Task<Void, Never>?
    private var pendingLocation: (session: UUID, content: ReaderChapterContent, offset: UInt64)?
    private var lastConfirmedLocation: String?
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid
    private var backgroundLeaseGeneration: UUID?
    private var backgroundFlush: Task<Void, Never>?
    private var backgroundFlushGeneration: UUID?
    private var backgroundExpired = false
    private var started = false
    private var locationSaveFailed = false
    private var needsImportCleanup = false
    private var stopImportAfterCurrent = false
    private var actionSubscription: AnyCancellable?
    private var readingTimeSubscription: AnyCancellable?
    private var featureRecoverySubscription: AnyCancellable?
    private var visibleReadingTimeSession: UUID?
    private struct SourceSwitchIntent {
        let id: String
        let original: ReaderActiveSession
        let candidate: ReaderOnlineCandidate
        var oldPositionConfirmed = false
        var prepared: ReaderOnlineSwitchResult?
        var rollbackBook: ReaderBook?
        var rollbackSnapshot: ReaderProgressSnapshot?
        var rollbackFailure: String?
        var rollbackNeedsTerminal = false
    }
    @Published private var sourceSwitchIntent: SourceSwitchIntent?
    private struct LocalReprocessIntent {
        let id: String
        let original: ReaderActiveSession
        var oldPositionConfirmed = false
        var prepared: ReaderImportResult?
    }
    @Published private var localReprocessIntent: LocalReprocessIntent?
    private var localReprocessInFlight = false
    private var sourceSwitchInFlight = false
    private var sourceSwitchFlushing = false
    private var cacheWindowTask: Task<Void, Never>?
    private var cacheWindowGeneration = UUID()
    var sourceSwitchFrozen: Bool { sourceSwitchIntent != nil || localReprocessIntent != nil }


    /// Read-only feature boundary shared by local tools and online adapters.
    var libraryService: any ReaderLibraryServing { service }

    init(service: any ReaderLibraryServing, backgroundTasks: (any ReaderBackgroundTaskManaging)? = nil) {
        self.service = service
        self.readingTime = ReaderReadingTimeOwner(service: service)
        self.featureRecovery = ReaderFeatureRecoveryOwner(service: service)
        self.backgroundTasks = backgroundTasks ?? ReaderSystemBackgroundTasks()
        actionSubscription = actions.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        featureRecoverySubscription = featureRecovery.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        readingTimeSubscription = readingTime.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
            DispatchQueue.main.async { self?.updateBackgroundLease() }
        }
        actions.pendingChecker = { [weak self] id in
            if self?.sourceSwitchIntent?.id == id || self?.localReprocessIntent?.id == id { return true }
            guard let features = service as? any ReaderLibraryFeatures else { return false }
            do { return try await features.pendingFeatureOperations().contains { $0.id == id } }
            catch { return nil }
        }
    }

    var importBusy: Bool { reconcilingImports || importOperation?.phase == .importing || importOperation?.phase == .unresolved }

    func start() async {
        guard !started else { return }
        started = true
        await reconcileImports()
        await featureRecovery.reload()
        await reloadLibrary()
        if service is any ReaderReadingToolsServing { Task { await readingTime.flush() } }
    }

    func reloadLibrary() async {
        let generation = UUID()
        let navigation = navigationGeneration
        libraryGeneration = generation
        if books.isEmpty { libraryState = .loading }
        do {
            let result: [ReaderBook]
            if let features = service as? any ReaderLibraryFeatures {
                result = try await features.listBooks(query: ReaderShelfQuery(sourceId: nil))
            } else { result = try await service.listBooks() }
            guard generation == libraryGeneration, navigation == navigationGeneration else { return }
            books = result
            libraryState = result.isEmpty ? .empty : .ready
        } catch {
            guard generation == libraryGeneration, navigation == navigationGeneration else { return }
            if books.isEmpty { libraryState = .failed("书架加载失败，请重试") }
            else { showFeedback("书架刷新失败，已保留当前内容") }
        }
    }

    func importFile(_ url: URL) {
        importFiles([url])
    }

    func importFiles(_ urls: [URL]) {
        guard !importBusy else {
            showFeedback("正在处理其他导入，本次打开的文件尚未导入，请稍后重新打开")
            return
        }
        guard !urls.isEmpty else { return }
        let operation = UUID()
        stopImportAfterCurrent = false
        let items = urls.map { ReaderImportItemPresentation(id: UUID(), filename: $0.lastPathComponent) }
        importOperation = ReaderImportPresentation(id: operation,
            filename: urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) 个文件",
            phase: .importing, message: "正在导入", items: items)
        importResultVisible = true
        updateBackgroundLease()
        // Closing the result cannot cancel an accepted write. Stop only files
        // that have not been dispatched; unknown writes retain the original owner.
        Task {
            for (index, url) in urls.enumerated() {
                guard importOperation?.id == operation else { return }
                if stopImportAfterCurrent {
                    importOperation?.items[index].phase = .skipped
                    importOperation?.items[index].message = "未执行"
                    continue
                }
                importOperation?.items[index].phase = .importing
                importOperation?.items[index].message = "正在导入"
                do {
                    let result = try await service.importBook(at: url)
                    guard importOperation?.id == operation else { return }
                    importOperation?.items[index].phase = .completed
                    importOperation?.items[index].message = result.created ? "已导入书架" : "这本书已在书架中"
                    needsImportCleanup = needsImportCleanup || result.finalizationPending
                } catch {
                    guard importOperation?.id == operation else { return }
                    if case ReaderLibraryError.operationPending = error {
                        importOperation?.items[index].phase = .unresolved
                        importOperation?.items[index].message = "原导入结果待核对"
                        stopImportAfterCurrent = true
                    } else {
                        importOperation?.items[index].phase = .failed
                        importOperation?.items[index].message = error.localizedDescription
                    }
                }
            }
            guard importOperation?.id == operation, let completed = importOperation else { return }
            let unresolved = completed.items.contains { $0.phase == .unresolved }
            let success = completed.items.filter { $0.phase == .completed }.count
            let failures = completed.items.filter { $0.phase == .failed }.count
            let skipped = completed.items.filter { $0.phase == .skipped }.count
            importOperation?.phase = unresolved ? .unresolved : success == 0 && failures > 0 ? .failed : .completed
            importOperation?.message = unresolved ? "导入结果仍在确认，请保留文件" :
                urls.count == 1 && success == 1 ? completed.items[0].message :
                "已完成 \(success) 项，失败 \(failures) 项，未执行 \(skipped) 项"
            updateBackgroundLease()
            await reloadLibrary()
        }
    }

    func stopRemainingImports() {
        guard importOperation?.phase == .importing else { return }
        stopImportAfterCurrent = true
        importOperation?.message = "已停止后续文件，当前文件继续处理"
    }

    func reconcileImports() async {
        guard importOperation?.phase != .importing, !reconcilingImports else { return }
        reconcilingImports = true
        defer { reconcilingImports = false }
        let originalOperation = importOperation?.id
        do {
            let pending = try await service.recoverPendingImports()
            guard importOperation?.id == originalOperation else { return }
            needsImportCleanup = !pending.isEmpty
            if let unresolved = pending.first(where: \.requiresReconciliation) {
                importOperation = ReaderImportPresentation(id: importOperation?.id ?? UUID(), filename: unresolved.fileName,
                    phase: .unresolved, message: "导入结果仍在确认，请保留文件", items: importOperation?.items ?? [])
            } else if importOperation?.phase == .unresolved {
                importOperation?.phase = .completed
                importOperation?.message = "原导入操作已核对"
                if let items = importOperation?.items {
                    for index in items.indices where items[index].phase == .unresolved {
                        importOperation?.items[index].phase = .completed
                        importOperation?.items[index].message = "原导入操作已确认"
                    }
                }
            }
        } catch {
            guard importOperation?.id == originalOperation else { return }
            let pending = try? await service.pendingImports()
            if (ReaderLibraryService.isDefiniteMutationRejection(error) || error is ReaderImportRollbackCompletion), pending?.isEmpty == true {
                if importOperation?.phase == .unresolved {
                    importOperation?.phase = .failed
                    importOperation?.message = "原导入操作未完成，已有书籍已保留。请检查文件后重试。"
                    if let items = importOperation?.items {
                        for index in items.indices where items[index].phase == .unresolved {
                            importOperation?.items[index].phase = .failed
                            importOperation?.items[index].message = "原导入操作未完成"
                        }
                    }
                } else if importOperation == nil {
                    showFeedback("上次导入未完成，已有书籍已保留")
                }
            } else if let unresolved = pending?.first(where: \.requiresReconciliation) {
                importOperation = ReaderImportPresentation(id: importOperation?.id ?? UUID(), filename: unresolved.fileName,
                    phase: .unresolved, message: "导入结果仍在确认，请保留文件", items: importOperation?.items ?? [])
            }
        }
        updateBackgroundLease()
    }

    func open(_ book: ReaderBook, chapterIndex requestedIndex: UInt32? = nil) {
        guard !featureRecovery.blocksNewReader else { showFeedback("请先核对原换源或重新处理操作，再继续阅读"); return }
        guard openingBookID == nil, reader == nil else { return }
        let generation = UUID()
        navigationGeneration = generation
        openingBookID = book.bookId
        recoveryMessage = nil
        resetFeedback()
        Task {
            do {
                let chapters = try await service.chapters(for: book)
                let saved = try await service.progress(for: book)
                if let requestedIndex, !chapters.contains(where: { $0.index == requestedIndex }) { throw ReaderLibraryError.invalidPosition }
                let index = requestedIndex ?? saved.progress?.chapterIndex ?? chapters.first?.index ?? 0
                let selected = chapters.first(where: { $0.index == index })?.index ?? chapters.first?.index ?? 0
                let content = try await service.content(for: book, chapterIndex: selected)
                guard generation == navigationGeneration else { return }
                let sameBody = saved.progress?.chapterIndex == selected && saved.progress?.bodyVersion == content.bodyVersion &&
                    saved.progress?.processingVersion == content.processingVersion
                let offset = sameBody ? min(saved.progress?.chapterOffset ?? 0, content.scalarCount) : 0
                reader = ReaderActiveSession(id: UUID(), book: book, chapters: chapters, content: content,
                    scalarOffset: offset, progressRevision: saved.progressRevision, restorationID: UUID())
                lastConfirmedLocation = saved.found && sameBody ? locationKey(content: content, offset: offset) : nil
                locationSaveFailed = false
                openingBookID = nil
                scheduleReadingCacheWindow()
                await reloadHighlights()
            } catch {
                guard generation == navigationGeneration else { return }
                openingBookID = nil
                showFeedback("暂时无法打开这本书，请重试")
            }
        }
    }

    /// Installs only the current Core catalog projection. A catalog read never
    /// acknowledges a write or replaces the live content/position/CAS lease.
    func refreshOnlineCatalog(sessionID: UUID, bookID: String) async throws -> ReaderOnlineDetail {
        guard let current = reader, current.id == sessionID, current.book.id == bookID,
              current.book.sourceId != "local", !chapterLoading, !closingReader, !sourceSwitchFrozen,
              let online = service as? any ReaderOnlineServing else { throw ReaderLibraryError.busy }
        let generation = UUID(); catalogGeneration = generation
        let detail = try await online.refreshOnlineCatalog(for: current.book)
        try Task.checkCancellation()
        guard catalogGeneration == generation, let live = reader, live.id == sessionID,
              live.book.id == bookID, !chapterLoading, !closingReader, !sourceSwitchFrozen else {
            throw CancellationError()
        }
        guard detail.book.id == live.book.id, !detail.chapters.isEmpty,
              Set(detail.chapters.map(\.index)).count == detail.chapters.count else {
            throw ReaderLibraryError.invalidResponse("updated catalog identity")
        }
        // Keep an already displayed body only when its canonical chapter still
        // has the same identity. Reordering/rebinding is not a position remap.
        guard let before = live.chapters.first(where: { $0.index == live.content.chapterIndex }),
              let after = detail.chapters.first(where: { $0.index == live.content.chapterIndex }),
              !after.url.isEmpty, before.url == after.url else { throw ReaderLibraryError.invalidPosition }
        if live.chapters != detail.chapters {
            var updated = live
            updated.chapters = detail.chapters
            updated.catalogGeneration = UUID()
            reader = updated
        }
        return detail
    }

    func changeChapter(to index: UInt32, landingAtEnd: Bool = false) async {
        guard let current = reader, !chapterLoading, !closingReader, !sourceSwitchFrozen,
              current.chapters.contains(where: { $0.index == index }), index != current.content.chapterIndex else { return }
        let generation = UUID()
        chapterGeneration = generation
        chapterLoading = true
        cancelReadingCacheWindow()
        guard await flushReading(), reader?.id == current.id, chapterGeneration == generation else {
            chapterLoading = false
            return
        }
        do {
            let content = try await service.content(for: current.book, chapterIndex: index)
            guard reader?.id == current.id, chapterGeneration == generation else { return }
            reader?.content = content
            reader?.scalarOffset = landingAtEnd ? content.scalarCount : 0
            reader?.restorationID = UUID()
            selection = nil
            lastConfirmedLocation = nil
            chapterLoading = false
            enqueueCurrentLocation()
            scheduleReadingCacheWindow()
            await reloadHighlights()
        } catch {
            guard reader?.id == current.id, chapterGeneration == generation else { return }
            chapterLoading = false
            showFeedback("章节加载失败，已保留当前正文")
        }
    }

    func moveChapter(_ direction: Int, landingAtEnd: Bool = false) async {
        guard let current = reader,
              let position = current.chapters.firstIndex(where: { $0.index == current.content.chapterIndex }) else { return }
        let target = position + direction
        guard current.chapters.indices.contains(target) else { return }
        await changeChapter(to: current.chapters[target].index, landingAtEnd: landingAtEnd)
    }

    func recordVisibleOffset(_ offset: UInt64, sessionID: UUID, restorationID: UUID) {
        guard reader?.id == sessionID, reader?.restorationID == restorationID, !chapterLoading, !closingReader, !sourceSwitchFrozen,
              let count = reader?.content.scalarCount else { return }
        reader?.scalarOffset = min(offset, count)
        saveDebounce?.cancel()
        if !foreground {
            // A decelerating UITextView may deliver a final current-session
            // position after the background-edge flush has already finished.
            // Dispatch now so the save owns a lease before this job returns.
            saveDebounce = nil
            enqueueCurrentLocation()
            return
        }
        saveDebounce = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.enqueueCurrentLocation()
        }
    }

    func seek(to fraction: Double) {
        guard let current = reader, !chapterLoading, !closingReader, !sourceSwitchFrozen else { return }
        let fraction = min(1, max(0, fraction))
        reader?.scalarOffset = UInt64(Double(current.content.scalarCount) * fraction)
        reader?.restorationID = UUID()
        selection = nil
        enqueueCurrentLocation()
    }

    func seek(toScalar offset: UInt64) {
        guard let current = reader, !chapterLoading, !closingReader, !sourceSwitchFrozen else { return }
        reader?.scalarOffset = min(offset, current.content.scalarCount)
        reader?.restorationID = UUID()
        selection = nil
        enqueueCurrentLocation()
    }

    func jump(chapterIndex: UInt32, scalarOffset: UInt64) async {
        guard let current = reader else { return }
        if current.content.chapterIndex != chapterIndex { await changeChapter(to: chapterIndex) }
        guard reader?.id == current.id, reader?.content.chapterIndex == chapterIndex else { return }
        seek(toScalar: scalarOffset)
    }

    func jump(scope: ReaderContentPositionScope, scalarOffset: UInt64) async {
        guard let current = reader, !chapterLoading, !closingReader, !sourceSwitchFrozen,
              scope.sourceId == current.book.sourceId, scope.bookId == current.book.bookId,
              current.chapters.contains(where: { $0.index == scope.chapterIndex }) else { return }
        let generation = UUID()
        chapterGeneration = generation
        chapterLoading = true
        cancelReadingCacheWindow()
        defer { if chapterGeneration == generation { chapterLoading = false } }
        do {
            let content = try await service.content(for: current.book, chapterIndex: scope.chapterIndex)
            guard content.bodyVersion == scope.bodyVersion, content.processingVersion == scope.processingVersion,
                  scalarOffset <= content.scalarCount else { throw ReaderLibraryError.invalidPosition }
            guard await flushReading(), reader?.id == current.id, chapterGeneration == generation else { return }
            reader?.content = content
            reader?.scalarOffset = scalarOffset
            reader?.restorationID = UUID()
            selection = nil
            lastConfirmedLocation = nil
            enqueueCurrentLocation()
            scheduleReadingCacheWindow()
            await reloadHighlights()
        } catch {
            guard reader?.id == current.id, chapterGeneration == generation else { return }
            showFeedback(error.localizedDescription)
        }
    }

    func jump(node: ReaderDirectoryNode, snapshot: ReaderDirectorySnapshot) async {
        guard let current = reader, !chapterLoading, !closingReader, !sourceSwitchFrozen,
              snapshot.sourceId == current.book.sourceId, snapshot.bookId == current.book.bookId,
              let feature = service as? any ReaderLibraryFeatures else { return }
        let generation = UUID(); chapterGeneration = generation; chapterLoading = true
        cancelReadingCacheWindow()
        defer { if chapterGeneration == generation { chapterLoading = false } }
        do {
            let target = try await feature.resolveDirectoryTarget(node, in: snapshot)
            let content = try await feature.content(for: current.book, target: target)
            let offset = target.chapterOffsetScalar ?? 0
            if let scope = target.positionScope {
                guard scope == (try ReaderContentPositionScope(book: current.book, content: content)) else { throw ReaderLibraryError.invalidPosition }
            }
            guard offset <= content.scalarCount else { throw ReaderLibraryError.invalidPosition }
            guard await flushReading(), reader?.id == current.id, chapterGeneration == generation else { return }
            reader?.content = content; reader?.scalarOffset = offset; reader?.restorationID = UUID()
            selection = nil; lastConfirmedLocation = nil; enqueueCurrentLocation()
            scheduleReadingCacheWindow()
            await reloadHighlights()
        } catch {
            guard reader?.id == current.id, chapterGeneration == generation else { return }
            showFeedback(error.localizedDescription)
        }
    }

    @discardableResult
    func addBookmark(note: String = "") async -> Bool {
        guard let current = reader, !sourceSwitchFrozen, let feature = service as? any ReaderLibraryFeatures else { return false }
        let selected = selection.flatMap { $0.sourceId == current.book.sourceId && $0.bookId == current.book.bookId &&
            $0.chapterIndex == current.content.chapterIndex && $0.bodyVersion == current.content.bodyVersion &&
            $0.processingVersion == current.content.processingVersion ? $0 : nil }
        let offset = selected?.start ?? current.scalarOffset
        let text = selected?.text ?? String(current.content.content.unicodeScalars.dropFirst(Int(offset)).prefix(120))
        let result = await actions.perform("保存书签", scope: current.book.id) { id in
            _ = try await feature.createBookmark(for: current.book, content: current.content,
                scalarOffset: offset, text: text, note: note, operationID: id)
        }
        if result, reader?.id == current.id { showFeedback("书签已保存") }
        return result
    }

    func updateSelection(start: UInt64, end: UInt64, text: String, sessionID: UUID, restorationID: UUID) {
        guard let current = reader, !sourceSwitchFrozen, current.id == sessionID, current.restorationID == restorationID else { return }
        guard end > start, end <= current.content.scalarCount else { selection = nil; return }
        selection = ReaderTextSelection(sourceId: current.book.sourceId, bookId: current.book.bookId,
            chapterIndex: current.content.chapterIndex, bodyVersion: current.content.bodyVersion,
            processingVersion: current.content.processingVersion, start: start, end: end, text: text)
    }

    func reloadHighlights() async {
        guard let current = reader, let tools = service as? any ReaderReadingToolsServing else { return }
        do {
            let values = try await tools.highlights(for: current.book)
            guard reader?.id == current.id else { return }
            highlights = values
        } catch {
            guard reader?.id == current.id else { return }
            showFeedback("笔记读取失败，已有正文保留")
        }
    }

    func closeReader() async {
        guard let current = reader, !chapterLoading, !closingReader, !sourceSwitchFrozen else { return }
        closingReader = true
        cancelReadingCacheWindow()
        defer { closingReader = false }
        let generation = navigationGeneration
        guard await flushReading(), reader?.id == current.id, generation == navigationGeneration else { return }
        cancelReadingCacheWindow()
        navigationGeneration = UUID()
        chapterGeneration = UUID()
        reader = nil
        selection = nil
        highlights = []
        lastConfirmedLocation = nil
        recoveryMessage = nil
        resetFeedback()
        await reloadLibrary()
    }

    @discardableResult
    func flushReading() async -> Bool {
        guard !sourceSwitchFrozen || sourceSwitchFlushing else { return false }
        let sessionID = reader?.id
        let navigation = navigationGeneration
        let generation = UUID()
        flushGeneration = generation
        saveDebounce?.cancel()
        enqueueCurrentLocation()
        await saveDrain?.value
        guard reader?.id == sessionID, navigationGeneration == navigation, flushGeneration == generation else { return false }
        do {
            try await service.flush()
            guard reader?.id == sessionID, navigationGeneration == navigation, flushGeneration == generation else { return false }
            if !locationSaveFailed { recoveryMessage = nil }
        }
        catch {
            guard reader?.id == sessionID, navigationGeneration == navigation, flushGeneration == generation else { return false }
            recoveryMessage = "阅读位置尚未确认保存，请重试原保存操作"
        }
        return recoveryMessage == nil
    }

    private func enqueueCurrentLocation() {
        guard let current = reader, !sourceSwitchFrozen || sourceSwitchFlushing else { return }
        let key = locationKey(content: current.content, offset: current.scalarOffset)
        guard key != lastConfirmedLocation else { return }
        pendingLocation = (current.id, current.content, current.scalarOffset)
        guard saveDrain == nil else { return }
        saveDrain = Task { [weak self] in
            guard let self else { return }
            while let next = pendingLocation {
                pendingLocation = nil
                guard let current = reader, current.id == next.session else { continue }
                do {
                    if let originalReceipt = try await service.reconcilePendingProgress(for: current.book) {
                        guard reader?.id == next.session else { continue }
                        reader?.progressRevision = originalReceipt.progressRevision
                        if let progress = originalReceipt.progress {
                            lastConfirmedLocation = "\(progress.chapterIndex):\(progress.bodyVersion ?? ""):\(progress.processingVersion ?? ""):\(progress.chapterOffset)"
                        }
                        if lastConfirmedLocation == locationKey(content: next.content, offset: next.offset) {
                            locationSaveFailed = false
                            recoveryMessage = nil
                            continue
                        }
                    }
                    guard reader?.id == next.session else { continue }
                    let receipt = try await service.saveProgress(for: current.book, content: next.content,
                        scalarOffset: next.offset, expectedRevision: reader?.progressRevision)
                    guard reader?.id == next.session else { continue }
                    reader?.progressRevision = receipt.progressRevision
                    lastConfirmedLocation = locationKey(content: next.content, offset: next.offset)
                    locationSaveFailed = false
                    recoveryMessage = nil
                } catch {
                    guard reader?.id == next.session else { continue }
                    locationSaveFailed = true
                    recoveryMessage = "阅读位置尚未确认保存，请重试原保存操作"
                    break
                }
            }
            saveDrain = nil
            updateBackgroundLease()
        }
        updateBackgroundLease()
    }

    /// A switch owns the original session until Runtime confirms its terminal.
    /// An acknowledged target is retained across later Host catalog failures;
    /// retrying that adoption never sends a second switch intent.
    func switchOnlineSource(_ candidate: ReaderOnlineCandidate, operationID: String) async throws {
        guard !operationID.isEmpty, !sourceSwitchInFlight, localReprocessIntent == nil,
              let adapter = service as? any ReaderSourceSwitchServing,
              let current = reader, current.book.sourceId != "local", !chapterLoading, !closingReader else {
            throw ReaderLibraryError.busy
        }
        if let original = sourceSwitchIntent {
            guard original.id == operationID, original.original.id == current.id,
                  original.candidate == candidate else { throw ReaderLibraryError.busy }
        } else {
            guard current.book.id != candidate.id else { throw ReaderLibraryError.invalidPosition }
            sourceSwitchIntent = SourceSwitchIntent(id: operationID, original: current, candidate: candidate)
            selection = nil
            saveDebounce?.cancel(); saveDebounce = nil
            cancelReadingCacheWindow()
        }
        sourceSwitchInFlight = true
        defer { sourceSwitchInFlight = false }
        if let restoredBook = sourceSwitchIntent?.rollbackBook {
            if sourceSwitchIntent?.rollbackNeedsTerminal == true, let intent = sourceSwitchIntent {
                do {
                    _ = try await adapter.switchOnlineBook(from: intent.original.book,
                        currentChapterIndex: intent.original.content.chapterIndex,
                        currentChapterTitle: intent.original.content.chapterTitle, candidate: intent.candidate, operationID: intent.id)
                    throw ReaderLibraryError.operationPending(operationID)
                } catch let rollback as ReaderSourceSwitchRolledBack {
                    sourceSwitchIntent?.rollbackSnapshot = rollback.restoredProgressSnapshot
                    sourceSwitchIntent?.rollbackFailure = rollback.localizedDescription
                    sourceSwitchIntent?.rollbackNeedsTerminal = false
                } catch { throw ReaderLibraryError.operationPending(operationID) }
            }
            let failure = sourceSwitchIntent?.rollbackFailure ?? "已恢复原书"
            do { try await refreshRolledBackSession(restoredBook, operationID: operationID) }
            catch { throw ReaderLibraryError.operationPending(operationID) }
            throw ReaderLibraryError.core(code: "SOURCE_SWITCH_ROLLED_BACK", message: failure, retryable: false, reason: nil)
        }
        do {
            guard let intent = sourceSwitchIntent else { throw ReaderLibraryError.invalidPosition }
            if !intent.oldPositionConfirmed {
                sourceSwitchFlushing = true
                let saved = await flushReading()
                sourceSwitchFlushing = false
                guard saved, reader?.id == intent.original.id else { throw ReaderLibraryError.operationPending(operationID) }
                sourceSwitchIntent?.oldPositionConfirmed = true
            }
            if sourceSwitchIntent?.prepared == nil {
                let result = try await adapter.switchOnlineBook(from: intent.original.book,
                    currentChapterIndex: intent.original.content.chapterIndex,
                    currentChapterTitle: intent.original.content.chapterTitle, candidate: candidate, operationID: operationID)
                guard sourceSwitchIntent?.id == operationID, reader?.id == intent.original.id else {
                    throw ReaderLibraryError.operationPending(operationID)
                }
                sourceSwitchIntent?.prepared = result
            }
            guard let result = sourceSwitchIntent?.prepared,
                  result.book.id == candidate.id, result.content.sourceId == result.book.sourceId,
                  result.content.bookId == result.book.bookId else { throw ReaderLibraryError.operationPending(operationID) }
            let chapters = try await service.chapters(for: result.book)
            guard chapters.contains(where: { $0.index == result.content.chapterIndex }),
                  sourceSwitchIntent?.id == operationID, reader?.id == intent.original.id else {
                throw ReaderLibraryError.operationPending(operationID)
            }
            let position = result.progressSnapshot.progress
            let matching = position?.sourceId == result.book.sourceId && position?.bookId == result.book.bookId &&
                position?.chapterIndex == result.content.chapterIndex && position?.bodyVersion == result.content.bodyVersion &&
                position?.processingVersion == result.content.processingVersion
            let offset = matching ? min(position?.chapterOffset ?? 0, result.content.scalarCount) : 0
            saveDebounce?.cancel(); saveDebounce = nil
            pendingLocation = nil
            chapterGeneration = UUID(); navigationGeneration = UUID()
            reader = ReaderActiveSession(id: UUID(), book: result.book, chapters: chapters, content: result.content,
                scalarOffset: offset, progressRevision: result.progressSnapshot.progressRevision, restorationID: UUID())
            selection = nil; highlights = []
            lastConfirmedLocation = result.progressSnapshot.found && matching ? locationKey(content: result.content, offset: offset) : nil
            locationSaveFailed = false; recoveryMessage = nil
            sourceSwitchIntent = nil
            scheduleReadingCacheWindow()
            await reloadHighlights()
            await reloadLibrary()
        } catch {
            sourceSwitchFlushing = false
            if let rollback = error as? ReaderSourceSwitchRolledBack {
                sourceSwitchIntent?.rollbackBook = rollback.restoredBook
                sourceSwitchIntent?.rollbackSnapshot = rollback.restoredProgressSnapshot
                sourceSwitchIntent?.rollbackNeedsTerminal = false
                sourceSwitchIntent?.rollbackFailure = rollback.localizedDescription
                do { try await refreshRolledBackSession(rollback.restoredBook, operationID: operationID) }
                catch { throw ReaderLibraryError.operationPending(operationID) }
                throw error
            }
            if let refresh = error as? ReaderSourceSwitchRefreshRequired {
                sourceSwitchIntent?.rollbackBook = refresh.restoredBook
                sourceSwitchIntent?.rollbackNeedsTerminal = true
                sourceSwitchIntent?.rollbackFailure = refresh.localizedDescription
                throw ReaderLibraryError.operationPending(operationID)
            }
            if sourceSwitchIntent?.prepared != nil { throw ReaderLibraryError.operationPending(operationID) }
            if case ReaderLibraryError.operationPending = error { throw ReaderLibraryError.operationPending(operationID) }
            // Only a confirmed absence of unfinished original work releases the
            // old session. Query failure is uncertainty, never permission to write.
            if let feature = service as? any ReaderLibraryFeatures,
               let pending = try? await feature.pendingFeatureOperations(), !pending.contains(where: { $0.id == operationID }) {
                sourceSwitchIntent = nil
                scheduleReadingCacheWindow()
                throw error
            }
            throw ReaderLibraryError.operationPending(operationID)
        }
    }

    /// Reprocessing is explicit and separate from saving a rule. Core alone
    /// reparses and migrates scalar anchors; Host adopts only its new snapshot.
    func reprocessLocalCurrentBook(operationID: String) async throws {
        guard !operationID.isEmpty, !localReprocessInFlight, sourceSwitchIntent == nil,
              let feature = service as? any ReaderLibraryFeatures, let current = reader,
              current.book.sourceId == "local", !chapterLoading, !closingReader else { throw ReaderLibraryError.busy }
        if let intent = localReprocessIntent {
            guard intent.id == operationID, intent.original.id == current.id else { throw ReaderLibraryError.busy }
        } else {
            localReprocessIntent = LocalReprocessIntent(id: operationID, original: current)
            selection = nil; saveDebounce?.cancel(); saveDebounce = nil; cancelReadingCacheWindow()
        }
        localReprocessInFlight = true
        defer { localReprocessInFlight = false; sourceSwitchFlushing = false }
        do {
            guard let intent = localReprocessIntent else { throw ReaderLibraryError.invalidPosition }
            if !intent.oldPositionConfirmed {
                sourceSwitchFlushing = true
                let saved = await flushReading()
                sourceSwitchFlushing = false
                guard saved, reader?.id == intent.original.id else { throw ReaderLibraryError.operationPending(operationID) }
                localReprocessIntent?.oldPositionConfirmed = true
            }
            if localReprocessIntent?.prepared == nil {
                let result = try await feature.reprocessLocalBook(intent.original.book, operationID: operationID)
                guard localReprocessIntent?.id == operationID, reader?.id == intent.original.id else {
                    throw ReaderLibraryError.operationPending(operationID)
                }
                localReprocessIntent?.prepared = result
            }
            guard let result = localReprocessIntent?.prepared, result.book.id == intent.original.book.id else {
                throw ReaderLibraryError.operationPending(operationID)
            }
            let chapters = try await service.chapters(for: result.book)
            let snapshot = try await service.progress(for: result.book)
            let requested = snapshot.progress?.chapterIndex ?? chapters.first?.index ?? 0
            let selected = chapters.first(where: { $0.index == requested })?.index ?? chapters.first?.index ?? 0
            let content = try await service.content(for: result.book, chapterIndex: selected)
            guard localReprocessIntent?.id == operationID, reader?.id == intent.original.id else {
                throw ReaderLibraryError.operationPending(operationID)
            }
            let matching = snapshot.progress?.chapterIndex == content.chapterIndex &&
                snapshot.progress?.bodyVersion == content.bodyVersion && snapshot.progress?.processingVersion == content.processingVersion
            let offset = matching ? min(snapshot.progress?.chapterOffset ?? 0, content.scalarCount) : 0
            pendingLocation = nil; saveDebounce?.cancel(); saveDebounce = nil
            chapterGeneration = UUID(); navigationGeneration = UUID()
            reader = ReaderActiveSession(id: UUID(), book: result.book, chapters: chapters, content: content,
                scalarOffset: offset, progressRevision: snapshot.progressRevision, restorationID: UUID())
            selection = nil; highlights = []; locationSaveFailed = false; recoveryMessage = nil
            lastConfirmedLocation = snapshot.found && matching ? locationKey(content: content, offset: offset) : nil
            localReprocessIntent = nil
            await reloadHighlights(); await reloadLibrary()
        } catch {
            if localReprocessIntent?.prepared != nil { throw ReaderLibraryError.operationPending(operationID) }
            if case ReaderLibraryError.operationPending = error { throw error }
            if let pending = try? await feature.pendingFeatureOperations(), !pending.contains(where: { $0.id == operationID }) {
                localReprocessIntent = nil
                throw error
            }
            throw ReaderLibraryError.operationPending(operationID)
        }
    }

    /// Called only after Runtime's original rollback terminal. The fresh read
    /// supplies the newly leased observation revision; it never confirms rollback.
    private func refreshRolledBackSession(_ book: ReaderBook, operationID: String) async throws {
        guard let intent = sourceSwitchIntent, intent.id == operationID,
              reader?.id == intent.original.id, book.id == intent.original.book.id else {
            throw ReaderLibraryError.operationPending(operationID)
        }
        let snapshot: ReaderProgressSnapshot
        if let confirmed = intent.rollbackSnapshot { snapshot = confirmed }
        else { snapshot = try await service.progress(for: book) }
        let position = snapshot.progress
        let index = position?.chapterIndex ?? intent.original.content.chapterIndex
        let content: ReaderChapterContent
        if index == intent.original.content.chapterIndex,
           position?.bodyVersion == intent.original.content.bodyVersion,
           position?.processingVersion == intent.original.content.processingVersion {
            content = intent.original.content
        } else { content = try await service.content(for: book, chapterIndex: index) }
        guard sourceSwitchIntent?.id == operationID, reader?.id == intent.original.id else {
            throw ReaderLibraryError.operationPending(operationID)
        }
        let matching = position?.sourceId == book.sourceId && position?.bookId == book.bookId &&
            position?.chapterIndex == content.chapterIndex && position?.bodyVersion == content.bodyVersion &&
            position?.processingVersion == content.processingVersion
        let offset = matching ? min(position?.chapterOffset ?? 0, content.scalarCount) : 0
        reader?.content = content
        reader?.scalarOffset = offset
        reader?.progressRevision = snapshot.progressRevision
        reader?.restorationID = UUID()
        lastConfirmedLocation = snapshot.found && matching ? locationKey(content: content, offset: offset) : nil
        selection = nil; locationSaveFailed = false; recoveryMessage = nil
        sourceSwitchIntent = nil
        scheduleReadingCacheWindow()
    }

    private func cancelReadingCacheWindow() {
        cacheWindowGeneration = UUID()
        cacheWindowTask?.cancel(); cacheWindowTask = nil
    }

    /// Opportunistic current/adjacent-body cache, separate from the user's
    /// explicit download queue. A failed or obsolete window never clears text.
    private func scheduleReadingCacheWindow() {
        cancelReadingCacheWindow()
        guard foreground, !sourceSwitchFrozen, let current = reader, current.book.sourceId != "local",
              let downloads = service as? any ReaderDownloadServing else { return }
        let generation = cacheWindowGeneration
        cacheWindowTask = Task { [weak self] in
            do { _ = try await downloads.cacheReadingWindow(current.book, around: current.content.chapterIndex) }
            catch {
                guard let self, !Task.isCancelled, generation == cacheWindowGeneration,
                      reader?.id == current.id, reader?.content.chapterIndex == current.content.chapterIndex else { return }
                showFeedback("阅读窗口缓存暂未完成，当前正文已保留")
            }
            guard let self, generation == cacheWindowGeneration else { return }
            cacheWindowTask = nil
        }
    }

    private func locationKey(content: ReaderChapterContent, offset: UInt64) -> String {
        "\(content.chapterIndex):\(content.bodyVersion ?? ""):\(content.processingVersion ?? ""):\(offset)"
    }

    func setForeground(_ active: Bool) {
        guard foreground != active else { return }
        foreground = active
        if active {
            Task { await featureRecovery.reload() }
            scheduleReadingCacheWindow()
            backgroundExpired = false
            // The old operation may still receive its original Core reply.
            // Revoke only its lifecycle ownership, not the underlying write.
            backgroundFlushGeneration = nil
            backgroundFlush = nil
            endBackgroundTask()
            if importOperation?.phase == .unresolved || needsImportCleanup {
                Task { await reconcileImports() }
            }
        }
        if !active {
            if let visible = visibleReadingTimeSession { setReadingBodyVisible(false, sessionID: visible) }
            cancelReadingCacheWindow()
            resetFeedback()
            actions.clearFeedback()
            if backgroundFlush == nil {
                let generation = UUID()
                backgroundFlushGeneration = generation
                backgroundFlush = Task {
                    guard backgroundFlushGeneration == generation, !foreground else { return }
                    _ = await flushReading()
                    guard backgroundFlushGeneration == generation else { return }
                    backgroundFlushGeneration = nil
                    backgroundFlush = nil
                    updateBackgroundLease()
                }
            }
        }
        updateBackgroundLease()
    }

    private func updateBackgroundLease() {
        let activity = saveDrain != nil || backgroundFlush != nil || importOperation?.phase == .importing || importOperation?.phase == .unresolved || (service is any ReaderReadingToolsServing && (readingTime.flushing || readingTime.hasPending))
        guard !foreground, activity else { endBackgroundTask(); return }
        guard !backgroundExpired, backgroundTask == .invalid else { return }
        let generation = UUID()
        backgroundLeaseGeneration = generation
        backgroundTask = backgroundTasks.begin(name: "ReaderLocalOperations") { [weak self] in
            guard let self, self.backgroundLeaseGeneration == generation else { return }
            self.backgroundExpired = true
            self.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        let task = backgroundTask
        backgroundTask = .invalid
        backgroundLeaseGeneration = nil
        if task != .invalid { backgroundTasks.end(task) }
    }

    /// Visibility is a session lease, so an old reader's disappearance cannot
    /// end a newly adopted book's interval. Native layout supplies readiness.
    func setReadingBodyVisible(_ visible: Bool, sessionID: UUID) {
        guard service is any ReaderReadingToolsServing else { return }
        if visible {
            guard foreground, let current = reader, current.id == sessionID,
                  !chapterLoading, !closingReader, !sourceSwitchFrozen else { return }
            visibleReadingTimeSession = sessionID
            readingTime.setActive(true, book: current.book)
        } else if visibleReadingTimeSession == sessionID {
            visibleReadingTimeSession = nil
            readingTime.setActive(false, book: nil)
        }
    }

    func showFeedback(_ message: String) {
        guard foreground else { return }
        let generation = UUID()
        feedbackGeneration = generation
        feedback = message
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self, self.feedbackGeneration == generation else { return }
            self.feedback = nil
        }
    }

    private func resetFeedback() { feedbackGeneration = UUID(); feedback = nil }
}
