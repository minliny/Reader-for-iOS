# iOS Real Source Executable Plan

## 1. 可行性结论

**可支撑真实书源全流程实现。**

当前基础设施已具备：
- `ReaderCoreServiceFactory` 已支持 `makeSearchService/makeTOCService/makeContentService`
- `DefaultTOCService`/`DefaultContentService` 使用 `NetworkPolicyLayer` HTTP fetch + `NonJSParserEngine` 解析
- 星星小说网 BookSource JSON 已有 `ruleToc`/`ruleContent`/`ruleSearch` 规则（CSS selector 格式）
- `NetworkAccessController` 已支持用户偏好 + 书源策略评估
- `SnapshotStore` 已支持 search/toc snapshot，可快速扩展 detail/content
- Provider 已有 `controlledOnline` 模式
- UI 链（SearchView→BookDetailView→ChapterListView→ReaderView）已就绪

## 2. 阻塞点分析

| # | 阻塞点 | 严重度 | 是否阻塞 | 解决 |
|---|---|---|---|---|
| B1 | `getBookDetail/getChapterList/getChapterContent` 缺少 `controlledOnline` 分发 | P0 | 阻塞 M2 | Provider 加 3 个分支 |
| B2 | `prepareControlledOnlineSearchService()` 只创建 SearchService | P0 | 阻塞 M2 | 改为统一创建 Search+TOC+Content |
| B3 | BookSource JSON `ruleBookInfo` 为空 `{}` | P2 | 不阻塞 | 搜索结果的 SearchResultItem 已有 title/author/intro，足够 detail 展示 |
| B4 | `canUseRealService` 走 RealNetworkGate（默认 denied） | P0 | 阻塞 | controlledOnline 走 NetworkAccessController，不依赖 `canUseRealService` |
| B5 | 真实网络请求需要星星小说网可访问 | P1 | 阻塞设备端验证 | Fake service 可覆盖代码侧；设备端需网络可用 |
| B6 | `NonJSParserEngine` 在 ReaderCoreParser | P1 | 不阻塞代码 | 在 CoreBridge adapter 层引用是允许的 |
| B7 | 当前没有 `prepareControlledOnlineTOC/Content` | P0 | 阻塞 M2 | 合并到统一方法 |
| B8 | Content snapshot 未实现 | P2 | 不阻塞 | M2 末尾补充 |

## 3. M2 详细任务分解

### M2-A: Provider controlledOnline 全路径 (1 session)

**目标**: `searchBooks/getBookDetail/getChapterList/getChapterContent` 全部支持 `controlledOnline`。

**当前代码路径**:

```
searchBooks: canUseRealService → controlledOnline → controlledOnlineDryRun → offlineReplay → mock ✓ (已完整)
getBookDetail: canUseRealService → (controlledOnlineDryRun|offlineReplay) → mock ✗ (缺 controlledOnline)
getChapterList: canUseRealService → (controlledOnlineDryRun|offlineReplay) → mock ✗
getChapterContent: canUseRealService → (controlledOnlineDryRun|offlineReplay) → mock ✗
```

**修改文件**:
- `ReaderCoreServiceProvider.swift`: 
  - `getBookDetail`: 增加 `mode == .controlledOnline` → NetworkAccessController → real service
  - `getChapterList`: 同上
  - `getChapterContent`: 同上
  - `prepareControlledOnlineSearchService()` → 重命名/扩展为 `prepareControlledOnlineAllServices()`

**验证**: fake service test — all 3 paths call fake when allowed, fallback when denied.

**代码量**: ~40 lines added, ~10 lines modified.

### M2-B: Snapshot + BookSource JSON (0.5 session)

**Snapshots**:
- `SnapshotStore.saveDetailSnapshot/saveContentSnapshot`
- Provider dispatcher 内保存（同 search 逻辑）

**BookSource JSON**:
- 当前 `ruleBookInfo: {}` → 保持（search result 已有 title/author/intro）
- `ruleToc`/`ruleContent` 已有基础规则
- 可选：补全 `ruleBookInfo` 的 CSS selector

**修改文件**: `SnapshotStore.swift` (+2 methods), BookSource JSON (minor)

**代码量**: ~30 lines.

### M2-C: ViewModels + Integration Tests (1 session)

**ViewModels**:
- `SearchViewModel.search()`: 已走 `provider.searchBooks()` — 无需修改
- `BookDetailViewModel.loadDetail()`: 已走 `provider.getBookDetail()` — 无需修改
- `ChapterListViewModel.loadChapters()`: 已走 `provider.getChapterList()` — 无需修改
- `ReaderViewModel.loadContent()`: 已走 `provider.getChapterContent()` — 无需修改

**结论**: ViewModels 代码不需要修改！只要 provider dispatcher 打通，UI 自动获得 controlledOnline 能力。

**Tests**: 10-15 integration tests covering:
1. controlledOnline search → detail → TOC → content 全链路 fake service
2. Each step's denied fallback
3. Snapshot save/load per step
4. M1 regression

## 4. 开发 Loop 规划

### Session Loop（每次 Claude Code session 执行）

```
Session Start
├─ 1. boundary check + build                         （1 min）
├─ 2. 检查当前 M2 状态                                （0.5 min）
├─ 3. 选择下一个 PENDING 子任务                        （0.5 min）
├─ 4. 实现子任务                                      （main work）
│   ├─ 修改代码
│   └─ 添加测试
├─ 5. boundary check + build                          （1 min）
│   └─ 如果失败 → 修复 → 重新 build
├─ 6. commit                                          （0.5 min）
└─ 7. 更新 MILESTONE_STATUS.md                        （0.5 min）
```

### M2 子任务 和 预估 session

| # | 任务 | 预估 | 依赖 | 阻塞 |
|---|---|---|---|---|
| M2-A1 | getBookDetail 增加 controlledOnline 分支 | 15 min | 无 | — |
| M2-A2 | getChapterList 增加 controlledOnline 分支 | 15 min | 无 | — |
| M2-A3 | getChapterContent 增加 controlledOnline 分支 | 15 min | 无 | — |
| M2-A4 | prepareControlledOnlineAllServices() | 15 min | A1-A3 | — |
| M2-A5 | M2-A fake service tests (6-8 tests) | 15 min | A4 | — |
| M2-B1 | SnapshotStore detail/content save/load | 15 min | A4 | — |
| M2-B2 | Snapshot tests | 10 min | B1 | — |
| M2-B3 | BookSource JSON 补全（如需要） | 10 min | — | B3 |
| M2-C1 | Integration tests (8-10 tests) | 20 min | A5+B2 | — |
| M2-C2 | M2 report + milestone update | 10 min | C1 | — |

**总计**: M2-A ~1.5h, M2-B ~35min, M2-C ~30min ≈ **2.5-3 sessions**.

## 5. Cron Loop 任务规划

### 健康检查 (daily 09:03 — 已有 job 247226d6)

```
boundary check + build + git log
→ DAILY_BUILD_STATUS.md
失败时 flag WARNING
```

### 进度更新 (daily 17:57 — 已有 job 9c224438)

```
读取 MILESTONE_STATUS.md
检查最近 commits
更新完成的子任务状态
如果 M2/M3 全部 CODE_READY → 标记 milestone completion
```

### 全量测试 (daily 02:00 — 新增)

```
boundary + build + xcodebuild test (all test targets)
→ CI_STATUS.md
失败时 flag CI_FAILURE
```

使用 `CronCreate` 设置：
```
cron: "7 2 * * *"
task: (1) boundary check (2) xcodebuild build (3) xcodebuild test -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ReaderAppTests 2>&1 | tail -20 (4) Append results to docs/ui-handoff/ios/CI_STATUS.md
```

## 6. 当前状态和下一步

| Item | Status |
|---|---|
| M1 | CLOSED |
| M2.1 Detail shell | CODE_READY |
| M2.2 TOC shell | CODE_READY |
| M2-A Provider controlledOnline | PENDING ← **下一步** |
| M2-B Snapshot + JSON | PENDING |
| M2-C Integration tests | PENDING |
| M3-M8 | PENDING |

## 7. 阻塞点解决状态

| 阻塞 | 解决方案 | 状态 |
|---|---|---|
| B1: detail/toc/content 缺 controlledOnline 分支 | M2-A 实现 | 计划中 |
| B2: 只创建 SearchService | M2-A4 改为 AllServices | 计划中 |
| B3: ruleBookInfo 为空 | 搜索结果已有 title/author/intro | 接受 |
| B4: canUseRealService 走 RealNetworkGate | controlledOnline 走 NetworkAccessController | 已解决 |
| B5: 真实网络不可用 | Fake service 覆盖代码侧测试 | 代码侧可行 |
| B6: NonJSParserEngine | CoreBridge adapter 层允许引用 | 已确认 |
| B7: 缺 TOC/Content 创建方法 | M2-A4 | 计划中 |
| B8: Content snapshot 缺 | M2-B1 | 计划中 |

## 8. 即时行动

**立即执行 M2-A1**: 进入 `ReaderCoreServiceProvider.swift`，为 `getBookDetail` 增加 `controlledOnline` 分发分支。
