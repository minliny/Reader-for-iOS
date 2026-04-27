import Foundation

public final class ChapterCacheStore: @unchecked Sendable {
    public static let shared = ChapterCacheStore()

    private let fileURL: URL
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("chapter_cache.json")
    }

    private func loadAllEntries() throws -> [String: ChapterCacheEntry] {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([String: ChapterCacheEntry].self, from: data)
    }

    private func saveAllEntries(_ entries: [String: ChapterCacheEntry]) throws {
        lock.lock()
        defer { lock.unlock() }

        let data = try encoder.encode(entries)
        try data.write(to: fileURL)
    }

    private func cacheKey(chapterURL: String, sourceID: String) -> String {
        return "\(sourceID)_\(chapterURL)"
    }

    public func loadEntry(chapterURL: String, sourceID: String) throws -> ChapterCacheEntry? {
        let entries = try loadAllEntries()
        return entries[cacheKey(chapterURL: chapterURL, sourceID: sourceID)]
    }

    public func saveEntry(_ entry: ChapterCacheEntry) throws {
        var entries = (try? loadAllEntries()) ?? [:]
        let key = cacheKey(chapterURL: entry.chapterURL, sourceID: entry.sourceID)
        entries[key] = entry
        try saveAllEntries(entries)
    }

    public func removeEntry(chapterURL: String, sourceID: String) throws {
        var entries = (try? loadAllEntries()) ?? [:]
        let key = cacheKey(chapterURL: chapterURL, sourceID: sourceID)
        entries.removeValue(forKey: key)
        try saveAllEntries(entries)
    }
}