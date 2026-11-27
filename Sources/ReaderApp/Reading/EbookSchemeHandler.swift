import Foundation
import ReaderHost
import UniformTypeIdentifiers
import WebKit

@MainActor
final class EbookSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "reader-ebook"
    static let host = "renderer"
    static let shell = URL(string: "\(scheme)://\(host)/shell.html")!

    private let shellHTML: Data
    private var source: (documentId: String, book: RetainedSource)?
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    init(shellHTML: Data) { self.shellHTML = shellHTML }

    func authorize(_ source: RetainedSource, documentId: String) {
        retire()
        self.source = (documentId, source)
    }

    func retire() {
        source = nil
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url, url.scheme == Self.scheme,
              url.host == Self.host, url.user == nil, url.password == nil, url.port == nil,
              url.query == nil, url.fragment == nil else {
            urlSchemeTask.didFailWithError(URLError(.unsupportedURL))
            return
        }
        if url == Self.shell {
            deliver(shellHTML, mime: "text/html", url: url, task: urlSchemeTask)
            return
        }
        guard let source,
              let encoded = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath,
              let path = encoded.removingPercentEncoding else {
            urlSchemeTask.didFailWithError(URLError(.noPermissionsToReadFile))
            return
        }
        let scope = "/archive/\(source.documentId)/"
        guard path.hasPrefix(scope) else {
            urlSchemeTask.didFailWithError(URLError(.noPermissionsToReadFile))
            return
        }
        let entry = String(path.dropFirst(scope.count))
        let mime = Self.admittedMIME(for: entry)
        guard let mime, RetainedSource.isArchivePath(entry) else {
            urlSchemeTask.didFailWithError(URLError(.noPermissionsToReadFile))
            return
        }
        let id = ObjectIdentifier(urlSchemeTask)
        tasks[id] = Task {
            let result = await Task.detached {
                Result { try source.book.readEntry(entry) }
            }.value
            guard tasks.removeValue(forKey: id) != nil else { return }
            switch result {
            case .success(let data): deliver(data, mime: mime, url: url, task: urlSchemeTask)
            case .failure(let error): urlSchemeTask.didFailWithError(error)
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        tasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask))?.cancel()
    }

    private func deliver(_ bytes: Data, mime: String, url: URL, task: any WKURLSchemeTask) {
        task.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: bytes.count,
                                    textEncodingName: mime == "text/html" ? "utf-8" : nil))
        task.didReceive(bytes)
        task.didFinish()
    }

    private static func admittedMIME(for path: String) -> String? {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        if ext == "css" { return "text/css" }
        if ext == "woff2" { return "font/woff2" }
        if ext == "woff" { return "font/woff" }
        if ext == "ttf" { return "font/ttf" }
        if ext == "otf" { return "font/otf" }
        let allowedImages = ["png", "jpg", "jpeg", "webp", "gif", "avif"]
        guard allowedImages.contains(ext) else { return nil }
        return UTType(filenameExtension: ext)?.preferredMIMEType
    }
}
