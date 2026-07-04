# 动效实现缺口审计

状态：Draft v0.1

范围：基于当前 `frontend-demo/` 和三份动效规划文档，审计从“完整规划初稿”到“可交给各平台排期实现”的剩余缺口。

结论：当前已有方向、Motion ID、效果描述、平台映射、第一版可执行 registry 和关键 Motion ID 的 contract 层状态机，但仍缺组件级实现状态机、录屏证据、平台测试映射和设备验证。以下缺口全部需要补齐。

收束原则：

- `frontend-demo/` 的下一步只补 Contract proof 和高风险链路证据，不继续扩展成三端最终实现。
- Web CSS、DOM、`data-*` selector、query 参数和 fixture route stack 只服务 demo 取证；平台只能继承 Motion ID、state fields、token 语义、打断规则、reduced-motion 和验收结果。
- 平台最终实现必须在 Android Compose / iOS SwiftUI / HarmonyOS ArkUI 内用原生组件、导航、手势、safe area、keyboard inset、fold posture、accessibility focus 和性能工具自证。

## UI / Platform Ownership Split

当前 UI 侧已补齐真实前端开发启动前的 handoff 包：

- `../docs/ui-handoff/FRONTEND_DEVELOPMENT_READINESS.md`：UI 侧 start gate、Design / Contract ready、Demo proof ready、Platform implementation missing 的分层结论。
- `../docs/ui-handoff/FRONTEND_DEVELOPMENT_SLICE_MATRIX.md`：建议平台先做的 bounded vertical slices。
- `../docs/ui-handoff/UI_PLATFORM_EVIDENCE_REQUESTS.md`：平台完成后必须回传的 native build、navigation、gesture、fold、accessibility 和 performance 证据。
- `verify/handoff/verify-ui-handoff-readiness.mjs`：检查 UI handoff 文件、131 route contract、motion coverage、代表证据和项目角色边界。

这些文件把 UI 侧缺口收束为“开发输入和验收基准已可用”。它们不声称平台实现完成；真实 Compose / SwiftUI / ArkUI 组件、原生导航、设备录屏、无障碍和性能仍由各平台仓库完成。

## P0：阻塞实装的缺口

| 缺口 | 当前状态 | 需要补充 | 验收标准 |
|---|---|---|---|
| Motion token 落地 | 已新增 `frontend-demo/motion-tokens.css`，并把 `frontend-demo/styles/` 中裸写的 `160ms`、`220ms`、`0.8s` 替换为 token；通用控件也已接入基础 motion token | 继续做视觉回归，确认 token 替换没有改变既有布局和关键节奏 | `rg "160ms|220ms|0.8s" frontend-demo/styles` 不命中；关键路径截图/录屏无非预期变化 |
| Reduced motion 实装 | 已新增 `@media (prefers-reduced-motion: reduce)`、`data-motion-reduced` 和 `?motionReduced=1/0` 测试开关；翻页、loading、通用控件 transition 已降级 | 补 reduced-motion capture，覆盖键盘、底表、弹窗、封面进入、控制层、翻页、loading、折叠重排 | 系统 reduced motion 或 `?motionReduced=1` 下移除位移/循环动画，状态反馈仍可辨认 |
| 可执行 Motion Contract Registry | `motion-controller.js` 已暴露 `ReaderMotionController.CONTRACT`，可把当前 renderer 的 Motion ID 解析到 family、token、state fields、state machine、平台组件和证据规则；`verify-motion-coverage.mjs` 已校验 registry 解析、状态机字段和 47 个关键 Motion ID 的精确状态机 | 继续把 exact state machine 扩展到全部 P0/P1 Motion ID，并绑定实际组件状态机 | 当前绑定和 runtime 必需 Motion ID 全部能解析并具备状态机；平台不能照抄 CSS，只能按 registry 的 Motion ID、state fields、state machine、token 和证据要求映射原生实现 |
| TAB / segmented 状态动效 | 已补 `tab.item.press/select/switch` 和 `segment.item.switch` contract 状态机；主 TAB、阅读模块 TAB 和 segmented control 已接入 `data-motion-tab-*` / `data-motion-segment-*` 状态、`data-motion-press-id`、token 化 pressed/select/switch CSS 和 `reader.module.switch` / `segment.item.switch` 事务 | 补主 TAB / 阅读模块 TAB / segmented control 的录屏证据，并继续确认 indicator/active 层不推动布局 | 按下、单按钮选中、A -> B 切换、重复点击 active 行为可区分；栏尺寸稳定 |
| 下拉栏统一动效 | 已补 `dropdown.*` contract 状态机；demo 已接入 `attachDropdownMotionState`，阅读设置、朗读设置、设置页选项、发现排序、筛选菜单、书源更多、书架更多和书籍焦点菜单会写入 `data-motion-dropdown-*` 状态、`dropdown.option.press` press-id；连续打开 A 后切 B 会写入 `data-motion-dropdown-switch-*` 并触发 `motion.interrupt.redirect`；menu/option/trigger/switch target 已 token 化 CSS | 继续补关闭保留动画、打开 A 后切 B 的录屏证据、resize/orientation 触发的 `dropdown.menu.reposition` 证据 | 所有下拉展开/收起/点击节奏一致；同层只留一个 open；选择后值/semantics 同步；resize/orientation 可重定位 |
| 通用交互组件族纳管 | 已新增 `MOTION_SELECTOR_MATRIX.md`，148 个唯一 `data-*` 入口均已映射到 Motion ID / route / platform component；demo 已通过 `data-motion-id`、`data-motion-component-*`、`is-motion-pressed` 和 token CSS 接入 button、toggle、choice、numeric、input、state、selection、surface 的 normalized 状态字段；当前 coverage 使用的 Motion ID 都有 contract 状态机 | 继续补每个组件族的录屏/截图证据、平台测试文件名和 async pending / focus restore 等深状态 | 所有控件族都有 token、效果、平台映射、reduced-motion、实现代码和验证路径；证据文件可追溯到 Motion ID |
| 首次打开应用动效 | 已补 `app.launch.firstOpen` 规划和第一版实现层 adapter；demo 会在 cold start 初始化 `firstOpenMotion`，在 root / screen host 写入 `data-motion-first-open-*`，用 `--fd-motion-effective-first-open` 播放一次性首屏淡入并自动 settle；reduced-motion 即时落位 | 补冷启动默认页/深链页录屏、后台恢复设备证据和平台测试映射 | 冷启动默认页/深链页只播放一次，返回和切 Tab 不重播 |
| 封面进入沉浸阅读 | 已补 `reader.entry.coverToImmersive` / `reader.entry.actionToImmersive` 实现层 adapter；书架封面、继续阅读封面和普通阅读按钮会写入 `data-motion-entry-*` 状态，封面入口有 snapshot 层，目标阅读面有 token 化淡入和 reduced-motion 降级 | 补封面入口、无封面按钮入口、返回来源页、连续点击和录屏/截图证据，并继续覆盖详情页/章节行入口 | 点击书架封面/继续阅读封面进入 `immersive-reading`；不显示控制层；返回来源页 |
| 控制层小横条拖拽 | 已补 `reader.control.handle.press/drag/release` 精确状态机和实现层 adapter；`.fd-reader-grabber` / `.fd-reader-full-grabber` 会写入 `data-motion-control-handle-*` 状态，拖动使用临时 offset，释放按阈值展开/收回，reduced-motion 即时提交；full 页小横条已可收回到对应控制层 | 补录屏/截图证据，并继续验证真实触摸设备上的长路径 drag、方向阈值和目录 full 页上拉 promote | 拖动中正文不动；释放只落到展开、收回或原状态之一；返回栈不乱 |
| 宽屏控制层 dock 长按移动 | 已补 `reader.control.dock.longPress/drag/release/rebound` 精确状态机和第一版实现层 adapter；宽屏 `.fd-reader-grabber` 长按后移动同一组 fixed-width dock，按 ReaderFrame/dock group 计算 bounds，transform offset，按 viewport class 保存位置，并在 resize 后 clamp/rebound；窄屏会清理 dock transform | 补真实鼠标/触摸录屏、折叠屏 hinge/pane 安全区验证、旋转中打断证据和平台测试映射 | fixed-width dock 可移动但不变形；不跨 hinge/安全区；正文不重排；释放位置合法 |
| 自动翻页/朗读运行胶囊动效 | 已补 `reader.session.autoPage.start` / `reader.session.tts.start` 启动事务和 `reader.session.capsule.enter/update/switch/exit` 第一版实现层 adapter；沉浸页胶囊会写入 `data-motion-session-capsule-*` 状态，自动翻页倒计时会局部更新并保留固定宽度，TTS/自动翻页互斥 | 补录屏证据、停止/退出路径、后台/切章打断验证和平台测试映射 | 从控制层或完整页开启自动翻页/朗读后回到 `immersive-reading`；只显示一个胶囊；互斥切换不排队 |
| 控制层上方胶囊锚点动效 | 已补 `reader.session.controlSpace.*` 第一版实现层 adapter；控制层会把同一颗运行胶囊重锚定到顶部，并写入 `data-motion-control-space-*`、countdown/voice/control/label 子角色和 token 化 enter/update/tick/voice/control CSS | 补 matched geometry / snapshot 录屏证据、停止/退出打断验证和平台测试映射 | 打开控制层时胶囊停靠到控制层上方；切换控制层子页仍可见；隐藏控制层时回到沉浸页脚胶囊；结束态没有双主控 |
| 控制胶囊内部微动效 | 已补 `.fd-ir-status-controls button` / `data-reader-capsule-control` 局部按压、play/pause 状态、`data-reader-capsule-countdown` 数字 tick、`data-reader-capsule-voice` 播放态 pulse 和 reduced-motion 静态降级 | 补录屏证据、真实触摸按压和停止/切换时的退出验证 | 按钮切换不打开控制层；数字变化不重放整颗胶囊；朗读图标播放时轻提示、暂停静态 |
| 整屏旋转适配与动效 | 已补 `viewport.orientation.prepare/reshape/settle` 第一版实现层 adapter；resize / `visualViewport.resize` 发生方向或 viewport class 变化时，root / screen host 会写入 `data-motion-orientation-*`，记录 route、session、overlay、focus、dock sync、from/to viewport 和 reanchor 状态，并用 token 化 anchor settle 动效；宽屏 dock 会复用 resize clamp/rebound | 补真实旋转录屏、折叠屏 hinge/pane 验证、正文字符锚点重分页证据、overlay/focus 恢复自动化和平台测试映射 | portrait <-> landscape、compact-landscape、tablet-expanded resize 下，route/返回栈/active session 不丢；正文不跳章；控制层/胶囊/overlay/dock 都落到合法位置 |
| 打断动画状态机 | 已补 `motion.interrupt.cancel/redirect/completeThenReplace` 第一版实现层 adapter；route push/replace/back、Tab 切换、viewport 变化、loading 完成、宽屏 dock 拖动开始、pointer cancel、连续下拉 A->B 和 reader loading 异步结果会写入 root / screen host 或 dropdown switch / async result 状态，清理 pressed、tab/segment/dropdown pressed、handle dragging 和 dock dragging 临时状态，并接入 token 化 `interruptSettle` / dropdown switch / async completion CSS | 补 overlay 关闭、焦点恢复自动化、真实交互录屏和平台测试映射 | 连续点击、返回、关闭、loading 完成、拖动开始后最终状态唯一；旧异步结果不能覆盖新 route |
| Motion capture 证据 | 已建立 `frontend-demo/verify/motion/` 和 `selector-matrix/` 证据目录说明，并补第一批代表性浏览器截图：首启、Tab、下拉、封面进入、自动翻页胶囊、控制层上方胶囊锚点、orientation 和 interrupt 已写入 `evidence/manifest.json` 且进入 coverage gate | 只为高风险 Motion ID 继续补代表录屏/GIF/关键帧截图，并回填到 `MOTION_SELECTOR_MATRIX.md` 的 Evidence 列；低风险通用控件以 selector matrix + coverage + 少量代表证据为准 | P0 高风险 Motion ID 至少一份 demo proof；证据命名可追溯；明确该证据不等于平台真机录屏 |
| 折叠屏/大屏验证 | 当前只有 viewport class 规划和部分 adaptive PNG | 增加 fold/open/collapse/compact-landscape 的手动或模拟器验证矩阵 | ReaderContext、overlay、返回栈、正文分页映射均有证据 |
| 平台实现映射到组件 | 平台映射已补通用组件族和 Reader 主链路的组件级方向，并新增 Contract / Demo proof / Platform implementation 分层 | 继续为高风险 Motion ID 标明平台组件、state 字段、测试文件/验收方式和真机证据类型 | Compose/SwiftUI/ArkUI 可按 native work item 拆任务；不引用 Web CSS/DOM 作为实现依据 |

## P1：影响一致性的缺口

| 缺口 | 当前状态 | 需要补充 | 验收标准 |
|---|---|---|---|
| Motion ID 状态机表 | 已在 `ReaderMotionController.CONTRACT` 中建立 family fallback，并为 47 个关键 Motion ID 补 `from/to/interrupt/finalState/reducedMotion` 精确状态机 | 扩展到剩余 P0/P1 Motion ID，并把状态机与真实组件 reducer / platform test 文件绑定 | 状态机表能解释所有打断和降级，coverage 能失败提示缺失项 |
| 手势阈值 | 亮度/进度拖动有原则，无阈值 | 定义 drag slop、velocity、取消阈值、底表拖拽边界 | 手势跟手，无 easing 滞后；误触边界明确 |
| 性能预算 | 未定义 | 补 FPS、layout shift、动画属性白名单、低端设备降级 | 动画只用 transform/opacity 等优先属性；有性能验收项 |
| 无障碍/semantics | 只有 reduced motion | 补 VoiceOver/TalkBack 焦点迁移、弹窗焦点陷阱、aria/semantics 更新时机 | 动画期间不会读出隐藏 overlay；返回焦点正确 |
| Reader 互斥状态 | 已有原则，未成表 | 补 TTS、自动翻页、章节跳转、进度拖动、翻页动画互斥矩阵 | 同时触发时结果确定，不出现双状态 |
| 运行会话退出策略 | 当前只定义启动和静态胶囊，缺少生命周期表 | 补停止、暂停、返回、退出阅读、章节跳转、后台切换时的 session/capsule 结果 | 胶囊隐藏、保留或暂停的规则明确；不会拦截沉浸阅读热区 |
| 封面进入的跨场景覆盖 | 只补了书架/继续阅读/普通入口 | 细化搜索结果、详情页封面、章节行、发现页封面是否走同一 Motion ID | 每个入口都有明确动效或降级策略 |

## P2：交付治理缺口

| 缺口 | 当前状态 | 需要补充 | 验收标准 |
|---|---|---|---|
| Haptic/音效策略 | 未定义 | 决定是否需要 haptic，哪些动作触发，reduced motion 下是否保留 | 平台一致，不默认增加噪声反馈 |
| 设计验收总表 | 分散在三份文档 | 建立 Motion ID -> demo route -> 证据 -> 平台组件 -> 测试方式总表 | 评审时能逐项勾选 |
| 版本治理 | 未定义 | 规定 token/Motion ID 变更流程和平台兼容策略 | Motion 变更不会让平台实现失配 |
| 文档与 demo 同步规则 | 未定义 | 每次修改 demo 动效必须同步 contract/effects/mapping/gap audit | 文档不会变成过期规划 |

## P0 推荐落地顺序

1. 已完成第一版：`motion-tokens.css`、裸写时长替换、reduced-motion CSS/测试开关、148 个 `data-*` selector 总表、基础 `data-motion-id` / pressed state 接入、`ReaderMotionController.CONTRACT` 可执行 registry，以及 47 个关键 Motion ID 的精确 contract 状态机。
2. 已完成第一版：主 TAB、阅读模块 TAB 和 segmented control 已实现 `tab.item.press/select/switch` / `segment.item.switch` adapter、`reader.module.switch` / `segment.item.switch` 事务和 token 化状态；下一步补录屏证据与 indicator/active 层校验。
3. 已完成第一版：通用控件族已接入 `data-motion-component-*` normalized adapter，覆盖 button、toggle/switch、chip/filter/segment、slider/stepper/progress、input/search、feedback/state、selection、listRow/card 的 family / role / state / phase / value 字段；下一步补全族录屏、async pending、focus restore 和平台测试文件映射。
4. 已完成第一版：`dropdown.*` 已接入 trigger/menu/option 状态 adapter、press-id 和 token 化 CSS；连续打开 A 后切 B 已补 `data-motion-dropdown-switch-*` + `motion.interrupt.redirect` adapter；下一步补关闭保留动画、reposition 和录屏证据。
5. 已完成第一版：`app.launch.firstOpen` 已接入 cold-start 一次性状态、root/screen host `data-motion-first-open-*`、token 化首屏淡入和 reduced-motion 即时 settle；下一步补默认页/深链页录屏、后台恢复设备证据和平台测试映射。
6. 已完成第一版：`reader.entry.coverToImmersive` / `reader.entry.actionToImmersive` 已接入 source cover/action、snapshot、target reveal 和 reduced-motion 状态；下一步补录屏、连续点击、返回来源页和详情/章节入口证据。
7. 已完成第一版：`reader.control.handle.press/drag/release` 已接入小横条 press、drag preview、release snap/expand/collapse、full 页收回和 reduced-motion；下一步补真实触摸/鼠标录屏证据和目录 full 页上拉 promote 验证。
8. 已完成第一版：`reader.control.dock.*` 已接入宽屏 fixed-width dock 长按移动、bounds clamp、viewport class offset 保存、resize 越界回弹和窄屏 transform 清理；下一步补真实设备/折叠屏/旋转打断录屏证据。
9. 已完成第一版：`viewport.orientation.prepare/reshape/settle` 已接入 root / screen host `data-motion-orientation-*`、route/session/overlay/focus/dock 元数据、token 化 reshape/anchor settle、reduced-motion 即时 settle 和宽屏 dock clamp；下一步补真实旋转录屏、折叠屏 hinge/pane、正文字符锚点重分页和 overlay/focus 恢复证据。
10. 已完成第一版：`reader.session.autoPage.start`、`reader.session.tts.start` 和 `reader.session.capsule.*` 已接入回沉浸阅读、唯一运行胶囊、内部更新、互斥切换、退出状态和 token 化 CSS；下一步补录屏、停止/退出打断和平台测试。
11. 已完成第一版：`reader.session.controlSpace.*` 已接入控制层上方胶囊锚点、countdown/voice/control/label 子角色、局部 tick/update 和 reduced-motion token；下一步补 matched capsule-to-above-control-anchor 录屏、停止/退出打断和平台测试。
12. 已完成第一版：`reader.session.capsule.control.*`、`reader.session.capsule.countdownTick` 和 `reader.session.capsule.voiceIcon.active` 已接入局部按钮、倒计时数字和朗读图标状态；下一步补真实设备/录屏证据。
13. 已完成第一版：`motion.interrupt.*` 已接入统一 interrupt adapter、root/screen host `data-motion-interrupt-*`、临时 pressed/dragging/dropdown 清理、route/Tab/viewport/loading/dock drag/连续下拉 A->B 入口和 token 化短收尾；reader loading 结果已补 `data-motion-async-*` request-scoped 状态、取消/过期防覆盖和 completion CSS；下一步补 overlay 关闭、焦点恢复自动化和录屏证据。
14. 已完成第一版：`overlay.keyboard/sheet/dialog.*` 已接入 `data-motion-overlay-*` role/state/action/focus-return 字段，settings sheet/dialog 主体进入同一 `data-demo-sheet/dialog` 入口，键盘/底表/弹窗基础焦点恢复已通过浏览器验证；下一步补连续 overlay 打断、遮罩互斥、录屏和平台焦点测试。
15. 已建立 `frontend-demo/verify/motion/evidence/manifest.json` 并补第一批代表性浏览器截图；下一步录制 TAB press/select/switch、下拉栏展开/收起/点击、通用控件族、首启、封面进入、控制层显隐、小横条、宽屏 dock 拖动、整屏旋转、运行胶囊、控制层上方胶囊锚点、翻页、打断、折叠/resize 的完整视频或关键帧序列。
16. 把平台映射继续细化到 state 字段、测试文件和平台任务拆分。

收束后的优先级：先保留并补证据的 demo 高风险链路是 TAB/dropdown、封面进阅读、阅读控制层、自动翻页/朗读胶囊、控制层上方胶囊锚点、orientation/resize、interrupt、reduced-motion；平台侧优先拆 native work item，包括 token adapter、motion reducer、原生导航、原生 overlay、Reader 控制层手势、运行 session、orientation/fold、accessibility/performance。

## 当前不应声称完成的内容

- 不能声称 demo 已完成跨端动效实现。
- 不能声称折叠屏动效已经验证。
- 不能声称各平台可以直接照代码实现。
- 不能声称 TAB / segmented press/select/switch 已有全量录屏证据；当前已完成主 TAB、阅读模块 TAB 和 segmented control 的实现层 adapter，并补了主 TAB 切换代表截图，但媒体证据仍不完整。
- 不能声称所有下拉栏已有全量录屏证据或关闭保留动画；当前已完成 trigger/menu/option/switch 的实现层 adapter、token CSS 和 coverage gate，但 `collapse` 保留动画、打开 A 后切 B 录屏与 resize/orientation reposition 仍需证据。
- 不能声称通用按钮、chip/filter、toggle/switch、slider/stepper/progress、input/search、toast/state、selection、业务 row/card 已经完成全量交付；当前已有 selector 总表、基础 token/reduced-motion、normalized `data-motion-component-*` 状态 adapter 和 contract 状态机，但全族录屏、async pending、focus restore 和平台测试映射仍缺。
- 不能声称封面进入沉浸阅读已有全量录屏证据；当前已完成书架封面、继续阅读封面和普通阅读按钮的实现层 adapter，并补了书架封面进入代表截图，但详情/章节入口、连续点击和视频证据仍需补齐。
- 不能声称宽屏控制层 dock 长按移动已有真实设备、折叠屏或录屏证据；当前只有第一版实现层 adapter、bounds clamp 和 coverage gate。
- 不能声称自动翻页/朗读运行胶囊已有完整录屏、停止/退出打断或平台测试证据；当前已有第一版实现层 adapter、局部倒计时 timer、coverage gate 和自动翻页胶囊代表截图。
- 不能声称首次打开应用或控制层上方胶囊锚点已有录屏/设备证据；首次打开应用、控制胶囊按钮运行/暂停、倒计时数字变化、朗读图标和控制层上方胶囊锚点已有第一版实现层 adapter，并补了首启/控制层上方胶囊锚点代表截图，但真实设备录屏仍缺；控制层小横条已有第一版实现层 adapter，但真实设备录屏和 full 页 promote 证据仍缺。
- 不能声称整屏旋转已有真实设备、折叠屏、正文字符锚点重分页和完整录屏证据；当前已有第一版 `prepare/reshape/settle` adapter、root/screen host 状态、route/session/overlay/focus/dock 元数据、token CSS、coverage gate 和 compact-landscape 代表截图。
- 不能声称打断动画已有完整自动化和录屏证据；当前已有第一版 `motion.interrupt.*` adapter、临时状态清理、coverage gate 和 Tab switch redirect 代表截图，overlay/focus 状态也有第一版 adapter，连续下拉 A->B 和 reader loading async result 防覆盖已有第一版状态字段，但连续 overlay 打断和完整录屏还需深化。
- 不能声称 reduced-motion 已完成录屏验证。
- 不能把 `frontend-demo/` 的 CSS、DOM、`data-*` 字段、截图或 route stack 作为 Android / iOS / HarmonyOS 的最终前端实现依据；它们只证明契约样板。
- 不能把 demo coverage 通过等同于平台实现完成；平台必须另行提供 native test、真机/模拟器录屏、无障碍和性能证据。
