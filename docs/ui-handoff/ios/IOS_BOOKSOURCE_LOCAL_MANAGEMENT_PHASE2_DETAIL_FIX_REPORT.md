# iOS BookSource Phase 2 Detail Fix Report

## 1. 总体结论

**IOS_BOOKSOURCE_LOCAL_MANAGEMENT_PHASE2_DETAIL_FIX_READY**

## 2. 本轮目标

修复 BookSource 详情 sheet 空白 + 本地模拟测试不可触发。不接真实网络。

## 3. 根因分析

**BOOKSOURCE-P2-P1-002（sheet 空白）**：

BookSourceListView 有三个 `.sheet(isPresented:)` modifier 附着在同一视图上（import / share / detail），在 iOS 18 上多 sheet modifier 存在冲突——只有最外层 sheet 正常工作，内层 sheet 打开时内容区域为空白。上轮改为 ScrollView+VStack 无效，因为问题不在内容布局而在 sheet 分发机制。

**修复**：
1. 将三个 `.sheet(isPresented:)` 合并为单个 `.sheet(item: $activeSheet)`，用 `BookSourceSheet` 枚举分发
2. 新建 `BookSourceDetailSheet` — NavigationStack+List 包裹的独立 View，专用于 sheet 展示
3. toggle/delete 改为本地 state 操作（不再依赖 BookSourceStore）

**BOOKSOURCE-P2-P1-003（本地模拟测试不可触发）**：

由详情空白导致，已随 P1-002 修复。

## 4. 修复内容

| 文件 | 变更 |
|---|---|
| `iOS/Features/BookSources/BookSourceListView.swift` | (1) 三 sheet → 单 sheet(item:) + BookSourceSheet 枚举分发；(2) toggle/delete 改为 local state；(3) 移除 BookSourceStore/ReaderAppPersistence 依赖 |
| `iOS/Features/BookSources/BookSourceDetailSheet.swift` | 新增：NavigationStack+List 包裹的详情 sheet View |

## 5. Mock Flow 兼容

| 检查项 | 结果 |
|---|---|
| 5 个 fixture 书源 | 保持 |
| 导入入口 | 保持 |
| Search mock flow | 不受影响 |
| Debug Prototype Gallery | 不受影响 |

## 6. Boundary / Safety

| 检查项 | 结果 |
|---|---|
| 是否未引用 parser internals | PASS |
| 是否无真实网络 | PASS |
| 是否未修改 Reader-Core | PASS |
| clean-room | PASS |

## 7. Build / Test 结果

| 命令 | 结果 |
|---|---|
| `bash scripts/check_ios_boundary.sh` | PASS（87 files, 0 violations） |
| `xcodebuild build` | **BUILD SUCCEEDED** |

## 8. 修改文件

| 文件 | 变更 |
|---|---|
| `iOS/Features/BookSources/BookSourceListView.swift` | 修改 — 单 sheet(item:) + local state |
| `iOS/Features/BookSources/BookSourceDetailSheet.swift` | 新增 |

## 9. P0/P1/P2

- P0: 0
- P1: 0（代码侧），2 个 READY_FOR_CODEX_VERIFY
- P2: 0

## 10. 建议交给 Codex 复测
