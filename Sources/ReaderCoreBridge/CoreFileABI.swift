import Foundation
import ReaderCore

public struct LibraryProbe: Decodable, Sendable {
    public struct Observation: Decodable, Sendable {
        public struct Layout: Decodable, Sendable {
            public let layoutId: String
        }

        public let freshStorage: Bool
        public let layout: Layout?
    }

    public let observation: Observation
}

public enum CoreFileABI {
    public static func probe(_ directory: URL) throws -> LibraryProbe {
        let path = Array(directory.path.utf8)
        var out = rc_owned_bytes_t()
        try CoreTransport.check(rc_storage_probe_v1(path, path.count, &out), "rc_storage_probe_v1")
        defer { rc_owned_bytes_free(&out) }
        guard let data = out.data else { throw CoreBridgeFailure.invalidEvent }
        return try JSONDecoder().decode(LibraryProbe.self, from: Data(bytes: data, count: out.length))
    }

    public static func epubEntry(_ archive: URL, path: String, maxBytes: Int) throws -> Data {
        let archiveBytes = Array(archive.path.utf8)
        let entryBytes = Array(path.utf8)
        var out = rc_owned_bytes_t()
        try CoreTransport.check(
            rc_epub_read_entry(archiveBytes, archiveBytes.count, entryBytes, entryBytes.count, maxBytes, &out),
            "rc_epub_read_entry"
        )
        defer { rc_owned_bytes_free(&out) }
        guard let data = out.data else { throw CoreBridgeFailure.invalidEvent }
        return Data(bytes: data, count: out.length)
    }
}
