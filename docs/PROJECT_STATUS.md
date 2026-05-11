# 项目状态总览

## 当前可信主线

- 可信主线分支：`main`
- 当前仓库身份：`Reader-iOS 主仓`
- Reader-Core 已独立为：`../Reader-Core` / `https://github.com/minliny/Reader-Core`
- 当前结论：反向拆仓已完成，双仓协同 Phase 1 (CoreBridge + Mock Service + non-JS UI) 工程基线已就绪，等待 macOS 测试验证。

## 当前阶段

- 项目目标：`Reader-for-iOS Phase 1 开发`
- 当前阶段：`Phase 1D-Linux: 状态收口 + CI 对齐`
- 当前主线：`Reader-for-iOS 正式开发启动阶段`
- 当前状态：`ENGINEERING_BASELINE_READY_CANDIDATE`
- 当前下一步：`Phase 1 macOS 验证（M-IOS-4）`

## Phase 1 完成摘要

详见 `docs/PHASE_1_STATUS.md`。

### Phase 1A (implicit)
- iOS 目录结构建立
- App Shell 骨架 (AppDelegate, SceneDelegate, RootShellView)
- Package.swift 基础 targets
- 边界检查脚本

### Phase 1B: PlatformAdapters + Real Mode Probe
- ReaderIOSPlatformAdapters target（5 adapter files）→ ✅ 编译通过
- PlatformAdapterTests target → ✅ 编译通过
- ReaderCoreRealModeProbe.swift → ✅ actor-based stub
- SettingsView.swift + SettingsViewModel.swift → ✅ 已接入导航
- Package.swift + check_ios_boundary.sh 更新

### Phase 1C: Linux Test Decoupling + Swift 6 Warning Cleanup
- LinuxValidationTests target（8 tests）→ ✅ 编译通过
- Route.swift `.settings` case + ReaderApp toolbar → ✅ 已接入
- MockReaderCoreService → ✅ 移除 Sendable
- InMemoryBookSourceRepository → ✅ NSLock → actor
- 零 Swift 6 warning → ✅
- SwiftPM Linux `swift test` blocker → ✅ 文档化

### Phase 1D-Linux: 状态收口 + CI 对齐
- Git 工作树干净（所有变更已提交）
- CI workflow 修正为真实 test targets + 正确 filter
- `docs/PHASE_1_STATUS.md` 新建（详细文件清单 + macOS 验证预案）
- 三份状态文件同步更新

## Linux 验证结果

| Target | Status | Swift 6 Warnings |
|--------|--------|-----------------|
| ReaderAppSupport | ✅ PASS | 0 |
| ReaderIOSPlatformAdapters | ✅ PASS | 0 |
| ReaderShellValidation | ✅ PASS | 0 |
| LinuxValidationTests | ✅ PASS | 0 |
| PlatformAdapterTests | ✅ PASS | 0 |
| ReaderApp (SwiftUI) | N/A Linux | N/A |

- `scripts/check_ios_boundary.sh`: ✅ PASS（62 files, 7 paths, 4 forbidden modules）

## SwiftPM Linux Test Blocker

`swift test --filter <X>` 在 Linux 下会编译 ALL test targets 依赖图，包含 SwiftUI 的 `ReaderApp`。
Workaround: Linux CI 用 `swift build --target`；macOS CI 用 `swift test`。

## CI Workflow 对齐

详见 `docs/PHASE_1_STATUS.md#5`。
- 旧 workflow：引用不存在的 `ReaderAppPackageTests` product 和 8 个不存在的 test filter
- 新 workflow：使用实际 5 个 test targets + 正确 `--filter` 值，diagnostic-only 保留 ReaderApp

## Reader-Core Real Mode Blocker

详见 `docs/READER_CORE_REAL_MODE_PROBE.md`。

**阻塞点**：Reader-Core Parser public facade 缺失。需要 Reader-Core 提供高层 pipeline service facade。

## 当前风险

- macOS `swift test` 尚未执行（环境限制）
- Reader-Core real mode 等待 upstream facade

## 推荐下一步

1. **M-IOS-4**: macOS-14 runner 执行 `swift test`，验证所有非 SwiftUI 测试通过
2. **M-IOS-5**: Reader-Core 侧提供 public Parser pipeline facade

## Clean-Room 说明

- 本次 Phase 1 仅基于 Legado 书源 JSON 结构规范、Reader-Core public API 探测、样本驱动原则开发
- 未复制/翻译/改写 Legado Android 源码
- PlatformAdapters 基于 iOS 平台 API 独立实现
