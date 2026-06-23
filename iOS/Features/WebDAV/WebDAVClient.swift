import Foundation

public struct WebDAVConnectionSummary: Equatable, Sendable {
    public var statusCode: Int
    public var method: String
    public var serverURL: String

    public init(statusCode: Int, method: String, serverURL: String) {
        self.statusCode = statusCode
        self.method = method
        self.serverURL = serverURL
    }
}

public struct WebDAVUploadSummary: Equatable, Sendable {
    public var statusCode: Int
    public var remoteURL: URL
    public var byteCount: Int

    public init(statusCode: Int, remoteURL: URL, byteCount: Int) {
        self.statusCode = statusCode
        self.remoteURL = remoteURL
        self.byteCount = byteCount
    }
}

public struct WebDAVDownloadSummary: Equatable, Sendable {
    public var statusCode: Int
    public var remoteURL: URL
    public var data: Data

    public var byteCount: Int { data.count }

    public init(statusCode: Int, remoteURL: URL, data: Data) {
        self.statusCode = statusCode
        self.remoteURL = remoteURL
        self.data = data
    }
}

public struct WebDAVDeleteSummary: Equatable, Sendable {
    public var statusCode: Int
    public var remoteURL: URL

    public init(statusCode: Int, remoteURL: URL) {
        self.statusCode = statusCode
        self.remoteURL = remoteURL
    }
}

public struct WebDAVRemoteBackup: Equatable, Identifiable, Sendable {
    public var id: String { remoteURL.absoluteString }
    public var remoteURL: URL
    public var filename: String
    public var byteCount: Int64?
    public var modifiedAt: Date?
    public var etag: String?

    public init(
        remoteURL: URL,
        filename: String,
        byteCount: Int64? = nil,
        modifiedAt: Date? = nil,
        etag: String? = nil
    ) {
        self.remoteURL = remoteURL
        self.filename = filename
        self.byteCount = byteCount
        self.modifiedAt = modifiedAt
        self.etag = etag
    }
}

public enum WebDAVClientError: Error, Equatable, LocalizedError, Sendable {
    case invalidURL(String)
    case missingCredentials
    case unreadableBackup(URL)
    case emptyBackupResponse(URL)
    case invalidWebDAVResponse
    case unexpectedHTTPStatus(Int)
    case missingHTTPResponse

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return "Invalid WebDAV URL: \(value)"
        case .missingCredentials:
            return "WebDAV username and password are required."
        case .unreadableBackup(let url):
            return "Backup file is unreadable: \(url.lastPathComponent)"
        case .emptyBackupResponse(let url):
            return "Downloaded backup is empty: \(url.lastPathComponent)"
        case .invalidWebDAVResponse:
            return "WebDAV server returned an invalid directory listing."
        case .unexpectedHTTPStatus(let status):
            return "WebDAV request failed with HTTP \(status)."
        case .missingHTTPResponse:
            return "WebDAV request did not return an HTTP response."
        }
    }
}

public protocol WebDAVConnectionTesting: Sendable {
    func testConnection(credentials: WebDAVCredentials) async throws -> WebDAVConnectionSummary
}

public protocol WebDAVBackupUploading: Sendable {
    func uploadBackup(fileURL: URL, credentials: WebDAVCredentials) async throws -> WebDAVUploadSummary
}

public protocol WebDAVBackupDownloading: Sendable {
    func downloadBackup(remoteURL: URL, credentials: WebDAVCredentials) async throws -> WebDAVDownloadSummary
}

public protocol WebDAVBackupListing: Sendable {
    func listBackups(credentials: WebDAVCredentials) async throws -> [WebDAVRemoteBackup]
}

public protocol WebDAVBackupDeleting: Sendable {
    func deleteBackup(remoteURL: URL, credentials: WebDAVCredentials) async throws -> WebDAVDeleteSummary
}

public typealias WebDAVClienting = WebDAVConnectionTesting & WebDAVBackupUploading & WebDAVBackupDownloading & WebDAVBackupListing & WebDAVBackupDeleting

public struct URLSessionWebDAVClient: WebDAVClienting {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func testConnection(credentials: WebDAVCredentials) async throws -> WebDAVConnectionSummary {
        let url = try validatedURL(credentials.serverURL)
        try validateCredentials(credentials)

        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("0", forHTTPHeaderField: "Depth")
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(authorizationHeader(credentials), forHTTPHeaderField: "Authorization")
        request.httpBody = Data("""
        <?xml version="1.0" encoding="utf-8"?>
        <propfind xmlns="DAV:"><prop><resourcetype/></prop></propfind>
        """.utf8)

        let (_, response) = try await session.data(for: request)
        let status = try httpStatus(from: response)
        guard (200..<300).contains(status) || status == 207 else {
            throw WebDAVClientError.unexpectedHTTPStatus(status)
        }
        return WebDAVConnectionSummary(statusCode: status, method: "PROPFIND", serverURL: url.absoluteString)
    }

    public func uploadBackup(fileURL: URL, credentials: WebDAVCredentials) async throws -> WebDAVUploadSummary {
        let baseURL = try validatedURL(credentials.serverURL)
        try validateCredentials(credentials)
        guard let data = try? Data(contentsOf: fileURL) else {
            throw WebDAVClientError.unreadableBackup(fileURL)
        }

        let remoteURL = baseURL.appendingPathComponent(fileURL.lastPathComponent)
        var request = URLRequest(url: remoteURL)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        request.setValue(authorizationHeader(credentials), forHTTPHeaderField: "Authorization")
        request.httpBody = data

        let (_, response) = try await session.data(for: request)
        let status = try httpStatus(from: response)
        guard (200..<300).contains(status) else {
            throw WebDAVClientError.unexpectedHTTPStatus(status)
        }
        return WebDAVUploadSummary(statusCode: status, remoteURL: remoteURL, byteCount: data.count)
    }

    public func downloadBackup(remoteURL: URL, credentials: WebDAVCredentials) async throws -> WebDAVDownloadSummary {
        try validateCredentials(credentials)
        guard let scheme = remoteURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw WebDAVClientError.invalidURL(remoteURL.absoluteString)
        }

        var request = URLRequest(url: remoteURL)
        request.httpMethod = "GET"
        request.setValue(authorizationHeader(credentials), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        let status = try httpStatus(from: response)
        guard (200..<300).contains(status) else {
            throw WebDAVClientError.unexpectedHTTPStatus(status)
        }
        guard !data.isEmpty else {
            throw WebDAVClientError.emptyBackupResponse(remoteURL)
        }
        return WebDAVDownloadSummary(statusCode: status, remoteURL: remoteURL, data: data)
    }

    public func listBackups(credentials: WebDAVCredentials) async throws -> [WebDAVRemoteBackup] {
        let baseURL = try validatedURL(credentials.serverURL)
        try validateCredentials(credentials)

        var request = URLRequest(url: baseURL)
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(authorizationHeader(credentials), forHTTPHeaderField: "Authorization")
        request.httpBody = Data("""
        <?xml version="1.0" encoding="utf-8"?>
        <propfind xmlns="DAV:">
          <prop>
            <getcontentlength/>
            <getlastmodified/>
            <getetag/>
            <resourcetype/>
          </prop>
        </propfind>
        """.utf8)

        let (data, response) = try await session.data(for: request)
        let status = try httpStatus(from: response)
        guard status == 207 || (200..<300).contains(status) else {
            throw WebDAVClientError.unexpectedHTTPStatus(status)
        }

        let resources = try WebDAVMultistatusParser.parse(data)
        let requestedPath = normalizedPath(baseURL.path)
        return resources.compactMap { resource -> WebDAVRemoteBackup? in
            guard !resource.isCollection else { return nil }
            guard let remoteURL = absoluteResourceURL(from: resource.href, baseURL: baseURL) else { return nil }
            guard normalizedPath(remoteURL.path) != requestedPath else { return nil }
            let filename = remoteURL.lastPathComponent
            guard filename.lowercased().hasSuffix(".readerbackup.json") else { return nil }
            return WebDAVRemoteBackup(
                remoteURL: remoteURL,
                filename: filename,
                byteCount: resource.contentLength,
                modifiedAt: resource.lastModified,
                etag: resource.etag
            )
        }
        .sorted(by: sortRemoteBackups)
    }

    public func deleteBackup(remoteURL: URL, credentials: WebDAVCredentials) async throws -> WebDAVDeleteSummary {
        try validateCredentials(credentials)
        guard let scheme = remoteURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw WebDAVClientError.invalidURL(remoteURL.absoluteString)
        }

        var request = URLRequest(url: remoteURL)
        request.httpMethod = "DELETE"
        request.setValue(authorizationHeader(credentials), forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        let status = try httpStatus(from: response)
        guard (200..<300).contains(status) else {
            throw WebDAVClientError.unexpectedHTTPStatus(status)
        }
        return WebDAVDeleteSummary(statusCode: status, remoteURL: remoteURL)
    }

    private func validatedURL(_ value: String) throws -> URL {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            throw WebDAVClientError.invalidURL(value)
        }
        return url
    }

    private func validateCredentials(_ credentials: WebDAVCredentials) throws {
        if credentials.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            credentials.password.isEmpty {
            throw WebDAVClientError.missingCredentials
        }
    }

    private func authorizationHeader(_ credentials: WebDAVCredentials) -> String {
        let token = "\(credentials.username):\(credentials.password)"
            .data(using: .utf8)?
            .base64EncodedString() ?? ""
        return "Basic \(token)"
    }

    private func httpStatus(from response: URLResponse) throws -> Int {
        guard let http = response as? HTTPURLResponse else {
            throw WebDAVClientError.missingHTTPResponse
        }
        return http.statusCode
    }

    private func absoluteResourceURL(from href: String, baseURL: URL) -> URL? {
        let decoded = href.removingPercentEncoding ?? href
        if let absolute = URL(string: decoded), absolute.scheme != nil {
            return absolute
        }
        if decoded.hasPrefix("/"),
           var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) {
            components.path = decoded
            components.query = nil
            components.fragment = nil
            return components.url
        }
        return URL(string: decoded, relativeTo: baseURL)?.absoluteURL
    }

    private func normalizedPath(_ path: String) -> String {
        guard path.count > 1 else { return path }
        return path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    private func sortRemoteBackups(_ lhs: WebDAVRemoteBackup, _ rhs: WebDAVRemoteBackup) -> Bool {
        if lhs.modifiedAt != rhs.modifiedAt {
            switch (lhs.modifiedAt, rhs.modifiedAt) {
            case let (left?, right?):
                return left > right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                break
            }
        }
        return lhs.filename > rhs.filename
    }
}

private struct WebDAVResource {
    var href = ""
    var contentLength: Int64?
    var lastModified: Date?
    var etag: String?
    var isCollection = false
}

private final class WebDAVMultistatusParser: NSObject, XMLParserDelegate {
    private(set) var resources: [WebDAVResource] = []
    private var currentResource: WebDAVResource?
    private var activeElement: String?
    private var textBuffer = ""

    static func parse(_ data: Data) throws -> [WebDAVResource] {
        let delegate = WebDAVMultistatusParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw WebDAVClientError.invalidWebDAVResponse
        }
        return delegate.resources
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let element = normalizedElementName(elementName, qName: qName)
        switch element {
        case "response":
            currentResource = WebDAVResource()
        case "href", "getcontentlength", "getlastmodified", "getetag":
            guard currentResource != nil else { return }
            activeElement = element
            textBuffer = ""
        case "collection":
            currentResource?.isCollection = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard activeElement != nil else { return }
        textBuffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let element = normalizedElementName(elementName, qName: qName)
        let value = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if activeElement == element {
            switch element {
            case "href":
                currentResource?.href = value
            case "getcontentlength":
                currentResource?.contentLength = Int64(value)
            case "getlastmodified":
                currentResource?.lastModified = parseHTTPDate(value)
            case "getetag":
                currentResource?.etag = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            default:
                break
            }
            activeElement = nil
            textBuffer = ""
        }

        if element == "response", let resource = currentResource {
            resources.append(resource)
            currentResource = nil
        }
    }

    private func normalizedElementName(_ elementName: String, qName: String?) -> String {
        let raw = qName ?? elementName
        return raw.split(separator: ":").last.map(String.init) ?? raw
    }

    private func parseHTTPDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in [
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "EEEE, dd-MMM-yy HH:mm:ss zzz",
            "EEE MMM d HH:mm:ss yyyy"
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return ISO8601DateFormatter().date(from: value)
    }
}
