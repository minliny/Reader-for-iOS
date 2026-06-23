import Foundation
import CryptoKit
import ReaderAppSupport
import ReaderAppPersistence
import ReaderCoreModels

public struct WebDAVBackupArchive: Codable, Equatable {
    public var schemaVersion: Int
    public var package: ReaderCoreModels.BackupPackage
    public var items: [BookshelfItem]
    public var bookSources: [ReaderCoreModels.BookSource]
    public var readerSettings: ReaderDisplaySettings?
    public var readingProgress: [ReadingProgress]
    public var restorePolicy: ReaderCoreModels.RestorePolicy
    public var cleanRoomMaintained: Bool
    public var externalGPLCodeCopied: Bool

    public init(
        schemaVersion: Int = 2,
        package: ReaderCoreModels.BackupPackage,
        items: [BookshelfItem],
        bookSources: [ReaderCoreModels.BookSource] = [],
        readerSettings: ReaderDisplaySettings? = nil,
        readingProgress: [ReadingProgress] = [],
        restorePolicy: ReaderCoreModels.RestorePolicy = ReaderCoreModels.RestorePolicy(mode: .full),
        cleanRoomMaintained: Bool = true,
        externalGPLCodeCopied: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.package = package
        self.items = items
        self.bookSources = bookSources
        self.readerSettings = readerSettings
        self.readingProgress = readingProgress
        self.restorePolicy = restorePolicy
        self.cleanRoomMaintained = cleanRoomMaintained
        self.externalGPLCodeCopied = externalGPLCodeCopied
    }
}

public struct WebDAVBackupExportResult: Equatable, Sendable {
    public var fileURL: URL
    public var package: ReaderCoreModels.BackupPackage
    public var itemCount: Int
    public var bookSourceCount: Int
    public var readingProgressCount: Int
    public var includesReaderSettings: Bool
    public var cleanRoomMaintained: Bool
    public var externalGPLCodeCopied: Bool

    public init(
        fileURL: URL,
        package: ReaderCoreModels.BackupPackage,
        itemCount: Int,
        bookSourceCount: Int = 0,
        readingProgressCount: Int = 0,
        includesReaderSettings: Bool = false,
        cleanRoomMaintained: Bool = true,
        externalGPLCodeCopied: Bool = false
    ) {
        self.fileURL = fileURL
        self.package = package
        self.itemCount = itemCount
        self.bookSourceCount = bookSourceCount
        self.readingProgressCount = readingProgressCount
        self.includesReaderSettings = includesReaderSettings
        self.cleanRoomMaintained = cleanRoomMaintained
        self.externalGPLCodeCopied = externalGPLCodeCopied
    }
}

public protocol WebDAVBackupExporting: Sendable {
    func exportBackup() async throws -> WebDAVBackupExportResult
}

public final class WebDAVBackupExporter: WebDAVBackupExporting, @unchecked Sendable {
    public static let shared = WebDAVBackupExporter()

    private let bookshelfStore: BookshelfStore
    private let bookSourceStore: BookSourceStore
    private let readerSettingsStore: ReaderSettingsStore
    private let readingProgressStore: ReadingProgressStore
    private let fileManager: FileManager
    private let exportDirectory: URL?
    private let now: @Sendable () -> Date
    private let backupIDProvider: @Sendable () -> String

    public init(
        bookshelfStore: BookshelfStore = .shared,
        bookSourceStore: BookSourceStore = .shared,
        readerSettingsStore: ReaderSettingsStore = .shared,
        readingProgressStore: ReadingProgressStore = .shared,
        fileManager: FileManager = .default,
        exportDirectory: URL? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        backupIDProvider: @escaping @Sendable () -> String = { "backup-\(UUID().uuidString)" }
    ) {
        self.bookshelfStore = bookshelfStore
        self.bookSourceStore = bookSourceStore
        self.readerSettingsStore = readerSettingsStore
        self.readingProgressStore = readingProgressStore
        self.fileManager = fileManager
        self.exportDirectory = exportDirectory
        self.now = now
        self.backupIDProvider = backupIDProvider
    }

    public func exportBackup() async throws -> WebDAVBackupExportResult {
        let items = try bookshelfStore.loadItems()
        let bookSources = try await bookSourceStore.load()
        let readerSettings = try readerSettingsStore.loadSettings()
        let readingProgress = try readingProgressStore.loadAllProgress()
            .values
            .sorted { lhs, rhs in
                if lhs.bookID != rhs.bookID { return lhs.bookID < rhs.bookID }
                return lhs.updatedAt < rhs.updatedAt
            }
        let createdAt = now()
        let backupID = backupIDProvider()
        let payloads: [(relativePath: String, data: Data)] = [
            ("bookshelf.json", try encodedPayload(items)),
            ("book_sources.json", try encodedPayload(bookSources)),
            ("reader_settings.json", try encodedPayload(readerSettings)),
            ("reading_progress.json", try encodedPayload(readingProgress))
        ]
        let entries = payloads.map { payload in
            ReaderCoreModels.BackupManifest.Entry(
                relativePath: payload.relativePath,
                sha256: "sha256:\(sha256Hex(payload.data))",
                sizeBytes: Int64(payload.data.count),
                modifiedAt: createdAt
            )
        }
        let totalBytes = payloads.reduce(Int64(0)) { partial, payload in
            partial + Int64(payload.data.count)
        }
        let manifest = ReaderCoreModels.BackupManifest(
            backupID: backupID,
            createdAt: createdAt,
            entries: entries,
            totalBytes: totalBytes,
            bookCount: items.count
        )
        let package = ReaderCoreModels.BackupPackage(
            manifest: manifest,
            format: .directory,
            checksum: nil
        )
        let archive = WebDAVBackupArchive(
            package: package,
            items: items,
            bookSources: bookSources,
            readerSettings: readerSettings,
            readingProgress: readingProgress
        )
        let data = try archiveEncoder.encode(archive)

        let exportDir = (exportDirectory ?? fileManager.temporaryDirectory)
            .appendingPathComponent("reader_backup", isDirectory: true)
        try fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "reader_backup_\(formatter.string(from: createdAt)).readerbackup.json"
        let fileURL = exportDir.appendingPathComponent(filename)

        try data.write(to: fileURL)
        return WebDAVBackupExportResult(
            fileURL: fileURL,
            package: package,
            itemCount: items.count,
            bookSourceCount: bookSources.count,
            readingProgressCount: readingProgress.count,
            includesReaderSettings: true
        )
    }

    private var archiveEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private func encodedPayload<T: Encodable>(_ payload: T) throws -> Data {
        try archiveEncoder.encode(payload)
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
