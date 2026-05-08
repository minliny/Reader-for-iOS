# WebView Runtime Autorun Simulator Guide

## 1. 为什么 Claude Code 不应依赖人工点击 UI

Claude Code 是一个命令行工具，其设计目标是自动化、可重复、可脚本化的任务执行。如果依赖人工在 Simulator 中点击 UI 来触发功能，会有以下问题：

1. **不可自动化**：CLI 工具无法模拟鼠标点击
2. **不可重复**：每次手动点击都会有差异
3. **无法集成到 CI**：CI 环境没有 GUI 交互
4. **不稳定**：人工操作容易出错

因此，WebView Harness 应该支持通过命令行参数自动触发，而不是依赖 UI 点击。

---

## 2. 推荐方案：simctl launch 参数触发

使用 `xcrun simctl boot` 和 `xcrun simctl launch` 来启动 App，并通过启动参数传递配置。

### 基本命令

```bash
# 启动 Simulator
xcrun simctl boot "iPhone 17 Pro"

# 通过 CLI 启动 App 并传递 autorun 参数
xcrun simctl launch "iPhone 17 Pro" com.reader.ios \
  --webview-harness-autorun \
  --webview-url "https://www.qianfanxs.com/9/9556" \
  --webview-allowed-host "www.qianfanxs.com" \
  --webview-source-id "qianfanxs_user_provided" \
  --webview-source-name "千帆小说" \
  --webview-stage "detail" \
  --webview-output-dir "/tmp/webview_results"
```

---

## 3. 启动参数设计

### 必须参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `--webview-harness-autorun` | 启用 autorun 模式 | 开关 |
| `--webview-url` | 要渲染的 URL | `https://www.qianfanxs.com/9/9556` |
| `--webview-allowed-host` | 允许的主机 | `www.qianfanxs.com` |

### 可选参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--webview-source-id` | `autorun_user_provided` | 来源 ID |
| `--webview-source-name` | `Autorun` | 来源名称 |
| `--webview-stage` | `detail` | 阶段：search/detail/toc/content |
| `--webview-output-dir` | `~/Documents/WebViewHarnessRuns` | 输出目录 |
| `--webview-max-navigation-count` | `1` | 最大导航次数 |
| `--webview-require-https` | `true` | 是否要求 HTTPS |
| `--webview-exit-after-run` | `false` | 执行后是否退出 |

---

## 4. 安全约束

这些约束必须在代码层面强制执行：

### 硬约束（不可绕过）

- **Single URL only**：每次只允许一个 URL
- **allowed_host required**：必须指定并验证 host
- **maxNavigationCount = 1**：禁止批量请求、递归、翻页
- **requireHttps = true**：禁止 HTTP URL
- **no batch**：禁止同时发起多个请求
- **no recursion**：禁止页面内递归导航
- **no pagination**：禁止自动翻页
- **no chapter batch fetch**：禁止批量章节获取

### 禁止项

- ❌ WAF / anti-bot bypass
- ❌ Auto retry（自动重试）
- ❌ Cookie/Login 自动流程（除非单独授权）
- ❌ Arbitrary JS runtime（任意 JS 执行）

---

## 5. 结果文件

Autorun 完成后，会在输出目录生成以下文件：

### 5.1 webview_run_status.json

```json
{
  "status": "success",
  "runId": "550e8400-e29b-41d4-a716-446655440000",
  "finalUrl": "https://www.qianfanxs.com/9/9556",
  "navigationCount": 1,
  "renderedHtmlSize": 45678,
  "snapshotPath": "Snapshot: snap_123456",
  "errorMessage": null,
  "startedAt": "2026-05-09T00:00:00Z",
  "finishedAt": "2026-05-09T00:00:05Z"
}
```

### 5.2 rendered_detail.html

渲染后的 HTML 内容文件。

### 5.3 webview_result.json

```json
{
  "status": "success",
  "finalUrl": "https://www.qianfanxs.com/9/9556",
  "navigationCount": 1,
  "renderedHtmlSize": 45678,
  "pageTitle": "千帆小说",
  "executionTimeMs": 5000,
  "snapshotId": "snap_123456",
  "snapshotFilePath": "/path/to/snapshot",
  "runId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### 5.4 webview_audit.json

（如果 requireAudit=true）

### 5.5 webview_snapshot_metadata.json

```json
{
  "snapshotId": "snap_123456",
  "snapshotFilePath": "/path/to/snapshot",
  "runId": "550e8400-e29b-41d4-a716-446655440000"
}
```

---

## 6. 目录结构

```
~/Documents/WebViewHarnessRuns/
└── {runId}/
    ├── webview_run_status.json      # 运行状态
    ├── webview_result.json           # 执行结果
    ├── webview_audit.json            # 审计日志（如果启用）
    ├── webview_snapshot_metadata.json # 快照元数据
    └── rendered_detail.html          # 渲染后的 HTML
```

---

## 7. 当前已实现代码

以下文件已存在于 `iOS/Features/Debug/` 目录：

- `WebViewRuntimeHarnessViewModel.swift` - 手动触发模式的 ViewModel
- `WebViewRuntimeAutorunView.swift` - Autorun 模式的 View
- `WebViewRuntimeAutorunConfiguration.swift` - 命令行参数解析

### 使用方法

```swift
import ReaderCoreModels
import ReaderPlatformAdapters

#if DEBUG && canImport(WebKit)

// 在 AppDelegate 或 SceneDelegate 中解析启动参数
let config = WebViewRuntimeAutorunConfiguration.parse(CommandLine.arguments)

if config.isEnabled && config.isValid {
    // 显示 Autorun View
    contentView = WebViewRuntimeAutorunView(configuration: config)
} else {
    // 显示正常的 UI
}
#endif
```

---

## 8. 下一轮才实现

以下功能需要在后续阶段实现：

1. **AppDelegate/SceneDelegate 集成**：解析启动参数并路由到正确的 View
2. **xcrun simctl launch 脚本**：创建便捷脚本封装启动命令
3. **结果文件解析**：创建读取和验证结果文件的工具函数
4. **错误处理**：完善各种错误场景的处理
5. **真实 URL 测试**：用户单独授权后执行真实 WebView URL

---

## 9. CLI 启动示例脚本

```bash
#!/bin/bash
# run_webview_harness.sh

set -e

SIMULATOR="iPhone 17 Pro"
BUNDLE_ID="com.reader.ios"
OUTPUT_DIR="/tmp/webview_results_$(date +%Y%m%d_%H%M%S)"

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 启动 App（不执行真实 WebView，本轮仅验证配置）
xcrun simctl launch "$SIMULATOR" "$BUNDLE_ID" \
  --webview-harness-autorun \
  --webview-url "https://www.qianfanxs.com/9/9556" \
  --webview-allowed-host "www.qianfanxs.com" \
  --webview-source-id "qianfanxs_user_provided" \
  --webview-source-name "千帆小说" \
  --webview-stage "detail" \
  --webview-output-dir "$OUTPUT_DIR" \
  --webview-require-https "true" \
  --webview-exit-after-run

echo "Results written to: $OUTPUT_DIR"
```

---

## 10. 状态检查

```
DUPLICATE_CLASS_WARNING_REMOVED ✅
IOS_APP_TARGET_SOURCES_CONFIRMED_SAFE ✅
CLAUDE_CODE_IOS_DEV_ENV_READY ✅
WEBVIEW_AUTORUN_WORKFLOW_PREPARED ✅
NO_REAL_WEBVIEW_EXECUTION_THIS_ROUND ✅
```

---

## 11. 下一步（NEXT_ROUTE）

```
NEXT_ROUTE = ENABLE_CLAUDE_CODE_AUTORUN_WEBVIEW_HARNESS
```

需要用户单独授权才能执行真实 WebView URL 测试。

---

## 12. 相关文档

- `docs/IOS_DEVELOPMENT_WITH_CLAUDE_CODE.md` - iOS 开发指南
- `docs/CLAUDE_CODE_IOS_ENVIRONMENT_SETUP.md` - 环境配置说明
- `CLAUDE.md` - Claude Code 项目配置
- `.claude/commands/ios-dev.md` - iOS 开发命令