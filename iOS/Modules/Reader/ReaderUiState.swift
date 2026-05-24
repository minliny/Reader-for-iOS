import Foundation

/// 跨平台全局 UI 状态（12 类）
/// 真源：Reader-Core docs/cross-platform-ui/CROSS_PLATFORM_STATE_MATRIX.md §1
public enum ReaderUiState: Equatable {
    case idle
    case loading
    case empty
    case error(message: String, retryable: Bool = true)
    case offline
    case disabled(reason: String)
    case permissionRequired(permission: String)
    case localFileError(message: String)
    case networkSourceError(sourceId: String, message: String)
    case webDavAuthError
    case syncConflict(localVersion: String, remoteVersion: String)
    case importSuccess(targetId: String)
    case importFailure(message: String)
}
