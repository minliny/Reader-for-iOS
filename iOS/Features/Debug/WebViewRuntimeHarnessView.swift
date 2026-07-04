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
        DemoBackScreen(title: "WebView Harness") {
            authorizationSection

            Divider()

            securityConstraintsSection

            Divider()

            executeButton

            Divider()

            if viewModel.isLoading {
                loadingSection
            }

            if let error = viewModel.errorMessage {
                errorSection(error)
            }

            if !viewModel.statusMessage.isEmpty && viewModel.errorMessage == nil && !viewModel.isLoading {
                resultSection
            }
        }
    }

    // MARK: - Authorization Section

    private var authorizationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ReaderIcon(.shield, size: 20, accessibilityLabel: "授权信息")
                Text("授权信息")
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
            }

            VStack(alignment: .leading, spacing: 6) {
                HarnessMetricRow(label: "URL", value: viewModel.authorizedUrl)
                HarnessMetricRow(label: "Allowed Host", value: viewModel.allowedHost)
                HarnessMetricRow(label: "Source", value: "qianfanxs_user_provided")
            }
        }
        .padding()
        .background(ReaderDesignTokens.Color.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md))
    }

    // MARK: - Security Constraints Section

    private var securityConstraintsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ReaderIcon(.shield, size: 20, accessibilityLabel: "安全约束")
                Text("安全约束")
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
            }

            let violations = viewModel.validateSecurityConstraints()

            if violations.isEmpty {
                HStack {
                    ReaderIcon(.check, size: 16, accessibilityLabel: "通过")
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    Text("所有安全约束已满足")
                        .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                }
            } else {
                ForEach(violations, id: \.self) { violation in
                    HStack {
                        ReaderIcon(.warning, size: 16, accessibilityLabel: "违规")
                            .foregroundColor(ReaderDesignTokens.Color.Semantic.danger)
                        Text(violation)
                            .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                            .foregroundColor(ReaderDesignTokens.Color.Semantic.danger)
                    }
                }
            }
        }
        .padding()
        .background(ReaderDesignTokens.Color.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md))
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
                    // demo `.fd-discover-bottom-loading i`：14×14 旋转圆，2px border。
                    // 在 primary 背景上用白色轨道 + 白色 top arc。
                    DemoLoadingSpinnerInlineOnPrimary()
                } else {
                    ReaderIcon(.play, size: 16, accessibilityLabel: nil)
                        .foregroundColor(.white)
                }
                Text(viewModel.isLoading ? "执行中..." : "执行 WebView 渲染")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isLoading ? ReaderDesignTokens.Color.muted : ReaderDesignTokens.Color.primary)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md))
        }
        .disabled(viewModel.isLoading)
    }

    // MARK: - Loading Section

    private var loadingSection: some View {
        VStack(spacing: 8) {
            // demo `.fd-reader-loading-panel i`：30×30 旋转圆。
            DemoLoadingSpinner(size: .reader)
            Text(viewModel.statusMessage)
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundColor(ReaderDesignTokens.Color.muted)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Error Section

    private func errorSection(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ReaderIcon(.warning, size: 20, accessibilityLabel: "错误")
                    .foregroundColor(ReaderDesignTokens.Color.Semantic.danger)
                Text("错误")
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.Semantic.danger)
            }

            Text(error)
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundColor(ReaderDesignTokens.Color.Semantic.danger)
        }
        .padding()
        .background(ReaderDesignTokens.Color.Semantic.danger.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md))
    }

    // MARK: - Result Section

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ReaderIcon(.check, size: 20, accessibilityLabel: "执行结果")
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                Text("执行结果")
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            }

            VStack(alignment: .leading, spacing: 6) {
                HarnessMetricRow(label: "状态", value: viewModel.statusMessage)
                HarnessMetricRow(label: "Final URL", value: viewModel.finalUrl.isEmpty ? "-" : viewModel.finalUrl)
                HarnessMetricRow(label: "Navigation Count", value: "\(viewModel.navigationCount)")
                HarnessMetricRow(label: "HTML Size", value: "\(viewModel.renderedHtmlSize) bytes")
                HarnessMetricRow(label: "Page Title", value: viewModel.pageTitle.isEmpty ? "-" : viewModel.pageTitle)
                HarnessMetricRow(label: "Execution Time", value: "\(viewModel.executionTimeMs) ms")

                if let snapshot = viewModel.savedSnapshotPath {
                    HarnessMetricRow(label: "Snapshot", value: snapshot)
                }
            }

            if !viewModel.warnings.isEmpty {
                Divider()
                HStack(spacing: 8) {
                    ReaderIcon(.warning, size: 16, accessibilityLabel: "警告")
                        .foregroundColor(ReaderDesignTokens.Color.Semantic.warning)
                    Text("警告")
                        .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.Semantic.warning)
                }

                ForEach(viewModel.warnings, id: \.self) { warning in
                    Text("• \(warning)")
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundColor(ReaderDesignTokens.Color.Semantic.warning)
                }
            }

            if !viewModel.auditEvents.isEmpty {
                Divider()
                HStack(spacing: 8) {
                    ReaderIcon(.log, size: 16, accessibilityLabel: "审计事件")
                        .foregroundColor(ReaderDesignTokens.Color.muted)
                    Text("审计事件")
                        .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.muted)
                }

                ForEach(viewModel.auditEvents, id: \.self) { event in
                    Text("• \(event)")
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundColor(ReaderDesignTokens.Color.muted)
                }
            }
        }
        .padding()
        .background(ReaderDesignTokens.Color.primaryDark.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md))
    }
}

// MARK: - Preview

#Preview {
    WebViewRuntimeHarnessView()
}

private struct HarnessMetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Spacer()
            Text(value)
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .multilineTextAlignment(.trailing)
        }
    }
}

#endif
