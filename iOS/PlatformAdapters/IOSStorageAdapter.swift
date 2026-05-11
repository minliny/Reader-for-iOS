import Foundation

public protocol LocalStorageProtocol: Sendable {
    func save(_ data: Data, to filename: String) async throws
    func load(from filename: String) async throws -> Data
    func delete(filename: String) async throws
    func exists(filename: String) async -> Bool
}

public final class IOSStorageAdapter: LocalStorageProtocol, @unchecked Sendable {
    private let fileManager = FileManager.default
    private let baseURL: URL
    private let lock = NSLock()

    public init(baseURL: URL? = nil) {
        if let baseURL = baseURL {
            self.baseURL = baseURL
        } else {
            let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.baseURL = documents.appendingPathComponent("ReaderStorage", isDirectory: true)
        }
        try? fileManager.createDirectory(at: self.baseURL, withIntermediateDirectories: true)
    }

    public func save(_ data: Data, to filename: String) async throws {
        let url = baseURL.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
    }

    public func load(from filename: String) async throws -> Data {
        let url = baseURL.appendingPathComponent(filename)
        return try Data(contentsOf: url)
    }

    public func delete(filename: String) async throws {
        let url = baseURL.appendingPathComponent(filename)
        try fileManager.removeItem(at: url)
    }

    public func exists(filename: String) async -> Bool {
        let url = baseURL.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: url.path)
    }
}
