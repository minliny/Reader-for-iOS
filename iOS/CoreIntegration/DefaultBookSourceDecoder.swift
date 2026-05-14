import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

public enum BookSourceValidationError: Error, LocalizedError {
    case missingName
    case missingURL
    case bothMissing

    public var errorDescription: String? {
        switch self {
        case .missingName: return "Book source is missing 'bookSourceName'"
        case .missingURL: return "Book source is missing 'bookSourceUrl'"
        case .bothMissing: return "Book source is missing both name and URL"
        }
    }
}

public final class DefaultBookSourceDecoder: BookSourceDecoder {
    public init() {}

    public func decodeBookSource(from data: Data) throws -> BookSource {
        let decoder = JSONDecoder()
        let source = try decoder.decode(BookSource.self, from: data)

        let name = source.bookSourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = (source.bookSourceUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hasName = !name.isEmpty
        let hasURL = !url.isEmpty

        switch (hasName, hasURL) {
        case (false, false): throw BookSourceValidationError.bothMissing
        case (false, true):  throw BookSourceValidationError.missingName
        case (true, false):  throw BookSourceValidationError.missingURL
        case (true, true):   break
        }

        return source
    }
}
