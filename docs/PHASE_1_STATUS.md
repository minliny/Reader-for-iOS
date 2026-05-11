# Phase 1 状态文档

> 当前环境: Linux 沙箱（SwiftUI 不可用）
> 当前状态: **READY_CANDIDATE**（未达到 READY）
> 最后更新: 2026-05-11

---

## 1. Phase 1 范围定义

**目标**: Reader-for-iOS Phase 1 — CoreBridge + Mock Service + non-JS UI 骨架
**约束**: 不实现 JS/WebView/WebDAV/真实网络访问

---

## 2. Phase 1 文件清单

### 2.1 Phase 1A (implicit, 早期 commits)

| 文件 | 路径 | 类型 |
|------|------|------|
| AppDelegate.swift | iOS/App/ | 新增 |
| SceneDelegate.swift | iOS/App/ | 新增 |
| RootShellView.swift | iOS/App/ | 新增 |
| Package.swift (v1) | iOS/ | 新增 |
| check_ios_boundary.sh | scripts/ | 新增 |

### 2.2 Phase 1B (bc6f07f ~ e18865f)

| 文件 | 路径 | 类型 | 说明 |
|------|------|------|------|
| IOSHTTPAdapter.swift | iOS/PlatformAdapters/ | 新增 | HTTP 适配器 |
| IOSStorageAdapter.swift | iOS/PlatformAdapters/ | 新增 | 本地存储适配器 |
| IOSKeychainCredentialStore.swift | iOS/PlatformAdapters/ | 新增 | Keychain（Apple only） |
| IOSLoggerAdapter.swift | iOS/PlatformAdapters/ | 新增 | Logger（#if canImport os） |
| IOSSnapshotStore.swift | iOS/PlatformAdapters/ | 新增 | Snapshot 存储 |
| PlatformAdapterTests.swift | iOS/Tests/PlatformAdapterTests/ | 新增 | 适配器测试 |
| ReaderCoreRealModeProbe.swift | iOS/CoreIntegration/ | 新增 | Real mode 编译探测 |
| SettingsView.swift | iOS/Features/Settings/ | 新增 | 设置页面 |
| SettingsViewModel.swift | iOS/Features/Settings/ | 新增 | 设置 ViewModel |
| Package.swift (v2) | iOS/ | 修改 | + ReaderIOSPlatformAdapters, PlatformAdapterTests |
| check_ios_boundary.sh | scripts/ | 修改 | + PlatformAdapters, forbidden patterns |

**Phase 1B 新增: 9 文件，修改: 2 文件**

### 2.3 Phase 1C (e18865f)

| 文件 | 路径 | 类型 | 说明 |
|------|------|------|------|
| LinuxValidationTests.swift | iOS/Tests/LinuxValidationTests/ | 新增 | Linux 验证测试（8 tests） |
| Route.swift | iOS/Navigation/ | 修改 | + .settings case |
| ReaderApp.swift | iOS/App/ | 修改 | + settings toolbar 入口 |
| MockReaderCoreService.swift | iOS/CoreBridge/ | 修改 | 移除 Sendable，rename lock |
| InMemoryBookSourceRepository.swift | iOS/CoreIntegration/ | 修改 | NSLock → actor |
| ReaderCoreRealModeProbe.swift | iOS/CoreIntegration/ | 修改 | actor-based stubs |
| ShellAssemblySmokeTests.swift | iOS/Tests/ShellSmokeTests/ | 修改 | nonisolatedIs helper |
| Package.swift (v3) | iOS/ | 修改 | + LinuxValidationTests target |
| ios-shell-ci.yml | .github/workflows/ | 修改 | 修正为真实 targets |
| docs/PROJECT_STATUS.md | docs/ | 修改 | Phase 1 完成摘要 |
| docs/AI_HANDOFF/PROJECT_STATUS.md | docs/AI_HANDOFF/ | 修改 | 同上 |
| docs/AI_HANDOFF/OPEN_TASKS.md | docs/AI_HANDOFF/ | 修改 | M-IOS-2~5 任务状态 |

**Phase 1C 新增: 1 文件，修改: 10 文件**

### 2.4 统计汇总

| 批次 | 新增 | 修改 |
|------|------|------|
| Phase 1A | ~5 | ~0 |
| Phase 1B | 9 | 2 |
| Phase 1C | 1 | 10 |
| **合计** | **~15** | **~12** |

---

## 3. Linux 验证结果

### 3.1 Build-level 验证（✅ 全部通过）

```bash
# 边界检查
./scripts/check_ios_boundary.sh  # ✅ PASS (62 files)

# SwiftPM targets
swift build --target ReaderAppSupport           # ✅ 0 warning
swift build --target ReaderIOSPlatformAdapters  # ✅ 0 warning
swift build --target ReaderShellValidation      # ✅ 0 warning
swift build --target PlatformAdapterTests       # ✅ 0 warning
swift build --target LinuxValidationTests       # ✅ 0 warning
```

### 3.2 Swift test 执行（❌ Linux blocker）

```bash
swift test --filter LinuxValidationTests  # ❌ SwiftPM blocker
swift test --filter PlatformAdapterTests   # ❌ SwiftPM blocker
swift test --filter ShellSmokeTests       # ❌ SwiftPM blocker
```

**Blocker 原因**: SwiftPM 编译阶段编译 ALL test targets 依赖图，无论 `--filter`。
`ReaderApp` target 依赖 SwiftUI → `no such module 'SwiftUI'` on Linux。

**不计入 Phase 1D-Linux 失败**：这是 SwiftPM 设计限制，不是 Phase 1 代码缺陷。
Workaround: Linux CI 用 `swift build --target`；macOS CI 用 `swift test`。

---

## 4. macOS 验证预案

> **⚠️ 以下命令本轮未执行**，当前环境是 Linux 沙箱。

在 macOS-14 runner 执行：

```bash
# 工具链验证
swift --version
xcodebuild -version

# Package resolve
cd iOS && swift package resolve

# Build targets
swift build --package-path iOS --target ReaderAppSupport
swift build --package-path iOS --target ReaderIOSPlatformAdapters
swift build --package-path iOS --target ReaderShellValidation
swift build --package-path iOS --target ReaderApp

# Test targets (non-SwiftUI)
swift test --package-path iOS --filter PlatformAdapterTests
swift test --package-path iOS --filter LinuxValidationTests
swift test --package-path iOS --filter ShellSmokeTests
swift test --package-path iOS --filter PublicSurfaceFunctionalSmokeTests
swift test --package-path iOS --filter ReaderAppSupportSkeletonTests

# 全量测试（如可行）
swift test --package-path iOS
```

**预期结果**: 所有 `swift test` 通过，零 failure。

---

## 5. CI Workflow 对齐结果

### 5.1 修复前（ios-shell-ci.yml）

```yaml
# 问题：
# 1. --test-product ReaderAppPackageTests → 不存在的 product
# 2. --filter ReaderFlowFunctionalValidationTests → 不存在的测试类
# 3. --filter ReaderFlowHardeningTests → 不存在的测试类
# 4. --filter ReaderUXFoundationStateTests → 不存在的测试类
# 5. --filter ReaderInteractionValidationTests → 不存在的测试类
# 6. --filter ReaderSessionValidationTests → 不存在的测试类
# 7. --filter ReaderNavigationValidationTests → 不存在的测试类
# 8. --filter ReaderPresentationValidationTests → 不存在的测试类
```

### 5.2 修复后

所有 step 使用实际存在的 test targets 和 filter：

| Step | 命令 | 状态 |
|------|------|------|
| boundary | `./scripts/check_ios_boundary.sh` | ✅ 正确 |
| compile ReaderAppSupport | `swift build --target ReaderAppSupport` | ✅ 正确 |
| compile ReaderIOSPlatformAdapters | `swift build --target ReaderIOSPlatformAdapters` | ✅ 正确 |
| compile ReaderShellValidation | `swift build --target ReaderShellValidation` | ✅ 正确 |
| test PlatformAdapterTests | `swift test --filter PlatformAdapterTests` | ✅ 正确 |
| test LinuxValidationTests | `swift test --filter LinuxValidationTests` | ✅ 正确 |
| test ShellSmokeTests | `swift test --filter ShellSmokeTests` | ✅ 正确 |
| test PublicSurfaceFunctional | `swift test --filter PublicSurfaceFunctionalSmokeTests` | ✅ 正确 |
| test ReaderAppSupportSkeleton | `swift test --filter ReaderAppSupportSkeletonTests` | ✅ 正确 |
| diag ReaderApp (SwiftUI) | `swift build --target ReaderApp` | ⚠️ diagnostic only |

---

## 6. Reader-Core Real Mode 前置清单

详见 `docs/READER_CORE_REAL_MODE_PROBE.md`。

### 6.1 iOS 侧已就绪的组件

| 组件 | 状态 |
|------|------|
| `ReaderCoreServiceProvider` + `ServiceMode` | ✅ 入口已就绪 |
| `BookSourceRepository` | ✅ 已实现 InMemoryBookSourceRepository |
| `BookSourceDecoder` | ✅ 已实现 DefaultBookSourceDecoder |
| PlatformAdapters (HTTP/Storage/Keychain/Logger/Snapshot) | ✅ 已实现 |
| `ShellAssembly` DI 组装 | ✅ 已就绪 |

### 6.2 Reader-Core 需要提供的最小 public API

**Protocol / Facade 清单**:

```swift
// 1. BookSource 加载
public protocol BookSourceLoader {
    func loadBookSource(from url: String) async throws -> BookSource
}

// 2. 搜索
public protocol SearchPipeline {
    func execute(query: SearchQuery, source: BookSource) async throws -> [SearchResultItem]
}

// 3. 书籍详情
public protocol BookDetailPipeline {
    func execute(url: String, source: BookSource) async throws -> SearchResultItem
}

// 4. 目录
public protocol TOCPipeline {
    func execute(detailURL: String, source: BookSource) async throws -> [TOCItem]
}

// 5. 正文
public protocol ContentPipeline {
    func execute(chapterURL: String, source: BookSource) async throws -> ContentPage
}

// 6. 错误映射（已有部分）
public protocol BookErrorMapper: ErrorMapper {
    // 需扩展为支持书源解析错误
}
```

**DTO 清单（已有，不需要额外提供）**:
- `BookSource`, `SearchQuery`, `SearchResultItem`, `TOCItem`, `ContentPage`
- `ReaderError`, `FailureRecord`, `CompatibilityMark`
- `HTTPRequest`, `HTTPResponse`, `CacheEntry`, `CacheScope`

### 6.3 iOS 侧禁止依赖

- ❌ `CSSExecutor` (internal)
- ❌ `SelectorEngine` (internal)
- ❌ `NonJSParserEngine` (internal)
- ❌ `ReaderCoreParser` internal types
- ❌ 直接实例化 `NonJSParser`

---

## 7. Phase 1 状态判断

| 维度 | 状态 | 说明 |
|------|------|------|
| Linux build-level | ✅ READY | 5/5 targets 零 warning |
| Linux test execution | ⚠️ BLOCKED | SwiftPM design blocker |
| macOS test execution | ⏳ 未验证 | 需要 macOS-14 runner |
| CI workflow | ✅ 已对齐 | 修正为真实 targets |
| Boundary check | ✅ PASS | 62 files, 7 paths, 4 forbidden |
| SettingsView 导航 | ✅ 就绪 | Route + toolbar 已接入 |
| Swift 6 warnings | ✅ 零 warning | Mock/InMemory actor 修复 |
| Reader-Core real mode | ⏳ BLOCKED | 等待 upstream facade |

**结论**: `ENGINEERING_BASELINE_READY_CANDIDATE`
- 所有 Linux 可验证目标已完成
- macOS 测试执行未验证（环境限制）
- 不升级为 READY，直到 macOS `swift test` 真实通过

---

## 8. 下一步

### M-IOS-4: macOS 验证（pending）
在 macOS-14 runner 执行 `swift test`，确认 4 个非 SwiftUI 测试类全部通过。

### M-IOS-5: Reader-Core Parser Facade（pending, upstream）
在 Reader-Core 侧推动 public pipeline service facade，解除 real mode 阻塞。

---

## 9. Clean-Room 状态

- Clean-room maintained: `yes`
- External GPL code copied: `no`
- Legado Android source referenced: `no`
