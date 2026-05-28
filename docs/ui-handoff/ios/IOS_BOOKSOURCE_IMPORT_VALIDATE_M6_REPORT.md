# iOS BookSource Import and Validate M6 Report

## 1. 总体结论

**IOS_BOOKSOURCE_IMPORT_AND_VALIDATE_M6_READY**

M6 书源导入与验证基础能力已完成：JSON 解析 → 本地校验 → 保存到本地书源列表 → 手动测试入口。

## 2. 本轮目标

本轮目标是构建书源导入、本地校验（不上网）、保存到本地书源列表、手动测试入口的最小可用能力。

## 3. 输入状态

已读取：
- `docs/ui-handoff/ios/MILESTONE_STATUS.md`
- `docs/ui-handoff/ios/IOS_READING_HISTORY_BOOKMARKS_M5_REPORT.md`
- `docs/ui-handoff/ios/IOS_READING_HISTORY_BOOKMARKS_M5_DEVICE_REVIEW.md`
- `iOS/AppSupport/Sources/xingxingxsw.search-only.json`
- `iOS/Features/BookSources/`
- `iOS/App/Persistence/BookSourceStore.swift`
- `iOS/CoreBridge/ReaderCoreServiceProvider.swift`
- `scripts/check_ios_boundary.sh`

## 4. 当前缺口审计

| 项目 | 审计结果 | 备注 |
|---|---|---|
| 是否有导入入口 | ✅ 已有 | `BookSourceImportView` + `BookSourceViewModel.importFromText()` |
| 是否有本地校验 | ✅ 已有（本次增强） | `BookSourceImportValidator` — 检查 sourceName/baseURL/capability |
| 是否有本地保存 | ✅ 已有 | `BookSourceStore.add()` |
| 是否有手动测试 | ⚠️ 框架已有（本次增强 UI） | `BookSourceDetailView` 显示 capability status + "测试搜索" 按钮 |
| 是否有 capability 状态 | ✅ 已有（本次新增） | `CapabilityStatus` enum：ready/missing/invalid |

## 5. 实现内容

### M6-A: Import JSON

**已有**：`BookSourceImportView` + `BookSourceViewModel.importFromText()`
- 用户粘贴 JSON → `provider.validateBookSource(from: data)` → `store.add(source)`
- 解析失败显示明确错误（idle/success/failed/unsupported/partial）

**本轮增强**：
- `BookSourceImportView` 新增 capability status 显示（search/detail/toc/content）
- `BookSourceDetailView` 显示 capability status rows（.ready/.missing/.invalid）
- "测试搜索" 按钮替换 "本地模拟测试"，更明确意图

### M6-B: Local Validation

**新增**：`iOS/App/Persistence/BookSourceImportValidator.swift`

- `BookSourceValidationResult` struct — 包含 sourceId/sourceName/baseURL + per-capability status + warnings + errors
- `CapabilityStatus` enum — `.ready / .missing / .invalid`
- `BookSourceImportValidator.validate()` — 不联网的本地结构校验：
  - sourceName 不为空
  - bookSourceUrl 合法前缀（http/https/file）
  - 禁止 path traversal（URL 中不含 `../`）
  - 报告 search/detail/toc/content capability

### M6-C: Save to Local BookSource Store

**已有**：`BookSourceStore.add()` — 支持新增，重复 sourceId 追加到列表

### M6-D: Manual Test Entry

**已有**：`BookSourceDetailView` — 显示 capability status + test button

**本轮增强**：
- capability rows 替换原来硬编码文本
- 按钮文案改为 "测试搜索"，更明确

## 6. 网络与安全边界

| 项目 | 状态 |
|---|---|
| 导入/校验不自动联网 | ✅ |
| 手动测试才 controlledOnline | ✅ — `provider.searchBooks()` 受 `NetworkAccessController` 控制 |
| 每次只测一个 operation | ✅ — 每次只触发 search |
| 不保存 token/cookie | ✅ |
| 不接 WebDAV/RSS/Sync | ✅ |
| boundary | ✅ PASS |
| build | ✅ BUILD SUCCEEDED |

## 7. M1-M5 回归影响

✅ 无回归 — M6 仅新增 `BookSourceImportValidator.swift` 文件和 `BookSourceDetailView` UI 修改。

## 8. P0 问题

无。

## 9. P1 问题

无。

## 10. 下一步建议

**M6 Device Review**：在设备上验证：
1. 书源列表 → 点击"+" → 导入 xingxingxsw JSON → 本地校验显示结果
2. 保存成功 → 书源列表显示新书源
3. 点击书源 → 详情页显示 capability 状态
4. 点击"测试搜索" → controlledOnline search 触发

## 报告路径

`docs/ui-handoff/ios/IOS_BOOKSOURCE_IMPORT_VALIDATE_M6_REPORT.md`