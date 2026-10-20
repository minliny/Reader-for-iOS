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
}

struct ReaderActiveSession {
    let id: UUID
    let book: ReaderBook
    let chapters: [ReaderChapter]
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

    private let service: any ReaderLibraryServing
    private let backgroundTasks: any ReaderBackgroundTaskManaging
    private var navigationGeneration = UUID()
    private var libraryGeneration = UUID()
    private var chapterGeneration = UUID()
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

    init(service: any ReaderLibraryServing, backgroundTasks: (any ReaderBackgroundTaskManaging)? = nil) {
        self.service = service
        self.backgroundTasks = backgroundTasks ?? ReaderSystemBackgroundTasks()
    }

    var importBusy: Bool { reconcilingImports || importOperation?.phase == .importing || importOperation?.phase == .unresolved }

    func start() async {
        guard !started else { return }
        started = true
        await reconcileImports()
        await reloadLibrary()
    }

    func reloadLibrary() async {
        let generation = UUID()
        let navigation = navigationGeneration
        libraryGeneration = generation
        if books.isEmpty { libraryState = .loading }
        do {
            let result = try await service.listBooks()
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
        guard !importBusy else { importResultVisible = true; return }
        let operation = UUID()
        importOperation = ReaderImportPresentation(id: operation, filename: url.lastPathComponent,
            phase: .importing, message: "正在导入")
        importResultVisible = true
        updateBackgroundLease()
        // This task belongs to the runtime, not to the picker/result surface.
        Task {
            do {
                let result = try await service.importBook(at: url)
                guard importOperation?.id == operation else { return }
                importOperation?.phase = .completed
                importOperation?.message = result.created ? "已导入书架" : "这本书已在书架中"
                needsImportCleanup = result.finalizationPending
                updateBackgroundLease()
                await reloadLibrary()
            } catch {
                guard importOperation?.id == operation else { return }
                if case ReaderLibraryError.operationPending = error {
                    importOperation?.phase = .unresolved
                    importOperation?.message = "导入结果仍在确认，请保留文件"
                } else {
                    importOperation?.phase = .failed
                    importOperation?.message = "导入失败，原有书籍已保留。请检查文件后重试。"
                }
                updateBackgroundLease()
            }
        }
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
                    phase: .unresolved, message: "导入结果仍在确认，请保留文件")
            } else if importOperation?.phase == .unresolved {
                importOperation?.phase = .completed
                importOperation?.message = "原导入操作已核对"
            }
        } catch {
            guard importOperation?.id == originalOperation else { return }
            let pending = try? await service.pendingImports()
            if (ReaderLibraryService.isDefiniteMutationRejection(error) || error is ReaderImportRollbackCompletion), pending?.isEmpty == true {
                if importOperation?.phase == .unresolved {
                    importOperation?.phase = .failed
                    importOperation?.message = "原导入操作未完成，已有书籍已保留。请检查文件后重试。"
                } else if importOperation == nil {
                    showFeedback("上次导入未完成，已有书籍已保留")
                }
            } else if let unresolved = pending?.first(where: \.requiresReconciliation) {
                importOperation = ReaderImportPresentation(id: importOperation?.id ?? UUID(), filename: unresolved.fileName,
                    phase: .unresolved, message: "导入结果仍在确认，请保留文件")
            }
        }
        updateBackgroundLease()
    }

    func open(_ book: ReaderBook) {
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
                let index = saved.progress?.chapterIndex ?? chapters.first?.index ?? 0
                let selected = chapters.first(where: { $0.index == index })?.index ?? chapters.first?.index ?? 0
                let content = try await service.content(for: book, chapterIndex: selected)
                guard generation == navigationGeneration else { return }
                let sameBody = saved.progress?.bodyVersion == content.bodyVersion &&
                    saved.progress?.processingVersion == content.processingVersion
                let offset = sameBody ? min(saved.progress?.chapterOffset ?? 0, content.scalarCount) : 0
                reader = ReaderActiveSession(id: UUID(), book: book, chapters: chapters, content: content,
                    scalarOffset: offset, progressRevision: saved.progressRevision, restorationID: UUID())
                lastConfirmedLocation = saved.found && sameBody ? locationKey(content: content, offset: offset) : nil
                locationSaveFailed = false
                openingBookID = nil
            } catch {
                guard generation == navigationGeneration else { return }
                openingBookID = nil
                showFeedback("暂时无法打开这本书，请重试")
            }
        }
    }

    func changeChapter(to index: UInt32) async {
        guard let current = reader, !chapterLoading, !closingReader,
              current.chapters.contains(where: { $0.index == index }), index != current.content.chapterIndex else { return }
        let generation = UUID()
        chapterGeneration = generation
        chapterLoading = true
        guard await flushReading(), reader?.id == current.id, chapterGeneration == generation else {
            chapterLoading = false
            return
        }
        do {
            let content = try await service.content(for: current.book, chapterIndex: index)
            guard reader?.id == current.id, chapterGeneration == generation else { return }
            reader?.content = content
            reader?.scalarOffset = 0
            reader?.restorationID = UUID()
            lastConfirmedLocation = nil
            chapterLoading = false
            enqueueCurrentLocation()
        } catch {
            guard reader?.id == current.id, chapterGeneration == generation else { return }
            chapterLoading = false
            showFeedback("章节加载失败，已保留当前正文")
        }
    }

    func moveChapter(_ direction: Int) async {
        guard let current = reader,
              let position = current.chapters.firstIndex(where: { $0.index == current.content.chapterIndex }) else { return }
        let target = position + direction
        guard current.chapters.indices.contains(target) else { return }
        await changeChapter(to: current.chapters[target].index)
    }

    func recordVisibleOffset(_ offset: UInt64, sessionID: UUID, restorationID: UUID) {
        guard reader?.id == sessionID, reader?.restorationID == restorationID, !chapterLoading, !closingReader,
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
        guard let current = reader, !chapterLoading, !closingReader else { return }
        let fraction = min(1, max(0, fraction))
        reader?.scalarOffset = UInt64(Double(current.content.scalarCount) * fraction)
        reader?.restorationID = UUID()
        enqueueCurrentLocation()
    }

    func closeReader() async {
        guard let current = reader, !chapterLoading, !closingReader else { return }
        closingReader = true
        defer { closingReader = false }
        let generation = navigationGeneration
        guard await flushReading(), reader?.id == current.id, generation == navigationGeneration else { return }
        navigationGeneration = UUID()
        chapterGeneration = UUID()
        reader = nil
        lastConfirmedLocation = nil
        recoveryMessage = nil
        resetFeedback()
        await reloadLibrary()
    }

    @discardableResult
    func flushReading() async -> Bool {
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
        guard let current = reader else { return }
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

    private func locationKey(content: ReaderChapterContent, offset: UInt64) -> String {
        "\(content.chapterIndex):\(content.bodyVersion ?? ""):\(content.processingVersion ?? ""):\(offset)"
    }

    func setForeground(_ active: Bool) {
        guard foreground != active else { return }
        foreground = active
        if active {
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
            resetFeedback()
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
        let activity = saveDrain != nil || backgroundFlush != nil || importOperation?.phase == .importing || importOperation?.phase == .unresolved
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

    private func showFeedback(_ message: String) {
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
