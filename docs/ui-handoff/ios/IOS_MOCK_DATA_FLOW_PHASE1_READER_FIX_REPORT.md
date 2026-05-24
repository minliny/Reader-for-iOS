# iOS Mock Data Flow Phase 1 Reader Fix Report

## 1. 总体结论

**IOS_MOCK_DATA_FLOW_PHASE1_READER_FIX_READY**

## 2. 本轮目标

修复 MOCK-FLOW-P1-002：TOC 点击章节后 ReaderView 只显示 yellow warning 图标，无 mock 正文。

## 3. 输入问题

Codex V2 设备端复测：
- Search → Detail 已通过（V2 修复）
- TOC 5 章可见
- 点击"第一章 山村少年"后只显示黄色 warning 图标
- 无章节标题、无 mock 正文
- 主底栏已隐藏（`.toolbar(.hidden, for: .tabBar)` 生效）

## 4. 根因分析

**双重 NavigationStack 嵌套导致 ReaderView 内容渲染异常。**

链条：
```
Bookshelf Tab NavigationStack
 → SearchView NavigationStack (pushed)
  → BookDetailView (sheet)
   → ChapterListView NavigationStack (sheet content)
    → ReaderView NavigationStack (pushed via navigationDestination)
```

ReaderView 有自身 NavigationStack，当从 ChapterListView 的 NavigationStack 内通过 `.navigationDestination` 推送时，形成嵌套 NavigationStack。在 iOS 18 上，内层 NavigationStack 的 `VStack(spacing: 0)` 布局无法正确分配到可用高度，导致 `readerStateView`（尤其是 `.partial`/`.loaded` 状态的 ScrollView）高度为零或极小，只渲染出 warning label 而正文 ScrollView 被压缩。

**为什么 Debug ReaderView Fixture 不受影响**：fixture 使用 pre-loaded `readerState = .loaded(content:)` ，绕过了 `loadContent()` 和 NavigationStack 的嵌套渲染时序问题。

## 5. 修复内容

### 修改文件

| 文件 | 变更 |
|---|---|
| `iOS/Features/Reader/ReaderView.swift` | (1) 移除内层 `NavigationStack` wrapper，`.navigationTitle`/`.toolbar`/`.sheet` 使用父级 NavigationStack 上下文；(2) `.toolbar(.hidden, for: .tabBar)` 直接附加到内容；(3) `.partial` 状态 ScrollView 添加 `.frame(maxHeight: .infinity)` 确保正文区不塌缩 |

### 修复后结构

```
ReaderView (无 NavigationStack wrapper)
 → ZStack { contentBackground + VStack(progressSurface, readerStateView, actionBar) }
 → .navigationTitle / .toolbar / .sheet (uses parent NavigationStack)
 → .toolbar(.hidden, for: .tabBar)
 → .safeAreaInset (TTS panel)
```

## 6. Mock Flow 结果

| 页面 | 状态 |
|---|---|
| Search | 3 个 mock results ✓ |
| Detail | mock 数据可见（V2 修复） ✓ |
| TOC | 5 章，点击可导航 ✓ |
| ReaderView | 无嵌套 NavigationStack，mock content 可渲染 ✓ |

## 7. Bound / Safety

| 检查项 | 结果 |
|---|---|
| 是否未引用 parser internals | PASS |
| 是否无真实网络 | PASS |
| 是否未接 WebDAV/RSS/Sync | PASS |
| 是否未修改 Reader-Core | PASS |
| clean-room | PASS |

## 8. 测试 / Build 结果

| 命令 | 结果 |
|---|---|
| `bash scripts/check_ios_boundary.sh` | PASS（83 files, 0 violations） |
| `xcodebuild build` | **BUILD SUCCEEDED** |

## 9. 修改文件

| 文件 | 变更 |
|---|---|
| `iOS/Features/Reader/ReaderView.swift` | 修改 — 移除 NavigationStack wrapper + partial ScrollView frame fix |

新增文件：0。

## 10. P0 问题

无。

## 11. P1 问题

无代码侧 P1。
- MOCK-FLOW-P1-001：DEVICE_VERIFIED_RESOLVED
- MOCK-FLOW-P1-002：READY_FOR_CODEX_VERIFY

## 12. P2 问题

- MOCK-FLOW-P2-001：Book Detail 可见信息不足（简介/来源/最新章节未显式渲染）— 保留 P2

## 13. 是否建议交给 Codex 复测

建议交给 Codex 复测 Search → Detail → TOC → ReaderView mock flow。
