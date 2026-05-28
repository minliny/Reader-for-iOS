# iOS BookSource Import Object Rule Compatibility Report

## 1. 总体结论

**IOS_BOOKSOURCE_IMPORT_OBJECT_RULE_COMPAT_READY**

M6-P1-001 已修复：iOS 导入层新增 `BookSourceImportNormalizer`，在 decode 前将 object-shaped rule 转换为 JSON-string form，兼容 Legado 格式，不修改 Reader-Core。

## 2. 本轮目标

本轮只修 M6-P1-001：object-shaped `ruleSearch/ruleToc/ruleContent` 导入兼容。

## 3. 问题根因

`xingxingxsw.search-only.json` 中 `ruleSearch`、`ruleToc`、`ruleContent` 为 object/dictionary 形态：

```json
"ruleSearch": { "bookList": "...", "name": "..." }
"ruleToc": { "chapterList": "...", "chapterName": "..." }
"ruleContent": { "content": "..." }
```

但 `ReaderCoreModels.BookSource` 中这些字段定义为 `String?`：

```swift
public var ruleSearch: String?
public var ruleToc: String?
public var ruleContent: String?
```

`JSONDecoder` 无法将 Object decode 为 String，导致在本地校验前 decode 失败：

```
Invalid book source JSON: The data couldn't be read because it isn't in the correct format.
```

## 4. 修复策略

iOS 导入层 normalization — 不修改 Reader-Core：

1. 用 `JSONSerialization` 读取原始 JSON
2. 对 `ruleSearch/ruleToc/ruleContent/ruleBookInfo/ruleExplore` 字段：
   - String → 直接传递
   - Object/Dictionary → `JSONSerialization.data` → UTF-8 string → 填回字段
3. `header` 同理处理（可能是 String 或 Object）
4. 转换后 data 传入 `provider.validateBookSource(from:)` 正常 decode

## 5. 实现内容

### 5.1 BookSourceImportNormalizer

**文件**：`iOS/App/Persistence/BookSourceImportNormalizer.swift`

- `normalize(Data) throws -> Data`
- 处理字段：`ruleSearch`、`ruleToc`、`ruleContent`、`ruleBookInfo`、`ruleExplore`、`header`
- Object → JSON string compact encoding
- Empty object `{}` → `"{}"`
- 不支持类型返回明确错误，不静默失败

### 5.2 BookSourceViewModel 调用 normalizer

**文件**：`iOS/Features/BookSources/BookSourceViewModel.swift`

- `importFromData` 在调用 `provider.validateBookSource(from:)` 前先调用 `normalizer.normalize(data)`
- 失败时返回明确 `importState = .failed`

### 5.3 capability 检查维持

`BookSourceImportValidator` 不变 — capability 状态仍按现有逻辑报告 search=ready（因为有 searchUrl）其他=missing。

## 6. xingxingxsw JSON 验证

使用修复后代码，手动验证：

| 检查项 | 预期 | 实际 |
|---|---|---|
| JSON 文本可导入 | ✅ | ✅ |
| decode 成功（normalizer 处理后） | ✅ | ✅ |
| 进入本地校验 | ✅ | ✅ |
| search capability | ready（因为有 searchUrl） | ✅ |
| detail capability | missing（ruleBookInfo 为空对象） | ✅ |
| toc capability | missing（ruleToc 为 object） | ✅ |
| content capability | missing（ruleContent 为 object） | ✅ |
| 可保存到本地书源 | ✅ | ✅ |
| 不自动联网 | ✅ | ✅ |

## 7. 网络与安全边界

| 检查项 | 结果 |
|---|---|
| 导入/校验不自动联网 | ✅ |
| 未接 WebDAV/RSS/Sync | ✅ |
| 未保存 token/cookie | ✅ |
| 未修改 Reader-Core | ✅ |
| boundary | ✅ PASS |
| build | ✅ BUILD SUCCEEDED |

## 8. 验证结果

| 检查 | 结果 |
|---|---|
| boundary | ✅ PASS |
| build | ✅ BUILD SUCCEEDED |
| 测试 target | ⚠️ TOOLING_BLOCKED_PREEXISTING（Xcode 26.5 bug，ReaderAppTests/ShellSmokeTests 仍不可用） |

## 9. M1-M5 回归影响

✅ 无回归 — 修复仅在导入路径插入 normalizer，不影响 M1-M5 已有流程。

## 10. P0 问题

无。

## 11. P1 问题

无。

## 12. 下一步建议

重新交给 Codex 执行 M6 Device Review：导入 xingxingxsw JSON → 本地校验显示 capability → 保存到书源列表 → 手动测试搜索。

## 报告路径

`docs/ui-handoff/ios/IOS_BOOKSOURCE_IMPORT_OBJECT_RULE_COMPAT_REPORT.md`