import Foundation

public protocol SnapshotStoreProtocol: Sendable {
    func saveSnapshot(_ data: Data, identifier: String) async throws
    func loadSnapshot(identifier: String) async throws -> Data?
    func deleteSnapshot(identifier: String) async throws
    func listSnapshots() async -> [String]
}

public final class IOSSnapshotStore: SnapshotStoreProtocol, @unchecked Sendable {
    private let baseURL: URL
    private let fileManager = FileManager.default
    private let lock = NSLock()

    public init(baseURL: URL? = nil) {
        if let baseURL = baseURL {
            self.baseURL = baseURL
        } else {
            let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.baseURL = documents.appendingPathComponent("ReaderSnapshots", isDirectory: true)
        }
        try? fileManager.createDirectory(at: self.baseURL, withIntermediateDirectories: true)
    }

    public func saveSnapshot(_ data: Data, identifier: String) async throws {
        let url = baseURL.appendingPathComponent("\(identifier).json")
        try data.write(to: url, options: .atomic)
    }

    public func loadSnapshot(identifier: String) async throws -> Data? {
        let url = baseURL.appendingPathComponent("\(identifier).json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    public func deleteSnapshot(identifier: String) async throws {
        let url = baseURL.appendingPathComponent("\(identifier).json")
        try fileManager.removeItem(at: url)
    }

    public func listSnapshots() async -> [String] {
        guard let files = try? fileManager.contentsOfDirectory(atPath: baseURL.path) else {
            return []
        }
        return files
            .filter { $0.hasSuffix(".json") }
            .map { $0.replacingOccurrences(of: ".json", with: "") }
    }
}
