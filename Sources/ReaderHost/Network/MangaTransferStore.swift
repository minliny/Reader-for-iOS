import CryptoKit
import Foundation
import ReaderCoreBridge

public struct MangaResourceFile: Sendable {
    public let url: URL
    public let bytes: Int
    public let sha256: String
    public let chunks: Int
}

public actor MangaTransferStore {
    private struct Destination {
        let url: URL
        var reservedBytes = 0
        var downloaded: MangaResourceFile?
    }

    private let directory: URL
    private var lease: MangaScratchLease?
    private var destinations: [String: Destination] = [:]
    private var inspections: [String: String] = [:]
    private var transfers = 0
    private let diskBudget = 64 * 1_048_576

    init(directory: URL) {
        self.directory = directory
    }

    /// Registration authorizes a single Core transfer to write a sandbox-owned
    /// target. The resulting file remains valid until its owner discards it.
    public func register(_ id: String) throws {
        guard destinations[id] == nil, destinations.count < 64 else {
            throw NetworkHostFailure.invalid("Manga cache is full or transfer ID is active")
        }
        let session = try lease ?? MangaScratchLease(root: directory)
        lease = session
        let url = session.directory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        destinations[id] = Destination(url: url)
    }

    public func result(_ id: String) -> MangaResourceFile? { destinations[id]?.downloaded }

    public func discard(_ id: String) {
        guard let item = destinations.removeValue(forKey: id) else { return }
        inspections = inspections.filter { $0.value != id }
        try? FileManager.default.removeItem(at: item.url)
    }

    public func registerInspection(_ inspection: String, of transfer: String) throws {
        guard inspections[inspection] == nil, destinations[transfer]?.downloaded != nil else {
            throw NetworkHostFailure.invalid("Manga inspection has no transferred asset")
        }
        inspections[inspection] = transfer
    }

    public func endInspection(_ inspection: String) {
        inspections.removeValue(forKey: inspection)
    }

    func fileForInspection(_ params: M3MangaTransferInspectInput) throws -> MangaResourceFile {
        guard let id = inspections[params.transferId], let asset = result(id),
              asset.bytes == params.bytes, asset.bytes <= params.maxBytes.rawValue,
              asset.sha256 == params.sha256 else {
            throw NetworkHostFailure.invalid("Manga inspection identity does not match transferred bytes")
        }
        return asset
    }

    func enterTransfer() throws {
        guard transfers < 2 else {
            throw NetworkHostFailure(code: .internal, phase: .runtime,
                                     message: "Two image transfers are already active", retryable: true)
        }
        transfers += 1
    }

    func leaveTransfer() { transfers -= 1 }

    func reserve(_ id: String, bytes: Int, scratch: Int) throws -> URL {
        let used = destinations.values.reduce(0) { $0 + $1.reservedBytes }
        guard let item = destinations[id], item.reservedBytes == 0, bytes > 0, bytes + scratch <= diskBudget - used else {
            throw NetworkHostFailure.invalid("Manga transfer is unregistered or exceeds the disk budget")
        }
        destinations[id]?.reservedBytes = bytes + scratch
        return item.url
    }

    func publish(_ id: String, bytes: Int, sha256: String, chunks: Int) throws {
        guard let item = destinations[id], bytes <= item.reservedBytes,
              FileManager.default.fileExists(atPath: item.url.path) else { throw CancellationError() }
        destinations[id]?.reservedBytes = bytes
        destinations[id]?.downloaded = MangaResourceFile(url: item.url, bytes: bytes, sha256: sha256, chunks: chunks)
    }
}
