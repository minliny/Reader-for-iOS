import Foundation
import ReaderCoreBridge

public struct LibraryHost: Sendable {
    public let probe: LibraryProbe
    public let info: CoreInfoData
    public let runtime: CoreRuntimeActor
    public let network: NetworkAndWebHost?

    public static func open(
        directory: URL, host: (any CoreHost)? = nil
    ) async throws -> LibraryHost {
        let probe = try await Task.detached {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return try CoreFileABI.probe(directory)
        }.value
        let network: NetworkAndWebHost?
        if let host {
            network = host as? NetworkAndWebHost
        } else {
            network = try await NetworkAndWebHost(directory: directory.appendingPathComponent("host", isDirectory: true))
        }
        let runtime = try await CoreRuntimeActor.open(
            config: ReaderRuntimeConfig(dataDirectory: directory.path, freshStorageFormat: .library47),
            host: host ?? network ?? SystemSurfaceHost()
        )
        do {
            let info = try await runtime.request(ReaderM1.coreInfo, EmptyParams()).value
            let layout = try await Task.detached { try CoreFileABI.probe(directory).observation.layout }.value
            guard info.sqliteUserVersion == 47, info.storageFormat?.format == .library47,
                  layout != nil,
                  !probe.observation.freshStorage || layout?.layoutId == "reader-sqlite-47-remote" else {
                throw CoreBridgeFailure.endpointMismatch
            }
            return LibraryHost(probe: probe, info: info, runtime: runtime, network: network)
        } catch {
            await runtime.close()
            throw error
        }
    }
}
