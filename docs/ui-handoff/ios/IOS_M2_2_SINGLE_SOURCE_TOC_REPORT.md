# iOS M2.2 Single Source TOC Report

## 1. 总体结论

**IOS_M2_2_SINGLE_SOURCE_TOC_READY**

## 2. Implementation

| 变更 | 说明 |
|---|---|
| `ChapterListView` | 新增 sourceName 参数 |
| `BookDetailView` → TOC sheet | 传入 sourceName |
| `TOCSnapshot` + `TOCSnapshotItem` | Codable 模型 |
| `SnapshotStore.saveTOCSnapshot/loadTOCSnapshot` | M2.2 TOC 快照 |
| `SingleSourceTOCM2Tests` | 7 tests |

## 3. TOC Flow

```
BookDetail → "查看目录" → sheet → ChapterListView(bookURL, bookTitle, sourceName)
→ ChapterListViewModel.loadChapters() → provider.getChapterList(bookURL)
→ mock/offlineReplay → 5 chapters displayed
→ tap chapter → ReaderView (using existing NavigationLink, M2.3 Content)
```

## 4. Safety

| 检查 | 结果 |
|---|---|
| Provider 默认 mock | ✓ |
| Real network 未执行 | ✓ |
| Content 未做 | ✓ |
| M1 Search 保持 | ✓ |
| M2.1 Detail 保持 | ✓ |
| Boundary | PASS (100 files) |
| Build | BUILD SUCCEEDED |

## 5. Next: M2.3 Content
