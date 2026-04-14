# AI Handoff

## 当前唯一可信主线

- 分支：`main`
- 远端状态：`origin/main` 已与本地 `main` 对齐

## 已删除历史分支

- `claude/fervent-goldstine`
  - 原因：仅 1 个 ahead 提交，内容只是 5 份 non-js smoke report 回写
- `codex/main`
  - 原因：对应 GitHub PR #2 已 MERGED，分支仅为历史 head，不再适合作为任何主线参考
- `codex/cache-ci-evidence`
  - 原因：上一轮已确认被 `main` 完整覆盖并删除
- `codex-cache-ci-evidence-2407`
  - 原因：静态资产已在 `main`，Swift 差异为旧版契约/测试实现，已被 `main` 的后续架构 supersede
- `codex-policy-regression-verification-20260409`
  - 原因：policy 资产与 workflow 已在 `main`，关键 404 逻辑已在 `main`，分支 tip 代码相对 `main` 更旧，已被 supersede

## 阻塞点

- 当前 Windows 环境没有 `swift`，本轮无法做 Swift 编译/测试验证
- 无远端历史分支阻塞；后续工作直接基于 `main`

## 下一步

- 继续 Track D
- 以 `main` 为唯一可信主线推进 `M-IOS-7: Reader Flow Functional Validation`
- 若继续做仓库治理，优先处理 `codex-policy-regression-verification-20260409` 的 selective cherry-pick 审计

## Clean-Room

- 本轮仅做 Git 分支审计、远端清理和文档固化
- 未引入外部 GPL 代码
- 未复制、翻译或改写 Legado Android 源码
