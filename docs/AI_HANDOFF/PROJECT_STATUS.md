# 项目状态 (PROJECT_STATUS)

## 项目目标
交付一个本地化、多端可复用的阅读核心能力，兼容 Legado 书源 JSON 主流字段结构与主流程行为。

## 当前路线
统一 Core + 多端壳层，当前阶段以 iOS 先行，先做非 JS 主路径闭环。

## 首版范围
- ✅ 统一 Core 基础模型
- ✅ BookSource 导入
- ⏳ 搜索 / 目录 / 正文主链路
- ⏳ 非 JS 主路径
- ⏳ Header / 基础 Cookie / 缓存 / 错误定位
- ⏳ 最小调试能力

## 当前阶段
Fixture 层开发阶段，聚焦 TOC 解析最小实现。

## 当前已完成模块
| 模块 | 状态 | 审查状态 |
|------|------|----------|
| BookSource 模型 | ✅ 完成 | ⏳ 待审 |
| Environment 配置 | ✅ 完成 | ⏳ 待审 |
| CSSNode 模型 | ✅ 完成 | ⏳ 待审 |
| HTMLParser | ✅ 完成 | ⏳ 待审 |
| CSSExecutor | ✅ 完成 | ⏳ 待审 |
| FixtureTocItem | ✅ 完成 | ⏳ 待审 |
| FixtureTocParser | ✅ 完成 | ⏳ 待审 |

## 当前未完成模块
- ContentParser
- SearchParser
- 完整 TocParser（非 Fixture 层）
- 网络层集成
- Cookie 完整支持
- 缓存层集成
- 错误定位系统

## 当前阻断点
无。

## 当前最重要的 3 个下一步
1. 审查并稳定 FixtureTocParser
2. 实现 Fixture 层 ContentParser
3. 实现 Fixture 层 SearchParser

## 当前不允许做的事
- ❌ 修改高层协议、Service、Engine
- ❌ 扩展 RuleDSL
- ❌ 引入 RuleScheduler 依赖到 Fixture 层
- ❌ 实现 JS 相关功能
- ❌ 云同步、账号、社区功能

## 建议下一位 AI 首先阅读的文件列表
1. `AGENTS.md` - 项目治理总则
2. `.trae/rules/reader-project-rules.md` - 项目规则
3. `Core/Sources/ReaderCoreParser/CSSExecutor.swift` - 当前已通过的 CSS 执行器
4. `Core/Sources/ReaderCoreParser/FixtureTocParser.swift` - 最新 Fixture 层 TOC 解析器
5. `Core/Tests/ReaderCoreParserTests/FixtureTocParserTests.swift` - Fixture 层测试
