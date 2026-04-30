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
