# 项目状态总览

## 当前可信主线

- 可信主线分支：`main`
- 当前仓库身份：`Reader-iOS 主仓`
- Reader-Core 已独立为：`../Reader-Core` / `https://github.com/minliny/Reader-Core`
- 当前结论：反向拆仓已完成，但双仓尚未达到长期稳态；当前阶段是 `post_split_stabilization_audit`。

## 当前阶段

- 项目目标：`Post-Split Stabilization Audit`
- 当前阶段：`post_split_stabilization_audit`
- 当前主线：`Reader-iOS standalone hardening with Reader-Core external dependency`
- 当前下一步：`修复 Reader-Core CI failures and migrate Reader-iOS off path dependency`

## 当前审计结论

- Reader-Core fresh clone：`可独立获取`
- Reader-Core standalone CI：`not green`
- Reader-iOS dependency direction：`correct`
- Reader-iOS active dependency mode：`path dependency, not yet stable as long-term mode`
- Reader-iOS ios-shell-ci：`存在 checkout path 风险，已在本仓修复`
- Reader-iOS docs semantics：`存在 transition-host 漂移，已在本仓回写`

## 仓库角色说明

- 本仓是 Reader-iOS 主仓，不再是 Reader-Core transition host。
- 本仓长期归属：
  - `iOS/**`
  - `docs/IOS_*`
  - `docs/ios_*`
  - `.github/workflows/ios-shell-ci.yml`
  - `scripts/check_ios_boundary.sh`
- Reader-Core 长期归属：
  - `Core/**`
  - `samples/**`
  - `tools/**`
  - `Adapters/**`
  - `Platforms/**`
  - Core-only workflows

## 当前风险

- Reader-Core 最新 `Reader Core Swift Tests` 失败，说明双仓还未达到真正稳态。
- Reader-iOS 仍以 path dependency 作为活动依赖模式，不适合长期 CI/发布稳态。
- 历史拆仓治理文档仍有部分 retained-for-history 语义，需要与当前主线严格区分。

## 推荐下一步

- 在 Reader-Core 仓修复 standalone test failures，恢复 core-swift-tests green baseline。
- 在 Reader-iOS 完成 remote package dependency 切换方案评审后，移除 path dependency。
- 持续保留 boundary gate，防止 Core 资产和 Core-only docs/workflows 回流到 Reader-iOS。

## Clean-Room 说明

- 本次审计仅基于当前仓与 Reader-Core fresh clone、CI 运行记录和现有文档。
- 未开发新 feature，未修改业务逻辑，未搬运外部 GPL 代码。
