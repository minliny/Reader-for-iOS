# iOS BookSource Import Header Compatibility Report

## 1. 总体结论

**IOS_BOOKSOURCE_IMPORT_HEADER_COMPAT_READY**

M6-P1-002 已修复：扩展 `BookSourceImportNormalizer` 对 `header` 字段的 normalization，支持 JSON object string、dictionary 和 missing case。

## 2. 本轮目标

本轮只修 M6-P1-002：header 字段（JSON object string / dictionary / missing）导入兼容。

## 3. 问题根因

`xingxingxsw.search-only.json` 中 `header` 字段值为 JSON object string：

```json
"header": "{\"accept-language\": \"zh-CN,zh;q=0.9\"}"
```

但 `ReaderCoreModels.BookSource.header` 定义为 `[String: String]`：

```swift
public var header: [String: String]
```

上一轮 normalizer 将 dictionary header 转换为 JSON string（存入 dict["header"] = jsonString），但 decode 时 `JSONDecoder` 会将 string 尝试 decode 为 `[String: String]`，失败。

## 4. 修复策略

iOS 导入层 normalization — 不修改 Reader-Core：

1. **dictionary header**（`[String: Any]`）：将所有 value 转换为 String，存入 `dict["header"] = [String: String]`
2. **JSON object string header**（`String` 且可解析为 JSON）：解析后转为 `[String: String]`，存入 `dict["header"] = [String: String]`
3. **empty string header**：转为空 dict `[:]`
4. **plain text non-JSON string header**：保留，decode 时 BookSource 会处理

关键：`dict["header"]` 必须是 `[String: String]`（Swift native），这样 `JSONEncoder` 编码后 decode 为 `[String: String]` 才能成功。

## 5. 实现内容

### 5.1 BookSourceImportNormalizer 扩展

**文件**：`iOS/App/Persistence/BookSourceImportNormalizer.swift`

- dictionary header → `[String: String]` dict
- JSON object string header → 解析后转为 `[String: String]` dict
- empty string → `[:]`
- plain text non-JSON → 保留原样（validation 会捕获）

### 5.2 object-shaped rule 兼容保持

`ruleSearch/ruleToc/ruleContent/ruleBookInfo/ruleExplore` 的 object→string 转换逻辑不受影响。

## 6. xingxingxsw JSON 验证

使用修复后代码验证 xingxingxsw.search-only.json 导入路径：

| 检查项 | 预期 | 实际 |
|---|---|---|
| JSON 文本可导入 | ✅ | ✅ |
| header JSON string normalize 成功 | ✅ | ✅ |
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

## 9. P0 问题

无。

## 10. P1 问题

无。

## 11. 下一步建议

重新交给 Codex 执行 M6 Device Review：导入 xingxingxsw JSON → 本地校验显示 capability → 保存到书源列表 → 手动测试搜索。

## 报告路径

`docs/ui-handoff/ios/IOS_BOOKSOURCE_IMPORT_HEADER_COMPAT_REPORT.md`