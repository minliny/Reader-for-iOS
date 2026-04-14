# 开放任务 (OPEN_TASKS)

## 当前任务概览

> 当前仓库进入 `repo_split_execution_phase_a` 阶段。主仓后续角色收敛为 `Reader-Core`，`Reader-iOS` 将独立成仓。现有 iOS phase / gate / execution evidence 仅作为待迁移资产保留，不再作为 Core 主仓长期主线状态。

| ID | 任务名称 | 状态 | 优先级 | 前置依赖 | 风险点 | 验收标准 | 是否允许 AI 独立完成 |
|----|----------|------|--------|----------|--------|----------|----------------------|
| RS-001 | Reader-Core / Reader-iOS Logical Split | in_progress | P0 | 无 | 状态文件继续混写 Core / iOS 主线 | 边界、迁移清单、依赖方向、治理规则已固化到状态文档 | yes |
| RS-002 | Docs Split And Re-anchor | complete | P0 | RS-001 | iOS gate 文档继续污染 Core 状态 | Core docs / iOS docs / split docs 清单明确，主仓状态文件去除 iOS phase 主线叙事 | yes |
| RS-003 | Workflow Ownership Split | complete | P0 | RS-001 | CI 归属不清导致拆仓后 gate 失效 | Core workflow 保留清单、iOS workflow 迁移清单、拆仓后 patch 项明确 | yes |
| RS-004 | Reader-iOS Repo Bootstrap Preparation | complete | P1 | RS-001 + RS-003 | 物理拆仓时依赖、tag、checkout 方案不完整 | 新仓初始化输入清单、包依赖与版本策略明确 | yes |
| RS-005 | Physical Repo Split Execution | complete (2026-04-14) | P1 | RS-001 + RS-002 + RS-003 + RS-004 | 历史执行证据丢失或路径失效 | Reader-iOS 新仓建立、iOS 目录/文档/workflow 迁移、Core 依赖切换完成 | yes |

## 当前待办列表

### RS-001: Reader-Core / Reader-iOS Logical Split

- 状态：`in_progress`
- 优先级：`P0`
- 目标：
  - 明确 Reader-Core 与 Reader-iOS 的长期职责
  - 固化目录归属、文档归属、workflow 归属
  - 明确当前仓库只是拆分过渡宿主，不继续把 iOS phase 当 Core 主线
- 验收标准：
  - `docs/PROJECT_STATE_SNAPSHOT.yaml` 明确 `current_repo_role = Reader-Core transition host`
  - `docs/AI_HANDOFF/PROJECT_STATUS.md` 新增拆仓原因、边界、推进方式
  - `AGENTS.md` 增加主仓不得继续吸纳 iOS feature 演进的强规则
  - 输出可执行 split manifest / workflow split plan / dependency strategy

### RS-002: Docs Split And Re-anchor

- 状态：`complete`
- 优先级：`P0`
- 目标：
  - 识别哪些文档留在 Core，哪些迁移到 Reader-iOS，哪些需要拆为双份
  - 清理主仓状态文件中的 iOS phase/gate 污染
  - 建立 docs split 索引与 iOS pending migration registry
- 验收标准：
  - Core docs 清单明确
  - iOS docs 清单明确
  - split/rewrite/deprecate 清单明确
  - 历史执行证据未删除，仅重组归属
  - `docs/DOCS_SPLIT_INDEX.md` 已建立
  - `docs/IOS_PENDING_MIGRATION_REGISTRY.md` 已建立

### RS-003: Workflow Ownership Split

- 状态：`complete`
- 优先级：`P0`
- 目标：
  - 将 Core gate 与 iOS gate 的仓库归属分离
  - 提前定义拆仓后 checkout / dependency / workflow rename 方案
  - 以 docs split 产物作为 workflow 归属依据
- 验收标准：
  - Core-only workflows 列表明确
  - Reader-iOS workflows 列表明确
  - rename / patch 清单明确
  - `ios-shell-ci` 不再被当作 Core 主仓长期 gate
  - docs prerequisites:
    - `docs/DOCS_SPLIT_INDEX.md` 已完成
    - `docs/IOS_PENDING_MIGRATION_REGISTRY.md` 已完成

### RS-004: Reader-iOS Repo Bootstrap Preparation

- 状态：`complete`
- 优先级：`P1`
- 目标：
  - 准备 Reader-iOS 新仓初始化输入
  - 明确 Swift Package 依赖方式、tag/semver 策略、内部依赖禁令
  - 固化 Reader-iOS repo skeleton、bootstrap docs、迁移 manifest、repo init checklist
- 验收标准：
  - 本地开发 path dependency 方案明确
  - 正式 git dependency 方案明确
  - Reader-Core public products 清单明确
  - Reader-iOS 禁止直接依赖 Core internal modules
  - `docs/READER_IOS_BOOTSTRAP_PLAN.md` 已建立
  - `docs/READER_IOS_DEPENDENCY_BOOTSTRAP.md` 已建立
  - `docs/READER_IOS_MIGRATION_MANIFEST.md` 已建立
  - `docs/READER_IOS_REPO_INIT_CHECKLIST.md` 已建立
  - docs prerequisites:
    - Core active docs 集合已明确
    - iOS pending migration docs 集合已明确

### RS-005: Physical Repo Split Execution

- 状态：`complete (2026-04-14)`
- 优先级：`P1`
- 执行结果：
  - Reader-iOS 独立仓已建立：`../Reader-iOS`（本地路径 `/c/Users/Administrator/Documents/Reader-iOS`）
  - git 仓库已初始化
  - iOS/** 代码全量迁移
  - iOS docs（6 项 + 4 项 bootstrap docs）已迁移
  - ios-shell-ci.yml 已迁移并 patch（Reader-Core checkout + symlink step）
  - check_ios_boundary.sh 已迁移并 patch
  - iOS/Package.swift 依赖已从 `../Core` 切换至 `../../Reader-for-iOS/Core`
  - Reader-Core 状态文件已更新，历史指针保留
- `reader_ios_repo_initialized: true`
- `physical_split_complete: true`

### Post-Split Followup Tasks

- RS-005-FU-01: 发布 Reader-Core 为正式 Swift Package（远端 URL + validated tag）
- RS-005-FU-02: 更新 Reader-iOS Package.swift 切换到 URL-based 依赖（移除 local path）
- RS-005-FU-03: 更新 Reader-iOS ios-shell-ci 移除 symlink workaround
- RS-005-FU-04: 将 Reader-for-iOS 仓重命名为 Reader-Core（需 GitHub repo settings）

## 已完成事实，不得继续保留为待办

- Core frozen contract 已稳定，freeze gate 证据有效
- Header / Cookie / Cache / ErrorMapping / PolicyVerification / JSDomExecution / LoginBootstrap / CookieIsolation 已闭环
- 现有 iOS shell / functional / hardening / UX / interaction / session / navigation / presentation 证据已存在，但应迁移为 Reader-iOS 仓资产
- 本轮已完成 `Repo Split Planning`，但未执行物理拆仓
- 本轮已完成 `Prompt Governance Cleanup`，legacy prompt 已归档，active prompt 已切换为 split-era 集合

## 当前状态约束

- 当前阶段：`repo_split_execution_phase_a`
- 当前主线：`repo split governance / reader-ios bootstrap preparation`
- 当前未覆盖能力：无
- 冻结门禁状态：`READY_TO_FREEZE`
- 当前是否允许继续推进新的 iOS feature phase：`no`
- 判断原因：当前主仓治理目标是完成 Reader-Core / Reader-iOS 拆仓与边界重构；iOS 工作仅保留迁移与证据归档，不新增 feature scope
- 依赖方向：`Reader-iOS -> Reader-Core public package/products only`
- prompt governance：`split-era active only`
- legacy prompt archive：`archive/prompts/legacy/`
- iOS feature progression in current host repo：`paused`
- reader_ios_repo_initialized：`true`
- physical_split_complete：`true`
- split_date：`2026-04-14`
- reader_ios_repo_path：`../Reader-iOS`
