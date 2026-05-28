import Foundation

// MARK: - TOC Snapshot Model (M2.2)

public struct TOCSnapshot: Codable, Sendable {
    public let sourceId: String
    public let sourceName: String
    public let host: String
    public let bookURL: String
    public let chapterCount: Int
    public let requestedAt: String
    public let chapters: [TOCSnapshotItem]

    public init(sourceId: String, sourceName: String, host: String, bookURL: String, chapterCount: Int, chapters: [TOCSnapshotItem]) {
        self.sourceId = sourceId; self.sourceName = sourceName; self.host = host
        self.bookURL = bookURL; self.chapterCount = chapterCount
        self.requestedAt = ISO8601DateFormatter().string(from: Date())
        self.chapters = chapters
    }
}

public struct TOCSnapshotItem: Codable, Sendable {
    public let chapterTitle: String
    public let chapterURL: String
    public let index: Int
}

// MARK: - Search Snapshot Model

public struct SearchSnapshot: Codable, Sendable {
    public let sourceId: String
    public let sourceName: String
    public let host: String
    public let operation: String
    public let keyword: String
    public let requestedAt: String
    public let resultCount: Int
    public let networkTriggered: Bool
    public let results: [SearchSnapshotItem]
}

public struct SearchSnapshotItem: Codable, Sendable {
    public let title: String
    public let author: String?
    public let bookURL: String
    public let coverURL: String?
    public let intro: String?

    public init(from item: any SearchResultConvertible) {
        self.title = item.snapshotTitle
        self.author = item.snapshotAuthor
        self.bookURL = item.snapshotBookURL
        self.coverURL = item.snapshotCoverURL
        self.intro = item.snapshotIntro
    }
}

public protocol SearchResultConvertible {
    var snapshotTitle: String { get }
    var snapshotAuthor: String? { get }
    var snapshotBookURL: String { get }
    var snapshotCoverURL: String? { get }
    var snapshotIntro: String? { get }
}

/// Phase 4D: SnapshotStore — 本地快照路径管理 + M1.3 search snapshot save/load
public final class SnapshotStore: Sendable {
    public let snapshotRoot: URL

    public init(snapshotRoot: URL) {
        self.snapshotRoot = snapshotRoot
    }

    // MARK: - Path Construction

    public func makeSnapshotPath(candidateId: String, operation: String) -> String {
        let safeCandidate = sanitize(candidateId)
        let safeOperation = sanitize(operation)
        return "\(safeCandidate)/\(safeOperation).json"
    }

    public func metadataPath(for snapshotRelativePath: String) -> String {
        snapshotRelativePath + ".metadata.json"
    }

    // MARK: - Safety

    public func validatePathInsideSnapshotRoot(_ relativePath: String) -> Bool {
        if relativePath.contains("..") { return false }
        if relativePath.hasPrefix("/") { return false }
        let fullPath = snapshotRoot.appendingPathComponent(relativePath).standardized.path
        let rootPath = snapshotRoot.standardized.path
        return fullPath.hasPrefix(rootPath)
    }

    public func hasSnapshot(_ relativePath: String) -> Bool {
        guard validatePathInsideSnapshotRoot(relativePath) else { return false }
        let metaURL = snapshotRoot.appendingPathComponent(metadataPath(for: relativePath))
        return FileManager.default.fileExists(atPath: metaURL.path)
    }

    // MARK: - M1.3: Search Snapshot Save

    public func saveSearchSnapshot(
        sourceId: String, sourceName: String, host: String,
        keyword: String, results: [SearchSnapshotItem], networkTriggered: Bool
    ) -> Result<String, Error> {
        let relativePath = makeSnapshotPath(candidateId: sourceId, operation: "search")
        guard validatePathInsideSnapshotRoot(relativePath) else {
            return .failure(SnapshotStoreError.invalidPath(relativePath))
        }

        let snapshot = SearchSnapshot(
            sourceId: sourceId, sourceName: sourceName, host: host,
            operation: "search", keyword: keyword,
            requestedAt: ISO8601DateFormatter().string(from: Date()),
            resultCount: results.count, networkTriggered: networkTriggered,
            results: results
        )

        let fileURL = snapshotRoot.appendingPathComponent(relativePath)
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            return .success(relativePath)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - M1.3: Search Snapshot Load

    public func loadSearchSnapshot(candidateId: String) -> SearchSnapshot? {
        let relativePath = makeSnapshotPath(candidateId: candidateId, operation: "search")
        guard validatePathInsideSnapshotRoot(relativePath) else { return nil }
        let fileURL = snapshotRoot.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(SearchSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }

    // MARK: - M2.2 TOC Snapshot

    public func saveTOCSnapshot(sourceId: String, sourceName: String, host: String, bookURL: String, chapters: [TOCSnapshotItem]) -> Result<String, Error> {
        let relativePath = makeSnapshotPath(candidateId: sourceId, operation: "toc")
        guard validatePathInsideSnapshotRoot(relativePath) else {
            return .failure(SnapshotStoreError.invalidPath(relativePath))
        }
        let toc = TOCSnapshot(sourceId: sourceId, sourceName: sourceName, host: host, bookURL: bookURL, chapterCount: chapters.count, chapters: chapters)
        let fileURL = snapshotRoot.appendingPathComponent(relativePath)
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        do {
            let data = try JSONEncoder().encode(toc)
            try data.write(to: fileURL, options: .atomic)
            return .success(relativePath)
        } catch {
            return .failure(error)
        }
    }

    public func loadTOCSnapshot(candidateId: String) -> TOCSnapshot? {
        let relativePath = makeSnapshotPath(candidateId: candidateId, operation: "toc")
        guard validatePathInsideSnapshotRoot(relativePath),
              let data = try? Data(contentsOf: snapshotRoot.appendingPathComponent(relativePath)),
              let toc = try? JSONDecoder().decode(TOCSnapshot.self, from: data)
        else { return nil }
        return toc
    }

    // MARK: - Placeholder

    public func saveSnapshotPlaceholder(candidateId: String, operation: String, host: String) -> Result<String, Error> {
        let relativePath = makeSnapshotPath(candidateId: candidateId, operation: operation)
        guard validatePathInsideSnapshotRoot(relativePath) else {
            return .failure(SnapshotStoreError.invalidPath(relativePath))
        }
        let metaURL = snapshotRoot.appendingPathComponent(metadataPath(for: relativePath))
        let metaDir = metaURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: metaDir, withIntermediateDirectories: true)
        let metadata: [String: String] = [
            "candidateId": candidateId, "operation": operation, "host": host,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "placeholder": "true"
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
            try data.write(to: metaURL, options: .atomic)
            return .success(relativePath)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Content Save

    public func saveContent(_ relativePath: String, jsonData: Data) -> Result<String, Error> {
        guard validatePathInsideSnapshotRoot(relativePath) else {
            return .failure(SnapshotStoreError.invalidPath(relativePath))
        }
        let fileURL = snapshotRoot.appendingPathComponent(relativePath)
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        do {
            try jsonData.write(to: fileURL, options: .atomic)
            return .success(relativePath)
        } catch {
            return .failure(error)
        }
    }

    private func sanitize(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return input.unicodeScalars.filter { allowed.contains($0) }.map { String($0) }.joined()
    }
}

public enum SnapshotStoreError: Error, LocalizedError {
    case invalidPath(String)
    public var errorDescription: String? {
        switch self { case .invalidPath(let path): return "Snapshot path 不安全或越界：\(path)" }
    }
}
