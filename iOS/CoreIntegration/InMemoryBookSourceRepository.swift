import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

public final class InMemoryBookSourceRepository: BookSourceRepository, @unchecked Sendable {
    private var sources: [String: BookSource] = [:]
    private let lock = NSLock()

    public init() {}

    public func save(_ source: BookSource) async throws {
        lock.lock()
        defer { lock.unlock() }

        let id = source.id ?? UUID().uuidString
        var mutableSource = source
        mutableSource.id = id
        sources[id] = mutableSource
    }

    public func allSources() async throws -> [BookSource] {
        lock.lock()
        defer { lock.unlock() }
        return Array(sources.values)
    }

    public func source(id: String) async throws -> BookSource? {
        lock.lock()
        defer { lock.unlock() }
        return sources[id]
    }
}
