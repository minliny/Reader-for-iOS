import Foundation
import CryptoKit
import Darwin

/// A private import-resource receipt, never a Core mutation receipt. Paths are
/// relative to the retained-source directory so container migration is harmless.
struct ReaderImportStagingOwner: Codable {
    enum Phase: String, Codable { case copying, sealed, handedOff }
    struct FileIdentity: Codable, Equatable {
        let device: UInt64
        let inode: UInt64
        init(_ value: stat) {
            device = UInt64(bitPattern: Int64(value.st_dev))
            inode = UInt64(value.st_ino)
        }
    }
    struct CreatedSource: Codable, Equatable {
        let name: String
        let identity: FileIdentity
    }
    let version: Int
    let id: String
    let stagedName: String
    let expectedBytes: Int64
    var payloadIdentity: FileIdentity?
    var phase: Phase
    var sha256: String?
    var createdSource: CreatedSource? = nil
    var transactionID: String { "ios-import-" + id }
}

/// Test checkpoints observe actual production-written state. They do not supply
/// a parse result, receipt, file content or permission to skip a safety check.
enum ReaderImportStagingCheckpoint: Equatable {
    case sourceWillOpen
    case admitted
    case ownerDurable
    case payloadBound
    case firstChunkWritten
    case sealed
    case parsed
    case handedOff
    case retainedSourceRegistered
    case localV2TerminalDurable
    case localV2NonAdmissionDurable
    case sourceDescriptorClosed(succeeded: Bool)
    case payloadDescriptorClosed(succeeded: Bool)
}
typealias ReaderImportStagingObserver = @Sendable (ReaderImportStagingCheckpoint, URL) throws -> Void

/// Cancellation is observed even if Foundation invokes its coordinated accessor
/// outside the original Swift task context. It never cancels a Core mutation.
final class ReaderImportCopyCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    func check() throws {
        lock.lock(); let value = cancelled; lock.unlock()
        if value { throw CancellationError() }
    }
}

/// One nonblocking OS lease for import/copy/reprocess/recovery at this library.
/// It stays held across actor suspension; OS release on process death is not
/// inferred from an age, a PID, a shelf read or the absence of a Core reply.
final class ReaderImportStagingLease {
    static let maximumInputBytes: Int64 = 64 * 1024 * 1024 // Core141 local-book input bound.
    private let stageURL: URL
    private let stageFD: Int32
    private let ownersFD: Int32
    private var lockFD: Int32
    private let observe: ReaderImportStagingObserver

    init(stagingURL: URL, observe: @escaping ReaderImportStagingObserver = { _, _ in }) throws {
        let stage = try Self.openDirectory(stagingURL)
        var owners: Int32 = -1
        var lock: Int32 = -1
        do {
            if mkdirat(stage, ".owners", 0o700) != 0, errno != EEXIST { throw Self.posix() }
            owners = openat(stage, ".owners", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard owners >= 0 else { throw Self.posix() }
            lock = openat(owners, "lease", O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
            guard lock >= 0 else { throw Self.posix() }
            _ = try Self.regularStat(lock)
            guard flock(lock, LOCK_EX | LOCK_NB) == 0 else {
                if errno == EWOULDBLOCK || errno == EAGAIN { throw ReaderLibraryError.busy }
                throw Self.posix()
            }
        } catch {
            if lock >= 0 { Darwin.close(lock) }
            if owners >= 0 { Darwin.close(owners) }
            Darwin.close(stage)
            throw error
        }
        stageURL = stagingURL
        stageFD = stage
        ownersFD = owners
        lockFD = lock
        self.observe = observe
    }
    deinit { release(); Darwin.close(ownersFD); Darwin.close(stageFD) }
    func release() {
        guard lockFD >= 0 else { return }
        _ = flock(lockFD, LOCK_UN)
        Darwin.close(lockFD)
        lockFD = -1
    }

    /// This is deliberately synchronous like the old copyItem: no worker may
    /// outlive importInFlight, the security-scope access, or the OS lease.
    func copy(_ input: URL, selection: String, cancellation: ReaderImportCopyCancellation? = nil) throws -> ReaderImportStagingOwner {
        guard Self.validID(selection) else { throw ReaderLibraryError.invalidResponse("staging identity") }
        var failure: NSError?
        var result: Result<ReaderImportStagingOwner, Error>?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: input, options: [], error: &failure) { coordinated in
            result = Result { try self.copyCoordinated(coordinated, selection: selection, cancellation: cancellation) }
        }
        if let failure { throw failure }
        guard let result else { throw ReaderLibraryError.invalidResponse("coordinated source read") }
        return try result.get()
    }

    private func copyCoordinated(_ input: URL, selection: String, cancellation: ReaderImportCopyCancellation?) throws -> ReaderImportStagingOwner {
        var pathBefore = stat()
        guard lstat(input.path, &pathBefore) == 0 else { throw Self.posix() }
        guard Self.isRegular(pathBefore) else { throw ReaderLibraryError.unsupportedFile }
        try observe(.sourceWillOpen, input)
        // NONBLOCK prevents a raced special-file replacement from blocking open.
        let sourceFD = open(input.path, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC)
        guard sourceFD >= 0 else { throw Self.posix() }
        defer {
            let succeeded = Darwin.close(sourceFD) == 0
            try? observe(.sourceDescriptorClosed(succeeded: succeeded), input)
        }
        let sourceBefore = try Self.regularStat(sourceFD)
        guard Self.sameSnapshot(pathBefore, sourceBefore) else { throw Self.sourceChanged() }
        guard sourceBefore.st_size >= 0, sourceBefore.st_size <= Self.maximumInputBytes else {
            throw CocoaError(.fileReadTooLarge)
        }
        try cancellation?.check()
        try Task.checkCancellation()
        try observe(.admitted, input)
        var owner = ReaderImportStagingOwner(version: 1, id: selection, stagedName: selection + ".source",
            expectedBytes: sourceBefore.st_size, payloadIdentity: nil, phase: .copying, sha256: nil)
        var existingOwner = stat()
        guard fstatat(ownersFD, owner.id + ".json", &existingOwner, AT_SYMLINK_NOFOLLOW) != 0, errno == ENOENT else {
            throw ReaderLibraryError.invalidResponse("staging owner already exists")
        }
        try store(owner)
        do {
            try observe(.ownerDurable, payloadURL(owner))
            let destinationFD = openat(stageFD, owner.stagedName, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
            guard destinationFD >= 0 else { throw Self.posix() }
            defer {
                let succeeded = Darwin.close(destinationFD) == 0
                try? observe(.payloadDescriptorClosed(succeeded: succeeded), payloadURL(owner))
            }
            owner.payloadIdentity = ReaderImportStagingOwner.FileIdentity(try Self.regularStat(destinationFD))
            try store(owner) // No payload byte may be written before this receipt.
            try observe(.payloadBound, payloadURL(owner))
            let source = FileHandle(fileDescriptor: sourceFD, closeOnDealloc: false)
            let destination = FileHandle(fileDescriptor: destinationFD, closeOnDealloc: false)
            var digest = SHA256()
            var copied: Int64 = 0
            while copied < owner.expectedBytes {
                try cancellation?.check()
                try Task.checkCancellation()
                let maximum = Int(min(1024 * 1024, owner.expectedBytes - copied))
                guard let chunk = try source.read(upToCount: maximum), !chunk.isEmpty else { throw Self.sourceChanged() }
                try destination.write(contentsOf: chunk)
                digest.update(data: chunk)
                copied += Int64(chunk.count)
                if copied == Int64(chunk.count) { try observe(.firstChunkWritten, payloadURL(owner)) }
            }
            try cancellation?.check()
            try Task.checkCancellation()
            guard (try source.read(upToCount: 1))?.isEmpty != false else { throw Self.sourceChanged() }
            let sourceAfter = try Self.regularStat(sourceFD)
            var pathAfter = stat()
            guard lstat(input.path, &pathAfter) == 0,
                  Self.sameSnapshot(sourceBefore, sourceAfter), Self.sameSnapshot(sourceBefore, pathAfter) else {
                throw Self.sourceChanged()
            }
            try destination.synchronize()
            guard try Self.regularStat(destinationFD).st_size == owner.expectedBytes else { throw Self.sourceChanged() }
            owner.sha256 = digest.finalize().map { String(format: "%02x", $0) }.joined()
            owner.phase = .sealed
            try store(owner)
            try observe(.sealed, payloadURL(owner))
            return owner
        } catch {
            // Only this known precommit owner may retire this exact inode. An
            // ambiguous create-before-inode-bind crash is preserved on recovery.
            try? retirePrecommit(owner, protections: [])
            throw error
        }
    }

    func payloadURL(_ owner: ReaderImportStagingOwner) -> URL { stageURL.appendingPathComponent(owner.stagedName) }
    func parsed(_ owner: ReaderImportStagingOwner) throws { try observe(.parsed, payloadURL(owner)) }

    /// Resource identity survives handoff until an exact business terminal. It
    /// is not an ACK and never permits replay of the original mutation.
    @discardableResult
    func handoff(_ owner: ReaderImportStagingOwner) throws -> ReaderImportStagingOwner {
        var transferred = owner
        transferred.phase = .handedOff
        try store(transferred)
        try observe(.handedOff, payloadURL(owner))
        return transferred
    }

    /// The caller has already registered this actual rename identity in RAM,
    /// before this write or any directory fsync can fail.
    func recordCreatedSource(_ owner: ReaderImportStagingOwner) throws {
        guard valid(owner), owner.phase == .handedOff, owner.createdSource != nil else {
            throw ReaderLibraryError.invalidResponse("created source ownership")
        }
        try validateExistingOwner(against: owner)
        try store(owner)
        try observe(.retainedSourceRegistered, stageURL.deletingLastPathComponent().appendingPathComponent(owner.createdSource!.name))
    }

    func owner(for transactionID: String) throws -> ReaderImportStagingOwner? {
        guard transactionID.hasPrefix("ios-import-") else { return nil }
        let id = String(transactionID.dropFirst("ios-import-".count))
        guard Self.validID(id) else { return nil }
        do {
            let value = try readOwner(id + ".json")
            guard valid(value), value.transactionID == transactionID else { throw Self.sourceChanged() }
            return value
        } catch let error as NSError where error.domain == NSPOSIXErrorDomain && error.code == Int(ENOENT) { return nil }
    }

    enum RetirementAuthority: Equatable { case notDispatched, persistRejected, rolledBack, finalized }

    /// Requires the business owner to have consumed the original Core terminal,
    /// or to prove this same invocation never entered the persist send attempt.
    /// Unlike orphan recovery, the live exact proof remains valid if its owner
    /// metadata was already absent. Only the recorded path AND inode can retire.
    func retireOwned(_ owner: ReaderImportStagingOwner, authority: RetirementAuthority) throws {
        guard valid(owner), owner.payloadIdentity != nil else { throw Self.sourceChanged() }
        try validateExistingOwner(against: owner)
        if authority == .persistRejected || authority == .notDispatched, owner.createdSource != nil { throw Self.sourceChanged() }
        try retireExact(name: owner.stagedName, identity: owner.payloadIdentity!, directoryFD: stageFD)
        if authority == .rolledBack, let created = owner.createdSource {
            let sourceFD = try Self.openDirectory(stageURL.deletingLastPathComponent())
            defer { Darwin.close(sourceFD) }
            try retireExact(name: created.name, identity: created.identity, directoryFD: sourceFD)
        }
        // finalized deliberately leaves the readable book's retained source.
        try removeOwner(owner)
    }

    private func validateExistingOwner(against expected: ReaderImportStagingOwner) throws {
        guard let current = try owner(for: expected.transactionID) else { return }
        guard current.id == expected.id, current.stagedName == expected.stagedName,
              current.sha256 == expected.sha256, current.payloadIdentity == expected.payloadIdentity,
              current.createdSource == nil || current.createdSource == expected.createdSource else { throw Self.sourceChanged() }
    }

    private func retireExact(name: String, identity: ReaderImportStagingOwner.FileIdentity, directoryFD: Int32) throws {
        guard !name.contains("/"), name != ".", name != ".." else { throw Self.sourceChanged() }
        var current = stat()
        if fstatat(directoryFD, name, &current, AT_SYMLINK_NOFOLLOW) != 0 {
            guard errno == ENOENT else { throw Self.posix() }
            try Self.sync(directoryFD) // Retry a previous unlink whose fsync failed.
            return
        }
        guard Self.isRegular(current), ReaderImportStagingOwner.FileIdentity(current) == identity else { throw Self.sourceChanged() }
        guard unlinkat(directoryFD, name, 0) == 0 else { throw Self.posix() }
        try Self.sync(directoryFD)
    }

    struct Protection {
        let transactionID: String
        let stagedName: String
        let hash: String
    }

    /// Enumerates only this new receipt namespace. Old naked .source files,
    /// unrecognized receipts, symlinks and every business-owned payload survive.
    func recoverPrecommit(protections: [Protection]) throws {
        let ownersURL = stageURL.appendingPathComponent(".owners", isDirectory: true)
        for url in try FileManager.default.contentsOfDirectory(at: ownersURL, includingPropertiesForKeys: nil) where url.pathExtension == "json" {
            guard let owner = try? readOwner(url.lastPathComponent), valid(owner),
                  url.lastPathComponent == owner.id + ".json" else { continue }
            try retirePrecommit(owner, protections: protections)
        }
    }

    func retirePrecommit(_ owner: ReaderImportStagingOwner, protections: [Protection]) throws {
        guard valid(owner), let currentOwner = try? readOwner(owner.id + ".json"), valid(currentOwner),
              currentOwner.id == owner.id, currentOwner.stagedName == owner.stagedName else { return }
        let owner = currentOwner // Never downgrade a durable handedOff phase via a stale caller value.
        let related = protections.filter { $0.transactionID == owner.transactionID || $0.stagedName == owner.stagedName }
        if related.contains(where: { $0.transactionID == owner.transactionID && $0.stagedName == owner.stagedName && $0.hash == owner.sha256 }) {
            return // Keep exact resource identity until this original business terminal.

        }
        guard related.isEmpty, owner.phase != .handedOff else { return }
        var current = stat()
        if fstatat(stageFD, owner.stagedName, &current, AT_SYMLINK_NOFOLLOW) != 0 {
            if errno == ENOENT { try removeOwner(owner); return }
            throw Self.posix()
        }
        guard Self.isRegular(current), let identity = owner.payloadIdentity,
              ReaderImportStagingOwner.FileIdentity(current) == identity,
              current.st_size >= 0, current.st_size <= owner.expectedBytes else { return }
        if owner.phase == .sealed {
            guard let hash = owner.sha256, try Self.verifiedSHA256(at: payloadURL(owner)) == hash else { return }
        }
        guard unlinkat(stageFD, owner.stagedName, 0) == 0 else { throw Self.posix() }
        try Self.sync(stageFD)
        try removeOwner(owner)
    }

    private func valid(_ owner: ReaderImportStagingOwner) -> Bool {
        guard owner.version == 1, Self.validID(owner.id), owner.stagedName == owner.id + ".source",
              owner.expectedBytes >= 0, owner.expectedBytes <= Self.maximumInputBytes else { return false }
        if owner.phase != .copying {
            guard let hash = owner.sha256, hash.count == 64,
                  hash.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
                  owner.payloadIdentity != nil else { return false }
        }
        if let created = owner.createdSource {
            guard owner.phase == .handedOff, let hash = owner.sha256, created.name == hash + ".source",
                  created.identity == owner.payloadIdentity else { return false }
        }
        return true
    }
    private static func validID(_ value: String) -> Bool { UUID(uuidString: value)?.uuidString.lowercased() == value }
    private func readOwner(_ name: String) throws -> ReaderImportStagingOwner {
        let fd = openat(ownersFD, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard fd >= 0 else { throw Self.posix() }
        defer { Darwin.close(fd) }
        let initial = try Self.regularStat(fd)
        guard initial.st_size >= 0, initial.st_size <= 16 * 1024 else { throw Self.sourceChanged() }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        let data = try handle.read(upToCount: Int(initial.st_size) + 1) ?? Data()
        guard data.count == Int(initial.st_size), Self.sameSnapshot(initial, try Self.regularStat(fd)) else { throw Self.sourceChanged() }
        return try JSONDecoder().decode(ReaderImportStagingOwner.self, from: data)
    }
    private func store(_ owner: ReaderImportStagingOwner) throws {
        try Self.writeDurably(try JSONEncoder().encode(owner), directoryFD: ownersFD, name: owner.id + ".json")
        try Self.sync(stageFD) // Includes the new .owners directory entry.
    }
    private func removeOwner(_ owner: ReaderImportStagingOwner) throws {
        guard unlinkat(ownersFD, owner.id + ".json", 0) == 0 || errno == ENOENT else { throw Self.posix() }
        try Self.sync(ownersFD)
    }

    static func writeDurably(_ data: Data, to url: URL) throws {
        let directory = try openDirectory(url.deletingLastPathComponent())
        defer { Darwin.close(directory) }
        try writeDurably(data, directoryFD: directory, name: url.lastPathComponent)
    }
    private static func writeDurably(_ data: Data, directoryFD: Int32, name: String) throws {
        guard !name.isEmpty, !name.contains("/"), name != ".", name != ".." else { throw sourceChanged() }
        let temporary = ".write-" + UUID().uuidString.lowercased()
        let fd = openat(directoryFD, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw posix() }
        defer { Darwin.close(fd) }
        do {
            let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
            try handle.write(contentsOf: data)
            try handle.synchronize()
            guard renameat(directoryFD, temporary, directoryFD, name) == 0 else { throw posix() }
            try sync(directoryFD)
        } catch {
            _ = unlinkat(directoryFD, temporary, 0) // Only this invocation's exclusive temporary.
            throw error
        }
    }
    static func verifiedSHA256(at url: URL) throws -> String { try verifiedFile(at: url).sha256 }
    static func verifiedFile(at url: URL) throws -> (sha256: String, identity: ReaderImportStagingOwner.FileIdentity) {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw posix() }
        defer { Darwin.close(fd) }
        let initial = try regularStat(fd)
        guard initial.st_size >= 0, initial.st_size <= maximumInputBytes else { throw CocoaError(.fileReadTooLarge) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        var remaining = initial.st_size
        var digest = SHA256()
        while remaining > 0 {
            let length = Int(min(1024 * 1024, remaining))
            guard let data = try handle.read(upToCount: length), !data.isEmpty else { throw sourceChanged() }
            digest.update(data: data)
            remaining -= Int64(data.count)
        }
        guard (try handle.read(upToCount: 1))?.isEmpty != false,
              sameSnapshot(initial, try regularStat(fd)) else { throw sourceChanged() }
        return (digest.finalize().map { String(format: "%02x", $0) }.joined(), .init(initial))
    }
    /// RENAME_EXCL (iOS 10+) is an atomic, no-overwrite, same-volume rename.
    /// A cross-volume operation fails; it cannot silently copy to a new inode.
    static func moveExclusively(_ source: URL, to destination: URL) throws {
        guard renameatx_np(AT_FDCWD, source.path, AT_FDCWD, destination.path, UInt32(RENAME_EXCL)) == 0 else { throw posix() }
    }
    static func synchronizeDirectory(_ url: URL) throws {
        let fd = try openDirectory(url)
        defer { Darwin.close(fd) }
        try sync(fd)
    }
    private static func openDirectory(_ url: URL) throws -> Int32 {
        let fd = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw posix() }
        return fd
    }
    private static func regularStat(_ fd: Int32) throws -> stat {
        var value = stat()
        guard fstat(fd, &value) == 0 else { throw posix() }
        guard isRegular(value) else { throw ReaderLibraryError.unsupportedFile }
        return value
    }
    private static func isRegular(_ value: stat) -> Bool { (value.st_mode & S_IFMT) == S_IFREG }
    private static func sameSnapshot(_ lhs: stat, _ rhs: stat) -> Bool {
        isRegular(lhs) && isRegular(rhs) && lhs.st_dev == rhs.st_dev && lhs.st_ino == rhs.st_ino &&
            lhs.st_size == rhs.st_size && lhs.st_mtimespec.tv_sec == rhs.st_mtimespec.tv_sec &&
            lhs.st_mtimespec.tv_nsec == rhs.st_mtimespec.tv_nsec && lhs.st_ctimespec.tv_sec == rhs.st_ctimespec.tv_sec &&
            lhs.st_ctimespec.tv_nsec == rhs.st_ctimespec.tv_nsec
    }
    private static func sync(_ fd: Int32) throws { guard fsync(fd) == 0 else { throw posix() } }
    private static func posix() -> NSError { NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    private static func sourceChanged() -> ReaderLibraryError { .invalidResponse("local import source changed") }
}
