# AI Handoff

## 当前唯一可信主线

- 分支：`main`
- 仓库角色：`Reader-Core transition host`
- 当前主线：`split-era governance / reader-ios bootstrap preparation`

## 当前 handoff 语义

- 本仓当前不继续推进新的 iOS feature phase。
- iOS 资产仍在仓内，但归属语义为 `pending migration to future Reader-iOS repo`。
- Core frozen contract 继续由当前主仓维护。
- 当前 active handoff 面向 RS-* 治理任务，不再面向任何 pre-split iOS feature phase。
- 当前 active handoff 已进入 `RS-004 Reader-iOS Bootstrap Preparation`。

## 下一步

- RS-004 Reader-iOS Bootstrap Preparation
- RS-005 Physical Repo Split Execution

## Reader-iOS Bootstrap Entry

- `docs/READER_IOS_BOOTSTRAP_PLAN.md`
- `docs/READER_IOS_DEPENDENCY_BOOTSTRAP.md`
- `docs/READER_IOS_MIGRATION_MANIFEST.md`
- `docs/READER_IOS_REPO_INIT_CHECKLIST.md`
- `docs/AI_HANDOFF/PROJECT_STATUS.md`
- `docs/AI_HANDOFF/OPEN_TASKS.md`

## Split Preconditions Already Frozen

- `RS-002 Docs Split = PASS`
- `RS-003 Workflow Split = PASS`
- 当前任何 iOS 变更仅服务于 split/bootstrap，不得扩张为新的 iOS feature mainline。

## Legacy Prompt Policy

- legacy prompt 仅允许存在于 archive-only 区域
- active handoff 不得引用 archive prompt 内容或旧阶段标记

## Clean-Room

- 本轮仅做 prompt governance cleanup 与 split-era handoff 收敛
- 未引入外部 GPL 代码
- 未复制、翻译或改写 Legado Android 源码
