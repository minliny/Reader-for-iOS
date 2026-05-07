import Foundation
import ReaderCoreModels
import ReaderPlatformAdapters
#if canImport(WebKit)
import WebKit
#endif

// ============================================================
// WebViewRuntimeHarnessViewModel.swift
// iOS Simulator WebView Render Test Harness
//
// 授权范围: AUTHORIZE_SINGLE_WEBVIEW_URL_RENDER_TEST
// 约束: maxNavigationCount=1, requireHttps=true, allowExternalNavigation=false
//       allowPopup=false, allowDownload=false
// 禁止: 批量请求, 递归, 翻页, 批量章节, WAF 绕过, 自动重试
// ============================================================

#if DEBUG && canImport(WebKit)

import SwiftUI
import Combine

/// WebView Runtime Harness ViewModel
/// 用于在 iOS Simulator 中测试 WKWebViewRuntimeAdapter
@MainActor
public final class WebViewRuntimeHarnessViewModel: ObservableObject {

    // ===== 状态 =====
    @Published public var isLoading: Bool = false
    @Published public var statusMessage: String = "Ready"
    @Published public var errorMessage: String?

    @Published public var finalUrl: String = ""
    @Published public var navigationCount: Int = 0
    @Published public var renderedHtmlSize: Int = 0
    @Published public var pageTitle: String = ""
    @Published public var executionTimeMs: Int = 0

    @Published public var warnings: [String] = []
    @Published public var auditEvents: [String] = []

    @Published public var savedSnapshotPath: String?

    // ===== 配置 =====
    private let adapter: WKWebViewRuntimeAdapter
    private let configuration: HarnessConfiguration

    // ===== 授权信息 =====
    public let authorizedUrl: String
    public let allowedHost: String

    // MARK: - Configuration

    public struct HarnessConfiguration: Sendable {
        public let maxNavigationCount: Int
        public let requireHttps: Bool
        public let allowExternalNavigation: Bool
        public let allowPopup: Bool
        public let allowDownload: Bool
        public let requireSnapshot: Bool

        public static let qianfanxsAuthorized = HarnessConfiguration(
            maxNavigationCount: 1,
            requireHttps: true,
            allowExternalNavigation: false,
            allowPopup: false,
            allowDownload: false,
            requireSnapshot: true
        )
    }

    // MARK: - 初始化

    public init(
        url: String = "https://www.qianfanxs.com/9/9556",
        allowedHost: String = "www.qianfanxs.com",
        configuration: HarnessConfiguration = .qianfanxsAuthorized
    ) {
        self.authorizedUrl = url
        self.allowedHost = allowedHost
        self.configuration = configuration

        // 创建 adapter（严格配置）
        self.adapter = WKWebViewRuntimeAdapter.strict(
            rootDirectory: Self.defaultSnapshotDirectory(),
            allowedHosts: [allowedHost],
            requireHttps: configuration.requireHttps
        )
    }

    // MARK: - 执行 WebView 渲染

    public func executeRender() async {
        guard !isLoading else { return }

        resetState()
        isLoading = true
        statusMessage = "Starting WebView render..."

        let startTime = Date()

        // 构造请求
        let request = createAuthorizedRequest()

        statusMessage = "Executing WebView request..."

        // 执行
        let result = await adapter.execute(request: request)

        let executionTime = Int(Date().timeIntervalSince(startTime) * 1000)
        self.executionTimeMs = executionTime

        // 处理结果
        if result.success {
            self.finalUrl = result.finalUrl
            self.renderedHtmlSize = result.html.utf8.count
            self.pageTitle = result.title ?? ""
            self.navigationCount = 1 // 单次请求

            if let snapshotId = result.snapshotId {
                self.savedSnapshotPath = "Snapshot: \(snapshotId)"
            }

            self.warnings = result.warnings
            self.auditEvents = result.auditEvents.map { "[\($0.eventType.rawValue)] \($0.reason)" }

            self.statusMessage = "Success"
        } else {
            self.errorMessage = result.errorMessage ?? "Unknown error"
            self.statusMessage = "Failed: \(result.errorType?.rawValue ?? "unknown")"
        }

        isLoading = false
    }

    // MARK: - 创建授权请求

    private func createAuthorizedRequest() -> RuntimeWebViewRequest {
        RuntimeWebViewRequest(
            sourceId: "qianfanxs_user_provided",
            sourceName: "千帆小说",
            url: authorizedUrl,
            stage: .detail,
            waitPolicy: .standard(),
            scriptPolicy: .default(),
            snapshotRequired: configuration.requireSnapshot,
            snapshotPrefix: "qianfanxs_webview",
            securityRiskLevel: .high,
            authorization: RuntimeAuthorization(
                authorizationId: "auth_webview_single_url_test",
                capabilityAllowlist: [.webView],
                allowedHosts: [allowedHost],
                grantedBy: "user",
                grantedAt: Date(),
                expiresAt: Date().addingTimeInterval(3600),
                revoked: false
            )
        )
    }

    // MARK: - 状态重置

    private func resetState() {
        errorMessage = nil
        finalUrl = ""
        navigationCount = 0
        renderedHtmlSize = 0
        pageTitle = ""
        executionTimeMs = 0
        warnings = []
        auditEvents = []
        savedSnapshotPath = nil
    }

    // MARK: - 辅助方法

    private static func defaultSnapshotDirectory() -> String {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths.first?.appendingPathComponent("WebViewHarness/Snapshots").path ?? "/tmp/webview_harness"
    }

    // MARK: - 安全性验证

    public func validateSecurityConstraints() -> [String] {
        var violations: [String] = []

        // 验证 HTTPS
        if configuration.requireHttps && !authorizedUrl.lowercased().hasPrefix("https://") {
            violations.append("URL must use HTTPS")
        }

        // 验证 host
        if let url = URL(string: authorizedUrl), url.host != allowedHost {
            violations.append("URL host must match allowedHost")
        }

        // 验证 navigation count
        if configuration.maxNavigationCount != 1 {
            violations.append("maxNavigationCount must be 1")
        }

        // 验证无外部导航
        if configuration.allowExternalNavigation {
            violations.append("allowExternalNavigation must be false")
        }

        // 验证无 popup
        if configuration.allowPopup {
            violations.append("allowPopup must be false")
        }

        // 验证无下载
        if configuration.allowDownload {
            violations.append("allowDownload must be false")
        }

        return violations
    }
}

#endif