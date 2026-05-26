# iOS Reader Long-term Product Roadmap

## 1. 总体结论

**IOS_READER_PRODUCT_ROADMAP_READY**

当前不是"产品完成"，而是基础设施和 mock/offline/controlled network 基线就绪。下一步从基建转向产品。

## 2. 当前状态判断

### 已完成

| 层 | 内容 | 状态 |
|---|---|---|
| App Shell | 书架/发现/书源/我的 4 tabs | ✓ |
| Prototype Gallery | 38 entries + Reader controls | ✓ |
| Mock Flow | Search→Detail→TOC→ReaderView 全 mock | ✓ |
| BookSource UI | 5 fixture 书源 + 详情 + 启用/停用 + 导入 | ✓ |
| Facade Boundary | provider mock 默认，parser internals 0 引用 | ✓ |
| Network Gates | RealNetworkGate/LiveProbeGate/RateLimiter | ✓ |
| Offline Replay | 5 chapters + 3 search results | ✓ |
| Controlled Network | UserNetworkPreference + SourceNetworkPolicy + NetworkAccessController | ✓ |
| Dry-run | controlledOnlineDryRun → offline replay | ✓ |
| Real path | controlledOnline → fake service (test-only) | ✓ |

### 尚未完成（产品缺口）

| 缺口 | 说明 |
|---|---|
| **真实书源接入** | 没有选定任何真实书源 |
| **真实搜索** | controlledOnline 路径存在但从未用真实数据验证 |
| **真实详情/目录/正文** | 只做了 search mock；detail/TOC/content 在 controlledOnline 下只走 offline replay |
| **缓存/快照持久化** | SnapshotStore 只有 placeholder；未保存真实 fetch 结果 |
| **阅读进度** | ReadingProgressStore 存在但未被 active flow 使用 |
| **多书源** | BookSource 列表只有 5 个 fixture |
| **书源导入验证** | 导入页面存在但只做 JSON decode，未验证真实可用性 |
| **继续阅读** | 无 |
| **产品级 UI 打磨** | loading/error/重试/缓存提示 需要完善 |

## 3. 产品目标

**最终闭环**：

```
书源管理 → 启用书源 → 联网搜索 → 书籍详情 → 目录 → 正文阅读 → 本地缓存 → 继续阅读
```

**核心原则**：
- 真实网络是产品一等能力，不是异常。
- 限制目标是受控（限频、缓存、可回退、可审计），不是禁止。
- 测试和 CI 默认不联网，产品路径允许联网。
- WebDAV/RSS/Sync 暂不混入。

## 4. 战略纠偏

**停止过度投入**：
- 不再堆安全 gate（已有 5 层 gate，足够）
- 不再重复 no-network 审计（边界已确认）
- 不再把真网视为异常（已从 Phase 4E 纠偏到 Phase 5）
- 不再写低价值测试证明"没有联网"

**加大投入**：
- 真实书源接入
- 产品可用路径打通
- 缓存和离线阅读体验
- UI 状态和错误提示

## 5. 长期里程碑

| M | 名称 | 目标 | 网络 | 优先级 |
|---|---|---|---|---|
| M1 | 单书源真实搜索 MVP | 选定候选源 → controlledOnline 真实 search → 保存 snapshot | 单次 controlled | P0 |
| M2 | 单书源真实阅读闭环 | Detail→TOC→Content→ReaderView 全链真实数据 | 单次 controlled | P0 |
| M3 | 缓存/离线/进度 | 搜索结果/章节缓存，断网可读，进度恢复 | 缓存优先 | P1 |
| M4 | 多书源搜索 | 多 enabled source，去重，健康状态 | 多源 controlled | P2 |
| M5 | 书源导入与验证 | 真实 JSON 导入 + 本地校验 + 手动测试 | 单源 probe | P2 |
| M6 | 产品体验打磨 | 搜索/加载/错误/重试/缓存提示/书架/夜间模式 | 产品化 | P2 |
| M7 | WebDAV/RSS/Sync | 同步和扩展能力 | 独立阶段 | P3 |

## 6. 里程碑验收标准

| M | 验收标准 | 不做什么 |
|---|---|---|
| M1 | 1 个真实书源 selected；controlledOnline 真实 search 返回结果；结果在 UI 可见；snapshot 已保存；test 用 fake；provider 默认仍 mock | 不做 detail/TOC/content；不做多源；不做自动刷新 |
| M2 | 同一书源 Detail/TOC/Content 全链 real data；ReaderView 正文可读；每一步可 fallback offline replay | 不做多源聚合；不做自动翻页；不做 WebDAV |
| M3 | search/detail/TOC/content 缓存可复用；断网读取缓存；阅读进度记录；继续阅读入口 | 不做云同步；不做缓存过期策略细节 |
| M4 | 多个 enabled source 参与搜索；disabled 不访问；结果按来源标识 | 不做复杂去重算法；不做源评分 |
| M5 | 导入 JSON 书源；本地校验；手动测试不影响生产 | 不做自动批量验证；不做源站爬取 |
| M6 | loading/error/重试 UI；缓存命中提示；书架操作；阅读设置可用 | 不做 UI 重构；不改变导航结构 |
| M7 | WebDAV 配置/备份；RSS 订阅；Sync 进度 | 不混入阅读主流程 |

## 7. 最近 3 个任务

### Task 1：单书源真实搜索候选源选择与接入

| 项目 | 内容 |
|---|---|
| 目标 | 选定 1 个低风险书源，接入 controlledOnline search |
| 输入 | 现有 ControlledNetworkPolicy、NetworkAccessController、ReaderCoreServiceProvider |
| 输出 | 选定书源的 SourceNetworkPolicy；controlledOnline search 可通过真实 search service 返回结果 |
| 验收 | test 用 fake service；provider 默认仍 mock；不退化 mock flow |
| 不做什么 | 不做 detail/TOC/content；不做多源；不自动刷新；不修改 Reader-Core |

### Task 2：真实 search 结果 UI 可见 + snapshot 保存

| 项目 | 内容 |
|---|---|
| 目标 | 用户在 UI 中看到真实搜索结果；结果保存为本地 snapshot |
| 输入 | Task 1 的 controlledOnline search path |
| 输出 | Search UI 显示 real results；SnapshotStore 保存真实结果 JSON；失败 fallback offline replay |
| 验收 | Codex 设备端验证 UI 可见 real results；snapshot 文件存在；断网可回放 |
| 不做什么 | 不做自动刷新；不做分页；不做缓存 TTL |

### Task 3：Detail + TOC + Content 真实数据链路

| 项目 | 内容 |
|---|---|
| 目标 | 从真实 search result 进入 detail，加载 TOC，打开章节正文 |
| 输入 | Task 1/2 的 search + BookDetailView/ChapterListView/ReaderView |
| 输出 | Detail/TOC/Content 在 controlledOnline 下走 real service；每一步可 fallback |
| 验收 | Codex 设备端全链路验证：Search → Detail → TOC → ReaderView 正文可读 |
| 不做什么 | 不做缓存/进度（那是 M3）；不做多源 |

## 8. 停止投入清单

| 停止项 | 原因 |
|---|---|
| 新增安全 gate | 已有 5 层（RealNetworkGate/LiveProbeGate/NetworkAccessController/RateLimiter/SnapshotStore path safety），足够 |
| 重复 no-network 审计 | 边界已确认，0 引用 parser internals，0 token/secret |
| 大量低价值测试 | 不再需要 30 个测试证明"没联网" |
| WebDAV/RSS/Sync | M7 才做，当前不混入 |
| 多书源聚合 | M4 才做，先单源闭环 |
| 复杂 UI 重构 | M6 才打磨，当前保持现有 UI |
| 把每步拆成过小 Phase | 当前 M1-M3 每个都应该是可验收的产品增量 |

## 9. 应保留但不再扩展的基础设施

| 组件 | 用途 | 说明 |
|---|---|---|
| RealNetworkGate | 底层网络总闸 | 保留，不扩展 |
| LiveProbeGate | 开发探针 | 保留，不用于产品搜索 |
| OfflineReplayService | 测试/缓存/降级 | 保留，M3 可能增强 |
| SnapshotStore | 快照保存 | 保留，M1-M2 开始写入真实数据 |
| NetworkAccessController | 产品级网络控制 | 保留，M1 开始用于产品路径 |
| boundary script | CI 检查 | 保留 |
| Provider mock default | 测试安全 | 保留 |

## 10. 下一步建议

**进入 M1：单书源真实搜索 MVP。**

立即行动：
1. 选定 1 个低风险候选书源
2. 创建对应的 SourceNetworkPolicy
3. 通过 controlledOnline + real search service 执行单次搜索
4. 保存搜索结果为本地 snapshot
5. Codex 设备端验证 UI 可见真实结果

不再继续 gate/审计/计划文档。
