# 项目状态 (PROJECT_STATUS)

## 项目定义

- 当前仓库名：`Reader-for-iOS`
- 当前仓库角色：`Reader-iOS 主仓`
- 依赖上游仓：`Reader-Core`
- 当前主线：`post-split stabilization audit`
- 当前阶段：`post_split_stabilization_audit`
- 当前是否允许继续推进新功能：`no`
- 判断原因：本轮只允许审计、split 后结构/依赖/CI/文档修复与 boundary gate 加固。

## 当前审计批次

### Batch 1: Reader-Core 独立性验证

- fresh clone：`complete`
- 独立 Package.swift：`present`
- 最新 GitHub Actions core-swift-tests：`failure`
- 结论：Reader-Core 尚未达到独立 green 稳态

### Batch 2: Reader-iOS 依赖策略审计

- 当前模式：`path dependency`
- 依赖方向：`Reader-iOS -> Reader-Core public package/products only`
- 结论：方向正确，但 path dependency 不适合作为长期 canonical mode

### Batch 3: Boundary Gate 加固

- `scripts/check_ios_boundary.sh`：`patched`
- 新增校验：
  - forbidden root paths
  - forbidden core workflows
  - forbidden core docs
  - legacy local Core path references

### Batch 4: Docs Semantic Audit

- 发现：当前仓仍残留 `Reader-Core transition host` 语义
- 处理：主状态文档、handoff、prompt governance、docs split index 已回写为 Reader-iOS 主仓语义

### Batch 5: CI Audit

- Reader-Core 最新 `Reader Core Swift Tests`：`failure`
- Reader-iOS 最新 `iOS Shell CI`：`failure`
- Reader-iOS 阻断原因：checkout path 在 workspace 之外
- 处理：本仓 workflow 已改为 `path: Reader-Core`

## 最近一次动作

- 已完成：`Post-Split Stabilization Audit`
- 已完成：Reader-iOS `ios-shell-ci` checkout path 修复
- 已完成：Reader-iOS boundary gate 加固
- 已完成：Reader-iOS 状态文档去除 transition-host 漂移

## 下一步唯一最优任务

```yaml
current_repo_role: Reader-iOS
reverse_split_bootstrap_complete: true
core_asset_migration_complete: true
current_repo_role_switched_to_reader_ios: true
dual_repo_consistency_complete: true
```

- 本仓保留资产：iOS/**、scripts/check_ios_boundary.sh、.github/workflows/ios-shell-ci.yml、iOS docs/handoff
- 本仓已移除：Core/**、samples/**、tools/**、Adapters/**、Platforms/**、10 Core workflows、Core docs
- 远端：https://github.com/minliny/Reader-for-iOS（TODO: 改名为 Reader-iOS）
- Reader-Core 远端：https://github.com/minliny/Reader-Core，commit b4dffc4，tag 0.1.0
- Reader-iOS 依赖：`../Reader-Core` (local)，canonical: `https://github.com/minliny/Reader-Core.git`

## Clean-Room 状态

- Clean-room maintained: `yes`
- External GPL code copied: `no`
