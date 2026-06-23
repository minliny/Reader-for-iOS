# iOS SwiftUI Prototype Manual Fix Queue

| Issue ID | 风险等级 | 截图编号 | 页面/entry | 问题描述 | 期望表现 | 修复建议 | 是否需要修改 Swift | 是否需要人工复核 | 是否阻塞进入下一阶段 |
|---|---|---|---|---|---|---|---|---|---|
| MANUAL-P0-001 | P0 | 001-038 | `[DEBUG] Prototype Gallery` / all entries | App 可运行，但 GUI 中未暴露 Prototype Gallery 入口 | Debug build 中应存在可点击的 `[DEBUG] Prototype Gallery` 入口 | RESOLVED：已在 `iOS/App/ReaderApp.swift` 的 Home Tab toolbar 中添加 `#if DEBUG` NavigationLink → `PrototypeGalleryView`，并接入 `Route.prototypeGallery` | 是 | 是 | 否 |
| MANUAL-P0-002 | P0 | 001-038 | fresh Debug build / all entries | 含 Debug entry 的 fresh App 无法构建安装；`ReaderShellValidation` target 在 `iOS/CoreBridge/RuntimeContractMapping.swift` 编译失败 | `ReaderForIOSApp` Debug build 应能通过 | RESOLVED：修复 `ProductionWebViewAdapter.swift`（securityGate internal 化、currentPolicy→webViewPolicy 避免类型冲突）、`RuntimeContractMapping.swift`（删 extra timestamp arg、GateEvaluation 非私有、@preconcurrency conformance、新增 currentPolicy: RuntimePolicy）、`WebViewAdapterSmokeTests.swift`（适配重命名）；xcodebuild BUILD SUCCEEDED | 是 | 是 | 否 |

## 摘要

| 风险等级 | 数量 |
|---|---:|
| P0 | 0 |
| P1 | 0 |
| P2 | 0 |
| P3 | 0 |

clean-room 结论：本轮仅依据本仓现有 SwiftUI 结构、Xcode/Simulator 运行结果与项目文档记录阻塞；无外部 GPL 代码搬运。
