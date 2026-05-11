import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

public actor InMemoryBookSourceRepository: BookSourceRepository {
    private var sources: [String: BookSource] = [:]

    public init() {}

    public func save(_ source: BookSource) async throws {
        let id = source.id ?? UUID().uuidString
        var mutableSource = source
        mutableSource.id = id
        sources[id] = mutableSource
    }

    public func allSources() async throws -> [BookSource] {
        return Array(sources.values)
    }

    public func source(id searchId: String) async throws -> BookSource? {
        return sources[searchId]
    }
}
