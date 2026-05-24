# iOS BookSource Local Management Phase 2 Device P1 Fix Report

## 1. 总体结论

**IOS_BOOKSOURCE_LOCAL_MANAGEMENT_PHASE2_DEVICE_P1_FIX_READY**

## 2. 本轮目标

修复 Codex 设备端发现的 3 个 P1，不接真实网络。

## 3. 输入问题

| ID | 问题 |
|---|---|
| BOOKSOURCE-P2-P1-001 | 仅显示 1 个 Mock 书源（非 5 个 fixture） |
| BOOKSOURCE-P2-P1-002 | 详情 sheet 空白 |
| BOOKSOURCE-P2-P1-003 | 本地模拟测试不可触发 |

## 4. 根因分析

### P1-001：只显示 1 个 Mock 书源

`loadSources()` 从 `BookSourceStore.shared` 加载数据。Phase 1 的 `SearchViewModel.loadSources()` 已向 store 添加了 1 个 "Mock 书源"。当 `BookSourceListView` 检查 `list.isEmpty` 时，列表非空（有 1 个 Mock 书源），因此 5 个 fixture 永远不被加载。

**修复**：`loadSources()` 不再查询 store，直接使用 `Self.fixtureSources` 作为数据源。fixture 是离线 demo 的 canonical 数据。

### P1-002：详情 sheet 空白

`BookSourceDetailView` 使用 `NavigationStack { List { Section { ... } } }` 布局。在 iOS 18 上，sheet 内嵌套 NavigationStack + List 会导致内容区域渲染为空白。

**修复**：移除 NavigationStack，用 `ScrollView + VStack` 替代 List。内容以 `.padding()` + `Divider()` 分段，不依赖 List Section 语义。

### P1-003：本地模拟测试不可触发

由 P1-002 导致（详情空白，按钮不可见）。详情修复后，本地模拟测试按钮自然可见且可触发。

**附修**：按钮 disabled 逻辑简化为 `testState == "测试中..."`，避免复杂的可选链判断。

## 5. 修复内容

| 文件 | 变更 |
|---|---|
| `iOS/Features/BookSources/BookSourceListView.swift` | `loadSources()` 直接使用 `fixtureSources`，不再查询 store |
| `iOS/Features/BookSources/BookSourceDetailView.swift` | NavigationStack+List → ScrollView+VStack；按钮 disabled 逻辑简化 |

## 6. Phase 1 状态更新

MOCK-FLOW-P2-001 已设备端通过 → **DEVICE_VERIFIED_RESOLVED**。

Phase 1 所有 P0/P1/P2 已清零。

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
| `bash scripts/check_ios_boundary.sh` | PASS（86 files, 0 violations） |
| `xcodebuild build` | **BUILD SUCCEEDED** |

## 9. 修改文件

| 文件 | 变更 |
|---|---|
| `iOS/Features/BookSources/BookSourceListView.swift` | loadSources() 改为直接使用 fixtureSources |
| `iOS/Features/BookSources/BookSourceDetailView.swift` | 移除 NavigationStack+List，改用 ScrollView+VStack |

新增文件：0。

## 10. P0 问题

无。

## 11. P1 问题

无代码侧 P1。3 个 BookSource P1 标记 `READY_FOR_CODEX_VERIFY`。

## 12. P2 问题

无。

## 13. 是否建议交给 Codex 复测

建议交给 Codex 复测 BookSource local management Phase 2。
