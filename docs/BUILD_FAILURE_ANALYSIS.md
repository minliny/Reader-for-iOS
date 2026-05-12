# BUILD_FAILURE_ANALYSIS

## Reader for iOS Xcode 项目构建失败分析

**日期**: 2026-05-08
**仓库**: Reader for iOS

---

## 一、构建失败现象

执行 `xcodegen generate` 成功生成了 `.xcodeproj`，但 `xcodebuild build` 失败：

```
** BUILD FAILED **
The following build commands failed:
    SwiftCompile CSSExecutor.swift (in target 'ReaderCoreParser' from project 'ReaderCore')
```

---

## 二、根本原因

### 2.1 iOS 版本不兼容

Reader-Core 的 `Package.swift` 声明的部署目标：

```swift
platforms: [
    .iOS(.v15),  // Reader-Core 最低支持 iOS 15
    .macOS(.v13)
]
```

但 `CSSExecutor.swift` 使用了仅 iOS 16+ 可用的 API：

```swift
private func elapsedMilliseconds(since start: ContinuousClock.Instant) -> Int {
    let duration = start.duration(to: clock.now)
    let millisecondsFromSeconds = duration.components.seconds * 1_000
    //                              ^^^^^^^^^^^^^^^^^^^^^^^ .components 仅 iOS 16+
}
```

### 2.2 Swift Package 依赖问题

Swift Package dependencies (`Reader-Core`) 使用自己的 `Package.swift` 声明的 iOS 15 部署目标。

Xcode 项目设置（project.yml 的 `deploymentTarget: "18.0"`）**不会覆盖** Swift Package 的部署目标。

---

## 三、已验证项

### 3.1 XcodeGen

✅ `xcodegen generate` 成功
✅ 生成了 `ReaderForIOS.xcodeproj`
✅ target 列表正确显示 `ReaderForIOSApp`

### 3.2 xcodebuild

❌ 构建失败 - Reader-Core 的 Swift Package 声明 iOS 15 但使用 iOS 16+ API

---

## 四、解决方案

### 4.1 需要的修复（在 Reader-Core）

Reader-Core 需要修改 `Core/Package.swift`：

```swift
// 从:
platforms: [
    .iOS(.v15),
    .macOS(.v13)
]

// 改为:
platforms: [
    .iOS(.v17),  // 或更高版本
    .macOS(.v13)
]
```

同时需要修复 `CSSExecutor.swift` 的 `elapsedMilliseconds` 方法，添加 `@available(iOS 16.0, *)` 或提供 iOS 15 fallback。

---

## 五、修复状态

### 5.1 阶段一：Reader-Core 修复 ✅

**修复文件**：
- `Core/Package.swift`: iOS 从 .v15 改为 .v17
- `Core/Sources/ReaderCoreParser/CSSExecutor.swift`: ContinuousClock 改为 Date-based timing

**验证**：
```bash
cd /Users/minliny/Documents/Reader-Core
swift build
# ✅ BUILD SUCCEEDED
```

### 5.2 阶段二：Reader for iOS project.yml 修复 ✅

**问题**：ReaderShellValidation 和 ReaderAppPersistence 模块无法解析

**修复**：
- 添加 `ReaderAppSupport`、`ReaderAppPersistence`、`ReaderShellValidation` 作为独立 framework targets
- 添加 `GENERATE_INFOPLIST_FILE: YES` 和代码签名禁用设置

**验证**：
```bash
cd "/Users/minliny/Documents/Reader for iOS"
xcodegen generate
xcodebuild -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
# ✅ BUILD SUCCEEDED
```

### 5.3 阶段三：iOS Color API 修复 ✅

**问题**：`Color.platformSecondaryGroupedBackground` 在 iOS 上不存在

**修复**：
- `iOS/Modules/Color+PlatformCompat.swift`: 添加 iOS 版本 Color extensions

### 5.4 阶段四：WebViewRuntimeHarnessViewModel.swift API 修正 ✅

**问题**：
- `RuntimeWebViewResult` 没有 `warnings` 和 `auditEvents` 属性
- `RuntimeAuthorization` 初始化参数顺序错误

**修复**：
- 移除 `result.warnings` 和 `result.auditEvents` 引用
- 修正 `allowedHosts` 须在 `capabilityAllowlist` 之前的参数顺序

---

## 六、本轮完成状态

| 项目 | 状态 |
|------|------|
| project.yml 创建 | ✅ 完成 |
| xcodegen generate | ✅ 成功 |
| .xcodeproj 生成 | ✅ 成功 |
| xcodebuild build | ✅ 成功 (2026-05-08 22:10) |
| Reader-Core iOS 版本 | ✅ 已修复 (.v17) |
| CSSExecutor timing | ✅ 已修复 (Date-based) |
| Reader for iOS project.yml targets | ✅ 已修复 |
| iOS Color API | ✅ 已修复 |
| WebViewRuntimeHarnessViewModel | ✅ 已修复 |

---

## 七、后续步骤

1. 启动 Simulator：`xcrun simctl boot "iPhone 17 Pro"`
2. 安装 App：`xcrun simctl install booted /Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Build/Products/Debug-iphonesimulator/ReaderForIOSApp.app`
3. 运行 App：`xcrun simctl launch booted com.reader.ios`
4. 在 DEBUG 模式下，点击 "WebView Harness" 工具栏按钮测试 WebView Runtime

---

*文档更新时间：2026-05-08*
*状态：BUILD_FIXED_AND_VERIFIED*
