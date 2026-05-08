import Foundation
import ReaderCoreModels
import ReaderPlatformAdapters

#if DEBUG && canImport(WebKit)

import SwiftUI
import Combine

// ============================================================
// WebViewRuntimeAutorunView.swift
// iOS Simulator WebView Render Test Harness - Autorun Mode
//
// 授权范围: AUTHORIZE_SINGLE_WEBVIEW_URL_RENDER_TEST
// 约束: maxNavigationCount=1, requireHttps=true, allowExternalNavigation=false
//       allowPopup=false, allowDownload=false
// 禁止: 批量请求, 递归, 翻页, 批量章节, WAF 绕过, 自动重试
// ============================================================

/// WebView Runtime Harness View - Autorun 模式
/// 自动执行模式：启动后立即执行 WebView 渲染，不显示 UI
public struct WebViewRuntimeAutorunView: View {
    @StateObject private var viewModel: WebViewRuntimeAutorunViewModel

    public init(configuration: WebViewRuntimeAutorunConfiguration) {
        _viewModel = StateObject(wrappedValue: WebViewRuntimeAutorunViewModel(configuration: configuration))
    }

    public var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView("执行 WebView 渲染...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("执行失败")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("执行成功")
                        .font(.headline)
                        .foregroundColor(.green)

                    Group {
                        LabeledContent("Final URL") {
                            Text(viewModel.finalUrl.isEmpty ? "-" : viewModel.finalUrl)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        LabeledContent("Navigation Count") {
                            Text("\(viewModel.navigationCount)")
                        }
                        LabeledContent("HTML Size") {
                            Text("\(viewModel.renderedHtmlSize) bytes")
                        }
                        LabeledContent("Page Title") {
                            Text(viewModel.pageTitle.isEmpty ? "-" : viewModel.pageTitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        LabeledContent("Execution Time") {
                            Text("\(viewModel.executionTimeMs) ms")
                        }
                    }
                    .font(.caption)

                    if !viewModel.savedSnapshotPath.isEmpty {
                        Divider()
                        LabeledContent("Snapshot") {
                            Text(viewModel.savedSnapshotPath)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .task {
            // 延迟启动，确保 SwiftUI view 完全稳定
            try? await Task.sleep(nanoseconds: 500_000_000)
            await viewModel.executeRender()
        }
    }
}

// MARK: - ViewModel

/// Autorun 专用 ViewModel
@MainActor
public final class WebViewRuntimeAutorunViewModel: ObservableObject {
    // ===== 状态 =====
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var finalUrl: String = ""
    @Published public var navigationCount: Int = 0
    @Published public var renderedHtmlSize: Int = 0
    @Published public var pageTitle: String = ""
    @Published public var executionTimeMs: Int = 0
    @Published public var savedSnapshotPath: String = ""

    // ===== 配置 =====
    private let configuration: WebViewRuntimeAutorunConfiguration
    private let adapter: WKWebViewRuntimeAdapter

    // ===== 结果路径 =====
    private var runId: String = ""
    private var outputDirectory: String = ""

    public init(configuration: WebViewRuntimeAutorunConfiguration) {
        self.configuration = configuration
        self.runId = UUID().uuidString

        // 创建默认 output directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "/tmp")
        self.outputDirectory = configuration.outputDirectory.isEmpty
            ? documentsPath.appendingPathComponent("WebViewHarnessRuns/\(runId)").path
            : "\(configuration.outputDirectory)/\(runId)"

        // 创建 adapter（严格配置）
        self.adapter = WKWebViewRuntimeAdapter.strict(
            rootDirectory: Self.defaultSnapshotDirectory(),
            allowedHosts: [configuration.allowedHost],
            requireHttps: configuration.requireHttps
        )
    }

    public func executeRender() async {
        guard !isLoading else { return }

        // 创建输出目录
        try? FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

        // 写入初始状态
        writeRunStatus(status: "running", errorMessage: nil)

        isLoading = true
        let startTime = Date()

        // 构造请求
        let request = createAuthorizedRequest()

        // 执行 - adapter.execute 现在是 @MainActor
        let result = await adapter.execute(request: request)

        let executionTime = Int(Date().timeIntervalSince(startTime) * 1000)
        self.executionTimeMs = executionTime

        // 处理结果
        if result.success {
            self.finalUrl = result.finalUrl
            self.renderedHtmlSize = result.html.utf8.count
            self.pageTitle = result.title ?? ""
            self.navigationCount = 1

            if let snapshotId = result.snapshotId {
                self.savedSnapshotPath = "Snapshot: \(snapshotId)"
            }

            // 写入结果文件
            writeResultFiles(result: result)

            // 更新状态
            writeRunStatus(status: "success", errorMessage: nil)
        } else {
            self.errorMessage = result.errorMessage ?? "Unknown error"

            // 写入失败状态
            writeRunStatus(status: "failed", errorMessage: result.errorMessage ?? "Unknown error")
        }

        isLoading = false

        // 如果配置了 exitAfterRun，延迟退出
        if configuration.exitAfterRun {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            exit(0)
        }
    }

    private func createAuthorizedRequest() -> RuntimeWebViewRequest {
        RuntimeWebViewRequest(
            sourceId: configuration.sourceId,
            sourceName: configuration.sourceName,
            url: configuration.url,
            stage: configuration.stage,
            waitPolicy: .standard(),
            scriptPolicy: .default(),
            snapshotRequired: configuration.requireSnapshot,
            snapshotPrefix: "autorun_\(runId.prefix(8))",
            securityRiskLevel: .high,
            authorization: RuntimeAuthorization(
                authorizationId: "autorun_\(runId)",
                sourceId: configuration.sourceId,
                sourceName: configuration.sourceName,
                grantedBy: "autorun",
                grantedAt: Date(),
                expiresAt: Date().addingTimeInterval(3600),
                allowedHosts: [configuration.allowedHost],
                capabilityAllowlist: [.webView],
                revoked: false
            )
        )
    }

    private func writeResultFiles(result: RuntimeWebViewResult) {
        // webview_result.json
        let resultJson = """
        {
            "status": "\(result.success ? "success" : "failed")",
            "finalUrl": "\(result.finalUrl.replacingOccurrences(of: "\"", with: "\\\""))",
            "navigationCount": \(navigationCount),
            "renderedHtmlSize": \(renderedHtmlSize),
            "pageTitle": "\(result.title ?? "".replacingOccurrences(of: "\"", with: "\\\""))",
            "executionTimeMs": \(executionTimeMs),
            "snapshotId": "\(result.snapshotId ?? "".replacingOccurrences(of: "\"", with: "\\\""))",
            "snapshotFilePath": "\(result.snapshotFilePath ?? "".replacingOccurrences(of: "\"", with: "\\\""))",
            "runId": "\(runId)"
        }
        """
        let resultPath = "\(outputDirectory)/webview_result.json"
        try? resultJson.write(toFile: resultPath, atomically: true, encoding: .utf8)

        // rendered_detail.html
        let htmlPath = "\(outputDirectory)/rendered_detail.html"
        try? result.html.write(toFile: htmlPath, atomically: true, encoding: .utf8)

        // snapshot metadata
        let snapshotMeta = """
        {
            "snapshotId": "\(result.snapshotId ?? "")",
            "snapshotFilePath": "\(result.snapshotFilePath ?? "")",
            "runId": "\(runId)"
        }
        """
        let snapshotMetaPath = "\(outputDirectory)/webview_snapshot_metadata.json"
        try? snapshotMeta.write(toFile: snapshotMetaPath, atomically: true, encoding: .utf8)
    }

    private func writeRunStatus(status: String, errorMessage: String?) {
        let statusJson: String
        if let error = errorMessage {
            statusJson = """
            {
                "status": "\(status)",
                "runId": "\(runId)",
                "finalUrl": "\(finalUrl.replacingOccurrences(of: "\"", with: "\\\""))",
                "navigationCount": \(navigationCount),
                "renderedHtmlSize": \(renderedHtmlSize),
                "snapshotPath": "\(savedSnapshotPath.replacingOccurrences(of: "\"", with: "\\\"其事"))",
                "errorMessage": "\(error.replacingOccurrences(of: "\"", with: "\\\""))",
                "startedAt": "\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(-Double(executionTimeMs) / 1000)))",
                "finishedAt": "\(ISO8601DateFormatter().string(from: Date()))"
            }
            """
        } else {
            statusJson = """
            {
                "status": "\(status)",
                "runId": "\(runId)",
                "finalUrl": "\(finalUrl.replacingOccurrences(of: "\"", with: "\\\""))",
                "navigationCount": \(navigationCount),
                "renderedHtmlSize": \(renderedHtmlSize),
                "snapshotPath": "\(savedSnapshotPath.replacingOccurrences(of: "\"", with: "\\\""))",
                "startedAt": "\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(-Double(executionTimeMs) / 1000)))",
                "finishedAt": "\(ISO8601DateFormatter().string(from: Date()))"
            }
            """
        }

        let statusPath = "\(outputDirectory)/webview_run_status.json"
        try? statusJson.write(toFile: statusPath, atomically: true, encoding: .utf8)
    }

    private static func defaultSnapshotDirectory() -> String {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths.first?.appendingPathComponent("WebViewHarness/Snapshots").path ?? "/tmp/webview_harness"
    }
}

#endif
