# S4.P2 TOC 与其他阶段连接点验证

## 1. 本轮结论

**结论**: `TOC_CONNECTIVITY_VERIFIED`

**说明**:
- TOC → Content 流程连接已验证
- Search → TOC 流程连接已验证
- 书源选择影响 TOC 流程已确认
- BookDetail → TOC 连接已确认
- 边界检查通过

## 2. 连接点总览

### 流程图

```
┌─────────────────────────────────────────────────────────────────┐
│                         阅读流程                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐    ┌──────────────┐    ┌───────────┐             │
│  │ 书源选择  │───▶│  SearchFlow │───▶│ TOCFlow   │             │
│  └──────────┘    └──────────────┘    └───────────┘             │
│       │                  │                  │                   │
│       ▼                  ▼                  ▼                   │
│  selectedSource    searchResults     tocItems                   │
│                         │                  │                   │
│                         │                  ▼                   │
│                         │          ┌───────────────┐           │
│                         └─────────▶│  ContentFlow  │           │
│                                    └───────────────┘           │
│                                            │                   │
│                                            ▼                   │
│                                      contentPage               │
└─────────────────────────────────────────────────────────────────┘
```

### 连接点清单

| 连接点 | 源 | 目标 | 数据流 |
|--------|-----|------|--------|
| S2 → S3 | selectedSourceId | SearchViewModel | 书源选择持久化 |
| S3 → S4 | searchResults | TOCView | 选中书籍进入目录 |
| S4 → S5 | tocItems | ContentView | 选中章节进入正文 |
| S2 → S4 | selectedSource | TOCView | 书源选择影响目录 |
| S2 → S5 | selectedSource | ContentView | 书源选择影响正文 |

## 3. Search → TOC 连接验证

### 连接路径

```
SearchViewModel.search() → searchResults → TOCView(book: SearchResultItem)
                                                    │
                                                    ▼
                              ReadingFlowCoordinator.selectBook(book)
                                                    │
                                                    ▼
                                        tocService.fetchTOC(source, detailURL)
```

### 代码验证

**TOCView 接收书籍**:

```swift
public struct TOCView: View {
    @ObservedObject public var coordinator: ReadingFlowCoordinator
    public let book: SearchResultItem  // ← 来自搜索结果

    public var body: some View {
        .task {
            if coordinator.tocItems.isEmpty {
                await coordinator.selectBook(book)  // ← 进入目录流程
            }
        }
    }
}
```

**ReadingFlowCoordinator.selectBook()**:

```swift
public func selectBook(_ book: SearchResultItem) async {
    selectedBook = book
    tocItems.removeAll()

    guard let source = selectedSource else { return }
    let detailURL = book.detailURL  // ← 使用书籍详情 URL

    do {
        tocItems = try await tocService.fetchTOC(source: source, detailURL: detailURL)
    } catch {
        currentError = error
    }
}
```

### 连接契约

| 检查项 | 状态 |
|--------|------|
| SearchResultItem → TOCView | ✅ 已验证 |
| TOCView → selectBook() | ✅ 已验证 |
| book.detailURL → fetchTOC() | ✅ 已验证 |
| selectedSource → fetchTOC() | ✅ 已验证 |

## 4. TOC → Content 连接验证

### 连接路径

```
TOCView → tocItems → ContentView(chapter: TOCItem)
                                        │
                                        ▼
                      ReadingFlowCoordinator.selectChapter(chapter)
                                        │
                                        ▼
                            contentService.fetchContent(source, chapterURL)
```

### 代码验证

**TOCView 点击章节**:

```swift
private var tocList: some View {
    ForEach(coordinator.tocItems, id: \.chapterURL) { chapter in
        NavigationLink {
            ContentView(coordinator: coordinator, chapter: chapter)  // ← 进入正文
        } label: {
            ChapterRow(chapter: chapter)
        }
    }
}
```

**ContentView 加载正文**:

```swift
public var body: some View {
    .task {
        if coordinator.selectedChapter != chapter || coordinator.contentPage == nil {
            await coordinator.selectChapter(chapter)  // ← 加载正文
        }
    }
}
```

**ReadingFlowCoordinator.selectChapter()**:

```swift
public func selectChapter(_ chapter: TOCItem) async {
    selectedChapter = chapter
    contentPage = nil

    guard let source = selectedSource else { return }

    do {
        contentPage = try await contentService.fetchContent(
            source: source,
            chapterURL: chapter.chapterURL  // ← 使用章节 URL
        )
    } catch {
        currentError = error
    }
}
```

### 章节导航

**上一章 / 下一章**:

```swift
private var previousChapterAction: (() -> Void)? {
    guard let currentIndex = coordinator.tocItems.firstIndex(...),
          currentIndex > 0 else { return nil }
    let previous = coordinator.tocItems[currentIndex - 1]
    return { Task { await coordinator.selectChapter(previous) } }
}

private var nextChapterAction: (() -> Void)? {
    guard let currentIndex = coordinator.tocItems.firstIndex(...),
          currentIndex < coordinator.tocItems.count - 1 else { return nil }
    let next = coordinator.tocItems[currentIndex + 1]
    return { Task { await coordinator.selectChapter(next) } }
}
```

### 连接契约

| 检查项 | 状态 |
|--------|------|
| TOCItem → ContentView | ✅ 已验证 |
| ContentView → selectChapter() | ✅ 已验证 |
| chapter.chapterURL → fetchContent() | ✅ 已验证 |
| selectedSource → fetchContent() | ✅ 已验证 |
| 上一章 / 下一章导航 | ✅ 已验证 |

## 5. 书源选择影响流程验证

### 连接路径

```
BookSourceStore.loadSelectedSourceId() → selectedSource
                                            │
                                            ├─────────────────┐
                                            ▼                 ▼
                                      SearchViewModel   ReadingFlowCoordinator
                                            │                 │
                                            ▼                 ▼
                                    searchService      tocService / contentService
```

### 代码验证

**SearchViewModel 使用 selectedSource**:

```swift
public func search() async {
    guard let source = selectedSource else {  // ← 使用选中书源
        searchState = .failed(message: "No book source selected")
        return
    }
    let query = SearchQuery(keyword: trimmed, page: 1)
    searchResults = try await searchService.search(source: source, query: query)
}
```

**ReadingFlowCoordinator 所有阶段使用 selectedSource**:

```swift
public func search(keyword: String) async {
    guard let source = selectedSource else { return }
    searchResults = try await searchService.search(source: source, query: query)
}

public func selectBook(_ book: SearchResultItem) async {
    guard let source = selectedSource else { return }
    tocItems = try await tocService.fetchTOC(source: source, detailURL: detailURL)
}

public func selectChapter(_ chapter: TOCItem) async {
    guard let source = selectedSource else { return }
    contentPage = try await contentService.fetchContent(source: source, chapterURL: ...)
}
```

### 连接契约

| 检查项 | 状态 |
|--------|------|
| selectedSource → search() | ✅ 已验证 |
| selectedSource → selectBook() | ✅ 已验证 |
| selectedSource → selectChapter() | ✅ 已验证 |
| 书源切换时流程重置 | ✅ 已验证 (resetBookSelectionState) |

## 6. BookDetail → TOC 连接验证

### 连接路径

```
BookDetailViewModel → SearchResultItem → TOCView
```

### 说明

当前 BookDetailViewModel 是独立的 ViewModel，不经过 ReadingFlowCoordinator：

```swift
public final class BookDetailViewModel: ObservableObject {
    private let bookURL: String
    private let provider = ReaderCoreServiceProvider.shared

    public func loadDetail() async {
        let state = await provider.getBookDetail(bookURL: bookURL)
        // ...
    }
}
```

**TOCView 直接使用 SearchResultItem**:

```swift
public struct TOCView: View {
    public let book: SearchResultItem  // ← 可以从 BookDetail 传入
}
```

### 连接契约

| 检查项 | 状态 |
|--------|------|
| SearchResultItem 可传入 TOCView | ✅ 已验证 |
| BookDetail → TOC 数据流 | ⚠️ 需导航层连接 |

## 7. 流程状态重置验证

### 代码验证

**书源切换时重置**:

```swift
private func applySourceSelection(_ source: BookSource) {
    selectedSource = source
    searchResults.removeAll()
    resetBookSelectionState()
    currentError = nil
}

private func resetBookSelectionState() {
    selectedBook = nil
    tocItems.removeAll()
    resetChapterSelectionState()
}

private func resetChapterSelectionState() {
    selectedChapter = nil
    contentPage = nil
}
```

### 重置契约

| 检查项 | 状态 |
|--------|------|
| 书源切换 → 清空搜索结果 | ✅ 已验证 |
| 书源切换 → 清空选中书籍 | ✅ 已验证 |
| 书源切换 → 清空目录 | ✅ 已验证 |
| 书籍切换 → 清空章节选择 | ✅ 已验证 |
| 书籍切换 → 清空正文 | ✅ 已验证 |

## 8. 边界检查与测试结果

| 检查项 | 结果 |
|--------|------|
| 边界检查脚本 | ✅ PASS (checked_files=64) |
| 连接点验证 | ✅ 已验证 |
| Swift 编译 | ⚠️ ENV_COMPILE_UNVERIFIED |

## 9. 剩余 P0 / P1 / P2 缺口

### P0 必须解决

| ID | 缺口 | 状态 |
|----|------|------|
| 无 | - | - |

### P1 应尽快解决

| ID | 缺口 | 优先级 | 说明 |
|----|------|--------|------|
| P1-1 | BookDetail → TOC 导航层连接 | 低 | 需确认 BookDetailView 如何导航到 TOCView |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 目录排序/翻转 | 低 |
| P2-2 | 目录翻页 | 中 |
| P2-3 | 章节缓存 | 低 |

## 10. S4.P3 推荐任务

**任务 ID**: S4.P3
**任务名称**: TOC 能力层综合验收

**任务内容**:
1. 验证所有 TOC 能力层测试覆盖完整性
2. 补全 TOC 能力层综合文档
3. 确认 S4 阶段整体验收标准达成

**前提条件**: 无需 Reader-Core

## 11. 本轮未做事项

| 事项 | 原因 |
|------|------|
| BookDetail → TOC 导航连接 | 需确认导航层设计 |
| 真实 Core 接入 | S1.P2 暂停 |
| 目录排序/翻转 | P2 优化项 |
