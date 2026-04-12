# 项目状态总览

## 当前可信主线

- 可信主线分支：`main`
- 当前结论：本地开发成果已从 `codex/cache-ci-evidence` 收敛到 `main`，后续开发与审查应以 `main` 为唯一事实主线。
- 远端基线：`origin/main` 待本次整理提交与推送后对齐到最新状态。

## 本次分支收敛

- 已完成：将 `codex/cache-ci-evidence` 上的有效开发成果快进合并到 `main`
- 已完成：恢复一次中断的 `rebase`，解决 `AGENTS.md` 与 `iOS/Shell/ShellAssembly.swift` 的冲突标记残留
- 已确认保留：`origin/claude/fervent-goldstine`
  原因：仅包含 5 份 non-js smoke report 更新，未并入主线，不应在未人工确认价值前删除
- 已确认保留：`origin/codex-cache-ci-evidence-2407`
  原因：与当前主线分叉，包含较早期 adapter/cache hardening 结果，当前主线未按同一提交链吸收，不应武断删除
- 已确认保留：`origin/codex-policy-regression-verification-20260409`
  原因：与当前主线分叉，包含 policy regression 方向独立提交，需在后续专门审视后决定是否摘取
- 计划删除：`codex/cache-ci-evidence` / `origin/codex/cache-ci-evidence`
  原因：其成果已被 `main` 覆盖，删除不会丢失独立开发结果

## 当前阶段

- 项目目标：Reader-Core first，iOS later
- 当前阶段：`m_ios_6_reader_feature_wired_verified`
- 已完成重点：
  - OT-006 Adapter Integration Harness 已 `ci_verified`
  - OT-007 TraceInspector 已 `ci_verified`
  - M-IOS-1 ~ M-IOS-6 已完成，Reader 主链路已通过 `ShellAssembly` 接入 iOS 壳层
  - GitHub Actions run `24307509812` 保持 boundary gate / isolated compile / shell smoke tests 全绿
- 未完成事项：
  - `M-IOS-7: Reader Flow Functional Validation`
  - OT-008 Optional Fixture Replay / Selector Tester
  - OT-009 gate decision 文档化收尾（若仍需单独审议）

## 风险与阻塞

- 当前 Windows 本地环境无 `swift`，无法在本机执行 Swift build/test；本次整理仅完成 Git 一致性与分支收敛验证
- `origin/codex-cache-ci-evidence-2407` 与 `origin/codex-policy-regression-verification-20260409` 仍含未并入主线的历史提交链，暂不删除
- `origin/claude/fervent-goldstine` 仅变更报告文件，是否保留需人工结合审计价值判断

## 推荐下一步

- 以 `main` 为基线推进 `M-IOS-7: Reader Flow Functional Validation`
- 单独审视 `origin/codex-policy-regression-verification-20260409` 是否仍有值得 selective cherry-pick 的 policy regression 资产
- 若确认无保留价值，再清理 `origin/claude/fervent-goldstine`、`origin/codex-cache-ci-evidence-2407`、`origin/codex-policy-regression-verification-20260409`

## Clean-Room 说明

- 本次操作仅基于本地仓库 Git 历史、工作区文件与项目内文档执行，未引入或搬运任何外部 GPL 代码。
