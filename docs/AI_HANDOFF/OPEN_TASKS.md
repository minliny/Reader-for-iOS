# 开放任务 (OPEN_TASKS)

## 当前唯一最优任务

| ID | 任务名称 | 状态 | 优先级 | 前置依赖 | 风险点 | 验收标准 | 是否允许 AI 独立完成 |
|----|----------|------|--------|----------|--------|----------|----------------------|
| OT-001 | P0 convergence executable verification | in_progress | P0 | failure taxonomy 已收敛；policy/error 样本资产已更新；当前本机无 swift，尚未完成 executable verification | 未执行测试却继续标记通过；taxonomy-clean 改动与 matrix/report 不一致；跳过验证直接恢复 rollout | 在 macOS CI 重新执行 policy/error 相关 Swift 测试，并把状态保持为 OPEN 直到执行结果落地 | yes |

## 当前待办列表

### OT-001: P0 convergence executable verification
- 状态：`in_progress`
- 优先级：`P0`
- 前置依赖：`taxonomy = clean`；`policyLayerRegression = static_only`；`errorMappingRegression = static_only`
- 风险点：不得未执行测试就把 static-only 写成 executable verified；不得在 verification 之前恢复 Multiplatform rollout；不得把 HarmonyOS 简单等同于 Android
- 验收标准：
  - Run executable regression on macOS CI
  - Verify policy samples by executable tests
  - Keep state OPEN until regression passes
  - 把 `testsRun` 更新为 `true`
  - 把 `verificationStatus` 从 `NOT_VERIFIED` 改到执行后状态
  - 保持不实现平台 UI、不扩展 Adapter、不修改 taxonomy
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
- `SAMPLE-P1-POLICY-001` static-only 收敛完成，待 executable verification
- `SAMPLE-P1-POLICY-002` static-only 收敛完成，待 executable verification
- `SAMPLE-P1-POLICY-003` static-only 收敛完成，待 executable verification
- policy structure converged
- Multiplatform architecture skeleton 已落地，且 `platformImplementationDone=false`
- Platform adapter minimal validation 已完成，`platform=macOS`，且 `fullAdapterLayerImplemented=false`
- Adapter contract hardening 已完成，`platform=macOS`，`validatedSamples=3`
- P0 policy layer convergence 已形成 static-only 基线

## 当前状态约束

- 当前阶段：`core_contract_stabilization`
- 当前主线：`Reader-Core compatibility kernel development`
- 当前未覆盖能力：Header / Cookie / ErrorMapping
- 当前是否允许进入 iOS 阶段：`no`
- 判断原因：policy structure converged but executable verification pending
