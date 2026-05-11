# 项目状态总览

## 当前可信主线

- 可信主线分支：`main`
- 当前仓库身份：`Reader-iOS 主仓`
- Reader-Core 已独立为：`../Reader-Core` / `https://github.com/minliny/Reader-Core`
- 当前结论：反向拆仓已完成，双仓协同 Phase 1 (CoreBridge + Mock Service + non-JS UI) 已完成。

## 当前阶段

- 项目目标：`Reader-for-iOS Phase 1 开发`
- 当前阶段：`Phase 1C — Linux Test 解耦 + Settings 路由 + Swift 6 Warning 清理`
- 当前主线：`Reader-for-iOS 正式开发启动阶段`
- 当前状态：`READY_CANDIDATE`
- 当前下一步：`Phase 2: macOS 验证 + Reader-Core real mode bridge 接入`

## Phase 1 完成摘要

### Phase 1A: 项目初始化
- iOS 目录结构建立
- App Shell 骨架 (AppDelegate, SceneDelegate, RootShellView)
- Package.swift 基础 targets
- 边界检查脚本

### Phase 1B: PlatformAdapters + Real Mode Probe
- ReaderIOSPlatformAdapters target 纳入编译（5 个 adapter 文件）
- PlatformAdapterTests target
- ReaderCoreRealModeProbe.swift（actor-based stub 实现）
- docs/READER_CORE_REAL_MODE_PROBE.md
- SettingsView.swift + SettingsViewModel.swift
- check_ios_boundary.sh 更新（PlatformAdapters + forbidden patterns）
- 修改文件：2 个（Package.swift, check_ios_boundary.sh）
- 新增文件：10 个（PlatformAdapters ×5, Tests ×2, Probe ×1, Settings ×2）

### Phase 1C: Linux Test 解耦 + Swift 6 Warning 清理
- LinuxValidationTests target（8 个测试用例）
- Route.swift 新增 `.settings` case
- ReaderApp.swift 新增 settings 导航入口（toolbar gear button）
- MockReaderCoreService: 移除 `Sendable`，scenarioLock 重命名
- InMemoryBookSourceRepository: NSLock → actor（消除 async context warnings）
- ShellAssemblySmokeTests + LinuxValidationTests: `nonisolatedIs` helper 适配 actor
- 所有非 SwiftUI targets 零 Swift 6 warning 编译通过
- SwiftPM Linux `swift test` blocker 已文档化

## 当前验证结果（Linux, swift build --target）

| Target | Status | Swift 6 Warnings |
|--------|--------|------------------|
| ReaderAppSupport | ✅ PASS | 0 |
| ReaderIOSPlatformAdapters | ✅ PASS | 0 |
| ReaderShellValidation | ✅ PASS | 0 |
| LinuxValidationTests | ✅ PASS | 0 |
| PlatformAdapterTests | ✅ PASS | 0 |
| ReaderApp (SwiftUI) | N/A Linux | N/A |

- `swift test --filter LinuxValidationTests`: ❌ SwiftPM blocker（编译阶段仍编译 ReaderApp）
- `scripts/check_ios_boundary.sh`: ✅ PASS（62 文件检查，7 路径限制，4 forbidden modules）

## Reader-Core Real Mode Blocker

详见 `docs/READER_CORE_REAL_MODE_PROBE.md`。

**核心发现**：Reader-Core Parser public facade 缺失。ReaderCoreParser product 存在，但其导出内容无法满足 BookSourceDecoder/SearchService/TOCService/ContentService 所需的 pipeline service。

**阻塞点**：需要 Reader-Core 提供高于 Parser internal 实现层的 public Facade API。

## 当前风险

- SwiftPM `swift test` 在 Linux 下无法跳过 SwiftUI target 编译 — 需 Swift 团队改变设计，或 macOS CI
- Reader-Core real mode 等待 Core 侧提供 public Parser facade
- LinuxValidationTests 和 ShellSmokeTests 断言使用 `nonisolatedIs` helper — 非标准 pattern

## 推荐下一步

1. **macOS 验证**：在 macOS 环境下运行 `swift test`，验证所有非 SwiftUI 测试实际执行通过
2. **Reader-Core facade**：在 Reader-Core 侧推动 public Parser pipeline service facade
3. **ios-shell-ci 验证**：确认 CI 在 macOS-14 runner 上全绿

## Clean-Room 说明

- 本次 Phase 1 仅基于 Legado 书源 JSON 结构规范、Reader-Core public API 探测、样本驱动原则开发
- 未复制/翻译/改写 Legado Android 源码
- PlatformAdapters 基于 iOS 平台 API 独立实现（SwiftUI/#if canImport/Security）
