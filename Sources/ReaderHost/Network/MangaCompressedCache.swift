import CryptoKit
import Foundation
import ReaderCoreBridge

/// Owns physical bytes only. The caller proves the exact chapter publication
/// in Core before offering retained art as an offline reading resource.
public actor MangaCompressedCache {
    private struct Proof: Codable {
        let bytes: Int
        let sha256: String
        let chunks: Int
        let inspection: M3MangaResourceInspectData
    }

    private let directory: URL
    private let budget = 256 * 1_048_576

    init(directory: URL) { self.directory = directory }

    public func store(file: MangaResourceFile, inspection: M3MangaResourceInspectData,
                      chapter: M3MangaChapterIdentity, manifest: String, resource: String) throws {
        let (bytes, proof) = try paths(chapter: chapter, manifest: manifest, resource: resource)
        let fm = FileManager.default
        if let retained = try? record(chapter: chapter, manifest: manifest, resource: resource),
           retained.file.sha256 == file.sha256 { return }
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let used = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
            .reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        guard used <= budget - file.bytes else {
            throw NetworkHostFailure.invalid("Manga offline cache exceeds its storage budget")
        }
        let data = try Data(contentsOf: file.url, options: .mappedIfSafe)
        guard data.count == file.bytes, Self.sha(data) == file.sha256 else {
            throw NetworkHostFailure.invalid("Manga offline bytes no longer match the transfer receipt")
        }
        try data.write(to: bytes, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        let receipt = Proof(bytes: file.bytes, sha256: file.sha256, chunks: file.chunks, inspection: inspection)
        try JSONEncoder().encode(receipt).write(to: proof, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    public func record(chapter: M3MangaChapterIdentity, manifest: String, resource: String)
    throws -> (file: MangaResourceFile, inspection: M3MangaResourceInspectData) {
        let (bytes, proof) = try paths(chapter: chapter, manifest: manifest, resource: resource)
        let receipt = try JSONDecoder().decode(Proof.self, from: Data(contentsOf: proof))
        guard (1...budget).contains(receipt.bytes),
              try bytes.resourceValues(forKeys: [.fileSizeKey]).fileSize == receipt.bytes,
              Self.sha(try Data(contentsOf: bytes, options: .mappedIfSafe)) == receipt.sha256 else {
            throw NetworkHostFailure.invalid("Manga offline file failed its receipt")
        }
        return (.init(url: bytes, bytes: receipt.bytes, sha256: receipt.sha256, chunks: receipt.chunks), receipt.inspection)
    }

    private func paths(chapter: M3MangaChapterIdentity, manifest: String, resource: String) throws -> (URL, URL) {
        let data = try JSONEncoder().encode([chapter.sourceId, chapter.bookId, chapter.chapterId, manifest, resource])
        let name = Self.sha(data)
        return (directory.appendingPathComponent(name + ".image"), directory.appendingPathComponent(name + ".json"))
    }

    private static func sha(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
