# AI Handoff

## 当前唯一可信主线

- 分支：`main`
- 仓库角色：`Reader-iOS 主仓`
- 当前主线：`post-split stabilization audit / boundary and CI hardening`

## 当前 handoff 语义

- 当前任务不是继续拆仓，而是验证拆仓后双仓是否真正稳定。
- 本仓只允许处理：
  - 审计
  - split 后结构/依赖/CI/文档问题修复
  - boundary gate / governance 加固
- 不允许：
  - 新功能开发
  - Core 业务逻辑修改
  - 扩 scope

## 下一步

- 修复 Reader-Core standalone CI failures
- 评审 Reader-iOS remote package dependency 切换窗口
- 维持 Reader-iOS boundary gate 与 docs semantics 稳态

## Active Handoff Entry

- `docs/PROJECT_STATE_SNAPSHOT.yaml`
- `docs/AI_HANDOFF/PROJECT_STATUS.md`
- `docs/AI_HANDOFF/OPEN_TASKS.md`
- `docs/POST_SPLIT_STABILIZATION_AUDIT.md`

## Clean-Room

- 本轮仅做 post-split stabilization audit 与结构/CI/文档/边界加固
- 未引入外部 GPL 代码
- 未复制、翻译或改写 Legado Android 源码
