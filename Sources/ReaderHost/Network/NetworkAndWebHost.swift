import Foundation
import ReaderCoreBridge
import WebKit

@MainActor
public final class NetworkAndWebHost: CoreHost {
    private let system = SystemSurfaceHost()
    private let cookies: SourceCookieStore
    private let mediaDirectory: URL
    private var logins: [String: SourceLoginSession] = [:]
    private var loginGenerations: [String: UUID] = [:]

    public nonisolated let capabilities: [ReaderHostCapability] = [
        .hostSmokeEcho, .timeNow, .httpExecute, .cookieGet, .cookieSet, .webviewEvaluateJavaScript, .mediaDownload,
    ]
    public nonisolated let protocolExtensions = ["http.execute.timeoutMs.v1"]

    public init(directory: URL) throws {
        guard directory.isFileURL else {
            throw NetworkHostFailure(code: .permissionDenied, phase: .storage, message: "Host storage requires a file URL")
        }
        cookies = SourceCookieStore(directory: directory.appendingPathComponent("cookies", isDirectory: true))
        mediaDirectory = directory.appendingPathComponent("media", isDirectory: true)
    }

    public func execute(_ request: ReaderHostRequestEvent) async -> CoreHostReply {
        await system.execute(request)
    }

    public func executeNetwork(_ request: CoreNetworkHostRequest, operationId: Int64) async -> CoreHostReply {
        do {
            try Task.checkCancellation()
            switch request {
            case .http(let params):
                return .http(try await fetch(params))
            case .cookieGet(let params):
                return .cookieGet(try await cookies.get(params))
            case .cookieSet(let params):
                return .cookieSet(try await cookies.set(params))
            case .webView(let params):
                return .webView(try await evaluate(params))
            case .media(let params):
                return .media(try await media(params))
            }
        } catch {
            return NetworkHostFailure.classified(error).reply(operationId: operationId)
        }
    }

    public func discardUnsent(_ reply: CoreHostReply) async {
        if case .media(let receipt) = reply, let path = receipt.tempPath {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    public func fetch(_ params: M2HostHttpRequest) async throws -> M2HostHttpResponse {
        let request = try URLSessionNetwork.request(params)
        let useCookies = params.usePlatformCookieJar ?? (params.session != nil)
        let profile = try useCookies ? cookies.profile(session: params.session?.id, url: request.url) : nil
        try await profile?.pullFromWeb()
        let exchange = try await URLSessionNetwork.execute(request, params: params, jar: profile?.jar)
        if let profile {
            for cookie in URLSessionNetwork.cookies(from: exchange.redirects + [exchange.response]) {
                try await profile.write(cookie)
            }
        }
        if exchange.response.statusCode >= 400 { throw NetworkHostFailure.status(exchange.response.statusCode) }
        return URLSessionNetwork.receipt(exchange, params: params)
    }

    public func beginLogin(sourceId: String, url: URL, timeout: Duration = .seconds(60)) async throws -> SourceLoginSession {
        let target = try hostHTTPURL(url.absoluteString)
        revokeLogin(sourceId: sourceId)
        let generation = UUID()
        loginGenerations[sourceId] = generation
        do {
            let profile = try cookies.profile(session: sourceId)
            let site = try await profile.beginWebSession()
            guard loginGenerations[sourceId] == generation else { throw CancellationError() }
            try Task.checkCancellation()
            let session = SourceLoginSession(sourceId: sourceId, site: site)
            logins[sourceId] = session
            session.start(url: target, timeout: timeout)
            return session
        } catch {
            if loginGenerations[sourceId] == generation { revokeLogin(sourceId: sourceId) }
            throw error
        }
    }

    public func revokeLogin(sourceId: String) {
        loginGenerations.removeValue(forKey: sourceId)
        logins.removeValue(forKey: sourceId)?.revoke()
    }

    public func clearLogin(sourceId: String, baseURL: URL) async throws {
        _ = try hostHTTPURL(baseURL.absoluteString)
        revokeLogin(sourceId: sourceId)
        try await cookies.clear(sourceId: sourceId)
    }

    public func synchronizeLogin(sourceId: String) async throws {
        let profile = try cookies.profile(session: sourceId)
        try await profile.pullFromWeb()
    }

    private func evaluate(_ params: M2HostWebViewEvaluateJavaScriptRequest) async throws -> M2HostWebViewEvaluateJavaScriptResponse {
        var scopedCookies: [HTTPCookie] = []
        if let profileId = params.profileId {
            let profile = try cookies.profile(session: profileId)
            try await profile.pullFromWeb()
            scopedCookies = profile.jar.cookies ?? []
        }
        return try await BackgroundWebEvaluator(params: params).run(cookies: scopedCookies)
    }

    private func media(_ params: M2HostMediaDownloadRequest) async throws -> M2HostMediaDownloadResponse {
        let profile = try params.sessionId.map { try cookies.profile(session: $0) }
        try await profile?.pullFromWeb()
        let exchange = try await MediaDownload.execute(params, directory: mediaDirectory, jar: profile?.jar)
        do {
            try Task.checkCancellation()
            if let profile {
                for cookie in URLSessionNetwork.cookies(from: exchange.responses) {
                    try await profile.write(cookie)
                }
            }
        } catch {
            if let path = exchange.receipt.tempPath { try? FileManager.default.removeItem(atPath: path) }
            throw error
        }
        return exchange.receipt
    }
}
