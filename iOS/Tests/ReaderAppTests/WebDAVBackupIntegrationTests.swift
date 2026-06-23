import Foundation
import XCTest
@testable import ReaderApp
import ReaderAppPersistence
import ReaderAppSupport
import ReaderCoreModels

@MainActor
final class WebDAVBackupIntegrationTests: XCTestCase {
    func testExporterWritesCoreBackupPackageArchive() async throws {
        let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)
        let root = temporaryDirectoryURL(name: "webdav-exporter")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let store = BookshelfStore(storageURL: root.appendingPathComponent("bookshelf.json"))
        let bookSourceStore = BookSourceStore(storageURL: root.appendingPathComponent("book_sources.json"))
        let settingsStore = ReaderSettingsStore(storageURL: root.appendingPathComponent("reader_settings.json"))
        let progressStore = ReadingProgressStore(storageURL: root.appendingPathComponent("reading_progress.json"))
        try store.saveItems([
            BookshelfItem(
                id: "book-1",
                sourceID: "source-1",
                sourceName: "Example Source",
                bookURL: "https://example.com/book/1",
                title: "Example Book",
                author: "Author",
                updatedAt: fixedDate,
                lastReadChapterTitle: "Chapter 3",
                lastReadChapterURL: "https://example.com/chapter/3",
                readingProgress: 0.42
            )
        ])
        try await bookSourceStore.save([
            BookSource(
                id: "source-1",
                bookSourceName: "Example Source",
                bookSourceUrl: "https://source.example",
                enabled: true
            )
        ])
        var settings = ReaderDisplaySettings.default
        settings.fontSize = 21
        try settingsStore.saveSettings(settings)
        let progress = ReadingProgress(
            bookID: "book-1",
            sourceID: "source-1",
            bookURL: "https://example.com/book/1",
            chapterURL: "https://example.com/chapter/3",
            chapterTitle: "Chapter 3",
            progressRatio: 0.42,
            updatedAt: fixedDate
        )
        try progressStore.saveProgress(progress)

        let exporter = WebDAVBackupExporter(
            bookshelfStore: store,
            bookSourceStore: bookSourceStore,
            readerSettingsStore: settingsStore,
            readingProgressStore: progressStore,
            exportDirectory: root,
            now: { fixedDate },
            backupIDProvider: { "backup-fixed" }
        )

        let result = try await exporter.exportBackup()

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
        XCTAssertEqual(result.itemCount, 1)
        XCTAssertEqual(result.bookSourceCount, 1)
        XCTAssertEqual(result.readingProgressCount, 1)
        XCTAssertTrue(result.includesReaderSettings)
        XCTAssertEqual(result.package.manifest.backupID, "backup-fixed")
        XCTAssertEqual(result.package.manifest.bookCount, 1)
        XCTAssertEqual(result.package.manifest.entries.map(\.relativePath), [
            "bookshelf.json",
            "book_sources.json",
            "reader_settings.json",
            "reading_progress.json"
        ])
        XCTAssertEqual(result.package.format, .directory)
        XCTAssertTrue(result.package.manifest.entries.allSatisfy { $0.sha256?.hasPrefix("sha256:") == true })
        XCTAssertTrue(result.cleanRoomMaintained)
        XCTAssertFalse(result.externalGPLCodeCopied)

        let data = try Data(contentsOf: result.fileURL)
        let archive = try JSONDecoder().decode(WebDAVBackupArchive.self, from: data)
        XCTAssertEqual(archive.package, result.package)
        XCTAssertEqual(archive.items.map(\.title), ["Example Book"])
        XCTAssertEqual(archive.bookSources.map(\.bookSourceName), ["Example Source"])
        XCTAssertEqual(archive.readerSettings?.fontSize, 21)
        XCTAssertEqual(archive.readingProgress, [progress])
        XCTAssertEqual(archive.restorePolicy.mode, .full)
        XCTAssertTrue(archive.cleanRoomMaintained)
        XCTAssertFalse(archive.externalGPLCodeCopied)
    }

    func testExporterWritesEmptyCoreBackupPackageWhenBookshelfIsEmpty() async throws {
        let fixedDate = Date(timeIntervalSince1970: 1_800_000_100)
        let root = temporaryDirectoryURL(name: "webdav-empty-exporter")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let store = BookshelfStore(storageURL: root.appendingPathComponent("bookshelf.json"))
        let exporter = WebDAVBackupExporter(
            bookshelfStore: store,
            bookSourceStore: BookSourceStore(storageURL: root.appendingPathComponent("book_sources.json")),
            readerSettingsStore: ReaderSettingsStore(storageURL: root.appendingPathComponent("reader_settings.json")),
            readingProgressStore: ReadingProgressStore(storageURL: root.appendingPathComponent("reading_progress.json")),
            exportDirectory: root,
            now: { fixedDate },
            backupIDProvider: { "backup-empty" }
        )

        let result = try await exporter.exportBackup()

        XCTAssertEqual(result.itemCount, 0)
        XCTAssertEqual(result.bookSourceCount, 0)
        XCTAssertEqual(result.readingProgressCount, 0)
        XCTAssertTrue(result.includesReaderSettings)
        XCTAssertEqual(result.package.manifest.bookCount, 0)
        XCTAssertGreaterThan(result.package.manifest.totalBytes, 0)

        let archive = try JSONDecoder().decode(
            WebDAVBackupArchive.self,
            from: try Data(contentsOf: result.fileURL)
        )
        XCTAssertTrue(archive.items.isEmpty)
        XCTAssertTrue(archive.bookSources.isEmpty)
        XCTAssertEqual(archive.readerSettings, .default)
        XCTAssertTrue(archive.readingProgress.isEmpty)
    }

    func testViewModelUsesInjectedWebDAVClientForConnectionAndUpload() async throws {
        let root = temporaryDirectoryURL(name: "webdav-view-model")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let backupURL = root.appendingPathComponent("reader_backup.readerbackup.json")
        try Data("{\"ok\":true}".utf8).write(to: backupURL)

        let package = ReaderCoreModels.BackupPackage(
            manifest: ReaderCoreModels.BackupManifest(
                backupID: "backup-view-model",
                createdAt: Date(timeIntervalSince1970: 1_800_000_200),
                entries: [],
                totalBytes: 0,
                bookCount: 2
            ),
            format: .directory
        )
        let exporter = FakeWebDAVBackupExporter(
            result: WebDAVBackupExportResult(
                fileURL: backupURL,
                package: package,
                itemCount: 2
            )
        )
        let client = FakeWebDAVClient()
        let viewModel = WebDAVSettingsViewModel(
            keychain: InMemoryWebDAVCredentialStore(),
            configurationStore: InMemoryWebDAVBackupConfigurationStore(),
            exporter: exporter,
            webDAVClient: client
        )
        viewModel.serverURL = " https://dav.example.com/backups "
        viewModel.username = " user "
        viewModel.password = "secret"

        await viewModel.testConnection()
        guard case .success(let connectionMessage) = viewModel.connectionTestResult else {
            XCTFail("Expected WebDAV connection success, got \(viewModel.connectionTestResult)")
            return
        }
        XCTAssertEqual(connectionMessage, "Connection OK (207)")
        let testedCredentials = await client.testedCredentials
        XCTAssertEqual(testedCredentials?.serverURL, "https://dav.example.com/backups")
        XCTAssertEqual(testedCredentials?.username, "user")

        await viewModel.exportBackup()
        guard case .success(let exportMessage) = viewModel.exportResult else {
            XCTFail("Expected WebDAV upload success, got \(viewModel.exportResult)")
            return
        }
        XCTAssertEqual(exportMessage, "Uploaded 2 items to reader_backup.readerbackup.json")
        XCTAssertNotNil(viewModel.lastBackupDate)
        let uploaded = await client.uploadedBackups
        XCTAssertEqual(uploaded.map(\.fileURL), [backupURL])
        XCTAssertEqual(uploaded.first?.credentials.password, "secret")
    }

    func testViewModelUploadPrunesRemoteBackupsBeyondRetentionCount() async throws {
        let root = temporaryDirectoryURL(name: "webdav-view-model-retention")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let backupURL = root.appendingPathComponent("reader_backup_current.readerbackup.json")
        try Data("{\"ok\":true}".utf8).write(to: backupURL)

        let package = ReaderCoreModels.BackupPackage(
            manifest: ReaderCoreModels.BackupManifest(
                backupID: "backup-current",
                createdAt: Date(timeIntervalSince1970: 1_800_000_700),
                entries: [],
                totalBytes: 0,
                bookCount: 2
            ),
            format: .directory
        )
        let keepURL = URL(string: "https://dav.example.com/backups/reader_backup_keep.readerbackup.json")!
        let deleteURL = URL(string: "https://dav.example.com/backups/reader_backup_delete.readerbackup.json")!
        let client = FakeWebDAVClient(
            remoteBackups: [
                WebDAVRemoteBackup(
                    remoteURL: keepURL,
                    filename: keepURL.lastPathComponent,
                    modifiedAt: Date(timeIntervalSince1970: 1_800_000_600)
                ),
                WebDAVRemoteBackup(
                    remoteURL: deleteURL,
                    filename: deleteURL.lastPathComponent,
                    modifiedAt: Date(timeIntervalSince1970: 1_800_000_500)
                )
            ]
        )
        let viewModel = WebDAVSettingsViewModel(
            keychain: InMemoryWebDAVCredentialStore(),
            configurationStore: InMemoryWebDAVBackupConfigurationStore(),
            exporter: FakeWebDAVBackupExporter(
                result: WebDAVBackupExportResult(
                    fileURL: backupURL,
                    package: package,
                    itemCount: 2
                )
            ),
            webDAVClient: client
        )
        viewModel.serverURL = "https://dav.example.com/backups"
        viewModel.username = "reader"
        viewModel.password = "secret"
        viewModel.retentionCount = 2

        await viewModel.exportBackup()

        guard case .success(let exportMessage) = viewModel.exportResult else {
            XCTFail("Expected WebDAV upload success, got \(viewModel.exportResult)")
            return
        }
        XCTAssertEqual(exportMessage, "Uploaded 2 items to reader_backup_current.readerbackup.json; pruned 1 old backups")
        let deleted = await client.deletedBackups
        XCTAssertEqual(deleted.map(\.remoteURL), [deleteURL])
        XCTAssertEqual(viewModel.remoteBackups.map(\.remoteURL.absoluteString), [
            "https://dav.example.com/backups/reader_backup_current.readerbackup.json",
            keepURL.absoluteString
        ])
    }

    func testConfigurationStorePersistsScheduleRetentionAndLastBackupDate() throws {
        let root = temporaryDirectoryURL(name: "webdav-config-store")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = WebDAVBackupConfigurationStore(
            storageURL: root.appendingPathComponent("webdav_backup_config.json")
        )
        let configuration = WebDAVBackupConfiguration(
            schedule: .daily,
            retentionCount: 3,
            lastBackupDate: Date(timeIntervalSince1970: 1_800_001_000)
        )

        try store.save(configuration)

        XCTAssertEqual(try store.load(), configuration)
    }

    func testViewModelPersistsBackupConfigurationAndEvaluatesScheduleDue() async throws {
        let configStore = InMemoryWebDAVBackupConfigurationStore(
            configuration: WebDAVBackupConfiguration(
                schedule: .daily,
                retentionCount: 4,
                lastBackupDate: Date(timeIntervalSince1970: 1_800_000_000)
            )
        )
        let viewModel = WebDAVSettingsViewModel(
            keychain: InMemoryWebDAVCredentialStore(),
            configurationStore: configStore,
            exporter: FakeWebDAVBackupExporter(result: emptyExportResult(root: temporaryDirectoryURL(name: "unused-config-export"))),
            webDAVClient: FakeWebDAVClient(),
            now: { Date(timeIntervalSince1970: 1_800_086_401) }
        )

        XCTAssertEqual(viewModel.backupSchedule, .daily)
        XCTAssertEqual(viewModel.retentionCount, 4)
        XCTAssertTrue(viewModel.isScheduledBackupDue())
        viewModel.backupSchedule = .weekly
        XCTAssertFalse(viewModel.isScheduledBackupDue())
        viewModel.backupSchedule = .manual
        XCTAssertFalse(viewModel.isScheduledBackupDue())
        viewModel.retentionCount = 2

        await viewModel.saveCredentials()

        XCTAssertEqual(
            configStore.savedConfigurations.last,
            WebDAVBackupConfiguration(
                schedule: .manual,
                retentionCount: 2,
                lastBackupDate: Date(timeIntervalSince1970: 1_800_000_000)
            )
        )
    }

    func testScheduledBackupRunsWhenDueAndPersistsLastBackupDate() async throws {
        let root = temporaryDirectoryURL(name: "webdav-scheduled-backup")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let backupURL = root.appendingPathComponent("reader_backup_scheduled.readerbackup.json")
        try Data("{\"ok\":true}".utf8).write(to: backupURL)
        let now = Date(timeIntervalSince1970: 1_800_100_000)
        let configStore = InMemoryWebDAVBackupConfigurationStore(
            configuration: WebDAVBackupConfiguration(
                schedule: .daily,
                retentionCount: 5,
                lastBackupDate: now.addingTimeInterval(-25 * 60 * 60)
            )
        )
        let client = FakeWebDAVClient()
        let viewModel = WebDAVSettingsViewModel(
            keychain: InMemoryWebDAVCredentialStore(),
            configurationStore: configStore,
            exporter: FakeWebDAVBackupExporter(
                result: WebDAVBackupExportResult(
                    fileURL: backupURL,
                    package: ReaderCoreModels.BackupPackage(
                        manifest: ReaderCoreModels.BackupManifest(
                            backupID: "scheduled",
                            createdAt: now,
                            entries: [],
                            totalBytes: 0,
                            bookCount: 1
                        ),
                        format: .directory
                    ),
                    itemCount: 1
                )
            ),
            webDAVClient: client,
            now: { now }
        )
        viewModel.serverURL = "https://dav.example.com/backups"
        viewModel.username = "reader"
        viewModel.password = "secret"

        let didRun = await viewModel.runScheduledBackupIfNeeded()

        XCTAssertTrue(didRun)
        let uploaded = await client.uploadedBackups
        XCTAssertEqual(uploaded.map(\.fileURL), [backupURL])
        XCTAssertEqual(
            configStore.savedConfigurations.last,
            WebDAVBackupConfiguration(schedule: .daily, retentionCount: 5, lastBackupDate: now)
        )
    }

    func testProgressSyncPayloadCarriesCoreProgressRecords() {
        let updatedAt = Date(timeIntervalSince1970: 1_800_200_000)
        let progress = ReadingProgress(
            bookID: "book-core",
            sourceID: "source-core",
            bookURL: "https://example.com/book",
            chapterURL: "https://example.com/chapter/7",
            chapterTitle: "Chapter 7",
            progressRatio: 0.77,
            updatedAt: updatedAt
        )

        let payload = WebDAVProgressSyncPayload(records: [progress], deviceID: "ios-unit")

        XCTAssertEqual(payload.records, [progress])
        XCTAssertEqual(payload.coreRecords, [
            ProgressCloudSyncRecord(
                bookId: "book-core",
                chapterIndex: 0,
                chapterTitle: "Chapter 7",
                progressFraction: 0.77,
                updatedAt: updatedAt,
                deviceId: "ios-unit"
            )
        ])
        XCTAssertTrue(payload.cleanRoomMaintained)
        XCTAssertFalse(payload.externalGPLCodeCopied)
    }

    func testProgressSyncServiceMergesRemoteAndLocalByNewestTimestamp() async throws {
        let root = temporaryDirectoryURL(name: "webdav-progress-sync-service")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let progressStore = ReadingProgressStore(storageURL: root.appendingPathComponent("reading_progress.json"))
        let localOlder = ReadingProgress(
            bookID: "book-a",
            sourceID: "source-local",
            bookURL: "https://example.com/a",
            chapterURL: "local-a",
            chapterTitle: "Local A",
            progressRatio: 0.1,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let localOnly = ReadingProgress(
            bookID: "book-c",
            sourceID: "source-local",
            bookURL: "https://example.com/c",
            chapterURL: "local-c",
            chapterTitle: "Local C",
            progressRatio: 0.3,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_300)
        )
        let localNewer = ReadingProgress(
            bookID: "book-d",
            sourceID: "source-local",
            bookURL: "https://example.com/d",
            chapterURL: "local-d",
            chapterTitle: "Local D",
            progressRatio: 0.8,
            updatedAt: Date(timeIntervalSince1970: 1_800_001_000)
        )
        let remoteNewer = ReadingProgress(
            bookID: "book-a",
            sourceID: "source-remote",
            bookURL: "https://example.com/a",
            chapterURL: "remote-a",
            chapterTitle: "Remote A",
            progressRatio: 0.9,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_900)
        )
        let remoteOnly = ReadingProgress(
            bookID: "book-b",
            sourceID: "source-remote",
            bookURL: "https://example.com/b",
            chapterURL: "remote-b",
            chapterTitle: "Remote B",
            progressRatio: 0.2,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_200)
        )
        let remoteOlder = ReadingProgress(
            bookID: "book-d",
            sourceID: "source-remote",
            bookURL: "https://example.com/d",
            chapterURL: "remote-d",
            chapterTitle: "Remote D",
            progressRatio: 0.4,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_400)
        )
        try progressStore.saveProgress(localOlder)
        try progressStore.saveProgress(localOnly)
        try progressStore.saveProgress(localNewer)
        let remote = FakeWebDAVProgressRemote(records: [remoteNewer, remoteOnly, remoteOlder])
        let service = WebDAVProgressSyncService(progressStore: progressStore, remote: remote)

        let summary = try await service.syncAll(
            credentials: WebDAVCredentials(
                serverURL: "https://dav.example.com/backups",
                username: "reader",
                password: "secret"
            )
        )

        XCTAssertEqual(summary.localRecordCount, 3)
        XCTAssertEqual(summary.remoteRecordCount, 3)
        XCTAssertEqual(summary.uploadedRecordCount, 4)
        XCTAssertEqual(summary.downloadedRecordCount, 2)
        XCTAssertEqual(summary.conflictCount, 2)
        XCTAssertEqual(summary.conflicts.map(\.bookID), ["book-a", "book-d"])
        XCTAssertEqual(summary.conflicts.map(\.resolution), [.remoteApplied, .localKept])
        XCTAssertEqual(summary.conflicts.first?.resolved, remoteNewer)
        XCTAssertEqual(summary.conflicts.last?.resolved, localNewer)
        XCTAssertEqual(try progressStore.loadProgress(bookID: "book-a"), remoteNewer)
        XCTAssertEqual(try progressStore.loadProgress(bookID: "book-b"), remoteOnly)
        XCTAssertEqual(try progressStore.loadProgress(bookID: "book-c"), localOnly)
        XCTAssertEqual(try progressStore.loadProgress(bookID: "book-d"), localNewer)
        let saved = await remote.savedRecordBatches.last
        XCTAssertEqual(saved?.map(\.bookID), ["book-a", "book-b", "book-c", "book-d"])
    }

    func testProgressSyncAdapterPushPullAndListRemoteProgress() async throws {
        let remote = FakeWebDAVProgressRemote()
        let adapter = WebDAVProgressSyncAdapter(
            credentials: WebDAVCredentials(
                serverURL: "https://dav.example.com/backups",
                username: "reader",
                password: "secret"
            ),
            remote: remote
        )
        let progress = ReadingProgress(
            bookID: "book-adapter",
            sourceID: "source-adapter",
            bookURL: "https://example.com/adapter",
            chapterURL: "chapter-adapter",
            chapterTitle: "Adapter Chapter",
            progressRatio: 0.6,
            updatedAt: Date(timeIntervalSince1970: 1_800_300_000)
        )

        try await adapter.pushProgress(progress)

        let pulled = try await adapter.pullProgress(bookID: "book-adapter")
        let listed = try await adapter.listRemoteProgress()
        XCTAssertEqual(pulled, progress)
        XCTAssertEqual(listed, [progress])
    }

    func testViewModelSyncReadingProgressUsesWebDAVCredentials() async throws {
        let root = temporaryDirectoryURL(name: "webdav-view-model-progress-sync")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let syncer = FakeWebDAVProgressSyncer(
            summary: WebDAVProgressSyncSummary(
                localRecordCount: 1,
                remoteRecordCount: 1,
                uploadedRecordCount: 2,
                downloadedRecordCount: 1,
                conflictCount: 0
            )
        )
        let viewModel = WebDAVSettingsViewModel(
            keychain: InMemoryWebDAVCredentialStore(),
            configurationStore: InMemoryWebDAVBackupConfigurationStore(),
            exporter: FakeWebDAVBackupExporter(result: emptyExportResult(root: root)),
            webDAVClient: FakeWebDAVClient(),
            progressSyncer: syncer
        )
        viewModel.serverURL = " https://dav.example.com/backups "
        viewModel.username = " reader "
        viewModel.password = "secret"

        await viewModel.syncReadingProgress()

        guard case .success(let message) = viewModel.progressSyncResult else {
            XCTFail("Expected progress sync success, got \(viewModel.progressSyncResult)")
            return
        }
        XCTAssertEqual(message, "Synced 2 progress records")
        let credentials = await syncer.lastCredentials
        XCTAssertEqual(credentials?.serverURL, "https://dav.example.com/backups")
        XCTAssertEqual(credentials?.username, "reader")
        XCTAssertEqual(credentials?.password, "secret")
    }

    func testRestorerAppliesCoreBackupArchiveToBookshelfStore() async throws {
        let root = temporaryDirectoryURL(name: "webdav-restorer")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let store = BookshelfStore(storageURL: root.appendingPathComponent("bookshelf.json"))
        let bookSourceStore = BookSourceStore(storageURL: root.appendingPathComponent("book_sources.json"))
        let settingsStore = ReaderSettingsStore(storageURL: root.appendingPathComponent("reader_settings.json"))
        let progressStore = ReadingProgressStore(storageURL: root.appendingPathComponent("reading_progress.json"))
        let restored = BookshelfItem(
            id: "restored-book",
            sourceID: "source-restore",
            bookURL: "https://example.com/restored",
            title: "Restored Book",
            readingProgress: 0.7
        )
        let restoredSource = BookSource(
            id: "source-restore",
            bookSourceName: "Restored Source",
            bookSourceUrl: "https://source.example",
            enabled: true
        )
        var restoredSettings = ReaderDisplaySettings.default
        restoredSettings.backgroundMode = .sepia
        let restoredProgress = ReadingProgress(
            bookID: "restored-book",
            sourceID: "source-restore",
            bookURL: "https://example.com/restored",
            chapterURL: "https://example.com/chapter/1",
            chapterTitle: "Chapter 1",
            progressRatio: 0.7,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_320)
        )
        let data = try makeArchiveData(
            items: [restored],
            bookSources: [restoredSource],
            readerSettings: restoredSettings,
            readingProgress: [restoredProgress]
        )
        let restorer = WebDAVBackupRestorer(
            bookshelfStore: store,
            bookSourceStore: bookSourceStore,
            readerSettingsStore: settingsStore,
            readingProgressStore: progressStore
        )

        let result = try await restorer.restoreBackup(data: data, overridePolicy: nil)

        XCTAssertTrue(result.applied)
        XCTAssertEqual(result.restoredItemCount, 1)
        XCTAssertEqual(result.restoredBookSourceCount, 1)
        XCTAssertEqual(result.restoredReadingProgressCount, 1)
        XCTAssertTrue(result.restoredReaderSettings)
        XCTAssertEqual(try store.loadItems(), [restored])
        let loadedSources = try await bookSourceStore.load()
        XCTAssertEqual(loadedSources, [restoredSource])
        XCTAssertEqual(try settingsStore.loadSettings(), restoredSettings)
        XCTAssertEqual(try progressStore.loadProgress(bookID: "restored-book"), restoredProgress)
        XCTAssertTrue(result.cleanRoomMaintained)
        XCTAssertFalse(result.externalGPLCodeCopied)
    }

    func testRestorerDryRunDoesNotWriteBookshelfStore() async throws {
        let root = temporaryDirectoryURL(name: "webdav-restorer-dry-run")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let store = BookshelfStore(storageURL: root.appendingPathComponent("bookshelf.json"))
        let progressStore = ReadingProgressStore(storageURL: root.appendingPathComponent("reading_progress.json"))
        let existing = BookshelfItem(
            id: "existing-book",
            sourceID: "source-existing",
            bookURL: "https://example.com/existing",
            title: "Existing Book"
        )
        try store.saveItems([existing])
        let incoming = BookshelfItem(
            id: "incoming-book",
            sourceID: "source-incoming",
            bookURL: "https://example.com/incoming",
            title: "Incoming Book"
        )
        let data = try makeArchiveData(
            items: [incoming],
            restorePolicy: RestorePolicy(mode: .dryRun)
        )
        let restorer = WebDAVBackupRestorer(
            bookshelfStore: store,
            bookSourceStore: BookSourceStore(storageURL: root.appendingPathComponent("book_sources.json")),
            readerSettingsStore: ReaderSettingsStore(storageURL: root.appendingPathComponent("reader_settings.json")),
            readingProgressStore: progressStore
        )

        let result = try await restorer.restoreBackup(data: data, overridePolicy: nil)

        XCTAssertFalse(result.applied)
        XCTAssertEqual(result.restoredItemCount, 1)
        XCTAssertEqual(try store.loadItems(), [existing])
        XCTAssertTrue(try progressStore.loadAllProgress().isEmpty)
    }

    func testViewModelDownloadsAndRestoresRemoteBackup() async throws {
        let root = temporaryDirectoryURL(name: "webdav-view-model-restore")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let store = BookshelfStore(storageURL: root.appendingPathComponent("bookshelf.json"))
        let restored = BookshelfItem(
            id: "remote-book",
            sourceID: "remote-source",
            bookURL: "https://example.com/remote",
            title: "Remote Book",
            readingProgress: 0.5
        )
        let client = FakeWebDAVClient(downloadData: try makeArchiveData(items: [restored]))
        let viewModel = WebDAVSettingsViewModel(
            keychain: InMemoryWebDAVCredentialStore(),
            configurationStore: InMemoryWebDAVBackupConfigurationStore(),
            exporter: FakeWebDAVBackupExporter(result: emptyExportResult(root: root)),
            restorer: makeRestorer(root: root, bookshelfStore: store),
            webDAVClient: client
        )
        viewModel.serverURL = "https://dav.example.com/backups"
        viewModel.username = "reader"
        viewModel.password = "secret"
        viewModel.restoreURL = " https://dav.example.com/backups/reader_backup.readerbackup.json "

        await viewModel.restoreBackup()

        guard case .success(let message) = viewModel.restoreResult else {
            XCTFail("Expected WebDAV restore success, got \(viewModel.restoreResult)")
            return
        }
        XCTAssertEqual(message, "Restored 1 items")
        XCTAssertEqual(try store.loadItems(), [restored])
        let downloads = await client.downloadedBackups
        XCTAssertEqual(downloads.map(\.remoteURL.absoluteString), ["https://dav.example.com/backups/reader_backup.readerbackup.json"])
        XCTAssertEqual(downloads.first?.credentials.username, "reader")
    }

    func testURLSessionClientListsReaderBackupArchivesFromWebDAVMultistatus() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WebDAVURLProtocolStub.self]
        defer { WebDAVURLProtocolStub.handler = nil }
        WebDAVURLProtocolStub.handler = { request in
            XCTAssertEqual(request.httpMethod, "PROPFIND")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Depth"), "1")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Basic cmVhZGVyOnNlY3JldA==")
            let data = Data("""
            <?xml version="1.0" encoding="utf-8"?>
            <d:multistatus xmlns:d="DAV:">
              <d:response>
                <d:href>/webdav/backups/</d:href>
                <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop></d:propstat>
              </d:response>
              <d:response>
                <d:href>/webdav/backups/reader_backup_20260622_090000.readerbackup.json</d:href>
                <d:propstat><d:prop>
                  <d:getcontentlength>128</d:getcontentlength>
                  <d:getlastmodified>Mon, 22 Jun 2026 09:00:00 GMT</d:getlastmodified>
                  <d:getetag>"older-etag"</d:getetag>
                </d:prop></d:propstat>
              </d:response>
              <d:response>
                <d:href>/webdav/backups/notes.txt</d:href>
                <d:propstat><d:prop><d:getcontentlength>64</d:getcontentlength></d:prop></d:propstat>
              </d:response>
              <d:response>
                <d:href>/webdav/backups/reader_backup_20260623_100000.readerbackup.json</d:href>
                <d:propstat><d:prop>
                  <d:getcontentlength>256</d:getcontentlength>
                  <d:getlastmodified>Tue, 23 Jun 2026 10:00:00 GMT</d:getlastmodified>
                  <d:getetag>"newer-etag"</d:getetag>
                </d:prop></d:propstat>
              </d:response>
            </d:multistatus>
            """.utf8)
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 207,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/xml"]
                )!,
                data
            )
        }

        let client = URLSessionWebDAVClient(session: URLSession(configuration: configuration))
        let backups = try await client.listBackups(
            credentials: WebDAVCredentials(
                serverURL: "https://dav.example.com/webdav/backups",
                username: "reader",
                password: "secret"
            )
        )

        XCTAssertEqual(backups.map(\.filename), [
            "reader_backup_20260623_100000.readerbackup.json",
            "reader_backup_20260622_090000.readerbackup.json"
        ])
        XCTAssertEqual(backups.first?.remoteURL.absoluteString, "https://dav.example.com/webdav/backups/reader_backup_20260623_100000.readerbackup.json")
        XCTAssertEqual(backups.first?.byteCount, 256)
        XCTAssertEqual(backups.first?.etag, "newer-etag")
    }

    func testURLSessionClientDeletesRemoteBackupWithAuthorization() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WebDAVURLProtocolStub.self]
        defer { WebDAVURLProtocolStub.handler = nil }
        let remoteURL = URL(string: "https://dav.example.com/webdav/backups/reader_backup_delete.readerbackup.json")!
        WebDAVURLProtocolStub.handler = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url, remoteURL)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Basic cmVhZGVyOnNlY3JldA==")
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 204,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data()
            )
        }

        let client = URLSessionWebDAVClient(session: URLSession(configuration: configuration))
        let summary = try await client.deleteBackup(
            remoteURL: remoteURL,
            credentials: WebDAVCredentials(
                serverURL: "https://dav.example.com/webdav/backups",
                username: "reader",
                password: "secret"
            )
        )

        XCTAssertEqual(summary.statusCode, 204)
        XCTAssertEqual(summary.remoteURL, remoteURL)
    }

    func testViewModelListsRemoteBackupsAndRestoresSelectedBackup() async throws {
        let root = temporaryDirectoryURL(name: "webdav-view-model-list-restore")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let store = BookshelfStore(storageURL: root.appendingPathComponent("bookshelf.json"))
        let selectedURL = URL(string: "https://dav.example.com/backups/reader_backup_selected.readerbackup.json")!
        let olderURL = URL(string: "https://dav.example.com/backups/reader_backup_older.readerbackup.json")!
        let restored = BookshelfItem(
            id: "selected-remote-book",
            sourceID: "remote-source",
            bookURL: "https://example.com/selected",
            title: "Selected Remote Book",
            readingProgress: 0.8
        )
        let client = FakeWebDAVClient(
            remoteBackups: [
                WebDAVRemoteBackup(
                    remoteURL: selectedURL,
                    filename: selectedURL.lastPathComponent,
                    byteCount: 512,
                    modifiedAt: Date(timeIntervalSince1970: 1_800_000_600)
                ),
                WebDAVRemoteBackup(
                    remoteURL: olderURL,
                    filename: olderURL.lastPathComponent,
                    byteCount: 256,
                    modifiedAt: Date(timeIntervalSince1970: 1_800_000_500)
                )
            ],
            downloadDataByURL: [
                selectedURL: try makeArchiveData(items: [restored])
            ]
        )
        let viewModel = WebDAVSettingsViewModel(
            keychain: InMemoryWebDAVCredentialStore(),
            configurationStore: InMemoryWebDAVBackupConfigurationStore(),
            exporter: FakeWebDAVBackupExporter(result: emptyExportResult(root: root)),
            restorer: makeRestorer(root: root, bookshelfStore: store),
            webDAVClient: client
        )
        viewModel.serverURL = "https://dav.example.com/backups"
        viewModel.username = "reader"
        viewModel.password = "secret"

        await viewModel.loadRemoteBackups()

        guard case .success(let listMessage) = viewModel.listBackupsResult else {
            XCTFail("Expected backup list success, got \(viewModel.listBackupsResult)")
            return
        }
        XCTAssertEqual(listMessage, "Found 2 backups")
        XCTAssertEqual(viewModel.remoteBackups.map(\.id), [selectedURL.absoluteString, olderURL.absoluteString])
        XCTAssertEqual(viewModel.selectedRemoteBackupID, selectedURL.absoluteString)
        XCTAssertEqual(viewModel.restoreURL, selectedURL.absoluteString)
        let listedCredentials = await client.listedCredentials
        XCTAssertEqual(listedCredentials?.serverURL, "https://dav.example.com/backups")

        await viewModel.restoreSelectedBackup()

        guard case .success(let restoreMessage) = viewModel.restoreResult else {
            XCTFail("Expected selected restore success, got \(viewModel.restoreResult)")
            return
        }
        XCTAssertEqual(restoreMessage, "Restored 1 items")
        XCTAssertEqual(try store.loadItems(), [restored])
        let downloads = await client.downloadedBackups
        XCTAssertEqual(downloads.map(\.remoteURL), [selectedURL])
    }

    func testViewModelDeletesSelectedRemoteBackupAndUpdatesSelection() async throws {
        let root = temporaryDirectoryURL(name: "webdav-view-model-delete")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let selectedURL = URL(string: "https://dav.example.com/backups/reader_backup_selected.readerbackup.json")!
        let remainingURL = URL(string: "https://dav.example.com/backups/reader_backup_remaining.readerbackup.json")!
        let client = FakeWebDAVClient(
            remoteBackups: [
                WebDAVRemoteBackup(
                    remoteURL: selectedURL,
                    filename: selectedURL.lastPathComponent,
                    modifiedAt: Date(timeIntervalSince1970: 1_800_000_800)
                ),
                WebDAVRemoteBackup(
                    remoteURL: remainingURL,
                    filename: remainingURL.lastPathComponent,
                    modifiedAt: Date(timeIntervalSince1970: 1_800_000_700)
                )
            ]
        )
        let viewModel = WebDAVSettingsViewModel(
            keychain: InMemoryWebDAVCredentialStore(),
            configurationStore: InMemoryWebDAVBackupConfigurationStore(),
            exporter: FakeWebDAVBackupExporter(result: emptyExportResult(root: root)),
            webDAVClient: client
        )
        viewModel.serverURL = "https://dav.example.com/backups"
        viewModel.username = "reader"
        viewModel.password = "secret"

        await viewModel.loadRemoteBackups()
        await viewModel.deleteSelectedBackup()

        guard case .success(let deleteMessage) = viewModel.deleteBackupResult else {
            XCTFail("Expected delete success, got \(viewModel.deleteBackupResult)")
            return
        }
        XCTAssertEqual(deleteMessage, "Deleted reader_backup_selected.readerbackup.json")
        XCTAssertEqual(viewModel.remoteBackups.map(\.remoteURL), [remainingURL])
        XCTAssertEqual(viewModel.selectedRemoteBackupID, remainingURL.absoluteString)
        XCTAssertEqual(viewModel.restoreURL, remainingURL.absoluteString)
        let deleted = await client.deletedBackups
        XCTAssertEqual(deleted.map(\.remoteURL), [selectedURL])
    }

    private func temporaryDirectoryURL(name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeArchiveData(
        items: [BookshelfItem],
        bookSources: [BookSource] = [],
        readerSettings: ReaderDisplaySettings? = nil,
        readingProgress: [ReadingProgress] = [],
        restorePolicy: RestorePolicy = RestorePolicy(mode: .full, overwriteExisting: true)
    ) throws -> Data {
        let manifest = ReaderCoreModels.BackupManifest(
            backupID: "backup-restore",
            createdAt: Date(timeIntervalSince1970: 1_800_000_300),
            entries: [
                ReaderCoreModels.BackupManifest.Entry(
                    relativePath: "bookshelf.json",
                    sha256: nil,
                    sizeBytes: 0,
                    modifiedAt: Date(timeIntervalSince1970: 1_800_000_300)
                )
            ],
            totalBytes: 0,
            bookCount: items.count
        )
        let archive = WebDAVBackupArchive(
            package: ReaderCoreModels.BackupPackage(manifest: manifest, format: .directory),
            items: items,
            bookSources: bookSources,
            readerSettings: readerSettings,
            readingProgress: readingProgress,
            restorePolicy: restorePolicy
        )
        return try JSONEncoder().encode(archive)
    }

    private func makeRestorer(root: URL, bookshelfStore: BookshelfStore) -> WebDAVBackupRestorer {
        WebDAVBackupRestorer(
            bookshelfStore: bookshelfStore,
            bookSourceStore: BookSourceStore(storageURL: root.appendingPathComponent("book_sources_restore.json")),
            readerSettingsStore: ReaderSettingsStore(storageURL: root.appendingPathComponent("reader_settings_restore.json")),
            readingProgressStore: ReadingProgressStore(storageURL: root.appendingPathComponent("reading_progress_restore.json"))
        )
    }

    private func emptyExportResult(root: URL) -> WebDAVBackupExportResult {
        let manifest = ReaderCoreModels.BackupManifest(
            backupID: "unused",
            createdAt: Date(timeIntervalSince1970: 1_800_000_400),
            entries: [],
            totalBytes: 0,
            bookCount: 0
        )
        return WebDAVBackupExportResult(
            fileURL: root.appendingPathComponent("unused.readerbackup.json"),
            package: ReaderCoreModels.BackupPackage(manifest: manifest, format: .directory),
            itemCount: 0
        )
    }
}

private final class FakeWebDAVBackupExporter: WebDAVBackupExporting, @unchecked Sendable {
    private let result: WebDAVBackupExportResult

    init(result: WebDAVBackupExportResult) {
        self.result = result
    }

    func exportBackup() async throws -> WebDAVBackupExportResult {
        result
    }
}

private actor FakeWebDAVClient: WebDAVClienting {
    private let downloadData: Data
    private var remoteBackups: [WebDAVRemoteBackup]
    private let downloadDataByURL: [URL: Data]
    private(set) var testedCredentials: WebDAVCredentials?
    private(set) var listedCredentials: WebDAVCredentials?
    private(set) var uploadedBackups: [(fileURL: URL, credentials: WebDAVCredentials)] = []
    private(set) var downloadedBackups: [(remoteURL: URL, credentials: WebDAVCredentials)] = []
    private(set) var deletedBackups: [(remoteURL: URL, credentials: WebDAVCredentials)] = []

    init(
        downloadData: Data = Data("{\"empty\":true}".utf8),
        remoteBackups: [WebDAVRemoteBackup] = [],
        downloadDataByURL: [URL: Data] = [:]
    ) {
        self.downloadData = downloadData
        self.remoteBackups = remoteBackups
        self.downloadDataByURL = downloadDataByURL
    }

    func testConnection(credentials: WebDAVCredentials) async throws -> WebDAVConnectionSummary {
        testedCredentials = credentials
        return WebDAVConnectionSummary(
            statusCode: 207,
            method: "PROPFIND",
            serverURL: credentials.serverURL
        )
    }

    func uploadBackup(fileURL: URL, credentials: WebDAVCredentials) async throws -> WebDAVUploadSummary {
        uploadedBackups.append((fileURL, credentials))
        let byteCount = (try? Data(contentsOf: fileURL).count) ?? 0
        let remoteURL = URL(string: credentials.serverURL)!.appendingPathComponent(fileURL.lastPathComponent)
        if !remoteBackups.contains(where: { $0.remoteURL == remoteURL }) {
            remoteBackups.append(
                WebDAVRemoteBackup(
                    remoteURL: remoteURL,
                    filename: remoteURL.lastPathComponent,
                    byteCount: Int64(byteCount),
                    modifiedAt: Date(timeIntervalSince1970: 1_900_000_000)
                )
            )
        }
        return WebDAVUploadSummary(
            statusCode: 201,
            remoteURL: remoteURL,
            byteCount: byteCount
        )
    }

    func downloadBackup(remoteURL: URL, credentials: WebDAVCredentials) async throws -> WebDAVDownloadSummary {
        downloadedBackups.append((remoteURL, credentials))
        return WebDAVDownloadSummary(
            statusCode: 200,
            remoteURL: remoteURL,
            data: downloadDataByURL[remoteURL] ?? downloadData
        )
    }

    func listBackups(credentials: WebDAVCredentials) async throws -> [WebDAVRemoteBackup] {
        listedCredentials = credentials
        return remoteBackups
    }

    func deleteBackup(remoteURL: URL, credentials: WebDAVCredentials) async throws -> WebDAVDeleteSummary {
        deletedBackups.append((remoteURL, credentials))
        remoteBackups.removeAll { $0.remoteURL == remoteURL }
        return WebDAVDeleteSummary(statusCode: 204, remoteURL: remoteURL)
    }
}

private final class WebDAVURLProtocolStub: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: WebDAVStubError.missingHandler)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private enum WebDAVStubError: Error {
    case missingHandler
}

private final class InMemoryWebDAVCredentialStore: WebDAVCredentialStoring, @unchecked Sendable {
    private var credentials: WebDAVCredentials?

    func save(_ credentials: WebDAVCredentials) throws {
        self.credentials = credentials
    }

    func load() throws -> WebDAVCredentials? {
        credentials
    }
}

private final class InMemoryWebDAVBackupConfigurationStore: WebDAVBackupConfigurationStoring, @unchecked Sendable {
    private var configuration: WebDAVBackupConfiguration
    private(set) var savedConfigurations: [WebDAVBackupConfiguration] = []

    init(configuration: WebDAVBackupConfiguration = WebDAVBackupConfiguration()) {
        self.configuration = configuration
    }

    func load() throws -> WebDAVBackupConfiguration {
        configuration
    }

    func save(_ configuration: WebDAVBackupConfiguration) throws {
        self.configuration = configuration
        savedConfigurations.append(configuration)
    }
}

private actor FakeWebDAVProgressRemote: WebDAVProgressRemoteSyncing {
    private var records: [ReadingProgress]
    private(set) var loadedCredentials: WebDAVCredentials?
    private(set) var savedCredentials: WebDAVCredentials?
    private(set) var savedRecordBatches: [[ReadingProgress]] = []

    init(records: [ReadingProgress] = []) {
        self.records = records
    }

    func loadProgress(credentials: WebDAVCredentials) async throws -> [ReadingProgress] {
        loadedCredentials = credentials
        return records
    }

    func saveProgress(_ records: [ReadingProgress], credentials: WebDAVCredentials) async throws {
        savedCredentials = credentials
        savedRecordBatches.append(records)
        self.records = records
    }
}

private actor FakeWebDAVProgressSyncer: WebDAVProgressSyncing {
    private let summary: WebDAVProgressSyncSummary
    private(set) var lastCredentials: WebDAVCredentials?

    init(summary: WebDAVProgressSyncSummary) {
        self.summary = summary
    }

    func syncAll(credentials: WebDAVCredentials) async throws -> WebDAVProgressSyncSummary {
        lastCredentials = credentials
        return summary
    }
}
