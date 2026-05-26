# iOS Reader Detailed Execution Plan

## 1. 总体结论

**IOS_DETAILED_EXECUTION_PLAN_READY**

基于当前仓库真实状态（`e4bac98`，95 files boundary PASS，127 Swift files，23 test files）。

## 2. 当前基础设施清单

| 层 | 组件 | 成熟度 | 产品可用 |
|---|---|---|---|
| UI | 4-tab App Shell + 38 prototype entries | 完成 | ✓ |
| UI | Search/Detail/TOC/ReaderView | 完成 | ✓ mock only |
| UI | BookSource list/detail/import | 完成 | ✓ fixture only |
| Data | ReaderCoreServiceProvider (5 modes) | 完成 | 需接 real service |
| Data | MockReaderCoreService (8 scenarios) | 完成 | test only |
| Data | OfflineReplayService (5 chapters) | 完成 | test/fallback |
| Gate | RealNetworkGate (default deny) | 完成 | keep |
| Gate | LiveProbeGate (12 rules) | 完成 | probe only |
| Gate | NetworkAccessController (8 checks) | 完成 | **product path** |
| Policy | UserNetworkPreference | 完成 | 需接 UI |
| Policy | SourceNetworkPolicy | 完成 | 需接真实书源 |
| Snap | SnapshotStore (path safety + placeholder) | 完成 | 需写真实数据 |
| Exec | ManualLiveProbeExecutor | 完成 | dev only |
| Exec | LiveFetchExecutor | 完成 | dev only |
| Test | 23 test files, mock flow passes | 完成 | keep |

## 3. 产品闭环 vs 当前差距

```
目标闭环: 书源管理 → 启用书源 → 联网搜索 → 详情 → 目录 → 正文 → 缓存 → 继续阅读

当前能走通: 书源管理(fixture) → 启用书源(fixture) → 搜索(mock) → 详情(mock) → 目录(mock) → 正文(mock)
缺失环节:              真实书源!        真实搜索!      真实详情!    真实目录!   真实正文!    缓存!  进度!
```

## 4. 里程碑详细任务分解

---

### M1: 单书源真实搜索 MVP — 5 tasks

**阻塞点**: 需要选定真实书源 URL。如果没有，M1 无法启动。

| # | 子任务 | 文件 | 预估 | 阻塞 | 依赖 |
|---|---|---|---|---|---|
| M1.1 | 选定候选源 + 创建 SourceNetworkPolicy | `SourceNetworkPolicy` 新 fixture | 1 session | 需用户提供书源 URL | 无 |
| M1.2 | controlledOnline search 接真实 SearchService | `ReaderCoreServiceProvider.swift` | 1 session | M1.1 | 已有 `performControlledOnlineSearch` |
| M1.3 | 保存真实搜索结果到 SnapshotStore | `SnapshotStore.swift` + provider | 1 session | M1.2 | 已有 `saveContent()` |
| M1.4 | Search UI 展示真实搜索结果 | `SearchView.swift`/`SearchViewModel.swift` | 1 session | M1.3 | 已有 NavigationLink→BookDetail |
| M1.5 | Codex 设备端验证 | Simulator + screenshot | Codex | M1.4 | — |

**验收**: 用户在书源 tab 启用书源 → 搜索 → UI 显示真实结果 → snapshot 已保存 → 断网可回放。

**禁止**: 不做 detail/TOC/content。不做多源。不自动刷新。

---

### M2: 单书源真实阅读闭环 — 6 tasks

**阻塞点**: M1 完成（真实搜索结果可用）。

| # | 子任务 | 文件 | 预估 | 依赖 |
|---|---|---|---|---|
| M2.1 | Detail 接真实数据 | `BookDetailView.swift`/`BookDetailViewModel.swift` | 1 session | M1 |
| M2.2 | Detail 保存 snapshot | snapshot store | 0.5 session | M2.1 |
| M2.3 | TOC 接真实数据 | `ChapterListView.swift`/`ChapterListViewModel.swift` | 1 session | M2.1 |
| M2.4 | Content 接真实数据 | `ReaderView.swift`/`ReaderViewModel.swift` | 1 session | M2.3 |
| M2.5 | 全链路失败 fallback | provider dispatch | 0.5 session | M2.1-4 |
| M2.6 | Codex 设备端全链路验证 | Simulator | Codex | M2.5 |

**验收**: Search → Detail → TOC → Content → ReaderView 正文可读。每步失败可 fallback。主底栏在 ReaderView 隐藏。

**禁止**: 不做缓存/进度。不做多源。

---

### M3: 缓存、离线阅读、阅读进度 — 5 tasks

**阻塞点**: M2 完成（真实数据链路可用）。

| # | 子任务 | 预估 | 依赖 |
|---|---|---|---|
| M3.1 | Search/Detail/TOC/Content 缓存写入 | 1 session | M2 |
| M3.2 | 缓存优先策略：命中不走网络 | 1 session | M3.1 |
| M3.3 | 阅读进度记录 + 恢复 | 1 session | M2.4 |
| M3.4 | 继续阅读入口（最近阅读 → ReaderView） | 0.5 session | M3.3 |
| M3.5 | Codex 设备端验证缓存放回 | Codex | M3.1-4 |

**验收**: 搜索后断网重搜仍可见结果。阅读进度保存后重启 App 可恢复。

---

### M4-M7: 后续里程碑（概要）

| M | 任务数 | 核心内容 |
|---|---|---|
| M4 多书源 | 4 | 多源搜索聚合、去重、源标识、健康检查 |
| M5 书源导入 | 3 | JSON 导入、本地校验、手动测试 |
| M6 产品打磨 | 5 | 加载/错误/重试 UI、书架、夜间模式、字体 |
| M7 Sync | 4 | WebDAV/RSS/Sync 独立接入 |

## 5. 阻塞点总览

| 阻塞 | 影响 | 解决 |
|---|---|---|
| **真实书源 URL 未选定** | M1 无法启动 | 用户提供候选书源 |
| **Reader-Core real service 需要 parser internals** | 真实搜索需要 parser | 现有 `ReaderCoreServiceFactory` 已封装，或使用 adapter |
| **用户网络偏好未接 UI** | 用户无法控制开关 | M1.4 或 M1 后用 Settings UI |
| **Codex 不可用** | 设备端验证无法执行 | 代码侧自测 + 等 Codex 恢复 |

## 6. Loop 规划（自动化开发循环）

### 6.1 日常开发 Loop

```
Session start
→ 1. git pull + check boundary + build（1 min）
→ 2. 执行当前 milestone 的下一个未完成子任务
→ 3. 修改代码 + 测试
→ 4. boundary check + build
→ 5. 如果 boundary/build 失败，修复并重新验证
→ 6. commit
→ 7. 更新 milestone progress
→ Session end
```

### 6.2 状态机

每个子任务状态: `PENDING → IN_PROGRESS → CODE_READY → DEVICE_VERIFIED → DONE`

状态文件: `docs/ui-handoff/ios/MILESTONE_STATUS.md`

### 6.3 每次 session 必须执行

```bash
git status --short
bash scripts/check_ios_boundary.sh
xcodebuild build -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

如果 build 失败，优先修复 build，暂停新功能。

## 7. Cron Loop 任务规划

### 7.1 项目健康检查（每 30 分钟）

```
cron: "*/30 * * * *"
task: build + boundary check
如果失败: 记录到 docs/ui-handoff/ios/HEALTH_LOG.md
如果不失败: no-op（不生成噪音）
```

### 7.2 每日代码状态（每天 09:00）

```
cron: "0 9 * * *"
task: 
1. git log --oneline -n 5
2. bash scripts/check_ios_boundary.sh
3. xcodebuild build
4. 写入 docs/ui-handoff/ios/DAILY_STATUS.md
```

### 7.3 Milestone 进度更新（每天 18:00）

```
cron: "18 18 * * *"
task:
1. 读取 MILESTONE_STATUS.md
2. 检查最近 commits
3. 更新完成的子任务状态
4. 如果当前 milestone 所有子任务 DONE，标记 milestone DONE
```

### 7.4 完整验证（每天 02:00）

```
cron: "0 2 * * *"
task:
1. boundary check
2. xcodebuild build  
3. 运行所有测试: xcodebuild test
4. git status 检查未提交改动
5. 写入 CI_STATUS.md
```

## 8. 即时可执行：下一个开发 session 的精确任务

### Session: M1.1 候选源选择与 SourceNetworkPolicy

**输入**（需要用户提供）: 1 个真实书源 URL。示例格式：
```
name: 笔趣阁
host: www.biquge.com
searchURL: https://www.biquge.com/search?q={keyword}
```

**Claude Code 执行步骤**:

1. 创建 `SourceNetworkPolicy` fixture 对应候选源
2. 确认 `host` 字段精确
3. 设置 `allowSearch = true`, `allowDetail = false`, `allowTOC = false`, `allowContent = false`（M1 只做 search）
4. 编写 `testSourcePolicyForCandidate` 测试
5. boundary + build
6. commit

**如果用户未提供候选源**: 记录 BLOCKED，等待用户。

## 9. 现有基础设施保留策略

| 保留 | 用途 |
|---|---|
| `boundary check` | 每次 commit 前 |
| `ServiceMode.mock` | 测试/CI 默认 |
| `OfflineReplayService` | 缓存降级 |
| `NetworkAccessController` | 产品路径 gate |
| `SnapshotStore` | 真实数据缓存 |
| 23 test files | 回归保护 |

| 不再扩展 | 原因 |
|---|---|
| `LiveProbeGate` | 5 层 gate 足够 |
| `ManualLiveProbeExecutor` | dev-only，够用 |
| `LiveFetchExecutor` | 产品路径用 provider controlledOnline |
| `RealNetworkGate` | 已有底层总闸 |

## 10. 风险与缓解

| 风险 | 缓解 |
|---|---|
| 用户未提供书源 URL | M1 BLOCKED，等待 |
| Reader-Core real service 需要 parser | 使用 adapter 层封装，不暴露到 UI |
| 书源不稳定 | snapshot + fallback offline replay |
| Codex 不可用 | 代码侧自测，文档化验证步骤 |
| 真实网络被 CI 误触 | `testSafeDefaultDeniesNetwork` 已有 |

## 11. 立即行动

1. 用户提供 1 个候选书源 URL
2. Claude Code 执行 M1.1
3. 后续自动进入 M1.2-M1.5
4. M1 DONE → M2
