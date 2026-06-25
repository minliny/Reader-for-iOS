import Foundation
import ReaderAppPersistence
import ReaderAppSupport
import ReaderCoreModels
import ReaderShellValidation

public typealias WebDAVReadingProgress = ReaderAppSupport.ReadingProgress

public struct WebDAVProgressSyncPayload: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var records: [WebDAVReadingProgress]
    public var coreRecords: [ProgressCloudSyncRecord]
    public var cleanRoomMaintained: Bool
    public var externalGPLCodeCopied: Bool

    public init(
        schemaVersion: Int = 1,
        records: [WebDAVReadingProgress],
        deviceID: String,
        cleanRoomMaintained: Bool = true,
        externalGPLCodeCopied: Bool = false
    ) {
        let sortedRecords = records.sortedByStableProgressKey()
        self.schemaVersion = schemaVersion
        self.records = sortedRecords
        self.coreRecords = sortedRecords.map { $0.coreProgressRecord(deviceID: deviceID) }
        self.cleanRoomMaintained = cleanRoomMaintained
        self.externalGPLCodeCopied = externalGPLCodeCopied
    }
}

public enum WebDAVProgressConflictResolution: String, Codable, Equatable, Sendable {
    case localKept
    case remoteApplied
}

public struct WebDAVProgressSyncConflict: Codable, Equatable, Identifiable, Sendable {
    public var id: String { bookID }
    public var bookID: String
    public var local: WebDAVReadingProgress
    public var remote: WebDAVReadingProgress
    public var resolved: WebDAVReadingProgress
    public var resolution: WebDAVProgressConflictResolution

    public init(
        bookID: String,
        local: WebDAVReadingProgress,
        remote: WebDAVReadingProgress,
        resolved: WebDAVReadingProgress,
        resolution: WebDAVProgressConflictResolution
    ) {
        self.bookID = bookID
        self.local = local
        self.remote = remote
        self.resolved = resolved
        self.resolution = resolution
    }
}

public struct WebDAVProgressSyncSummary: Equatable, Sendable {
    public var localRecordCount: Int
    public var remoteRecordCount: Int
    public var uploadedRecordCount: Int
    public var downloadedRecordCount: Int
    public var conflictCount: Int
    public var conflicts: [WebDAVProgressSyncConflict]
    public var cleanRoomMaintained: Bool
    public var externalGPLCodeCopied: Bool

    public init(
        localRecordCount: Int,
        remoteRecordCount: Int,
        uploadedRecordCount: Int,
        downloadedRecordCount: Int,
        conflictCount: Int,
        conflicts: [WebDAVProgressSyncConflict] = [],
        cleanRoomMaintained: Bool = true,
        externalGPLCodeCopied: Bool = false
    ) {
        self.localRecordCount = localRecordCount
        self.remoteRecordCount = remoteRecordCount
        self.uploadedRecordCount = uploadedRecordCount
        self.downloadedRecordCount = downloadedRecordCount
        self.conflictCount = conflictCount
        self.conflicts = conflicts
        self.cleanRoomMaintained = cleanRoomMaintained
        self.externalGPLCodeCopied = externalGPLCodeCopied
    }
}

public protocol WebDAVProgressRemoteSyncing: Sendable {
    func loadProgress(credentials: WebDAVCredentials) async throws -> [WebDAVReadingProgress]
    func saveProgress(_ records: [WebDAVReadingProgress], credentials: WebDAVCredentials) async throws
}

public protocol WebDAVProgressSyncing: Sendable {
    func syncAll(credentials: WebDAVCredentials) async throws -> WebDAVProgressSyncSummary
}

public struct URLSessionWebDAVProgressSyncClient: WebDAVProgressRemoteSyncing {
    private let session: URLSession
    private let progressFilename: String
    private let deviceID: String

    public init(
        session: URLSession = .shared,
        progressFilename: String = "reader_progress.json",
        deviceID: String = "ios"
    ) {
        self.session = session
        self.progressFilename = progressFilename
        self.deviceID = deviceID
    }

    public func loadProgress(credentials: WebDAVCredentials) async throws -> [WebDAVReadingProgress] {
        let url = try progressURL(credentials: credentials)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(authorizationHeader(credentials), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        let status = try httpStatus(from: response)
        if status == 404 || data.isEmpty {
            return []
        }
        guard (200..<300).contains(status) else {
            throw WebDAVClientError.unexpectedHTTPStatus(status)
        }
        let payload = try JSONDecoder.webDAVProgressDecoder.decode(WebDAVProgressSyncPayload.self, from: data)
        guard payload.cleanRoomMaintained, !payload.externalGPLCodeCopied else {
            throw WebDAVBackupRestoreError.externalGPLCodeMarkerPresent
        }
        return payload.records.sortedByStableProgressKey()
    }

    public func saveProgress(_ records: [WebDAVReadingProgress], credentials: WebDAVCredentials) async throws {
        let url = try progressURL(credentials: credentials)
        let payload = WebDAVProgressSyncPayload(records: records, deviceID: deviceID)
        let data = try JSONEncoder.webDAVProgressEncoder.encode(payload)

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        request.setValue(authorizationHeader(credentials), forHTTPHeaderField: "Authorization")
        request.httpBody = data

        let (_, response) = try await session.data(for: request)
        let status = try httpStatus(from: response)
        guard (200..<300).contains(status) else {
            throw WebDAVClientError.unexpectedHTTPStatus(status)
        }
    }

    private func progressURL(credentials: WebDAVCredentials) throws -> URL {
        let trimmed = credentials.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = URL(string: trimmed),
              let scheme = baseURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw WebDAVClientError.invalidURL(credentials.serverURL)
        }
        if credentials.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || credentials.password.isEmpty {
            throw WebDAVClientError.missingCredentials
        }
        return baseURL.appendingPathComponent(progressFilename)
    }

    private func authorizationHeader(_ credentials: WebDAVCredentials) -> String {
        let token = "\(credentials.username.trimmingCharacters(in: .whitespacesAndNewlines)):\(credentials.password)"
            .data(using: .utf8)?
            .base64EncodedString() ?? ""
        return "Basic \(token)"
    }

    private func httpStatus(from response: URLResponse) throws -> Int {
        guard let http = response as? HTTPURLResponse else {
            throw WebDAVClientError.missingHTTPResponse
        }
        return http.statusCode
    }
}

public final class WebDAVProgressSyncService: WebDAVProgressSyncing, @unchecked Sendable {
    public static let shared = WebDAVProgressSyncService()

    private let progressStore: ReadingProgressStore
    private let remote: any WebDAVProgressRemoteSyncing

    public init(
        progressStore: ReadingProgressStore = .shared,
        remote: any WebDAVProgressRemoteSyncing = URLSessionWebDAVProgressSyncClient()
    ) {
        self.progressStore = progressStore
        self.remote = remote
    }

    public func syncAll(credentials: WebDAVCredentials) async throws -> WebDAVProgressSyncSummary {
        let localRecords = Array(try progressStore.loadAllProgress().values).sortedByStableProgressKey()
        let remoteRecords = try await remote.loadProgress(credentials: credentials)
        let resolution = resolve(local: localRecords, remote: remoteRecords)
        try progressStore.saveAllProgress(Dictionary(uniqueKeysWithValues: resolution.records.map { ($0.bookID, $0) }))
        try await remote.saveProgress(resolution.records, credentials: credentials)

        return WebDAVProgressSyncSummary(
            localRecordCount: localRecords.count,
            remoteRecordCount: remoteRecords.count,
            uploadedRecordCount: resolution.records.count,
            downloadedRecordCount: resolution.downloadedCount,
            conflictCount: resolution.conflicts.count,
            conflicts: resolution.conflicts
        )
    }

    private func resolve(
        local: [WebDAVReadingProgress],
        remote: [WebDAVReadingProgress]
    ) -> (records: [WebDAVReadingProgress], downloadedCount: Int, conflicts: [WebDAVProgressSyncConflict]) {
        var merged: [String: WebDAVReadingProgress] = Dictionary(uniqueKeysWithValues: local.map { ($0.bookID, $0) })
        var downloadedCount = 0
        var conflicts: [WebDAVProgressSyncConflict] = []

        for remoteRecord in remote {
            guard let localRecord = merged[remoteRecord.bookID] else {
                merged[remoteRecord.bookID] = remoteRecord
                downloadedCount += 1
                continue
            }
            guard localRecord != remoteRecord else { continue }
            if remoteRecord.updatedAt > localRecord.updatedAt {
                merged[remoteRecord.bookID] = remoteRecord
                downloadedCount += 1
                conflicts.append(
                    WebDAVProgressSyncConflict(
                        bookID: remoteRecord.bookID,
                        local: localRecord,
                        remote: remoteRecord,
                        resolved: remoteRecord,
                        resolution: .remoteApplied
                    )
                )
            } else {
                conflicts.append(
                    WebDAVProgressSyncConflict(
                        bookID: remoteRecord.bookID,
                        local: localRecord,
                        remote: remoteRecord,
                        resolved: localRecord,
                        resolution: .localKept
                    )
                )
            }
        }

        return (Array(merged.values).sortedByStableProgressKey(), downloadedCount, conflicts)
    }
}

public final class WebDAVProgressSyncAdapter: ProgressSyncAdapterProtocol, @unchecked Sendable {
    private let credentials: WebDAVCredentials
    private let remote: any WebDAVProgressRemoteSyncing

    public init(
        credentials: WebDAVCredentials,
        remote: any WebDAVProgressRemoteSyncing = URLSessionWebDAVProgressSyncClient()
    ) {
        self.credentials = credentials
        self.remote = remote
    }

    public func pushProgress(_ progress: WebDAVReadingProgress) async throws {
        var recordsByID = Dictionary(uniqueKeysWithValues: try await remote.loadProgress(credentials: credentials).map { ($0.bookID, $0) })
        recordsByID[progress.bookID] = progress
        try await remote.saveProgress(Array(recordsByID.values).sortedByStableProgressKey(), credentials: credentials)
    }

    public func pullProgress(bookID: String) async throws -> WebDAVReadingProgress? {
        try await remote.loadProgress(credentials: credentials).first { $0.bookID == bookID }
    }

    public func listRemoteProgress() async throws -> [WebDAVReadingProgress] {
        try await remote.loadProgress(credentials: credentials)
    }
}

private extension Array where Element == WebDAVReadingProgress {
    func sortedByStableProgressKey() -> [WebDAVReadingProgress] {
        sorted { lhs, rhs in
            if lhs.bookID != rhs.bookID { return lhs.bookID < rhs.bookID }
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
            return lhs.chapterURL < rhs.chapterURL
        }
    }
}

private extension WebDAVReadingProgress {
    func coreProgressRecord(deviceID: String) -> ProgressCloudSyncRecord {
        ProgressCloudSyncRecord(
            bookId: bookID,
            chapterIndex: 0,
            chapterTitle: chapterTitle,
            progressFraction: progressRatio,
            updatedAt: updatedAt,
            deviceId: deviceID
        )
    }
}

private extension JSONEncoder {
    static var webDAVProgressEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var webDAVProgressDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
