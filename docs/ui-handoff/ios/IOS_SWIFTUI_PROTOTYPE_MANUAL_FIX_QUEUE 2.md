# iOS SwiftUI Prototype Manual Fix Queue

| Issue ID | 风险等级 | 截图编号 | 页面/entry | 问题描述 | 期望表现 | 修复建议 | 是否需要修改 Swift | 是否需要人工复核 | 是否阻塞进入下一阶段 |
|---|---|---|---|---|---|---|---|---|---|
| MANUAL-P0-001 | P0 | 001-038 | `[DEBUG] Prototype Gallery` / all entries | App 可运行，但 GUI 中未暴露 Prototype Gallery 入口；当前仅能看到 Home / Bookshelf / Search / Settings 与 WebView Harness | Debug build 中应存在可点击的 `[DEBUG] Prototype Gallery` 入口，进入后可访问 38 个 prototype entry | 在 DEBUG-only 范围内添加最小入口，例如 toolbar/debug menu `NavigationLink(destination: PrototypeGalleryView())`；不得替换生产 App 主入口，不得改变主底栏生产接线 | 是 | 是 | 是 |

## 摘要

| 风险等级 | 数量 |
|---|---:|
| P0 | 1 |
| P1 | 0 |
| P2 | 0 |
| P3 | 0 |

clean-room 结论：本轮仅依据本仓现有 SwiftUI 结构、Xcode/Simulator 运行结果与项目文档记录阻塞；无外部 GPL 代码搬运。
