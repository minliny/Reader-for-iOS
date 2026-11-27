import Darwin
import Foundation

/// A process lock owns one scratch directory. A separate parent lock serializes
/// discovery with directory creation across runtimes opening the same library.
final class MangaScratchLease: Sendable {
    let directory: URL
    private let descriptor: Int32

    init(root: URL) throws {
        let files = FileManager.default
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        let parent = try Self.openLock(root.appendingPathComponent(".sessions"))
        defer { close(parent) }
        guard flock(parent, LOCK_EX) == 0 else { throw Self.storageFailure }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        for candidate in try files.contentsOfDirectory(at: root, includingPropertiesForKeys: Array(keys)) {
            guard UUID(uuidString: candidate.lastPathComponent) != nil,
                  let info = try? candidate.resourceValues(forKeys: keys),
                  info.isDirectory == true, info.isSymbolicLink == false,
                  let stale = try? Self.openLock(candidate.appendingPathComponent(".owner")) else { continue }
            if flock(stale, LOCK_EX | LOCK_NB) == 0 {
                try? files.removeItem(at: candidate)
            }
            close(stale)
        }
        let created = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try files.createDirectory(at: created, withIntermediateDirectories: false)
        let owner: Int32
        do {
            owner = try Self.openLock(created.appendingPathComponent(".owner"))
        } catch {
            try? files.removeItem(at: created)
            throw error
        }
        guard flock(owner, LOCK_EX | LOCK_NB) == 0 else {
            close(owner)
            try? files.removeItem(at: created)
            throw Self.storageFailure
        }
        directory = created
        descriptor = owner
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
        close(descriptor)
    }

    private static func openLock(_ url: URL) throws -> Int32 {
        let fd = open(url.path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, mode_t(S_IRUSR | S_IWUSR))
        guard fd >= 0 else { throw storageFailure }
        return fd
    }

    private static var storageFailure: NetworkHostFailure {
        .init(code: .internal, phase: .storage, message: "Manga scratch ownership is unavailable")
    }
}
