# Frontend Development Slice Matrix

Status: `UI_SLICE_MATRIX_READY`

Date: 2026-07-01

Scope: 只定义 `Reader UI` 交付给平台开发的启动顺序和验收输入；不实现平台代码。

## Slice 0: Platform Project Preflight

| 项 | 内容 |
|---|---|
| 目标 | 确认真实开发发生在目标平台 App 仓库或新建平台工程中 |
| UI 输入 | `README.md`、`FRONTEND_DEVELOPMENT_READINESS.md` |
| 平台输出 | 构建入口、测试命令、路由宿主、状态管理选型、token adapter 文件落点 |
| 不做 | 不从 `frontend-demo/` 复制 HTML/CSS/DOM |
| 验收 | 平台仓库能构建最小 App shell，并声明如何消费 UI handoff |

## Slice 1: AppShell + Main Tabs

| 项 | 内容 |
|---|---|
| 目标 | 建立四主 Tab 原生 shell：书架 / 发现 / RSS / 设置 |
| UI 输入 | `CROSS_PLATFORM_UI_BASELINE.md`、`CROSS_PLATFORM_COMPONENT_MAPPING.md`、`ROUTE_MAP.md`、`SCREEN_MATRIX.md` |
| Motion 输入 | `tab.item.press`、`tab.item.select`、`tab.item.switch`、`app.tab.switch` |
| 平台实现 | 原生 NavigationBar/TabRow/Picker/ArkUI tab，主内容区域独立 transition |
| 不做 | 不把搜索、阅读、书源管理放成主 Tab；不把 tab switch 写成 route push |
| 验收 | 主 Tab 数量、顺序、点击热区稳定；切换后 back stack 语义正确；reduced-motion 下无位移 |

## Slice 2: Bookshelf to Immersive Reading

| 项 | 内容 |
|---|---|
| 目标 | 书架封面或继续阅读入口进入 `immersive-reading`，返回来源页 |
| UI 输入 | `frontend-demo/README.md` 的 Reading Flow、`route-contract.js` 的 `bookshelf` / `immersive-reading` / `reader` |
| Motion 输入 | `reader.entry.coverToImmersive`、`reader.entry.actionToImmersive`、`app.route.push`、`app.route.pop` |
| 平台实现 | 原生 route/back stack、ReaderContext、阅读正文 surface、封面 source fallback |
| 不做 | 不自动显示阅读控制层；不把封面强行 morph 成正文；不跨 hinge 做封面飞行 |
| 验收 | 最终状态是沉浸阅读；返回到来源页；连续点击只保留最后目标；reduced-motion 即时进入 |

## Slice 3: Reader Control Layer Minimum

| 项 | 内容 |
|---|---|
| 目标 | 沉浸阅读正文中部点击打开控制层，再隐藏回沉浸阅读 |
| UI 输入 | `MOTION_EFFECTS.md` 的 `reader.control.show/hide`、`SCREEN_MATRIX.md` 中阅读控制层条目 |
| Motion 输入 | `reader.control.show`、`reader.control.hide`、`reader.module.switch` |
| 平台实现 | 正文 surface 保持挂载；顶栏、底部控制层、模块导航作为 overlay |
| 不做 | 不改变正文排版、透明度、分页结果；不把 Reader 模块做成无关全屏页面 |
| 验收 | 控制层打开/隐藏前后 ReaderContext 不丢；正文不重排；模块按钮几何稳定 |

## Slice 4: Overlay and Focus Foundation

| 项 | 内容 |
|---|---|
| 目标 | 键盘、底表、弹窗、焦点恢复和 system back 的原生基础能力 |
| UI 输入 | `MOTION_CONTRACT.md` overlay IDs、`MOTION_EFFECTS.md` 覆盖层动效、`STATE_MATRIX.md` |
| Motion 输入 | `overlay.keyboard.enter/exit`、`overlay.sheet.enter/exit`、`overlay.dialog.enter/exit`、`motion.interrupt.cancel/redirect` |
| 平台实现 | 原生 keyboard inset、sheet/dialog/popover、focus trap、semantics restore |
| 不做 | 不用全屏 blocker 伪装所有 overlay；不让 hidden overlay 保留 hit area |
| 验收 | overlay 进入中可关闭；返回后最终状态唯一；焦点回到触发器或最新目标 |

## Slice 5: Session Capsule Minimum

| 项 | 内容 |
|---|---|
| 目标 | 自动翻页或朗读先做一个运行会话闭环，再扩展另一个 |
| UI 输入 | `MOTION_CONTRACT.md`、`MOTION_EFFECTS.md`、`MOTION_PLATFORM_MAPPING.md` 中 session/capsule 章节 |
| Motion 输入 | `reader.session.autoPage.start` 或 `reader.session.tts.start`、`reader.session.capsule.enter/update/exit`、`reader.session.capsule.control.press/toggle` |
| 平台实现 | `activeSession` reducer、唯一运行胶囊、暂停/继续、退出、互斥切换 |
| 不做 | 不出现双胶囊；不把控制层留成返回栈上一层；不让胶囊按钮打开控制层 |
| 验收 | 启动后 replace 回沉浸阅读；暂停/继续只更新 session state；退出释放 hit area |

## Slice 6: Orientation and Fold Proof

| 项 | 内容 |
|---|---|
| 目标 | 先覆盖普通 orientation/resize，再扩展 fold/hinge/posture |
| UI 输入 | `MOTION_CONTRACT.md` viewport IDs、`MOTION_EFFECTS.md` orientation/fold 章节、`MOTION_PLATFORM_MAPPING.md` 验证矩阵 |
| Motion 输入 | `viewport.orientation.prepare`、`viewport.orientation.reshape`、`viewport.orientation.settle`、`viewport.fold.expand/collapse` |
| 平台实现 | window metrics、size class、safe area、fold posture、正文锚点重分页、dock clamp |
| 不做 | 不把旋转写成 route；不销毁 Navigation host；不只按旧 page index 映射正文 |
| 验收 | route/back stack/ReaderContext/session/overlay/focus 保留；正文不跳章；fold pane 不跨 hinge |

## Deferred Full-Scale Work

这些工作必须等 Slice 1-5 的原生闭环通过后再展开：

- 131 routes 全量迁移。
- Discover/RSS/Source/Settings 全业务状态全量接入。
- 全 Motion ID 一次性实现。
- 全平台折叠屏、大屏、多窗口、无障碍和性能矩阵。
- 复杂文本选择、批量管理、远端同步冲突、真实网络错误全量覆盖。
