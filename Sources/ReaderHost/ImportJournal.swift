import Foundation
import ReaderCoreBridge

public actor ImportJournal {
    public struct Entry: Codable, Sendable {
        public enum Phase: String, Codable, Sendable {
            case persistDispatched, persisted, shelfDispatched, shelfCommitted, completed, rolledBack
        }

        public let transactionId: String
        public let bookId: String
        public let sha256: String
        public let stagedPath: String
        public var phase: Phase
        public var rollbackToken: ImportLocalBookRollbackToken?

        public init(transactionId: String, bookId: String, staged: StagedSource) {
            self.transactionId = transactionId
            self.bookId = bookId
            self.sha256 = staged.sha256
            self.stagedPath = staged.path.path
            self.phase = .persistDispatched
        }
    }

    private let directory: URL

    public init(root: URL) { self.directory = root.appendingPathComponent("import-journal", isDirectory: true) }

    public func record(_ entry: Entry) throws {
        guard UUID(uuidString: entry.transactionId) != nil else { throw FileAndAssetFailure.unauthorized }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(entry.transactionId + ".json")
        let bytes = try JSONEncoder().encode(entry)
        try bytes.write(to: url, options: .atomic)
    }

    public func pending() throws -> [Entry] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { try JSONDecoder().decode(Entry.self, from: Data(contentsOf: $0)) }
            .filter { $0.phase != .completed && $0.phase != .rolledBack }
    }
}
