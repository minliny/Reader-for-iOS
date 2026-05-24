# iOS SwiftUI Prototype Fix Queue

## 摘要

| 风险等级 | 数量 |
|---|---|
| P0 | 0 |
| P1 | 0 |
| P2 | 2 |
| P3 | 0 |

---

## P2 Issues

### P2-001：Reader 四角信息不完整

| 字段 | 值 |
|---|---|
| Issue ID | IOS-PROTO-P2-001 |
| 风险等级 | P2 |
| 页面/entry | reader-base（阅读页基础控制层） |
| 问题描述 | 跨平台基线要求阅读页四角信息为「左上书名、右上电量、左下章节、右下时间」。当前 ReaderBasePrototype 的 top bar 将书名居中显示，meta row 显示章节名和书源 chip，但缺少独立的四角 overlay（尤其是电量指示和时间显示）。 |
| 期望表现 | ZStack 四角各有独立 Text：topLeading 书名、topTrailing 电量图标+百分比、bottomLeading 章节名、bottomTrailing 时间 |
| 修复建议 | 在 ReaderBasePrototype 的 ZStack 中添加四个 `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .xxx)` overlay，使用 ReaderTypography.controlLabel + ReaderColors.controlInk |
| 是否需要修改 Swift | 是（iOS/Modules/Prototype/PrototypeGalleryView.swift） |
| 是否需要重新跑 boundary | 否（仅 UI 层修改） |
| 是否需要人工复核 | 是 |

### P2-002：自动翻页快捷按钮图标语义

| 字段 | 值 |
|---|---|
| Issue ID | IOS-PROTO-P2-002 |
| 风险等级 | P2 |
| 页面/entry | reader-base（阅读页基础控制层） |
| 问题描述 | QuickButton 中自动翻页使用了 `"play.fill"` 图标，而非自动翻页专用语义图标。跨平台规范要求使用明确的「自动翻页」语义图标，Android 端使用 `AutoMode`。 |
| 期望表现 | 使用 `"arrow.triangle.2.circlepath"` 或 `"clock.arrow.circlepath"` 等自动/循环语义图标 |
| 修复建议 | 将 `QuickButton(icon: "play.fill", label: "自动翻页", ...)` 改为 `QuickButton(icon: "arrow.triangle.2.circlepath", label: "自动翻页", ...)` |
| 是否需要修改 Swift | 是（iOS/Modules/Prototype/PrototypeGalleryView.swift line 605） |
| 是否需要重新跑 boundary | 否 |
| 是否需要人工复核 | 是 |

---

## 非修复项（无需代码修改）

以下为审计确认无需修复的项：

1. **macOS API 错误**：预存问题，非 Prototype Gallery 引入，不影响 iOS target
2. **38 entry 数量**：已确认 >= 38，无需新增
3. **主底栏**：已确认正确（书架/发现/书源/我的），无需修改
4. **Reader 10 条规则**：全部通过，无需修改
5. **Boundary**：PASS，无需修改

---

## 修复后验证

修复完成后需执行：

```bash
bash scripts/check_ios_boundary.sh
cd iOS && swift build --target ReaderApp
```

注意：ReaderApp build 的 macOS API 错误是预存问题，不阻塞 Prototype Gallery。
