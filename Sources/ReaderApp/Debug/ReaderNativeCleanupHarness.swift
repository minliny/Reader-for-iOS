#if DEBUG
import SwiftUI
import BackgroundTasks
import CryptoKit
import Security

/// This switch changes only a deliberately selected DEBUG launch. Neither an
/// invalid request nor a failed journey may fall back to the preserved library.
enum ReaderNativeCleanupLaunch {
    static let modeKey = "READER_NATIVE_CLEANUP_MODE"
    static let runKey = "READER_NATIVE_CLEANUP_RUN_ID"
    static let mode = "physical-isolated-native-cleanup-v1"
    static let isRequested = ProcessInfo.processInfo.environment[modeKey] != nil
        || ProcessInfo.processInfo.environment[runKey] != nil
    private(set) static var backgroundHandlerRegistered = false
    private static var registrationAttempted = false

    @MainActor static func registerBackgroundRejectionHandler() {
        guard !registrationAttempted else { return }
        registrationAttempted = true
        // Do not cancel or reschedule an existing user request. If the OS
        // delivers one during this launch, it cannot open the original runtime.
        backgroundHandlerRegistered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "io.reader.minliny.rule-sub-refresh", using: nil) {
                $0.setTaskCompleted(success: false)
            }
    }

    @MainActor static func admittedRun() throws -> UUID {
        #if targetEnvironment(simulator)
        throw ReaderLibraryError.invalidResponse("The native cleanup journey requires a physical iPhone")
        #else
        let environment = ProcessInfo.processInfo.environment
        guard environment[modeKey] == mode,
              let raw = environment[runKey], let run = UUID(uuidString: raw),
              raw == run.uuidString.lowercased(),
              Bundle.main.bundleIdentifier == "io.reader.minliny.free",
              UIDevice.current.userInterfaceIdiom == .phone,
              environment["SIMULATOR_UDID"] == nil,
              backgroundHandlerRegistered else {
            throw ReaderLibraryError.invalidResponse("The isolated native cleanup launch was not admitted")
        }
        return run
        #endif
    }
}

struct ReaderNativeCleanupHarnessView: View {
    @StateObject private var owner = ReaderNativeCleanupHarnessOwner()
    @State private var panelPresented = false

    var body: some View {
        VStack(spacing: 16) {
            Text("DEBUG 隔离原生清理取证").accessibilityIdentifier("native-cleanup-harness")
            ReaderPageState(title: owner.title, detail: owner.failure ?? "", loading: owner.preparing)
            Text(owner.phase).font(.caption)
                .accessibilityIdentifier("native-cleanup-harness-phase")
            if owner.phase == "ready" {
                Text(verbatim: owner.readyProofIdentity).font(.caption2)
                    .accessibilityIdentifier("native-cleanup-ready-identity")
                Text(verbatim: owner.readyProofSource).font(.caption2)
                    .accessibilityIdentifier("native-cleanup-ready-source")
                Text(verbatim: owner.readyProofInventory).font(.caption2)
                    .accessibilityIdentifier("native-cleanup-ready-inventory")
            }
            if owner.phase == "finished" {
                Text(verbatim: owner.finalProofResult).font(.caption2)
                    .accessibilityIdentifier("native-cleanup-finished-result")
                Text(verbatim: owner.finalProofIsolation).font(.caption2)
                    .accessibilityIdentifier("native-cleanup-finished-isolation")
            }
            if owner.ready {
                if !owner.panelClosed {
                    Button("打开隔离下载面板") { owner.panelOpened = true; panelPresented = true }
                        .accessibilityIdentifier("native-cleanup-harness-open")
                } else {
                    Button("核对并结束隔离取证") { Task { await owner.verifyAndFinish() } }
                        .accessibilityIdentifier("native-cleanup-harness-finish")
                }
            }
        }.padding(20)
            .task { await owner.prepare() }
            .sheet(isPresented: $panelPresented, onDismiss: { owner.panelClosed = true }) {
                if let model = owner.model, let session = owner.session {
                    // The actual production view owns the alert, cleanup UUID,
                    // dispatch, ACK presentation, refresh and disappearance.
                    ReaderOnlineDownloadPanel(model: model, session: session)
                }
            }
    }
}

/// Real network preparation and read-only postconditions around the production
/// panel. There is deliberately no cleanup dispatch method in this harness.
@MainActor
private final class ReaderNativeCleanupHarnessOwner: ObservableObject {
    @Published private(set) var preparing = true
    @Published private(set) var ready = false
    @Published private(set) var title = "正在准备真实隔离书库"
    @Published private(set) var failure: String?
    @Published private(set) var phase = "preparing"
    @Published private(set) var evidenceText = "{}"
    @Published private(set) var readyProofIdentity = ""
    @Published private(set) var readyProofSource = ""
    @Published private(set) var readyProofInventory = ""
    @Published private(set) var finalProofResult = ""
    @Published private(set) var finalProofIsolation = ""
    @Published private(set) var model: ReaderApplicationModel?
    @Published private(set) var session: ReaderActiveSession?
    @Published var panelOpened = false
    @Published var panelClosed = false

    private struct Fingerprint: Codable, Equatable { let bytes: UInt64; let sha256: String }
    private struct HostCommand: Decodable {
        let id: String
        let method: String
        let scope: String
        let parameters: Data
        let result: Data?
        let completed: Bool
    }
    private struct CookiePair { let sourceID: String; let query: [String: Any] }
    private var started = false
    private var finishing = false
    private var runID = "unadmitted"
    private var root: URL?
    private var evidenceDirectory: URL?
    private var markerBytes: Data?
    private var identityBytes: Data?
    private var packageURL: URL?
    private var service: ReaderLibraryService?
    private var credentialPairs: [CookiePair] = []
    private var originalFiles: [String: Fingerprint] = [:]
    private var sourceExport: Data?
    private var originalShelf: [ReaderBook] = []
    private var progress: ReaderProgressSnapshot?
    private var currentBody: ReaderChapterContent?
    private var completedBody: ReaderChapterContent?
    private var completedRow: ReaderDownloadChapter?
    private var automaticIdentity: ReaderCachedChapterIdentity?
    private var automaticBytes: UInt64 = 0
    private var baselineCommands: [String: Fingerprint] = [:]
    private var readingTimeFingerprint: Fingerprint?
    private var facts: [String: Any] = [:]
    private static let packageSHA = "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322"

    func prepare() async {
        guard !started else { return }
        started = true
        do {
            let run = try ReaderNativeCleanupLaunch.admittedRun()
            runID = run.uuidString.lowercased()
            let manager = FileManager.default
            let documents = try requiredURL(.documentDirectory)
            let input = documents.appendingPathComponent("Reader-real-sources.json")
            try requireRegularFile(input)
            let bytes = try Data(contentsOf: input)
            try require(bytes.count == 5606 && Self.sha(bytes) == Self.packageSHA, "Original real source package identity")
            packageURL = input
            originalFiles = try snapshotOriginal()
            let temporary = manager.temporaryDirectory.standardizedFileURL.resolvingSymlinksInPath()
            let directory = temporary.appendingPathComponent("ReaderNativeCleanup-" + runID, isDirectory: true)
            let evidence = temporary.appendingPathComponent("ReaderNativeCleanupEvidence-" + runID, isDirectory: true)
            try require(!manager.fileExists(atPath: directory.path) && !manager.fileExists(atPath: evidence.path), "Fresh UUID roots must be absent")
            try manager.createDirectory(at: directory, withIntermediateDirectories: false)
            root = directory
            let marker = try json(["mode": ReaderNativeCleanupLaunch.mode, "runID": runID])
            try marker.write(to: directory.appendingPathComponent("owner.json"), options: .withoutOverwriting)
            markerBytes = marker
            try manager.createDirectory(at: evidence, withIntermediateDirectories: false)
            evidenceDirectory = evidence
            try marker.write(to: evidence.appendingPathComponent("owner.json"), options: .withoutOverwriting)
            facts = ["schemaVersion": 1, "mode": ReaderNativeCleanupLaunch.mode, "runID": runID,
                     "bundleID": Bundle.main.bundleIdentifier ?? "", "temporaryRoot": directory.path,
                     "evidenceDirectory": evidence.path, "sourcePackageBytes": bytes.count,
                     "sourcePackageSHA256": Self.packageSHA, "backgroundRejectionHandlerRegistered": true,
                     "originalFileCount": originalFiles.count, "originalFilesSHA256": try digest(originalFiles),
                     "runtimeClosed": false, "temporaryCredentialPairsConfirmedAbsent": 0,
                     "temporaryRootRemovalAttempted": false, "temporaryRootRemoved": false,
                     "boundary": "Physical production panel in a fresh temporary library; original App data requires external postproof too"]
            facts["stage"] = "preparing-real-network-library"
            try writeEvidence("original-files", encodedFingerprints(originalFiles))
            try publish("preparing")

            let sourcesRoot = directory.appendingPathComponent("LocalSources", isDirectory: true)
            let operations = sourcesRoot.appendingPathComponent(".operations", isDirectory: true)
            let runtime = try ReaderLibraryService(storageURL: directory.appendingPathComponent("Core", isDirectory: true), sourceURL: sourcesRoot)
            service = runtime
            facts["runtimeCreated"] = true
            identityBytes = try Data(contentsOf: operations.appendingPathComponent(ReaderHostLibraryIdentity.fileName))
            let originalIdentityURL = try requiredURL(.applicationSupportDirectory)
                .appendingPathComponent("Reader/LocalSources/.operations/" + ReaderHostLibraryIdentity.fileName)
            try requireRegularFile(originalIdentityURL)
            let originalIdentity = try Data(contentsOf: originalIdentityURL)
            try require(identityBytes != originalIdentity, "Temporary and original library credential identities must differ")
            facts["originalLibraryIdentitySHA256"] = Self.sha(originalIdentity)
            facts["temporaryLibraryIdentityDiffersFromOriginal"] = true
            facts["temporaryLibraryIdentitySHA256"] = Self.sha(identityBytes ?? Data())
            // This is this fresh test library's non-secret UUID identity only.
            // Preserve it outside the removable root to attribute partial teardown.
            try writeEvidence("temporary-identity", json(["identityBase64": identityBytes?.base64EncodedString() ?? ""]))
            let namespace = try ReaderHostLibraryIdentity.loadOrCreate(in: operations)
            let imports = try await runtime.importSources(bytes, operationID: UUID().uuidString.lowercased())
            try require(imports.count == 2 && imports.allSatisfy(\.succeeded), "Both original source definitions must import")
            let sources = try await runtime.onlineSources()
            try require(sources.count == 2 && sources.allSatisfy(\.enabled), "Original enabled source definitions")
            // Admit only these exact, initially absent UUID-library pairs before
            // any search/body HTTP request. Cookie values never enter evidence.
            for sourceID in sources.map(\.id).sorted() {
                let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: "io.reader.minliny.source-cookies." + Self.sha(Data(namespace.utf8)),
                    kSecAttrAccount as String: Self.sha(Data(sourceID.utf8))]
                var read = query; read[kSecReturnData as String] = true
                var existing: CFTypeRef?
                try require(SecItemCopyMatching(read as CFDictionary, &existing) == errSecItemNotFound, "Fresh exact credential pair must be absent")
                credentialPairs.append(CookiePair(sourceID: sourceID, query: query))
            }
            try require(sources.contains { $0.id == "https://dushu.baidu.com/" }, "Original Baidu source must exist")
            let search = try await runtime.searchSource("https://dushu.baidu.com/", keyword: "剑来", page: 1)
            guard let candidate = search.books.first(where: { $0.sourceId == "https://dushu.baidu.com/" && $0.title == "剑来" }) else {
                throw ReaderLibraryError.invalidResponse("Real search did not return the required actual Baidu candidate")
            }
            let detail = try await runtime.onlineDetail(candidate)
            try require(!detail.chapters.isEmpty, "Real catalog must be nonempty")
            let book = try await runtime.addOnlineBook(detail, chapterIndex: detail.firstReadableIndex, operationID: UUID().uuidString.lowercased())
            try require(book.sourceId == candidate.sourceId && book.bookId == candidate.bookId, "Actual candidate and shelf identity")
            let current = try await runtime.content(for: book, chapterIndex: detail.firstReadableIndex)
            try require(!current.content.isEmpty && current.bodyVersion != nil && current.processingVersion != nil, "Real current body and versions")
            let observed = try await runtime.progress(for: book)
            let saved = try await runtime.saveProgress(for: book, content: current, scalarOffset: min(37, current.scalarCount), expectedRevision: observed.progressRevision)
            guard let downloaded = detail.chapters.first(where: {
                !$0.url.isEmpty && UInt64($0.index) > UInt64(detail.firstReadableIndex) + 2 && $0.index < UInt32.max
            }) else { throw ReaderLibraryError.invalidResponse("Real catalog lacks a separate downloadable chapter") }
            _ = try await runtime.downloadChapters(book, range: downloaded.index..<(downloaded.index + 1), operationID: UUID().uuidString.lowercased())
            let downloadedStatus = try await runtime.readerDownloadStatus(book)
            guard let completed = downloadedStatus.chapters.first(where: { $0.chapterIndex == downloaded.index }),
                  completed.state == .completed, completed.cachedBytes > 0,
                  let automatic = downloadedStatus.chapters.first(where: {
                      $0.navigable != false && !$0.url.isEmpty && $0.state == .missing &&
                      UInt64($0.chapterIndex) > UInt64(detail.firstReadableIndex) + 2 && $0.chapterIndex != downloaded.index
                  }) else { throw ReaderLibraryError.invalidResponse("Real completed download and separate missing automatic chapter are required") }
            let automaticBody = try await runtime.content(for: book, chapterIndex: automatic.chapterIndex)
            try require(!automaticBody.content.isEmpty && automaticBody.bodyVersion != nil && automaticBody.processingVersion != nil, "Real automatic body and versions")
            let status = try await runtime.readerDownloadStatus(book)
            let currentID = ReaderCachedChapterIdentity(book: book, chapterIndex: current.chapterIndex)
            let completedID = ReaderCachedChapterIdentity(book: book, chapterIndex: downloaded.index)
            let automaticID = ReaderCachedChapterIdentity(book: book, chapterIndex: automatic.chapterIndex)
            guard let automaticRow = status.chapters.first(where: { $0.chapterIndex == automatic.chapterIndex }) else {
                throw ReaderLibraryError.invalidResponse("Real automatic row missing")
            }
            let storage = try await runtime.readerStorageSummary(protected: [currentID])
            let cachedRows = status.chapters.filter { $0.cachedBytes > 0 }
            let cleanable = cachedRows.map { ReaderCachedChapterIdentity(book: book, chapterIndex: $0.chapterIndex) }
                .filter { !storage.protectedChapters.contains($0) }
            try require(automaticRow.state == .cached && automaticRow.cachedBytes > 0 &&
                storage.completedQueueChapters.contains(completedID) && !storage.completedQueueChapters.contains(automaticID) &&
                !storage.protectedChapters.contains(automaticID) && Set(cleanable) == Set([automaticID]) &&
                storage.cleanableBytes == automaticRow.cachedBytes && storage.totalBytes == cachedRows.reduce(UInt64(0), { $0 + $1.cachedBytes }) &&
                !storage.hasMore && !storage.completedQueueHasMore && storage.cleanupError == nil, "Complete exactly-one automatic-cache inventory")
            let pending = try await runtime.pendingFeatureOperations()
            try require(pending.isEmpty, "All preparation operations must have original terminal outcomes")
            currentBody = try await runtime.cachedDownloadBody(book, chapter: current.chapterIndex)
            completedBody = try await runtime.cachedDownloadBody(book, chapter: downloaded.index)
            try require(currentBody?.content == current.content && currentBody?.bodyVersion == current.bodyVersion &&
                currentBody?.processingVersion == current.processingVersion, "Current cache binds the actual network body")
            completedRow = completed; automaticIdentity = automaticID; automaticBytes = automaticRow.cachedBytes
            progress = saved; sourceExport = try await runtime.exportSources(nil); originalShelf = try await runtime.listBooks()
            baselineCommands = try snapshotFiles(operations.appendingPathComponent("commands", isDirectory: true))
            try writeEvidence("pre-cleanup-host-commands", encodedFingerprints(baselineCommands))
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            let protectedProgress = try encoder.encode(saved)
            try writeEvidence("protected-progress", protectedProgress)
            try require(try cleanupCommands().isEmpty, "No cleanup may precede the native confirm tap")
            let ledger = directory.appendingPathComponent("ReadingTime/ledger-v1.json")
            let isolatedModel = ReaderApplicationModel(service: runtime, readingTimeStorageURL: ledger)
            try require(!isolatedModel.readingTime.isActive && !isolatedModel.readingTime.hasPending &&
                isolatedModel.readingTime.queuedMilliseconds == 0 && isolatedModel.readingTime.failure == nil,
                "Only a fresh inactive temporary reading-time ledger may be installed")
            readingTimeFingerprint = try fingerprint(ledger)
            // No normal start(), reading view, preferences, font library,
            // subscription owner or reading visibility is started here.
            model = isolatedModel
            session = ReaderActiveSession(id: UUID(), book: book, chapters: detail.chapters, content: current,
                scalarOffset: saved.progress?.chapterOffset ?? 0, progressRevision: saved.progressRevision, restorationID: UUID())
            facts.merge(["sourceId": book.sourceId, "bookId": book.bookId, "title": book.title,
                         "searchCandidateCount": search.books.count, "currentChapterIndex": current.chapterIndex,
                         "completedChapterIndex": downloaded.index, "automaticChapterIndex": automatic.chapterIndex,
                         "automaticCachedBytes": automaticBytes, "automaticBodySHA256": Self.sha(Data(automaticBody.content.utf8)),
                         "currentBodySHA256": Self.sha(Data(current.content.utf8)),
                         "currentProgressSHA256": Self.sha(protectedProgress),
                         "completedBodySHA256": Self.sha(Data((completedBody?.content ?? "").utf8)),
                         "temporarySourceExportSHA256": Self.sha(sourceExport ?? Data()),
                         "temporaryShelfSHA256": Self.sha(try encoder.encode(originalShelf)),
                         "expectedStatusSummary": "已完成 \(status.completedCount) · 缓存 \(status.cachedCount) · 失败 \(status.failedCount) · 暂停 \(status.pausedCount)",
                         "expectedCleanupTitle": "自动缓存清理完成",
                         "expectedCleanupDetail": "本次已清理 1 章正文，共 \(ByteCountFormatter.string(fromByteCount: Int64(clamping: automaticBytes), countStyle: .file))。",
                         "baselineHostCommandCount": baselineCommands.count,
                         "readingTimeLedger": ledger.path, "readingTimeLedgerSHA256": readingTimeFingerprint?.sha256 ?? "",
                         "exactCredentialPairCount": credentialPairs.count]) { _, new in new }
            try require(try snapshotOriginal() == originalFiles, "Original protected files changed during isolated preparation")
            try publish("ready")
            title = "真实隔离书库已就绪"; preparing = false; ready = true
        } catch { stop(error) }
    }

    func verifyAndFinish() async {
        guard ready, panelOpened, panelClosed, !finishing else { return }
        finishing = true; ready = false
        do {
            facts["stage"] = "verifying-native-original-ack"
            guard let runtime = service, let root, let session, let currentBody, let completedBody,
                  let completedRow, let automaticIdentity, let progress, let sourceExport else {
                throw ReaderLibraryError.invalidResponse("Isolated preparation evidence is incomplete")
            }
            try assertOwnedRoot()
            try require(model?.actions.hasPending == false, "Native cleanup action owner must be settled")
            try require(try fingerprint(root.appendingPathComponent("ReadingTime/ledger-v1.json")) == readingTimeFingerprint,
                        "Inactive temporary reading-time ledger must remain exact")
            let pending = try await runtime.pendingFeatureOperations()
            try require(pending.isEmpty, "No temporary operation may remain pending")
            let commands = try cleanupCommands()
            try require(commands.count == 1, "Exactly one native cleanup operation is required")
            let command = commands[0]
            let expected: [String: Any] = ["contentScope": "text", "reason": "clear", "retainCompletedQueue": true,
                "retainedChapters": [], "protectedChapters": [["sourceId": session.book.sourceId,
                    "bookId": session.book.bookId, "chapterIndex": session.content.chapterIndex]]]
            try require(command.scope == "cache-storage" && command.completed &&
                command.parameters == json(expected), "Native original cleanup owner and immutable parameters")
            guard let result = command.result else { throw ReaderLibraryError.invalidResponse("Original cleanup ACK is missing") }
            let receipt = try JSONDecoder().decode(ReaderStorageSummary.self, from: result)
            try require(Set(receipt.removedChapters) == Set([automaticIdentity]) && receipt.removedContentBytes == automaticBytes &&
                !receipt.hasMore && receipt.cleanupError == nil, "Original cleanup ACK must remove exactly the real automatic body")
            let status = try await runtime.readerDownloadStatus(session.book)
            guard let removed = status.chapters.first(where: { $0.chapterIndex == automaticIdentity.chapterIndex }),
                  let retained = status.chapters.first(where: { $0.chapterIndex == completedRow.chapterIndex }) else {
                throw ReaderLibraryError.invalidResponse("Post-cleanup task identities missing")
            }
            try require(removed.state == .missing && removed.cachedBytes == 0 && sameRow(retained, completedRow), "Automatic body removed and completed task unchanged")
            let currentAfter = try await runtime.cachedDownloadBody(session.book, chapter: currentBody.chapterIndex)
            let completedAfter = try await runtime.cachedDownloadBody(session.book, chapter: completedBody.chapterIndex)
            let progressAfter = try await runtime.progress(for: session.book)
            let sourcesAfter = try await runtime.exportSources(nil)
            let shelfAfter = try await runtime.listBooks()
            try require(currentAfter == currentBody && completedAfter == completedBody && progressAfter == progress &&
                sourcesAfter == sourceExport && shelfAfter == originalShelf, "Current/completed bodies, progress, sources and shelf must be exact")
            let commandsNow = try snapshotFiles(root.appendingPathComponent("LocalSources/.operations/commands", isDirectory: true))
            try require(baselineCommands.allSatisfy { commandsNow[$0.key] == $0.value } &&
                commandsNow.count == baselineCommands.count + 1, "Only the native cleanup command may be added")
            try require(try snapshotOriginal() == originalFiles, "Original protected files must remain exact")
            facts.merge(["cleanupOperationID": command.id, "cleanupOriginalACKSHA256": Self.sha(result),
                         "removedChapterCount": receipt.removedChapters.count, "removedContentBytes": receipt.removedContentBytes,
                         "automaticMissing": true, "completedTaskAndBodyPreserved": true, "currentBodyAndProgressPreserved": true,
                         "originalProtectedFilesEqual": true, "onlyOneNativeCleanupCommandAdded": true]) { _, new in new }
            try writeEvidence("cleanup-original-host-command", JSONEncoder().encode(EvidenceCommand(command)))
            try publish("verified-before-close")
            // Unmounted production panel has cancelled its own refresh task.
            // A busy/unknown close is a stop, never permission to delete files.
            facts["stage"] = "closing-temporary-runtime"
            try await runtime.close()
            facts["runtimeClosed"] = true
            try assertOwnedRoot()
            try publish("runtime-closed")
            facts["stage"] = "deleting-exact-temporary-credential-pairs"
            var absentPairs = 0
            var pairResults: [[String: Any]] = []
            for pair in credentialPairs {
                let deleted = SecItemDelete(pair.query as CFDictionary)
                var read = pair.query; read[kSecReturnData as String] = true
                var remaining: CFTypeRef?
                let status = SecItemCopyMatching(read as CFDictionary, &remaining)
                pairResults.append(["sourceID": pair.sourceID, "deleteStatus": deleted, "postreadStatus": status])
                facts["temporaryCredentialCleanup"] = pairResults
                try require((deleted == errSecSuccess || deleted == errSecItemNotFound) && status == errSecItemNotFound,
                            "Exact admitted temporary credential pair cleanup")
                absentPairs += 1; facts["temporaryCredentialPairsConfirmedAbsent"] = absentPairs
                try publish("credential-pair-" + String(absentPairs) + "-absent")
            }
            facts["stage"] = "removing-exact-temporary-root"
            try publish("before-root-removal")
            facts["temporaryRootRemovalAttempted"] = true
            do {
                try FileManager.default.removeItem(at: root)
            } catch {
                facts["temporaryRootRemovalFailed"] = true
                // Recursive deletion may have removed children before failing.
                // Restore only this admitted UUID root's marker and namespace;
                // never overwrite an existing different identity.
                do { try retainPartialRootIdentity() }
                catch { facts["partialRootIdentityRetentionFailure"] = String(describing: error) }
                throw error
            }
            try require(!FileManager.default.fileExists(atPath: root.path), "Exact temporary root removal")
            facts["temporaryRootRemoved"] = true
            try publish("root-removed")
            facts["stage"] = "comparing-original-files-after-teardown"
            try require(try snapshotOriginal() == originalFiles, "Original protected files after teardown")
            service = nil; model = nil
            facts.merge(["runtimeClosed": true, "exactCredentialPairsAbsent": credentialPairs.count,
                         "temporaryRootRemoved": true, "originalProtectedFilesEqualAfterTeardown": true,
                         "externalPostproofRequired": true]) { _, new in new }
            try publish("finished")
            title = "隔离原生清理取证已核对"; preparing = false
        } catch { stop(error) }
    }

    private struct EvidenceCommand: Encodable {
        let id: String; let method: String; let scope: String; let parameters: Data; let result: Data?; let completed: Bool
        init(_ command: HostCommand) {
            id = command.id; method = command.method; scope = command.scope; parameters = command.parameters
            result = command.result; completed = command.completed
        }
    }
    private func sameRow(_ a: ReaderDownloadChapter, _ b: ReaderDownloadChapter) -> Bool {
        a.chapterIndex == b.chapterIndex && a.title == b.title && a.url == b.url && a.navigable == b.navigable &&
        a.state == b.state && a.cachedBytes == b.cachedBytes && a.attempts == b.attempts &&
        a.maxAttempts == b.maxAttempts && a.lastError == b.lastError && a.variables == b.variables
    }
    private func cleanupCommands() throws -> [HostCommand] {
        guard let root else { throw ReaderLibraryError.invalidResponse("Temporary root unavailable") }
        let directory = root.appendingPathComponent("LocalSources/.operations/commands", isDirectory: true)
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.map { url in
                try requireRegularFile(url)
                return try JSONDecoder().decode(HostCommand.self, from: Data(contentsOf: url))
            }.filter { $0.method == "cache.storage.cleanup" }
    }
    private func assertOwnedRoot() throws {
        guard let root, let markerBytes, let identityBytes else { throw ReaderLibraryError.invalidResponse("Temporary ownership proof unavailable") }
        let parent = FileManager.default.temporaryDirectory.standardizedFileURL.resolvingSymlinksInPath()
        try require(root.deletingLastPathComponent() == parent && root.lastPathComponent == "ReaderNativeCleanup-" + runID &&
            root.standardizedFileURL.resolvingSymlinksInPath() == root, "Exact temporary root containment")
        try require(try Data(contentsOf: root.appendingPathComponent("owner.json")) == markerBytes &&
            Data(contentsOf: root.appendingPathComponent("LocalSources/.operations/" + ReaderHostLibraryIdentity.fileName)) == identityBytes,
            "Exact temporary marker and library identity")
        _ = try snapshotFiles(root) // Refuse a symlink or unreadable descendant.
    }
    private func retainPartialRootIdentity() throws {
        guard let root, let markerBytes, let identityBytes else {
            throw ReaderLibraryError.invalidResponse("Partial temporary identity proof unavailable")
        }
        let manager = FileManager.default
        guard manager.fileExists(atPath: root.path) else {
            facts["temporaryRootRemoved"] = true
            facts["partialRootExists"] = false
            return
        }
        let parent = manager.temporaryDirectory.standardizedFileURL.resolvingSymlinksInPath()
        try require(root.deletingLastPathComponent() == parent && root.lastPathComponent == "ReaderNativeCleanup-" + runID &&
            root.resolvingSymlinksInPath() == root, "Partial temporary root containment")
        _ = try snapshotFiles(root)
        let operations = root.appendingPathComponent("LocalSources/.operations", isDirectory: true)
        try manager.createDirectory(at: operations, withIntermediateDirectories: true)
        for (url, data) in [(root.appendingPathComponent("owner.json"), markerBytes),
                            (operations.appendingPathComponent(ReaderHostLibraryIdentity.fileName), identityBytes)] {
            if manager.fileExists(atPath: url.path) {
                try requireRegularFile(url)
                try require(try Data(contentsOf: url) == data, "Existing partial temporary identity differs; it was not overwritten")
            } else { try data.write(to: url, options: .withoutOverwriting) }
        }
        facts["partialRootExists"] = true; facts["partialRootIdentityRetained"] = true
    }
    private func snapshotOriginal() throws -> [String: Fingerprint] {
        let original = try requiredURL(.applicationSupportDirectory).appendingPathComponent("Reader", isDirectory: true)
        try require(FileManager.default.fileExists(atPath: original.path), "Existing original Reader library required")
        var files = try snapshotFiles(original).reduce(into: [String: Fingerprint]()) { $0["Reader/" + $1.key] = $1.value }
        guard let packageURL else { throw ReaderLibraryError.invalidResponse("Original source package path unavailable") }
        files["Documents/Reader-real-sources.json"] = try fingerprint(packageURL)
        let preferences = try requiredURL(.libraryDirectory).appendingPathComponent("Preferences/" + (Bundle.main.bundleIdentifier ?? "") + ".plist")
        if FileManager.default.fileExists(atPath: preferences.path) { files["Preferences/App.plist"] = try fingerprint(preferences) }
        return files
    }
    private func snapshotFiles(_ directory: URL) throws -> [String: Fingerprint] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
        let rootFacts = try directory.resourceValues(forKeys: keys)
        let canonicalRoot = directory.standardizedFileURL.resolvingSymlinksInPath()
        try require(rootFacts.isDirectory == true && rootFacts.isSymbolicLink != true &&
            canonicalRoot == directory.standardizedFileURL, "Regular directory containment")
        let rootComponents = canonicalRoot.pathComponents
        var enumerationFailure: Error?
        guard let iterator = FileManager.default.enumerator(at: canonicalRoot, includingPropertiesForKeys: Array(keys),
            errorHandler: { _, error in enumerationFailure = error; return false }) else {
            throw ReaderLibraryError.invalidResponse("Protected file enumeration unavailable")
        }
        var files: [String: Fingerprint] = [:]
        for case let url as URL in iterator {
            let values = try url.resourceValues(forKeys: keys)
            let canonicalURL = url.standardizedFileURL.resolvingSymlinksInPath()
            let diagnostic = "root=\(directory.path); canonicalRoot=\(canonicalRoot.path); item=\(url.path); canonicalItem=\(canonicalURL.path)"
            try require(values.isSymbolicLink != true, "Protected symbolic link rejected: " + diagnostic)
            let itemComponents = canonicalURL.pathComponents
            // Foundation may enumerate /private/var (or /private/tmp) after
            // resolving the root to /var (or /tmp). Compare canonical components,
            // then read that same checked URL; raw spelling is not containment.
            try require(itemComponents.count > rootComponents.count && itemComponents.starts(with: rootComponents),
                "Protected canonical path escaped: " + diagnostic)
            if values.isDirectory == true { continue }
            try require(values.isRegularFile == true, "Protected item must be a regular file: " + diagnostic)
            files[itemComponents.dropFirst(rootComponents.count).joined(separator: "/")] = try fingerprint(canonicalURL)
        }
        if let enumerationFailure { throw enumerationFailure }
        return files
    }
    private func fingerprint(_ url: URL) throws -> Fingerprint {
        try requireRegularFile(url)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256(); var bytes: UInt64 = 0
        while let block = try handle.read(upToCount: 1024 * 1024), !block.isEmpty { hash.update(data: block); bytes += UInt64(block.count) }
        return Fingerprint(bytes: bytes, sha256: hash.finalize().map { String(format: "%02x", $0) }.joined())
    }
    private func requireRegularFile(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        try require(values.isRegularFile == true && values.isSymbolicLink != true &&
            url.standardizedFileURL.resolvingSymlinksInPath() == url.standardizedFileURL, "Regular non-symlink file required")
    }
    private func requiredURL(_ kind: FileManager.SearchPathDirectory) throws -> URL {
        guard let url = FileManager.default.urls(for: kind, in: .userDomainMask).first else {
            throw ReaderLibraryError.invalidResponse("App directory unavailable")
        }
        return url.standardizedFileURL.resolvingSymlinksInPath()
    }
    private func publish(_ phase: String) throws {
        facts["phase"] = phase
        let data = try json(facts)
        try writeEvidence(phase, data)
        let digest = Self.sha(data)
        if phase == "ready" {
            readyProofIdentity = try compactProof([("r", "runID"), ("m", "mode"), ("bundle", "bundleID")], evidenceSHA256: digest)
            readyProofSource = try compactProof([("o", "originalLibraryIdentitySHA256"),
                ("d", "temporaryLibraryIdentityDiffersFromOriginal"), ("s", "sourcePackageSHA256"),
                ("n", "sourcePackageBytes")])
            readyProofInventory = try compactProof([("src", "sourceId"), ("t", "title"),
                ("b", "automaticCachedBytes"), ("summary", "expectedStatusSummary"),
                ("title", "expectedCleanupTitle"), ("detail", "expectedCleanupDetail")])
        } else if phase == "finished" {
            finalProofResult = try compactProof([("r", "runID"), ("n", "removedChapterCount"),
                ("b", "removedContentBytes"), ("a", "automaticMissing"),
                ("c", "completedTaskAndBodyPreserved"), ("p", "currentBodyAndProgressPreserved")],
                evidenceSHA256: digest)
            finalProofIsolation = try compactProof([("h", "onlyOneNativeCleanupCommandAdded"),
                ("z", "runtimeClosed"), ("x", "exactCredentialPairsAbsent"),
                ("o", "originalProtectedFilesEqualAfterTeardown"), ("removed", "temporaryRootRemoved")])
        }
        evidenceText = String(decoding: data, as: UTF8.self)
        self.phase = ["ready", "finished"].contains(phase) ? phase : "preparing"
    }
    private func compactProof(_ fields: [(String, String)], evidenceSHA256: String? = nil) throws -> String {
        var output: [String: Any] = [:]
        for (alias, key) in fields {
            guard let value = facts[key] else { throw ReaderLibraryError.invalidResponse("Missing compact evidence field " + key) }
            output[alias] = value
        }
        if let evidenceSHA256 { output["e"] = evidenceSHA256 }
        let bytes = try json(output)
        try require(bytes.count <= 256, "Compact evidence exceeds accessibility field limit")
        return String(decoding: bytes, as: UTF8.self)
    }
    private func writeEvidence(_ name: String, _ data: Data) throws {
        guard let evidenceDirectory, let markerBytes else { throw ReaderLibraryError.invalidResponse("Evidence directory unavailable") }
        let values = try evidenceDirectory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        try require(values.isDirectory == true && values.isSymbolicLink != true &&
            evidenceDirectory.resolvingSymlinksInPath() == evidenceDirectory &&
            Data(contentsOf: evidenceDirectory.appendingPathComponent("owner.json")) == markerBytes, "Exact evidence directory ownership")
        try data.write(to: evidenceDirectory.appendingPathComponent(name + ".json"), options: .atomic)
    }
    private func stop(_ error: Error) {
        preparing = false; ready = false; title = "隔离取证已停止"
        let absentPairs = facts["temporaryCredentialPairsConfirmedAbsent"] as? Int ?? 0
        let removalAttempted = facts["temporaryRootRemovalAttempted"] as? Bool ?? false
        failure = "\(error)。已关闭运行时：\(facts["runtimeClosed"] as? Bool == true ? "是" : "否")；已核对缺席的临时凭据对：\(absentPairs)；临时根目录删除\(removalAttempted ? "已尝试，详见本轮证据" : "未尝试")。未回退原书库；停止后不再删除。"
        facts["runID"] = runID; facts["failure"] = String(describing: error)
        facts["phase"] = "failed"; facts["noFurtherAutomaticTeardown"] = true
        phase = "failed"
        if let root { facts["temporaryRootExistsAtFailure"] = FileManager.default.fileExists(atPath: root.path) }
        if let data = try? json(facts) { evidenceText = String(decoding: data, as: UTF8.self) }
        // Failure publication must never trigger recovery, close, redispatch or
        // broad cleanup. A partial teardown remains attributable to this UUID.
        if let data = evidenceText.data(using: .utf8) { try? writeEvidence("failed", data) }
    }
    private func require(_ condition: Bool, _ fact: String) throws {
        guard condition else { throw ReaderLibraryError.invalidResponse(fact) }
    }
    private func json(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) }
    private func digest(_ files: [String: Fingerprint]) throws -> String {
        Self.sha(try encodedFingerprints(files))
    }
    private func encodedFingerprints(_ files: [String: Fingerprint]) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(files)
    }
    private static func sha(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}
#endif
