import Foundation

public struct WebDAVBackupConfiguration: Codable, Equatable, Sendable {
    public var schedule: BackupSchedule
    public var retentionCount: Int
    public var lastBackupDate: Date?

    public init(
        schedule: BackupSchedule = .weekly,
        retentionCount: Int = 5,
        lastBackupDate: Date? = nil
    ) {
        self.schedule = schedule
        self.retentionCount = max(1, retentionCount)
        self.lastBackupDate = lastBackupDate
    }
}

public protocol WebDAVBackupConfigurationStoring: Sendable {
    func load() throws -> WebDAVBackupConfiguration
    func save(_ configuration: WebDAVBackupConfiguration) throws
}

public final class WebDAVBackupConfigurationStore: WebDAVBackupConfigurationStoring, @unchecked Sendable {
    public static let shared = WebDAVBackupConfigurationStore()

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appendingPathComponent("ReaderApp", isDirectory: true)
        fileURL = directory.appendingPathComponent("webdav_backup_config.json")
        fileManager = .default
        configureCoders()
    }

    public init(storageURL: URL, fileManager: FileManager = .default) {
        self.fileURL = storageURL
        self.fileManager = fileManager
        configureCoders()
    }

    public func load() throws -> WebDAVBackupConfiguration {
        lock.lock()
        defer { lock.unlock() }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return WebDAVBackupConfiguration()
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(WebDAVBackupConfiguration.self, from: data)
    }

    public func save(_ configuration: WebDAVBackupConfiguration) throws {
        lock.lock()
        defer { lock.unlock() }

        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(configuration)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func configureCoders() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
}
