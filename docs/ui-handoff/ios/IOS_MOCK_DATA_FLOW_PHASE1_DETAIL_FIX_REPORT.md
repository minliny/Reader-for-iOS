# iOS Mock Data Flow Phase 1 Detail Fix Report

## 1. 总体结论

**IOS_MOCK_DATA_FLOW_PHASE1_DETAIL_FIX_READY**

## 2. 本轮目标

修复 MOCK-FLOW-P1-001：Search result 点击后 Book Detail 空白问题。不接真实网络。

## 3. 输入问题

Codex 设备端复测发现：
- Search 可返回 3 个 mock results
- 点击第一个 result 后进入空白页面（仅返回按钮和主底栏）
- 等待超过 2 秒未恢复
- Book Detail 空白阻断 TOC 与 ReaderView 闭环

## 4. 根因分析

**根因：`BookDetailView` 内部嵌套 `NavigationStack`。**

`SearchView` 已有 `NavigationStack`，其中 `.navigationDestination(item: $bookRoute)` 推送 `BookDetailView`。但 `BookDetailView.body` 包裹了另一个 `NavigationStack`：

```swift
// BookDetailView (修复前)
var body: some View {
    NavigationStack {        // ← 内层 NavigationStack
        ScrollView { ... }
        .navigationDestination(isPresented: $showChapterList) { ... }
    }
}
```

在 iOS 18 上，当已推送的 view 内部又有一个 NavigationStack 时，内层 NavigationStack 无法正确渲染其 root 内容，导致空白页面。这是一个双 NavigationStack 嵌套渲染问题。

## 5. 修复内容

| 文件 | 变更 |
|---|---|
| `iOS/Features/BookDetail/BookDetailView.swift` | 移除内层 `NavigationStack`；`.navigationDestination` → `.sheet` 展示 ChapterListView；标题改为"书籍详情" |
| `iOS/Tests/ReaderAppTests/MockDataFlowTests.swift` | 新增 `testMockDetailLoadsFromSearchResult` 测试 |

### 修复后结构

```swift
// BookDetailView (修复后)
var body: some View {
    ScrollView { ... }
    .navigationTitle("书籍详情")
    .sheet(isPresented: $showChapterList) {
        ChapterListView(...)
    }
}
```

- 无内层 NavigationStack，由父级 SearchView 的 NavigationStack 提供导航上下文
- ChapterListView 通过 `.sheet` 弹出，避免嵌套导航
- Mock data flow 保持不变

## 6. Mock Flow 结果

| 页面 | 状态 |
|---|---|
| Search | 3 个 mock results ✓ |
| BookDetail | mock detail 数据可加载（凡人修仙传，忘语） ✓ |
| TOC | 5 章 mock 目录 ✓ |
| ReaderView | mock 正文内容 ✓ |

## 7. Boundary / Safety

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
| `xcodebuild build -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` | **BUILD SUCCEEDED** |

## 9. 修改文件

| 文件 | 变更 |
|---|---|
| `iOS/Features/BookDetail/BookDetailView.swift` | 修改 — 移除嵌套 NavigationStack，改用 sheet |
| `iOS/Tests/ReaderAppTests/MockDataFlowTests.swift` | 修改 — 新增 detail load 测试 |

新增文件：0。

## 10. P0 问题

无。

## 11. P1 问题

无代码侧 P1。MOCK-FLOW-P1-001 标记 `READY_FOR_CODEX_VERIFY`。

## 12. P2 问题

无。

## 13. 是否建议交给 Codex 复测

建议交给 Codex 复测 Search → Detail → TOC → ReaderView mock flow。
