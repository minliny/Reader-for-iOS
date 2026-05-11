import Foundation
import os.log

public protocol AppLoggerProtocol: Sendable {
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

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
