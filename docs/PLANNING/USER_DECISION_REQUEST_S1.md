# Reader-iOS S1 用户决策请求

## 决策 ID
`DECISION_S1_READER_CORE_TAG`

## 决策描述
请确认用于 Reader-iOS S1 阶段真实接入的 Reader-Core 稳定版本（commit hash 或 tag）。

## 背景信息

**当前状态**:
- S0 阶段即将完成
- 需要接入真实 Reader-Core Parser/Network
- Reader-Core 最新测试状态: ❌ 失败（来自 PROJECT_STATUS.md）

**可用选项**:
1. 使用 tag `0.1.0` (当前 Package.swift 中配置的版本)
2. 使用 commit `b4dffc4` (来自 PROJECT_STATUS.md)
3. 等待 Reader-Core 稳定后再进行
4. 其他（请指定）

## 预期影响

| 选项 | 影响 | 风险 |
|------|------|------|
| tag 0.1.0 | 稳定版本，可立即开始 | 可能缺少最新特性 |
| commit b4dffc4 | 最新提交，包含最新代码 | 可能不稳定 |
| 等待稳定 | 无风险 | 开发进度延期 |

## 需要用户提供

请确认以下内容：
1. 使用哪个 Reader-Core 版本？
   - [ ] tag 0.1.0
   - [ ] commit b4dffc4
   - [ ] 其他：_________
2. 是否立即开始 S1 阶段？
   - [ ] 是
   - [ ] 否，先等待 Reader-Core 稳定

## 决策参考文档

- `docs/PROJECT_STATUS.md` - 项目状态快照
- `docs/PLANNING/READER_IOS_LONG_TERM_DEV_PLAN.md` - 长期开发路线
- `docs/CODE_WIKI.md` - Code Wiki
