import Combine
import Foundation

/// Presentation owners only. Runtime retains every original resume/control
/// identity, acquisition child and receipt. A long resume must not disable
/// the separate pause/cancel intent lane while its acquisition is awaiting I/O.
@MainActor
final class ReaderDownloadControlOwner: ObservableObject {
    let resumeActions = ReaderLibraryActionOwner()
    let controlActions = ReaderLibraryActionOwner()
    let objectWillChange = ObservableObjectPublisher()
    private var observations = Set<AnyCancellable>()
    @Published private(set) var storage: ReaderStorageSummary?
    @Published private(set) var cleanupResult: CleanupResult?
    private var cleanupOperation: (id: String, scope: String)?
    private(set) var cleanupPresentationID = UUID()

    /// The original cleanup ACK is separate from current storage inventory.
    /// It is presentation only and never keeps a completed write pending.
    struct CleanupResult {
        enum Kind: Equatable { case completed, remaining, partiallyFailed, failed }
        let operationID: String
        let scope: String
        let summary: ReaderStorageSummary
        var kind: Kind {
            if summary.cleanupError != nil {
                return summary.removedChapters.isEmpty && summary.removedContentBytes == 0 ? .failed : .partiallyFailed
            }
            return summary.hasMore ? .remaining : .completed
        }
        var title: String {
            switch kind {
            case .completed: return "自动缓存清理完成"
            case .remaining: return "自动缓存仍有待清理项"
            case .partiallyFailed: return "自动缓存清理部分完成"
            case .failed: return "自动缓存清理未完成"
            }
        }
        var detail: String {
            let bytes = ByteCountFormatter.string(fromByteCount: Int64(clamping: summary.removedContentBytes), countStyle: .file)
            var text = "本次已清理 \(summary.removedChapters.count) 章正文，共 \(bytes)。"
            if let error = summary.cleanupError { text += "清理失败：" + error + "。" }
            if summary.hasMore { text += "仍有可清理项，本次尚未执行，可再次选择清理。" }
            return text
        }
    }

    func receiveStorageSummary(_ summary: ReaderStorageSummary) { storage = summary }

    func beginStorageCleanup(operationID: String, scope: String, presentationID: UUID) {
        guard cleanupPresentationID == presentationID,
              cleanupOperation?.id != operationID || cleanupOperation?.scope != scope else { return }
        cleanupOperation = (operationID, scope)
        cleanupResult = nil
    }

    func receiveStorageCleanupReceipt(_ summary: ReaderStorageSummary, operationID: String, scope: String, presentationID: UUID) {
        guard cleanupPresentationID == presentationID,
              cleanupOperation?.id == operationID, cleanupOperation?.scope == scope else { return }
        storage = summary
        cleanupResult = CleanupResult(operationID: operationID, scope: scope, summary: summary)
    }

    func retireStorageCleanupPresentation() {
        cleanupPresentationID = UUID()
        cleanupOperation = nil
        cleanupResult = nil
    }

    init(pendingChecker: ((String) async -> Bool?)? = nil) {
        // A missing/failed original-operation query is unknown, never proof
        // that an accepted write failed. Each child retains its exact UUID.
        let originalPending: (String) async -> Bool? = pendingChecker ?? { _ in nil }
        for owner in [resumeActions, controlActions] {
            owner.pendingChecker = originalPending
            owner.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }.store(in: &observations)
        }
    }

    var canControl: Bool { !controlActions.hasPending }
    var canResume: Bool { !resumeActions.hasPending && !controlActions.hasPending }
    var canClear: Bool { canResume }

    @discardableResult
    func performResume(scope: String, action: @escaping (String) async throws -> Void) async -> Bool {
        guard canResume else { return false }
        return await resumeActions.perform("更改下载任务", scope: scope, action: action)
    }

    @discardableResult
    func performControl(scope: String, action: @escaping (String) async throws -> Void) async -> Bool {
        guard canControl else { return false }
        return await controlActions.perform("更改下载任务", scope: scope, action: action)
    }

    @discardableResult
    func performClear(scope: String, action: @escaping (String) async throws -> Void) async -> Bool {
        guard canClear else { return false }
        return await controlActions.perform("清除此章下载", scope: scope, action: action)
    }
}
