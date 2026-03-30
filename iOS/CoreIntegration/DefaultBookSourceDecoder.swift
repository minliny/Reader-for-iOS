import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

public final class DefaultBookSourceDecoder: BookSourceDecoder {
    public init() {}

    public func decodeBookSource(from data: Data) throws -> BookSource {
        let decoder = JSONDecoder()
        return try decoder.decode(BookSource.self, from: data)
    }
}
