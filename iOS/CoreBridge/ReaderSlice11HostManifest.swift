import CoreFoundation
import Foundation
import ReaderCoreNativeAdapter

public enum ReaderSlice11HostManifestError: Error, Equatable, LocalizedError {
    case rejected(String)

    public var errorDescription: String? {
        switch self {
        case .rejected(let message): return "[SLICE11_HOST_MANIFEST_REJECTED] \(message)"
        }
    }
}

/// Exact Core-initiated Host surface advertised by the iOS app.
///
/// Explicit lane declaration is essential: HTTP + cookie capabilities would
/// otherwise make Core infer `anti_bot`, even though captcha/human challenge
/// return and WKWebView cookie handoff are not contracted. iOS therefore
/// advertises only lanes that execute without inventing those missing pieces.
public enum ReaderSlice11HostManifest {
    public static var capabilities: [String] {
        var values = [
            "host.smoke.echo",
            "http.execute",
            "cookie.get",
            "cookie.set",
            "file.read",
            "file.write",
            "cache.get",
            "cache.put",
            "log.emit",
            "time.now",
            "system.info",
            "persistence.get",
            "persistence.put",
            "media.download",
        ]
        #if canImport(WebKit) && canImport(UIKit)
        values.append("webview.evaluateJavaScript")
        #endif
        return values
    }

    public static var lanes: [String] {
        var values = ["login_cookie", "media_download"]
        #if canImport(WebKit) && canImport(UIKit)
        values.append("webview_render")
        #endif
        return values
    }

    public static func params(platformVersion: String? = nil) -> [String: Any] {
        var value: [String: Any] = [
            "capabilities": capabilities,
            "lanes": lanes,
            "platform": "ios",
        ]
        if let platformVersion, !platformVersion.isEmpty {
            value["platformVersion"] = platformVersion
        }
        return value
    }

    public static func apply(
        to runtime: ReaderCoreNativeRuntime,
        platformVersion: String? = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    ) throws {
        let event = try runtime.request(
            method: "runtime.setHostCapabilities",
            requestId: RustCoreServiceSupport.allocateRequestID(),
            params: params(platformVersion: platformVersion),
            timeout: 5
        )
        guard let data = event.data,
              let applied = data["applied"] as? NSNumber,
              CFGetTypeID(applied) == CFBooleanGetTypeID(),
              applied.boolValue else {
            throw ReaderSlice11HostManifestError.rejected("Core did not acknowledge the manifest")
        }
    }
}
