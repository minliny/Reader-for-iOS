# 开放任务 (OPEN_TASKS)

## 任务总表

| ID | 任务名称 | 状态 | 优先级 | 前置依赖 | 风险点 | 验收标准 | 负责人 | 是否允许 AI 独立完成 |
|----|----------|------|--------|----------|--------|----------|--------|----------------------|
| T1 | 审查 FixtureTocParser | todo | P0 | CSSExecutor 稳定 | 无 | Reviewer Agent 通过 | human | no |
| T2 | 实现 Fixture 层 ContentParser | todo | P0 | FixtureTocParser 通过 | 契约漂移风险 | 满足最小契约，仅 Fixture 层 | AI | yes |
| T3 | 实现 Fixture 层 SearchParser | todo | P0 | FixtureTocParser 通过 | 契约漂移风险 | 满足最小契约，仅 Fixture 层 | AI | yes |
| T4 | 补充 CSSExecutor 测试覆盖 | todo | P1 | CSSExecutor | 无 | 覆盖链式选择器、@html、@text、@href 等 | AI | yes |
| T5 | 补充 FixtureTocParser 边界测试 | todo | P1 | FixtureTocParser 通过 | 无 | 覆盖空输入、错误输入、边界情况 | AI | yes |
| T6 | 实现完整 TocParser（非 Fixture 层） | blocked | P0 | FixtureTocParser 通过、CSSExecutor 完全稳定 | 依赖未稳定组件风险 | 与高层协议一致，通过完整回归 | human | no |

---

## 任务详情

### T1: 审查 FixtureTocParser
- **状态**: todo
- **优先级**: P0
- **前置依赖**: CSSExecutor 稳定
- **风险点**: 无
- **验收标准**: Reviewer Agent 通过，确认符合所有约束
- **负责人**: human
- **是否允许 AI 独立完成**: no

### T2: 实现 Fixture 层 ContentParser
- **状态**: todo
- **优先级**: P0
- **前置依赖**: FixtureTocParser 通过
- **风险点**: 契约漂移风险
- **验收标准**: 满足最小契约，仅 Fixture 层，不依赖 RuleScheduler，不扩展 DSL
- **负责人**: AI
- **是否允许 AI 独立完成**: yes

### T3: 实现 Fixture 层 SearchParser
- **状态**: todo
- **优先级**: P0
- **前置依赖**: FixtureTocParser 通过
- **风险点**: 契约漂移风险
- **验收标准**: 满足最小契约，仅 Fixture 层，不依赖 RuleScheduler，不扩展 DSL
- **负责人**: AI
- **是否允许 AI 独立完成**: yes

### T4: 补充 CSSExecutor 测试覆盖
- **状态**: todo
- **优先级**: P1
- **前置依赖**: CSSExecutor
- **风险点**: 无
- **验收标准**: 覆盖链式选择器、@html、@text、@href、@src、@alt
- **负责人**: AI
- **是否允许 AI 独立完成**: yes

### T5: 补充 FixtureTocParser 边界测试
- **状态**: todo
- **优先级**: P1
- **前置依赖**: FixtureTocParser 通过
- **风险点**: 无
- **验收标准**: 覆盖空输入、错误输入、边界情况
- **负责人**: AI
- **是否允许 AI 独立完成**: yes

### T6: 实现完整 TocParser（非 Fixture 层）
- **状态**: blocked
- **优先级**: P0
- **前置依赖**: FixtureTocParser 通过、CSSExecutor 完全稳定
- **风险点**: 依赖未稳定组件风险
- **验收标准**: 与高层协议一致，通过完整回归
- **负责人**: human
- **是否允许 AI 独立完成**: no
