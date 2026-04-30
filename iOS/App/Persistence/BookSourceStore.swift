import Foundation
import ReaderCoreModels

public final class BookSourceStore: @unchecked Sendable {
    public static let shared = BookSourceStore()

    private let fileManager = FileManager.default
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()
    private var cache: [BookSource]?

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ReaderApp", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("book_sources.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public init(storageURL: URL) {
        fileURL = storageURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    public func load() async throws -> [BookSource] {
        if let cached = withLock({ cache }) {
            return cached
        }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        var sources = try decoder.decode([BookSource].self, from: data)

        if sources.isEmpty {
            return []
        }

        for i in sources.indices {
            if sources[i].id == nil {
                sources[i].id = UUID().uuidString
            }
        }

        withLock { cache = sources }

        return sources
    }

    public func save(_ sources: [BookSource]) async throws {
        withLock { cache = sources }

        let data = try encoder.encode(sources)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func add(_ source: BookSource) async throws {
        var sources = try await load()
        var newSource = source
        if newSource.id == nil {
            newSource.id = UUID().uuidString
        }
        sources.append(newSource)
        try await save(sources)
    }

    public func delete(id: String) async throws {
        var sources = try await load()
        sources.removeAll { $0.id == id }
        try await save(sources)
    }

    public func update(_ source: BookSource) async throws {
        var sources = try await load()
        if let index = sources.firstIndex(where: { $0.id == source.id }) {
            sources[index] = source
            try await save(sources)
        }
    }

    public func toggleEnabled(id: String) async throws {
        var sources = try await load()
        if let index = sources.firstIndex(where: { $0.id == id }) {
            sources[index].enabled = !sources[index].enabled
            try await save(sources)
        }
    }

    public func clearCache() {
        withLock { cache = nil }
    }
}

extension BookSource {
    public var displayName: String {
        bookSourceName
    }

    public var displayURL: String {
        bookSourceUrl ?? "No URL"
    }
}
