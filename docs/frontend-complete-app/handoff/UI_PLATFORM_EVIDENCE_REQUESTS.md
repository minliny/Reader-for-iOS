# UI Platform Evidence Requests

Status: `UI_EVIDENCE_REQUEST_READY`

Date: 2026-07-01

Scope: 本文件由 `Reader UI` 提供给 Android / iOS / HarmonyOS 平台仓库。它定义平台实现完成后必须回传的证据类型；不要求这些证据存放在 `Reader UI` 仓库。

## Evidence Tiers

| 层级 | 责任方 | 证据 | 当前状态 |
|---|---|---|---|
| Contract evidence | Reader UI | Motion ID、token、state fields、state machine、reduced-motion、interrupt、验收路径 | Ready |
| Demo proof evidence | Reader UI | canonical `frontend-demo/` coverage、代表截图、selector/motion 映射 | First P0 representative proof ready |
| Platform implementation evidence | 平台仓库 | 原生组件、导航、手势、真机/模拟器、无障碍、性能、生命周期证据 | Missing outside Reader UI |

## Required Platform Evidence

| 领域 | 平台必须提供 | 接受标准 |
|---|---|---|
| Build and smoke | 构建日志、启动 smoke、目标平台版本 | App 可安装/启动，入口不是 WebView 加载 `frontend-demo/` |
| Native shell | AppShell / MainTab 原生截图或 golden | 书架 / 发现 / RSS / 设置四主 Tab；搜索和阅读不在主 Tab |
| Native navigation | route push/pop/replace 测试或录屏 | back stack 与 UI contract 对齐；Tab switch 不写成二级 push |
| State reducer | loading/empty/error/offline/session reducer 测试 | 真实数据生命周期下最终状态唯一 |
| Motion token adapter | token 单测或 snapshot | Motion token 名称和 reduced-motion 规则可追溯到 UI contract |
| Interrupt reducer | 连续点击、返回、loading 完成、overlay 关闭测试 | latest intent wins；旧异步结果不能覆盖新 route |
| Keyboard and safe area | 原生键盘、安全区、系统手势区截图/录屏 | 输入、底表、Reader 控制层不被错误遮挡 |
| Reader control gesture | 小横条、宽屏 dock、拖动释放录屏 | 跟手、阈值、bounds clamp、release finalState 明确 |
| Session capsule | 自动翻页/TTS 运行会话录屏 | 只显示一个 active session；暂停/继续不打开控制层 |
| Orientation/resize | portrait/landscape/tablet resize 录屏 | route/back stack/ReaderContext/session/overlay/focus 保留 |
| Fold posture | fold open/half/collapse 或模拟器证据 | 不跨 hinge；pane/safe area 合法；正文按锚点重分页 |
| Accessibility | TalkBack / VoiceOver / ArkUI focus 记录 | overlay focus trap、关闭恢复、hidden state 不被读出 |
| Performance | 低端设备帧率、trace 或 profiler 摘要 | 动效不触发明显 jank；使用 transform/opacity 或平台等价高性能属性 |

## Slice Evidence Requests

| Slice | 最小平台证据 |
|---|---|
| AppShell + Main Tabs | 主 Tab 切换录屏、back stack 测试、reduced-motion 截图 |
| Bookshelf to Immersive Reading | 封面/按钮进入沉浸阅读录屏、返回来源页测试、连续点击处理 |
| Reader Control Layer | 控制层打开/隐藏录屏、正文不重排检查、模块切换几何稳定证据 |
| Overlay and Focus | 键盘、底表、弹窗、返回关闭、焦点恢复测试 |
| Session Capsule | 启动、暂停/继续、退出、互斥切换、后台恢复最小证据 |
| Orientation and Fold | orientation prepare/reshape/settle、dock clamp、fold pane/hinge 证据 |

## Rejection Rules

平台证据出现以下情况时，`Reader UI` 不应接受为完成：

- 使用 WebView 运行 `frontend-demo/` 作为正式 UI。
- 复制 Web CSS、DOM、`data-*` selector 或 query 参数作为平台 API。
- 只提交浏览器截图，缺少原生平台截图/录屏/测试。
- 声称折叠屏、大屏、无障碍或性能完成，但没有对应设备或工具证据。
- route/back stack、ReaderContext、activeSession、overlay/focus 的最终状态无法解释。
- reduced-motion 只关闭部分动画，仍保留大位移、循环 pulse 或 spinner。
