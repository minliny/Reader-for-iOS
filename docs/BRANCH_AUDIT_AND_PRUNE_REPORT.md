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
  classification: uncertain
  action: keep_for_now
  rationale:
    - "merge-base 为 85550af，说明该分支自较早主线分叉，后续 main 已有大规模演进。"
    - "git cherry 显示 22 个 ahead 提交均未被 main 以 patch-equivalent 形式吸收。"
    - "git range-diff 表明当前 main 不是该分支提交序列的直接等价覆盖，而是后续实现路线不同。"
    - "在未逐提交核对是否存在仍值得摘取的测试/fixture 资产前，强删存在丢失独立证据链的风险。"
  risk_level: medium
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
  classification: meaningful_unique
  action: manual_followup_required
  rationale:
    - "这是四条分支中风险最高的一条，ahead 37，且包含真实代码与样本资产变更，不是纯证据分支。"
    - "git cherry 与 range-diff 都不能证明这些提交已经被 main 等价覆盖。"
    - "其中既有 policy regression 代码/测试，也混入了更早的 adapter hardening 链，必须拆分后再判断是否摘取。"
    - "在未完成逐提交吸收评估前禁止强删。"
  risk_level: high
```

## 决策表

| 分支 | 结论 | 实际动作 |
|---|---|---|
| `claude/fervent-goldstine` | 可直接删除 | 已删除远端分支 |
| `codex/main` | PR 已合并，分支仅剩历史 head | 已删除远端分支 |
| `codex-cache-ci-evidence-2407` | 未证明等价覆盖 | 保留 |
| `codex-policy-regression-verification-20260409` | 含独立有效成果，需专项拆分 | 保留 |

## 实际执行动作

- 已执行 `git fetch --all --prune`
- 已执行 `gh pr view 2 --json ...`，确认 `codex/main` 对应 PR #2 为 `MERGED`
- 已执行 `git push --delete origin claude/fervent-goldstine`
- 已执行 `git push --delete origin codex/main`

## GitHub 清理结果

- 已删除远端分支：
  - `claude/fervent-goldstine`
  - `codex/main`
- 当前仍保留远端分支：
  - `codex-cache-ci-evidence-2407`
  - `codex-policy-regression-verification-20260409`

## 后续建议

- 继续以 `main` 作为唯一可信主线
- 后续 Track D 继续推进 `M-IOS-7: Reader Flow Functional Validation`
- 若要继续远端清理，先专项拆分 `codex-policy-regression-verification-20260409`
- `codex-cache-ci-evidence-2407` 需要补一轮逐提交“是否摘取测试/fixture 资产”的人工确认

## Clean-Room 说明

- 本次仅执行 Git 历史审计、远端分支清理与文档固化
- 未引入任何外部 GPL 代码
- 未复制、翻译或改写 Legado Android 源码
