import Foundation
import Observation
import ReaderCoreBridge
import ReaderDesign
import ReaderHost

struct BookIdentity: Hashable {
    let sourceId: String
    let bookId: String

    init(_ book: BookshelfEntryData) {
        sourceId = book.sourceId
        bookId = book.bookId
    }

    var query: BookshelfGetParams { .init(sourceId: sourceId, bookId: bookId) }
}

struct ShelfRecovery {
    let title: String
    let message: String
    let generation: Int
    var action: ReaderRecoveryAction? = nil
}

struct ImportProgress {
    let total: Int
    var completed = 0
    var failed = 0
}

@MainActor
@Observable
final class ShelfModel {
    private(set) var books: [BookshelfEntryData]?
    private(set) var error: String?
    private(set) var recovery: ShelfRecovery?
    private(set) var task: ImportProgress?
    private(set) var library: LibraryHost?
    private(set) var online: M2AppSession?
    private(set) var files: FileAndAssetHost?
    private var journal: ImportJournal?
    private var booting = false
    private var listGeneration = 0
    private var recoveryGeneration = 0
    private var importRunning = false
    let toast = ReaderToastPresenter()
    var frontmost = true
    var sceneActive = true
    var sort = ShelfSort.added

    var state: ReaderPageState? {
        if let books { return books.isEmpty ? .empty("书架还没有书籍") : nil }
        if let error { return .failed(error, actionGeneration: listGeneration) }
        return .loading
    }

    func start(root: URL, sandboxRoots: [URL] = []) async {
        guard library == nil, !booting else { return }
        booting = true
        defer { booting = false }
        error = nil
        do {
            let assets = root.appending(path: "Assets", directoryHint: .isDirectory)
            let library = try await LibraryHost.open(directory: root.appending(path: "Library", directoryHint: .isDirectory))
            self.library = library
            let online = M2AppSession(library: library, root: root)
            self.online = online
            files = FileAndAssetHost(root: assets, sandboxRoots: sandboxRoots)
            journal = ImportJournal(root: assets)
            await reload()
            await checkRecovery()
            await online.recoverDownloads()
        } catch {
            self.error = "无法打开本地书库，请重试。"
        }
    }

    func retry(root: URL, expected: Int) async {
        guard expected == listGeneration, frontmost, sceneActive else { return }
        if library != nil { await reload() } else { await start(root: root) }
    }

    func reload() async {
        guard let runtime = library?.runtime else { return }
        listGeneration += 1
        let generation = listGeneration
        let order: BookshelfListParamsSortBy = switch sort {
        case .added: .addedAt
        case .read: .lastReadAt
        case .title: .title
        }
        do {
            var items: [BookshelfEntryData] = []
            var offset: Int64 = 0
            while true {
                let response = try await runtime.request(ReaderM1.bookshelfList, .init(
                    sourceKind: .local, sortBy: order, sortDirection: sort == .title ? .ascending : .descending,
                    offset: offset, limit: 100
                )).value
                guard generation == listGeneration else { return }
                items.append(contentsOf: response.books)
                offset += Int64(response.books.count)
                if offset >= response.total || response.books.isEmpty { break }
            }
            books = items
            error = nil
        } catch {
            guard generation == listGeneration else { return }
            if books == nil { self.error = "暂时无法读取书架。" }
            else { feedback("无法刷新书架", key: "shelf-refresh") }
        }
    }

    func importFiles(_ urls: [URL]) {
        guard !urls.isEmpty, !importRunning, let runtime = library?.runtime,
              let files, let journal else { return }
        importRunning = true
        task = ImportProgress(total: urls.count)
        let coordinator = LocalImportCoordinator(runtime: runtime, files: files, journal: journal)
        Task { await importSelection(urls, coordinator: coordinator) }
    }

    private func importSelection(_ urls: [URL], coordinator: LocalImportCoordinator) async {
        for url in urls {
            do {
                _ = try await coordinator.importSelectedFile(url)
                task?.completed += 1
            } catch {
                task?.failed += 1
            }
        }
        importRunning = false
        await reload()
        await checkRecovery()
        if let task {
            feedback(task.failed == 0 ? "已加入书架" : "已导入 \(task.completed) 本，\(task.failed) 本未导入",
                     key: "local-import")
        }
    }

    func clearFinishedTask() {
        guard !importRunning else { return }
        task = nil
    }

    @discardableResult
    func remove(_ identity: BookIdentity) async -> Bool {
        guard let runtime = library?.runtime else { return false }
        do {
            let result = try await runtime.request(ReaderM1.bookshelfRemove,
                BookshelfRemoveParams(sourceId: identity.sourceId, bookId: identity.bookId))
            await reload()
            if result.value.removed { feedback("已从书架移除", key: "shelf-remove") }
            return result.value.removed
        } catch {
            feedback("暂时无法确认移除结果", key: "shelf-remove-error")
            await reload()
            return false
        }
    }

    func checkRecovery() async {
        guard let journal else { return }
        recoveryGeneration += 1
        let expected = recoveryGeneration
        do {
            let pending = try await journal.pending()
            guard expected == recoveryGeneration else { return }
            recovery = pending.isEmpty ? nil : ShelfRecovery(
                title: "导入待核对",
                message: "有 \(pending.count) 项原操作需要核对。已确认的藏书仍可阅读。",
                generation: expected,
                action: ReaderRecoveryAction(title: "核对", generation: expected)
            )
        } catch {
            guard expected == recoveryGeneration else { return }
            recovery = ShelfRecovery(title: "导入记录暂不可读", message: "保留了本地原操作记录。", generation: expected,
                action: ReaderRecoveryAction(title: "重查", generation: expected))
        }
    }

    func recover(expected: Int, action: Int) async {
        guard !importRunning, frontmost, sceneActive, expected == recovery?.generation,
              action == recovery?.action?.generation,
              let journal, let files, let runtime = library?.runtime else { return }
        let coordinator = LocalImportCoordinator(runtime: runtime, files: files, journal: journal)
        await coordinator.verifyPending()
        await reload()
        await checkRecovery()
    }

    private func feedback(_ message: String, key: String) {
        _ = toast.show(message: message, key: key, feedbackEnabled: frontmost, sceneActive: sceneActive)
    }
}
