import Foundation
import ReaderCoreModels
import ReaderAppSupport

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
        let result = conflictResolver.resolve(local: local, remote: remote)
        syncResults.append(result)
        syncState = result.resolved ? .success(result: result) : .conflict(local: local, remote: remote)
        return result
    }

    public func reset() {
        syncState = .idle
        syncResults.removeAll()
    }
}
