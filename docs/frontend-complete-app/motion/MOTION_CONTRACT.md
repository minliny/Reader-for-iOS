# 前端 Demo 动效契约初稿

状态：Draft v0.1

来源：当前 `frontend-demo/` 的路由/状态模型、Shell 结构和已有 CSS 表现。

目标：把当前 demo 从“视觉/交互原型”提升为跨端共享的动效契约，让 iOS、Android、HarmonyOS 和 Web 都能用各自原生技术实现同一套动效，而不是复制 Web CSS 或 DOM 行为。

文档边界：本文件只定义 motion token、Motion ID 和状态边界；具体动画效果、方向、透明度、位移、缩放、先后顺序和验收路径见 `MOTION_EFFECTS.md`。只靠本文件不能形成完整动效规划。

交付分层：

- Contract 层：跨平台共享 `Motion ID`、token 名称、state fields、`from/to`、interrupt、`finalState` 和 reduced-motion 规则。这一层是平台必须实现和测试的语义。
- Demo proof 层：`frontend-demo/` 只作为可执行契约样板，用浏览器路径、`data-motion-*` 状态字段、coverage 和代表截图证明状态语义、打断规则和高风险链路成立。Demo proof 不是 Android / iOS / HarmonyOS 的最终 UI 代码。
- Platform implementation 层：Android Compose、iOS SwiftUI、HarmonyOS ArkUI 必须用原生导航、原生组件、原生手势、safe area / keyboard inset、fold posture、accessibility focus 和性能工具实现最终动效。

非目标：

- 不把 Web CSS transition、DOM 结构、`data-*` selector 或 demo route stack 当作平台实现接口。
- 不用 Web demo 模拟三端全部平台差异，也不把 demo fixture 等同于真实业务生命周期。
- 不声称当前 demo 已完成跨端动效实现、折叠屏真机验证、真实设备录屏、无障碍焦点或平台性能验收。

## 1. 覆盖范围

本契约覆盖当前 demo 已经表达出来的动效面：

- `MainTabShell`：主 Tab 切换、底部导航选中反馈和稳定布局。
- `LibraryShell`：书架/搜索/详情路由推进、封面进入沉浸阅读、键盘、底表、弹窗和焦点面板。
- `ReaderShell`：封面/继续阅读进入沉浸阅读、阅读控制层、模块面板切换、快捷动作、展开式阅读面板、亮度/进度交互、翻页和行内加载。
- `SettingsShell`：设置页路由推进、选项底表、弹窗、焦点子面板和恢复流程反馈。
- `FlowShell`：从阅读器内打开的换源窗口，不使用全屏阻断式遮罩。
- 通用交互组件族：按钮、图标按钮、chip/filter、segment、toggle/switch/checkbox、slider/progress/stepper、输入/搜索、toast/state、文本选择、列表行和卡片。
- 下拉栏/锚定菜单：阅读设置下拉、朗读设置下拉、设置页选项下拉、发现排序菜单、书源更多菜单、书架更多菜单和书籍焦点菜单。
- 动画打断：新输入、返回、路由替换、overlay 互斥、loading 完成、拖动开始等场景下的动画接管和收尾。
- 折叠屏/大屏重排：手机态、半展开态、展开态、横屏紧凑态之间的布局切换和动画降级。

本初稿不覆盖：

- 不把 Web CSS 实现直接复用到平台应用。
- 不引入 WebView 作为原生 UI 运行时依赖。
- 不在设备验证前声称生产级动画性能已经完成。
- 不对阅读正文排版做会改变分页结果的装饰动画；除非用户主动修改字体、行距、页边距等排版状态。

## 2. 当前 Demo 证据

当前 demo 已经有一些动效钩子，但还没有集中管理：

| 区域 | 当前钩子 | 已有表现 |
|---|---|---|
| 键盘 | `.fd-phone.has-keyboard .fd-demo-keyboard` | 底部键盘层从 `translateY(100%)` 到 `0`，时长 `160ms ease`。 |
| 底表 | `.has-sheet .fd-demo-sheet` | 底表从底部 `translateY(100%)` 进入到 `0`，时长 `160ms ease`。 |
| 弹窗 | `.has-dialog .fd-demo-dialog` | 弹窗从 `translateY(-44%) scale(0.96)` 到 `translateY(-50%) scale(1)`。 |
| 阅读翻页 | `appState.readerTurnDirection` -> `.fd-reader-page-turn-next/prev` | 正文层从左右 +/- `16px` 进入，时长 `220ms ease-out`。 |
| 阅读加载 | `.fd-reader-loading-panel i` | spinner 使用 `0.8s linear infinite`。 |
| 焦点子面板 | `.fd-settings-subpanel.is-focused` | 子面板上浮 `-1px`，时长 `160ms ease`，并显示 focus shadow。 |

当前缺口：这些值仍分散在 CSS 和 renderer 状态逻辑里。平台应用要稳定沿用，需要先命名 motion token 和语义 transition ID。

效果缺口：每个 Motion ID 还需要明确“动画长什么样”。当前补充文件是 `MOTION_EFFECTS.md`，用于描述进入/退出方向、元素层级、时长节奏、禁用项和验收路径。

## 3. Motion Tokens

下面是建议统一的跨端词汇。数值是基于当前 demo 行为的初稿。

| Token | 值 | 用途 |
|---|---:|---|
| `app.motion.duration.firstOpen` | `280ms` | 冷启动首次打开应用后的首屏进入。 |
| `app.motion.duration.tabPress` | `80ms` | 同一 TAB 栏按钮按下/取消按下反馈。 |
| `app.motion.duration.tabSelect` | `120ms` | 单个 TAB 按钮进入或退出选中态。 |
| `app.motion.duration.tabSwitch` | `160ms` | 同一 TAB 栏从一个按钮切换到另一个按钮。 |
| `app.motion.duration.dropdownPress` | `80ms` | 下拉触发器和下拉选项的按下反馈。 |
| `app.motion.duration.dropdownExpand` | `160ms` | 下拉栏、popover、锚定菜单展开。 |
| `app.motion.duration.dropdownCollapse` | `120ms` | 下拉栏、popover、锚定菜单收起。 |
| `app.motion.duration.dropdownSelect` | `120ms` | 下拉选项选中态、check/icon 和当前值替换。 |
| `app.motion.duration.buttonPress` | `80ms` | 普通按钮、图标按钮、列表/卡片按下反馈。 |
| `app.motion.duration.buttonActivate` | `120ms` | 按钮释放确认、图标/文案状态替换。 |
| `app.motion.duration.toggleSwitch` | `140ms` | switch/toggle/checkbox 开关状态变化。 |
| `app.motion.duration.chipSelect` | `120ms` | chip、filter、segment 选中态变化。 |
| `app.motion.duration.filterCommit` | `160ms` | 筛选应用、重置和结果区短反馈。 |
| `app.motion.duration.numericCommit` | `120ms` | slider、progress、stepper 数值提交和 readout 替换。 |
| `app.motion.duration.inputFocus` | `120ms` | 输入框 focus、blur、clear、submit 反馈。 |
| `app.motion.duration.searchState` | `160ms` | 搜索 before/loading/results/empty/error 状态替换。 |
| `app.motion.duration.feedbackToast` | `180ms` | toast、inline feedback 进入/更新/退出。 |
| `app.motion.duration.stateReplace` | `160ms` | empty/error/success/state card 状态替换。 |
| `app.motion.duration.selectionToolbar` | `160ms` | 文本选择 toolbar 进入、重定位和退出。 |
| `reader.motion.duration.instant` | `0ms` | reduced motion、纯状态切换、禁用动画。 |
| `reader.motion.duration.micro` | `80ms` | 按压反馈、选中态轻反馈。 |
| `reader.motion.duration.fast` | `120ms` | 主 Tab 选中、小 chip/toggle 状态变化。 |
| `reader.motion.duration.base` | `160ms` | 键盘、底表、弹窗、焦点上浮；与当前 demo 一致。 |
| `reader.motion.duration.handleLongPress` | `320ms` | 宽屏控制层小横条长按进入拖动模式。 |
| `reader.motion.duration.handleSnap` | `120ms` | 控制层小横条释放后的吸附/回弹。 |
| `reader.motion.duration.panel` | `200ms` | 阅读模块面板和展开式控制面板进入。 |
| `reader.motion.duration.pageTurn` | `220ms` | 阅读翻页；与当前 demo 一致。 |
| `reader.motion.duration.readerEntry` | `240ms` | 从书架封面/继续阅读进入沉浸阅读。 |
| `reader.motion.duration.sessionReturn` | `200ms` | 自动翻页/朗读开启后从控制层回到沉浸阅读。 |
| `reader.motion.duration.runningSpace` | `180ms` | 运行胶囊在沉浸页脚与控制层上方锚点之间的重锚定。 |
| `reader.motion.duration.capsuleEnter` | `160ms` | 沉浸阅读运行胶囊进入、退出和类型切换。 |
| `reader.motion.duration.capsuleControl` | `120ms` | 控制胶囊内暂停/继续按钮的按压和状态切换。 |
| `reader.motion.duration.capsuleTick` | `120ms` | 自动翻页倒计时数字变化。 |
| `reader.motion.duration.voicePulse` | `960ms` | 朗读中语音图标的低频活动提示。 |
| `reader.motion.duration.overlay` | `240ms` | 弹窗背景、换源窗口、路由级覆盖层组合。 |
| `reader.motion.duration.loadingSpin` | `800ms` | 行内加载 spinner 单圈时长；与当前 demo 一致。 |
| `reader.motion.duration.interruptSettle` | `80ms` | 动画被新输入打断后的收尾/接管。 |
| `reader.motion.duration.viewportReshape` | `240ms` | 折叠屏展开/折叠、横竖屏或大屏断点变化后的布局重排。 |
| `reader.motion.duration.orientationFreeze` | `80ms` | 整屏旋转开始时冻结旧动画、释放手势和记录锚点。 |
| `reader.motion.duration.orientationSettle` | `240ms` | 整屏旋转后容器、overlay、控制层和胶囊落到新锚点。 |
| `reader.motion.easing.standard` | `ease` | 当前基础面板行为。 |
| `reader.motion.easing.exit` | `ease-in` | 关闭/退出。 |
| `reader.motion.easing.enter` | `ease-out` | 翻页和面板进入。 |
| `reader.motion.easing.reshape` | `ease-in-out` | 折叠屏和 viewport 重排。 |
| `reader.motion.distance.pageTurnX` | `16px` | 阅读翻页横向位移。 |
| `reader.motion.distance.focusY` | `-1px` | 设置/书源焦点面板上浮距离。 |
| `app.motion.distance.dropdownY` | `6px` | 下拉栏展开/收起的轻位移上限。 |
| `app.motion.distance.feedbackY` | `8px` | toast、state card、search state 进入/退出轻位移上限。 |
| `app.motion.distance.selectionToolbarY` | `6px` | 文本选择 toolbar 进入、重定位轻位移上限。 |
| `reader.motion.distance.readerEntryY` | `12px` | 沉浸阅读正文进入时的轻位移。 |
| `reader.motion.distance.controlDragMargin` | `16px` | 宽屏可移动控制层距离安全边界的最小间距。 |
| `reader.motion.distance.handlePullY` | `18px` | 控制层小横条低幅拖拽预览距离。 |
| `reader.motion.distance.runningSpaceY` | `10px` | 控制层上方胶囊锚点进入/退出的轻位移。 |
| `reader.motion.distance.orientationPanelY` | `10px` | 整屏旋转后控制层、overlay 和运行胶囊锚点重新定位的轻位移上限。 |
| `reader.motion.distance.capsuleY` | `6px` | 运行胶囊进入/退出的轻位移。 |
| `reader.motion.distance.capsuleTickY` | `4px` | 倒计时数字替换时的内部位移。 |
| `reader.motion.scale.dialogEnter` | `0.96 -> 1` | 弹窗进入缩放。 |
| `app.motion.scale.press` | `1 -> 0.98 -> 1` | 普通按钮、卡片、列表行的按下反馈缩放上限。 |
| `reader.motion.scale.coverPress` | `0.98` | 点击封面时的按压反馈。 |
| `reader.motion.scale.capsuleEnter` | `0.96 -> 1` | 运行胶囊出现时的轻缩放。 |
| `reader.motion.scale.capsuleControlPress` | `1 -> 0.90 -> 1` | 控制胶囊内暂停/继续按钮按压反馈。 |
| `reader.motion.scale.runningSpaceDock` | `0.92 -> 1` | 胶囊停靠到控制层上方锚点时的轻缩放。 |
| `reader.motion.scale.voicePulse` | `1 -> 1.06 -> 1` | 朗读图标活动提示缩放范围。 |

平台实现可以使用各自原生 easing 名称，只要视觉结果等价。

## 4. 语义 Transition ID

各平台应该实现这些命名 transition，而不是散落的匿名动画片段。

| Motion ID | 当前 demo 触发点 | 契约 |
|---|---|---|
| `app.launch.firstOpen` | 应用冷启动首次 render | 首屏内容短淡入并落位；不做阻塞式 splash，不在后台恢复或普通路由切换时重复播放。 |
| `tab.item.press` | 任一 TAB 栏按钮 pointer down / touch down | 只做按钮内部 pressed 反馈；不改变按钮占位、栏高度、栏宽度或相邻按钮坐标。 |
| `tab.item.select` | 某个 TAB 按钮成为 active | 当前按钮颜色、图标、文字和选中背景进入 active；用于首次选中或从未选中态变为选中态。 |
| `tab.item.switch` | 同一 TAB 栏 active 从 A 变为 B | A 退出 active，B 进入 active；如果有选中背景/indicator，可在同一栏内迁移或交叉淡换，但不能推动按钮布局。 |
| `app.tab.switch` | 主导航按钮 -> `goTab()` | 选中 Tab 原地变化。内容区可以短 fade，但底部导航尺寸和位置必须稳定。 |
| `app.route.push` | `[data-route]` -> `goTo(route, true)` | 非根路由入栈。平台可使用原生 stack motion；当前 demo 内容即时替换。 |
| `app.route.pop` | 返回按钮 -> `goBack()` | 返回上一层路由。方向应与 `app.route.push` 对称。 |
| `button.press` | 普通按钮、图标按钮、行内操作按钮 pointer down / touch down | 只做当前按钮内部 pressed 反馈；不改变按钮尺寸、行高、布局和相邻控件位置。 |
| `button.activate` | 按钮释放并确认执行 | 触发命令、route、submit 或状态更新；必要时只替换按钮内部 icon/label/loading，不重播页面入场。 |
| `button.disabledBlocked` | disabled / aria-disabled 按钮被触发 | 不执行命令；允许短暂 blocked 反馈或无反馈，不能制造可点击错觉。 |
| `toggle.press` | switch/toggle/checkbox 按下 | 当前控件局部 pressed；不立即改变最终值，除非平台原生控件语义要求。 |
| `toggle.switch` | switch/toggle/checkbox 值确认变化 | thumb、check、背景和 `aria-pressed` / semantics 同步变化；不重建所在 row。 |
| `toggle.revert` | 异步失败、权限不足或取消 | 从乐观值回到真实值；必须有明确短反馈，不让 UI 停在错误状态。 |
| `chip.item.press` | chip/filter/segment 按下 | 只做当前 chip 内部 pressed，不改变 chip row 滚动位置或相邻 chip 宽度。 |
| `chip.item.select` | chip/segment 成为 active | active 背景、文字色、icon 或 indicator 进入选中态；同组尺寸和间距稳定。 |
| `filter.item.toggle` | 多选筛选项勾选/取消 | 当前筛选项局部 selected 状态切换；如果需要“应用”按钮，结果区不立即替换。 |
| `filter.apply.commit` | 筛选应用/重置 | 筛选控件状态提交，结果区按 `state.content.replace` 或 `search.state.replace` 更新。 |
| `segment.item.switch` | 非主 TAB 的 segmented control 切换 | A/B 选中态在同一个 segment 内切换；不写 route stack，除非该 segment 明确是导航入口。 |
| `slider.drag.start` | slider/progress thumb 或 track 开始拖动 | 取消与该数值冲突的装饰动画；进入跟手状态。 |
| `slider.drag.update` | slider/progress 拖动中 | track fill、thumb、readout 跟手更新，不使用 easing。 |
| `slider.drag.release` | slider/progress 释放 | 提交最终值，必要时 snap 到合法刻度；随后执行 `slider.value.commit`。 |
| `slider.value.commit` | slider/progress/数值控件值确认 | 数值 readout、百分比、进度条和相关内容同步更新。 |
| `stepper.press` | stepper +/- 按下 | 当前按钮局部 pressed；禁用态不执行值变化。 |
| `stepper.repeat` | 长按 stepper 连续变化 | 按固定节奏重复提交；readout 稳定不抖动。 |
| `stepper.value.change` | stepper 数值变化 | 当前值和相关预览短更新；不重排整行。 |
| `progress.meter.update` | 恢复/导入/下载/缓存等进度更新 | 进度条 fill 和数值平滑更新；大跨度或后台恢复可直接跳到最新值。 |
| `input.focus` | 搜索框/输入行获得焦点 | 输入容器、光标、辅助文案进入 focus；可联动 `overlay.keyboard.enter`。 |
| `input.blur` | 输入失焦或键盘关闭 | focus ring 和键盘状态收回；输入值保留。 |
| `input.clear` | 清空按钮或重置搜索 | 文本清空，结果状态回到 before/empty；不重置整个 route。 |
| `input.submit` | 搜索/表单提交 | 输入控件保留，结果区进入 loading 或 results；按钮局部确认反馈。 |
| `search.state.replace` | 搜索 before/loading/results/empty/error 切换 | 搜索结果区域短淡换；搜索输入、筛选行和 route stack 稳定。 |
| `feedback.toast.enter` | toast / inline feedback 出现 | 轻位移 + fade 入场，不阻塞页面操作。 |
| `feedback.toast.update` | toast 文案或类型替换 | 同一 toast 容器内文案交叉替换，不排队堆叠。 |
| `feedback.toast.exit` | toast 超时、route 切换或被新 feedback 替换 | fade 退出并释放命中区。 |
| `state.content.replace` | 列表/结果/面板内容状态替换 | 容器稳定，内容短淡换；不改变外层 Shell、Tab 或 toolbar。 |
| `state.empty.enter` | empty state 出现 | 空状态插入当前内容容器，不替换整个页面 Shell。 |
| `state.error.enter` | error state 出现 | 错误状态进入当前容器；重试按钮使用 `button.*`。 |
| `state.success.enter` | success/result state 出现 | 成功/结果状态进入；后续操作按钮不重播页面入场。 |
| `selection.range.show` | 文本选择范围出现 | 选区高亮、手柄和 toolbar 按锚点出现；正文排版不变。 |
| `selection.range.drag` | 选择手柄拖动 | 选区范围和 toolbar 锚点跟手更新，不使用 easing。 |
| `selection.range.release` | 选择手柄释放 | 选区稳定，toolbar 重新锚定。 |
| `selection.toolbar.enter` | 文本选择 toolbar 出现 | toolbar fade + 小位移入场，锚定到选区而不是页面中心。 |
| `selection.toolbar.action` | 复制/划线/笔记/搜索等操作 | 当前 toolbar 按钮局部反馈；操作后按语义关闭或保持。 |
| `selection.toolbar.exit` | 取消选择、切 route、打开控制层 | toolbar 和选区退出，释放 pointer/focus。 |
| `listRow.press` | 可点击列表行 pointer down / touch down | 当前 row pressed；不改变列表行高度、分隔线或滚动位置。 |
| `listRow.select` | 选择型列表行选中/取消 | 选中背景、check、badge 或主文案状态同步更新。 |
| `listRow.route` | 导航型列表行进入详情 | row pressed 后执行 `app.route.push` 或对应业务 handoff。 |
| `card.press` | 书籍卡片、RSS 卡片、备份卡片、结果卡片按下 | 当前卡片局部 pressed；封面/内容不重排。 |
| `card.select` | 卡片进入选中、批量选择或聚焦状态 | 选中层、check、阴影或 focus ring 短更新。 |
| `card.route` | 卡片进入详情或阅读 | 卡片 pressed 后进入 route；书籍封面阅读入口优先使用 `reader.entry.coverToImmersive`。 |
| `bookshelf.view.switch` | 书架封面/列表视图切换 | 同一数据集合在封面/列表布局间切换；保留分组、滚动和当前选中语义。 |
| `dropdown.trigger.press` | 下拉触发按钮/设置行 pointer down / touch down | 只做触发器内部 pressed 反馈和 chevron/状态提示，不改变行高、按钮宽度或列表布局。 |
| `dropdown.menu.expand` | 下拉触发器从 closed -> open | 菜单锚定到触发器或当前行，短 fade + 轻位移展开；先完成 placement 测量，再显示菜单。 |
| `dropdown.menu.collapse` | 再次点击触发器、点击外部、返回、切 route、选择单选项 | 菜单从当前视觉状态收起并释放焦点/点击热区；关闭后触发器状态回到 closed。 |
| `dropdown.option.press` | 下拉选项 pointer down / touch down | 只作用于当前选项行，不影响菜单容器和相邻选项位置。 |
| `dropdown.option.select` | 单选/多选项确认 | 当前值、选中背景、check/icon 和 aria/semantics 同步更新；单选下拉选择后关闭，多选菜单按产品语义决定是否保持打开。 |
| `dropdown.menu.reposition` | open 状态下发生 scroll、resize、orientation、drop-up/drop-down 切换 | 重新计算锚点、最大高度和展开方向；不能跳到旧坐标，也不能被键盘/控制层/hinge 裁掉。 |
| `overlay.keyboard.enter` | `[data-open-keyboard]` -> `.has-keyboard` | 键盘从底部覆盖进入，层级高于主导航；动画期间不能挤压稳定 Shell 控件。 |
| `overlay.keyboard.exit` | `[data-close-keyboard]` | 键盘向下退出并释放输入焦点。 |
| `overlay.sheet.enter` | `[data-open-sheet]` -> `.has-sheet` | 底表从底部滑入，底层页面保持可见且布局稳定。 |
| `overlay.sheet.exit` | `[data-close-sheet]` | 底表向下退出。 |
| `overlay.dialog.enter` | `[data-open-dialog]` -> `.has-dialog` | 背景淡入，弹窗在中心 scale/fade 进入；层级必须高于底表。 |
| `overlay.dialog.exit` | `[data-close-dialog]` | 弹窗 scale/fade 退出，再清理背景。 |
| `reader.entry.coverToImmersive` | `[data-book-cover][data-route="immersive-reading"]` | 封面提供按压和上下文过渡，然后进入 `immersive-reading`；默认不显示阅读控制层，返回栈保留来源页。 |
| `reader.entry.actionToImmersive` | 继续阅读/章节/详情页阅读按钮 -> `immersive-reading` | 无封面 shared element 时使用轻量 route handoff；进入后仍是沉浸阅读态。 |
| `reader.control.show` | `immersive-reading` -> `reader` | 阅读控制层覆盖在同一个阅读正文层之上；正文层不能重排、变暗或改变透明度。 |
| `reader.control.hide` | `[data-reader-dismiss]` -> `immersive-reading` | 控制层离开，正文阅读面保持连续。 |
| `reader.control.handle.press` | `.fd-reader-grabber` / `.fd-reader-full-grabber` 按下 | 小横条提供轻量 pressed 反馈，点击热区不变化，不触发正文动画。 |
| `reader.control.handle.drag` | 小横条纵向拖动 | 面板跟手移动或展示展开预览；拖动期间不使用 easing，不改变正文排版。 |
| `reader.control.handle.release` | 小横条释放 | 超过阈值则进入 `reader.panel.expand` 或收回控制层；未超过阈值使用 `handleSnap` 回到原位。 |
| `reader.control.dock.longPress` | 宽屏 `.fd-reader-grabber` 长按 | 进入控制 dock 拖动模式；只在 fixed-width dock 布局启用。 |
| `reader.control.dock.drag` | 宽屏控制 dock 拖动中 | 整组控制 dock 跟手移动，宽高不变，不拉伸、不重排正文。 |
| `reader.control.dock.release` | 宽屏控制 dock 释放 | 位置吸附到可移动空间内的合法锚点；保存当前 viewport class 下的 dock offset。 |
| `reader.control.dock.rebound` | resize / fold 后 dock 越界 | 控制 dock 回弹到最新可移动空间内；不新增 route，也不关闭控制层。 |
| `reader.module.switch` | 底部模块导航 -> `toc-bookmarks` / `tts` / `reader-appearance` / `reader-settings` | 模块导航几何不变；只改变选中背景、图标色、文字色和面板内容。 |
| `reader.module.dismiss` | 再次点击当前 active 模块 | 回到默认阅读控制层，不改变 `ReaderContext`。 |
| `reader.quick.promote` | 快捷动作 -> 完整阅读路由 | 先显示 ReaderShell 行内加载态，再替换底部面板内容。 |
| `reader.session.autoPage.start` | `[data-reader-setting-toggle="autoPage"]` 开启自动翻页 | 开启自动翻页会话，先关闭朗读会话，再用 route replace 回到 `immersive-reading`，显示自动翻页运行胶囊。 |
| `reader.session.tts.start` | `[data-reader-tts-action="toggle"]` 开启朗读 | 开启朗读会话，先关闭自动翻页会话，再用 route replace 回到 `immersive-reading`，显示朗读运行胶囊。 |
| `reader.session.capsule.enter` | `readerImmersiveStatusCapsule(appState)` 首次出现 | 胶囊覆盖在沉浸阅读状态区，不打开完整控制层，不挤压正文。 |
| `reader.session.capsule.update` | 倒计时、播放/暂停、句序等运行状态变化 | 只更新胶囊内部图标、数字和文案，不重放整颗胶囊入场。 |
| `reader.session.capsule.control.press` | `.fd-ir-status-controls button` 按下 | 控制按钮提供局部 pressed 反馈；胶囊容器、正文和 route 不动。 |
| `reader.session.capsule.control.toggle` | `.fd-ir-status-controls button` 释放确认 | 在运行/暂停之间切换；只更新按钮图标、播放态、倒计时或语音图标状态，不打开控制层。 |
| `reader.session.capsule.countdownTick` | 自动翻页倒计时数字变化 | 只动画倒计时数字本身，胶囊容器、文案和页码不抖动。 |
| `reader.session.capsule.voiceIcon.active` | 朗读进行中语音图标 | 语音图标提供低频活动提示；暂停、reduced motion 或后台时保持静态。 |
| `reader.session.capsule.switch` | 自动翻页和朗读互斥切换 | 胶囊留在原锚点，内部 icon/label 交叉替换；不要先退场再重新入场。 |
| `reader.session.capsule.exit` | 停止会话、退出阅读、会话结束 | 胶囊淡出并释放点击热区；正文仍保持沉浸阅读上下文。 |
| `reader.session.controlSpace.enter` | 运行会话存在时 `immersive-reading` -> `reader` | 同一运行胶囊重锚定到控制层上方；不在控制首页额外生成临时状态条，也不同时显示两套运行主控。 |
| `reader.session.controlSpace.update` | 控制层打开时运行/暂停、倒计时、朗读状态变化 | 只更新控制层上方胶囊内部状态，不重启动控制层进入动画。 |
| `reader.session.controlSpace.exit` | 控制层隐藏回 `immersive-reading` | 控制层上方胶囊回到沉浸阅读页脚胶囊锚点，或在不支持 morph 时等价淡出/淡入。 |
| `reader.panel.expand` | `reader-full-*` 路由 | 展开式阅读面板从控制层上方展开；顶部阅读栏和阅读正文保持上下文可见。 |
| `reader.page.turn.next` | `onNextPage` / `data-reader-page-action=next` | 正文层从右侧进入，使用 `pageTurn` 时长；页码状态只变更一次。 |
| `reader.page.turn.prev` | `onPreviousPage` / `data-reader-page-action=prev` | 正文层从左侧进入，使用 `pageTurn` 时长；页码状态只变更一次。 |
| `reader.chapter.jump` | 目录/章节行 | 直接替换正文内容，不做装饰性 route 动画；同时重置页码和进度。 |
| `reader.sourceSwitch.open` | 顶部 `source-switch` 路由 | 在阅读交互平面内打开换源窗口。不使用全屏变暗；顶栏、底部控制层和模块导航按契约保持可操作。 |
| `reader.sourceSwitch.close` | 关闭/替换路由 | 移除换源窗口，并确保返回栈里不残留 `source-switch`。 |
| `state.loading.inline` | `renderActiveRoute(..., { loading: true })` | 行内加载面板出现在当前 Shell 内；spinner 使用 `loadingSpin`。 |
| `state.focus.flash` | 书源/设置焦点动作 -> `.is-focused` | 短时间显示 focus ring / lift，然后回到普通状态。 |
| `motion.interrupt.cancel` | 返回、关闭、切 Tab、切 route、拖动开始 | 正在播放的非必要动画立即取消，状态切到最新目标；允许使用 `interruptSettle` 做最短收尾。 |
| `motion.interrupt.redirect` | 面板 A 进入中又打开面板 B | 当前动画不倒放回起点，直接从当前视觉位置接管到新目标。 |
| `motion.interrupt.completeThenReplace` | loading 完成、数据到达、异步状态返回 | 当前必要状态动画收尾后立即替换内容；总延迟不能让交互显得卡住。 |
| `motion.async.resultGuard` | reader loading、搜索或远端结果返回前用户已经返回/切 route | 每个异步结果必须带 requestId、from/to、stack/context；只有仍匹配当前 route/context 的结果才能替换内容，过期结果写入 discarded/cancelled 状态且不得覆盖新页面。 |
| `viewport.fold.expand` | 折叠屏从手机/半开态进入展开态 | 布局从单列过渡到双栏/宽布局；阅读正文重新测量，控制层保持同一交互语义。 |
| `viewport.fold.collapse` | 折叠屏从展开态回到手机/半开态 | 双栏/宽布局收回单列；当前 route、overlay 和 ReaderContext 保留。 |
| `viewport.orientation.prepare` | 横竖屏/整屏旋转开始、`visualViewport` 或 window metrics 变化 | 冻结当前 route、ReaderContext、active session、overlay、focus、dock offset 和正文阅读锚点；取消非必要动画和进行中的拖动。 |
| `viewport.orientation.reshape` | portrait / landscape / compact-landscape / tablet-expanded 断点变化 | 使用 `viewportReshape` 统一处理整屏布局重排；阅读正文优先重新测量和分页，控制层、overlay、运行胶囊和控制层上方锚点重新定位。 |
| `viewport.orientation.settle` | 旋转后布局测量稳定 | 恢复 focus/pointer/语义可见性，clamp 宽屏 control dock 位置，恢复运行胶囊倒计时/朗读图标微动效。 |

## 5. 通用交互组件约束

通用控件优先复用本章 Motion ID，不为每个业务页面新增特例：

- 普通按钮、图标按钮、危险按钮、主按钮、行内操作按钮都走 `button.*`。业务命令可以不同，但 pressed、activate、disabled blocked 的节奏必须一致。
- switch、toggle、checkbox、批量选择勾选都走 `toggle.*`。开关状态只能改变当前控件和必要汇总信息，不能重建整行或整页。
- chip、filter、segment 必须先判定语义：即时选择走 `chip.item.select`，多选筛选走 `filter.item.toggle`，提交筛选走 `filter.apply.commit`，导航型 segment 才允许触发 route。
- slider、progress scrub、stepper 都属于数值控件。拖动中必须跟手无 easing；释放后才 snap、commit 或触发正文/结果重新测量。
- 输入框和搜索结果必须拆开：输入 focus/blur/clear/submit 走 `input.*`，结果区域切换走 `search.state.replace` 或 `state.content.replace`。
- toast、inline feedback、empty/error/success/state card 走 `feedback.*` 或 `state.*`，不能用临时 route 或弹窗伪装轻反馈。
- 文本选择层走 `selection.*`，它和 reader control、dropdown、overlay 互斥；选区拖动不能改变正文排版。
- 导航型 row/card、选择型 row/card、批量型 row/card 必须分开：按下走 `listRow.press` / `card.press`，选择走 `select`，进入详情或阅读才走 `route` 或 reader entry。
- 书架封面/列表视图切换走 `bookshelf.view.switch`，不能混成主 TAB 切换、route push 或列表逐项飞入。
- Discover、RSS、Source、Restore 的业务页面不单独定义业务专属动效；它们必须映射到 button、chip/filter、toggle、segment、row/card、state、progress、dialog/sheet 这些通用组件族。

## 6. Reader 专属约束

阅读器动效比普通应用页面更严格：

- 首次打开应用只用于冷启动首屏，不作为每个页面的入场动画；恢复前台和 route 切换不能重复播放。
- 同一 TAB 栏的按钮动效分三层：`press` 是按下反馈，`select` 是单按钮进入选中态，`switch` 是 active 从一个按钮迁移到另一个按钮。三者不能混成一次整栏重建。
- 阅读正文层是锚点。控制层必须覆盖在正文之上，不能改变标题、段落边距、透明度或分页结果。
- 从封面进入沉浸阅读时，封面只作为上下文锚点，不把封面强行 morph 成正文；最终落点必须是稳定的阅读纸面和正文层。
- 正常阅读时，`reader.page.turn.*` 是唯一允许作用在正文层上的装饰性动画。
- 任何打断都以最新用户意图为准：返回、关闭、拖动和切换 route 的优先级高于正在播放的装饰动画。
- 字体、主题、亮度、页边距、章节切换都先是状态变化；应该动画化控制控件，而不是动画化已测量的正文排版。
- 四个阅读模块按钮在 loading、active、inactive、switching 状态下都要保持尺寸、间距和点击热区稳定。
- 主 TAB 栏、阅读模块 TAB 栏和二级 segmented TAB 都必须保持按钮数量、间距、点击热区和栏尺寸稳定；选中态只能在按钮内部或独立 indicator 层变化。
- 所有下拉栏、popover 和锚定菜单必须共享 `dropdown.*` 语义。阅读设置、朗读设置、设置页选项、发现排序、书源更多、书架更多和书籍焦点菜单不能各自发明不同的展开/收起/点击节奏。
- 下拉菜单必须锚定触发器或当前设置行。展开/收起只能使用 opacity、轻位移或轻缩放，不能推挤列表行、改变触发器尺寸、改变当前 Shell 布局或重排阅读正文。
- 下拉选项点击分为 `option.press` 和 `option.select`。press 是局部反馈；select 才更新值、check/icon、`aria-selected` / semantics 和菜单关闭状态。
- 打开一个新的下拉时，旧下拉必须先走 `dropdown.menu.collapse` 或被 `motion.interrupt.redirect` 接管；同一层级不能保留多个互相遮挡的下拉。
- 下拉栏在 viewport/orientation/fold/键盘变化时走 `dropdown.menu.reposition`；如果空间不足，优先 drop-up 或限制最大高度，仍不足才降级到底表/全高选择器。
- 控制层小横条是面板手势入口，不是新的导航层。拖动开始时取消正在播放的面板动画，释放后只落到一个最终状态。
- 宽屏固定宽度控制层可通过长按小横条拖动。可拖动对象是同一组 control dock，包括底部控制面板、当前模块/快捷面板和模块导航；顶栏、正文层和沉浸热区不跟随移动。
- 宽屏 control dock 拖动只改变 dock offset，不能改变 `--reader-dock-width`、面板高度、按钮间距、正文测量宽高或阅读分页。
- 宽屏 control dock 可移动空间必须裁剪在当前 ReaderFrame 或当前 fold pane 内，并保留安全边距；不能跨 hinge、不能进入系统安全区、不能把小横条拖出可触达区域。
- 整屏旋转不是 route transition。旋转中必须保留 active tab、当前 route、返回栈、ReaderContext、章节进度、当前模块、active session、运行胶囊/控制层上方锚点状态和 overlay 语义。
- 整屏旋转时，阅读正文按章节进度或字符锚点重新分页；不能只按旧 page index 映射，避免横竖屏页数变化后跳章或跳段。
- 整屏旋转中如果控制层打开，需要把控制层映射到新 viewport class 的等价容器；手机底部整宽面板、compact landscape 压缩面板、宽屏 fixed dock 之间只改变容器锚点，不改变 ReaderContext。
- 整屏旋转后，宽屏 fixed dock 的保存 offset 必须按新的可移动空间重新 clamp；如果旧 offset 越界，使用 `reader.control.dock.rebound` 回弹到合法锚点。
- 整屏旋转开始时，正在进行的控制层拖动、小横条长按拖动、TAB pressed、胶囊按钮 pressed 和 overlay enter/exit 都要取消或提交到最近安全状态，不能跨旋转保留半按下/半拖动状态。
- 自动翻页和朗读是互斥运行会话。开启其中一个时，另一个必须先完成状态取消，再显示新的运行胶囊。
- 自动翻页/朗读从控制层或完整设置页启动后，必须用 route replace 回到 `immersive-reading`，不能把控制层留成额外返回层。
- 运行胶囊（控制胶囊）只表达当前会话状态和轻量控制；不能把完整控制层、朗读面板或自动翻页设置塞进胶囊。
- 点击控制胶囊内暂停/继续按钮只切换当前会话运行态，不触发 `reader.control.show`，不重播胶囊入场。
- 运行会话存在时打开控制层，需要让同一颗胶囊重锚定到控制层上方；不能让沉浸胶囊和控制层临时状态条同时成为主控制。
- 倒计时数字变化和朗读图标活动提示都是胶囊内部微动效，不能触发整颗胶囊重入场或正文重排。
- 沉浸阅读中点击正文中部打开控制层时，运行胶囊需要淡出或停靠到控制层语义位置，不能与控制层重复显示成两套主控制。
- 快捷 overlay 和底部功能 overlay 的可见性契约不同：
  - 快捷 overlay 可以保留快捷按钮、浮动页内控制和底部模块导航。
  - 底部功能 overlay 隐藏快捷按钮、亮度和浮动页内控制，但保留顶栏和底部模块导航。
- 换源属于阅读交互平面的一部分。除非产品契约明确变更，否则不能变成全局阻断式 modal。

## 7. Reduced Motion 契约

所有平台都必须提供一致的 reduced-motion 行为：

- 时长降为 `instant`，或最多 `80ms`。
- 位移距离降为 `0`。
- 必要反馈通过颜色、透明度、focus ring、选中态或内容替换保留。
- 系统开启 reduced motion 时，加载 spinner 可以替换为静态进度/状态提示。
- 阅读翻页变成即时内容替换，但页码和阅读进度仍要更新。
- TAB 按钮只保留颜色/透明度/状态变化；不做 scale、indicator 位移或内容区位移。
- 通用按钮、toggle、chip/filter/segment、row/card 只保留颜色、背景、outline、check/icon 和文案状态变化。
- slider、progress、stepper 在 reduced motion 下仍可即时更新数值，但不做 thumb snap 动画、fill tween 或 readout 位移。
- input/search、toast/state、selection toolbar 最多保留 `80ms` fade，不做 y 位移或 scale。
- 下拉栏 reduced motion 下即时展开/收起或最多 `80ms` 淡入淡出；不做 y 位移、缩放、chevron 旋转动画或列表项级联动画。
- 自动翻页/朗读回到沉浸阅读时即时替换 route；运行胶囊最多做 `80ms` 淡入淡出，不做 y 位移或缩放。
- 首次打开应用只保留首屏淡入；控制层小横条不做拖拽跟随动画，宽屏 control dock 释放后即时落到合法位置；运行胶囊在沉浸页脚与控制层上方锚点之间使用短淡入淡出，不做 morph；控制胶囊按钮、倒计时数字和语音图标保持静态状态变化。
- 整屏旋转只做即时重排或最多 `80ms` 淡换；不做整页旋转、缩放、飞入或长距离滑动。

## 8. 原生平台映射原则

- Web demo：验证 Motion ID、状态字段、route/context 关系、层级关系、reduced-motion 和高风险链路是否可复现；不作为平台 CSS/DOM 复用源。
- Android Compose：使用原生 `AnimatedVisibility`、`AnimatedContent`、`updateTransition`、`Animatable` / gesture state 和显式 `ReaderMotionTokens`，按 reducer 的最新状态取消或接管旧动画。
- iOS SwiftUI：使用 `withAnimation`、`transition`、`matchedGeometryEffect` 降级策略、稳定容器和 `UIAccessibility.isReduceMotionEnabled`，保留 `NavigationPath`、focus 和 reader progress anchor。
- HarmonyOS ArkUI：使用原生 `animateTo` / transition / gesture API，并提供本地 `ReaderMotionTokens` adapter，按窗口/折叠状态和安全区重算布局。

平台应用应该共享语义 ID 和 token 值，而不是共享实现语法。

平台必须自行验证：

- 真实设备录屏、低端设备帧率、GPU/CPU 性能预算和 reduced-motion。
- 折叠屏展开/折叠、半开态、hinge/pane 约束、大屏多窗口和横屏紧凑态。
- 原生键盘、安全区、系统返回、导航栈、后台/恢复生命周期和异步结果回写。
- 原生手势阈值、velocity/cancel、pointer capture 等价行为。
- TalkBack / VoiceOver / ArkUI accessibility focus、弹窗焦点陷阱和语义恢复。

## 9. 验收清单

本契约进入实装前，需要满足：

- 每个 Motion ID 都有 `frontend-demo/` 内的 capture route 或可复现点击路径。
- 每个 Motion ID 都出现在平台映射文档里。
- 每个 Motion ID 都在 `MOTION_EFFECTS.md` 中有视觉效果说明。
- 当前 renderer/runtime 使用的 Motion ID 都必须能通过 `ReaderMotionController.contractFor()` 解析到 state machine；P0 关键 Motion ID 必须有精确 `from/to/interrupt/finalState/reducedMotion`，不能只依赖 family fallback。
- 每个高风险 Motion ID 都明确区分：Contract 已定义、Demo proof 已具备或待补、Platform implementation 未完成或待验证。
- demo 使用集中 motion token，不再散落裸写 `160ms`、`220ms` 和 `0.8s`。
- demo 定义并验证 `prefers-reduced-motion`。
- 点击封面进入沉浸阅读必须覆盖书架封面、继续阅读封面和列表/详情无封面入口的降级路径。
- 通用交互组件族必须覆盖 button、toggle/switch/checkbox、chip/filter/segment、slider/progress/stepper、input/search、feedback/state、selection、listRow/card、bookshelf view switch。
- 148 个唯一 `data-*` 交互入口都需要映射到某个 Motion ID、demo route、平台组件和验证方式；不能只按业务页面口头归类。
- 同一 TAB 栏必须分别覆盖按钮按下、单按钮选中、A -> B 切换、重复点击当前 active 的行为。
- 所有下拉栏/锚定菜单必须覆盖触发器按下、展开、收起、选项按下、选项选中、打开 A 后切到 B、外部点击关闭、返回关闭、resize/orientation 重定位和 reduced-motion 降级。
- 首次打开应用、运行胶囊与控制层上方锚点停靠必须有可复现路径；首次打开应用、控制层小横条按压/拖动/释放、宽屏 fixed dock 长按移动、运行胶囊进入/更新/切换、控制层上方胶囊锚点、控制胶囊按钮运行/暂停、倒计时数字变化和朗读语音图标活动提示已接入第一版 demo adapter；首启、自动翻页胶囊和控制层上方胶囊锚点已有代表性浏览器截图，但仍需真实设备、折叠屏和录屏证据。
- 自动翻页和朗读启动必须覆盖“控制层/完整页 -> 沉浸阅读 -> 运行胶囊”的完整路径，并验证两者互斥切换。
- 阅读控制层、模块切换、换源窗口、底表、键盘和弹窗都在 portrait、tablet-expanded、compact-landscape 视口下检查过。
- 打断动画覆盖返回、关闭 overlay、切 Tab、切 route、loading 完成、拖动开始和连续点击模块。
- 折叠屏/大屏重排覆盖手机态、展开态、半展开态、横屏紧凑态；并验证 ReaderContext、overlay 层级和返回栈不丢失。
- 整屏旋转覆盖 portrait -> landscape、landscape -> portrait、compact-landscape -> portrait、tablet-expanded resize；并验证控制层、运行胶囊、控制层上方胶囊锚点、overlay、focus 和宽屏 dock offset 都映射到合法位置。
- 平台应用为阅读翻页、控制层显隐、模块切换、底表、弹窗、键盘和换源窗口提供 native motion 测试或 golden/人工复核证据。

平台 handoff 输出必须是任务边界和验收清单，而不是 Web CSS 复用说明。任何 `data-motion-*`、`data-* selector`、CSS variable 或 demo query 参数只用于 demo 内部取证和调试；平台实现只能映射其背后的 Motion ID、state fields、token 语义和验收结果。

高风险链路的最终交付边界见 `docs/ui-handoff/MOTION_PLATFORM_MAPPING.md` 的“高风险链路收束表”：该表逐项区分 Contract 层共享内容、Demo proof 保留范围、Platform implementation 必须完成的 native 证据，以及当前不能声称完成的事项。

## 10. 未决项

- 当前路由推进多数是即时替换 HTML；需要决定原生应用是否使用平台 stack motion，还是在密集操作页面保持即时切换。
- 通用交互组件族已完成 contract/effects/platform mapping、`MOTION_SELECTOR_MATRIX.md`、基础 token、reduced-motion 测试开关、`data-motion-id` / pressed state 接入、contract 层状态机和第一版 `data-motion-component-*` normalized adapter；首批 P0 代表截图已进入 `frontend-demo/verify/motion/evidence/manifest.json`，但还缺全族录屏、async pending、focus restore 和平台测试文件映射。
- TAB / segmented 已补 `tab.item.press/select/switch` 和 `segment.item.switch` contract 状态机；主 TAB、阅读模块 TAB 和 segmented control 已接入实现层 `data-motion-tab-*` / `data-motion-segment-*` 状态、press-id 和 token 化状态 CSS。indicator 媒体证据和录屏仍缺。
- 下拉栏已补 `dropdown.*` contract 状态机；当前 demo 已接入实现层 `data-motion-dropdown-*` 状态、trigger/menu/option adapter、`dropdown.option.press` press-id、打开 A 后切 B 的 `data-motion-dropdown-switch-*` / `motion.interrupt.redirect` adapter 和 token 化展开/选项点击/接管 CSS，并补 bookshelf more menu 展开代表截图。关闭保留动画、resize/orientation reposition 和完整录屏证据仍缺。
- 宽屏控制层长按拖动已接入第一版 demo adapter：宽屏 `.fd-reader-grabber` 长按后进入 `reader.control.dock.longPress`，拖动时更新 dock group transform，释放提交 viewport class offset，resize 后 clamp/rebound，窄屏清理 transform；真实设备、折叠屏 hinge/pane 和录屏证据仍缺。
- 封面进入沉浸阅读已接入 `data-motion-entry-*` source/target 状态、封面 snapshot 层、普通按钮 fallback 和 token 化淡入，并补书架封面 source/target 代表截图；详情/章节入口覆盖、连续点击打断和录屏证据仍缺。
- 自动翻页/朗读运行胶囊已接入第一版实现层 adapter：启动会话后 route replace 回 `immersive-reading`，胶囊写入 `data-motion-session-capsule-*` 状态，支持 enter/update/switch/exit、倒计时 tick、play/pause 局部按钮和 TTS voice icon active；自动翻页胶囊已有代表截图，录屏、停止/退出打断和平台测试证据仍缺。
- 控制层小横条已接入 `data-motion-control-handle-*` source/panel 状态、press/drag/release 精确状态机、drag preview、release snap/expand/collapse、full 页收回和 reduced-motion；真实设备长路径拖动、目录 full 页上拉 promote 和录屏证据仍缺。
- 首次打开应用、运行胶囊与控制层上方胶囊锚点停靠已有第一版实现层 adapter，但还没有完整录屏/设备证据；控制胶囊按钮运行/暂停、倒计时数字替换和朗读图标活动提示已有第一版实现层 adapter，但还缺真实设备和录屏证据；宽屏 control dock 长按拖动已有第一版实现，但还缺真实设备、折叠屏和录屏证据。
- 键盘、底表、弹窗和 settings overlay 已接入第一版 `data-motion-overlay-*` role/state/action/focus-return adapter，overlay 主体和触发器都有可验证状态字段，token 化 enter CSS 已接入；连续 overlay 打断、遮罩互斥、录屏和平台焦点测试仍缺。
- 当前弹窗背景还没有独立命名的 fade token。
- 阅读控制层显隐还需要单独做一次视觉 pass；当前 route-state 行为已经存在，但进入/退出动效没有完全 token 化。
- 换源窗口需要在 portrait 和 compact landscape 下补 capture 证据，明确进入/退出表现。
- 打断动画已接入第一版 demo adapter：`motion.interrupt.cancel/redirect/completeThenReplace` 会在 route push/replace/back、Tab 切换、viewport 变化、loading 完成、宽屏 dock 拖动开始、pointer cancel 和连续下拉 A->B 时写入对应 interrupt / dropdown switch 状态，并清理 pressed、tab/segment/dropdown pressed、handle dragging 和 dock dragging 临时状态；reader loading 异步结果已接入 `data-motion-async-*` requestId / pending / completed / cancelled / discarded 防覆盖状态；Tab switch redirect 已有代表截图，overlay/focus 状态字段也已有第一版 adapter，连续 overlay 打断和录屏证据仍缺。
- 折叠屏展开/折叠目前按 viewport 断点规划，仍需要真实设备或模拟器验证 hinge、半开态和窗口尺寸变化。
- 整屏旋转已补 `viewport.orientation.prepare/reshape/settle` 第一版实现层 adapter；demo 会在方向或 viewport class 改变时写入 root / screen host `data-motion-orientation-*`，记录 route、session、overlay、focus、dock sync、from/to viewport 和 reanchor 状态，并用 token 化 reshape/anchor settle。真实设备、折叠屏 hinge/pane、正文字符锚点重分页、overlay/focus 恢复自动化和录屏证据仍缺。
- 当前 `docs/ui-handoff/compose/COMPOSE_INTERACTION_CONTRACTS.md` 只定义事件和状态变化，还没有定义 motion；首轮验证后应引用本契约。

## 11. 建议下一轮 Slice

1. 按 `MOTION_SELECTOR_MATRIX.md` 回填 evidence，优先录制通用组件族、键盘、底表、弹窗、翻页和 loading。
2. 按 `MOTION_IMPLEMENTATION_GAP_AUDIT.md` 继续补 P0 缺口；通用组件族和 overlay/focus 已有第一版 adapter，reader loading 已有 request-scoped async result guard，下一步补全族录屏、平台测试文件映射，并把 interrupt adapter 继续覆盖到连续 overlay。
3. 继续补整屏旋转和折叠屏证据；首次打开、运行胶囊、控制层上方胶囊锚点、控制胶囊内部微动效、宽屏 dock 和 orientation lifecycle 已有第一版 adapter，下一步补录屏、停止/退出打断、后台恢复、正文重分页和折叠屏验证。
4. 从 canonical `frontend-demo/` 路径录制或截图核心动效状态。
