# Complete App Closure Work Breakdown

状态：P0 Reader UI gates split and filled
日期：2026-07-04

本文把“完整可用前端应用”剩余工作拆到对应仓库。Reader UI 负责契约和可验证参考，不负责三端生产 UI、Core 真实协议实现或设备证据。

## 1. 当前 Reader UI 已补齐

Reader UI 本仓当前已闭合：

- P0 页面参考：[PAGE_REFERENCE.md](./PAGE_REFERENCE.md)
- 完整矩阵：[ROUTE_COMPONENT_MATRIX.md](./ROUTE_COMPONENT_MATRIX.md)
- 动效规范：[MOTION_SPEC.md](./MOTION_SPEC.md)
- token 规范：[TOKEN_SPEC.md](./TOKEN_SPEC.md)
- Core/Host 边界：[CORE_HOST_BOUNDARY.md](./CORE_HOST_BOUNDARY.md)
- 三端切片：[SLICE_PLAN.md](./SLICE_PLAN.md)
- evidence 规格：[PLATFORM_EVIDENCE_SPEC.md](./PLATFORM_EVIDENCE_SPEC.md)
- 本仓防漂移门禁：
  - `matrix-coverage.test.mjs`
  - `motion-guard.test.mjs`
  - `token-group.test.mjs`
  - `core-host-boundary.test.mjs`

当前验证入口：

```bash
node --test contracts/tests/*.test.mjs
```

当前结果：`162/162 pass`。

## 2. Reader UI 剩余任务

| ID | 任务 | 当前状态 | 完成标准 |
| --- | --- | --- | --- |
| RUI-01 | demo/schema unknown 收敛 | strict/exception 起点已建立：`found=433 unknown=111 approved=111 unapproved=0`；route/token unknown 为 0，motion unknown 必须列入 `demo-contract-exceptions.json` | strict gate 或 explicit alias/deprecated exception list；route/token unknown 必须为 0，motion unknown 必须为 0 或列入例外 |
| RUI-02 | MotionId 归一化 | 已建立首批 alias 表：`reader.session.capsule.control.press/toggle` -> `reader.session.capsule.control.press-toggle`、`reader.page.turn.next/prev` -> `reader.page.turn.next-prev`、`tab.item.switch` -> `tab.switch`；demo 中仍有历史/内部 motion id 例外 | schema、demo runtime、fixtures、generated 使用同一 canonical MotionId；旧 id 只通过 deprecated alias 表存在 |
| RUI-03 | 全量 MotionSpec registry | P0 40/40 已有 fixture；总量 56/84 | 84/84 非 deprecated MotionId 都有 fixture、token refs、guardRules；三端生成 MotionSpecRegistry |
| RUI-04 | TokenRegistry value codegen | token fixtures 有 value；generated 目前主要是类型 | 生成 Swift/Kotlin/ArkTS token value registry；三端 TokenAdapter 可直接消费或映射 |
| RUI-05 | handoff readiness 8/8 | 旧检查曾因 contract-only `Package.swift` 失败 | verifier 明确允许 contract-only package 或文件移动；`verify-ui-handoff-readiness.mjs` 8/8 |

这些任务完成后，Reader UI 才能从“P0 可控开发参考”升级到“强门禁 contract release source”。

## 3. Reader-Core-Native 任务

| ID | 任务 | 输入 | 完成标准 |
| --- | --- | --- | --- |
| CORE-01 | P0 CoreCommand mapping | [CORE_HOST_BOUNDARY.md](./CORE_HOST_BOUNDARY.md), `core-command.schema.json` | `book.open` / `chapter.list` / `content.load` / `reader.location.resolve` / `reader.progress.update` 映射真实 Rust protocol |
| CORE-02 | DomainState 事实源证明 | [STATE_OWNERSHIP.md](./STATE_OWNERSHIP.md), Core bridge matrix | bookshelf、RSS、search history、content、progress、TTS queue、sync conflict 不由平台持久化 |
| CORE-03 | CoreEvent/error/stale 结果 | `core-event.schema.json`, `sync-conflict.schema.json` | success / failed / cancelled / stale result 都有协议测试 |
| CORE-04 | HostRequest host bus 对齐 | `host-request.schema.json` | HTTP、Cookie、file、credential、system TTS、storage path 等 HostRequest 有真实边界和测试 |

Core 任务完成前，三端可以做 Slice 0/1 骨架，但不能声称真实业务链路完成。

## 4. 三端平台任务

三端统一按 [SLICE_PLAN.md](./SLICE_PLAN.md) 推进。

| Slice | Android | iOS | HarmonyOS | 依赖 |
| --- | --- | --- | --- | --- |
| Slice 0 | generated Kotlin 接入、Reducer/ViewModel/CoreBridge/HostAdapter 骨架 | generated Swift 接入、Reducer/Coordinator/CoreBridge/HostAdapter 骨架 | generated ArkTS 接入、Store/Reducer/NAPI bridge/HostAdapter 骨架 | Reader UI generated |
| Slice 1 | Compose AppShell + 4 tabs + reducer golden | SwiftUI AppShell + 4 tabs + reducer golden | ArkUI AppShell + 4 tabs + reducer golden | Slice 0 |
| Slice 2 | bookshelf -> reader surface + Core bridge smoke | 同左 | 同左 | Core `book.open/content.load/progress` mapping |
| Slice 3 | reader control layer + overlay/focus tests | 同左 | 同左 | Slice 2 |
| Slice 4 | TTS/auto-page session capsule | 同左 | 同左 | Core TTS queue + Host TTS |
| Slice 5 | RSS/source/search | 同左 | 同左 | Core RSS/source/search |
| Slice 6 | sync/conflict/offline | 同左 | 同左 | Core sync/conflict |
| Slice 7 | Host Adapter capability completion | 同左 | 同左 | HostRequest matrix |
| Slice 8 | device smoke + accessibility + performance | 同左 | HarmonyOS 真机优先 | Slice 1-7 |

每端完成一个 slice 必须提交：

- 本仓源码路径
- 测试命令和输出
- reducer golden test
- TokenAdapter / MotionAdapter 覆盖证据
- 截图或录屏
- device/simulator evidence manifest

## 5. 执行顺序

1. Reader UI 保持 P0 gates 绿：`node --test contracts/tests/*.test.mjs`。
2. 三端同时做 Slice 0，仅允许接入 generated 和建立骨架。
3. Core 做 CORE-01 到 CORE-03，给 Slice 2 提供真实业务链路。
4. 三端进入 Slice 1；Slice 1 不依赖真实 Core 数据，可用 contract fixtures 证明 AppShell/reducer。
5. Core P0 bridge 可用后，三端进入 Slice 2。
6. Slice 3-6 只按 Core/Host 能力成熟度推进，不能用平台本地假仓库替代 DomainState。
7. Slice 8 前必须完成三端 raw token 检查、TokenAdapter coverage、MotionAdapter coverage、reducer golden test、device smoke。

## 6. 禁止事项

- 不允许把 `frontend-demo/` 放进 WebView 当生产 UI。
- 不允许三端直接写 bookshelf / RSS / search history / progress / sync conflict 持久化。
- 不允许绕过 generated types 手写 RouteId / MotionId / Token enum。
- 不允许用截图相似度替代 reducer / Core / Host evidence。
- 不允许单端无限向前做长尾页面，必须按 slice 对齐。
