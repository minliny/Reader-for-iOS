# 项目状态 (PROJECT_STATUS)

## 项目定义

- 当前仓库名：`Reader-for-iOS`
- 当前仓库角色：`Reader-iOS 主仓`
- 依赖上游仓：`Reader-Core`
- 当前主线：`Reader-for-iOS 正式开发启动阶段`
- 当前阶段：`Phase 1: CoreBridge + Mock Service + non-JS UI` — READY_CANDIDATE
- 当前状态：`READY_CANDIDATE`
- 当前是否允许继续推进新功能：`yes`

## Phase 1 完成情况

### Phase 1A (implicit)
- iOS 目录结构建立
- App Shell 骨架（AppDelegate, SceneDelegate, RootShellView）
- Package.swift 基础 targets
- 边界检查脚本 `scripts/check_ios_boundary.sh`

### Phase 1B: PlatformAdapters + Real Mode Probe
| 产出 | 状态 |
|------|------|
| ReaderIOSPlatformAdapters target（5 adapter files） | ✅ 编译通过 |
| PlatformAdapterTests target | ✅ 编译通过 |
| ReaderCoreRealModeProbe.swift | ✅ actor-based stub |
| docs/READER_CORE_REAL_MODE_PROBE.md | ✅ |
| SettingsView.swift + SettingsViewModel.swift | ✅ |
| Package.swift 修改（2 targets） | ✅ |
| check_ios_boundary.sh 更新 | ✅ |

### Phase 1C: Linux Test Decoupling + Swift 6 Warning Cleanup
| 产出 | 状态 |
|------|------|
| LinuxValidationTests target（8 tests） | ✅ 编译通过 |
| Route.swift `.settings` case | ✅ |
| ReaderApp.swift settings 入口（toolbar gear） | ✅ |
| MockReaderCoreService Swift 6 修复 | ✅ |
| InMemoryBookSourceRepository NSLock → actor | ✅ |
| ShellAssemblySmokeTests + LinuxValidationTests `nonisolatedIs` | ✅ |
| 所有非 SwiftUI targets 零 warning 编译 | ✅ |
| SwiftPM Linux `swift test` blocker 文档化 | ✅ |

## Linux 验证结果

```bash
swift build --target ReaderAppSupport           # ✅ 0 warning
swift build --target ReaderIOSPlatformAdapters  # ✅ 0 warning
swift build --target ReaderShellValidation      # ✅ 0 warning
swift build --target LinuxValidationTests       # ✅ 0 warning
swift build --target PlatformAdapterTests       # ✅ 0 warning
swift test --filter LinuxValidationTests       # ❌ SwiftPM blocker
scripts/check_ios_boundary.sh                  # ✅ PASS (62 files)
```

**Linux swift test blocker**: SwiftPM 编译 ALL test targets 依赖图，`--filter` 只影响执行阶段。
Solution: Linux CI 用 `swift build --target`，macOS CI 用 `swift test`。

## Reader-Core Real Mode Blocker

详见 `docs/READER_CORE_REAL_MODE_PROBE.md`。

**核心发现**：ReaderCoreParser product 存在但无 public pipeline facade。
**阻塞点**：需要 Reader-Core 提供高于 Parser internal 实现层的 public Facade API。
**后续任务**：M-IOS-5（upstream Reader-Core 侧任务）。

## 最近一次动作

- Phase 1C: Linux Test Decoupling + Swift 6 Warning Cleanup
- InMemoryBookSourceRepository: NSLock → actor
- MockReaderCoreService: 移除 `Sendable`，重命名 `scenarioLock`
- 三份状态文件同步更新
- SwiftPM Linux blocker 文档化

## 下一步唯一最优任务

**Phase 2 入口条件**：
1. macOS `swift test` 验证（非 SwiftUI 测试通过）
2. Reader-Core public Parser facade 完成（upstream）

**推荐路径**：
1. 在 macOS runner 执行 `swift test` 验证 Phase 1 测试通过
2. 在 Reader-Core 侧推动 public Parser pipeline facade

## Clean-Room 状态

- Clean-room maintained: `yes`
- External GPL code copied: `no`
- Legado Android source referenced: `no`
