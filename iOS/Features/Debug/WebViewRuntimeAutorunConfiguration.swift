import Foundation
import ReaderCoreModels

#if DEBUG && canImport(WebKit)

/// WebView Runtime Harness Autorun Configuration
/// 解析命令行参数，决定是否进入自动执行模式
public struct WebViewRuntimeAutorunConfiguration: Sendable {
    // ===== 状态 =====
    public let isEnabled: Bool
    public let isValid: Bool
    public let invalidReason: String?

    // ===== 配置 =====
    public let url: String
    public let allowedHost: String
    public let sourceId: String
    public let sourceName: String
    public let stage: RuntimeStage
    public let outputDirectory: String

    // ===== 安全约束 =====
    public let maxNavigationCount: Int
    public let requireHttps: Bool
    public let allowExternalNavigation: Bool
    public let allowPopup: Bool
    public let allowDownload: Bool
    public let requireSnapshot: Bool
    public let requireAudit: Bool
    public let exitAfterRun: Bool
    public let keepRenderedHTML: Bool

    // ===== 默认约束 =====
    public static let defaultMaxNavigationCount = 1
    public static let defaultRequireHttps = true
    public static let defaultAllowExternalNavigation = false
    public static let defaultAllowPopup = false
    public static let defaultAllowDownload = false
    public static let defaultRequireSnapshot = true
    public static let defaultRequireAudit = true

    // ===== 初始化 =====
    private init(
        isEnabled: Bool,
        isValid: Bool,
        invalidReason: String?,
        url: String,
        allowedHost: String,
        sourceId: String,
        sourceName: String,
        stage: RuntimeStage,
        outputDirectory: String,
        maxNavigationCount: Int,
        requireHttps: Bool,
        allowExternalNavigation: Bool,
        allowPopup: Bool,
        allowDownload: Bool,
        requireSnapshot: Bool,
        requireAudit: Bool,
        exitAfterRun: Bool,
        keepRenderedHTML: Bool
    ) {
        self.isEnabled = isEnabled
        self.isValid = isValid
        self.invalidReason = invalidReason
        self.url = url
        self.allowedHost = allowedHost
        self.sourceId = sourceId
        self.sourceName = sourceName
        self.stage = stage
        self.outputDirectory = outputDirectory
        self.maxNavigationCount = maxNavigationCount
        self.requireHttps = requireHttps
        self.allowExternalNavigation = allowExternalNavigation
        self.allowPopup = allowPopup
        self.allowDownload = allowDownload
        self.requireSnapshot = requireSnapshot
        self.requireAudit = requireAudit
        self.exitAfterRun = exitAfterRun
        self.keepRenderedHTML = keepRenderedHTML
    }

    // MARK: - 解析

    /// 从命令行参数解析配置
    public static func parse(_ arguments: [String]) -> WebViewRuntimeAutorunConfiguration {
        // 检查是否启用 autorun
        guard arguments.contains("--webview-harness-autorun") else {
            return disabled()
        }

        // Release 模式下禁用 autorun（仅 DEBUG 有效）
        #if RELEASE
        return invalid(reason: "autorun not supported in Release build")
        #endif

        // 解析参数
        var url: String?
        var allowedHost: String?
        var sourceId = "autorun_user_provided"
        var sourceName = "Autorun"
        var stage: RuntimeStage = .detail
        var outputDirectory = ""
        var maxNavigationCount = Self.defaultMaxNavigationCount
        var requireHttps = Self.defaultRequireHttps
        var allowExternalNavigation = Self.defaultAllowExternalNavigation
        var allowPopup = Self.defaultAllowPopup
        var allowDownload = Self.defaultAllowDownload
        var requireSnapshot = Self.defaultRequireSnapshot
        var requireAudit = Self.defaultRequireAudit
        var exitAfterRun = false
        var keepRenderedHTML = false

        // 解析每个参数
        for (index, arg) in arguments.enumerated() {
            switch arg {
            case "--webview-url":
                if index + 1 < arguments.count {
                    url = arguments[index + 1]
                }
            case "--webview-allowed-host":
                if index + 1 < arguments.count {
                    allowedHost = arguments[index + 1]
                }
            case "--webview-source-id":
                if index + 1 < arguments.count {
                    sourceId = arguments[index + 1]
                }
            case "--webview-source-name":
                if index + 1 < arguments.count {
                    sourceName = arguments[index + 1]
                }
            case "--webview-stage":
                if index + 1 < arguments.count {
                    let stageStr = arguments[index + 1]
                    switch stageStr.lowercased() {
                    case "search": stage = .search
                    case "detail": stage = .detail
                    case "toc": stage = .toc
                    case "content": stage = .content
                    default: break
                    }
                }
            case "--webview-output-dir":
                if index + 1 < arguments.count {
                    outputDirectory = arguments[index + 1]
                }
            case "--webview-max-navigation-count":
                if index + 1 < arguments.count, let count = Int(arguments[index + 1]) {
                    maxNavigationCount = count
                }
            case "--webview-require-https":
                if index + 1 < arguments.count {
                    requireHttps = arguments[index + 1].lowercased() == "true"
                }
            case "--webview-exit-after-run":
                exitAfterRun = true
            case "--webview-keep-rendered-html":
                keepRenderedHTML = true
            default:
                break
            }
        }

        // URL 必须提供
        guard let parsedUrl = url, !parsedUrl.isEmpty else {
            return invalid(reason: "missing required --webview-url")
        }

        // allowedHost 必须提供
        guard let parsedHost = allowedHost, !parsedHost.isEmpty else {
            return invalid(reason: "missing required --webview-allowed-host")
        }

        // 验证 URL 格式
        guard let urlObj = URL(string: parsedUrl) else {
            return invalid(reason: "malformed URL: \(parsedUrl)")
        }

        // 验证 HTTPS
        if requireHttps && !parsedUrl.lowercased().hasPrefix("https://") {
            return invalid(reason: "URL must use HTTPS (requireHttps=true)")
        }

        // 验证 host 匹配
        if let urlHost = urlObj.host, urlHost != parsedHost {
            return invalid(reason: "URL host '\(urlHost)' does not match allowed host '\(parsedHost)'")
        }

        // 验证 host 不为空
        guard urlObj.host != nil else {
            return invalid(reason: "URL must have a valid host")
        }

        // 验证 maxNavigationCount
        if maxNavigationCount > 1 {
            return invalid(reason: "maxNavigationCount must be 1 (no batch requests)")
        }

        return WebViewRuntimeAutorunConfiguration(
            isEnabled: true,
            isValid: true,
            invalidReason: nil,
            url: parsedUrl,
            allowedHost: parsedHost,
            sourceId: sourceId,
            sourceName: sourceName,
            stage: stage,
            outputDirectory: outputDirectory.isEmpty ? defaultOutputDirectory() : outputDirectory,
            maxNavigationCount: maxNavigationCount,
            requireHttps: requireHttps,
            allowExternalNavigation: allowExternalNavigation,
            allowPopup: allowPopup,
            allowDownload: allowDownload,
            requireSnapshot: requireSnapshot,
            requireAudit: requireAudit,
            exitAfterRun: exitAfterRun,
            keepRenderedHTML: keepRenderedHTML
        )
    }

    // MARK: - 工厂方法

    private static func disabled() -> WebViewRuntimeAutorunConfiguration {
        WebViewRuntimeAutorunConfiguration(
            isEnabled: false,
            isValid: true,
            invalidReason: nil,
            url: "",
            allowedHost: "",
            sourceId: "",
            sourceName: "",
            stage: .search,
            outputDirectory: "",
            maxNavigationCount: Self.defaultMaxNavigationCount,
            requireHttps: Self.defaultRequireHttps,
            allowExternalNavigation: Self.defaultAllowExternalNavigation,
            allowPopup: Self.defaultAllowPopup,
            allowDownload: Self.defaultAllowDownload,
            requireSnapshot: Self.defaultRequireSnapshot,
            requireAudit: Self.defaultRequireAudit,
            exitAfterRun: false,
            keepRenderedHTML: false
        )
    }

    private static func invalid(reason: String) -> WebViewRuntimeAutorunConfiguration {
        WebViewRuntimeAutorunConfiguration(
            isEnabled: false,
            isValid: false,
            invalidReason: reason,
            url: "",
            allowedHost: "",
            sourceId: "",
            sourceName: "",
            stage: .search,
            outputDirectory: "",
            maxNavigationCount: Self.defaultMaxNavigationCount,
            requireHttps: Self.defaultRequireHttps,
            allowExternalNavigation: Self.defaultAllowExternalNavigation,
            allowPopup: Self.defaultAllowPopup,
            allowDownload: Self.defaultAllowDownload,
            requireSnapshot: Self.defaultRequireSnapshot,
            requireAudit: Self.defaultRequireAudit,
            exitAfterRun: false,
            keepRenderedHTML: false
        )
    }

    private static func defaultOutputDirectory() -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "/tmp")
        return documentsPath.appendingPathComponent("WebViewHarnessRuns").path
    }
}

// MARK: - 描述

extension WebViewRuntimeAutorunConfiguration: CustomStringConvertible {
    public var description: String {
        if !isEnabled {
            return "WebViewRuntimeAutorunConfiguration: disabled"
        }
        if !isValid {
            return "WebViewRuntimeAutorunConfiguration: invalid - \(invalidReason ?? "unknown")"
        }
        return "WebViewRuntimeAutorunConfiguration: enabled for \(url) (host: \(allowedHost))"
    }
}

#endif
