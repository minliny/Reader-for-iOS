# 开放任务 (OPEN_TASKS)

## 当前唯一最优任务

| ID | 任务名称 | 状态 | 优先级 | 前置依赖 | 风险点 | 验收标准 | 是否允许 AI 独立完成 |
|----|----------|------|--------|----------|--------|----------|----------------------|
| OT-002 | Error mapping / Cache executable verification | pending | P3 | Header + Cookie VERIFIED + CLOSED | 不得新增 failureType；不得改 A/B/C/D 定义；不得改 package 结构 | testsRun=true, result=pass 才标 VERIFIED | yes |

## 当前待办列表

### OT-002: Error mapping / Cache executable verification
- 状态：`pending`
- 优先级：`P3`
- 前置依赖：`Header VERIFIED (runId 24200529880)`；`Cookie VERIFIED (runId 24200148174)`
- 风险点：不得新增 failureType；不得修改 A/B/C/D 定义；不得改 package 结构；不得扩展到 UI
- 验收标准：
  - Error mapping 有真实可执行测试
  - Cache 有真实可执行测试
  - testsRun=true, result=pass
  - 不破坏 Cookie / Header 已闭环状态
- 是否允许 AI 独立完成：`yes`

## 已完成事实，不得继续保留为待办

- `sample_js_runtime_001` 闭环完成
- `sample_js_runtime_002` 闭环完成
- `sample_004` 闭环完成
- `sample_005` 闭环完成
- `SAMPLE-P1-CACHE-001` 闭环完成
- `SAMPLE-P1-CACHE-002` 闭环完成
- `SAMPLE-P1-CACHE-003` 闭环完成
- `SAMPLE-P1-COOKIE-001` 闭环完成
- `SAMPLE-P1-COOKIE-002` 闭环完成
- `SAMPLE-P1-ERROR-001` 闭环完成
- `SAMPLE-P1-ERROR-002` 闭环完成
- `SAMPLE-P1-ERROR-003` 闭环完成
- `SAMPLE-P1-POLICY-001` executable verification 完成
- `SAMPLE-P1-POLICY-002` executable verification 完成
- `SAMPLE-P1-POLICY-003` executable verification 完成
- `SAMPLE-P1-HEADER-001` executable verification 完成
- `SAMPLE-P1-HEADER-002` executable verification 完成
- `SAMPLE-P1-HEADER-003` executable verification 完成
- `P0 policy executable verification` 完成，runId `24194591412`，result `pass`
- Cookie capability VERIFIED + CLOSED，runId `24200148174`，117 tests pass
- Header capability VERIFIED + CLOSED，runId `24200529880`，117 tests pass
- policy structure converged
- Core 继续作为统一事实基线
- Multiplatform architecture skeleton 已落地，且 `platformImplementationDone=false`
- Engineering architecture skeleton 已落地，且 `uiImplementationDone=false`
- Platform adapter minimal validation 已完成，`platform=macOS`，且 `fullAdapterLayerImplemented=false`
- Adapter contract hardening 已完成，`platform=macOS`，`validatedSamples=3`
- P0 policy layer convergence 已完成 executable verification
- SwiftPM circular dependency 已修复，ReaderPlatformAdapters 为 Core 内部 target

## 当前状态约束

- 当前阶段：`core_contract_stabilization`
- 当前主线：`Reader-Core compatibility kernel development`
- 当前未覆盖能力：ErrorMapping（executable verification 待执行）
- 当前是否允许进入 iOS 阶段：`no`
- 判断原因：仍处于 Reader-Core first，Error mapping / Cache executable verification 尚未完成
