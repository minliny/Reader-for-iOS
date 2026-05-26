# iOS BookSource Phase 2 Toggle Fix Report

## 1. 总体结论

**IOS_BOOKSOURCE_LOCAL_MANAGEMENT_PHASE2_TOGGLE_FIX_READY**

## 2. 本轮目标

修复 BOOKSOURCE-P2-P1-004：启用/禁用 Toggle 设备端无可见状态变化。不接真实网络。

## 3. 根因分析

上轮修复已正确用整体数组替换触发 `@State` 刷新。但 `BookSourceRowView` 的 `source` 是 `let` 属性，且 Toggle 使用 `Binding(get: { source.enabled }, set: { _ in onToggle() })`。当 `ForEach` 因 `id` 不变而复用视图时，`source` 不会重新传入，Toggle 的 `get:` 一直返回旧值。

**根因**：`source` 在 RowView 中是不可变的（`let`），`ForEach` 复用视图时不重新 init，导致 Toggle 绑定读数陈旧。

**修复**：`BookSourceRowView` 改为接收 `name/url/group` 值 + `@Binding var enabled: Bool`。Binding 在 `get:` 中通过 sourceId 实时查找 `sources` 数组，`set:` 中整体替换数组。不受视图复用影响。

## 4. 修改文件

| 文件 | 变更 |
|---|---|
| `iOS/Features/BookSources/BookSourceRowView.swift` | 重构：`source: BookSource + onToggle` → `name/url/group + @Binding var enabled` |
| `iOS/Features/BookSources/BookSourceListView.swift` | sourceRow 改为构造基于 sourceId 的 `Binding<Bool>`，get/set 均实时查找 |

## 5. Build / Boundary

| 命令 | 结果 |
|---|---|
| `check_ios_boundary.sh` | PASS（87 files, 0 violations） |
| `xcodebuild build` | BUILD SUCCEEDED |

## 6. P0/P1/P2

- P0: 0
- P1: 0（代码侧），1 个 READY_FOR_CODEX_VERIFY
- P2: 0

## 7. 建议交给 Codex 复测
