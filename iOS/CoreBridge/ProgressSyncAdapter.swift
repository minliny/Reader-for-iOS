import Foundation
import ReaderAppSupport

// MARK: - Adapter Protocol

public protocol ProgressSyncAdapterProtocol: Sendable {
    func pushProgress(_ progress: ReadingProgress) async throws
    func pullProgress(bookID: String) async throws -> ReadingProgress?
    func listRemoteProgress() async throws -> [ReadingProgress]
}

// MARK: - Conflict Policy

public enum ProgressSyncConflictPolicy: String, Sendable, CaseIterable {
    case localWins
    case remoteWins
    case newestTimestampWins
    case manualRequired
}

// MARK: - Sync Result

public struct ProgressSyncResult: Equatable, Sendable {
    public let bookID: String
    public let trigger: ProgressSyncTrigger
    public let resolved: Bool
    public let conflictPolicy: ProgressSyncConflictPolicy
    public let localProgress: ReadingProgress?
    public let remoteProgress: ReadingProgress?
    public let finalProgress: ReadingProgress?
    public let error: String?

    public init(
        bookID: String,
        trigger: ProgressSyncTrigger,
        resolved: Bool,
        conflictPolicy: ProgressSyncConflictPolicy = .localWins,
        localProgress: ReadingProgress? = nil,
        remoteProgress: ReadingProgress? = nil,
        finalProgress: ReadingProgress? = nil,
        error: String? = nil
    ) {
        self.bookID = bookID
        self.trigger = trigger
        self.resolved = resolved
        self.conflictPolicy = conflictPolicy
        self.localProgress = localProgress
        self.remoteProgress = remoteProgress
        self.finalProgress = finalProgress
        self.error = error
    }
}

// MARK: - Conflict Resolver

public struct ProgressSyncConflictResolver: Sendable {
    public let policy: ProgressSyncConflictPolicy

    public init(policy: ProgressSyncConflictPolicy = .manualRequired) {
        self.policy = policy
    }

    public func resolve(local: ReadingProgress, remote: ReadingProgress) -> ProgressSyncResult {
        let winner: ReadingProgress

        switch policy {
        case .localWins:
            winner = local
        case .remoteWins:
            winner = remote
        case .newestTimestampWins:
            winner = local.updatedAt >= remote.updatedAt ? local : remote
        case .manualRequired:
            return ProgressSyncResult(
                bookID: local.bookID,
                trigger: .appLaunch,
                resolved: false,
                conflictPolicy: .manualRequired,
                localProgress: local,
                remoteProgress: remote,
                finalProgress: nil,
                error: "Manual resolution required"
            )
        }

        return ProgressSyncResult(
            bookID: local.bookID,
            trigger: .appLaunch,
            resolved: true,
            conflictPolicy: policy,
            localProgress: local,
            remoteProgress: remote,
            finalProgress: winner
        )
    }
}

// MARK: - Fake Adapter

public actor FakeProgressSyncAdapter: ProgressSyncAdapterProtocol {
    private var remoteStore: [String: ReadingProgress] = [:]

    public init() {}

    public func pushProgress(_ progress: ReadingProgress) async throws {
        remoteStore[progress.bookID] = progress
    }

    public func pullProgress(bookID: String) async throws -> ReadingProgress? {
        remoteStore[bookID]
    }

    public func listRemoteProgress() async throws -> [ReadingProgress] {
        Array(remoteStore.values)
    }

    public func seed(progress: ReadingProgress) {
        remoteStore[progress.bookID] = progress
    }

    public func clear() {
        remoteStore.removeAll()
    }
}

// MARK: - Sync Error

public enum ProgressSyncError: Error, LocalizedError {
    case adapterNotConfigured
    case adapterFailure(reason: String)
    case conflictRequiresManualResolution

    public var errorDescription: String? {
        switch self {
        case .adapterNotConfigured:
            return "Sync adapter not configured"
        case .adapterFailure(let reason):
            return "Sync adapter failed: \(reason)"
        case .conflictRequiresManualResolution:
            return "Conflict requires manual resolution"
        }
    }
}
