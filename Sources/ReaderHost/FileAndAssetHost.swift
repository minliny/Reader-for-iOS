import CryptoKit
import Foundation
import ReaderCoreBridge

public enum FileAndAssetFailure: Error, Sendable {
    case unauthorized, invalidEntry, corruptSource, fileTooLarge
}

public struct StagedSource: Sendable {
    public let path: URL
    public let name: String
    public let sha256: String
}

public struct RetainedSource: Sendable {
    public let path: URL
    public let sha256: String

    public func readEntry(_ entry: String, maxBytes: Int = 8 * 1024 * 1024) throws -> Data {
        guard Self.isArchivePath(entry), (1...(8 * 1024 * 1024)).contains(maxBytes) else {
            throw FileAndAssetFailure.invalidEntry
        }
        return try CoreFileABI.epubEntry(path, path: entry, maxBytes: maxBytes)
    }

    public static func isArchivePath(_ path: String) -> Bool {
        !path.isEmpty && !path.contains("\\") && !path.contains("\0") && !path.contains(":")
            && path.split(separator: "/", omittingEmptySubsequences: false)
                .allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }
}

/// Files rooted in application support. A selected external URL is readable
/// only while its security scope is open.
public actor FileAndAssetHost {
    private let root: URL
    private let sandboxRoots: [URL]
    private static let maximumFileLength: Int64 = 256 * 1024 * 1024

    public init(root: URL, sandboxRoots: [URL]) {
        self.root = root
        self.sandboxRoots = sandboxRoots.map { $0.resolvingSymlinksInPath().standardizedFileURL }
    }

    public func stageSelectedFile(_ file: URL) throws -> StagedSource {
        guard file.isFileURL else { throw FileAndAssetFailure.unauthorized }
        #if os(iOS)
        let scoped = file.startAccessingSecurityScopedResource()
        defer { if scoped { file.stopAccessingSecurityScopedResource() } }
        #else
        let scoped = false
        #endif
        let resolved = file.resolvingSymlinksInPath().standardizedFileURL
        guard scoped || sandboxRoots.contains(where: { resolved.path.hasPrefix($0.path + "/") }) else {
            throw FileAndAssetFailure.unauthorized
        }
        guard try resolved.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw FileAndAssetFailure.unauthorized
        }
        let directory = try folder("staging")
        let temporary = directory.appendingPathComponent(UUID().uuidString.lowercased())
        do {
            let hash = try Self.hashAndCopy(resolved, to: temporary)
            return StagedSource(path: temporary, name: file.lastPathComponent, sha256: hash)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    public func retain(_ staged: StagedSource) throws -> RetainedSource {
        let directory = try folder("originals")
        let target = directory.appendingPathComponent(staged.sha256 + ".source")
        if !FileManager.default.fileExists(atPath: target.path) {
            // These folders belong to the same sandbox volume. Using an
            // exclusive hard link leaves the original journal input intact.
            do {
                try FileManager.default.linkItem(at: staged.path, to: target)
            } catch CocoaError.fileWriteFileExists {
                // A concurrent operation already retained this content.
            }
        }
        guard try Self.hashAndCopy(target) == staged.sha256 else { throw FileAndAssetFailure.corruptSource }
        return RetainedSource(path: target, sha256: staged.sha256)
    }

    public func retained(sha256 hash: String) throws -> RetainedSource {
        guard hash.utf8.count == 64, hash.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            throw FileAndAssetFailure.unauthorized
        }
        let path = try folder("originals").appendingPathComponent(hash + ".source")
        guard try Self.hashAndCopy(path) == hash else { throw FileAndAssetFailure.corruptSource }
        return RetainedSource(path: path, sha256: hash)
    }

    public func discard(_ staged: StagedSource) throws {
        try FileManager.default.removeItem(at: staged.path)
    }

    private func folder(_ name: String) throws -> URL {
        let path = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }

    private static func hashAndCopy(_ source: URL, to destination: URL? = nil) throws -> String {
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        let output: FileHandle?
        if let destination {
            guard FileManager.default.createFile(atPath: destination.path, contents: nil,
                                                 attributes: [.posixPermissions: 0o600]) else {
                throw FileAndAssetFailure.unauthorized
            }
            output = try FileHandle(forWritingTo: destination)
        } else {
            output = nil
        }
        defer { try? output?.close() }
        var length: Int64 = 0
        var hash = SHA256()
        while let bytes = try input.read(upToCount: 128 * 1024), !bytes.isEmpty {
            length += Int64(bytes.count)
            guard length <= maximumFileLength else { throw FileAndAssetFailure.fileTooLarge }
            hash.update(data: bytes)
            try output?.write(contentsOf: bytes)
        }
        try output?.synchronize()
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
