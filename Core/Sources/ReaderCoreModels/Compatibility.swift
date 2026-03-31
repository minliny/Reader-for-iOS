import Foundation

public enum CompatibilityLevel: String, Codable, CaseIterable, Sendable {
    case A
    case B
    case C
    case D
}

public enum CompatibilityStatus: String, Codable, Sendable {
    case pass
    case degraded
    case fail
}

public struct CompatibilityMark: Codable, Equatable, Sendable {
    public var level: CompatibilityLevel
    public var status: CompatibilityStatus
    public var notes: String?

    public init(level: CompatibilityLevel, status: CompatibilityStatus, notes: String? = nil) {
        self.level = level
        self.status = status
        self.notes = notes
    }
}
