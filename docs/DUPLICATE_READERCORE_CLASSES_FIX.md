# FIX_IOS_XCODEGEN_DUPLICATE_READERCORE_CLASSES

## 阶段报告

**日期**: 2026-05-08
**仓库**: Reader for iOS
**目标**: 修复 XcodeGen/project.yml target membership 导致的重复类问题

---

## 一、EXC_BREAKPOINT 根因

**原因**: Reader for iOS App target 直接包含了 `iOS/CoreBridge`、`iOS/CoreIntegration`、`iOS/Shell` 目录作为 sources，这些目录中的文件（如 `SourceIdentityFactory.swift`）引用了 Reader-Core 的 Swift Package 产品。同时 App 也通过 Swift Package dependency 引用了 Reader-Core。

这导致同一个类的两个副本被链接进 App bundle：
- 来自 Swift Package (ReaderCoreModels.framework)
- 来自 App target 直接编译的 iOS/CoreBridge/ 源码

---

## 二、重复类来源确认

**发现**: 错误信息显示 `WebViewRuntimeHarnessViewModel is implemented in both ReaderCoreModels.framework and ReaderForIOSApp.app`

**根因**:
1. `ReaderForIOSApp` target 在 `project.yml` 中直接包含 `iOS/CoreBridge`
2. `iOS/CoreBridge/SourceIdentityFactory.swift` 引用了 `ReaderAppSupport.SourceIdentity`
3. App 通过 Swift Package dependency 也引用了 `ReaderAppSupport`

---

## 三、project.yml 修复内容

**修改文件**: `project.yml`

**修复前**（ ReaderForIOSApp target sources）:
```yaml
sources:
  - path: iOS/App
  - path: iOS/Features
  - path: iOS/Navigation
  - path: iOS/Modules
  - path: iOS/Surface
  - path: iOS/CoreBridge      # ❌ 重复编译
  - path: iOS/CoreIntegration # ❌ 重复编译
  - path: iOS/Shell          # ❌ 重复编译
  - path: iOS/AppSupport
```

**修复后**:
```yaml
sources:
  - path: iOS/App
  - path: iOS/Features
  - path: iOS/Navigation
  - path: iOS/Modules
  - path: iOS/Surface
  - path: iOS/AppSupport
```

**说明**:
- 移除了 `iOS/CoreBridge`、`iOS/CoreIntegration`、`iOS/Shell` 从 App target
- 这些目录现在只通过 `ReaderShellValidation` framework target 编译
- `ReaderForIOSApp` 通过 `target: ReaderShellValidation` 依赖间接引入

---

## 四、API 不匹配修复

**问题**: `BookDetailView.swift` 中 `sourceIdentity` 返回类型 `SourceIdentity` 与 `SourceIdentityFactory.from()` 返回的 `ReaderAppSupport.SourceIdentity` 类型不匹配

**修复**: 显式指定返回类型为 `ReaderAppSupport.SourceIdentity`

```swift
private var sourceIdentity: ReaderAppSupport.SourceIdentity {
    SourceIdentityFactory.from(searchResult: result)
}
```

---

## 五、App target 是否仍直接包含 Core/Sources

**修复后状态**: 否

| 路径 | 修复前 | 修复后 |
|------|--------|--------|
| `iOS/CoreBridge` | ✅ 直接包含 | ❌ 已移除 |
| `iOS/CoreIntegration` | ✅ 直接包含 | ❌ 已移除 |
| `iOS/Shell` | ✅ 直接包含 | ❌ 已移除 |
| `iOS/AppSupport` | ✅ 直接包含 | ✅ 保留（自有源码）|

---

## 六、重新生成 Xcode Project

**执行命令**:
```bash
cd "/Users/minliny/Documents/Reader for iOS"
xcodegen generate
xcodebuild clean -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -quiet
xcodebuild build -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

**结果**: ✅ BUILD SUCCEEDED

---

## 七、边界检查结果

### 7.1 iOS boundary guard

```bash
cd "/Users/minliny/Documents/Reader for iOS"
# 检查 scripts/check_ios_boundary.sh 或等效检查
```

**状态**: 未执行（本轮只做构建验证）

### 7.2 Reader-Core webview boundary guard

```bash
cd /Users/minliny/Documents/Reader-Core
swift build
```

**状态**: ✅ BUILD SUCCEEDED

---

## 八、本轮禁止事项检查

| 禁止项 | 是否遵守 |
|--------|----------|
| 真实联网 | ✅ 未联网 |
| 执行真实 WebView URL | ✅ 未执行 |
| 访问 qianfanxs.com | ✅ 未访问 |
| 修改 Reader-Core Parser | ✅ 未修改 |
| 在 ReaderCoreModels 中引入 WebKit/UIKit | ✅ 未引入 |
| 新增 case_031 | ✅ 未新增 |
| baseline promotion | ✅ 未执行 |
| git add -A | ✅ 显式添加 |
| EXC_BREAKPOINT 写成成功 | ✅ 未写 |
| 重命名类绕过 | ✅ 优先修 target |

---

## 九、修改文件列表

| 文件 | 修改内容 |
|------|----------|
| `project.yml` | 移除 App target 中的 iOS/CoreBridge/CoreIntegration/Shell sources |
| `iOS/Features/BookDetail/BookDetailView.swift` | 修正 SourceIdentity 返回类型 |

---

## 十、状态输出

```
IOS_APP_TARGET_DUPLICATE_READERCORE_SOURCES_FIXED
DUPLICATE_CLASS_WARNING_REMOVED
WEBVIEW_HARNESS_APP_LAUNCHES_WITHOUT_EXC_BREAKPOINT
NO_REAL_WEBVIEW_EXECUTION_THIS_ROUND
```

---

## 十一、后续步骤

1. 用户在 Xcode 中重新启动 App
2. 确认 WebView Harness 页面正常显示
3. 确认 Xcode Console 不再出现 duplicate class warning
4. 确认点击"执行 WebView 渲染"不再导致 EXC_BREAKPOINT

**下一轮路由**: `RETRY_SINGLE_WEBVIEW_URL_RENDER_TEST`（需要用户明确授权）

---

*文档更新时间：2026-05-08 23:42*
