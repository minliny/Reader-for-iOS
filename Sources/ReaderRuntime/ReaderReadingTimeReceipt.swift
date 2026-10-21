import Foundation

/// Core's one global elapsed-time lineage. It is not a per-book counter and
/// does not imply source/book-ID isolation for the legacy book-name record key.
public struct ReaderReadingTimeHead: Codable, Hashable, Sendable {
    public let operationId: String
    public let sequence: UInt64
    public let deviceId: String
    public let bookName: String
    public let author: String
    public let elapsedMillis: Int64
    public let readAt: Int64
    public let record: ReaderReadingRecord
    public init(operationId: String, sequence: UInt64, deviceId: String, bookName: String, author: String,
                elapsedMillis: Int64, readAt: Int64, record: ReaderReadingRecord) {
        self.operationId = operationId; self.sequence = sequence; self.deviceId = deviceId
        self.bookName = bookName; self.author = author; self.elapsedMillis = elapsedMillis
        self.readAt = readAt; self.record = record
    }
}

extension ReaderLibraryService {
    public func readReadingTimeHead() async throws -> ReaderReadingTimeHead? {
        if let pending = try pendingCoreCommands().first(where: { $0.scope == "reading-time" }) {
            throw ReaderLibraryError.operationPending(pending.id)
        }
        struct Result: Decodable { let receipt: ReaderReadingTimeHead? }
        let result = try decode(Result.self, await coreRead("read-record.accumulate-receipt", [:]))
        guard let receipt = result.receipt else { return nil }
        guard receipt.sequence > 0, receipt.sequence <= 9_007_199_254_740_991,
              receipt.operationId == receipt.deviceId + "/" + String(receipt.sequence),
              receipt.elapsedMillis > 0, receipt.readAt >= 0,
              receipt.record.deviceId == receipt.deviceId, receipt.record.bookName == receipt.bookName else {
            throw ReaderLibraryError.invalidResponse("reading time original head identity")
        }
        return receipt
    }
}
