import Foundation
import ReaderAppSupport

public final class ReadingProgressStore: @unchecked Sendable, ReadingProgressing {
    public static let shared = ReadingProgressStore()

    private let fileURL: URL
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("reading_progress.json")
    }

    public init(storageURL: URL) {
        fileURL = storageURL
    }

    private func loadAllProgress() throws -> [String: ReadingProgress] {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([String: ReadingProgress].self, from: data)
    }

    private func saveAllProgress(_ progressMap: [String: ReadingProgress]) throws {
        lock.lock()
        defer { lock.unlock() }

        let data = try encoder.encode(progressMap)
        try data.write(to: fileURL)
    }

    public func loadProgress(bookID: String) throws -> ReadingProgress? {
        let progressMap = try loadAllProgress()
        return progressMap[bookID]
    }

    public func saveProgress(_ progress: ReadingProgress) throws {
        var progressMap = (try? loadAllProgress()) ?? [:]
        progressMap[progress.bookID] = progress
        try saveAllProgress(progressMap)
    }

    public func removeProgress(bookID: String) throws {
        var progressMap = (try? loadAllProgress()) ?? [:]
        progressMap.removeValue(forKey: bookID)
        try saveAllProgress(progressMap)
    }
}