# 动效平台映射初稿

状态：Draft v0.1

主契约：`frontend-demo/MOTION_CONTRACT.md`

效果说明：`frontend-demo/MOTION_EFFECTS.md`

本文档把 demo 动效契约映射到各平台的原生实现概念。它是实现指导，不是要求把 Web demo 嵌入平台应用，也不是要求复制 CSS。

## 0. 交付分层

| 层 | 交付物 | 责任边界 | 不承担 |
|---|---|---|---|
| Contract | Motion ID、token、state fields、`from/to`、interrupt、`finalState`、reduced-motion | 所有平台共享同一语义；变更时同步 `MOTION_CONTRACT.md`、`MOTION_EFFECTS.md` 和 contract registry | 不定义平台具体 API 调用和 DOM/CSS 结构 |
| Demo proof | `frontend-demo/` route、`data-motion-*` 状态、coverage、代表截图/录屏 | 证明关键状态流、打断规则、层级、reduced-motion 和高风险链路可复现 | 不证明平台真机性能、折叠屏、键盘、安全区、导航栈或无障碍已完成 |
| Platform implementation | Compose / SwiftUI / ArkUI 原生实现、平台测试、真机/模拟器证据 | 按原生组件、导航、手势、安全区、keyboard inset、fold posture、accessibility focus 实现最终体验 | 不复制 Web CSS、DOM、`data-* selector`、fixture route stack 或浏览器 viewport 行为 |

平台团队接收的是任务边界和验收清单，不是 Web CSS 复用指令。`data-motion-*` 和 selector matrix 只用于把 demo 证据追溯到 Motion ID。

## 0.1 高风险链路收束表

| 链路 | Contract 层必须共享 | Demo proof 现在保留 | Platform implementation 必须完成 | 当前不能声称 |
|---|---|---|---|---|
| TAB / segmented | `tab.item.press/select/switch`、`reader.module.switch`、`segment.item.switch`；`from/to`、active-repeat、reduced-motion | 主 TAB、阅读模块 TAB、segmented 写入 `data-motion-tab-*` / `data-motion-segment-*`，coverage 验证状态机 | 原生 TabRow / NavigationBar / Picker / Segment 控件，indicator 不推动布局，录屏或 golden | 不能声称已有全量录屏或平台控件已完成 |
| Dropdown / anchored menu | `dropdown.trigger.press`、`dropdown.menu.expand/collapse/reposition`、`dropdown.option.press/select`、A -> B `motion.interrupt.redirect` | demo 保留 trigger/menu/option/switch 状态和代表截图，用于证明同层单 open 与接管语义 | Compose DropdownMenu/Popup、SwiftUI Menu/Popover、ArkUI Popup；空间不足降级、orientation reposition、焦点恢复 | 不能声称关闭保留动画、reposition、平台焦点测试已完成 |
| 封面进入阅读 | `reader.entry.coverToImmersive`、`reader.entry.actionToImmersive`；source/target、fallback、reduced-motion | 书架封面/继续阅读/普通按钮入口写入 source/target，代表截图证明最终是 `immersive-reading` | 原生 shared/snapshot 或 fade 降级；跨 pane/hinge 不做封面飞行；原生导航栈返回来源页 | 不能声称详情/章节入口、连续点击和真机录屏已完成 |
| 阅读控制层 | `reader.control.handle.press/drag/release`、`reader.control.dock.longPress/drag/release/rebound`；阈值、bounds、finalState | 小横条、full 页收回、宽屏 dock bounds clamp 和 reduced-motion 保留 demo adapter | 原生 gesture、velocity/cancel、safe area、fold pane、resize clamp；真机/模拟器录屏 | 不能声称真实触摸、fold hinge、目录 full 页 promote 已完成 |
| 自动翻页 / 朗读胶囊 | `reader.session.autoPage.start`、`reader.session.tts.start`、`reader.session.capsule.*`；互斥、playing、countdown、voice、exit | demo 证明启动后 replace 回沉浸页、唯一胶囊、倒计时/播放态局部更新 | 原生 `activeSession` reducer，后台恢复、锁屏、章节跳转、停止/退出打断；真机录屏 | 不能声称停止/退出、后台生命周期、平台测试完成 |
| 控制层上方胶囊锚点 | `reader.session.controlSpace.enter/update/exit`；capsule-to-above-control-anchor、single controller、reduced-motion | demo 保留 `data-reader-control-space` 和子角色，证明控制层里只有同一颗运行胶囊主控，切换控制层子页不丢失 | 原生控制层中映射 active session；隐藏控制层回沉浸页脚胶囊；结束态释放 hit area | 不能声称 matched geometry、停止/退出、平台测试完成 |
| Orientation / resize | `viewport.orientation.prepare/reshape/settle`、`viewport.fold.expand/collapse`；route/session/overlay/focus/dock 元数据 | demo 用 viewport class、orientation 状态和代表截图证明 reshape/reanchor 语义 | 原生 window metrics、size class、fold posture、正文锚点重分页、dock clamp | 不能声称真实旋转、折叠屏、正文字符锚点重分页已验证 |
| Interrupt / async result | `motion.interrupt.cancel/redirect/completeThenReplace`、`motion.asyncResult.*`；latest intent wins、requestId、discard | demo coverage 验证 route/tab/dropdown/loading/dock drag 等入口清理临时态，async 旧结果不覆盖新 route | 平台 reducer 取消旧 transition、检查 route/context/requestId、overlay/focus restore 自动化 | 不能声称连续 overlay、焦点恢复和完整录屏已完成 |
| Reduced motion | 所有高风险 Motion ID 的 reduced-motion fallback；状态反馈仍可辨认 | demo 保留 URL / system reduced-motion 状态和 coverage gate | 平台接入系统 reduced motion，去除大位移/循环动画，保留语义反馈 | 不能声称 reduced-motion 全链路录屏和平台证据已完成 |

## 1. 共享 Token 命名

| 契约 token | Web/CSS 初稿 | Android Compose 初稿 | iOS SwiftUI 初稿 | HarmonyOS ArkUI 初稿 |
|---|---|---|---|---|
| `app.motion.duration.firstOpen` | `--app-motion-duration-first-open` | `AppMotionTokens.DurationFirstOpen` | `AppMotion.Duration.firstOpen` | `AppMotion.durationFirstOpen` |
| `app.motion.duration.tabPress` | `--app-motion-duration-tab-press` | `AppMotionTokens.DurationTabPress` | `AppMotion.Duration.tabPress` | `AppMotion.durationTabPress` |
| `app.motion.duration.tabSelect` | `--app-motion-duration-tab-select` | `AppMotionTokens.DurationTabSelect` | `AppMotion.Duration.tabSelect` | `AppMotion.durationTabSelect` |
| `app.motion.duration.tabSwitch` | `--app-motion-duration-tab-switch` | `AppMotionTokens.DurationTabSwitch` | `AppMotion.Duration.tabSwitch` | `AppMotion.durationTabSwitch` |
| `app.motion.duration.buttonPress` | `--app-motion-duration-button-press` | `AppMotionTokens.DurationButtonPress` | `AppMotion.Duration.buttonPress` | `AppMotion.durationButtonPress` |
| `app.motion.duration.buttonActivate` | `--app-motion-duration-button-activate` | `AppMotionTokens.DurationButtonActivate` | `AppMotion.Duration.buttonActivate` | `AppMotion.durationButtonActivate` |
| `app.motion.duration.toggleSwitch` | `--app-motion-duration-toggle-switch` | `AppMotionTokens.DurationToggleSwitch` | `AppMotion.Duration.toggleSwitch` | `AppMotion.durationToggleSwitch` |
| `app.motion.duration.chipSelect` | `--app-motion-duration-chip-select` | `AppMotionTokens.DurationChipSelect` | `AppMotion.Duration.chipSelect` | `AppMotion.durationChipSelect` |
| `app.motion.duration.filterCommit` | `--app-motion-duration-filter-commit` | `AppMotionTokens.DurationFilterCommit` | `AppMotion.Duration.filterCommit` | `AppMotion.durationFilterCommit` |
| `app.motion.duration.numericCommit` | `--app-motion-duration-numeric-commit` | `AppMotionTokens.DurationNumericCommit` | `AppMotion.Duration.numericCommit` | `AppMotion.durationNumericCommit` |
| `app.motion.duration.inputFocus` | `--app-motion-duration-input-focus` | `AppMotionTokens.DurationInputFocus` | `AppMotion.Duration.inputFocus` | `AppMotion.durationInputFocus` |
| `app.motion.duration.searchState` | `--app-motion-duration-search-state` | `AppMotionTokens.DurationSearchState` | `AppMotion.Duration.searchState` | `AppMotion.durationSearchState` |
| `app.motion.duration.feedbackToast` | `--app-motion-duration-feedback-toast` | `AppMotionTokens.DurationFeedbackToast` | `AppMotion.Duration.feedbackToast` | `AppMotion.durationFeedbackToast` |
| `app.motion.duration.stateReplace` | `--app-motion-duration-state-replace` | `AppMotionTokens.DurationStateReplace` | `AppMotion.Duration.stateReplace` | `AppMotion.durationStateReplace` |
| `app.motion.duration.selectionToolbar` | `--app-motion-duration-selection-toolbar` | `AppMotionTokens.DurationSelectionToolbar` | `AppMotion.Duration.selectionToolbar` | `AppMotion.durationSelectionToolbar` |
| `app.motion.duration.dropdownPress` | `--app-motion-duration-dropdown-press` | `AppMotionTokens.DurationDropdownPress` | `AppMotion.Duration.dropdownPress` | `AppMotion.durationDropdownPress` |
| `app.motion.duration.dropdownExpand` | `--app-motion-duration-dropdown-expand` | `AppMotionTokens.DurationDropdownExpand` | `AppMotion.Duration.dropdownExpand` | `AppMotion.durationDropdownExpand` |
| `app.motion.duration.dropdownCollapse` | `--app-motion-duration-dropdown-collapse` | `AppMotionTokens.DurationDropdownCollapse` | `AppMotion.Duration.dropdownCollapse` | `AppMotion.durationDropdownCollapse` |
| `app.motion.duration.dropdownSelect` | `--app-motion-duration-dropdown-select` | `AppMotionTokens.DurationDropdownSelect` | `AppMotion.Duration.dropdownSelect` | `AppMotion.durationDropdownSelect` |
| `reader.motion.duration.instant` | `--reader-motion-duration-instant` | `ReaderMotionTokens.DurationInstant` | `ReaderMotion.Duration.instant` | `ReaderMotion.durationInstant` |
| `reader.motion.duration.micro` | `--reader-motion-duration-micro` | `ReaderMotionTokens.DurationMicro` | `ReaderMotion.Duration.micro` | `ReaderMotion.durationMicro` |
| `reader.motion.duration.fast` | `--reader-motion-duration-fast` | `ReaderMotionTokens.DurationFast` | `ReaderMotion.Duration.fast` | `ReaderMotion.durationFast` |
| `reader.motion.duration.base` | `--reader-motion-duration-base` | `ReaderMotionTokens.DurationBase` | `ReaderMotion.Duration.base` | `ReaderMotion.durationBase` |
| `reader.motion.duration.handleLongPress` | `--reader-motion-duration-handle-long-press` | `ReaderMotionTokens.DurationHandleLongPress` | `ReaderMotion.Duration.handleLongPress` | `ReaderMotion.durationHandleLongPress` |
| `reader.motion.duration.handleSnap` | `--reader-motion-duration-handle-snap` | `ReaderMotionTokens.DurationHandleSnap` | `ReaderMotion.Duration.handleSnap` | `ReaderMotion.durationHandleSnap` |
| `reader.motion.duration.panel` | `--reader-motion-duration-panel` | `ReaderMotionTokens.DurationPanel` | `ReaderMotion.Duration.panel` | `ReaderMotion.durationPanel` |
| `reader.motion.duration.pageTurn` | `--reader-motion-duration-page-turn` | `ReaderMotionTokens.DurationPageTurn` | `ReaderMotion.Duration.pageTurn` | `ReaderMotion.durationPageTurn` |
| `reader.motion.duration.readerEntry` | `--reader-motion-duration-reader-entry` | `ReaderMotionTokens.DurationReaderEntry` | `ReaderMotion.Duration.readerEntry` | `ReaderMotion.durationReaderEntry` |
| `reader.motion.duration.sessionReturn` | `--reader-motion-duration-session-return` | `ReaderMotionTokens.DurationSessionReturn` | `ReaderMotion.Duration.sessionReturn` | `ReaderMotion.durationSessionReturn` |
| `reader.motion.duration.runningSpace` | `--reader-motion-duration-running-space` | `ReaderMotionTokens.DurationRunningSpace` | `ReaderMotion.Duration.runningSpace` | `ReaderMotion.durationRunningSpace` |
| `reader.motion.duration.capsuleEnter` | `--reader-motion-duration-capsule-enter` | `ReaderMotionTokens.DurationCapsuleEnter` | `ReaderMotion.Duration.capsuleEnter` | `ReaderMotion.durationCapsuleEnter` |
| `reader.motion.duration.capsuleControl` | `--reader-motion-duration-capsule-control` | `ReaderMotionTokens.DurationCapsuleControl` | `ReaderMotion.Duration.capsuleControl` | `ReaderMotion.durationCapsuleControl` |
| `reader.motion.duration.capsuleTick` | `--reader-motion-duration-capsule-tick` | `ReaderMotionTokens.DurationCapsuleTick` | `ReaderMotion.Duration.capsuleTick` | `ReaderMotion.durationCapsuleTick` |
| `reader.motion.duration.voicePulse` | `--reader-motion-duration-voice-pulse` | `ReaderMotionTokens.DurationVoicePulse` | `ReaderMotion.Duration.voicePulse` | `ReaderMotion.durationVoicePulse` |
| `reader.motion.duration.overlay` | `--reader-motion-duration-overlay` | `ReaderMotionTokens.DurationOverlay` | `ReaderMotion.Duration.overlay` | `ReaderMotion.durationOverlay` |
| `reader.motion.duration.loadingSpin` | `--reader-motion-duration-loading-spin` | `ReaderMotionTokens.DurationLoadingSpin` | `ReaderMotion.Duration.loadingSpin` | `ReaderMotion.durationLoadingSpin` |
| `reader.motion.duration.interruptSettle` | `--reader-motion-duration-interrupt-settle` | `ReaderMotionTokens.DurationInterruptSettle` | `ReaderMotion.Duration.interruptSettle` | `ReaderMotion.durationInterruptSettle` |
| `reader.motion.duration.viewportReshape` | `--reader-motion-duration-viewport-reshape` | `ReaderMotionTokens.DurationViewportReshape` | `ReaderMotion.Duration.viewportReshape` | `ReaderMotion.durationViewportReshape` |
| `reader.motion.duration.orientationFreeze` | `--reader-motion-duration-orientation-freeze` | `ReaderMotionTokens.DurationOrientationFreeze` | `ReaderMotion.Duration.orientationFreeze` | `ReaderMotion.durationOrientationFreeze` |
| `reader.motion.duration.orientationSettle` | `--reader-motion-duration-orientation-settle` | `ReaderMotionTokens.DurationOrientationSettle` | `ReaderMotion.Duration.orientationSettle` | `ReaderMotion.durationOrientationSettle` |
| `app.motion.distance.dropdownY` | `--app-motion-distance-dropdown-y` | `AppMotionTokens.DropdownY` | `AppMotion.Distance.dropdownY` | `AppMotion.dropdownY` |
| `app.motion.distance.feedbackY` | `--app-motion-distance-feedback-y` | `AppMotionTokens.FeedbackY` | `AppMotion.Distance.feedbackY` | `AppMotion.feedbackY` |
| `app.motion.distance.selectionToolbarY` | `--app-motion-distance-selection-toolbar-y` | `AppMotionTokens.SelectionToolbarY` | `AppMotion.Distance.selectionToolbarY` | `AppMotion.selectionToolbarY` |
| `reader.motion.distance.pageTurnX` | `--reader-motion-distance-page-turn-x` | `ReaderMotionTokens.PageTurnX` | `ReaderMotion.Distance.pageTurnX` | `ReaderMotion.pageTurnX` |
| `reader.motion.distance.focusY` | `--reader-motion-distance-focus-y` | `ReaderMotionTokens.FocusY` | `ReaderMotion.Distance.focusY` | `ReaderMotion.focusY` |
| `reader.motion.distance.readerEntryY` | `--reader-motion-distance-reader-entry-y` | `ReaderMotionTokens.ReaderEntryY` | `ReaderMotion.Distance.readerEntryY` | `ReaderMotion.readerEntryY` |
| `reader.motion.distance.controlDragMargin` | `--reader-motion-distance-control-drag-margin` | `ReaderMotionTokens.ControlDragMargin` | `ReaderMotion.Distance.controlDragMargin` | `ReaderMotion.controlDragMargin` |
| `reader.motion.distance.handlePullY` | `--reader-motion-distance-handle-pull-y` | `ReaderMotionTokens.HandlePullY` | `ReaderMotion.Distance.handlePullY` | `ReaderMotion.handlePullY` |
| `reader.motion.distance.runningSpaceY` | `--reader-motion-distance-running-space-y` | `ReaderMotionTokens.RunningSpaceY` | `ReaderMotion.Distance.runningSpaceY` | `ReaderMotion.runningSpaceY` |
| `reader.motion.distance.orientationPanelY` | `--reader-motion-distance-orientation-panel-y` | `ReaderMotionTokens.OrientationPanelY` | `ReaderMotion.Distance.orientationPanelY` | `ReaderMotion.orientationPanelY` |
| `reader.motion.distance.capsuleY` | `--reader-motion-distance-capsule-y` | `ReaderMotionTokens.CapsuleY` | `ReaderMotion.Distance.capsuleY` | `ReaderMotion.capsuleY` |
| `reader.motion.distance.capsuleTickY` | `--reader-motion-distance-capsule-tick-y` | `ReaderMotionTokens.CapsuleTickY` | `ReaderMotion.Distance.capsuleTickY` | `ReaderMotion.capsuleTickY` |
| `app.motion.scale.press` | `--app-motion-scale-press` | `AppMotionTokens.PressScale` | `AppMotion.Scale.press` | `AppMotion.pressScale` |
| `reader.motion.scale.dialogEnter` | `--reader-motion-scale-dialog-enter` | `ReaderMotionTokens.DialogEnterScale` | `ReaderMotion.Scale.dialogEnter` | `ReaderMotion.dialogEnterScale` |
| `reader.motion.scale.coverPress` | `--reader-motion-scale-cover-press` | `ReaderMotionTokens.CoverPressScale` | `ReaderMotion.Scale.coverPress` | `ReaderMotion.coverPressScale` |
| `reader.motion.scale.capsuleEnter` | `--reader-motion-scale-capsule-enter` | `ReaderMotionTokens.CapsuleEnterScale` | `ReaderMotion.Scale.capsuleEnter` | `ReaderMotion.capsuleEnterScale` |
| `reader.motion.scale.capsuleControlPress` | `--reader-motion-scale-capsule-control-press` | `ReaderMotionTokens.CapsuleControlPressScale` | `ReaderMotion.Scale.capsuleControlPress` | `ReaderMotion.capsuleControlPressScale` |
| `reader.motion.scale.runningSpaceDock` | `--reader-motion-scale-running-space-dock` | `ReaderMotionTokens.RunningSpaceDockScale` | `ReaderMotion.Scale.runningSpaceDock` | `ReaderMotion.runningSpaceDockScale` |
| `reader.motion.scale.voicePulse` | `--reader-motion-scale-voice-pulse` | `ReaderMotionTokens.VoicePulseScale` | `ReaderMotion.Scale.voicePulse` | `ReaderMotion.voicePulseScale` |

## 2. Transition 映射

| Motion ID | Demo 来源 | Web 表现 | Android Compose 实现方向 | iOS SwiftUI 实现方向 | HarmonyOS ArkUI 实现方向 |
|---|---|---|---|---|---|
| `app.launch.firstOpen` | 冷启动首次 render；demo 输出 `data-motion-first-open-*` | Shell 和首屏内容短 fade/lift，只播放一次；settle 后保持最终尺寸和命中区。 | `LaunchedEffect(appSessionId)` 驱动一次性 content transition；不要绑定每次 route。 | app root `onAppear` 只在 cold start 标记下 `withAnimation`。 | app root 初始化状态驱动一次性淡入。 |
| `tab.item.press/select/switch` | 主 TAB / 阅读模块 TAB / segmented TAB | press、单按钮选中、A -> B 切换分层；栏尺寸稳定。 | `InteractionSource` 管 press；active indicator 放在 tab row overlay；内容动画放在 nav 外。 | `ButtonStyle`/gesture 管 press；`matchedGeometryEffect` 或 crossfade 管 indicator。 | pressed state + active indicator 独立层；内容区单独 transition。 |
| `button.press/activate/disabledBlocked` | 普通按钮、图标按钮、行内操作按钮、危险按钮 | 按下只反馈当前按钮；释放后触发确认态、loading 或 route；禁用态只给不可用反馈。 | `Button`/`IconButton` + `InteractionSource`；loading/disabled 写入同一 button state。 | `ButtonStyle`/`PrimitiveButtonStyle` 管 pressed；loading/disabled 由 view state 驱动。 | Button/ImageButton pressed state；disabled/loading 不创建新 route。 |
| `toggle.press/switch/revert` | switch、toggle、checkbox、多选按钮 | pressed、thumb/check 切换和失败回滚分开；多选汇总区独立更新。 | `Switch`/`Checkbox`/`FilterChip`，thumb/check 用 token；失败时 reducer 回滚目标值。 | `Toggle`/`ToggleStyle` 或 checkbox 自定义样式；失败回滚用同一 binding state。 | Toggle/Checkbox state；失败回滚回同一控件，不额外弹层。 |
| `chip.item.press/select` | 书架分组、搜索范围、source chip、settings chip | chip 本体按下和 active 切换；横向 chip row 不因 active 文案变化抖动。 | `FilterChip`/`AssistChip` 或稳定宽度 row；结果区变化另走 `state.content.replace`。 | capsule button/custom chip；active 背景和 check/icon 局部 transition。 | Button/chip row；active indicator 局部更新。 |
| `filter.item.toggle/filter.apply.commit` | Discover/RSS/Source/Restore 筛选 | 单项勾选可即时反馈；应用筛选后结果区统一替换，旧请求不能覆盖新状态。 | filter state 与 result state 分开；`AnimatedContent` 只包结果区。 | filter selection state 与 result model 分开；task result 写入前检查筛选版本。 | filter panel state 与 result state 分开，应用后只替换结果容器。 |
| `segment.item.switch` | segmented control、模式切换、管理/编辑 tabs | indicator/active item 切换；内容区可短 fade，segment 本体尺寸稳定。 | `SingleChoiceSegmentedButtonRow` 或 TabRow；content 用 `AnimatedContent`。 | `Picker(.segmented)` 或 custom segment；内容用 opacity/transition。 | Segmented control/custom row；内容独立 transition。 |
| `slider.drag.start/update/release` | 亮度、阅读进度、章节进度、可拖进度条 | 拖动中 thumb/fill/readout 跟手，无 easing；释放后才 commit/snap。 | `Slider` + `onValueChange` 跟手，`onValueChangeFinished` commit；取消冲突动画。 | `Slider`/`DragGesture`；drag state 与 committed value 分离。 | Slider/Gesture；拖动中只写 temporary value。 |
| `slider.value.commit/progress.meter.update` | 数值提交、恢复进度、导入/检测进度 | commit 后 readout/track 微更新；progress meter 只更新 fill，不重建卡片。 | committed value 触发局部 recomposition；progress 用 `LinearProgressIndicator`。 | committed value 局部 `withAnimation`；progress 用 `ProgressView` 或 custom fill。 | Progress/Slider 局部刷新。 |
| `stepper.press/repeat/value.change` | 字号、行距、页间距、设置页步进 | 按下有局部反馈；长按重复；数值和预览区更新解耦。 | IconButton + repeat job；value change 更新 text/preview，布局稳定。 | ButtonStyle + repeat gesture/timer；preview 独立 transition。 | button repeat gesture；value display 固定宽度。 |
| `input.focus/blur/clear/submit` | 搜索框、设置搜索、书源/RSS 搜索 | 焦点环、clear 按钮、submit 状态统一；键盘 overlay 与 input focus 同步。 | `TextField` focus state + keyboard insets；clear/submit 是同一 input reducer。 | `FocusState` + keyboard frame；clear/submit 不重建 search shell。 | TextInput focus state；keyboard/panel 与 focus 绑定。 |
| `search.state.replace/state.content.replace` | 搜索 before/loading/results/empty/error、列表状态替换 | 搜索状态和结果容器替换，不重放页面 route 动画。 | `AnimatedContent(targetState = searchState)`；request version 防旧结果覆盖。 | `AnimatedContent` 等价的 opacity/transition；task 写入前检查 query token。 | result container state transition；旧请求丢弃。 |
| `feedback.toast.enter/update/exit` | toast、inline feedback、缓存清理/导入结果 | 同一 host 内 enter/update/exit；短 toast 不堆叠阻塞。 | `SnackbarHost` 或自定义 toast host；队列策略写入 host state。 | overlay toast host；同一 container 文案更新。 | Toast/overlay host；超时退出释放点击区域。 |
| `state.empty/error/success.enter` | empty、error、success、offline/permission 状态 | 状态卡进入只替换内容区，不改变外层 shell。 | empty/error/success composable 用同一 slot；`AnimatedContent` 包 slot。 | ZStack/slot 容器替换；focus 映射到新状态主操作。 | slot 内容替换，semantics 更新。 |
| `selection.range.show/drag/release` | 阅读文本选区、手柄、选区高亮 | 选区和手柄按文本锚点出现；拖动跟手，正文排版不变。 | 使用平台 Text selection 能力优先；自定义时 overlay handles + selection state。 | 原生 Text selection 优先；自定义 toolbar/handles 绑定 geometry anchor。 | Text selection 或 custom overlay；拖动中只更新 selection range。 |
| `selection.toolbar.enter/action/exit` | 复制、划线、笔记、更多 toolbar | toolbar 锚定选区可见范围；点击 action 后局部反馈或退出。 | Popup/DropdownMenu anchored to selection rect；与 reader control/dropdown 互斥。 | `Menu`/custom overlay anchored to selection；action 后恢复 VoiceOver focus。 | Popup/menu anchored to selection；action 后释放 overlay。 |
| `listRow.press/select/route` | RSS 文章、Source row、搜索结果、恢复项、管理列表 | 导航型、选择型、批量型 row 的 pressed/select/route 分开；行高稳定。 | `LazyColumn` item 使用 stable key；row press/select 与 navigation 分离。 | `List`/`LazyVStack` stable identity；navigation push 放在 row activate 后。 | List item stable key；pressed/select state 局部。 |
| `card.press/select/route/bookshelf.view.switch` | 书籍卡片、备份卡、发现书籍、书架网格/列表切换 | 卡片 press/select 与封面进入区分；视图切换保留滚动/选择上下文。 | Lazy grid/list stable keys；view switch 映射相同 item identity。 | Grid/List 切换保存 scroll anchor；card select 不触发 reader entry。 | Grid/List state 保持 item identity。 |
| `dropdown.trigger.press` | 下拉触发器/设置行 | 触发器内部 pressed，chevron/open state 不改布局。 | `InteractionSource` 或 pointer state；Row 高宽稳定，chevron 独立旋转或 reduced-motion 静态。 | `ButtonStyle` / `onLongPressGesture` 不需要；普通 press state 即可，chevron 独立状态。 | button pressed state；触发器布局稳定。 |
| `dropdown.menu.expand/collapse` | 阅读/朗读/设置/发现/书源/书架锚定菜单 | 锚点测量后 fade + 轻位移展开/收起；同层只留一个 open。 | `Popup` / anchored menu / `DropdownMenu`，用 shared token 包装 enter/exit；打开新菜单时关闭旧菜单。 | `popover` / custom overlay anchored to geometry；用同 token 做 fade/offset，空间不足降级 sheet。 | Popup/overlay anchored to component；统一 enter/exit token。 |
| `dropdown.option.press/select` | 下拉选项点击和选择 | 选项局部 pressed；选中态、check/icon 和当前值 `120ms` 更新；单选后关闭。 | option row pressed + selected state；single-select 写 reducer 后关闭 menu；semantics 更新。 | option `ButtonStyle` + selected/check transition；single-select 后关闭并恢复 focus。 | option pressed + selected state；single-select 后关闭并更新 accessibility state。 |
| `dropdown.menu.reposition` | open 菜单遇到 scroll/resize/orientation/键盘/fold | 重新计算 drop-up/drop-down、max-height 和锚点；必要时降级底表/全高选择器。 | 基于 constraints/window insets/fold pane 重算 popup bounds；键盘遮挡时改用 bottom sheet。 | 基于 GeometryProxy/safe area/keyboard frame 重算；空间不足使用 sheet。 | 基于 window/fold safe area 重算；空间不足降级 sheet/panel。 |
| `app.tab.switch` | 主导航 -> `goTab()` | 导航位置稳定，只更新选中态，内容区可短 fade。 | 内容区使用 `AnimatedContent(targetState = selectedTab)`；`MainTabBar` 放在动画外。 | 选中态使用 `withAnimation(.easeOut(duration: fast))`；内容区使用 `opacity` transition。 | 选中态绑定状态；内容区可做 opacity transition。 |
| `app.route.push` | `[data-route]` -> `goTo(route, true)` | 当前 demo 即时替换 route 内容。 | Navigation host push；按 Shell 使用平台 stack 或 `AnimatedContent`。 | `NavigationStack` push 或 Shell 级自定义 transition。 | Router push，优先使用原生页面 transition。 |
| `app.route.pop` | 返回 -> `goBack()` | 当前 demo 即时切回上一 route。 | 与 push 对称；root tab 切换保持稳定。 | 与 push 对称。 | 与 push 对称。 |
| `overlay.keyboard.enter/exit` | `.has-keyboard` | 从底部覆盖进入/退出。 | 系统输入法优先用系统动画；自定义键盘用 `AnimatedVisibility` + `slideInVertically/slideOutVertically`。 | 系统键盘优先跟随系统动画；自定义键盘用 `.move(edge: .bottom)`。 | 系统输入法优先用系统动画；自定义层用底部 slide transition。 |
| `overlay.sheet.enter/exit` | `.has-sheet .fd-demo-sheet` | 底部滑入，不替换 route。 | `ModalBottomSheet` 或自定义 `AnimatedVisibility` 底部滑入；页面保持挂载。 | 平台 `.sheet` 或自定义底部面板 transition。 | `bindSheet` 或自定义底部面板 transition。 |
| `overlay.dialog.enter/exit` | `.has-dialog .fd-demo-dialog` | 背景 + 中心 scale/fade。 | `Dialog` 内容外包显式 scale/fade 动画。 | `.scaleEffect` + `.opacity`，背景单独 fade。 | Dialog 组件或自定义 overlay scale/fade。 |
| `reader.entry.coverToImmersive` | `[data-book-cover] -> immersive-reading` | 封面 pressed + 阅读纸面淡入；封面只作来源锚点。 | 可用 `SharedTransitionLayout` / snapshot；折叠屏跨 pane 时降级为右侧阅读纸面淡入。 | 可用 `matchedGeometryEffect`，不适用时用 source press + reader fade。 | 用 snapshot/overlay 或普通 fade；hinge 场景不跨折痕飞行。 |
| `reader.entry.actionToImmersive` | 阅读按钮/章节行 -> immersive-reading | 无封面 snapshot 的轻量 route handoff。 | Button press + `AnimatedContent` reader fade；不进入控制层。 | `withAnimation` 淡入 reader surface；不显示 controls。 | button press + reader surface fade；不显示 controls。 |
| `reader.control.show/hide` | `immersive-reading` <-> `reader` | 同一阅读正文层上替换 route-state。 | Reader 正文层保持挂载，控制层用 `AnimatedVisibility`。 | 正文 view 保持挂载，控制层叠加 transition。 | 正文组件保持挂载，控制层独立动画。 |
| `reader.control.handle.press/drag/release` | `.fd-reader-grabber` / `.fd-reader-full-grabber` | 小横条 pressed、拖动跟手、释放阈值决定展开/收回。 | `Modifier.draggable` / `anchoredDraggable` 管 offset 和 anchor；route 只在 release 后更新。 | `DragGesture` 管临时 offset；release 后用 snap animation 或切状态。 | ArkUI gesture 管临时 offset；release 后切换 reader panel state。 |
| `reader.control.dock.longPress/drag/release/rebound` | 宽屏 `.fd-reader-grabber` | 长按后拖动 fixed-width control dock；bounds clamp；释放吸附；resize 越界回弹。 | `detectDragGesturesAfterLongPress` 或 `anchoredDraggable`；bounds 由 `BoxWithConstraints`、window insets、fold pane 计算。 | `LongPressGesture` + `DragGesture` 组合；按 geometry/insets 计算 clamp。 | long press gesture + pan；按 window/fold safe area 计算 clamp。 |
| `reader.module.switch` | 阅读模块路由 | 模块导航稳定，只改选中态和面板内容。 | 底部模块导航放在 `AnimatedContent` 外；只动画面板内容。 | 模块栏稳定；面板使用 opacity 或纵向 slide。 | 模块导航稳定；只动画面板。 |
| `reader.quick.promote` | 快捷动作 -> loading -> 完整路由 | 先行内加载，再替换完整阅读面板。 | 状态机：`QuickOverlay -> Loading -> ExpandedPanel`；保持 `ReaderContext` 稳定。 | 同一状态机，使用 `withAnimation`。 | 同一状态机，使用 ArkUI state 和 transition。 |
| `reader.session.autoPage.start` | `data-reader-setting-toggle="autoPage"` | 开启后 route replace 回沉浸阅读，显示自动翻页胶囊。 | reducer 设置 `activeSession=autoPage`，取消 TTS；正文保持挂载，`AnimatedVisibility` 显示 capsule。 | `ReaderSession.autoPage` 驱动 overlay capsule；`NavigationPath` 不新增记录。 | ArkUI state 设置 autoPage，会话 capsule 作为 reader overlay。 |
| `reader.session.tts.start` | `data-reader-tts-action="toggle"` | 开启后 route replace 回沉浸阅读，显示朗读胶囊。 | reducer 设置 `activeSession=tts`，取消 autoPage；capsule 进入。 | `ReaderSession.tts` 驱动 overlay capsule；不 push 控制页。 | ArkUI state 设置 tts，会话 capsule 作为 reader overlay。 |
| `reader.session.capsule.enter/update/exit` | `.fd-ir-status-capsule` | 胶囊 opacity/translateY/scale 入场；内部状态更新；停止后淡出。 | `AnimatedVisibility` 管进入/退出；倒计时只重组内部 Text；播放 icon 用 `AnimatedContent`。 | `overlay(alignment:)` 管 capsule；图标/数字用局部 transition。 | 使用独立 overlay 组件；倒计时和播放态只更新内部节点。 |
| `reader.session.capsule.control.press/toggle` | `.fd-ir-status-controls button` | 按钮局部 scale/opacity；释放后切换 play/pause 图标和 playing state。 | 按钮用 `InteractionSource`/pressed state；图标用 `AnimatedContent`；reducer 只更新 active session playing。 | `ButtonStyle` pressed + 局部 icon transition；不改 navigation path。 | button pressed state + icon transition；只更新 session state。 |
| `reader.session.capsule.countdownTick` | `.fd-ir-countdown-dot` | 数字固定宽度，旧数上移淡出，新数下方淡入。 | `AnimatedContent(targetState = countdown)`，容器固定宽度，禁用整颗 capsule 重入场。 | 固定宽度 text，可用局部 numeric transition 或 opacity/offset。 | 固定宽度 Text，数字节点局部 transition。 |
| `reader.session.capsule.voiceIcon.active` | `.fd-ir-status-capsule[type=tts]` | 朗读图标低频 opacity/scale pulse；暂停静态。 | 仅 playing 时 `rememberInfiniteTransition`，reduced motion 下禁用。 | 仅 playing 时 symbol/opacity pulse，reduced motion 下静态。 | 仅 playing 时循环 scale/opacity，reduced motion 下静态。 |
| `reader.session.capsule.switch` | 自动翻页/朗读互斥切换 | 同锚点替换 icon/label，不退场再入场。 | 同一 capsule container，`AnimatedContent(targetState = activeSession)` 替换内部内容。 | 同一 capsule view，内部内容交叉替换。 | 同一 capsule 容器，内部内容 transition。 |
| `reader.session.controlSpace.enter/update/exit` | 运行胶囊 <-> 控制层上方胶囊锚点 | 支持时用 snapshot/matched geometry 停靠；不支持时同一胶囊在两个锚点间 fade/position update。 | `SharedTransitionLayout` 或 overlay snapshot；结束态只保留控制层上方胶囊。 | `matchedGeometryEffect` 或 ZStack snapshot；降级为交叉淡入淡出。 | overlay snapshot 或普通 fade；hinge 场景不跨 pane。 |
| `reader.panel.expand` | `reader-full-*` 路由 | ReaderShell 内展开式面板。 | 底部面板从控制层增长/滑出；顶部阅读栏保持稳定。 | 自定义底部面板 transition；除非产品变更契约，否则不要推成无关全屏。 | Reader shell 内自定义 panel transition。 |
| `reader.page.turn.next/prev` | `readerTurnDirection` class | 正文从 +/- `16px` 进入，`220ms ease-out`。 | 以 page index 为 key 的 `AnimatedContent` 横向 slide/fade；不能改变 route。 | 基于 page index 做 `transition(.asymmetric(...))` 或 offset/opacity。 | 基于 page index 动画正文容器 offset/opacity。 |
| `reader.chapter.jump` | 章节行 | 即时替换正文，重置页状态。 | 直接更新 chapter/page 状态，不做装饰性 stack motion。 | 直接更新 reader state。 | 直接更新 reader state。 |
| `reader.sourceSwitch.open/close` | `source-switch` route | 阅读平面内窗口，无全屏阻断变暗。 | 阅读器内联 overlay，不用全局 modal；按契约保持顶栏/底栏可操作。 | Reader `ZStack` 内联 overlay，不使用 sheet/modal。 | Reader stack 内联 overlay，不使用 global dialog。 |
| `state.loading.inline` | `data-reader-loading` | Shell 内 spinner。 | 行内 progress 组件，语义边界清晰。 | `ProgressView` 或自定义 spinner；reduced motion 下可静态化。 | 原生 loading indicator；reduced motion 下可静态化。 |
| `state.focus.flash` | `.is-focused` | focus ring 和 `-1px` lift，持续有限时间。 | 临时 focused visual state，避免布局位移。 | 临时 focused visual state。 | 临时 focused visual state。 |
| `motion.interrupt.cancel` | 新操作打断旧动画 | 取消旧 CSS 动画并切到最新状态。 | 用单一 state reducer/transition target，取消旧 `Animatable` 或更新 `Transition` target。 | 以最新 state 驱动 `withAnimation`，旧动画不排队。 | 以最新 state 更新 transition target，取消旧动画。 |
| `motion.interrupt.redirect` | A 面板进入中切 B 面板 | 从当前视觉状态接管到新目标。 | `updateTransition` 直接切新 target；容器不重复创建。 | 当前 view 保持，同容器切换 content transition。 | 同容器切换目标 state。 |
| `motion.interrupt.completeThenReplace` | loading 完成或异步返回 | loading 最短显示后替换，主动返回优先；输出 requestId/from/to/context，过期结果为 cancelled/discarded。 | reducer 判断 user intent 优先级，loading result 写入前校验 requestId + current route/context。 | task result 写入前检查 requestId、current route 和 NavigationPath。 | 异步结果写入前检查 requestId 与当前页面状态。 |
| `viewport.fold.expand` | 折叠屏展开 | 单列重排到展开态，ReaderContext 保留。 | 使用 `WindowSizeClass` / fold posture 状态驱动布局；正文重新分页。 | 使用 size class / scene size 驱动布局；正文重新测量。 | 使用窗口尺寸/折叠状态驱动重排；正文重新测量。 |
| `viewport.fold.collapse` | 折叠屏折叠 | 展开态收回手机态，overlay 等价降级。 | 宽布局状态映射回单列；overlay 映射到底表/面板。 | 宽布局映射回 compact；保留 navigation path。 | 宽布局映射回单列；保留 router state。 |
| `viewport.orientation.prepare` | 横竖屏/整屏旋转开始 | 写入 `data-motion-orientation-state=preparing`，记录 route、active session、overlay、focus、dock sync、from/to viewport；取消旧动画由后续统一 interrupt reducer 补齐。 | configuration/window metrics 变化时冻结 UI motion state，取消 drag/pressed/Animatable，保留 Navigation state。 | geometry/size class 变化前保存 NavigationPath、reader anchor、focus 和 dock offset；取消 gesture 临时态。 | window/orientation 变化时保存 router、reader state、session 和 overlay，取消旧 transition。 |
| `viewport.orientation.reshape` | 横竖屏/resize/断点变化 | `data-orientation` / `data-viewport-class` 切换，并写入 `data-motion-orientation-role`；控制层、胶囊、overlay、dropdown 和宽屏 dock 重锚定 / clamp，正文重分页证据仍需补。 | 根据 `WindowSizeClass`、constraints、insets 和 fold pane 重新 layout；阅读分页按进度/字符锚点映射。 | 根据 size class、GeometryProxy、safe area 重新 layout；阅读分页按进度/字符锚点映射。 | 根据窗口尺寸、方向和 fold safe area 重新 layout；阅读分页按进度/字符锚点映射。 |
| `viewport.orientation.settle` | 旋转后布局稳定 | 写入 `data-motion-orientation-state=settling/settled`，恢复 pointer，clamp fixed-width dock，恢复胶囊倒计时/朗读 icon 微动效；focus 恢复自动化仍需补。 | layout pass 后 clamp saved dock offset，恢复 semantics/focus，继续 active session 更新。 | layout 稳定后 clamp dock offset，恢复 VoiceOver focus 和 capsule micro motion。 | layout 稳定后 clamp dock offset，恢复可操作层和 session micro motion。 |

## 3. 平台 Guardrails

Android Compose：

- 使用 Kotlin/Compose 原生组件；不要用 WebView 渲染 `frontend-demo/` HTML。
- 首次打开应用动效只绑定冷启动标记，不绑定 route state。
- TAB 栏 press、select、switch 分开处理；TabRow/NavigationBar 尺寸稳定，active indicator 独立绘制。
- 通用 button、toggle、chip/filter、segment、slider、stepper、input、toast/state、row/card 必须优先落到 Material/Compose 原生控件或本地封装；Discover/RSS/Source/Restore 业务页不能绕过这些 Motion ID 另写特例。
- Slider/stepper/progress 的拖动或连续数值变化中不加 easing；Lazy list/grid 的 row/card motion 必须使用 stable key，避免选择态或视图切换重建整行。
- 下拉栏、popover 和锚定菜单共用 `dropdown.*` 状态机；同层级只允许一个打开，打开新菜单时关闭旧菜单。
- 阅读正文、控制层、模块导航和换源窗口必须是稳定分层。
- 封面进入沉浸阅读要保存 source route 和 reader context；最终 route 是 `immersive-reading`，不是控制层 route。
- 翻页不能绑定到 navigation route；它只是 reader state。
- 动画必须由单一 UI state/reducer 驱动，避免多个 `Animatable` 在打断时各自收尾。
- 控制层小横条拖动使用手势 anchor；拖动中只更新临时 offset，释放后再写入 route/state。
- 宽屏 control dock 拖动只在 fixed-width dock 布局启用；demo 第一版使用 `.fd-reader-grabber` 长按进入 `reader.control.dock.longPress`，移动同一组 bottom sheet + module nav dock，bounds 以当前 Reader pane、window insets、top bar 和 dock group size 计算，不能跨 hinge。
- 自动翻页和朗读共用一个 `activeSession` 状态，不能出现双胶囊；启动会话使用 replace/handoff，不新增 navigation entry。
- 胶囊暂停/继续按钮只更新 `activeSession.playing`，不能打开控制层或写 navigation。
- 控制层打开时需要把 active session 映射到唯一的控制层上方胶囊锚点；不要同时暴露沉浸胶囊和控制层临时状态条。
- 胶囊作为阅读 surface overlay；倒计时更新不触发整颗 capsule 重入场。
- 折叠屏使用窗口尺寸和 posture 状态驱动布局，不能把展开/折叠写成新 route。
- 整屏旋转使用 configuration/window metrics 触发布局重算；不要销毁 Navigation host，不重建 ReaderContext，不把旋转写成 route。
- 旋转后按新 constraints clamp 宽屏 dock offset；offset 建议按 window size class / posture key 分开保存。
- 为状态迁移、semantics 和关键 motion 状态补测试；能做 golden capture 的地方优先保留证据。

iOS SwiftUI：

- 使用 SwiftUI 原生 transition，并遵守 `UIAccessibility.isReduceMotionEnabled`。
- 首次打开应用需要冷启动一次性状态；不要绑在每个 `NavigationStack` 变化上。
- 通用按钮、toggle、segment、slider、list row 和 card 先用 `ButtonStyle`、`ToggleStyle`、`Picker`、`Slider`、`List`/`LazyVStack` 的本地能力承载；业务页只传状态，不定义新的节奏。
- 输入/搜索、toast/state 和文本选择 toolbar 统一使用 `input.*`、`search.state.*`、`feedback/state.*`、`selection.*`，并保留 `NavigationPath` 和 focus 语义。
- 下拉栏、popover 和锚定菜单共用 `dropdown.*` 状态机；使用 geometry anchor 时先测量再显示，避免菜单从错误坐标跳入。
- 控制层显隐时，阅读正文 surface 必须保持挂载。
- 封面 shared element 只作为上下文锚点；不能把封面拉伸成正文纸面。
- 小横条用 `DragGesture` 临时状态，释放后再决定展开或收回。
- 宽屏 dock 长按拖动需要单独的 saved offset，按 size class / viewport class 分开保存；resize 后先 clamp 再绘制，越界使用 `reader.control.dock.rebound`。
- 除非 Shell 契约变更，否则不要把阅读模块面板当作无关导航目的地。
- 异步回调写入 UI 前必须检查当前 route/context，避免打断后旧结果覆盖新页面。
- 折叠屏/大屏根据 size class 和 scene size 重排，不修改 navigation path。
- 整屏旋转只更新 geometry-driven layout；保留 `NavigationPath`、reader progress anchor、active session 和 overlay 语义。
- 旋转后先 clamp saved dock offset，再恢复 `DragGesture` 可用状态；VoiceOver focus 映射到同语义控件。

HarmonyOS ArkUI：

- 使用 ArkUI 原生 transition，并提供与契约命名一致的本地 token adapter。
- 实装时验证 reduced-motion 支持；验证前可在 UI 层提供测试开关。
- 首启动效只由 cold-start state 触发一次。
- Button、Toggle/Checkbox、Slider、Progress、List item、Popup/toast 优先映射 ArkUI 原生组件；业务管理流按通用组件族复用 Motion ID。
- 输入/搜索、状态卡、文本选择层需要同一 token adapter 和 reduced-motion 降级，不在各页面散写时长。
- 下拉栏、popover 和锚定菜单共用 `dropdown.*` 状态机；空间不足时按同语义降级为 sheet/panel。
- 换源保持为阅读平面内联 overlay，不做全局 modal。
- 封面进入阅读在跨屏/hinge 场景下降级为阅读纸面淡入。
- 自动翻页/朗读运行胶囊在 fold/resize 后重新锚定到当前阅读 surface，不跨 hinge 飞行。
- 打断时以最新 state 为准，旧 transition 不排队。
- 折叠/展开只改变布局形态，不新增 router 记录。
- 整屏旋转保留 router、reader progress anchor、active session 和 overlay；按窗口/折叠安全区 clamp 宽屏 dock。

Web demo proof：

- 使用 CSS variables、`data-motion-*` 和测试 query 暴露契约状态，方便浏览器取证。
- 保留 `@media (prefers-reduced-motion: reduce)` 和 `?motionReduced=1/0`，证明降级语义可复现。
- 首启动效、TAB/dropdown、封面进入阅读、控制层、运行胶囊、orientation、interrupt 等高风险链路保留最小可执行 adapter。
- Selector matrix 只追踪 demo 内部 `selector -> Motion ID -> route -> platform component -> evidence`，平台不得把 selector 当 API。
- 宽屏 control dock、orientation、overlay、async result 等 demo adapter 用于证明状态边界；平台仍需补原生 gesture、fold pane、safe area、keyboard inset、accessibility focus 和设备证据。
- dev mode 中保留 route/state 名称，方便平台实现者把视觉证据和契约对应起来。

## 4. 验证矩阵

| 验证项 | Demo route / 点击路径 | 平台所需证据 |
|---|---|---|
| 首次打开应用 | 冷启动默认页/深链页 | 首屏动效只播放一次；后台恢复和 route 切换不重播。 |
| TAB 按钮按下/选中/切换 | 主 TAB、阅读模块 TAB、segmented TAB | press、select、A -> B switch 有不同状态；栏尺寸和按钮坐标不变。 |
| 通用按钮/图标按钮 | 顶栏、行内动作、固定底部动作、危险确认按钮 | pressed、activate、disabled/loading 有统一反馈；按钮尺寸和相邻控件不抖动。 |
| Toggle/Switch/Checkbox | 设置开关、阅读开关、书源/RSS/恢复多选 | press、switch、revert 统一；失败回滚不出现双状态；批量汇总区更新明确。 |
| Chip/Filter/Segment | 书架分组、搜索范围、Discover/RSS/Source/Settings filter 和 segment | chip select、filter apply、segment switch 节奏一致；结果区替换不重放整页 route。 |
| Slider/Progress/Stepper | 阅读亮度/进度、字号/行距步进、restore/import progress | 拖动跟手无 easing；释放后 commit；progress 更新不重建卡片或列表行。 |
| Input/Search | 书籍搜索、RSS 搜索、Source 搜索、Settings 搜索 | focus/blur/clear/submit 与键盘同步；before/loading/results/empty/error 状态替换统一。 |
| Toast/State | 缓存清理、导入/导出、离线/权限、empty/error/success | toast enter/update/exit 统一；状态卡只替换内容 slot；焦点/semantics 正确迁移。 |
| Selection/Row/Card | 阅读文本选择、RSS/Source/Discover row、书架卡片/列表 | 选区手柄跟手；toolbar 锚定；row/card press/select/route 分离；视图切换保留 item identity。 |
| 下拉栏展开/收起/点击 | 阅读设置、朗读设置、设置页选项、发现排序、书源更多、书架更多、书籍焦点菜单 | trigger press、expand、collapse、option press、option select、reposition 统一；同层只留一个 open。 |
| 键盘进入/退出 | 书籍搜索输入 -> 关闭键盘 | 原生键盘或自定义键盘不错误遮挡主导航。 |
| 底表 | 书籍详情 -> 更多/更换书源底表 | 底表从底部进入，关闭后释放 pointer/焦点状态。 |
| 弹窗 | 书籍详情 -> 移除确认 | 弹窗层级高于底表，并有 reduced-motion fallback。 |
| 封面进入沉浸阅读 | 书架封面/继续阅读封面 -> `immersive-reading` | 最终为沉浸阅读态，返回来源页，封面不跨 hinge 拉伸。 |
| 阅读控制层显隐 | `immersive-reading` 正文中部 -> `reader`，再 dismiss | 正文 surface 稳定，控制层只是覆盖。 |
| 控制层小横条 | `reader` / `reader-full-*` 小横条按压、拖动、释放 | 拖动跟手，释放阈值明确；route 只落到一个最终状态。 |
| 宽屏控制层 dock 拖动 | `expanded-width` / `tablet-expanded` / `compact-landscape` 长按小横条 | 固定宽度 dock 可移动；bounds clamp；不跨 hinge；释放吸附；resize 越界回弹。 |
| 阅读模块切换 | 阅读底部导航：目录/朗读/界面/设置 | 模块导航几何不抖动。 |
| 快捷动作展开 | 搜索/自动翻页/替换快捷动作 | 行内 loading 先于 expanded panel，或平台等价状态。 |
| 自动翻页/朗读启动 | 控制层或完整页开启自动翻页/朗读 | route replace 回沉浸阅读；只显示一个运行胶囊；互斥状态正确。 |
| 运行胶囊更新/切换/退出 | 沉浸阅读运行胶囊 | 倒计时、播放/暂停、类型切换不重放整颗入场动画；退出释放点击热区。 |
| 控制层上方胶囊锚点 | 运行胶囊可见时打开/隐藏控制层 | 胶囊与控制层上方锚点有明确空间映射或降级；结束态只有一个主控，控制层子页切换不丢失。 |
| 胶囊暂停/继续按钮 | 自动翻页/朗读胶囊右侧控制按钮 | 按下局部反馈；释放后只切换 playing state；不打开控制层。 |
| 胶囊倒计时数字 | 自动翻页胶囊 countdown tick | 数字局部替换，胶囊容器和页码不抖动。 |
| 胶囊朗读图标 | 朗读胶囊播放/暂停 | 播放时低频活动提示，暂停/reduced motion 静态。 |
| 翻页 | 阅读上一页/下一页控件 | 页码只变一次；不修改 route stack。 |
| 换源窗口 | 阅读顶部换源 | 阅读平面内联窗口，无全屏 blocker。 |
| 打断动画 | overlay 进入中关闭、loading 中返回、连续切模块 | 最终状态唯一，旧动画不排队、不覆盖新状态。 |
| 折叠屏展开 | 手机态到展开态 | ReaderContext、overlay state、返回栈保留；布局重排正确。 |
| 折叠屏折叠 | 展开态到手机态 | 宽布局等价降级，overlay 不丢状态。 |
| 横屏/resize 重排 | compact-landscape / tablet-expanded 断点切换 | 控制层连续，正文重新分页不跳章。 |
| 整屏旋转 prepare/reshape/settle | portrait <-> landscape，普通页面和阅读页 | route、返回栈、active tab、focus、overlay、ReaderContext、active session 保留；旧动画不排队。 |
| 阅读中整屏旋转 | `immersive-reading` / `reader` / `reader-full-*` 旋转 | 正文按进度/字符锚点重新分页；控制层映射到等价容器；模块状态保留。 |
| 运行会话中整屏旋转 | 自动翻页/朗读运行时旋转 | 胶囊或控制层上方锚点重锚定；倒计时/播放态保留；不出现双主控。 |
| 宽屏 dock 旋转 clamp | fixed-width dock 移动后旋转或 resize | saved offset 按新可移动空间 clamp；越界回弹或 reduced-motion 即时落位；不跨 hinge/安全区。 |
| overlay 旋转适配 | 底表/弹窗/换源窗口打开时旋转 | overlay 重新锚定或等价降级；焦点/semantics 不指向隐藏控件。 |
| Reduced motion | 系统开启 reduced motion | 移除位移，保留状态反馈。 |

## 5. Handoff 就绪条件

本映射进入平台实装前需要满足：

- `frontend-demo/MOTION_CONTRACT.md` 已根据 canonical demo 复核。
- `frontend-demo/MOTION_EFFECTS.md` 已补齐每个高风险 Motion ID 的视觉效果描述。
- `frontend-demo/motion-controller.js` 暴露可执行 `ReaderMotionController.CONTRACT`，并能把当前 renderer 使用的 Motion ID 解析到 token、state fields、state machine、平台组件和证据规则；关键 Motion ID 必须命中精确 `from/to/interrupt/finalState/reducedMotion`，不能只用 family fallback。
- Demo CSS 已使用共享 motion token。
- Demo 已实现 reduced-motion 行为。
- Demo 已实现主 TAB、阅读模块 TAB 和 segmented control 的 `data-motion-tab-*` / `data-motion-segment-*` 状态 adapter、`tab.item.press/select/switch` / `segment.item.switch` press-id 和 `reader.module.switch` / `segment.item.switch` 事务；录屏证据仍需补齐。
- Demo 已实现通用组件族第一版 `data-motion-component-*` normalized adapter，覆盖 button、toggle/switch/checkbox、chip/filter/segment、slider/progress/stepper、input/search、feedback/state、selection、listRow/card 和 bookshelf view switch 的 family / role / state / phase / value 字段；平台应映射这些字段到原生组件状态机，不能从 Web CSS 推断控件行为。async pending、focus restore、平台测试文件映射和全族录屏仍需补齐。
- 148 个唯一 `data-*` 交互入口已映射到 `Motion ID -> demo route -> platform component -> evidence` 总表；没有未归类的产品交互入口。
- Demo 已接入统一 `dropdown.*` state adapter，覆盖下拉触发器、菜单和选项的 `data-motion-dropdown-*` 状态、press-id 和 token CSS；打开 A 切 B 已输出 `data-motion-dropdown-switch-from/to/role/sequence` 并触发 `motion.interrupt.redirect`，原生平台应映射为同层级单一 open state 的目标接管；关闭保留动画、reposition 和录屏证据仍需补齐。
- Demo 已接入第一版 `overlay.keyboard/sheet/dialog.*` adapter，覆盖键盘、底表、弹窗和 settings overlay 主体的 `data-motion-overlay-*` role/state/action/focus-return 字段、token 化 enter CSS 和基础焦点恢复；平台应映射到原生 keyboard inset、sheet/dialog focus trap 和 semantics restore，不能只照 Web transition。连续 overlay 打断、遮罩互斥、录屏和平台焦点测试仍需补齐。
- Demo 已接入封面进入沉浸阅读 state adapter，覆盖 `data-motion-entry-*` source/target 状态、封面 snapshot、普通阅读按钮 fallback 和 reduced-motion；详情/章节入口与录屏证据仍需补齐。
- Demo 已接入控制层小横条 state adapter，覆盖 `.fd-reader-grabber` / `.fd-reader-full-grabber` 的 `data-motion-control-handle-*` 状态、press/drag/release、阈值 snap/expand/collapse、full 页收回和 reduced-motion；宽屏 dock 长按移动也已接入 `reader.control.dock.longPress/drag/release/rebound` 第一版 adapter、bounds clamp、viewport-class offset 和 resize rebound；真实设备录屏、折叠屏 hinge/pane、目录 full 页上拉 promote 仍需补齐。
- Demo 已接入运行胶囊 state adapter，覆盖 `reader.session.autoPage.start`、`reader.session.tts.start`、`reader.session.capsule.enter/update/switch/exit`、`reader.session.capsule.control.press/toggle`、`reader.session.capsule.countdownTick` 和 `reader.session.capsule.voiceIcon.active`；平台应映射这些 Motion ID、state 字段和 reducer 事件到原生组件，不能照搬 Web CSS；录屏、停止/退出打断和真实设备证据仍需补齐。
- Demo 已接入 `motion.interrupt.cancel/redirect/completeThenReplace` 第一版 state adapter，覆盖 route push/replace/back、Tab 切换、viewport 变化、loading 完成、宽屏 dock 拖动开始、pointer cancel、连续下拉 A->B 和 reader loading async result guard，输出 `data-motion-interrupt-*` / `data-motion-dropdown-switch-*` / `data-motion-async-*` 并清理 pressed/dragging/dropdown 临时态；overlay/focus 第一版状态字段已接入，连续 overlay 打断和录屏证据仍需补齐。
- Demo 已有整屏旋转第一版 state adapter，覆盖 root / screen host `data-motion-orientation-*`、route/session/overlay/focus/dock 元数据、anchor settle CSS、dropdown 重定位和宽屏 dock clamp；真实旋转录屏、正文字符锚点重分页、overlay/focus 自动化和平台设备证据仍需补齐。
- Demo 已补 `frontend-demo/verify/motion/evidence/manifest.json` 第一批代表性浏览器截图，覆盖首启、Tab、下拉、封面进入、自动翻页胶囊、控制层上方胶囊锚点、orientation 和 interrupt；这些截图只能证明 canonical demo 的代表状态，不等于平台真实设备录屏。
- Demo 仍没有折叠屏/大屏 reshape 的真实设备 capture；展开、折叠、半开态、hinge/pane 和阅读分页映射需要用模拟器或真机补证据。
- 每个高风险阅读 transition 至少有一份截图或录屏证据。
- 平台团队确认 route push 是走原生 stack motion，还是在密集操作页面保持即时切换。

## 6. 平台任务拆分边界

平台实现必须拆成以下 native work items，而不是“照 Web 写 CSS”：

| 任务 | Compose | SwiftUI | ArkUI | 必需平台证据 |
|---|---|---|---|---|
| Contract token adapter | `ReaderMotionTokens` / `AppMotionTokens` | `ReaderMotion.Duration` / `AppMotion.Duration` | `ReaderMotion` token adapter | reduced-motion 开关、token 单测或 snapshot |
| Motion reducer/state | 单一 UI state + `Transition` target | 单一 view model state + `withAnimation` | 单一状态源 + `animateTo` target | 打断后最终状态唯一的测试 |
| 原生导航 | Navigation host / back stack | `NavigationStack` / `NavigationPath` | ArkUI router | route push/back/replace 与 demo Motion ID 对齐 |
| 原生 overlay | `ModalBottomSheet`、dialog、Popup、keyboard inset | `.sheet`、dialog、popover、keyboard safe area | Sheet/dialog/popup/keyboard area | 焦点陷阱、关闭恢复、键盘/安全区证据 |
| Reader 控制层和手势 | Compose gesture + window insets + fold posture | `DragGesture` + safe area + size class | Gesture + window/fold constraints | 小横条、宽屏 dock、bounds clamp 真机/模拟器录屏 |
| 运行胶囊/session | `activeSession` reducer | `activeSession` observable state | `activeSession` state | 自动翻页/TTS 互斥、暂停/继续、后台恢复 |
| orientation/fold | Window metrics / posture | scene size / size class | window/fold state | 旋转、半开态、hinge/pane、正文锚点重分页 |
| accessibility/performance | TalkBack、Macrobenchmark | VoiceOver、Instruments | ArkUI accessibility/perf | 焦点恢复、低端设备帧率、reduced-motion |

## 7. 当前结论

- 设计契约：已具备第一版 Motion ID、token、状态机、reduced-motion 和高风险路径说明。
- Demo 样板：已具备第一版可执行 proof，coverage 通过，代表截图覆盖部分 P0 链路；仍缺全量录屏、连续 overlay、focus restore 自动化、折叠屏和真实设备证据。
- 平台最终实现：未完成。Compose / SwiftUI / ArkUI 需要按本文件拆 native work item，自行完成组件、导航、手势、生命周期、无障碍和性能验证。
