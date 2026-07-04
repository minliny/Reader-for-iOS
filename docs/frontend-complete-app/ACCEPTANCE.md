# Reader UI Contract 验收门槛

本文档逐项回答 [CONTRACT_FIRST_NATIVE_UI_PLAN.md](./CONTRACT_FIRST_NATIVE_UI_PLAN.md) §10 合并门槛 7 问，
标注 Reader UI 仓库范围内的完成度与剩余缺口。

Reader UI 仓库是 UI Contract 源，不是生产运行时。验收范围仅限：
- `contracts/` 下的 schema、fixtures、tests
- `tools/codegen/` 的 codegen 脚本
- `generated/` 下的三端生成类型
- `frontend-demo/verify/contract/` 的 demo 一致性校验

## §10 合并门槛 7 问

### 1. 这个状态属于 DomainState、UiState 还是 EphemeralState？

- **DomainState**：归 `Reader-Core-Native`，由 `core-command` / `core-event` / `progress-location` / `content` / `sync-conflict` schema 定义形状
- **UiState**：归 Platform Interaction Reducer，由 `ui-state` schema 定义 9 必填字段 + 派生状态，三层状态归属见 [STATE_OWNERSHIP.md](./STATE_OWNERSHIP.md)
- **EphemeralState**：归 Native UI，不进入本仓 schema（dragOffset、scrollPixel、layoutMeasurement 等）

Reader UI 仓库不持有任何运行时状态。schema 只定义形状与 enum，不定义运行时实例。

### 2. 是否已经进入 schema？

**Phase 1 契约基础（6 schema）**：
- ✓ `route.schema.json` —— 139 个 RouteId
- ✓ `ui-event.schema.json` —— 209 个 UiEventType
- ✓ `ui-state.schema.json` —— 9 必填字段 + 派生状态
- ✓ `view-state.schema.json` —— 64 个 ComponentType
- ✓ `motion.schema.json` —— 84 个 MotionId
- ✓ `token.schema.json` —— 12 个 TokenCategory

**Phase 2 Core bridge 规划契约（6 schema）**：
- ✓ `core-command.schema.json` —— 45 个 CoreCommandType
- ✓ `core-event.schema.json` —— 69 个 CoreEventType
- ✓ `host-request.schema.json` —— 31 个 HostRequestType
- ✓ `progress-location.schema.json` —— Locator + ProgressSource
- ✓ `content.schema.json` —— Block 模型（8 种 BlockType）
- ✓ `sync-conflict.schema.json` —— 5 种冲突类型 + 5 种 resolution

**Phase 1 收尾（1 schema）**：
- ✓ `state-rule.schema.json` —— 5 种 kind（mutex / async-guard / required-with / forbidden-with / transition-guard）

**FFI 协议**：
- ✓ `ffi-protocol-version.md` —— FFI 协议版本 1.0.0

### 3. 三端生成类型是否通过？

**13 个 schema × 3 端 = 39 个 generated 文件**：
- ✓ `generated/swift/` —— 13 个 .swift 文件
- ✓ `generated/kotlin/` —— 13 个 .kt 文件
- ✓ `generated/arkts/` —— 13 个 .ets 文件

校验方式：
- `node --test contracts/tests/codegen-consistency.test.mjs` —— 23 项测试，校验三端 generated 文件的 enum 值与 schema 一致
- `node tools/codegen/generate.mjs` —— 可重复生成，不依赖本机绝对路径

### 4. reducer 是否有 golden test？

**Reader UI 仓库范围内**：暂不提供 reducer golden test。

原因：reducer 归 Platform Interaction Reducer（iOS / Android / HarmonyOS 各自仓库），不在 Reader UI 仓库范围内。
Reader UI 仓库提供的是 `state-rule.fixtures.json`（13 项规则），定义 reducer 必须遵守的约束。
三端 reducer 实现时，应基于这些规则编写本地 golden test。

当前 `state-rule.fixtures.json` 覆盖：
- overlay 互斥
- activeSession 互斥
- loading async guard（禁止 route 切换）
- overlay async guard（禁止 tab 切换）
- TTS/auto-page session 互斥
- readerMode 转移限制
- overlay 转移限制（经 null 中转）
- 首次开屏 async guard
- 搜索 loading async guard
- sync loading async guard
- error 与 pageState 关联

### 5. UI 是否只渲染 ViewState？

**Reader UI 仓库范围内**：`view-state.schema.json` 定义了 64 个 ComponentType，覆盖 AppShell、main tabs、bookshelf→reader、reader overlay、session、focus、RSS、source、search、sync、conflict、offline 链路。

三端 Native UI 是否只渲染 ViewState，由各端仓库自验。Reader UI 仓库通过 `view-state.fixtures.json`（35 项）提供可渲染状态样本，三端可作为渲染输入。

### 6. 是否绕过了 Core 或 Host Adapter？

**Reader UI 仓库范围内**：不绕过。

- Core 业务事实源由 `Reader-Core-Native` 持有，本仓 `core-command` / `core-event` / `progress-location` / `content` / `sync-conflict` schema 只定义 Reader UI 侧 Core bridge 规划形状，不实现业务逻辑
- `CoreCommand` / `CoreEvent` 不等于 Reader-Core-Native 当前协议已经完全对齐；后续仍需 Core bridge mapping / 协议收敛，把契约项逐项映射到真实 Core 命令、事件、错误与 Host 边界
- Host Adapter 能力由三端实现，本仓 `host-request` schema 只列能力清单 enum，不实现平台调用
- `ffi-protocol-version.md` 只描述 FFI 入口形状，不写 Rust 代码

### 7. 是否会造成三端行为漂移？

**Reader UI 仓库范围内**：通过契约约束降低漂移风险。

- 三端从同一套 schema 生成类型，schema breaking change 会触发三端编译或测试失败
- `state-rule.fixtures.json` 定义统一的状态约束，三端 reducer 必须遵守
- `phase1-slice.test.mjs`（40 项）校验 6 个优先链路（Slice 1-6）在 fixtures 中的覆盖完整
- `demo-consistency.test.mjs`（5 项）校验 frontend-demo 与 schema 的一致性，baseline unknown=209 可追踪

剩余风险：
- 三端 reducer 实现可能对同一 StateRule 有不同解释（需 Phase 3 golden test 验证）
- demo 中 209 个 id 未在 schema 中（需产品决策是否补入）

## 当前完成度汇总

| 阶段 | 状态 | 仓库范围 |
|---|---|---|
| Phase 0 架构冻结 | ✓ 完成 | Reader UI/contracts |
| Phase 1 契约基础 | ✓ 完成（6 schema + codegen + tests + Slice 1-6 fixtures + StateRule） | Reader UI |
| Phase 2 Core bridge 规划契约 | ✓ Reader UI 侧完成（6 schema + codegen + tests + FFI 协议）；跨仓 Core bridge mapping / 协议收敛未完成 | Reader UI + Reader-Core-Native |
| Phase 3 三端 reducer 落地 | ✗ 未开始（归三端仓库） | iOS / Android / HarmonyOS |
| Phase 4 Host Adapter 补齐 | ✗ 未开始（归三端仓库） | iOS / Android / HarmonyOS |
| Phase 5 一致性验证 | 部分（contract test ✓ / reducer golden test ✗ / core protocol test ✗ / device smoke ✗） | 跨仓 |

## 测试与校验入口

```bash
# 全量契约测试
node --test contracts/tests/*.test.mjs
# 当前结果：143 tests / 143 pass / 0 fail

# fixtures 校验
node contracts/tests/validate.mjs

# codegen 重生成
node tools/codegen/generate.mjs

# demo 一致性校验
node frontend-demo/verify/contract/verify-demo-contract-consistency.mjs
```

## 版本

见 [VERSION.json](./VERSION.json)。当前 1.3.0。
