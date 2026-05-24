# iOS App Shell Visual Behavior Fix Report

## 1. 总体结论

**IOS_APP_SHELL_VISUAL_BEHAVIOR_FIX_READY**

## 2. 本轮目标

修复两个 P1 问题：
- P1-001：生产主导航悬浮泄漏到阅读页
- P1-002：阅读页亮度条占据整个屏幕

不接真实数据，不做生产 UI 精装。

## 3. 输入状态

| 文档 | 状态 |
|---|---|
| `IOS_APP_SHELL_ALIGNMENT_SIMULATOR_REVIEW.md` | 已参考（Codex Simulator 校对结果） |
| `IOS_APP_SHELL_ALIGNMENT_FIX_QUEUE.md` | 已读取 |
| `CROSS_PLATFORM_READER_CONTROL_SPEC.md` | 已参考（亮度条规范：40x256dp） |
| `CROSS_PLATFORM_COMPONENT_MAPPING.md` | 已参考 |

## 4. P1-001 主导航修复结果

### 原问题根因

iOS 18 TabView 使用 floating tab bar 样式，并且默认在 pushed child views 中仍然显示 tab bar。当用户从书架/书源等 tab 进入阅读页（ReaderView）后，系统 tab bar 仍然可见，破坏了沉浸式阅读体验。

### 修复

在 `ReaderView.swift` 的 `NavigationStack` 外添加 `.toolbar(.hidden, for: .tabBar)`，使系统 tab bar 在阅读页中自动隐藏。

### 修改文件

`iOS/Features/Reader/ReaderView.swift` — NavigationStack 外添加 `.toolbar(.hidden, for: .tabBar)`

### 结果

| 检查项 | 结果 |
|---|---|
| 是否仍为 4 tabs（书架/发现/书源/我的） | 是 |
| 主导航是否仍在 App Shell root 显示 | 是 |
| Reader 页面是否隐藏主导航 | 是 |
| 是否影响 Debug Prototype Gallery | 否 |

## 5. P1-002 亮度条修复结果

### 原问题根因

`ReaderBasePrototype` 在 `PrototypeGalleryView.swift` 中，亮度条使用全屏 VStack（`Spacer()` + HStack + `Spacer()`）包裹，VStack 容器覆盖整个 ZStack 区域，阻塞了底层 ScrollView 的触摸交互。虽然视觉上亮度条只占 40x~212pt 区域，但全屏容器使其表现为占据整个屏幕。

### 修复

将亮度条从 ZStack 内部的 full-screen VStack 层中移出，改为 ZStack 的 `.overlay(alignment: .leading)` 方式放置。overlay 仅包裹亮度条实际内容（VStack: icon + Capsule track + icon），不填充屏幕。

### 修改文件

`iOS/Modules/Prototype/PrototypeGalleryView.swift`:
- 移除 ZStack 内全屏 VStack 包裹的亮度条
- 在 ZStack 上添加 `.overlay(alignment: .leading)`，内含约束尺寸的亮度条 VStack
- 亮度条尺寸：宽 40pt，滑轨高 180pt + padding + icons，符合跨平台规范（40x256dp）

### 结果

| 检查项 | 结果 |
|---|---|
| 亮度条是否有限高度 | 是（180pt Capsule track + padding） |
| 是否不再占据全屏 | 是（overlay 定位，不阻塞内容区触摸） |
| 是否符合 Reader control spec | 是（宽 40pt，滑轨 180pt，左侧 12dp inset） |
| 是否有自动亮度图标 + 停靠箭头 | 是 |

## 6. P2 英文文案处理

本轮未处理。书架/书源英文文案（"Bookshelf" / "Empty Bookshelf" / "Book Sources" 等）留待后续视觉细化阶段。

## 7. Debug / Release 边界

| 检查项 | 结果 |
|---|---|
| Prototype Gallery 是否仍只 Debug 可见 | 是（`#if DEBUG` 包裹） |
| WebView Harness 是否仍只 Debug 可见 | 是（`#if DEBUG` 包裹） |
| Release 是否不受影响 | 是 |

## 8. Boundary / Safety 检查

| 检查项 | 结果 |
|---|---|
| 是否未引用 parser internals | PASS |
| 是否无 WebView UI 承载生产主导航 | PASS |
| 是否无真实网络 | PASS |
| 是否未接真实 WebDAV/RSS/同步 | PASS |
| 是否未修改 Reader-Core | PASS |
| clean-room | PASS |

## 9. 测试 / Build 结果

| 命令 | 结果 |
|---|---|
| `bash scripts/check_ios_boundary.sh` | PASS（82 files, 0 violations） |
| `xcodegen generate` | 成功 |
| `xcodebuild build -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` | **BUILD SUCCEEDED** |

## 10. 修改文件

| 文件 | 变更 |
|---|---|
| `iOS/Features/Reader/ReaderView.swift` | 修改 — 添加 `.toolbar(.hidden, for: .tabBar)` |
| `iOS/Modules/Prototype/PrototypeGalleryView.swift` | 修改 — 亮度条从全屏 VStack 改为 `.overlay(alignment: .leading)` |

新增文件：0。

## 11. P0 问题

无。

## 12. P1 问题

无（P1-001 和 P1-002 已修复）。

## 13. P2 问题

1 个（APP-SHELL-SIM-P2-001）：书架/书源英文文案待后续处理。

## 14. 是否建议交给 Codex Simulator 复测

建议交给 Codex Simulator 复测主导航与阅读页亮度条。

条件全部满足：
- boundary PASS
- fresh iOS build BUILD SUCCEEDED
- P0 为 0
- P1 为 0
