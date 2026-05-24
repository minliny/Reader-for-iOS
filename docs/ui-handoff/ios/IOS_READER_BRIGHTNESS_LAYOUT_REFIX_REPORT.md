# iOS Reader Brightness Layout Refix Report

## 1. 总体结论

**IOS_READER_BRIGHTNESS_LAYOUT_REFIX_READY**

## 2. 本轮目标

重新修复亮度条占据大量空间问题。上轮 `40x180pt` 左侧竖向 overlay 仍过于突出，不符合"只占正文空间/控制层区域"的通过标准。本轮改为紧凑横向控制行。

## 3. 输入状态纠偏

- 上轮 Codex 报告 `READER-P1-002 DEVICE_VERIFIED_RESOLVED`
- 用户人工复核认为不成立：亮度条未修复，仍然占据大量空间
- **READER-P1-002 已 REOPENED**

## 4. 根因分析

上轮修复将亮度条从全屏 VStack 改为 `.overlay(alignment: .leading)`，但保留了 40x180pt 的竖向 Capsule 控件。该竖向条虽然宽度仅 40pt，但高度达 180pt，位于屏幕左侧居中位置，占据了大量视觉空间并覆盖正文区域，不符合 Reader 控制层规划的"局部控件"语义。

## 5. 修复方案

采用**方案 A：横向亮度控制行**。

### 控件新布局

```
┌──────────────────────────────────────┐
│  Top Bar (56pt)                       │
│  Meta Row (48pt)                      │
│  ┌────────────────────────────────┐   │
│  │ ☀ ───●─── ☀ 系统              │   │ ← 亮度控制行 (44pt)
│  └────────────────────────────────┘   │
│                                       │
│  正文内容（不受遮挡）                  │
│                                       │
├──────────────────────────────────────┤
│  Quick Actions + Page Control         │
│  Bottom Bar (68pt)                    │
└──────────────────────────────────────┘
```

### 控件规格

| 属性 | 值 |
|---|---|
| 位置 | 顶部（top bar + meta row 下方 8pt） |
| 尺寸 | 高度 44pt，宽度随屏幕（水平 padding 20pt） |
| 内容 | `sun.min` | `Slider` | `sun.max` | "系统" |
| 样式 | `colors.float` 背景，圆角 12pt |
| 实现 | `.overlay(alignment: .top)` + `padding(.top, 112)` |

### 改进

| 之前 (上轮) | 之后 (本轮) |
|---|---|
| 竖向 Capsule 40x180pt | 横向行 44pt 高 |
| `.overlay(alignment: .leading)` 左侧浮动 | `.overlay(alignment: .top)` 顶部浮动 |
| 覆盖正文左侧大量区域 | 仅占顶部控制区，不覆盖正文 |
| 无 Slider 交互 | 真实 Slider 可拖拽调节 |

## 6. 修改文件

| 文件 | 变更 |
|---|---|
| `iOS/Modules/Prototype/PrototypeGalleryView.swift` | 亮度条从 40x180pt 竖向 overlay 改为 44pt 高横向控制行；移除未使用的 `dock` 状态变量 |

新增文件：0。

## 7. Reader 控制层规则验证

| 检查项 | 结果 |
|---|---|
| 亮度控制是否局部化 | 是（44pt 高固定行） |
| 是否不全屏 | 是（无 maxHeight: .infinity） |
| 是否不占据大量正文 | 是（仅顶部 44pt 行） |
| 是否保留正文可见 | 是（正文区域不受遮挡） |
| 是否保留四角信息 | 是 |
| 是否保留底部控制层 | 是 |
| 是否覆盖顶部控制区 | 否（位于 top bar + meta row 下方） |
| 是否有亮度图标 + "系统" | 是（sun.min/sun.max + 系统） |

## 8. Boundary / Safety 检查

| 检查项 | 结果 |
|---|---|
| 是否未引用 parser internals | PASS |
| 是否无 WebView UI | PASS |
| 是否无真实网络 | PASS |
| 是否未接真实 WebDAV/RSS/同步 | PASS |
| 是否未修改 Reader-Core | PASS |
| clean-room | PASS |

## 9. 测试 / Build 结果

| 命令 | 结果 |
|---|---|
| `bash scripts/check_ios_boundary.sh` | PASS（82 files, 0 violations） |
| `xcodebuild build -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` | **BUILD SUCCEEDED** |

## 10. P0 问题

无。

## 11. P1 问题

无代码侧 P1。READER-P1-002 标记 `READY_FOR_CODEX_VERIFY`，等待 Codex 设备端复测。

## 12. P2 问题

- APP-SHELL-SIM-P2-001：书架/书源英文文案
- APP-SHELL-SIM-P2-002：生产 ReaderView 设备端路径待补

## 13. 是否建议交给 Codex 复测

建议交给 Codex 复测亮度条布局。

条件全部满足：boundary PASS、fresh build 成功、无 P0/P1。
