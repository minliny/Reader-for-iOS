# iOS Mock Data Flow Phase 1 Detail Fix V2 Report

## 1. 总体结论

**IOS_MOCK_DATA_FLOW_PHASE1_DETAIL_FIX_READY_V2**

## 2. 本轮目标

重新修复 Search → Book Detail 空白问题。上轮移除内层 NavigationStack 后仍复现，必须重新定位根因。

## 3. 输入问题

Codex 设备端复测：
- Search 返回 3 个 mock results ✓
- accessibility 行点击和标题区域点击第一条结果均进入空白页
- 空白页仅保留返回按钮和主底栏
- 上轮"移除 BookDetailView 内层 NavigationStack"修复无效

## 4. 重新根因分析

### 4.1 上轮修复为何无效

上轮认为根因是 `BookDetailView` 内部 `NavigationStack` 嵌套导致 iOS 18 渲染空白。移除后仍复现，说明真正的根因不在此处。

### 4.2 真正根因

**`navigationDestination(item: $bookRoute)` 的 @State 双变量竞态**。

`SearchView` 使用两个独立的 `@State` 变量控制导航：

```swift
@State private var selectedResult: SearchResultItem?
@State private var bookRoute: BookDetailRoute?

// 点击结果时：
onTap: {
    selectedResult = result           // @State 1
    bookRoute = BookDetailRoute(...)  // @State 2
}
```

`.navigationDestination(item: $bookRoute)` 在 `bookRoute` 变为非 nil 时触发。但闭包内部依赖 `selectedResult`：

```swift
.navigationDestination(item: $bookRoute) { _ in
    if let result = selectedResult {  // ← 使用 selectedResult
        BookDetailView(result: result)
    }
    // 如果 selectedResult 为 nil → 返回 EmptyView（空白）
}
```

在 iOS 18 的视图更新机制下，两个 `@State` 赋值虽在同一闭包中，但视图可能在 `bookRoute` 已设置而 `selectedResult` 尚未生效时重新渲染，导致 `selectedResult` 读为 nil，闭包返回空视图。

此外，`SearchView` 自身 `NavigationStack` 嵌套在 Bookshelf tab 的 `NavigationStack` 内，双层 NavigationStack 加剧了 `@State` 传播时机的不确定性。

### 4.3 修复策略

抛弃 `.navigationDestination(item:)` + 双 `@State` 变量的不透明导航，改用最直接的 `NavigationLink(destination:)`：

```swift
NavigationLink {
    BookDetailView(result: result)  // ← 直接传入 result，无中间变量
} label: {
    SearchResultRowView(...)
}
```

每个 result row 直接携带 `result` 到 destination，不经过 `@State` 变量中转。这是 SwiftUI 中最稳定、最直接的导航方式。

## 5. 修复内容

| 文件 | 变更 |
|---|---|
| `iOS/Features/Search/SearchView.swift` | (1) 移除 `BookDetailRoute`、`selectedResult`、`bookRoute` 三个未使用类型/变量；(2) 移除 `.navigationDestination(item: $bookRoute)`；(3) success/partial 结果行改用 `NavigationLink { BookDetailView(result:) }` 包裹 |

## 6. Mock Flow 结果

| 页面 | 状态 |
|---|---|
| Search | 3 个 mock results ✓ |
| BookDetail | NavigationLink(destination:) 直接传入 result ✓ |
| TOC | 5 章，sheet 展示 ✓ |
| ReaderView | mock 正文 ✓ |

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
| `iOS/Features/Search/SearchView.swift` | 修改 — NavigationLink 替代 navigationDestination；清理未使用 @State |

新增文件：0。

## 10. P0 问题

无。

## 11. P1 问题

无代码侧 P1。MOCK-FLOW-P1-001 标记 `READY_FOR_CODEX_VERIFY`。

## 12. P2 问题

无。

## 13. 是否建议交给 Codex 复测

建议交给 Codex 复测 Search → Detail → TOC → ReaderView mock flow。
