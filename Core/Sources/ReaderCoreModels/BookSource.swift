import Foundation
import ReaderCoreFoundation

public struct BookSource: Codable, Equatable, Sendable {
    public var id: String?
    public var bookSourceName: String
    public var bookSourceUrl: String?
    public var bookSourceGroup: String?
    public var bookSourceType: Int?
    public var bookUrlPattern: String?
    public var customOrder: Int?
    public var searchUrl: String?
    public var exploreUrl: String?
    public var ruleSearch: String?
    public var ruleBookInfo: String?
    public var ruleToc: String?
    public var ruleContent: String?
    public var enabled: Bool
    public var enabledExplore: Bool
    public var header: [String: String]
    public var loginUrl: String?
    public var loginUi: String?
    public var enabledCookieJar: Bool
    public var compatibility: CompatibilityMark?
    public var unknownFields: [String: JSONValue]

    public init(
        id: String? = nil,
        bookSourceName: String,
        bookSourceUrl: String? = nil,
        bookSourceGroup: String? = nil,
        bookSourceType: Int? = nil,
        bookUrlPattern: String? = nil,
        customOrder: Int? = nil,
        searchUrl: String? = nil,
        exploreUrl: String? = nil,
        ruleSearch: String? = nil,
        ruleBookInfo: String? = nil,
        ruleToc: String? = nil,
        ruleContent: String? = nil,
        enabled: Bool = true,
        enabledExplore: Bool = false,
        header: [String: String] = [:],
        loginUrl: String? = nil,
        loginUi: String? = nil,
        enabledCookieJar: Bool = false,
        compatibility: CompatibilityMark? = nil,
        unknownFields: [String: JSONValue] = [:]
    ) {
        self.id = id
        self.bookSourceName = bookSourceName
        self.bookSourceUrl = bookSourceUrl
        self.bookSourceGroup = bookSourceGroup
        self.bookSourceType = bookSourceType
        self.bookUrlPattern = bookUrlPattern
        self.customOrder = customOrder
        self.searchUrl = searchUrl
        self.exploreUrl = exploreUrl
        self.ruleSearch = ruleSearch
        self.ruleBookInfo = ruleBookInfo
        self.ruleToc = ruleToc
        self.ruleContent = ruleContent
        self.enabled = enabled
        self.enabledExplore = enabledExplore
        self.header = header
        self.loginUrl = loginUrl
        self.loginUi = loginUi
        self.enabledCookieJar = enabledCookieJar
        self.compatibility = compatibility
        self.unknownFields = unknownFields
    }

    public init(from decoder: Decoder) throws {
        let dynamic = try decoder.container(keyedBy: DynamicCodingKey.self)
        let all = try dynamic.decode([String: JSONValue].self)

        id = try dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("bookSourceId"))
        bookSourceName = (try dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("bookSourceName"))) ?? ""
        bookSourceUrl = try dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("bookSourceUrl"))
        bookSourceGroup = try dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("bookSourceGroup"))
        bookSourceType = try dynamic.decodeIfPresent(Int.self, forKey: DynamicCodingKey("bookSourceType"))
        bookUrlPattern = try dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("bookUrlPattern"))
        customOrder = try dynamic.decodeIfPresent(Int.self, forKey: DynamicCodingKey("customOrder"))
        searchUrl = try dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("searchUrl"))
        exploreUrl = try dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("exploreUrl"))
        ruleSearch = try dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("ruleSearch"))
        ruleBookInfo = try dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("ruleBookInfo"))
        ruleToc = try dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("ruleToc"))
        ruleContent = try dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("ruleContent"))
        enabled = (try dynamic.decodeIfPresent(Bool.self, forKey: DynamicCodingKey("enabled"))) ?? true
        enabledExplore = (try dynamic.decodeIfPresent(Bool.self, forKey: DynamicCodingKey("enabledExplore"))) ?? false
        header = (try dynamic.decodeIfPresent([String: String].self, forKey: DynamicCodingKey("header"))) ?? [:]
        loginUrl = try dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("loginUrl"))
        loginUi = try dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("loginUi"))
        enabledCookieJar = (try dynamic.decodeIfPresent(Bool.self, forKey: DynamicCodingKey("enabledCookieJar"))) ?? false
        compatibility = try dynamic.decodeIfPresent(CompatibilityMark.self, forKey: DynamicCodingKey("compatibility"))

        let knownKeys = Set([
            "bookSourceId",
            "bookSourceName",
            "bookSourceUrl",
            "bookSourceGroup",
            "bookSourceType",
            "bookUrlPattern",
            "customOrder",
            "searchUrl",
            "exploreUrl",
            "ruleSearch",
            "ruleBookInfo",
            "ruleToc",
            "ruleContent",
            "enabled",
            "enabledExplore",
            "header",
            "loginUrl",
            "loginUi",
            "enabledCookieJar",
            "compatibility"
        ])
        unknownFields = all.filter { !knownKeys.contains($0.key) }
    }

    public func encode(to encoder: Encoder) throws {
        var dynamic = encoder.container(keyedBy: DynamicCodingKey.self)
        try dynamic.encode(id, forKey: DynamicCodingKey("bookSourceId"))
        try dynamic.encode(bookSourceName, forKey: DynamicCodingKey("bookSourceName"))
        try dynamic.encodeIfPresent(bookSourceUrl, forKey: DynamicCodingKey("bookSourceUrl"))
        try dynamic.encodeIfPresent(bookSourceGroup, forKey: DynamicCodingKey("bookSourceGroup"))
        try dynamic.encodeIfPresent(bookSourceType, forKey: DynamicCodingKey("bookSourceType"))
        try dynamic.encodeIfPresent(bookUrlPattern, forKey: DynamicCodingKey("bookUrlPattern"))
        try dynamic.encodeIfPresent(customOrder, forKey: DynamicCodingKey("customOrder"))
        try dynamic.encodeIfPresent(searchUrl, forKey: DynamicCodingKey("searchUrl"))
        try dynamic.encodeIfPresent(exploreUrl, forKey: DynamicCodingKey("exploreUrl"))
        try dynamic.encodeIfPresent(ruleSearch, forKey: DynamicCodingKey("ruleSearch"))
        try dynamic.encodeIfPresent(ruleBookInfo, forKey: DynamicCodingKey("ruleBookInfo"))
        try dynamic.encodeIfPresent(ruleToc, forKey: DynamicCodingKey("ruleToc"))
        try dynamic.encodeIfPresent(ruleContent, forKey: DynamicCodingKey("ruleContent"))
        try dynamic.encode(enabled, forKey: DynamicCodingKey("enabled"))
        try dynamic.encode(enabledExplore, forKey: DynamicCodingKey("enabledExplore"))
        try dynamic.encode(header, forKey: DynamicCodingKey("header"))
        try dynamic.encodeIfPresent(loginUrl, forKey: DynamicCodingKey("loginUrl"))
        try dynamic.encodeIfPresent(loginUi, forKey: DynamicCodingKey("loginUi"))
        try dynamic.encode(enabledCookieJar, forKey: DynamicCodingKey("enabledCookieJar"))
        try dynamic.encodeIfPresent(compatibility, forKey: DynamicCodingKey("compatibility"))
        for (key, value) in unknownFields {
            try dynamic.encode(value, forKey: DynamicCodingKey(key))
        }
    }
}

public struct DynamicCodingKey: CodingKey, Hashable {
    public var stringValue: String
    public var intValue: Int?

    public init(_ string: String) {
        self.stringValue = string
        self.intValue = nil
    }

    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    public init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
