import Foundation

public struct SourceIdentity: Codable, Equatable, Hashable {
    public let id: String
    public let name: String?
    public let baseURL: String?

    public static let unknown = SourceIdentity(id: "unknown", name: nil, baseURL: nil)

    public init(id: String, name: String?, baseURL: String?) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
    }
}

public enum SourceIdentityFactory {
    public static func from(searchResult: SearchResultItem) -> SourceIdentity {
        return SourceIdentity(
            id: searchResult.detailURL,
            name: nil,
            baseURL: nil
        )
    }

    public static func fallback(name: String?, url: String?, rawJSON: String?) -> String {
        if let url = url, !url.isEmpty {
            return url
        }
        if let name = name, !name.isEmpty {
            return "source_\(name)"
        }
        if let rawJSON = rawJSON, !rawJSON.isEmpty {
            return "source_\(rawJSON.hashValue)"
        }
        return "unknown"
    }
}