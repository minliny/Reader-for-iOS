import Foundation

#if DEBUG
/// App-hosted tests must opt in before launch. Any partial or conflicting
/// request still isolates the production runtime; only a valid request may
/// be used as evidence that the intended test host was selected.
enum ReaderIsolatedUnitTestLaunch {
    static let modeKey = "READER_ISOLATED_UNIT_TEST_MODE"
    static let runKey = "READER_ISOLATED_UNIT_TEST_RUN_ID"
    static let mode = "physical-unit-tests-v1"

    static var isRequested: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment[modeKey] != nil || environment[runKey] != nil
    }

    static var isAdmitted: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let environment = ProcessInfo.processInfo.environment
        guard environment[modeKey] == mode,
              let raw = environment[runKey], let run = UUID(uuidString: raw),
              raw == run.uuidString.lowercased(),
              Bundle.main.bundleIdentifier == "io.reader.minliny.free",
              environment["SIMULATOR_UDID"] == nil,
              environment["READER_NATIVE_CLEANUP_MODE"] == nil,
              environment["READER_NATIVE_CLEANUP_RUN_ID"] == nil else { return false }
        return true
        #endif
    }
}
#endif

/// One production runtime per app process, shared by the scene and OS-granted
/// refresh work. A background launch never opens a parallel business database.
actor ReaderAppRuntimeStore {
    static let shared = ReaderAppRuntimeStore()
    private var pending: Task<ReaderLibraryService, Error>?
    func library() async throws -> ReaderLibraryService {
        #if DEBUG
        // Fail closed even for malformed journey arguments. No isolated UI
        // path may recover by opening the preserved production library.
        let launch = ProcessInfo.processInfo.environment
        guard launch["READER_NATIVE_CLEANUP_MODE"] == nil, launch["READER_NATIVE_CLEANUP_RUN_ID"] == nil,
              !ReaderIsolatedUnitTestLaunch.isRequested else {
            throw ReaderLibraryError.invalidResponse("An isolated test launch cannot open the shared App library")
        }
        #endif
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
