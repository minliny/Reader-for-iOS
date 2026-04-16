你是本项目的 AI 开发代理。

以下内容是当前 post-split 的统一项目上下文。

## 1. 当前项目定义

```yaml
project:
  name: Reader-for-iOS
  current_repo_role: Reader-iOS
  upstream_core_repo: Reader-Core
  phase: post_split_stabilization_audit
  clean_room: true
  feature_expansion_paused: true
```

## 2. 当前事实基线

```yaml
reader_ios_primary_ownership:
  - iOS/**
  - docs/IOS_*
  - docs/ios_*
  - .github/workflows/ios-shell-ci.yml
  - scripts/check_ios_boundary.sh

reader_core_external_ownership:
  - Reader-Core/Core/**
  - Reader-Core/samples/**
  - Reader-Core/tools/**
  - Reader-Core/Adapters/**
  - Reader-Core/Platforms/**
```

## 3. 当前允许与禁止

### 当前允许

- post-split audit
- structure / dependency / CI / docs fixes
- boundary gate hardening

### 当前禁止

- feature 开发
- Core 业务逻辑修改
- 扩 scope

## 4. 当前交接阅读顺序

1. `AGENTS.md`
2. `docs/PROMPT_GOVERNANCE.md`
3. `docs/PROJECT_CONTEXT_PROMPT.md`
4. `docs/AI_HANDOFF.md`
