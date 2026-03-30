import Foundation
import ReaderCoreModels

public struct StructuredErrorLog: Codable, Equatable, Sendable {
    public var id: String
    public var timestamp: Date
    public var errorCode: ReaderErrorCode
    public var failureType: FailureType?
    public var stage: String?
    public var ruleField: String?
    public var targetUrl: String?
    public var sampleId: String?
    public var message: String
    public var context: [String: String]

    public init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        errorCode: ReaderErrorCode,
        failureType: FailureType? = nil,
        stage: String? = nil,
        ruleField: String? = nil,
        targetUrl: String? = nil,
        sampleId: String? = nil,
        message: String,
        context: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.errorCode = errorCode
        self.failureType = failureType
        self.stage = stage
        self.ruleField = ruleField
        self.targetUrl = targetUrl
        self.sampleId = sampleId
        self.message = message
        self.context = context
    }

    public static func from(
        _ error: ReaderError,
        stage: String? = nil,
        ruleField: String? = nil,
        targetUrl: String? = nil,
        sampleId: String? = nil
    ) -> StructuredErrorLog {
        StructuredErrorLog(
            errorCode: error.code,
            failureType: error.failure?.type,
            stage: stage,
            ruleField: ruleField,
            targetUrl: targetUrl,
            sampleId: sampleId ?? error.failure?.sampleId,
            message: error.message,
            context: error.context
        )
    }
}

public protocol ErrorLogger: Sendable {
    func log(_ errorLog: StructuredErrorLog) async
    func getErrors(since: Date?) async -> [StructuredErrorLog]
    func clear() async
}

public final class InMemoryErrorLogger: ErrorLogger, @unchecked Sendable {
    private var logs: [StructuredErrorLog] = []
    private let lock = NSLock()
    private let maxCapacity: Int

    public init(maxCapacity: Int = 1000) {
        self.maxCapacity = maxCapacity
    }

    public func log(_ errorLog: StructuredErrorLog) async {
        lock.lock()
        defer { lock.unlock() }

        logs.append(errorLog)
        if logs.count > maxCapacity {
            logs.removeFirst(logs.count - maxCapacity)
        }
    }

    public func getErrors(since: Date?) async -> [StructuredErrorLog] {
        lock.lock()
        defer { lock.unlock() }

        if let since = since {
            return logs.filter { $0.timestamp >= since }
        }
        return Array(logs)
    }

    public func clear() async {
        lock.lock()
        defer { lock.unlock() }
        logs.removeAll()
    }
}
