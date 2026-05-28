# iOS Real Source Full Flow Development Plan

## 1. 总体结论

**IOS_REAL_SOURCE_FULL_FLOW_DEVELOPMENT_PLAN_READY**

## 2. 当前仓库状态判断

### 已完成

| 层 | 状态 |
|---|---|
| M1 单书源搜索 | CLOSED — Search + controlledOnline + SnapshotStore + Codex verified |
| M2.1 Detail shell | CODE_READY — sourceName 传入，latestChapter 占位 |
| M2.2 TOC shell | CODE_READY — sourceName 传入，TOC snapshot |
| Network infra | RealNetworkGate / Controller / SnapshotStore / OfflineReplay / controlledOnline search |

### 当前最大缺口

| 缺口 | 详情 |
|---|---|
| **Detail/TOC/Content 没有 controlledOnline path** | `getBookDetail`/`getChapterList`/`getChapterContent` dispatcher 只有 `canUseRealService → offlineReplay → mock`，没有 `controlledOnline` 分支 |
| **没有 prepareControlledOnlineTOC/Content** | 只有 `prepareControlledOnlineSearchService()`，TOC/Content service 未创建 |
| **`canUseRealService` 永远 false** | 依赖 `RealNetworkGate`，默认 denied |
| **BookSource JSON ruleBookInfo 为空** | `{}` — detail 规则缺失，但 TOC/Content 规则已有基础 |
| **UI 使用 mock 数据** | Detail/TOC/ReaderView 都从 mock/offlineReplay 取数据 |
| **Content snapshot 未保存** | SnapshotStore 有 Search + TOC，无 Content |

## 3. 产品目标

```
书源管理 → 启用书源 → 联网搜索 → 详情 → 目录 → 正文阅读 → 缓存 → 继续阅读
```

## 4. 战略纠偏

**停止**：微任务拆分、gate 扩展、重复审计、no-network 证明。
**加速**：真实书源全流程闭环。

## 5. 长期里程碑

| M | 名称 | 目标 |
|---|---|---|
| M2 | 单书源真实阅读闭环 | Search → Detail → TOC → Content → ReaderView |
| M3 | 缓存/离线/继续阅读 | search/detail/toc/content cache + progress + continue reading |
| M4 | 书架与阅读资产 | 真实结果加入书架、进度、最近阅读 |
| M5 | 多书源搜索 | 多 enabled source、去重、健康检查 |
| M6 | 书源导入验证 | Legado JSON import + validate + manual test |
| M7 | 产品打磨 | loading/error/retry/夜间模式/字体/书架 |
| M8 | WebDAV/RSS/Sync | 独立阶段 |

## 6. M2 详细计划：单书源真实阅读闭环

### 缺口根因

`getBookDetail`/`getChapterList`/`getChapterContent` 的 dispatcher 缺少 `controlledOnline` 分支：

```swift
// 当前
if canUseRealService { ... }  // ← 永远 false（RealNetworkGate denied）
if mode == .controlledOnlineDryRun || mode == .offlineReplay { ... } // ← 走 replay
return mockService.xxx()

// 需要
if canUseRealService { ... }
if mode == .controlledOnline { ... }  // ← 缺失！
if mode == .controlledOnlineDryRun || mode == .offlineReplay { ... }
return mockService.xxx()
```

同时 `prepareControlledOnlineSearchService()` 只创建 SearchService，TOC/Content service 未创建。

### M2 合并为 3 个较大任务

#### M2-A：补全 controlledOnline detail/toc/content service path

**目标**：provider 的 getBookDetail/getChapterList/getChapterContent 支持 controlledOnline 分支 + 创建 real TOC/Content service。

**工作**：
1. `getBookDetail`/`getChapterList`/`getChapterContent` dispatcher 增加 `mode == .controlledOnline` 分支
2. 新增 `prepareControlledOnlineAllServices()` 一次性创建 Search+TOC+Content
3. 或扩展现有 `prepareControlledOnlineSearchService()` 为统一方法
4. 分支内通过 NetworkAccessController 检查后使用 realTOCService/realContentService
5. Fallback 保持 offlineReplay/mock
6. Provider 默认仍 mock

**验证**：fake service 测试通过；denied 时回退 offlineReplay。

**不做**：不修改 Reader-Core；不启用 real 默认；不抓真实网站。

#### M2-B：BookSource JSON 补齐 + controlledOnline snapshot

**目标**：完善 BookSource JSON 的 detail/toc/content 规则；snapshot save 覆盖全链路。

**工作**：
1. 补全 `xingxingxsw.search-only.json` → 重命名为真实书源 JSON（保留 search + 完善 ruleBookInfo/ruleToc/ruleContent）
2. SnapshotStore 已有 search/toc snapshot；补齐 detail + content snapshot
3. Provider dispatcher 内 save snapshot 同 search 逻辑

**验证**：JSON 字段完整；snapshot save/load 全链路通过。

**不做**：不真实请求网站；不过度泛化 snapshot 框架。

#### M2-C：UI 全链路 real data + 测试

**目标**：Search → Detail → TOC → ReaderView 全链路展示 controlledOnline 结果。

**工作**：
1. BookDetailViewModel 在 controlledOnline 下使用 provider.getBookDetail
2. ChapterListViewModel 在 controlledOnline 下使用 provider.getChapterList
3. ReaderViewModel 在 controlledOnline 下使用 provider.getChapterContent
4. UI 层不需要修改（SearchResultRowView/BookDetailView/ChapterListView/ReaderView 已就绪）
5. 新增 M2 integration tests（10-15 tests, not 40）
6. Codex 设备端验证

**验证**：全链路 controlledOnline fake service → UI 展示完整；denied fallback 可用。

**不做**：不做设备端验证以外的 UI 重构。

### M2 验收标准

| 检查项 | 标准 |
|---|---|
| controlledOnline search | 返回真实/fake 结果 |
| controlledOnline detail | 返回真实/fake detail |
| controlledOnline TOC | 返回真实/fake 5+ 章 |
| controlledOnline content | 返回真实/fake 正文 |
| ReaderView | 显示正文，主底栏隐藏 |
| Snapshot | search/detail/toc/content 保存 |
| Fallback | denied → offlineReplay |
| Provider default | `.mock` |
| boundary/build | PASS |

## 7. 最近 3 个开发任务

### Task A：controlledOnline detail/toc/content provider path

| 项目 | 内容 |
|---|---|
| 目标 | provider 的 detail/toc/content 支持 controlledOnline |
| 输入 | 现有 provider 代码、NetworkAccessController、ReaderCoreServiceFactory |
| 输出 | `getBookDetail`/`getChapterList`/`getChapterContent` 有 controlledOnline 分支；`prepareControlledOnlineAllServices()` |
| 验收 | fake service test 通过；denied → offlineReplay |
| 不做什么 | 不修改 Reader-Core；不改 UI；不抓真实网站 |

### Task B：BookSource JSON + snapshot 全链路

| 项目 | 内容 |
|---|---|
| 目标 | 补全 JSON；search/detail/toc/content snapshot |
| 输入 | 现有 xingxingxsw JSON、SnapshotStore |
| 输出 | 完整 JSON；detail/content snapshot save/load |
| 验收 | JSON 字段不空 snapshot 全链路 |
| 不做什么 | 不真实请求；不泛化 |

### Task C：UI 全链路 + integration tests

| 项目 | 内容 |
|---|---|
| 目标 | ViewModels 接 controlledOnline；integration tests |
| 输入 | Task A + B 产物 |
| 输出 | BookDetailVM/TOCVM/ReaderVM 走 controlledOnline；M2 tests |
| 验收 | 全链路 fake service → UI；denied fallback |
| 不做什么 | 不 UI 重构；不设备端验证 |

## 8. 停止投入清单

| 停止项 | 原因 |
|---|---|
| 新增 gate 框架 | 已有 5 层 |
| 重复 no-network 审计 | 已确认 |
| 微任务拆分（10+ per M） | 合并为 2-3 个 |
| 过早多书源 | M5 |
| 过早 WebDAV/RSS/Sync | M8 |
| 复杂 UI 重构 | M7 |
| 低价值测试堆叠 | 10-15 integration tests 足够 |

## 9. 风险与处理

| 风险 | 处理 |
|---|---|
| 星星小说网 ruleBookInfo 为空 | detail 回退到 search result 已有字段 |
| 源站结构变化 | snapshot + offlineReplay fallback |
| Reader-Core API 不足 | adapter 层封装；不修改 Core |
| 正文解析失败 | fallback offlineReplay/mock content |
| snapshot 格式不稳定 | JSON codable + version field |
| UI navigation 空白 | 不嵌套 NavigationStack |
| 测试误触网络 | fake service + gate denied in tests |

## 10. 下一步建议

**立即进入 M2-A：controlledOnline detail/toc/content provider path。**

不要继续 M1 收尾工作。不要继续扩展 gate 框架。
