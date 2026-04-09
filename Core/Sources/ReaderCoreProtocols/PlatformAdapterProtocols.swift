import Foundation
import ReaderCoreModels

public protocol HTTPAdapterProtocol: HTTPClient {}

public protocol StorageAdapterProtocol: Sendable {
    func read(key: String) async throws -> Data?
    func write(_ data: Data, key: String) async throws
    func remove(key: String) async throws
}

public protocol SchedulerAdapterProtocol: Sendable {
    func schedule(taskId: String, executeAfter interval: TimeInterval) async throws
    func cancel(taskId: String) async throws
}

public enum LogLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
}

public protocol LoggingAdapterProtocol: Sendable {
    func log(_ level: LogLevel, message: String, metadata: [String: String]) async
}

public protocol ReaderErrorLoggingProtocol: Sendable {
    func log(_ errorLog: StructuredErrorLog) async
    func getErrors(since: Date?) async -> [StructuredErrorLog]
    func clear() async
}

public struct CoreAdapterDependencies: Sendable {
    public let http: any HTTPAdapterProtocol
    public let storage: (any StorageAdapterProtocol)?
    public let scheduler: (any SchedulerAdapterProtocol)?
    public let logger: (any LoggingAdapterProtocol)?

    public init(
        http: any HTTPAdapterProtocol,
        storage: (any StorageAdapterProtocol)? = nil,
        scheduler: (any SchedulerAdapterProtocol)? = nil,
        logger: (any LoggingAdapterProtocol)? = nil
    ) {
        self.http = http
        self.storage = storage
        self.scheduler = scheduler
        self.logger = logger
    }
}
