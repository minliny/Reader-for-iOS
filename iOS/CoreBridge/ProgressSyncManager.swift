import Foundation
import ReaderCoreModels
import ReaderAppSupport
import ReaderCoreNativeAdapter

// MARK: - Sync Trigger

public enum ProgressSyncTrigger: String, Sendable, CaseIterable {
    case exitReader
    case returnToBookshelf
    case appBackground
    case appWillTerminate
    case appLaunch
    case bookOpen
}

// MARK: - Sync State

public enum ProgressSyncState: Equatable, Sendable {
    case idle
    case syncing
    case success(result: ProgressSyncResult)
    case failed(message: String)
    case conflict(local: ReadingProgress, remote: ReadingProgress)
}

// MARK: - Sync Manager

@MainActor
public final class ProgressSyncManager: ObservableObject, Sendable {
    public static let shared = ProgressSyncManager()

    @Published public private(set) var syncState: ProgressSyncState = .idle
    @Published public private(set) var lastSyncAt: Date?
    @Published public private(set) var syncResults: [ProgressSyncResult] = []

    private var adapter: (any ProgressSyncAdapterProtocol)?
    private var conflictResolver: ProgressSyncConflictResolver

    /// Timeout for Core bridge calls (sync.conflict.resolve is a computation).
    private static let coreTimeout: TimeInterval = 10

    private static var requestCounter: UInt64 = 300_000
    private static let counterLock = NSLock()

    private static func nextRequestId() -> UInt64 {
        counterLock.lock()
        defer { counterLock.unlock() }
        requestCounter += 1
        return requestCounter
    }

    public var isSyncEnabled: Bool {
        adapter != nil
    }

    private init() {
        self.conflictResolver = ProgressSyncConflictResolver(policy: .manualRequired)
    }

    // MARK: - Configuration

    public func configure(
        adapter: any ProgressSyncAdapterProtocol,
        conflictPolicy: ProgressSyncConflictPolicy = .manualRequired
    ) {
        self.adapter = adapter
        self.conflictResolver = ProgressSyncConflictResolver(policy: conflictPolicy)
    }

    public func resetConfiguration() {
        adapter = nil
        conflictResolver = ProgressSyncConflictResolver(policy: .manualRequired)
        syncState = .idle
        syncResults.removeAll()
    }

    // MARK: - Trigger API

    public func handleTrigger(_ trigger: ProgressSyncTrigger) {
        guard let adapter = adapter else {
            syncState = .failed(message: "Sync not configured")
            return
        }
        Task { await performSync(for: trigger, adapter: adapter) }
    }

    public func pullRemoteProgress(bookID: String) async -> ReadingProgress? {
        guard let adapter = adapter else { return nil }

        do {
            syncState = .syncing
            let remote = try await adapter.pullProgress(bookID: bookID)
            syncState = .idle
            return remote
        } catch {
            syncState = .failed(message: error.localizedDescription)
            return nil
        }
    }

    // MARK: - Internal

    private func performSync(for trigger: ProgressSyncTrigger, adapter: any ProgressSyncAdapterProtocol) async {
        syncState = .syncing

        do {
            let remoteList = try await adapter.listRemoteProgress()
            lastSyncAt = Date()

            for remote in remoteList {
                // For this baseline, each remote progress item produces a result
                let result = ProgressSyncResult(
                    bookID: remote.bookID,
                    trigger: trigger,
                    resolved: true,
                    conflictPolicy: conflictResolver.policy,
                    remoteProgress: remote,
                    finalProgress: remote
                )
                syncResults.append(result)
            }

            if remoteList.isEmpty {
                syncState = .idle
            } else {
                syncState = .success(result: syncResults.last!)
            }
        } catch {
            syncState = .failed(message: error.localizedDescription)
        }
    }

    // MARK: - Conflict Resolution

    public func resolveConflict(local: ReadingProgress, remote: ReadingProgress) -> ProgressSyncResult {
        // Core bridge: try sync.conflict.resolve first; fall back to local resolver.
        if let coreResult = tryCoreConflictResolve(local: local, remote: remote) {
            syncResults.append(coreResult)
            syncState = coreResult.resolved ? .success(result: coreResult) : .conflict(local: local, remote: remote)
            return coreResult
        }

        let result = conflictResolver.resolve(local: local, remote: remote)
        syncResults.append(result)
        syncState = result.resolved ? .success(result: result) : .conflict(local: local, remote: remote)
        return result
    }

    // MARK: - Core Bridge

    /// Try Core `sync.conflict.resolve`. Returns nil on any failure (caller
    /// falls back to local conflictResolver).
    private func tryCoreConflictResolve(local: ReadingProgress, remote: ReadingProgress) -> ProgressSyncResult? {
        guard let runtime = RustCoreRuntimeHolder.shared.current else {
            return nil
        }
        let params: [String: Any] = [
            "local": Self.progressToDict(local),
            "remote": Self.progressToDict(remote),
        ]
        let requestId = Self.nextRequestId()
        guard let event = try? runtime.request(
            method: "sync.conflict.resolve",
            requestId: requestId,
            params: params,
            timeout: Self.coreTimeout
        ) else {
            return nil
        }
        guard let resolved = event.data?["resolved"] as? [String: Any],
              let finalProgress = Self.dictToProgress(resolved) else {
            return nil
        }
        return ProgressSyncResult(
            bookID: local.bookID,
            trigger: .appLaunch,
            resolved: true,
            conflictPolicy: conflictResolver.policy,
            localProgress: local,
            remoteProgress: remote,
            finalProgress: finalProgress
        )
    }

    private static func progressToDict(_ progress: ReadingProgress) -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        return [
            "bookID": progress.bookID,
            "sourceID": progress.sourceID,
            "bookURL": progress.bookURL,
            "chapterURL": progress.chapterURL,
            "chapterTitle": progress.chapterTitle,
            "progressRatio": progress.progressRatio,
            "updatedAt": formatter.string(from: progress.updatedAt),
        ]
    }

    private static func dictToProgress(_ dict: [String: Any]) -> ReadingProgress? {
        guard let bookID = dict["bookID"] as? String,
              let sourceID = dict["sourceID"] as? String,
              let bookURL = dict["bookURL"] as? String,
              let chapterURL = dict["chapterURL"] as? String,
              let chapterTitle = dict["chapterTitle"] as? String,
              let progressRatio = dict["progressRatio"] as? Double else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        let updatedAt = (dict["updatedAt"] as? String).flatMap { formatter.date(from: $0) } ?? Date()
        return ReadingProgress(
            bookID: bookID,
            sourceID: sourceID,
            bookURL: bookURL,
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            progressRatio: progressRatio,
            updatedAt: updatedAt
        )
    }

    public func reset() {
        syncState = .idle
        syncResults.removeAll()
    }
}
