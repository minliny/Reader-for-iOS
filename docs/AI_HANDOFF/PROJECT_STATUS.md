# 项目状态 (PROJECT_STATUS)

## 项目定义

- 当前仓库名：`Reader-for-iOS`
- 当前仓库角色：`Reader-iOS 主仓`
- 依赖上游仓：`Reader-Core`
- 当前主线：`Reader-for-iOS 正式开发启动阶段`
- 当前阶段：`Phase 1D-Linux: 状态收口 + CI 对齐`
- 当前状态：`ENGINEERING_BASELINE_READY_CANDIDATE`
- 当前是否允许继续推进新功能：`yes`

## Phase 1 完成情况

详见 `docs/PHASE_1_STATUS.md`。

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

### Phase 1D-Linux: 状态收口 + CI 对齐
| 产出 | 状态 |
|------|------|
| Git 工作树干净 | ✅ |
| ios-shell-ci.yml 修正（真实 targets + 正确 filter） | ✅ |
| docs/PHASE_1_STATUS.md 新建 | ✅ |
| 三份状态文件同步更新 | ✅ |
| Linux build-level 验证全部通过 | ✅ |

## Linux 验证结果

```bash
swift build --target ReaderAppSupport           # ✅ 0 warning
swift build --target ReaderIOSPlatformAdapters  # ✅ 0 warning
swift build --target ReaderShellValidation      # ✅ 0 warning
swift build --target LinuxValidationTests       # ✅ 0 warning
swift build --target PlatformAdapterTests       # ✅ 0 warning
swift test --filter LinuxValidationTests        # ❌ SwiftPM blocker
scripts/check_ios_boundary.sh                  # ✅ PASS (62 files)
```

## CI Workflow 对齐

旧 workflow 问题：
- `--test-product ReaderAppPackageTests` → product 不存在
- 8 个不存在的 `--filter` test class 名称

新 workflow（`.github/workflows/ios-shell-ci.yml`）：
- 3 个 build step: ReaderAppSupport, ReaderIOSPlatformAdapters, ReaderShellValidation
- 5 个 test step: PlatformAdapterTests, LinuxValidationTests, ShellSmokeTests, PublicSurfaceFunctionalSmokeTests, ReaderAppSupportSkeletonTests
- 1 个 diagnostic-only step: ReaderApp（SwiftUI diagnostic）

## Reader-Core Real Mode Blocker

详见 `docs/READER_CORE_REAL_MODE_PROBE.md`。

**阻塞点**：ReaderCoreParser product 存在但无 public pipeline facade。
**后续任务**：M-IOS-5（upstream Reader-Core 侧任务）。

## 最近一次动作

- Phase 1D-Linux: 状态收口 + CI 对齐
- Git 工作树干净确认（所有 Phase 1C 变更已提交）
- ios-shell-ci.yml 修正为真实 targets + 正确 filter
- docs/PHASE_1_STATUS.md 新建（详细文件清单 + macOS 验证预案）
- 三份状态文件同步更新

## 下一步唯一最优任务

**Phase 1D-macOS 入口条件**：
1. macOS `swift test` 验证（非 SwiftUI 测试通过）
2. Reader-Core public Parser facade 完成（upstream）

**推荐路径**：
1. 在 macOS-14 runner 执行 `swift test`，验证 Phase 1 测试通过（docs/PHASE_1_STATUS.md#4）
2. 在 Reader-Core 侧推动 public Parser pipeline facade

## Clean-Room 状态

- Clean-room maintained: `yes`
- External GPL code copied: `no`
- Legado Android source referenced: `no`
