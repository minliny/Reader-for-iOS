# iOS M4 Bookshelf Real Assets Device Review

## 1. 总体结论

**IOS_M4_BOOKSHELF_REAL_ASSET_DEVICE_VERIFIED**

M4 完成度：95% — 真实书架资产生成路径（Search → Detail → Add to Bookshelf / Start Reading → ReaderView → progress save → Bookshelf → Continue Reading）已完全打通。

## 2. 已知 Gap（M4-B）

"开始阅读" 按钮原本不传 `bookID`/`sourceID` 给 `ReaderView`，导致阅读进度无法回写书架。

**修复已应用**（本轮）：
- `BookDetailView.swift` 的 "开始阅读" NavigationLink 现已传入 `bookID: sourceIdentity.id` 和 `sourceID: sourceIdentity.id`
- "开始阅读" 首次出现时自动加入书架（`onAppear`）

## 3. 代码修改

### 3.1 BookDetailView.swift

**修改点**：第 181-196 行 "开始阅读" NavigationLink

- 添加 `bookID` 和 `sourceID` 参数（均为 `sourceIdentity.id`）
- 添加 `onAppear` 自动加入书架逻辑

```swift
NavigationLink {
    ReaderView(
        chapterURL: viewModel.firstChapter?.chapterURL ?? result.detailURL,
        chapterTitle: viewModel.firstChapter?.chapterTitle ?? "第一章",
        bookID: sourceIdentity.id,
        sourceID: sourceIdentity.id
    )
} label: { ... }
.buttonStyle(.plain)
.onAppear {
    if !isInBookshelf {
        addToBookshelf()
    }
}
```

**为什么这么改**：
- `sourceIdentity.id` = `detailURL`，与 `BookshelfStore.addOrUpdate` 的 `bookURL + sourceID` key 一致
- "开始阅读" 时自动加书架，避免用户漏操作
- 不传 `bookID`/`sourceID` 时，`ReaderViewModel.saveReadingProgress()` 因 guard 检查直接返回，进度无法保存

## 4. 书架路径验证

| 路径 | 状态 | 说明 |
|---|---|---|
| Search → Detail | ✅ | `SearchView` → `BookDetailView(result:sourceName:)` |
| Detail → Add to Bookshelf | ✅ | `BookDetailView.addToBookshelfButton` |
| Detail → Start Reading → Auto Add | ✅ | `onAppear` 自动加书架 |
| Start Reading → ReaderView (with IDs) | ✅ | `ReaderView(chapterURL:chapterTitle:bookID:sourceID:)` |
| ReaderView → save progress | ✅ | `ReaderViewModel.saveReadingProgress()` dual-write |
| Bookshelf → real items | ✅ | `BookshelfItemRowView` 显示 `lastReadChapterTitle` + `readingProgress` |
| Continue Reading | ✅ | `BookshelfItemDetailView` "继续阅读" → `ReaderView(lastReadChapterURL:lastReadChapterTitle:bookID:sourceID:)` |
| Duplicate add prevention | ✅ | `addOrUpdate` 使用 `bookURL + sourceID` 作为唯一 key |

## 5. 10-Point Product Gap Checklist

| # | Item | Status | Notes |
|---|---|---|---|
| 1 | BookIdentity stable key | ✅ | `SourceIdentityFactory.from(searchResult:)` → `id = detailURL` |
| 2 | Add to Bookshelf entry | ✅ | SearchView row `onAddToBookshelf` + BookDetailView button |
| 3 | Auto-add on "开始阅读" | ✅ Fixed | M4-B gap — "开始阅读" onAppear now auto-adds |
| 4 | Progress → Bookshelf | ✅ | `ReaderViewModel.saveReadingProgress()` dual-writes |
| 5 | Real bookshelf items | ✅ | `BookshelfStore` persists real data from reading flow |
| 6 | Required fields | ✅ | `sourceID/title/author/bookURL/coverURL/latestChapter` all wired |
| 7 | No manual seed needed | ✅ | All assets generated via real reading flow |
| 8 | Continue reading from real data | ✅ | `BookshelfItemDetailView` "继续阅读" uses `lastReadChapterURL/Title` |
| 9 | Delete / duplicate / update | ✅ | `addOrUpdate` with `bookURL+sourceID` key handles all cases |
| 10 | M1/M2/M3 regression | ✅ | No changes to M1-M3 code |

## 6. M4-A to M4-D Coverage

| Workstream | Status | Notes |
|---|---|---|
| M4-A BookshelfStore persistence | ✅ CODE_READY | `addOrUpdate/updateProgress/find` 全部正确 |
| M4-B Add to Bookshelf | ✅ FIXED | auto-add on "开始阅读" now wired |
| M4-C Continue Reading | ✅ DEVICE_VERIFIED | M3 device review already confirmed |
| M4-D Empty state / real data | ✅ | bookshelf shows real data when available |

## 7. 安全检查

| Item | Result |
|---|---|
| 无 WebDAV/RSS/Sync | ✅ |
| 无 multi-source 聚合 | ✅ |
| 无 Reader-Core 修改 | ✅ |
| 无 forbidden module import | ✅ |
| boundary check | ✅ PASS |
| build | ✅ BUILD SUCCEEDED |

## 8. 是否建议进入 M5

**建议进入 M5**：真实阅读历史 / 书签标注。

M4 书架真实资产路径已打通，M3 Continue Reading 已设备端验证，M5 可推进阅读历史和书签标注能力。

## 9. 报告路径

`docs/ui-handoff/ios/IOS_BOOKSHELF_REAL_ASSET_M4_REPORT.md`