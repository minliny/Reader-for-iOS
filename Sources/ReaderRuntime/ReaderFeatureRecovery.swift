import Foundation

public struct ReaderFeatureRecoveryResult: Hashable, Sendable {
    public enum Status: String, Codable, Hashable, Sendable {
        case completed, continued, rejected, pending, refreshRequired
    }
    public let operationID: String
    public let status: Status
    public let message: String?
    public var remaining: Bool { status == .pending || status == .refreshRequired }
    public init(operationID: String, status: Status, message: String? = nil) {
        self.operationID = operationID; self.status = status; self.message = message
    }
}
