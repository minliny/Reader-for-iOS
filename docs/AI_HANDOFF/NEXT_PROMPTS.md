# 下一阶段提示词 (NEXT_PROMPTS)

---

## 1. 审查 FixtureTocParser（Reviewer Agent）
**适用前提**: FixtureTocParser 刚实现完成，需要审查

```
你现在是 Reviewer Agent。

请严格审查 FixtureTocParser。

重点检查：
1. 是否仍然出现 `css:` 前缀
2. 是否仍然出现 `|` 分段规则
3. 是否仍然依赖 RuleScheduler
4. 是否调用了与当前 CSSExecutor 不一致的接口
5. `titleRule` / `urlRule` 是否都是当前 RuleDSL 可直接解析的完整规则字符串
6. 空结果是否按当前 fixture 契约处理为 []
7. 是否允许进入下一步：yes/no

输出格式：
- P0 问题
- P1 问题
- 是否允许合并
- 合并前必须补的内容
```

---

## 2. 实现 Fixture 层 ContentParser（Builder Agent）
**适用前提**: FixtureTocParser 已通过审查，需要继续实现 Fixture 层 ContentParser

```
你现在是 Builder Agent。

当前不要实现完整 ContentParser，只实现最小 Fixture 层 ContentParser。

背景约束：
1. CSSExecutor 已通过
2. FixtureTocParser 已通过审查
3. 当前阶段只允许 fixture 层
4. 不允许修改高层协议、Service、Engine
5. 不允许扩展 DSL
6. 当前阶段只需要一个核心解析方法

必须满足：
1. 只保留一个核心方法：
   - parse(html:contentRule:baseURL:) throws -> [String]
2. `contentRule` 必须是当前 RuleDSL 已支持的完整规则字符串
   - 例如：`p@text`
   - 例如：`.content@html`
3. 不依赖 RuleScheduler
4. 不修改高层协议、Service、Engine
5. 空结果处理口径：
   - selector 未命中时，FixtureContentParser 层可捕获并返回 []
   - 其他真实错误继续抛出
6. 只面向 fixture 阶段，不扩展 DSL

请输出：
1. 修正后的完整文件内容
2. 包括：
   - Core/Sources/ReaderCoreParser/FixtureContentParser.swift
   - Core/Tests/ReaderCoreParserTests/Fixtures/ContentFixtures.swift
   - Core/Tests/ReaderCoreParserTests/FixtureContentParserTests.swift
3. 不要写分析报告
4. 代码必须与当前 RuleDSL / CSSExecutor 契约一致
5. 不要再出现 `css:` / `|` / 空格组合选择器
```

---

## 3. 实现 Fixture 层 SearchParser（Builder Agent）
**适用前提**: FixtureTocParser 和 FixtureContentParser 已通过审查

```
你现在是 Builder Agent。

当前不要实现完整 SearchParser，只实现最小 Fixture 层 SearchParser。

背景约束：
1. CSSExecutor 已通过
2. FixtureTocParser / FixtureContentParser 已通过审查
3. 当前阶段只允许 fixture 层
4. 不允许修改高层协议、Service、Engine
5. 不允许扩展 DSL
6. 当前阶段只需要一个核心解析方法

请输出：
1. 最小 FixtureSearchItem 结构
2. 最小 FixtureSearchParser 契约
3. fixture 层测试清单
4. 新增文件列表
5. 完整代码

要求：
- 只保留一个核心方法
- 不要写完整代码以外的分析
- 不要引入多余接口
```

---

## 4. 补充 CSSExecutor 测试覆盖（Builder Agent）
**适用前提**: CSSExecutor 已实现，需要补充测试

```
你现在是 Builder Agent。

当前任务：补充 CSSExecutor 测试覆盖。

必须覆盖：
1. 链式选择器 `>`
2. @text 提取
3. @html 提取
4. @href 提取
5. @src 提取
6. @alt 提取
7. selector 未命中
8. 空结果

请输出：
- Core/Tests/ReaderCoreParserTests/CSSExecutorTests.swift 的补充内容
- 不要修改现有已通过的测试
- 只新增测试用例
```
