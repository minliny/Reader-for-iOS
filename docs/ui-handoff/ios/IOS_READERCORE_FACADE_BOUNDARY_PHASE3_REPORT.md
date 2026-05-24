# iOS ReaderCore Facade Boundary Phase 3 Report

## 1. 总体结论

**IOS_READERCORE_FACADE_BOUNDARY_PHASE3_READY**

## 2. 本轮目标

ReaderCore facade 边界审计与测试，确认：
- UI 只通过 provider/facade 访问数据
- 无 parser internals 引用
- mock 默认，real service 非默认
- Debug tools 仅 Debug 可见
- 不接真实网络

## 3. 输入状态

| 文档 | 阶段 | 状态 |
|---|---|---|
| `IOS_MOCK_DATA_FLOW_PHASE1_CODE_READY_REPORT.md` | Phase 1 | 已读取 |
| `IOS_BOOKSOURCE_LOCAL_MANAGEMENT_PHASE2_REPORT.md` | Phase 2 | 已读取 |
| `IOS_REAL_DATA_INTEGRATION_PLANNING.md` | 规划 | 已参考 |
| `ReaderCoreServiceProvider.swift` | CoreBridge | 已审计 |
| `MockReaderCoreService.swift` | CoreBridge | 已审计 |

## 4. CoreBridge / Provider 审计

| 检查项 | 结果 |
|---|---|
| 默认 provider mode | `.mock` ✓ |
| real service 是否默认启用 | 否（需显式 `configureRealMode()`） |
| UI 是否只通过 provider/facade | 是（SearchViewModel → provider.searchBooks；BookDetailViewModel → provider.getBookDetail；ChapterListViewModel → provider.getChapterList；ReaderViewModel → provider.getChapterContent） |
| provider 是否单例 | 是（`.shared`） |
| mock scenario 可重置 | 是（`resetMock()` → `.success`） |

## 5. Search / Detail / TOC / Reader 审计

### Parser internals 引用

```
Features/:         0 matches
App/:              0 matches  
Modules/:          0 matches
CoreBridge/:       0 matches
```

**结论：UI 层无 parser internals 引用。** ✓

（注：`CoreIntegration/DefaultSearchService` 等 real service 依赖 `SearchParser`，但这些不在 UI 层，且从未被启用为默认数据源。）

### 网络引用

| 位置 | 用途 | 风险评估 |
|---|---|---|
| `WebViewRuntimeHarnessViewModel` | Debug WebView harness | Debug-only，非生产路径 |
| `WebDAVSettingsViewModel` | WebDAV URL 解析 | WebDAV 未接入主流程 |
| Features/ 其他 | 无 | PASS |

**结论：生产 UI 流（Search/Detail/TOC/Reader/BookSources）无真实网络访问。** ✓

### 各模块边界

| 模块 | ViewModel | 数据源 | 通过 facade | 无 parser | 无 network |
|---|---|---|---|---|---|
| Search | SearchViewModel | ReaderCoreServiceProvider.shared | ✓ | ✓ | ✓ |
| BookDetail | BookDetailViewModel | ReaderCoreServiceProvider.shared | ✓ | ✓ | ✓ |
| ChapterList | ChapterListViewModel | ReaderCoreServiceProvider.shared | ✓ | ✓ | ✓ |
| ReaderView | ReaderViewModel | ReaderCoreServiceProvider.shared | ✓ | ✓ | ✓ |
| BookSources | BookSourceStore + readerCoreServiceProvider | facade | ✓ | ✓ | ✓ |

## 6. BookSource 本地管理边界

| 检查项 | 结果 |
|---|---|
| fixture-only | 是（5 个硬编码 fixture，无网络加载） |
| 本地模拟测试不访问网络 | 是（仅 `Task.sleep` + 随机文本） |
| 导入模拟不读取真实 URL | 是（仅 JSON 解析） |
| 无 parser internals | 是 |
| 无真实 secrets/tokens | 是 |

## 7. Debug / Release 边界

| 入口 | Debug | Release | 检查 |
|---|---|---|---|
| `[DEBUG] Prototype Gallery` | 可见 | 不可见 | `#if DEBUG` ✓ |
| `[DEBUG] ReaderView Fixture` | 可见 | 不可见 | `#if DEBUG` ✓ |
| `WebView Harness` | 可见 | 不可见 | `#if DEBUG` ✓ |
| WebViewRuntimeAutorun | 可见 | 不可见 | `#if DEBUG && canImport(WebKit)` ✓ |
| Developer Tools Section | 可见 | 不可见 | `#if DEBUG` ✓ |
| 生产主底栏 | 可见 | 可见 | 正常 ✓ |

## 8. 测试结果

### 新增

`iOS/Tests/ReaderAppTests/ReaderCoreFacadeBoundaryTests.swift` — 17 个测试：
- Provider 默认 mock (2)
- Mock flow 保持 provider boundary (4)
- BookSource mock boundary (1)
- No network (1)
- Scenario coverage (3)
- Debug entries exist (2)
- Provider reset (1)
- No parser internals (compile-time)

### Build / Boundary

| 命令 | 结果 |
|---|---|
| `bash scripts/check_ios_boundary.sh` | PASS（86 files, 0 violations） |
| `xcodebuild build` | **BUILD SUCCEEDED** |

## 9. Boundary / Safety

| 检查项 | 结果 |
|---|---|
| boundary 脚本 | PASS |
| 是否未修改 Reader-Core | PASS |
| 是否无真实网络 | PASS |
| 是否未接 WebDAV/RSS/Sync | PASS |
| clean-room | PASS |

## 10. 剩余待设备端复测项

| Issue | 阶段 | 状态 |
|---|---|---|
| MOCK-FLOW-P2-001（Book Detail 信息完整性） | Phase 1 | READY_FOR_CODEX_VERIFY |
| BookSource local management device review | Phase 2 | PENDING_CODEX |

## 11. P0 问题

无。

## 12. P1 问题

无。

## 13. P2 问题

| 类型 | 数量 | 内容 |
|---|---|---|
| 代码侧 | 0 | — |
| 设备端待复测 | 2 | MOCK-FLOW-P2-001 + Phase 2 BookSource |

## 14. 是否建议继续下一阶段

建议继续 Phase 4 真实网络接入审计规划。设备端校对恢复后应优先补测待复测项。
