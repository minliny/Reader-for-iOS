# Branch Audit And Prune Report

## 时间

- 审计日期：2026-04-13
- 仓库：`Reader-for-iOS`
- 可信主线：`main`

## 审计范围

- `origin/claude/fervent-goldstine`
- `origin/codex/main`
- `origin/codex-cache-ci-evidence-2407`
- `origin/codex-policy-regression-verification-20260409`

## 基线证据

- 仓库根目录：`C:/Users/Administrator/Documents/Reader-for-iOS`
- 当前分支：`main`
- 工作区基线：干净
- 默认远端：`origin`
- 默认远端分支：`origin/main`
- `git fetch --all --prune`：已执行
- `git remote show origin`：`HEAD branch: main`

## 分支审计结果

### claude/fervent-goldstine

```yaml
branch_audit_result:
  branch: claude/fervent-goldstine
  behind_main: 74
  ahead_main: 1
  unique_commit_summary:
    - "731acfb ci: nonjs smoke real reports sample_001 through sample_005"
  changed_files_summary:
    - "samples/reports/latest/sample_001_nonjs_smoke_result.yml"
    - "samples/reports/latest/sample_002_nonjs_smoke_result.yml"
    - "samples/reports/latest/sample_003_nonjs_smoke_result.yml"
    - "samples/reports/latest/sample_004_nonjs_smoke_result.yml"
    - "samples/reports/latest/sample_005_nonjs_smoke_result.yml"
  classification: trivial_unique
  action: delete_now
  rationale:
    - "唯一 ahead 提交仅修改 5 份 CI smoke report 文件，没有业务代码、样本规范或治理文档变更。"
    - "该提交由 github-actions[bot] 生成，属于临时回写型产物，不构成独立长期开发成果。"
    - "删除该远端分支不会影响 main 的产品行为或兼容资产事实基线。"
  risk_level: low
```

### codex/main

```yaml
branch_audit_result:
  branch: codex/main
  behind_main: 209
  ahead_main: 3
  unique_commit_summary:
    - "e9237ba Initial Reader core, iOS app, and agent docs"
    - "385637b Add agents, project rules, AGENTS.md, samples, and docs"
    - "f32051e Create 样本库规范与兼容矩阵_ai开发版_v_1.md"
  changed_files_summary:
    - "历史初始化骨架、治理文档与早期样本/脚本文件"
    - "PR #2 head branch"
  classification: pr_context_only
  action: delete_now
  rationale:
    - "GitHub PR #2 已是 MERGED 状态，URL 为 https://github.com/minliny/Reader-for-iOS/pull/2。"
    - "该分支仅保留已合并 PR 的历史 head，没有继续作为可信主线存在的必要。"
    - "当前主线已演进 209 个提交，保留该远端分支只会造成历史主线误导。"
  risk_level: low
```

### codex-cache-ci-evidence-2407

```yaml
branch_audit_result:
  branch: codex-cache-ci-evidence-2407
  behind_main: 68
  ahead_main: 22
  unique_commit_summary:
    - "adapter hardening multi-sample validation"
    - "minimal adapter validation sync"
    - "error mapping contract sync"
    - "cache/cookie contract test additions"
    - "asset sync for header/cookie/error fixtures"
  changed_files_summary:
    - "Core/Package.swift"
    - "Core/Sources/ReaderCoreCache/MinimalCacheHTTPClient.swift"
    - "Core/Sources/ReaderCoreModels/ErrorMapping.swift"
    - "Core/Sources/ReaderPlatformAdapters/MinimalHTTPAdapter.swift"
    - "Core/Tests/ReaderPlatformAdaptersTests/MinimalHTTPAdapterTests.swift"
    - "Core/Tests/ReaderCoreNetworkTests/URLSessionHTTPClientTests.swift"
    - "header/cookie/error related fixtures and expected files"
  classification: fully_covered
  action: delete_now
  rationale:
    - "静态资产核对后，header/cookie/error fixtures 与 expected 已存在于 main，未发现缺失资产。"
    - "Swift 差异集中在旧版 ErrorMapping / MinimalCacheHTTPClient / MinimalHTTPAdapter 测试与契约；main 中对应文件已是更高阶的新架构实现。"
    - "分支中的 failure taxonomy 扩展（如 CONTENT_NOT_FOUND / PARSE_ERROR）未同步 failure taxonomy 配置，不符合当前治理约束，不能反向合并。"
    - "结论是该分支被 main 的后续实现 supersede，而不是仍需吸收。"
  risk_level: low
```

### codex-policy-regression-verification-20260409

```yaml
branch_audit_result:
  branch: codex-policy-regression-verification-20260409
  behind_main: 68
  ahead_main: 37
  unique_commit_summary:
    - "policy regression fix and test updates for NetworkPolicyLayer"
    - "policy sample booksource/expected/fixture sync"
    - "adapter hardening chain inherited from codex-cache-ci-evidence-2407"
    - "workflow/test sync commits"
  changed_files_summary:
    - ".github/workflows/policy-regression-macos.yml"
    - "Core/Sources/ReaderCoreNetwork/NetworkPolicyLayer.swift"
    - "Core/Tests/ReaderCoreNetworkTests/NetworkPolicyLayerTests.swift"
    - "policy booksources / expected / fixture text/json assets"
    - "adapter hardening and minimal validation files inherited from older branch"
  classification: fully_covered
  action: delete_now
  rationale:
    - "policy 相关静态资产与 workflow 已存在于 main；逐路径 diff 未发现需要再迁移的样本或工作流文件。"
    - "关键 Swift 提交 2ac89a5 只是为旧版 NetworkPolicyLayer 增加 404 特判，而 main 当前版本已包含同一 404 特判，并额外保留 login bootstrap 与 cookie scope 逻辑。"
    - "分支 tip 中的 NetworkPolicyLayer/Tests 相对 main 反而更旧，删除这些差异会回退能力，不应合并。"
    - "结论是该分支已被 main 的后续架构演进 supersede，可安全删除。"
  risk_level: low
```

## 决策表

| 分支 | 结论 | 实际动作 |
|---|---|---|
| `claude/fervent-goldstine` | 可直接删除 | 已删除远端分支 |
| `codex/main` | PR 已合并，分支仅剩历史 head | 已删除远端分支 |
| `codex-cache-ci-evidence-2407` | 已被 main 新架构 supersede | 已删除远端分支 |
| `codex-policy-regression-verification-20260409` | 已被 main 新架构 supersede | 已删除远端分支 |

## 实际执行动作

- 已执行 `git fetch --all --prune`
- 已执行 `gh pr view 2 --json ...`，确认 `codex/main` 对应 PR #2 为 `MERGED`
- 已执行 `git push --delete origin claude/fervent-goldstine`
- 已执行 `git push --delete origin codex/main`
- 已执行关键 Swift 静态核对：
  - `git show 2ac89a5 --`
  - `git show 7620d5f --`
  - `git diff main..origin/codex-policy-regression-verification-20260409 -- <关键文件>`
  - `git diff main..origin/codex-cache-ci-evidence-2407 -- <关键文件>`
- 已执行 `git push --delete origin codex-cache-ci-evidence-2407`
- 已执行 `git push --delete origin codex-policy-regression-verification-20260409`

## GitHub 清理结果

- 已删除远端分支：
  - `claude/fervent-goldstine`
  - `codex/main`
  - `codex-cache-ci-evidence-2407`
  - `codex-policy-regression-verification-20260409`
- 当前远端仅剩：
  - `main`

## 后续建议

- 继续以 `main` 作为唯一可信主线
- 后续 Track D 继续推进 `M-IOS-7: Reader Flow Functional Validation`
- 历史分支治理已完成，后续不再以任何 `codex/*` 历史分支作为事实来源

## Clean-Room 说明

- 本次仅执行 Git 历史审计、远端分支清理与文档固化
- 未引入任何外部 GPL 代码
- 未复制、翻译或改写 Legado Android 源码
