# Frontend Development Readiness

Status: `UI_HANDOFF_READY_FOR_BOUNDED_PLATFORM_SLICE`

Date: 2026-07-01

Canonical demo: `/Users/minliny/Documents/Reader UI/frontend-demo`

## 1. Conclusion

当前 `Reader UI` 仓库已经完成真实前端开发启动前，UI 侧必须交付的第一版输入：

- Design / Contract ready: 已具备 App Shell、主 Tab、route/state/component 基线、Motion ID、token、state machine、reduced-motion、interrupt 和 orientation/fold 契约。
- Demo proof ready: canonical `frontend-demo/` 已有 131 条 route render 覆盖、motion coverage gate、第一批代表截图证据和可执行 `ReaderMotionController.CONTRACT`。
- Platform implementation missing: Android Compose、iOS SwiftUI、HarmonyOS ArkUI 的真实工程、原生导航、手势、安全区、键盘、fold posture、无障碍和性能证据不属于本仓库，必须在平台仓库完成。

因此可以启动有边界的原生平台开发；不可以把 `frontend-demo/` 当作生产前端直接开发，也不可以把 demo coverage 通过等同于平台完成。

## 2. UI-Side Completed Inputs

| 输入 | UI 侧交付物 | 当前状态 | 平台消费方式 |
|---|---|---|---|
| Canonical source | `frontend-demo/README.md` | Complete | 只以 `frontend-demo/` 为设计和交互基准，不使用 draft 目录 |
| App shell baseline | `docs/cross-platform-ui/CROSS_PLATFORM_UI_BASELINE.md` | Complete | 固定书架 / 发现 / RSS / 设置四主 Tab；阅读页不是主 Tab |
| Route baseline | `frontend-demo/route-contract.js`、`docs/cross-platform-ui/CROSS_PLATFORM_ROUTE_MATRIX.md`、`docs/ui-handoff/ROUTE_MAP.md` | Complete | 平台转成原生 route/back stack；不要复制 fixture route stack |
| State baseline | `docs/cross-platform-ui/CROSS_PLATFORM_STATE_MATRIX.md`、`docs/ui-handoff/STATE_MATRIX.md` | Complete | 平台用真实 reducer/data lifecycle 落地 loading/empty/error/session 等状态 |
| Screen inventory | `docs/ui-handoff/SCREEN_MATRIX.md` | Complete | 平台按业务优先级挑选 screen，不一次性全量搬运 |
| Motion contract | `frontend-demo/MOTION_CONTRACT.md` | Complete | 平台继承 Motion ID、state fields、state machine、token 语义 |
| Motion effects | `frontend-demo/MOTION_EFFECTS.md` | Complete | 平台按效果语义重建原生动画，不逐帧复制 Web CSS |
| Motion platform mapping | `docs/ui-handoff/MOTION_PLATFORM_MAPPING.md` | Complete | 平台拆 native work item 和证据项 |
| Gap audit | `frontend-demo/MOTION_IMPLEMENTATION_GAP_AUDIT.md` | Complete | 用于区分 demo proof 缺口和平台实现缺口 |
| Demo coverage | `frontend-demo/verify/motion/motion-coverage-report.json` | Complete | 证明 canonical demo contract 未断裂 |
| Demo evidence | `frontend-demo/verify/motion/evidence/manifest.json` | Complete for first representative P0 proof | 只证明 demo 代表状态；不替代平台录屏 |
| Startup slices | `docs/ui-handoff/FRONTEND_DEVELOPMENT_SLICE_MATRIX.md` | Complete | 平台按 bounded vertical slice 开工 |
| Platform evidence request | `docs/ui-handoff/UI_PLATFORM_EVIDENCE_REQUESTS.md` | Complete | 平台仓库按清单补真机/模拟器/测试证据 |

## 3. UI-Side Non-Goals

这些不在 `Reader UI` 仓库内完成：

- 生产前端工程入口、构建脚本、依赖锁文件和 CI。
- Android Compose、iOS SwiftUI、HarmonyOS ArkUI 的真实组件实现。
- 平台原生 navigation/back stack、system back、keyboard inset、safe area、fold posture、gesture velocity/cancel。
- 真实业务数据、网络请求、数据库、后台恢复、锁屏、生命周期。
- TalkBack、VoiceOver、ArkUI accessibility focus、性能、低端设备帧率和平台真机录屏。

`Reader UI` 对这些内容只提供设计契约、验收条件和证据请求。

## 4. Startup Gate

前端平台仓库开始第一个 vertical slice 前，必须满足：

| Gate | UI 侧状态 | 平台侧动作 |
|---|---|---|
| G1: 入口确认 | 当前仓库确认不是生产前端工程 | 在目标平台 App 仓库或新平台工程开工 |
| G2: Shell 契约 | 四主 Tab 和 ReaderShell/LibraryShell/SettingsShell/FlowShell 已定义 | 建立原生 AppShell、route host、back stack |
| G3: Motion 语义 | Motion ID/token/state machine 已定义且 coverage 通过 | 建立平台 token adapter 和 motion reducer |
| G4: 状态矩阵 | loading/empty/error/offline/session 等状态已定义 | 建立真实 data/reducer lifecycle |
| G5: 证据分层 | demo proof 与 platform evidence 已分离 | 平台提交真机/模拟器/测试证据 |

## 5. Handoff Rules

- 平台可以继承：Motion ID、state fields、token 语义、互斥规则、打断规则、reduced-motion 规则、最终状态约束、验收路径。
- 平台不能继承：Web CSS、DOM、`data-*` selector、query 参数、截图文件名、fixture route stack、浏览器 viewport 行为。
- 任何新增 UI route、state、Motion ID 或高风险交互，都必须同步更新 `frontend-demo/route-contract.js`、motion contract/effects/mapping、slice matrix 或 evidence request。
- 任何平台声称完成，必须回填平台仓库证据；`Reader UI` 只接受证据链接或报告，不替平台测试。

## 6. Current Start Recommendation

现在推荐只启动：

1. AppShell + 主 Tab。
2. 书架到沉浸阅读首条 vertical slice。
3. Reader 控制层最小打开/隐藏。
4. Motion token adapter + reduced-motion + interrupt reducer 的最小平台骨架。

现在不推荐启动：

1. 131 routes 全量迁移。
2. 三端并行全量重写。
3. 按 Web CSS/DOM 复刻。
4. 折叠屏、大屏、无障碍和性能的一次性全量攻坚。
5. 把所有 Motion ID 一次性实现完。
