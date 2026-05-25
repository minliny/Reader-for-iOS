# iOS BookSource Phase 2 Toggle Button Fix Report

## 1. 总体结论

**IOS_BOOKSOURCE_LOCAL_MANAGEMENT_PHASE2_TOGGLE_BUTTON_FIX_READY**

## 2. 本轮目标

修复 BOOKSOURCE-P2-P1-004：Switch 点击后 Value 不变、状态标签不切换。不接真实网络。

## 3. 根因分析

上轮已将 `source` 改为 `@Binding var enabled` + ID-lookup Binding，数据层正确。但 SwiftUI `Toggle` 在包含 `.onTapGesture` + `.contentShape(Rectangle())` 的 row 卡片内，其交互被父级手势截获。设备端 Accessibility switch Value 始终为 1，点击/space/拖动均不改变，说明 Toggle 的 setter 从未被调用。

**根因**：SwiftUI `Toggle` 处于 `.onTapGesture` 区域内时，系统手势识别优先级冲突导致 Toggle 点击失效。

## 4. 修复

| 变更 | 说明 |
|---|---|
| 移除 `Toggle` | 不再使用 SwiftUI Toggle 控件 |
| 新增显式 `Button` | "启用" / "停用" 按钮，点击直接调用 `enabled.toggle()` |
| 状态标签 | "当前状态：已启用" / "当前状态：已禁用" + 对应系统图标 |
| 按钮区域 | 独立 `.buttonStyle(.plain)`，不与 row tap 冲突 |

## 5. 修改文件

`iOS/Features/BookSources/BookSourceRowView.swift` — Toggle 替换为显式 Button("启用"/"停用")

## 6. Build / Boundary

| 命令 | 结果 |
|---|---|
| `check_ios_boundary.sh` | PASS（87 files, 0 violations） |
| `xcodebuild build` | BUILD SUCCEEDED |

## 7. P0/P1/P2

- P0: 0
- P1: 0（代码侧），1 READY_FOR_CODEX_VERIFY
- P2: 0

## 8. 建议交给 Codex 只复测按钮切换
