import Foundation

/// Phase 4D: SnapshotStore skeleton — 本地快照路径管理，不保存真实网络内容
public final class SnapshotStore: Sendable {
    public let snapshotRoot: URL

    public init(snapshotRoot: URL) {
        self.snapshotRoot = snapshotRoot
    }

    // MARK: - Path Construction

    public func makeSnapshotPath(candidateId: String, operation: String) -> String {
        let safeCandidate = sanitize(candidateId)
        let safeOperation = sanitize(operation)
        return "\(safeCandidate)/\(safeOperation).json"
    }

    public func metadataPath(for snapshotRelativePath: String) -> String {
        snapshotRelativePath + ".metadata.json"
    }

    // MARK: - Safety

    /// 检查路径是否在 snapshotRoot 内，防止 `../` 路径穿越
    public func validatePathInsideSnapshotRoot(_ relativePath: String) -> Bool {
        // 拒绝包含 `..` 的路径
        if relativePath.contains("..") { return false }
        // 拒绝绝对路径
        if relativePath.hasPrefix("/") { return false }
        // 解析完整路径
        let fullPath = snapshotRoot.appendingPathComponent(relativePath).standardized.path
        let rootPath = snapshotRoot.standardized.path
        return fullPath.hasPrefix(rootPath)
    }

    /// 检查快照路径是否存在元数据占位文件
    public func hasSnapshot(_ relativePath: String) -> Bool {
        guard validatePathInsideSnapshotRoot(relativePath) else { return false }
        let metaURL = snapshotRoot.appendingPathComponent(metadataPath(for: relativePath))
        return FileManager.default.fileExists(atPath: metaURL.path)
    }

    // MARK: - Placeholder

    /// 写入本地占位元数据（不保存真实网络内容）
    public func saveSnapshotPlaceholder(candidateId: String, operation: String, host: String) -> Result<String, Error> {
        let relativePath = makeSnapshotPath(candidateId: candidateId, operation: operation)
        guard validatePathInsideSnapshotRoot(relativePath) else {
            return .failure(SnapshotStoreError.invalidPath(relativePath))
        }

        let metaURL = snapshotRoot.appendingPathComponent(metadataPath(for: relativePath))
        let metaDir = metaURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: metaDir, withIntermediateDirectories: true)

        let metadata: [String: String] = [
            "candidateId": candidateId,
            "operation": operation,
            "host": host,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "placeholder": "true",
            "note": "真实快照内容由 Phase 4D-next 首次 fetch 后写入"
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
            try data.write(to: metaURL, options: .atomic)
            return .success(relativePath)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Helpers

    private func sanitize(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return input.unicodeScalars.filter { allowed.contains($0) }.map { String($0) }.joined()
    }
}

public enum SnapshotStoreError: Error, LocalizedError {
    case invalidPath(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            return "Snapshot path 不安全或越界：\(path)"
        }
    }
}
