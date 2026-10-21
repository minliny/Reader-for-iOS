import Foundation

/// One production runtime per app process, shared by the scene and OS-granted
/// refresh work. A background launch never opens a parallel business database.
actor ReaderAppRuntimeStore {
    static let shared = ReaderAppRuntimeStore()
    private var pending: Task<ReaderLibraryService, Error>?
    func library() async throws -> ReaderLibraryService {
        if let pending { return try await pending.value }
        let task = Task.detached(priority: .userInitiated) {
            let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true).appendingPathComponent("Reader", isDirectory: true)
            return try ReaderLibraryService(storageURL: directory.appendingPathComponent("Core", isDirectory: true),
                sourceURL: directory.appendingPathComponent("LocalSources", isDirectory: true))
        }
        pending = task
        do { return try await task.value }
        catch { pending = nil; throw error }
    }
}
