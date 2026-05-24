# iOS BookSource Phase 2 Interaction Fix Report

## 1. 总体结论

**IOS_BOOKSOURCE_LOCAL_MANAGEMENT_PHASE2_INTERACTION_FIX_READY**

## 2. 本轮目标

修复 3 个反复阻塞的 P1：详情 sheet 空白、toggle 不工作、本地模拟测试不可触发。

## 3. 根因分析

### P1-002/P1-003：详情 sheet 仍空白

**根因 1**：`BookSourceSheet.id` 对所有 `.detail` case 返回固定 `"detail"`。`.sheet(item:)` 依赖 `Identifiable.id` 区分不同 sheet。当 id 不变时，SwiftUI 不重建 sheet 内容，导致首次打开的空白视图被复用。

**根因 2**：`BookSourceDetailSheet` 使用 `NavigationStack + List`。在 iOS 26.5 Simulator 上，sheet 内的 NavigationStack+List 组合导致内容高度塌缩为空白。

**修复**：
1. `BookSourceSheet.detail` 新增 `id: String` 参数，`var id` 返回 `"detail-\(sourceId)"` 保证唯一性
2. `BookSourceDetailSheet` 改为 `ScrollView + VStack`，移除 NavigationStack 和 List
3. 明确添加 `.background(Color(.systemBackground))` 防止透明

### P1-004：toggle 不工作

**根因**：`sources[idx].enabled.toggle()` 对 `@State` 数组内 struct 进行 in-place mutation。SwiftUI `@State` 不检测数组内元素的属性变更，不触发重渲染。

**修复**：改为整体替换数组：
```swift
var copy = sources
copy[idx].enabled.toggle()
sources = copy
```

## 4. 其他改进

- 本地模拟测试改为 **deterministic**（始终返回"测试成功：本地 fixture 可用"），避免随机结果复测不稳定
- 删除 `loadSources()` async（不需要），改为同步（直接赋值 fixtureSources）
- 测试按钮支持"重新测试"

## 5. 修改文件

| 文件 | 变更 |
|---|---|
| `iOS/Features/BookSources/BookSourceListView.swift` | (1) BookSourceSheet id 唯一化；(2) toggle 用数组整体替换；(3) loadSources 同步化 |
| `iOS/Features/BookSources/BookSourceDetailSheet.swift` | (1) NavigationStack+List → ScrollView+VStack + 背景色；(2) test deterministic |

## 6. Build / Boundary

| 命令 | 结果 |
|---|---|
| `check_ios_boundary.sh` | PASS（87 files, 0 violations） |
| `xcodebuild build` | BUILD SUCCEEDED |

## 7. P0/P1/P2

- P0: 0
- P1: 0（代码侧），3 个 READY_FOR_CODEX_VERIFY
- P2: 0

## 8. 建议交给 Codex 复测
