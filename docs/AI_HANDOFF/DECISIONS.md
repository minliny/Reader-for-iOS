# 技术决策 (DECISIONS)

---

## 已确认的技术决策

| 决策项 | 内容 | 状态 | 确认人 |
|--------|------|------|--------|
| 架构路线 | 统一 Core + 多端壳层 | ✅ 已确认 | project |
| 首版优先级 | 非 JS 主路径先行 | ✅ 已确认 | project |
| 开发方式 | clean-room，不复用 Legado 实现 | ✅ 已确认 | project |
| Fixture 层策略 | 先做 Fixture 层最小实现，再做完整实现 | ✅ 已确认 | human |
| CSSExecutor 调用签名 | `execute(_ rule: String, from html: String) throws -> [String]` | ✅ 已确认 | human |
| 空结果处理 | selector 未命中返回 `[]`，其他错误继续抛出 | ✅ 已确认 | human |

---

## 已否决的方案

| 方案 | 否决原因 | 否决时间 |
|------|----------|----------|
| Fixture 层依赖 RuleScheduler | CSSExecutor 未稳定前不应引入未稳定依赖 | 2026-04-01 |
| Fixture 层使用 `css:` 前缀 | RuleDSL 不需要前缀 | 2026-04-01 |
| Fixture 层使用 `|` 分段规则 | 当前阶段不支持多阶段规则 | 2026-04-01 |
| Fixture 层使用空格组合选择器 | 当前 CSSExecutor 不支持 | 2026-04-01 |
| FixtureTocItem 使用 Environment.siteURL 兜底 | 仅应使用传入的 baseURL | 2026-04-01 |
| FixtureTocParser 吞掉所有错误 | 仅 selector 未命中返回 `[]` | 2026-04-01 |

---

## 当前固定下来的契约

### FixtureTocItem 契约
```swift
public struct FixtureTocItem: Sendable, Equatable {
    public let title: String
    public let url: String
    
    public func absoluteURL(baseURL: String?) -> FixtureTocItem
    public func processedTitle() -> String
}
```

### FixtureTocParser 契约
```swift
public final class FixtureTocParser: Sendable {
    public func parse(
        html: String,
        titleRule: String,
        urlRule: String,
        baseURL: String?
    ) throws -> [FixtureTocItem]
}
```

### CSSExecutor 契约
```swift
public final class CSSExecutor: Sendable {
    public func execute(_ rule: String, from html: String) throws -> [String]
}
```

---

## 当前不允许漂移的规则

1. **RuleDSL 禁止扩展**：当前仅支持 `@text` / `@html` / `@href` / `@src` / `@alt`
2. **高层协议禁止修改**：不得修改 Contracts.swift / ParserProtocols.swift 等
3. **Service/Engine 禁止修改**：当前阶段不动上层
4. **clean-room 原则**：任何实现必须可追溯到样本、规范或项目文档
5. **样本驱动**：任何兼容性改动必须绑定样本
6. **人工审查**：AI 代码必须经过人工审查才能合并
7. **高风险改动必须补测试**：规则执行、网络层、Cookie、失败分类变更属于高风险

---

## 关键约束

### clean-room 原则
- 实现依据仅来自公开协议、输入输出行为、项目样本与本仓库规范
- 任何实现描述必须可追溯到样本、规范或本仓库文档
- 不得复制、翻译、改写 Legado Android 源码或其实现细节

### 样本驱动原则
- 每个兼容性需求必须先落地样本，再做实现
- 每个样本必须具备 metadata
- 每个改动必须更新或复用：
  - samples/metadata
  - samples/expected
  - samples/matrix/compat_matrix.yml
  - samples/matrix/failure_taxonomy.yml

### 回归门禁
所有 PR 合并前必须通过：
1. 单元测试通过
2. 样本回归通过（至少覆盖受影响样本集合）
3. 兼容矩阵校验脚本通过
4. 失败类型校验脚本通过
5. iOS 构建检查通过（仅涉及 iOS 代码时必需）

### A/B/C/D 兼容等级定义
（不得修改，详见 AGENTS.md）

### failure taxonomy
（不得新增而不同时更新配置，详见 AGENTS.md）
