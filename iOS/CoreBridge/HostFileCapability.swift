// CoreBridge
//
// HostFileCapability — UI/reducer-initiated `file.read/write/delete` and
// `storage.path` requests.
//
// Bridges the contract `HostRequest` to `FileManager`. App-sandbox-relative
// paths (`documents:/foo.txt`, `cache:/bar.bin`, `temp:/baz`) are resolved to
// absolute URLs before read/write/delete. Absolute paths are rejected unless
// they fall under the app's container (fail-closed — no arbitrary filesystem
// access from UI requests).
//
// Tier: simulatorProof — the app sandbox exists on both sim and device, but
// `FileManager.default.temporaryDirectory` / `urls(for:in:)` are unavailable
// on macOS `swift build` for the iOS app target. On macOS, storage.path
// returns a temp directory and read/write/delete operate on /tmp-style paths
// so the handler is testable cross-platform; the iOS container resolution
// kicks in via `#if canImport(UIKit)`.
//
// Payload contract:
// - `.file_read`:    `{ path: String, encoding?: "utf8"|"base64" }`
//                    → `{ data: String, encoding: String, size: Int }`
// - `.file_write`:   `{ path: String, data: String, encoding?: "utf8"|"base64" }`
//                    → `{ written: true, size: Int }`
// - `.file_delete`:  `{ path: String }` → `{ deleted: true }`
// - `.storage_path`: `{ kind: "documents"|"cache"|"temp" }`
//                    → `{ path: String, kind: String }`

import Foundation
import ReaderUIContract

#if canImport(UIKit)
import UIKit
#endif

public struct HostFileCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [
        .file_read, .file_write, .file_delete, .storage_path,
    ]
    public let tier: HostCapabilityTier = .simulatorProof

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        switch request.type {
        case .file_read:
            return handleRead(request.payload)
        case .file_write:
            return handleWrite(request.payload)
        case .file_delete:
            return handleDelete(request.payload)
        case .storage_path:
            return handleStoragePath(request.payload)
        default:
            return .failure(.notImplemented(request.type, "HostFileCapability does not handle \(request.type.rawValue)"))
        }
    }

    // MARK: - file.read

    private func handleRead(_ payload: [String: AnyCodable]) -> HostCapabilityOutcome {
        guard let path = payload["path"]?.value as? String, !path.isEmpty else {
            return .failure(.invalidParams("file.read requires non-empty `path`"))
        }
        let encoding = (payload["encoding"]?.value as? String) ?? "utf8"
        guard let url = resolveURL(for: path) else {
            return .failure(.invalidParams("file.read path is not a valid app-sandbox path: \(path)"))
        }
        guard fileManager.fileExists(atPath: url.path) else {
            return .failure(.invalidParams("file.read: file does not exist at \(url.path)"))
        }
        do {
            let data = try Data(contentsOf: url)
            let encoded: String
            switch encoding {
            case "base64":
                encoded = data.base64EncodedString()
            case "utf8":
                encoded = String(data: data, encoding: .utf8) ?? ""
            default:
                return .failure(.invalidParams("file.read encoding must be \"utf8\" or \"base64\", got \(encoding)"))
            }
            return .success([
                "data": AnyCodable(encoded),
                "encoding": AnyCodable(encoding),
                "size": AnyCodable(data.count),
            ])
        } catch {
            return .failure(.underlying("file.read failed: \(error.localizedDescription)"))
        }
    }

    // MARK: - file.write

    private func handleWrite(_ payload: [String: AnyCodable]) -> HostCapabilityOutcome {
        guard let path = payload["path"]?.value as? String, !path.isEmpty else {
            return .failure(.invalidParams("file.write requires non-empty `path`"))
        }
        guard let dataString = payload["data"]?.value as? String else {
            return .failure(.invalidParams("file.write requires `data` string"))
        }
        let encoding = (payload["encoding"]?.value as? String) ?? "utf8"
        guard let url = resolveURL(for: path) else {
            return .failure(.invalidParams("file.write path is not a valid app-sandbox path: \(path)"))
        }
        let data: Data
        switch encoding {
        case "base64":
            guard let decoded = Data(base64Encoded: dataString) else {
                return .failure(.invalidParams("file.write: `data` is not valid base64"))
            }
            data = decoded
        case "utf8":
            data = Data(dataString.utf8)
        default:
            return .failure(.invalidParams("file.write encoding must be \"utf8\" or \"base64\", got \(encoding)"))
        }
        do {
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            return .success([
                "written": AnyCodable(true),
                "size": AnyCodable(data.count),
            ])
        } catch {
            return .failure(.underlying("file.write failed: \(error.localizedDescription)"))
        }
    }

    // MARK: - file.delete

    private func handleDelete(_ payload: [String: AnyCodable]) -> HostCapabilityOutcome {
        guard let path = payload["path"]?.value as? String, !path.isEmpty else {
            return .failure(.invalidParams("file.delete requires non-empty `path`"))
        }
        guard let url = resolveURL(for: path) else {
            return .failure(.invalidParams("file.delete path is not a valid app-sandbox path: \(path)"))
        }
        guard fileManager.fileExists(atPath: url.path) else {
            // Idempotent — deleting a non-existent file is success.
            return .success(["deleted": AnyCodable(true), "existed": AnyCodable(false)])
        }
        do {
            try fileManager.removeItem(at: url)
            return .success(["deleted": AnyCodable(true), "existed": AnyCodable(true)])
        } catch {
            return .failure(.underlying("file.delete failed: \(error.localizedDescription)"))
        }
    }

    // MARK: - storage.path

    private func handleStoragePath(_ payload: [String: AnyCodable]) -> HostCapabilityOutcome {
        let kind = (payload["kind"]?.value as? String) ?? "documents"
        let url: URL
        switch kind {
        case "documents":
            url = Self.documentsURL()
        case "cache":
            url = Self.cacheURL()
        case "temp":
            url = Self.tempURL()
        default:
            return .failure(.invalidParams("storage.path kind must be \"documents\"/\"cache\"/\"temp\", got \(kind)"))
        }
        return .success([
            "path": AnyCodable(url.path),
            "kind": AnyCodable(kind),
        ])
    }

    // MARK: - Path resolution

    /// Resolve an app-sandbox-relative path (`documents:/foo`, `cache:/bar`,
    /// `temp:/baz`) to an absolute URL. Absolute paths are rejected unless
    /// they fall under the app's container — fail-closed to prevent UI requests
    /// from touching arbitrary filesystem locations.
    private func resolveURL(for path: String) -> URL? {
        if path.hasPrefix("documents:/") {
            let relative = String(path.dropFirst("documents:/".count))
            return Self.documentsURL().appendingPathComponent(relative)
        }
        if path.hasPrefix("cache:/") {
            let relative = String(path.dropFirst("cache:/".count))
            return Self.cacheURL().appendingPathComponent(relative)
        }
        if path.hasPrefix("temp:/") {
            let relative = String(path.dropFirst("temp:/".count))
            return Self.tempURL().appendingPathComponent(relative)
        }
        // Allow absolute paths only if they fall under one of the app
        // containers (defense in depth — the UI should never send an absolute
        // path, but a misbehaving caller should not escape the sandbox).
        let expanded = (path as NSString).expandingTildeInPath
        let containers = [Self.documentsURL(), Self.cacheURL(), Self.tempURL()]
        for container in containers {
            if expanded.hasPrefix(container.path) {
                return URL(fileURLWithPath: expanded)
            }
        }
        return nil
    }

    private static func documentsURL() -> URL {
        #if canImport(UIKit)
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        #else
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ReaderAppDocuments", isDirectory: true)
        #endif
    }

    private static func cacheURL() -> URL {
        #if canImport(UIKit)
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        #else
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ReaderAppCache", isDirectory: true)
        #endif
    }

    private static func tempURL() -> URL {
        FileManager.default.temporaryDirectory
    }
}
