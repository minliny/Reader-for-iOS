import Foundation
import ReaderHost

@MainActor
final class M2AppSession {
    let search: SearchCoordinator
    let sources: SourceManagementCoordinator
    let downloads: DownloadCoordinator
    private(set) var downloadRecoveryError: (any Error)?

    init(library: LibraryHost, root: URL) {
        search = SearchCoordinator(runtime: library.runtime)
        sources = SourceManagementCoordinator(runtime: library.runtime, network: library.network)
        downloads = DownloadCoordinator(
            runtime: library.runtime,
            journal: root.appending(path: "M2HostOperations/download-prefetch.json")
        )
    }

    func recoverDownloads() async {
        do {
            _ = try await downloads.recoverSavedPrefetches()
            downloadRecoveryError = nil
        } catch {
            downloadRecoveryError = error
        }
    }
}
