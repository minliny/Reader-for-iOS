# iOS Mock Data Flow Phase 1 Report

## 1. 总体结论

**IOS_MOCK_DATA_FLOW_PHASE1_READY**

## 2. 本轮目标

实现 Search → Detail → TOC → ReaderView fixture/offline replay 最小 mock 数据闭环。使用 MockReaderCoreService，不接真实网络，不引入 parser internals。

## 3. 输入状态

| 文档/代码 | 状态 |
|---|---|
| `IOS_REAL_DATA_INTEGRATION_PLANNING.md` | 已读取 |
| `IOS_APP_SHELL_PROTOTYPE_READER_CONTROL_CLOSURE_REPORT.md` | 已读取 |
| `ReaderCoreServiceProvider.swift` | 已读取 |
| `MockReaderCoreService.swift` | 已读取 |
| `SearchView.swift` / `SearchViewModel.swift` | 已读取并修改 |
| `BookDetailView.swift` / `BookDetailViewModel.swift` | 已读取 |
| `ChapterListView.swift` / `ChapterListViewModel.swift` | 已读取并修改 |
| `ReaderView.swift` / `ReaderViewModel.swift` | 已读取 |

## 4. 修改范围

### 修改文件

| 文件 | 变更 |
|---|---|
| `iOS/Features/Search/SearchViewModel.swift` | 移除搜索强制要求 BookSource 的 guard；mock 模式下无需真实书源即可搜索；自动预置 "Mock 书源" |
| `iOS/Features/Search/SearchView.swift` | 导航标题改为中文"搜索"；书源标签改为"书源" |
| `iOS/Features/ChapterList/ChapterListView.swift` | 新增 `ChapterNavigation` Hashable struct；ReaderView 导航传入正确的 chapterTitle（原来是 chapterURL）；TOC 标题改为"目录" |

### 新增文件

| 文件 | 说明 |
|---|---|
| `iOS/Tests/ReaderAppTests/MockDataFlowTests.swift` | Mock 数据闭环测试：Search/TOC/Content/Provider/SearchViewModel 验证 |

## 5. Mock 数据闭环结果

| 页面 | 数据源 | 状态 |
|---|---|---|
| Search | MockReaderCoreService → 3 个搜索结果 | 就绪 |
| BookDetail | SearchResultItem 传入 + MockReaderCoreService getBookDetail | 就绪 |
| TOC | MockReaderCoreService → 5 章 mock TOC | 就绪 |
| ReaderView | MockReaderCoreService → mock ContentPage（第一章 山村少年） | 就绪 |

### 闭环路径

```
书架/发现 → 搜索入口 → SearchView（Mock 书源搜索）
    → BookDetailView（凡人修仙传，含简介/作者/来源）
    → ChapterListView（5 章 mock 目录）
    → ReaderView（章节正文，主底栏隐藏）
    → 返回（主底栏恢复）
```

## 6. 关键修复点

### 6.1 Search 不再强制要求 BookSource

`SearchViewModel.search()` 之前要求 `selectedSource` 非 nil 才能搜索。现在 mock 模式下（provider 默认 mock），搜索不强制要求 source，`ReaderCoreServiceProvider.searchBooks()` 在 mock 模式下不使用 source 参数。

### 6.2 自动预置 Mock BookSource

`SearchViewModel.loadSources()` 在 `BookSourceStore` 为空时自动添加 "Mock 书源"，使搜索 source picker 有一个可选条目。

### 6.3 TOC → ReaderView 正确传参

`ChapterListView` 之前将 `chapterURL` 当作 `chapterTitle` 传入 ReaderView。现在使用 `ChapterNavigation` struct 同时传递 `chapterURL` 和 `chapterTitle`。

## 7. Boundary / Safety

| 检查项 | 结果 |
|---|---|
| 是否未引用 parser internals | PASS |
| 是否无真实网络 | PASS（mock 默认） |
| 是否未接 WebDAV/RSS/Sync | PASS |
| 是否未修改 Reader-Core | PASS |
| clean-room | PASS |

## 8. Provider / Toggle

- 当前默认 `ServiceMode.mock` ✓
- `ReaderCoreServiceProvider.shared.currentMode` = `.mock` ✓
- Real service 未启用 ✓
- Real service 边界风险（DefaultSearchService 依赖 SearchParser）已记录但不在本轮处理 ✓

## 9. 测试 / Build 结果

| 命令 | 结果 |
|---|---|
| `bash scripts/check_ios_boundary.sh` | PASS（83 files, 0 violations） |
| `xcodebuild build -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` | **BUILD SUCCEEDED** |

新增测试覆盖：
1. Mock search 返回 3 个结果
2. Mock TOC 返回 5 章
3. Mock content 返回非空正文
4. SearchViewModel 预置 mock 书源
5. Provider 默认 mock 模式
6. ChapterNavigation Hashable

## 10. P0 问题

无。

## 11. P1 问题

无。

## 12. P2 问题

无。

## 13. 是否建议交给 Codex 设备端校对

建议交给 Codex 设备端校对 Search → Detail → TOC → ReaderView mock flow。

条件全部满足：boundary PASS、build SUCCEEDED、P0/P1 为 0、mock 闭环代码侧完成。
