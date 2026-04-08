# 项目状态 (PROJECT_STATUS)

## 项目定义

- 项目策略：Reader-Core first
- 壳层策略：iOS later
- 当前主线：Reader-Core 兼容内核开发
- 当前阶段：`core_contract_stabilization`
- 当前是否允许进入 iOS 阶段：`no`
- 判断原因：`P0 convergence executable verification` 仍待执行，当前状态保持 `OPEN`

## 当前事实基线

### 已闭环样本
- `sample_js_runtime_001`
- `sample_js_runtime_002`
- `sample_004`
- `sample_005`

### 已成熟能力
- CI 执行
- artifact 产出
- regression 回写
- writeback 审核
- compat_matrix 审计吸收

### 当前未覆盖能力
- Header
- Cookie
- ErrorMapping

## 最近一次动作

- `P0 policy structure converged (not verified)`
- 当前结论：
  - `samples/matrix/failure_taxonomy.yml` 已收敛为唯一一级 failureType 列表
  - `samples/matrix/compat_matrix.yml` 中 `SAMPLE-P1-POLICY-001/002/003` 统一为 `B/B/C`
  - `samples/reports/latest/policy_regression_summary.yml` 统一为 `NOT_VERIFIED + OPEN`
  - 当前仍是 `static-only validation`
  - `executable verification pending`

## Adapter Validation

- status: `recorded`
- platform: `macOS`
- adapterUsed: `MinimalHTTPAdapter`
- sampleId: `sample_004`
- 验证链路：`sample -> Core -> HTTPAdapter -> response -> parser -> expected`
- 边界：不处理业务逻辑，不做 cache/cookie/error mapping，不代表多平台支持完成

## Adapter Hardening

- status: `recorded`
- platform: `macOS`
- adapterUsed: `MinimalHTTPAdapter`
- validatedSamples:
  - `SAMPLE-P1-HEADER-001`
  - `SAMPLE-P1-COOKIE-001`
  - `SAMPLE-P1-ERROR-001`
- 说明：仅做多样本 contract 验证，不新增 adapter 功能，不实现多平台 adapter，不回改 Core

## P0 Policy Layer Convergence

- status: `static_only`
- validatedSamples:
  - `SAMPLE-P1-POLICY-001`
  - `SAMPLE-P1-POLICY-002`
  - `SAMPLE-P1-POLICY-003`
- verificationStatus: `NOT_VERIFIED`
- closureDecision: `OPEN`
- 说明：policy structure converged；`executable verification pending`

## Capability 状态

- Header: `IN_PROGRESS`
- Cache: `OPEN`
- Cookie: `IN_PROGRESS`
- ErrorMapping: `OPEN`

## 下一步唯一最优任务

- `P0 convergence executable verification`
- 目标说明：先在 macOS CI 重新执行 policy/error 相关 Swift 测试，保持 `OPEN` 直到回归通过。

## 当前不允许做的事

- 未经架构 rollout 方案确认直接进入具体壳层实现
- 将 HarmonyOS 简单等同于 Android
- 引入与当前主线无关的 UI / 平台集成
- 修改 A/B/C/D 兼容等级定义
- 未同步 taxonomy 就新增 failureType
- 引入 retry、fallback 或复杂错误策略并伪装为 Error Mapping
- 引入外部 GPL 代码或引用 Legado Android 实现

## Clean-Room 状态

- 本次仅依据仓库内部协议、样本资产结构、matrix/regression/status 文件收敛 failure taxonomy 与最小 policy layer contract
- 无外部 GPL 代码
- 无 Legado Android 实现引用
