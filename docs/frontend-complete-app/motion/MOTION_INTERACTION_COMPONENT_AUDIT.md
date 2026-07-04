# 交互组件动效全量纳管审计

状态：Draft v0.1

范围：基于当前 `frontend-demo/` 的 `render-runtime.js`、样式层和四份动效规划文档，判断各类交互组件是否已经被统一动效体系纳管。

结论：通用交互组件已经进入第一版实现纳管，但还没有达到完整交付级纳管。当前 `MOTION_CONTRACT.md`、`MOTION_EFFECTS.md`、`MOTION_PLATFORM_MAPPING.md` 和 `MOTION_SELECTOR_MATRIX.md` 已补 button、toggle、chip/filter/segment、slider/progress/stepper、input/search、feedback/state、selection、listRow/card 等 Motion ID、效果、平台映射和 148 个 `data-*` selector 总表；demo 已落 `motion-tokens.css`、reduced-motion 测试开关、基础 `data-motion-id`、pressed state、`data-motion-component-*` normalized adapter 和第一版 `motion.interrupt.*` adapter。仍缺组件族专属深度状态机、async pending / focus restore、打断规则深化和录屏/截图证据。

## 1. 审计口径

这次按两个层级判断：

- 规划纳管：是否有 motion token、Motion ID、效果说明、平台映射、验收路径和缺口记录。
- 实现纳管：demo 是否已经用统一 token、统一状态机、reduced-motion、打断规则和录屏/截图证据实现。

当前结论需要把两者分开：很多组件已经进入规划，但尚未进入实现纳管。

本次扫描到的交互入口：

- `frontend-demo/render-runtime.js` / `render.js` / `index.html` 中有 148 个唯一 `data-*` 属性。
- 其中 107 个属于主要交互域：reader、source、rss、settings、discover、book、search、restore、route、overlay、dropdown、progress、selection 等。
- 语义角色覆盖 `button`、`dialog`、`listbox`、`menu`、`menuitem`、`option`、`slider`、`toolbar`。

## 2. 总体判断

| 组件族 | 当前纳管状态 | 判断 |
|---|---|---|
| 冷启动/首次打开 | 已有 Motion ID、token、效果和第一版 adapter；root / screen host 会写入 `data-motion-first-open-*` | 基础实现纳管，未录屏 |
| 主 TAB / 阅读模块 TAB / segmented TAB | 已有 `tab.item.*` | 规划纳管，未实现统一状态机 |
| 路由 push/pop / 主 Tab 切换 | 已有基础契约 | 部分纳管，普通路由方向和 dense 页面策略还需细化 |
| 键盘、底表、弹窗 | 已有 overlay Motion ID、核心时长、reduced-motion 和 `data-motion-overlay-*` role/state/action/focus-return adapter | 第一版实现纳管，未录屏 |
| 下拉栏 / popover / 锚定菜单 | 已补 `dropdown.*` | 规划纳管，未实现统一状态机 |
| Reader 封面进入沉浸阅读 | 已有 `reader.entry.*` | 规划纳管，未实现 snapshot/降级证据 |
| Reader 控制层显隐、小横条、宽屏 dock | 已有 `reader.control.*` / `reader.control.dock.*` | 规划纳管，拖动和 dock 仍未实现 |
| Reader 模块切换、快捷动作、完整页展开 | 已有 `reader.module.*` / `reader.quick.promote` / `reader.panel.expand` | 规划纳管，部分场景仍缺状态机 |
| 自动翻页/朗读会话、控制胶囊、运行空间 | 已有 `reader.session.*` | 规划纳管，demo 多为静态 UI |
| 翻页、章节跳转、换源窗口 | 已有 Reader 专属 Motion ID | 规划纳管，换源窗口缺 capture 证据 |
| 打断动画、viewport/fold/orientation | 已有 `motion.interrupt.*` 和 `viewport.*`；`motion.interrupt.*` 与 `viewport.orientation.prepare/reshape/settle` 第一版 adapter 已分别接入 `data-motion-interrupt-*` / `data-motion-orientation-*`；overlay/focus、连续下拉 A->B 和 reader loading async result guard 已接入第一版状态 adapter | interrupt/orientation/overlay/dropdown switch/async result 已进入实现层；连续 overlay 打断、fold posture 和设备证据仍需补齐 |
| 通用按钮、图标按钮、动作按钮 | 已补 `button.press/activate/disabledBlocked`，并接入基础 pressed state 与 `data-motion-component-family=button` | 第一版实现纳管，async pending / disabled evidence 和录屏仍缺 |
| chip/filter/segment/filter row | 已补 `chip.item.*`、`filter.*`、`segment.item.switch`，并接入 token 选中态 | 基础实现纳管，未录屏 |
| switch/toggle/checkbox | 已补 `toggle.press/switch/revert`，checkbox 归入 toggle family，thumb/check 已有 token transition | 基础实现纳管，未录屏 |
| slider/progress/stepper 数值控件 | 已补 `slider.*`、`stepper.*`、`progress.meter.update`，progress fill 已接 token | 基础实现纳管，未录屏 |
| 搜索输入、输入行、键盘焦点 | 已补 `input.*`、`search.state.replace`，键盘和 search state 已接 reduced-motion | 基础实现纳管，未录屏 |
| toast、inline feedback、状态卡 | 已补 `feedback.toast.*`、`state.*`，toast/state 已接 token transition | 基础实现纳管，未录屏 |
| 文本选择层、toolbar、拖拽选区手柄 | 已补 `selection.range.*`、`selection.toolbar.*`，toolbar 已接 token transition | 基础实现纳管，未录屏 |
| 书架视图切换、卡片/列表行、封面聚焦层 | 已补 `listRow.*`、`card.*`、`bookshelf.view.switch`，并接入基础 pressed / selector binding 与 `data-motion-component-family=surface/choice` | 第一版实现纳管，封面进入深动效和录屏仍缺 |
| Discover / RSS / Source / Restore 业务管理流 | 已归入通用组件族，并在 `MOTION_SELECTOR_MATRIX.md` 建立 selector 总表 | 基础实现纳管，缺证据 |
| demo/dev mode 控件 | 不属于产品主路径，但仍无统一策略 | 可低优先级纳管 |

## 3. 已纳管的核心 Motion 域

这些组件已经有较完整规划，但不能声称 demo 实现完成：

| 域 | 已有契约 | 缺口 |
|---|---|---|
| 首启与基础导航 | `app.launch.firstOpen`、`app.tab.switch`、`app.route.push/pop` | 首启动画已有 cold-start flag 和一次性 settle；仍缺路由栈方向策略和录屏证据 |
| TAB | `tab.item.press/select/switch` | 主 TAB、阅读模块 TAB、segmented TAB 的统一 pressed/select/switch 状态机 |
| Dropdown | `dropdown.trigger.press`、`dropdown.menu.expand/collapse/reposition`、`dropdown.option.press/select` | 当前 demo 仍是分散 mount/unmount、placement 和 chevron CSS |
| Overlay | `overlay.keyboard/sheet/dialog.*` | 已接入 token、reduced-motion、role/state/action/focus-return 字段和基础焦点陷阱；仍缺连续 overlay 互斥打断、录屏和平台焦点证据 |
| Reader Entry | `reader.entry.coverToImmersive`、`reader.entry.actionToImmersive` | 封面 snapshot/shared-element 和无封面入口降级 |
| Reader Control | `reader.control.show/hide`、`reader.control.handle.*`、`reader.control.dock.*` | 手势、阈值、pointer capture、dock bounds、offset 持久化 |
| Reader Session | `reader.session.*` | 胶囊动画、运行空间、倒计时 tick、语音 icon、互斥会话生命周期 |
| Reader Paging | `reader.page.turn.*`、`reader.chapter.jump` | 翻页 token 化、章节/进度拖动互斥矩阵 |
| Flow/Source Switch | `reader.sourceSwitch.open/close` | 换源窗口不同 viewport 的 capture 和打断规则 |
| Interrupt/Viewport | `motion.interrupt.*`、`viewport.fold.*`、`viewport.orientation.*` | interrupt、orientation、overlay/focus lifecycle、连续下拉 A->B 和 reader loading async result guard 已有第一版 adapter；继续补连续 overlay、fold posture 和旋转设备验证 |
| 通用组件族 | `button.*`、`toggle.*`、`chip/filter/segment.*`、`slider/stepper/progress.*`、`input/search.*`、`feedback/state.*`、`selection.*`、`listRow/card.*` | 已有 selector 总表、token、reduced-motion、基础 pressed state 和 `data-motion-component-*` normalized adapter；缺 async pending、focus restore、深度状态机证据和录屏证据 |

## 4. 已进入规划、待实现的组件族

### 4.1 通用按钮与动作控件

涉及：

- `.fd-icon-button`、`.fd-top-actions`、`.fd-action-row button`、`.fd-fixed-action-row button`。
- 阅读快捷按钮、书源批量操作按钮、RSS 详情动作按钮、设置页操作行按钮。

缺口：

- 已补 `button.press`、`button.activate`、`button.disabledBlocked`，但当前 pressed/active 样式仍散在 CSS，未统一到 token 和状态机。
- 主按钮、危险按钮、图标按钮、行内按钮已有 selector 总表，仍缺 route 级录屏证据。
- disabled、loading、confirm/destructive 语义需要落到同一 button family 的状态字段。

建议：

- 把主按钮、危险按钮、图标按钮和行内按钮归到同一个 button motion family。
- 为每类按钮建立 selector 映射和录屏证据。

### 4.2 Chip、Filter、Segment、Mode Row

涉及：

- 书架分组 chip、搜索范围 chip。
- Discover entry/filter/sort 行。
- RSS mode/group/category/manage filter/edit tabs。
- Source chip row、segment、debug module tabs。
- Settings chip row、settings segment。

缺口：

- 已补 `chip.item.press/select`、`filter.item.toggle`、`filter.apply.commit`、`segment.item.switch`，但未接入 demo selector。
- 横向 chip row 滚动、active 切换、筛选应用后的结果区更新仍缺统一打断规则和证据。
- 需要区分即时选择、待应用筛选、导航型 segment，不能全部复用 TAB 逻辑。

建议：

- 将 chip/filter/segment 分为三类：即时选择、待应用筛选、导航型 segment。
- 用 `state.content.replace` 统一承接筛选后结果区替换。

### 4.3 Toggle、Switch、Checkbox、Batch Selection

涉及：

- `.fd-settings-switch`、`.fd-reader-switch`、`.fd-source-switch`。
- `.fd-reader-auto-toggle`、`.fd-replace-switch`、`.fd-source-check`、`.fd-book-select-toggle`。
- 书源批量、RSS 批量、恢复范围多选。

缺口：

- 已补 `toggle.press`、`toggle.switch`、`toggle.revert`，checkbox 和批量选择归入同一 family，但 demo CSS/JS 还未统一。
- 多选行、批量选择、单个 switch 的状态反馈混在不同 CSS。
- disabled、loading、失败回滚还没有实现状态字段和测试证据。

建议：

- 统一 thumb 位移、check icon、选中背景和多选汇总条更新。
- 失败回滚必须回到同一控件状态，不能额外 push route 或弹出无关 overlay。

### 4.4 Slider、Progress、Stepper 数值控件

涉及：

- 阅读亮度 slider：`data-reader-brightness-track`。
- 阅读章节进度：`data-reader-chapter-progress`。
- 阅读字号/行距 stepper、page space stepper。
- 设置页 stepper。
- Restore progress meter。

缺口：

- 已补 `slider.drag.start/update/release`、`slider.value.commit`、`stepper.press/repeat/value.change`、`progress.meter.update`，但还没映射到具体 selector。
- 数值变化、track fill、thumb、readout 的同步时序还没有 demo 实现。
- 手势阈值、长按 repeat、释放 snap/commit 仍缺测试。

建议：

- 明确拖动中无 easing，释放后才 snap 或 commit。
- progress meter 更新只改 fill/readout，不重建外层卡片。

### 4.5 输入、搜索、键盘焦点

涉及：

- 搜索入口、搜索历史、搜索结果、RSS search、settings search、source search。
- `data-open-keyboard` 只覆盖键盘层进入。

缺口：

- 已补 `input.focus/blur/clear/submit` 和 `search.state.replace`，但输入 selector、键盘 overlay 和结果区状态还没有同一 reducer。
- 搜索 before/loading/results/empty/error 状态切换未统一到 `search.state.replace`。
- 搜索历史点击、clear、submit 和旧请求返回的打断规则仍缺。

建议：

- 让键盘 overlay 与 input focus 同步，而不是只做键盘层动画。
- 旧 query 结果写入前检查 current query token。

### 4.6 Toast、Inline Feedback、状态卡

涉及：

- `.fd-settings-toast`、`.fd-discover-toast`、`.fd-toast-host`。
- `.fd-search-state`、RSS empty/error、offline/permission/global state。
- 加入书架状态、缓存清理反馈、导入/导出结果。

缺口：

- 已补 `feedback.toast.enter/update/exit`、`state.content.replace`、`state.empty/error/success.enter`，但 toast host 和状态 slot 还没统一实现。
- toast 生命周期、排队、替换、dismiss、reduced-motion 未定义。
- empty/error/loading/success 之间如何切换仍缺 selector 和录屏。

建议：

- 统一 toast host：短 toast 更新同一容器，不堆叠阻塞。
- 统一状态 slot：只替换内容区，不重建页面 shell。

### 4.7 文本选择层与上下文菜单

涉及：

- `readerTextSelectionLayer`、`.fd-reader-selection-toolbar`、selection handles。
- `readerMoreMenuHtml`、`.fd-reader-more-menu`。
- 书籍焦点菜单虽然纳入 dropdown，但文本选择层还没有单独语义。

缺口：

- 已补 `selection.range.show/drag/release`、`selection.toolbar.enter/action/exit`，但文本选择层仍未接入统一状态机。
- 选区手柄、选区范围、toolbar 定位、复制/划线/笔记等 action feedback 还没有证据。

建议：

- 与 reader control、dropdown、overlay 的互斥规则单独列出。
- toolbar 需要按选区可见范围重锚定，并在 action 后释放或恢复 focus。

### 4.8 卡片、列表行、书架视图和业务列表

涉及：

- 书籍卡片/列表、搜索结果、Discover 书籍行、RSS 文章行、Source row、Restore backup card。
- 书架封面/列表视图切换。

缺口：

- 已补 `listRow.press/select/route`、`card.press/select/route`、`bookshelf.view.switch`，且已有 selector 总表和基础代码接入。
- 封面进入沉浸阅读只覆盖阅读入口；卡片/列表行普通 pressed/select、视图切换、批量选择需要走通用 row/card family。
- 大量 `role="button"` 文章/卡片仍只走即时 route。

建议：

- 区分导航型 row、选择型 row、批量型 row、结果型 row。
- 书架网格/列表切换需要保存 item identity 和 scroll anchor。

### 4.9 Discover / RSS / Source / Restore 业务管理流

涉及：

- Discover 入口、筛选、排序、登录、缓存 toast、规则测试。
- RSS 源管理、分组、批量、导入/导出、收藏、阅读记录、规则订阅。
- Source 管理、导入、批量、检测、调试、源码、删除确认。
- Restore 范围选择、进度、冲突处理、结果。

缺口：

- 已明确业务管理流不新增页面私有 motion，而是归入 row/card、chip/filter、toggle/checkbox、segment、progress/state、dialog/sheet 等通用组件族。
- 批量选择、导入结果、调试模块切换、源码/日志 segment、恢复进度和冲突选择还没有 selector 映射和实现证据。

建议：

- 不为每个业务 route 发明动画，而是把业务流归入通用组件族：row/card、chip/filter、toggle/checkbox、segment、progress/state、dialog/sheet。
- 建立 `Motion ID -> data-* selector -> route examples -> platform component -> evidence` 总表。

### 4.10 Demo / Developer Controls

涉及：

- `data-demo-mode-option`、route stack、capture/developer mode。

缺口：

- 不是产品主路径，但作为验收工具仍需要最小 reduced-motion 和状态稳定规则。

建议：

- 低优先级归入 `tooling.mode.switch` 或复用 `segment.item.switch`。

## 5. 纳管完成度矩阵

| 级别 | 定义 | 当前覆盖 |
|---|---|---|
| L0 未纳管 | 没有 Motion ID，只有静态样式或即时状态 | 产品主路径暂不保留 L0；demo/developer controls 可低优先级归类 |
| L1 泛化纳管 | 被 route/overlay/tab 等大类间接覆盖，但缺组件专属状态 | 普通 route、部分历史 CSS class、尚未映射的 dev mode 控件 |
| L2 规划纳管 | 有 Motion ID、效果说明、平台映射和缺口 | app launch、tab、dropdown、overlay、Reader 主链路、interrupt、viewport |
| L2.5 基础实现纳管 | 有 selector 总表、token、reduced-motion 测试开关、基础 pressed / state transition、`data-motion-component-*` normalized adapter 和第一版 interrupt adapter | 通用组件族、overlay 基础降级、Reader 翻页/loading token、motion.interrupt.* |
| L3 实现纳管 | demo 已统一 token、状态机、reduced-motion 和证据 | 当前没有完整达到 L3 的组件族 |

## 6. 必补缺口优先级

P0：

1. 把 `MOTION_SELECTOR_MATRIX.md` 的 evidence 列回填到具体录屏/截图。
2. 深化通用控件族状态机：`button.*`、`toggle.*`、`chip/filter/segment.*`、`listRow/card.*`。
3. 深化数值和手势控件：`slider.*`、`stepper.*`、`progress.*`。
4. 深化输入和反馈：`input.*`、`search.state.*`、`feedback.toast.*`、`state.*`。
5. 深化文本选择层：`selection.*`。

P1：

1. Discover / RSS / Source / Restore 业务流按通用控件族完成映射。
2. Haptic、sound、accessibility focus、semantics timing。
3. 性能预算、layout shift、动画属性白名单。

P2：

1. Demo/developer mode 控件归类。
2. 文档版本治理和变更流程。

## 7. 当前不能声称

- 不能声称各种交互组件的动效已经实现级统一全面纳管。
- 不能声称 demo 已经有跨端可直接实现的完整动效体系。
- 不能声称通用按钮、chip/filter、toggle/switch、slider/stepper、toast、selection、业务 row/card 已经完成深度状态机和证据；overlay 也仍缺录屏、连续打开打断和平台焦点证据。
- 不能声称已有录屏证据。

## 8. 建议下一步

下一步应从文档规划转为实现准备，而不是继续逐个业务页面追加特例：

1. 先按 `MOTION_SELECTOR_MATRIX.md` 录制 button/toggle/chip/filter/segment/listRow/card 的证据。
2. 再深化 slider/stepper/progress、input/search、feedback/state、selection 的状态机。
3. 最后按 Motion ID 录制证据，并把结果回填 gap audit。
