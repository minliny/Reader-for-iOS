# IOS_XCODE_PROJECT_GENERATION_PLAN
## iOS Xcode 项目生成计划 - WebView Runtime Harness

**文档版本**: 1.0
**创建日期**: 2026-05-08
**任务代码**: GENERATE_READER_IOS_XCODE_PROJECT_FOR_WEBVIEW_HARNESS

---

## 一、背景

### 1.1 当前阻塞

WebView Runtime 测试在 macOS CLI 环境被系统安全策略阻止 (exit 133 = SIGKILL)。

**原因**:
- WKWebView 需要 GUI host (NSApplication)
- CLI 环境缺少 AppKit 上下文
- macOS 系统对无 host 的 WebKit 调用强制终止

### 1.2 解决方案

在 Reader for iOS 仓库生成 iOS Xcode App Host，使 WebView Runtime Harness 可以在 iOS Simulator 中运行。

---

## 二、XcodeGen 方案

### 2.1 为什么选择 XcodeGen

1. **项目现状**: Reader for iOS 是纯 Swift Package，没有 `.xcodeproj`
2. **非侵入式**: 通过 `project.yml` 配置，不修改现有 Package.swift
3. **版本化**: `project.yml` 可提交到 git，`.xcodeproj` 可按需生成
4. **灵活性**: 支持多 target、复杂依赖、本地 package

### 2.2 XcodeGen 状态

**当前状态**: XcodeGen 未安装 (`xcodegen not found`)

**用户需要**:
1. 安装 XcodeGen: `brew install xcodegen`
2. 或从 https://github.com/yonaskolb/XcodeGen 下载
3. 安装后执行 `xcodegen generate`

---

## 三、project.yml 结构

### 3.1 文件位置

```
/Users/minliny/Documents/Reader for iOS/project.yml
```

### 3.2 内容概要

```yaml
name: ReaderForIOS
options:
  deploymentTarget:
    iOS: "17.0"

packages:
  ReaderCore:
    path: ../Reader-Core/Core
    from: "0.1.0"

targets:
  ReaderForIOSApp:
    type: application
    platform: iOS
    sources:
      - iOS/App
      - iOS/Features
      - iOS/Navigation
      - iOS/Modules
      - iOS/Surface
      - iOS/CoreBridge
      - iOS/CoreIntegration
      - iOS/Shell
      - iOS/AppSupport
    dependencies:
      - package: ReaderCore
        product: ReaderCoreModels
      - package: ReaderCore
        product: ReaderCoreProtocols
      - package: ReaderCore
        product: ReaderCoreParser
      - package: ReaderCore
        product: ReaderCoreNetwork
      - package: ReaderCore
        product: ReaderPlatformAdapters
```

---

## 四、iOS App Host 入口

### 4.1 现有入口

Reader for iOS 已有 SwiftUI App entry: `iOS/App/ReaderApp.swift`

### 4.2 Debug Harness 接入

在 `ReaderApp.swift` 的 `RootShellView` 中添加 DEBUG 条件工具栏按钮：

```swift
#if DEBUG
ToolbarItem(placement: .topBarTrailing) {
    NavigationLink(destination: WebViewRuntimeHarnessView()) {
        Text("WebView Harness")
    }
}
#endif
```

### 4.3 接入约束

1. **只在 DEBUG 暴露**: Release 构建不暴露 Harness 入口
2. **不自动联网**: App 启动不执行任何网络请求
3. **用户手动触发**: Harness 页面需要用户点击才会执行

---

## 五、WebViewRuntimeHarnessView 集成

### 5.1 文件位置

```
iOS/Features/Debug/WebViewRuntimeHarnessView.swift
iOS/Features/Debug/WebViewRuntimeHarnessViewModel.swift
```

### 5.2 依赖

- `ReaderCoreModels` (DTO + Protocol)
- `ReaderPlatformAdapters` (WKWebViewRuntimeAdapter)

### 5.3 约束

1. **DEBUG only**: `#if DEBUG && canImport(WebKit)`
2. **不自动执行**: 用户必须手动点击"执行渲染"按钮
3. **dry-run 优先**: 本轮不执行真实 URL，只验证 harness 可用性

---

## 六、Info.plist 配置

### 6.1 文件位置

```
iOS/Info.plist
```

### 6.2 安全配置

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>www.qianfanxs.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

---

## 七、生效步骤

### 7.1 用户操作步骤

1. **安装 XcodeGen** (如果未安装):
   ```bash
   brew install xcodegen
   ```

2. **生成 Xcode 项目**:
   ```bash
   cd /Users/minliny/Documents/Reader\ for\ iOS
   xcodegen generate
   ```

3. **打开项目**:
   ```bash
   open ReaderForIOS.xcodeproj
   ```

4. **选择 Simulator**:
   - 在 Xcode toolbar 选择 iPhone 17 Pro (或任何 iOS 17.0+ Simulator)
   - 或使用菜单: Product → Destination → iPhone 17 Pro

5. **运行 App** (⌘R):
   - App 启动后，toolbar 右上角显示 "WebView Harness" 按钮 (DEBUG only)
   - 点击进入 Harness 页面

6. **使用 Harness**:
   - 查看授权配置
   - 点击"执行渲染"按钮 (dry-run 或真实 URL)
   - 查看结果

### 7.2 本轮限制

- ❌ 不执行真实 URL (qianfanxs.com)
- ❌ 不联网
- ✅ 只验证 Harness 可用性
- ✅ 边界检查通过

### 7.3 下一轮

**下一轮任务**: AUTHORIZE_SINGLE_WEBVIEW_URL_RENDER_TEST_IN_GENERATED_XCODE_PROJECT

届时用户确认后，可以在生成的 Xcode 项目中执行真实 URL 测试。

---

## 八、.gitignore 规则

### 8.1 建议规则

```
# XcodeGen
*.xcodeproj
*.xcworkspace

# Build
.build/
DerivedData/

# OS
.DS_Store
```

### 8.2 提交内容

✅ `project.yml` - XcodeGen 配置（版本化）
✅ `iOS/Info.plist` - App 配置
✅ `iOS/App/ReaderApp.swift` - 更新（添加 DEBUG toolbar）
✅ `docs/IOS_XCODE_PROJECT_GENERATION_PLAN.md` - 本文档

❌ `.xcodeproj` - 按需生成，不提交
❌ `.build/` - 构建产物

---

## 九、验证步骤

### 9.1 XcodeGen 验证

```bash
xcodegen generate
ls -la *.xcodeproj  # 应该存在
```

### 9.2 xcodebuild 验证

```bash
xcodebuild -list -project ReaderForIOS.xcodeproj
# 应该显示 ReaderForIOSApp target
```

### 9.3 边界检查

```bash
bash scripts/check_ios_boundary.sh
# 应该 PASS
```

---

## 十、状态

**当前状态**: PROJECT_YML_CREATED

**下一步**:
1. 用户安装 XcodeGen
2. 执行 `xcodegen generate`
3. 打开 `.xcodeproj` 并运行

**目标状态**:
- IOS_XCODE_PROJECT_HOST_PREPARED_FOR_WEBVIEW_HARNESS ✅
- WEBVIEW_RUNTIME_HARNESS_APP_HOST_READY (待用户运行 xcodegen)
- NO_REAL_WEBVIEW_EXECUTION_THIS_ROUND ✅

---

*文档创建时间：2026-05-08*
*任务代码：GENERATE_READER_IOS_XCODE_PROJECT_FOR_WEBVIEW_HARNESS*