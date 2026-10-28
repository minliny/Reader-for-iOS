import Foundation
import Darwin

/// Source-tool input only. The 32MiB host budget matches the existing HTTP
/// text-response bound; it is not a Core format or local-book import limit.
/// Foundation owns coordination, UTF-8 decoding and JSON parsing. No retained
/// source copy, import lease, journal, business model or parser is created.
public enum ReaderSourcePackageInput {
    public static let maximumBytes = 32 * 1024 * 1024

    public static func decodeUTF8(_ data: Data) throws -> String {
        try ReaderCoordinatedUTF8Input.decode(data, maximumBytes: maximumBytes)
    }

    /// Called before JSONSerialization, including programmatic/pasted input.
    public static func validateJSONBytes(_ data: Data) throws {
        _ = try decodeUTF8(data)
    }

    public static func readUTF8File(at url: URL) async throws -> String {
        try await ReaderCoordinatedUTF8Input.read(at: url, maximumBytes: maximumBytes, options: [])
    }
}

/// Exact Core@8e remote/rule_bundle.rs raw JSON bound. This does not parse or
/// validate a rule bundle; Core owns the format, merge and mutation receipt.
public enum ReaderRuleBundleInput {
    public static let maximumBytes = 16 * 1024 * 1024

    public static func validateJSON(_ text: String) throws {
        guard text.utf8.count <= maximumBytes else { throw CocoaError(.fileReadTooLarge) }
    }

    public static func readUTF8File(at url: URL) async throws -> String {
        try await ReaderCoordinatedUTF8Input.read(at: url, maximumBytes: maximumBytes, options: .withoutChanges)
    }
}

/// Shared platform byte I/O; callers retain their separate input policies.
private enum ReaderCoordinatedUTF8Input {
    static func decode(_ data: Data, maximumBytes: Int) throws -> String {
        guard data.count <= maximumBytes else { throw CocoaError(.fileReadTooLarge) }
        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return text
    }

    static func read(at url: URL, maximumBytes: Int, options: NSFileCoordinator.ReadingOptions) async throws -> String {
        try Task.checkCancellation()
        let read = ReaderCoordinatedUTF8Read(url: url, maximumBytes: maximumBytes, options: options)
        let worker = Task.detached(priority: .userInitiated) {
            try Self.decode(read.run(), maximumBytes: maximumBytes)
        }
        return try await withTaskCancellationHandler(operation: {
            let text = try await worker.value
            try Task.checkCancellation()
            return text
        }, onCancel: {
            read.cancel()
            worker.cancel()
        })
    }
}

/// One coordinated read on one regular descriptor. Reuses the existing native
/// cancellation flag because a coordinated accessor need not share Task context.
/// NSFileCoordinator.cancel stops a pending accessor; an active accessor checks
/// cancellation between bounded FileHandle reads. It does not cancel a save.
private final class ReaderCoordinatedUTF8Read: @unchecked Sendable {
    private let url: URL
    private let maximumBytes: Int
    private let options: NSFileCoordinator.ReadingOptions
    private let coordinator = NSFileCoordinator(filePresenter: nil)
    private let cancellation = ReaderImportCopyCancellation()
    init(url: URL, maximumBytes: Int, options: NSFileCoordinator.ReadingOptions) {
        self.url = url; self.maximumBytes = maximumBytes; self.options = options
    }
    func cancel() { cancellation.cancel(); coordinator.cancel() }

    func run() throws -> Data {
        guard url.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
        try cancellation.check()
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var result: Result<Data, Error>?
        coordinator.coordinate(readingItemAt: url, options: options, error: &coordinationError) { readable in
            result = Result { try self.readDescriptor(readable) }
        }
        try cancellation.check()
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }

    private func readDescriptor(_ readable: URL) throws -> Data {
        try cancellation.check()
        let fd = open(readable.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { Darwin.close(fd) }
        let before = try regularStat(fd)
        guard before.st_size >= 0, before.st_size <= Int64(maximumBytes) else {
            throw CocoaError(.fileReadTooLarge)
        }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        var data = Data()
        data.reserveCapacity(Int(before.st_size))
        while data.count < Int(before.st_size) {
            try cancellation.check()
            let count = min(1024 * 1024, Int(before.st_size) - data.count)
            guard let chunk = try handle.read(upToCount: count), !chunk.isEmpty else {
                throw CocoaError(.fileReadUnknown)
            }
            data.append(chunk)
        }
        try cancellation.check()
        guard (try handle.read(upToCount: 1))?.isEmpty != false,
              sameSnapshot(before, try regularStat(fd)) else { throw CocoaError(.fileReadUnknown) }
        return data
    }

    private func regularStat(_ fd: Int32) throws -> stat {
        var value = stat()
        guard fstat(fd, &value) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        guard (value.st_mode & S_IFMT) == S_IFREG else { throw CocoaError(.fileReadUnknown) }
        return value
    }
    private func sameSnapshot(_ a: stat, _ b: stat) -> Bool {
        a.st_dev == b.st_dev && a.st_ino == b.st_ino && a.st_size == b.st_size &&
        a.st_mtimespec.tv_sec == b.st_mtimespec.tv_sec && a.st_mtimespec.tv_nsec == b.st_mtimespec.tv_nsec &&
        a.st_ctimespec.tv_sec == b.st_ctimespec.tv_sec && a.st_ctimespec.tv_nsec == b.st_ctimespec.tv_nsec
    }
}
