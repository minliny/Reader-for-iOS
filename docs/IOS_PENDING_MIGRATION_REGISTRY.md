# iOS Pending Migration Registry

## Status

```yaml
ownership_after_split: Reader-iOS
current_status: pending migration
evidence_preserved: true
physical_migration_complete: false
```

## Tracked Docs

| Document | Current Role In Host Repo | Future Owner | Notes |
|---|---|---|---|
| `docs/ios_shell_ci_gate.yml` | 历史 iOS shell CI 证据 | Reader-iOS | 保留 validation/evidence |
| `docs/IOS_PHASE_GATE_REVIEW.md` | 历史 gate review 证据 | Reader-iOS | 不再作为主仓 active 主线文档 |
| `docs/ios_gate_remediation_result.yml` | 历史 remediation 证据 | Reader-iOS | 保留审计链 |
| `docs/ios_architecture_remediation_plan.yml` | 历史 remediation 方案 | Reader-iOS | 迁移后独立维护 |
| `docs/ios_boundary_violations.yml` | 历史边界违规证据 | Reader-iOS | 保留证据，不再作为主仓 active source |

## Registry Rules

1. 本轮不移动物理文件。
2. 本轮不删除历史执行证据。
3. 本轮不伪造“已迁移到 Reader-iOS”。
4. 本轮只改变归属语义与索引入口。
