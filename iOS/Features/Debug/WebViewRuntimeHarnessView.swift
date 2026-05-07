import Foundation
import ReaderCoreModels
import ReaderPlatformAdapters
#if canImport(WebKit)
import WebKit
#endif

// ============================================================
// WebViewRuntimeHarnessView.swift
// iOS Simulator WebView Render Test Harness
//
// 授权范围: AUTHORIZE_SINGLE_WEBVIEW_URL_RENDER_TEST
// 约束: maxNavigationCount=1, requireHttps=true
// 禁止: 批量请求, 递归, 翻页, 批量章节
// ============================================================

#if DEBUG && canImport(WebKit)

import SwiftUI

/// WebView Runtime Harness View
/// 用于在 iOS Simulator 中可视化测试 WKWebViewRuntimeAdapter
public struct WebViewRuntimeHarnessView: View {

    @StateObject private var viewModel: WebViewRuntimeHarnessViewModel

    public init(
        url: String = "https://www.qianfanxs.com/9/9556",
        allowedHost: String = "www.qianfanxs.com"
    ) {
        _viewModel = StateObject(wrappedValue: WebViewRuntimeHarnessViewModel(
            url: url,
            allowedHost: allowedHost
        ))
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // ===== 授权信息 =====
                    authorizationSection

                    Divider()

                    // ===== 安全约束验证 =====
                    securityConstraintsSection

                    Divider()

                    // ===== 执行按钮 =====
                    executeButton

                    Divider()

                    // ===== 状态显示 =====
                    if viewModel.isLoading {
                        loadingSection
                    }

                    if let error = viewModel.errorMessage {
                        errorSection(error)
                    }

                    if !viewModel.statusMessage.isEmpty && viewModel.errorMessage == nil && !viewModel.isLoading {
                        resultSection
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("WebView Harness")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Authorization Section

    private var authorizationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("授权信息", systemImage: "checkmark.shield")
                .font(.headline)

            Group {
                LabeledContent("URL") {
                    Text(viewModel.authorizedUrl)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                LabeledContent("Allowed Host") {
                    Text(viewModel.allowedHost)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                LabeledContent("Source") {
                    Text("qianfanxs_user_provided")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Security Constraints Section

    private var securityConstraintsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("安全约束", systemImage: "lock.shield")
                .font(.headline)

            let violations = viewModel.validateSecurityConstraints()

            if violations.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("所有安全约束已满足")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else {
                ForEach(violations, id: \.self) { violation in
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text(violation)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Execute Button

    private var executeButton: some View {
        Button(action: {
            Task {
                await viewModel.executeRender()
            }
        }) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image(systemName: "play.fill")
                }
                Text(viewModel.isLoading ? "执行中..." : "执行 WebView 渲染")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isLoading ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(viewModel.isLoading)
    }

    // MARK: - Loading Section

    private var loadingSection: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Error Section

    private func errorSection(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("错误", systemImage: "xmark.octagon")
                .font(.headline)
                .foregroundColor(.red)

            Text(error)
                .font(.caption)
                .foregroundColor(.red)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Result Section

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("执行结果", systemImage: "checkmark.circle")
                .font(.headline)
                .foregroundColor(.green)

            Group {
                LabeledContent("状态") {
                    Text(viewModel.statusMessage)
                        .foregroundColor(.primary)
                }
                LabeledContent("Final URL") {
                    Text(viewModel.finalUrl.isEmpty ? "-" : viewModel.finalUrl)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                LabeledContent("Navigation Count") {
                    Text("\(viewModel.navigationCount)")
                        .foregroundColor(.primary)
                }
                LabeledContent("HTML Size") {
                    Text("\(viewModel.renderedHtmlSize) bytes")
                        .foregroundColor(.primary)
                }
                LabeledContent("Page Title") {
                    Text(viewModel.pageTitle.isEmpty ? "-" : viewModel.pageTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                LabeledContent("Execution Time") {
                    Text("\(viewModel.executionTimeMs) ms")
                        .foregroundColor(.primary)
                }

                if let snapshot = viewModel.savedSnapshotPath {
                    LabeledContent("Snapshot") {
                        Text(snapshot)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .font(.caption)

            if !viewModel.warnings.isEmpty {
                Divider()
                Label("警告", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)

                ForEach(viewModel.warnings, id: \.self) { warning in
                    Text("• \(warning)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            if !viewModel.auditEvents.isEmpty {
                Divider()
                Label("审计事件", systemImage: "list.bullet.rectangle")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(viewModel.auditEvents, id: \.self) { event in
                    Text("• \(event)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    WebViewRuntimeHarnessView()
}

#endif