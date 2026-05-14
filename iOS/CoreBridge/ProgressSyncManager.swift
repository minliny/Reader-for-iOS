import Foundation
import ReaderCoreModels
import ReaderAppSupport

// MARK: - Sync Trigger

public enum ProgressSyncTrigger: String, Sendable {
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
    case success
    case failed(message: String)
    case conflict(local: ReadingProgress, remote: ReadingProgress)
}

// MARK: - Sync Manager

@MainActor
public final class ProgressSyncManager: ObservableObject, Sendable {
    public static let shared = ProgressSyncManager()

    @Published public private(set) var syncState: ProgressSyncState = .idle
    @Published public private(set) var lastSyncAt: Date?
    @Published public private(set) var pendingTriggers: Set<ProgressSyncTrigger> = []

    public var isSyncEnabled: Bool {
        // Disabled until WebDAV adapter is configured
        false
    }

    private init() {}

    // MARK: - Trigger API

    public func handleTrigger(_ trigger: ProgressSyncTrigger) {
        pendingTriggers.insert(trigger)

        guard isSyncEnabled else {
            syncState = .failed(message: "Sync not configured — WebDAV adapter pending")
            return
        }

        Task { await performSync(for: trigger) }
    }

    public func pullRemoteProgress(bookID: String) async -> ReadingProgress? {
        guard isSyncEnabled else { return nil }
        syncState = .syncing
        // TODO: call WebDAVAdapter.fetchProgress(bookID:)
        syncState = .failed(message: "WebDAV adapter not yet wired")
        return nil
    }

    private func performSync(for trigger: ProgressSyncTrigger) async {
        syncState = .syncing
        defer {
            pendingTriggers.remove(trigger)
            if pendingTriggers.isEmpty && syncState == .syncing {
                syncState = .idle
            }
        }
        // TODO: invoke WebDAV sync via Core WebDAVAdapter
        lastSyncAt = Date()
        syncState = .failed(message: "WebDAV sync not yet implemented")
    }

    public func reset() {
        syncState = .idle
        pendingTriggers.removeAll()
    }
}
