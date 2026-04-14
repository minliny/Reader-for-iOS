# 技术决策 (DECISIONS)

## 当前已确认决策

| 决策项 | 内容 | 状态 |
|--------|------|------|
| 项目策略 | Reader-Core first | 已确认 |
| 壳层策略 | iOS later | 已确认 |
| 当前主线 | Reader-Core 兼容内核开发 | 已确认 |
| 当前阶段 | `core_contract_stabilization` | 已确认 |
| 开发方式 | clean-room，不复用 Legado Android 实现 | 已确认 |
| 当前已闭环样本 | `sample_js_runtime_001`、`sample_js_runtime_002`、`sample_004`、`sample_005` | 已确认 |
| Header capability | 通过回归闭环确认为 CLOSED | 已确认 |
| 下一步唯一最优任务 | `Cookie capability closure` | 已确认 |

## 当前未覆盖能力

- Cookie
- Cache
- Error mapping

## 自动状态更新决策

以下动作被定义为“开发步骤完成”，一旦发生必须同步状态文件：

- regression 正式回写
- writeback 完成
- compat_matrix 审计确认
- 新样本闭环完成

必须同步更新：

- `docs/PROJECT_STATE_SNAPSHOT.yaml`
- `docs/AI_HANDOFF/PROJECT_STATUS.md`
- `docs/AI_HANDOFF/OPEN_TASKS.md`

## 当前不允许漂移的规则

1. 不允许将当前阶段重新表述为 iOS 先行
2. 不允许遗漏已闭环样本
3. 不允许在 `OPEN_TASKS.md` 中保留已完成任务
4. 不允许在三份状态文件中出现不一致事实
5. 不允许修改 A/B/C/D 兼容等级定义
6. 不允许新增 failure taxonomy 而不更新配置
7. 不允许引入外部 GPL 代码或引用 Legado Android 实现

## Clean-Room 结论

- 本次决策文件仅记录仓库内部状态与治理结论
- 无外部 GPL 代码
- 无 Legado Android 实现引用
