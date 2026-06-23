import Foundation
import ReaderAppPersistence
import ReaderAppSupport
import ReaderCoreModels

public struct WebDAVBackupRestoreResult: Equatable {
    public var package: ReaderCoreModels.BackupPackage
    public var restoredItemCount: Int
    public var restoredBookSourceCount: Int
    public var restoredReadingProgressCount: Int
    public var restoredReaderSettings: Bool
    public var applied: Bool
    public var cleanRoomMaintained: Bool
    public var externalGPLCodeCopied: Bool

    public init(
        package: ReaderCoreModels.BackupPackage,
        restoredItemCount: Int,
        restoredBookSourceCount: Int = 0,
        restoredReadingProgressCount: Int = 0,
        restoredReaderSettings: Bool = false,
        applied: Bool,
        cleanRoomMaintained: Bool = true,
        externalGPLCodeCopied: Bool = false
    ) {
        self.package = package
        self.restoredItemCount = restoredItemCount
        self.restoredBookSourceCount = restoredBookSourceCount
        self.restoredReadingProgressCount = restoredReadingProgressCount
        self.restoredReaderSettings = restoredReaderSettings
        self.applied = applied
        self.cleanRoomMaintained = cleanRoomMaintained
        self.externalGPLCodeCopied = externalGPLCodeCopied
    }
}

public enum WebDAVBackupRestoreError: Error, Equatable, LocalizedError {
    case invalidArchive
    case externalGPLCodeMarkerPresent

    public var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "Backup archive format is invalid."
        case .externalGPLCodeMarkerPresent:
            return "Backup archive failed clean-room validation."
        }
    }
}

public protocol WebDAVBackupRestoring: Sendable {
    func restoreBackup(data: Data, overridePolicy: ReaderCoreModels.RestorePolicy?) async throws -> WebDAVBackupRestoreResult
}

public final class WebDAVBackupRestorer: WebDAVBackupRestoring, @unchecked Sendable {
    public static let shared = WebDAVBackupRestorer()

    private let bookshelfStore: BookshelfStore
    private let bookSourceStore: BookSourceStore
    private let readerSettingsStore: ReaderSettingsStore
    private let readingProgressStore: ReadingProgressStore

    public init(
        bookshelfStore: BookshelfStore = .shared,
        bookSourceStore: BookSourceStore = .shared,
        readerSettingsStore: ReaderSettingsStore = .shared,
        readingProgressStore: ReadingProgressStore = .shared
    ) {
        self.bookshelfStore = bookshelfStore
        self.bookSourceStore = bookSourceStore
        self.readerSettingsStore = readerSettingsStore
        self.readingProgressStore = readingProgressStore
    }

    public func restoreBackup(
        data: Data,
        overridePolicy: ReaderCoreModels.RestorePolicy? = nil
    ) async throws -> WebDAVBackupRestoreResult {
        let archive: WebDAVBackupArchive
        do {
            archive = try JSONDecoder().decode(WebDAVBackupArchive.self, from: data)
        } catch {
            throw WebDAVBackupRestoreError.invalidArchive
        }

        guard archive.cleanRoomMaintained, !archive.externalGPLCodeCopied else {
            throw WebDAVBackupRestoreError.externalGPLCodeMarkerPresent
        }

        let policy = overridePolicy ?? archive.restorePolicy
        let selectedItems = selectedItems(from: archive.items, policy: policy)
        let selectedProgress = selectedReadingProgress(from: archive.readingProgress, policy: policy)
        let shouldRestoreGlobalState = policy.mode == .full
        let shouldApply = policy.mode != .dryRun

        if shouldApply {
            let restoredItems = try mergedItems(selectedItems, overwriteExisting: policy.overwriteExisting)
            try bookshelfStore.saveItems(restoredItems)
            if shouldRestoreGlobalState {
                let restoredSources = try await mergedBookSources(
                    archive.bookSources,
                    overwriteExisting: policy.overwriteExisting
                )
                try await bookSourceStore.save(restoredSources)
                if let readerSettings = archive.readerSettings {
                    try readerSettingsStore.saveSettings(readerSettings)
                }
            }
            let restoredProgress = try mergedReadingProgress(
                selectedProgress,
                overwriteExisting: policy.overwriteExisting
            )
            try readingProgressStore.saveAllProgress(restoredProgress)
        }

        return WebDAVBackupRestoreResult(
            package: archive.package,
            restoredItemCount: selectedItems.count,
            restoredBookSourceCount: shouldRestoreGlobalState ? archive.bookSources.count : 0,
            restoredReadingProgressCount: selectedProgress.count,
            restoredReaderSettings: shouldRestoreGlobalState && archive.readerSettings != nil,
            applied: shouldApply,
            cleanRoomMaintained: archive.cleanRoomMaintained,
            externalGPLCodeCopied: archive.externalGPLCodeCopied
        )
    }

    private func selectedItems(
        from items: [BookshelfItem],
        policy: ReaderCoreModels.RestorePolicy
    ) -> [BookshelfItem] {
        guard policy.mode == .selective,
              let selectedBookIDs = policy.selectedBookIDs,
              !selectedBookIDs.isEmpty else {
            return items
        }
        let ids = Set(selectedBookIDs)
        return items.filter { ids.contains($0.id) }
    }

    private func selectedReadingProgress(
        from progress: [ReadingProgress],
        policy: ReaderCoreModels.RestorePolicy
    ) -> [ReadingProgress] {
        guard policy.mode == .selective,
              let selectedBookIDs = policy.selectedBookIDs,
              !selectedBookIDs.isEmpty else {
            return progress
        }
        let ids = Set(selectedBookIDs)
        return progress.filter { ids.contains($0.bookID) }
    }

    private func mergedItems(
        _ restoredItems: [BookshelfItem],
        overwriteExisting: Bool
    ) throws -> [BookshelfItem] {
        guard !overwriteExisting else {
            return restoredItems
        }

        var existing = try bookshelfStore.loadItems()
        for item in restoredItems {
            let alreadyExists = existing.contains {
                $0.id == item.id || ($0.bookURL == item.bookURL && $0.sourceID == item.sourceID)
            }
            if !alreadyExists {
                existing.append(item)
            }
        }
        return existing
    }

    private func mergedBookSources(
        _ restoredSources: [ReaderCoreModels.BookSource],
        overwriteExisting: Bool
    ) async throws -> [ReaderCoreModels.BookSource] {
        guard !overwriteExisting else {
            return restoredSources
        }

        var existing = try await bookSourceStore.load()
        for source in restoredSources {
            let alreadyExists = existing.contains {
                $0.id == source.id ||
                    (!$0.bookSourceUrl.isNilOrEmpty && $0.bookSourceUrl == source.bookSourceUrl)
            }
            if !alreadyExists {
                existing.append(source)
            }
        }
        return existing
    }

    private func mergedReadingProgress(
        _ restoredProgress: [ReadingProgress],
        overwriteExisting: Bool
    ) throws -> [String: ReadingProgress] {
        guard !overwriteExisting else {
            return Dictionary(uniqueKeysWithValues: restoredProgress.map { ($0.bookID, $0) })
        }

        var existing = try readingProgressStore.loadAllProgress()
        for progress in restoredProgress where existing[progress.bookID] == nil {
            existing[progress.bookID] = progress
        }
        return existing
    }
}

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}
