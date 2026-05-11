import Foundation

public protocol AppLoggerProtocol: Sendable {
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

#if canImport(os)
import os.log

public final class IOSLoggerAdapter: AppLoggerProtocol, Sendable {
    private let logger: Logger

    public init(subsystem: String = "com.reader.app", category: String = "default") {
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    public func debug(_ message: String) {
        logger.debug("\(message)")
    }

    public func info(_ message: String) {
        logger.info("\(message)")
    }

    public func warning(_ message: String) {
        logger.warning("\(message)")
    }

    public func error(_ message: String) {
        logger.error("\(message)")
    }
}

#else

public final class IOSLoggerAdapter: AppLoggerProtocol, Sendable {
    private let category: String

    public init(subsystem: String = "com.reader.app", category: String = "default") {
        self.category = category
    }

    public func debug(_ message: String) {
        print("[DEBUG][\(category)] \(message)")
    }

    public func info(_ message: String) {
        print("[INFO][\(category)] \(message)")
    }

    public func warning(_ message: String) {
        print("[WARN][\(category)] \(message)")
    }

    public func error(_ message: String) {
        print("[ERROR][\(category)] \(message)")
    }
}

#endif
