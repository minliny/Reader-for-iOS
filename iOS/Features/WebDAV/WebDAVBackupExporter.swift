import Foundation
import ReaderAppSupport
import ReaderAppPersistence

public struct BackupManifest: Codable {
    public var exportedAt: Date
    public var bookshelfCount: Int
    public var items: [BookshelfItem]
}

public final class WebDAVBackupExporter: Sendable {
    public static let shared = WebDAVBackupExporter()

    private let bookshelfStore: BookshelfStore
    private let fileManager: FileManager

    public init(
        bookshelfStore: BookshelfStore = .shared,
        fileManager: FileManager = .default
    ) {
        self.bookshelfStore = bookshelfStore
        self.fileManager = fileManager
    }

    public func exportBackup() throws -> URL {
        let items = try bookshelfStore.loadItems()

        let manifest = BackupManifest(
            exportedAt: Date(),
            bookshelfCount: items.count,
            items: items
        )

        let data = try JSONEncoder().encode(manifest)

        let exportDir = fileManager.temporaryDirectory
            .appendingPathComponent("reader_backup", isDirectory: true)
        try fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "reader_backup_\(formatter.string(from: Date())).json"
        let fileURL = exportDir.appendingPathComponent(filename)

        try data.write(to: fileURL)
        return fileURL
    }
}
