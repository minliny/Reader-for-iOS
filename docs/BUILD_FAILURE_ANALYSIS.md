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

### 4.2 本轮状态

本轮生成了正确的 Xcode 项目配置，但构建被 Reader-Core 的依赖声明阻塞。

---

## 五、本轮完成状态

| 项目 | 状态 |
|------|------|
| project.yml 创建 | ✅ 完成 |
| xcodegen generate | ✅ 成功 |
| .xcodeproj 生成 | ✅ 成功 |
| xcodebuild build | ❌ 失败 (Reader-Core Swift Package 版本) |

---

## 六、建议的下一步

1. **用户需要先修复 Reader-Core**:
   ```bash
   cd /Users/minliny/Documents/Reader-Core
   # 修改 Core/Package.swift 将 iOS 从 .v15 改为 .v17
   git add Core/Package.swift
   git commit -m "fix: upgrade iOS deployment target to 17.0"
   git push
   ```

2. **然后重新生成 Reader for iOS 项目**:
   ```bash
   cd /Users/minliny/Documents/Reader\ for\ iOS
   xcodegen generate
   open ReaderForIOS.xcodeproj
   ```

---

*文档创建时间：2026-05-08*
*状态：BUILD_BLOCKED_BY_READER_CORE_SWIFT_PACKAGE_IOS_VERSION*