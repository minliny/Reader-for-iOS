# 技术决策 (DECISIONS)

> support-only 文档；不是 active prompt entry，不参与唯一 active prompt chain。

## 当前已确认决策

| 决策项 | 内容 | 状态 |
|--------|------|------|
| 当前仓库角色 | Reader-iOS 主仓 | 已确认 |
| 上游 Core 仓 | Reader-Core | 已确认 |
| 当前阶段 | `post_split_stabilization_audit` | 已确认 |
| prompt 治理 | active prompt 仅保留 post-split 版本 | 已确认 |
| iOS 资产语义 | Reader-iOS mainline | 已确认 |
| 依赖方向 | Reader-iOS -> Reader-Core public package/products only | 已确认 |

## Prompt Governance 决策

1. 不再把 pre-split 主线口径作为 active prompt 时态。
2. 不再继续使用任何以 pre-split iOS feature phase 为默认下一步的 handoff prompt。
3. 历史 prompt 必须归档到 `archive/prompts/legacy/`，不得无痕删除。
4. 当前 active prompt set 仅由 post-split Reader-iOS 治理文档组成。
5. Reader-Core 与 Reader-iOS 长期保持独立治理 prompt。

## 当前不允许漂移的规则

1. 不允许将当前阶段重新表述为 pre-split iOS feature 推进期
2. 不允许把 iOS gate 文档继续作为主仓当前主线状态
3. 不允许遗漏已闭环样本
4. 不允许在状态文件中出现 split-era 与 pre-split 语义混写
5. 不允许修改 A/B/C/D 兼容等级定义
6. 不允许新增 failure taxonomy 而不更新配置
7. 不允许引入外部 GPL 代码或引用 Legado Android 实现

## Clean-Room 结论

- 本次决策文件仅记录仓库内部状态与治理结论
- 无外部 GPL 代码
- 无 Legado Android 实现引用
