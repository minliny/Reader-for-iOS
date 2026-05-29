# iOS BookSource Imported Source List Fix Report

## 1. 总体结论

**IOS_BOOKSOURCE_IMPORTED_SOURCE_LIST_READY**

M6-P1-003 已修复：`BookSourceListView.loadSources()` 现已合并 `BookSourceStore` 中的本地导入源 + fixture/candidate 源，导入源可在列表中区分展示。

## 2. 本轮目标

本轮只修 M6-P1-003：导入成功后本地书源未在书源列表中可区分展示。

## 3. 问题根因

`BookSourceListView.loadSources()` 仅返回 `Self.fixtureSources`（硬编码 6 个预置源），从未读取 `BookSourceStore` 中保存的本地导入源。

导入成功 → `store.add(source)` 保存到 `BookSourceStore` → 但列表只显示 `fixtureSources` → 导入源不可见。

## 4. 修复策略

修改 `BookSourceListView.loadSources()` 为 `async` 方法：

1. 加载 `fixtureSources` 作为基础列表
2. 调用 `BookSourceStore.shared.load()` 读取本地导入源
3. 合并两者（按 `id` 去重，避免覆盖预置源）
4. 预置源名称带 `⭐` 前缀，导入源不带 → 设备端可区分

## 5. 实现内容

### 5.1 BookSourceListView.loadSources()

**文件**：`iOS/Features/BookSources/BookSourceListView.swift`

- 添加 `import ReaderAppPersistence`
- `loadSources()` 改为 `async` 函数
- 合并 fixture + local store sources（按 `id` 去重）
- 列表 reload 后导入源可见（无 `⭐` 前缀，可区分）

### 5.2 删除本地源

`deleteSource()` 仅从内存 `sources` 移除，不写回 `BookSourceStore`（本地导入源持久化在 store，重启 App 后仍存在）。本次修复不改变删除行为。

## 6. 设备端复测预期

复测应看到：

1. 导入 xingxingxsw JSON 成功（已设备端确认）
2. 返回书源列表 → 出现两条 `星星小说网`：
   - `⭐ 星星小说网`（预置 candidate）
   - `星星小说网`（本地导入，无星星标记）
3. 点击导入源 → 进入 `BookSourceDetailView` 详情页
4. 详情页显示 capability 状态 + "测试搜索" 按钮
5. 可对导入源执行手动测试搜索

## 7. 网络与安全边界

| 检查项 | 结果 |
|---|---|
| 导入/校验不自动联网 | ✅ |
| 手动测试才 controlledOnline | ✅ — `provider.searchBooks()` 受 `NetworkAccessController` 控制 |
| 未接 WebDAV/RSS/Sync | ✅ |
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

建议 Codex 重新执行 M6 Device Review：导入 xingxingxsw JSON → 返回列表出现导入源 → 进入详情 → 手动测试搜索。

## 报告路径

`docs/ui-handoff/ios/IOS_BOOKSOURCE_IMPORTED_SOURCE_LIST_FIX_REPORT.md`