# 前端 Demo 动效效果说明初稿

状态：Draft v0.1

依赖文档：

- `MOTION_CONTRACT.md`：定义 motion token、Motion ID、Reader 约束和验收边界。
- `docs/ui-handoff/MOTION_PLATFORM_MAPPING.md`：定义平台实现映射。

本文档补齐“动画效果本身”。如果只看 `MOTION_CONTRACT.md`，只能得到状态契约，不能形成完整动效规划；完整规划必须同时包含本文件里的视觉效果描述、时间线、层级和验收方式。

边界说明：

- 本文件描述的是可感知效果和验收语义，不要求平台逐帧复制 Web CSS、DOM 层级或 easing 函数名。
- `frontend-demo/` 中的位移、透明度、scale、截图和 `data-motion-*` 字段只用于证明 Motion ID 的状态流、打断结果和 reduced-motion 降级。
- 平台最终实现必须按 Compose / SwiftUI / ArkUI 的原生组件、导航、手势、安全区、键盘、fold posture 和无障碍焦点重新落地。
- Demo proof 可以证明“设计契约已具备”和“关键样板可复现”，不能证明真实设备性能、折叠屏、后台恢复、系统键盘或平台导航栈已经完成。

## 1. 总体动效语言

Reader UI 的动效目标不是炫技，而是让阅读和管理操作更容易理解：

- 操作型页面要安静、短促、可预测。导航和列表不做夸张弹性。
- 阅读器页面以正文稳定为最高优先级。控制层可以动，正文排版不能被装饰动画打扰。
- 覆盖层从它所在的物理方向进入：键盘/底表从底部，弹窗从中心，换源窗口从阅读平面内轻浮现。
- 状态变化优先使用颜色、透明度、阴影和小位移；避免大幅位移和连续弹跳。
- 所有动效都必须有 reduced-motion 版本。

推荐基础节奏：

| 层级 | 典型时长 | 视觉感受 |
|---|---:|---|
| 按压/选中 | `80ms` 到 `120ms` | 立即响应，不抢视线。 |
| 普通覆盖层 | `160ms` | 能看清来源方向，但不拖慢操作。 |
| 阅读面板 | `200ms` | 稍慢于普通控件，让面板关系更清楚。 |
| 阅读翻页 | `220ms` | 有方向感，但不是拟物翻页。 |
| 进入沉浸阅读 | `240ms` | 从书籍上下文平顺进入阅读纸面。 |
| 弹窗/复杂 overlay | `200ms` 到 `240ms` | 背景和主体错开一点，层级更明确。 |
| 首次打开应用 | `280ms` | 冷启动首屏落位，不阻塞用户。 |
| 打断收尾 | `80ms` | 新操作优先，旧动画快速让位。 |
| 折叠屏重排 | `240ms` | 看清布局变化，但不拖慢阅读。 |

### `app.launch.firstOpen`

使用场景：应用冷启动后首次显示书架或深链目标页。

效果时间线：

1. `0ms`：显示应用背景色和最终 Shell 容器，不插入额外全屏广告式 splash。
2. `0ms -> 120ms`：首屏主内容 opacity `0 -> 1`，从下方 `8px` 到原位。
3. `40ms -> 200ms`：顶部栏和底部主导航淡入；导航尺寸、位置和点击热区从一开始就是最终值。
4. `200ms -> 280ms`：列表封面、继续阅读横条或深链目标内容完成落位，不逐项大幅 stagger。

深链规则：

- 如果冷启动直接进入 `immersive-reading`，按 `app.launch.firstOpen` 先建立 Shell，再接 `reader.entry.actionToImmersive` 的阅读纸面淡入降级。
- 如果冷启动直接进入二级页面，首屏只做一次整体淡入，不额外叠加 `app.route.push`。
- 后台恢复、切 Tab、普通返回和 route replace 都不能重复播放首启动效。

Reduced motion：

- 首屏即时显示，最多保留 `80ms` opacity fade。
- 不做位移、不做列表逐项出现。

## 2. 动画打断与接管

完整动效规划必须定义打断规则。否则连续点击、返回、关闭、拖动或异步 loading 完成时，各平台会各自处理，最终表现会不一致。

### 总原则

1. 最新用户意图优先。返回、关闭、拖动、切 Tab、切 route 的优先级高于正在播放的装饰动画。
2. 打断时不回放旧动画，不倒放到旧起点；从当前视觉状态直接接管到新目标。
3. 如果动画只负责装饰，允许立即取消。
4. 如果动画承载状态确认，例如危险弹窗关闭、loading 完成、章节跳转，需要在 `80ms` 内完成必要收尾。
5. 打断后只能存在一个最终状态：route stack、overlay open state、ReaderContext、focus 和 pointer 状态必须一致。

### `motion.interrupt.cancel`

使用场景：动画播放中触发返回、关闭 overlay、切主 Tab、切 route、开始拖动亮度/进度。

效果描述：

1. 正在播放的位移/透明度动画立即停止。
2. 目标状态直接切到最新操作对应的状态。
3. 可用 `80ms` 淡出残留 overlay，避免视觉瞬移。
4. 清理旧动画的 pointer、focus、aria-hidden 和 active 状态。

例子：

- 底表滑入到一半时点击关闭：底表从当前视觉位置向下退出，不先滑到完全展开。
- 阅读控制层显示中点击正文隐藏：顶栏/底栏从当前透明度和当前位置直接淡出。
- 翻页动画播放中拖动章节进度：翻页动画取消，正文直接切到拖动后的页码。

禁用项：

- 不排队播放旧动画。
- 不让旧 overlay 继续保留 pointer 命中区。
- 不为了完成装饰动画而延迟返回/关闭。

### `motion.interrupt.redirect`

使用场景：一个面板进入中，用户立刻切到另一个面板；或者一个 overlay 未完全关闭时打开另一个 overlay。

效果描述：

1. 当前动画停在当前视觉状态。
2. 新目标从当前视觉状态接管，过渡到新面板/新 overlay。
3. 面板内容可以交叉淡出/淡入，容器位置和层级不重复创建。
4. 总时长不超过新动画的正常时长；不叠加两个完整动画时长。

例子：

- 阅读模块从“目录”切到“朗读”又切到“界面”：模块导航不动，面板内容持续交叉淡入淡出，不出现空白闪烁。
- 打开底表未完成时触发弹窗：底表停止在当前状态并被收起或降级，弹窗按最高层级进入。

### `motion.interrupt.completeThenReplace`

使用场景：loading 中数据到达、快速动作触发完整页、异步检测结果返回。

效果描述：

1. 如果 loading 已显示不足 `160ms`，至少保持到 `160ms`，避免闪烁。
2. 如果用户主动返回/关闭，则不等待 loading，直接取消。
3. 数据到达后，loading 在 `80ms` 内淡出，新内容淡入或展开。
4. 新内容必须继承当前 route/ReaderContext，不重新初始化阅读状态。

### 打断优先级

| 优先级 | 操作 | 处理方式 |
|---:|---|---|
| 1 | 系统返回、关闭窗口、切后台、折叠屏尺寸变化 | 取消装饰动画，保存最新状态。 |
| 2 | 用户返回、关闭 overlay、切 Tab | 取消或重定向当前动画。 |
| 3 | 拖动亮度/进度/滚动列表 | 取消与手势冲突的动画，控件跟手。 |
| 4 | 切阅读模块、切快捷面板 | 重定向当前面板动画。 |
| 5 | loading 完成、数据返回 | 完成最短收尾后替换。 |

验收：

- 连续快速点击不会出现两个 overlay 同时可点。
- 返回后 route stack 与视觉页面一致。
- loading 完成和用户返回同时发生时，以用户返回为准。
- 拖动过程中没有 easing 滞后。

## 3. 折叠屏展开/折叠动效

折叠屏和大屏不是简单横屏。动效规划要覆盖宽度变化、hinge/折痕区域、半开态、窗口 resize 和阅读正文重新分页。

### 形态定义

| 形态 | 判断方式 | 布局目标 |
|---|---|---|
| 手机态 | 单屏窄宽度，或折叠屏合上 | 单列 app shell，底部主导航，Reader 控制层贴底。 |
| 半展开态 | 宽度增加但高度受限，可能有 hinge/半开角度 | 保持单列优先，必要时压缩控制层高度。 |
| 展开态 | tablet-expanded / foldable open | 可进入双栏、宽内容区或阅读控制窗口化布局。 |
| 横屏紧凑态 | `compact-landscape` | 优先保留一个连续控制平面，压缩面板而不是拆成多个浮块。 |

### `viewport.fold.expand`

使用场景：设备从折叠手机态展开到大屏/平板态。

效果时间线：

1. `0ms`：冻结当前交互语义，记录当前 route、ReaderContext、overlay state、scroll position 和 focus。
2. `0ms -> 80ms`：暂停正在播放的非必要动画；正在拖动的控件立即结束或转为最新值。
3. `80ms -> 240ms`：Shell 容器从单列重排到展开态布局。主导航、顶栏和 Reader 控制层使用 opacity/position 小幅过渡。
4. `240ms` 后：阅读正文按新宽高重新测量分页，页码映射到最接近原阅读进度的位置。
5. overlay 重新锚定到新布局中的同一语义区域。

视觉效果：

- 内容不是简单整体缩放，而是重排。
- 主导航从底部形态过渡到大屏目标形态时，选中态保留。
- Reader 控制面板保持一个连续面，不拆裂成多个孤立浮层。
- 换源窗口从手机态位置重新锚定到阅读可用区，不做全屏遮罩。

禁用项：

- 不把展开当成新 route push。
- 不丢失当前阅读章节、页内进度、主题、亮度和打开的 reader module。
- 不让旧手机态 overlay 停留在错误坐标。

### `viewport.fold.collapse`

使用场景：设备从展开态折叠回手机态。

效果时间线：

1. `0ms`：记录展开态当前 route、overlay、ReaderContext 和滚动位置。
2. `0ms -> 80ms`：取消宽布局中不再适用的装饰动画。
3. `80ms -> 240ms`：双栏/宽布局收回单列；优先保留用户正在操作的主内容。
4. `240ms` 后：阅读正文重新分页，页码映射到相同章节进度附近。
5. 如果原本打开的 overlay 在手机态空间不足，降级为同语义的底表或全高面板，但不能丢状态。

视觉效果：

- 宽布局辅助栏可以淡出或收回到当前 Shell。
- 当前主任务区域保持视觉连续。
- 阅读控制层回到底部连续控制层。

禁用项：

- 不在折叠时关闭用户打开的阅读模块，除非空间不足且有等价降级容器。
- 不让返回栈新增“折叠/展开”记录。
- 不重新进入加载态，除非确实需要重新取数。

### `viewport.orientation.reshape`

使用场景：整屏横竖屏切换、窗口 resize、`visualViewport` resize、`tablet-expanded` 和 `compact-landscape` 断点切换。

这组动效分为三段：`viewport.orientation.prepare`、`viewport.orientation.reshape`、`viewport.orientation.settle`。旋转不是 route transition，不进入 loading，不新增返回栈，也不重播首次打开应用动效。

#### `viewport.orientation.prepare`

触发：检测到 `orientation`、`viewportClass`、window metrics 或 `visualViewport` 即将变化。

效果描述：

1. `0ms`：记录当前 active tab、route stack、ReaderContext、章节/进度锚点、当前阅读模块、active session、overlay 类型、focus owner、宽屏 dock offset 和可见胶囊类型。
2. `0ms -> 80ms`：取消非必要动画，包括翻页装饰、控制层进入/退出、运行胶囊 pulse、TAB pressed、胶囊按钮 pressed、底表/弹窗进入和小横条拖动。
3. 如果用户正在拖动控制层小横条或宽屏 dock，释放 pointer capture，把拖动提交到最近安全状态；不要把半拖动 offset 带入旋转后的布局。
4. 阅读正文不淡出、不缩放；只冻结旧布局测量值，等待新尺寸下重新分页。

#### `viewport.orientation.reshape`

效果描述：

1. `80ms -> 240ms`：App Shell 和当前 route 容器切到新的 viewport class；普通页面可用 `240ms ease-in-out` 做容器重排，列表项不逐项飞入。
2. 主 TAB 栏、阅读模块 TAB 和 segmented TAB 保持 active 状态；位置从底部、侧边或紧凑布局互相映射时，只移动栏容器，不重建按钮。
3. 阅读正文按章节进度或字符锚点重新测量分页；正文可以即时替换到新排版，避免 opacity fade 造成闪烁或读者丢失阅读位置。
4. 阅读控制层按新 viewport class 映射：
   - portrait：底部连续控制层。
   - compact landscape：压缩高度，保持控制层和模块导航在一个连续平面内。
   - tablet-expanded / expanded-width：fixed-width dock，宽度不随屏幕继续拉伸。
5. 如果控制层已打开，旋转后保持打开，并重新锚定到等价容器；不因为旋转回到沉浸阅读。
6. 如果沉浸阅读中有自动翻页/朗读胶囊，胶囊保持会话类型和播放态，重新锚定到新阅读 surface 的状态区域；不能跨 hinge 飞行。
7. 如果控制层打开且存在运行会话，控制层运行中空间保持唯一主控；旋转中不同时显示沉浸胶囊和运行空间两套主控制。
8. overlay 以同语义容器映射：键盘跟随系统，底表/弹窗/换源窗口重新计算锚点；空间不足时降级为底表或全高面板，但保留状态和焦点语义。
9. 宽屏 fixed dock 的保存 offset 按新的可移动空间 clamp；如果越界，先落到最近合法点，再用 `reader.control.dock.rebound` 做 `120ms` 回弹。

#### `viewport.orientation.settle`

效果描述：

1. 布局稳定后恢复 focus、pointer hit area、aria/semantics 可见性和当前可操作层。
2. 自动翻页倒计时继续从当前剩余值更新；朗读图标只在播放态恢复低频 pulse。
3. 清理旋转临时状态，允许新的 TAB press、overlay enter、控制层拖动和翻页动画。
4. 如果旋转期间又发生第二次 resize，取消当前 settle，重新从最新 viewport 计算 `prepare -> reshape -> settle`，不排队播放多段动画。

可移动空间约束：

1. fixed-width dock 的可移动空间是当前 ReaderFrame 或当前 fold pane，扣除 safe area、顶栏、底部系统区域和 `controlDragMargin`。
2. dock group 包括底部控制面板、当前模块/快捷面板和模块导航；旋转时这组对象整体重新 clamp，不拆开映射。
3. offset 按 viewport class 保存。portrait、compact-landscape、tablet-expanded、expanded-width 互相切换时可以分别记忆；当前 class 没有合法历史 offset 时使用默认锚点。
4. 旋转后如果面板尺寸大于可移动空间，禁用自由拖动，回到当前 viewport 的默认 dock 位置。

禁用项：

- 不做整屏 spin/rotate transform，不把旧屏幕截图旋转成新布局。
- 不把旋转写成 `app.route.push`、`app.route.pop` 或新的 loading 态。
- 不重播 `app.launch.firstOpen`、封面进入沉浸阅读或控制层首次入场。
- 不在旋转时关闭 active session、丢失运行胶囊、重置自动翻页倒计时或暂停朗读。
- 不让旧 overlay 坐标残留在新布局中。

Reduced motion：

- 正文和容器即时重排。
- overlay、控制层和胶囊最多 `80ms` opacity 淡换。
- 不做 dock 回弹位移动画；直接落到合法位置。

验收：

- 横竖屏切换后 route、返回栈、active tab、当前选中模块、ReaderContext 和 active session 不变。
- 阅读进度映射误差应控制在同一章节内的邻近页，不跳章。
- overlay 锚点更新到新布局，不保留旧坐标。
- 控制层打开时旋转，旋转后仍打开并映射到新 viewport class 的等价容器。
- 沉浸阅读运行胶囊可见时旋转，旋转后胶囊仍在新阅读 surface 的合法锚点。
- 宽屏 fixed dock 有保存 offset 时旋转，旋转后 offset 被 clamp 到可移动空间内；越界时有一次明确回弹或 reduced-motion 即时落位。
- 连续旋转/resize 不会排队播放多段 reshape 动画。

## 4. App Shell 与路由动效

### `tab.item.press` / `select` / `switch`

使用场景：同一个 TAB 栏内的按钮状态变化，包括主导航 `书架/发现/RSS/设置`、阅读模块导航 `目录/朗读/界面/设置`，以及设置/书源里的 segmented tab。

按钮按下 `tab.item.press`：

1. `0ms -> 80ms`：被按下按钮的内部 icon 或选中背景透明度轻微变化；可以让 icon scale 到 `0.96`，但按钮外框、点击热区和相邻按钮坐标不变。
2. 手指/指针移出热区时，在 `80ms` 内取消 pressed 态，不切换 active。
3. 如果点击的是当前 active 且该 TAB 支持重复点击动作，先播放 pressed，再执行该场景定义的动作；不触发 A -> B switch。

单按钮选中 `tab.item.select`：

1. `0ms -> 120ms`：新 active 按钮的图标色、文字色和背景/indicator opacity 进入选中态。
2. 文案不改变字重到导致宽度变化；如需强调，只改颜色、背景或固定尺寸 indicator。
3. 用于初始选中、从无选中态进入选中态，或同一栏首次渲染后的 active 标记。

按钮间切换 `tab.item.switch`：

1. `0ms -> 80ms`：旧 active 按钮退出选中态，颜色和背景淡出。
2. `40ms -> 160ms`：新 active 按钮进入选中态。
3. 如果有独立选中背景/indicator，可以在同一 TAB 栏内部从旧按钮锚点移动到新按钮锚点，时长 `160ms`；如果没有独立层，则旧/新选中背景交叉淡换。
4. 内容区切换是另一个层级：主 TAB 内容可以 `80ms -> 120ms` 淡换；阅读模块面板按 `reader.module.switch` 进入。不让内容切换反向推动 TAB 栏。

重复点击当前 active：

- 主 TAB：保持当前页面；只允许 pressed 反馈，不重复刷新或重播页面入场，除非后续产品定义“回到顶部”。
- 阅读模块 TAB：按现有契约执行 `reader.module.dismiss`，即关闭当前模块面板回默认阅读控制层。
- Segmented TAB：保持当前选中值；只允许 pressed 反馈。

禁用项：

- 不让 active 按钮变宽、变高或把相邻按钮挤开。
- 不重建整条 TAB 栏。
- 不把 A -> B 切换写成 route push 动效。

### `dropdown.trigger.press` / `menu.expand` / `menu.collapse` / `option.press` / `option.select`

使用场景：所有锚定在按钮、设置行或工具栏项上的下拉栏、popover 和菜单，包括：

- 阅读设置 `.fd-reader-setting-dropdown`。
- 朗读设置 `.fd-reader-tts-dropdown`。
- 设置页选项 `.fd-settings-option-dropdown`。
- 发现排序 `.fd-discover-sort-popover`。
- 书源更多 `.fd-source-more-menu`。
- 书架更多 `.fd-bookshelf-more-menu`。
- 书籍焦点操作 `.fd-book-focus-menu`。

不包括：底表、全屏弹窗、确认弹窗和系统键盘；这些继续走 `overlay.sheet.*`、`overlay.dialog.*` 或系统动画。

触发器按下 `dropdown.trigger.press`：

1. `0ms -> 80ms`：触发器内部背景、图标或 chevron 做 pressed 反馈；行高、按钮宽度、列表布局不变化。
2. 如果触发器有 chevron，展开时 chevron 进入 open 状态，关闭时回到 closed；旋转本身不是选项选中动画。
3. 指针移出或取消时，在 `80ms` 内取消 pressed，不展开菜单。

展开 `dropdown.menu.expand`：

1. 展开前先完成 placement 测量：锚点、drop-down/drop-up、最大高度、safe area、键盘遮挡、fold pane 和当前 panel bounds。
2. `0ms -> 160ms`：菜单从锚点方向淡入，opacity `0 -> 1`，位移不超过 `6px`；drop-down 从上缘向下落位，drop-up 从下缘向上落位。
3. 菜单容器可以轻微 scale `0.98 -> 1`，但不能让文本模糊，也不能改变选项行高度。
4. 列表项不做级联飞入；最多允许选中项 check/icon 在 `120ms` 内淡入。
5. 展开后把焦点/semantics 移到菜单内第一个可操作项或当前选中项；触发器保留 `aria-expanded=true`。

收起 `dropdown.menu.collapse`：

1. 再次点击触发器、点击外部、返回、切 route、打开同层级另一个下拉、选择单选项、overlay 互斥或 orientation/resize 判定需要降级时触发。
2. `0ms -> 120ms`：从当前视觉状态淡出并反向轻位移；不要先跳回展开完成位置。
3. 收起后释放菜单点击热区，触发器 `aria-expanded=false`，焦点回到触发器或最新目标控件。
4. 如果是返回/切 route 打断，允许直接清理菜单，不排队播放完整退出动画。

选项按下 `dropdown.option.press`：

1. 只作用于当前选项行，使用 `80ms` 背景/透明度反馈。
2. 不改变菜单宽度、高度、滚动位置或相邻选项坐标。
3. 指针取消时撤销 pressed，不更新值。

选项确认 `dropdown.option.select`：

1. `0ms -> 120ms`：当前选中态、check/icon、文字色或背景更新；原选中项退出，新选中项进入。
2. 单选下拉：值更新后菜单收起，触发器文案/当前值同步替换；不重建整页 route。
3. 多选菜单：按产品语义决定是否保持打开；若保持打开，只更新当前选项和汇总值，不重放菜单展开。
4. 选中结果必须同步 `aria-selected`、`aria-pressed` 或平台 semantics。

打开 A 后切到 B：

1. 同层级只允许一个下拉打开。点击 B 时，A 走 `dropdown.menu.collapse` 或被 `motion.interrupt.redirect` 接管到 B 的展开。
2. B 的 placement 按最新布局重新测量，不能复用 A 的坐标。
3. 如果 A/B 在同一个设置列表中，列表滚动位置保持稳定，不因为菜单关闭/打开跳动。

重定位 `dropdown.menu.reposition`：

1. open 状态下发生 scroll、keyboard、resize、fold、orientation 或控制层容器变化时，重新计算锚点和最大高度。
2. 空间不足时优先 drop-up；仍不足时限制最大高度并允许菜单内部滚动。
3. 如果当前锚点被键盘、控制层、hinge 或安全区遮挡，降级到底表/全高选择器，但选中值和焦点语义不丢。
4. 重定位不新增 route，不关闭当前页面，不让旧坐标残留。

禁用项：

- 不用整页遮罩伪装下拉，除非已经降级到底表/全高选择器。
- 不让菜单展开推挤设置行、书架列表、阅读正文或控制层高度。
- 不让不同下拉拥有不同速度、不同 chevron 方向或不同选项 pressed 节奏。
- 不在选择单选项后先关闭再重新打开同一菜单。

Reduced motion：

- 菜单即时挂载或最多 `80ms` 淡入淡出。
- 不做位移、scale、chevron rotation 或列表项级联。
- pressed/selected 仅保留颜色、背景、check/icon 状态变化。

验收：

- 每一种下拉都能复现 trigger press、expand、collapse、option press、option select。
- 打开 A 再打开 B 时只有一个菜单可见，旧菜单不会悬挂在旧坐标。
- 选择单选项后值更新、菜单关闭、焦点回到触发器或最新目标。
- resize/orientation/键盘遮挡时，open 菜单重新锚定或明确降级，不被裁切到不可操作。
- reduced-motion 下状态仍可辨认。

### 通用交互组件族

使用场景：除 Reader 专属正文、控制层和 overlay 之外的通用控件，包括 button、toggle、chip/filter、segment、slider、progress、stepper、input/search、toast/state、selection、list row、card、bookshelf view switch。

这些组件不按业务页面定义动效。Discover、RSS、Source、Restore、Settings、Library 中的同类控件必须复用同一组 motion family。

#### `button.press` / `button.activate` / `button.disabledBlocked`

1. `button.press`：`0ms -> 80ms`，当前按钮内部背景、icon opacity 或 scale `1 -> 0.98`。按钮外框、宽高和相邻控件坐标不变。
2. `button.activate`：释放确认后 `0ms -> 120ms` 更新命令状态。图标按钮只替换 icon 或颜色；文字按钮只替换文案/状态，不重建整行。
3. `button.disabledBlocked`：禁用按钮不执行命令；可保留无反馈，或用 `80ms` 的弱透明度/outline 提示 blocked，不出现 pressed 完成态。
4. 主按钮、危险按钮、图标按钮、行内按钮节奏一致；差异只体现在颜色和语义，不体现在时长。

#### `toggle.press` / `toggle.switch` / `toggle.revert`

1. `toggle.press`：`0ms -> 80ms`，当前 switch/toggle/checkbox 局部 pressed。
2. `toggle.switch`：`0ms -> 140ms`，thumb、check、背景、文字状态和 `aria-pressed` / semantics 同步变化。
3. 如果状态需要异步确认，可先乐观切换；失败时使用 `toggle.revert` 在 `120ms` 内回到真实值，并显示 inline feedback 或 toast。
4. 所在 row 不重排，row 高度、右侧 value 区和点击热区保持稳定。

#### `chip.item.press` / `chip.item.select` / `filter.item.toggle` / `filter.apply.commit` / `segment.item.switch`

1. chip/filter 按下只影响当前项，`80ms` 内给出 pressed。
2. 单选 chip 或 segment 使用 `chip.item.select` / `segment.item.switch`：旧 active `0ms -> 80ms` 退出，新 active `40ms -> 120ms` 进入。
3. 多选筛选使用 `filter.item.toggle`：只更新当前筛选项和汇总状态，结果列表不立即替换，除非该筛选定义为即时生效。
4. “应用/重置”使用 `filter.apply.commit`：控件状态提交后，结果区按 `state.content.replace` 或 `search.state.replace` 更新。
5. 横向 chip row 不因 active 文案、字重或 indicator 改变滚动位置。

#### `slider.drag.*` / `slider.value.commit` / `stepper.*` / `progress.meter.update`

1. `slider.drag.start`：拖动开始立即取消与该值冲突的动画，例如翻页、阅读正文装饰动画或结果区淡换。
2. `slider.drag.update`：拖动中 track fill、thumb、readout 跟手更新，不使用 easing，不滞后手指。
3. `slider.drag.release`：释放后 snap 到合法范围或刻度，随后执行 `slider.value.commit`。
4. `stepper.press`：+/- 按钮 `80ms` pressed；禁用态不变化。
5. `stepper.repeat`：长按连续变化时，以固定节奏提交值，readout 固定宽度不抖动。
6. `progress.meter.update`：恢复、导入、下载、缓存等进度 fill 可用 `120ms` 到新值；后台恢复或大跨度变化可直接跳到最新进度。

#### `input.focus` / `input.blur` / `input.clear` / `input.submit` / `search.state.replace`

1. `input.focus`：`0ms -> 120ms`，输入框 focus ring、光标、辅助文案进入；需要键盘时联动 `overlay.keyboard.enter`。
2. `input.blur`：释放 focus ring 和键盘状态，输入值保留。
3. `input.clear`：清空文本后，结果区回到 before/empty，不重置 route stack。
4. `input.submit`：按钮局部确认反馈后，结果区进入 loading/results；输入栏、筛选栏和导航保持稳定。
5. `search.state.replace`：before、loading、results、empty、error 之间 `160ms` 短淡换；结果行不逐项飞入。

#### `feedback.toast.*` / `state.*`

1. `feedback.toast.enter`：toast 从当前 host 轻位移 `8px` + fade 进入，时长 `180ms`，不阻塞页面操作。
2. `feedback.toast.update`：同一 toast 容器内文案/类型交叉替换，不排队堆叠多个短 toast。
3. `feedback.toast.exit`：超时、route 切换、被新 feedback 替换时 fade 退出并释放命中区。
4. `state.content.replace`：结果区、列表区、面板内容稳定，内部状态短淡换。
5. `state.empty/error/success.enter`：状态卡进入当前容器，不替换顶栏、主导航、筛选栏或 ReaderContext。

#### `selection.range.*` / `selection.toolbar.*`

1. `selection.range.show`：选区高亮、手柄和 toolbar 以选区锚点出现；正文排版不变化。
2. `selection.range.drag`：手柄拖动时选区范围和 toolbar 锚点跟手更新，不使用 easing。
3. `selection.range.release`：释放后 toolbar 重新锚定到选区可见范围内。
4. `selection.toolbar.enter`：toolbar fade + 小位移进入，不居中弹出。
5. `selection.toolbar.action`：复制、划线、笔记、搜索等按钮只做局部反馈；操作完成后按语义关闭或保持。
6. 打开 reader control、dropdown、dialog、切 route 时，selection toolbar 必须退出并释放 pointer/focus。

#### `listRow.*` / `card.*` / `bookshelf.view.switch`

1. `listRow.press` / `card.press`：当前 row/card 局部 pressed；不改变列表行高、卡片尺寸、封面比例或滚动位置。
2. `listRow.select` / `card.select`：选择型 row/card 更新 check、背景、badge 或 focus ring；批量汇总区可用 `feedback.toast.update` 或 `state.content.replace` 更新。
3. `listRow.route` / `card.route`：导航型 row/card 在 pressed 后进入目标 route；书籍封面阅读入口优先走 `reader.entry.coverToImmersive`。
4. `bookshelf.view.switch`：封面/列表视图切换时，保留分组、筛选、滚动意图和选中语义；容器短淡换，不逐本书飞入。

通用禁用项：

- 不让 active/selected 字重改变导致按钮、chip、row 或 card 重新排版。
- 不把轻反馈做成全屏 dialog、route push 或 bottom sheet。
- 不让业务页面覆盖通用时长，除非有明确平台原生系统动画。
- 不让异步失败后 UI 停在乐观状态。

通用 reduced-motion：

- 按压、选中、toggle、chip、row/card 只保留颜色、背景、outline、check/icon 状态。
- slider/progress/stepper 数值即时更新，不做 thumb snap、fill tween 或 readout 位移。
- toast/state/search/selection toolbar 最多保留 `80ms` fade。

通用验收：

- 同一控件族在 Library、Discover、RSS、Settings、Source、Restore 中节奏一致。
- 同一控件的按下、取消、确认、禁用、异步失败状态可区分。
- 触发 route、替换结果、更新 toast 或打开 overlay 时，最终状态唯一，不留下 pressed 或 selected 残留。

### `app.tab.switch`

使用场景：书架、发现、RSS、设置主 Tab 切换。

效果描述：

1. 底部主导航始终固定在原位，不移动、不缩放、不改变高度。
2. 按下目标按钮时先执行 `tab.item.press`。
3. 如果目标不是当前 active，执行 `tab.item.switch`。
4. 内容区可以做 `80ms` 到 `120ms` 的淡出/淡入，但不做左右滑动。

禁用项：

- 不做主导航整体滑动。
- 不让选中项尺寸变大导致相邻按钮位移。
- 不做弹性 overshoot。

验收：

- 主导航四个按钮在切换前后坐标一致。
- 内容区切换时底部导航不抖动。

### `app.route.push` / `app.route.pop`

使用场景：书架进入搜索、书籍详情、设置二级页、书源管理等。

效果描述：

1. 同一 Shell 内的详情页进入时，新内容从右侧 `16px` 到 `0`，透明度 `0 -> 1`，时长 `160ms`。
2. 返回时方向相反，当前内容向右 `16px` 淡出，上一页淡入。
3. 顶栏和底部主导航如果属于同一个 Shell，应保持稳定，只替换内容区。
4. 高密度操作页可以使用即时替换或短淡入，避免过多横向滑动。

禁用项：

- 不把主 Tab 切换做成二级页 push。
- 不在 Reader 翻页时触发 route push 动效。

验收：

- route stack 只在真实页面导航时变化。
- 阅读页内翻页、模块切换、亮度/进度变化不修改 route stack。

## 5. 覆盖层动效

### `overlay.keyboard.enter` / `overlay.keyboard.exit`

使用场景：搜索输入入口打开键盘层。

进入效果：

1. 键盘面板从底部 `translateY(100%)` 移到 `0`。
2. 时长使用 `160ms`，easing 使用 `standard` 或系统键盘曲线。
3. 面板进入时先获得 pointer 交互，输入框在动画开始后进入 focus。
4. 主导航层级低于键盘，但不能在动画中发生尺寸变化。

退出效果：

1. 键盘面板向下滑出。
2. 输入 focus 在退出开始时释放。
3. 面板完全退出后恢复页面 pointer 状态。

Reduced motion：

- 不做位移，键盘层即时显示/隐藏。
- 输入 focus 和层级状态仍按正常流程更新。

### `overlay.sheet.enter` / `overlay.sheet.exit`

使用场景：书籍详情底表、设置选项底表。

进入效果：

1. 底表从屏幕底部向上滑入，起点在可视区下方。
2. 面板顶部 grabber 与面板一起移动，不单独延迟。
3. 底层页面保持可见，不做全屏变暗，除非具体场景需要阻断。
4. 时长 `160ms`，关闭方向完全反向。

视觉重点：

- 面板边缘和阴影在进入过程中同步出现。
- 面板内容不做逐项 stagger，避免列表项显得不稳定。

验收：

- 底表打开后不遮住必须保留的确认按钮或关闭入口。
- 关闭后焦点和 pointer 不残留在隐藏面板内。

### `overlay.dialog.enter` / `overlay.dialog.exit`

使用场景：删除确认、危险操作确认。

进入效果：

1. 背景遮罩先在 `120ms` 内从透明淡入到目标透明度。
2. 弹窗主体从 `scale(0.96)` 到 `scale(1)`，同时透明度 `0 -> 1`。
3. 弹窗垂直位置从略低/略偏移的位置进入中心，整体时长 `160ms` 到 `200ms`。
4. 弹窗层级必须高于底表。

退出效果：

1. 弹窗主体先淡出并轻微缩回到 `scale(0.98)`。
2. 背景遮罩随后淡出。

禁用项：

- 不做弹簧弹跳。
- 不让弹窗内容逐字或逐行出现。

## 6. ReaderShell 核心动效

### `reader.entry.coverToImmersive`

使用场景：在书架封面网格、继续阅读封面卡片点击封面，进入 `immersive-reading`。

设计目标：

- 让用户明确“打开的是这本书”，但不把封面强行变形成正文页面。
- 进入结果必须是沉浸阅读态，不显示阅读控制层。
- 过渡不改变阅读正文分页；正文只在 ReaderShell 按最终宽高测量后出现。

效果时间线：

1. `0ms -> 80ms`：封面按钮进入 pressed 状态，缩放到 `0.98`，阴影略收，卡片周边内容保持稳定。
2. `80ms -> 160ms`：创建封面 snapshot 或使用原封面层作为过渡锚点；封面轻微上浮 `-4px` 并恢复到 `1.0`，源页面内容透明度降到约 `0.92`。
3. `120ms -> 240ms`：阅读纸面从透明到可见，正文层从下方 `12px` 到原位，透明度 `0 -> 1`。
4. `200ms -> 240ms`：封面 snapshot 淡出；route 进入 `immersive-reading`，返回栈保留来源页。
5. 结束态：只显示沉浸阅读正文，阅读控制层不出现。

视觉重点：

- 封面是“来源锚点”，不是全屏 shared element 主体。可做轻量 shared element，但不能把 2:3 封面拉伸成阅读纸面。
- 书名/章节上下文可以短暂 crossfade 到阅读页标题/章节信息；如果沉浸态不显示顶栏，则只保留正文纸面淡入。
- 书架网格、继续阅读横条、详情页入口都应进入同一个沉浸阅读目标态。

无封面或非封面入口降级：

- `reader.entry.actionToImmersive` 用轻量 route handoff：按钮 pressed `80ms`，旧内容淡出，新阅读纸面从下方 `12px` 淡入。
- 章节行进入沉浸阅读时不使用封面 snapshot，只做内容 handoff。

打断规则：

- 转场前 `80ms` 内返回/切 Tab：取消进入，停留来源页。
- 阅读纸面已开始淡入后返回：进入完成后立即按 `app.route.pop` 返回，不能出现半个阅读页。
- 连续点多个封面：只保留最后一次点击的目标书籍，旧 snapshot 取消。

折叠屏规则：

- 展开态下，如果封面在左侧/书架栏、阅读区在右侧，封面 snapshot 不跨 hinge 飞行；使用来源封面按压 + 右侧阅读纸面淡入。
- 折叠态下按手机态处理。
- 过渡中发生 fold/resize：取消封面位移，按最新 viewport 直接进入阅读纸面。

Reduced motion：

- 只保留 `80ms` 以内 pressed 反馈，随后即时进入沉浸阅读。
- 不做封面上浮、snapshot、正文位移。

验收：

- 点击封面后最终 route 是 `immersive-reading`，不是 `reader`。
- 返回能回到点击前来源页。
- 阅读控制层不会自动出现。
- 连续点两个封面不会进入错误书籍或留下旧封面 snapshot。
- 展开态/折叠态都不会让封面跨 hinge 拉伸。

### `reader.entry.actionToImmersive`

使用场景：继续阅读按钮、书籍详情“继续阅读”、章节行、搜索结果已在书架的“阅读”按钮进入沉浸阅读。

效果描述：

1. 触发控件 pressed `80ms`。
2. 当前内容区短淡出，不使用封面 snapshot。
3. 阅读纸面淡入，正文层从下方 `12px` 到原位，时长 `160ms` 到 `240ms`。
4. 进入后保持沉浸阅读态。

禁用项：

- 不显示阅读控制层。
- 不播放翻页动画。
- 不把章节入口当作 route push 到阅读控制层。

### `reader.control.show`

使用场景：沉浸阅读正文中部点击，显示阅读控制层。

进入效果：

1. 阅读正文层保持原位，不改变排版、透明度和亮度。
2. 顶部阅读栏从上方 `-8px` 到原位，透明度 `0 -> 1`，时长 `160ms`。
3. 底部控制面板从下方 `12px` 到原位，透明度 `0 -> 1`，时长 `200ms`。
4. 四模块导航从底部 `8px` 到原位，透明度 `0 -> 1`，比底部控制面板晚 `20ms` 以内开始。
5. 亮度栏如果显示，使用透明度淡入，不做横向大位移。

禁用项：

- 不给正文加黑色遮罩。
- 不把正文整体缩放。
- 不改变正文可测量区域。

验收：

- 显示控制层前后，正文标题、段落坐标和分页结果一致。
- 顶栏、底部控制层和模块导航没有相互覆盖。

### `reader.control.hide`

使用场景：点击控制层正文中部隐藏控制层。

退出效果：

1. 顶部阅读栏向上 `-8px` 淡出。
2. 底部控制面板向下 `12px` 淡出。
3. 模块导航向下 `8px` 淡出。
4. 正文层不动，只恢复沉浸阅读热区。

Reduced motion：

- 控制层即时隐藏。
- 正文层仍不动。

### `reader.control.handle.press` / `drag` / `release`

使用场景：控制层顶部小横条 `.fd-reader-grabber` 和完整控制页小横条 `.fd-reader-full-grabber` 的按压、拖动和释放。

按压反馈：

1. `0ms -> 80ms`：小横条颜色略加深，宽度可以从 `42px` 过渡到 `48px`，高度最多从 `4px` 到 `5px`。
2. 点击热区不改变；视觉条变化不能影响布局。
3. 如果只是轻点，按当前语义进入完整控制页或回到阅读控制层。

拖动反馈：

1. 拖动开始时取消正在播放的控制层进入/退出动画。
2. 面板跟随手指移动，不加 easing；只允许控制层面板、阴影和小横条响应，阅读正文层保持稳定。
3. 普通控制层向上拖动时显示展开预览：面板高度和阴影轻微增强，最大预览位移建议 `18px`，超过阈值后释放进入 `reader.panel.expand`。
4. 完整控制页向下拖动时显示收回预览：面板向控制层方向跟手，超过阈值释放后回到 `reader` 控制层。
5. 拖动不足阈值时，用 `120ms` 吸附回原位，不改变 route。

释放规则：

- 距离阈值建议为 `18px` 或容器高度的 `8%`，速度阈值由平台按原生手势能力补齐。
- 同一次释放只能落到一个最终状态：展开完整控制页、回到控制层、或停留原状态。
- 释放后才更新 route；拖动中不反复改写返回栈。

禁用项：

- 不把小横条拖动写成页面 scroll。
- 不让正文层跟随小横条上下移动。
- 不在拖动中播放 loading 或 route push 动效。

### `reader.control.dock.longPress` / `drag` / `release` / `rebound`

使用场景：宽屏、平板展开态或横屏紧凑态中，阅读控制层已经不是随屏幕等比变宽的底部整宽面板，而是固定宽度 dock。用户长按小横条后，可以拖动整组控制层。

适用范围：

- 只在 `expanded-width`、`tablet-expanded`、`compact-landscape` 等 fixed-width dock 布局启用。
- 手机态、折叠合上态、底部整宽控制层不启用长按移动，只保留 `reader.control.handle.press/drag/release` 的展开/收回语义。
- 拖动对象是同一组 control dock：`.fd-reader-sheet`、当前模块/快捷面板、`.fd-reader-module-nav`，以及与 dock 绑定的临时运行空间。顶部阅读栏和正文层不跟随移动。

长按进入拖动：

1. `0ms -> 80ms`：小横条进入 pressed，颜色略加深，视觉宽度可从 `42px` 到 `48px`。
2. `80ms -> 320ms`：保持按住且移动距离未超过手势 slop 时，显示长按就绪反馈，例如小横条下方出现轻微 focus ring 或 dock 阴影增强。
3. 达到 `320ms` 后进入 dock 拖动模式。此时控制 dock 轻微上浮 `-1px`，阴影增强，正文层保持原位。
4. 如果在 `320ms` 前松开，按普通点击/展开处理；如果在长按完成前快速移动超过 slop，则取消长按，不进入 dock 移动。

拖动跟手：

1. 拖动期间 dock 以 pointer 位置跟手，不使用 easing。
2. 只更新 dock 的 offset，不更新 route、不重排正文、不改变 dock 宽高。
3. 小横条必须始终留在可触达区域内；拖动到边界时 dock 被 clamp 到边界，不做橡皮筋拉伸。
4. 模块导航和当前面板保持相对位置不变，作为一个整体移动。

可移动空间约束：

| 约束项 | 规则 |
|---|---|
| 坐标容器 | 以当前 `ReaderFrame` 的可见区域为容器；折叠屏展开时以当前阅读 pane 为容器，不跨 hinge。 |
| 左右边界 | `x >= safeLeft + 16px`，`x + dockWidth <= safeRight - 16px`。 |
| 上边界 | `y >= topBarBottom + 12px`；不能盖住顶部阅读栏的返回、换源、更多入口。 |
| 下边界 | `y + dockGroupHeight <= frameBottom - safeBottom - 16px`；不能进入系统手势区。 |
| 最小可触达 | 小横条中心必须距离任一可见边至少 `24px`，避免只能拖到屏幕外。 |
| 阅读正文 | dock 可以覆盖正文的一部分，但不能改变正文测量、分页或热区定义；拖动结束后正文不重排。 |
| 运行胶囊 | 如果运行会话存在，控制层运行中空间跟随 dock；沉浸胶囊不同时作为主控显示。 |

释放和吸附：

1. 释放时如果 dock 在合法边界内，使用 `120ms` ease-out 停到当前位置或最近的合法边缘锚点。
2. 默认吸附策略优先保留用户释放位置；只有距离边缘小于 `24px` 时吸附到该边缘安全边距。
3. 位置按 viewport class 保存，例如 `expanded-width`、`tablet-expanded`、`compact-landscape` 分开记忆。
4. 如果打开新阅读模块或快捷面板，dock 沿用当前保存位置，不回到默认右下角。

越界回弹：

1. resize、fold、orientation 变化后，重新计算可移动空间。
2. 如果保存位置越界，dock 在 `120ms` 内回弹到最近合法位置。
3. 如果当前 pane 变得小于 dock 最小可用宽度，禁用移动并回到默认 dock 锚点。

禁用项：

- 不让 dock 因为屏幕更宽而拉伸。
- 不拆开面板和模块导航分别拖动。
- 不跨折痕、分屏边界或系统安全区。
- 不在拖动中改变阅读进度、章节、route stack 或打开/关闭模块。

Reduced motion：

- 长按仍可进入拖动模式，但不播放上浮、阴影增强和吸附动画。
- 释放后 dock 即时落到合法位置。

### `reader.module.switch`

使用场景：目录、朗读、界面、设置四个底部模块切换。

进入/切换效果：

1. 四个模块按钮的位置、尺寸、间距不变。
2. 按下目标按钮时先执行 `tab.item.press`。
3. 如果目标不是当前 active，执行 `tab.item.switch`：旧模块按钮退出 active，新模块按钮进入 active。
4. 旧面板内容在 `80ms` 内淡出。
5. 新面板内容从下方 `8px` 到原位，透明度 `0 -> 1`，时长 `160ms`。
6. 面板容器高度优先保持稳定；如果内容高度不同，应在容器内部滚动，不让模块导航跳动。

再次点击 active 模块：

1. 当前面板内容淡出。
2. 回到默认阅读控制层。
3. `ReaderContext`、当前页、章节和排版状态不变。

禁用项：

- 不让 active 按钮变大。
- 不做整块控制层重新加载感。

### `reader.quick.promote`

使用场景：搜索、自动翻页、内容替换等快捷动作进入完整控制页。

效果时间线：

1. `0ms`：按钮进入 pressed/active 反馈。
2. `0ms -> 80ms`：当前底部面板内容轻淡出。
3. `80ms -> 240ms`：显示 ReaderShell 行内 loading，spinner 运行。
4. loading 结束后：展开式面板从底部控制层位置向上浮现，透明度 `0 -> 1`，时长 `200ms`。

视觉重点：

- loading 是 ReaderShell 内部状态，不是全屏 loading。
- 顶部阅读栏、正文层和 ReaderContext 保持稳定。

### `reader.session.autoPage.start` / `reader.session.tts.start`

使用场景：在阅读控制层、自动翻页快捷设置、朗读模块或完整朗读页中点击“开始/继续”，启动一个运行会话，然后回到沉浸阅读，显示运行胶囊（控制胶囊）。

效果时间线：

1. `0ms -> 80ms`：触发按钮进入 pressed/active 反馈。自动翻页可以突出倒计时/播放按钮，朗读可以突出播放按钮。
2. `80ms -> 160ms`：当前控制层或完整面板按 `reader.control.hide` / `reader.panel.expand` 的退出方向收起；阅读正文层保持原位。
3. `120ms -> 200ms`：route 使用 replace 进入 `immersive-reading`。这一步不是新的 push，返回栈不多一层控制面板。
4. `160ms -> 240ms`：运行胶囊在沉浸阅读状态区出现，透明度 `0 -> 1`，`translateY(6px) -> 0`，scale `0.96 -> 1`，时长 `160ms`。
5. 自动翻页胶囊显示倒计时圆点、`自动翻页` 文案和暂停/继续按钮；朗读胶囊显示朗读图标、`朗读` 文案和暂停/继续按钮。

互斥规则：

- 开启自动翻页前先取消朗读运行态，开启朗读前先取消自动翻页运行态。
- 互斥取消是状态替换，不播放两套“旧胶囊退出 + 新胶囊进入”的队列动画。
- 如果胶囊已经可见并切换类型，使用 `reader.session.capsule.switch`，在同一锚点内替换图标、数字和文案。

禁用项：

- 不保留启动来源控制层作为返回栈上一层。
- 不把控制层整体缩成胶囊。
- 不让正文因为胶囊出现而重新分页或移动。

### `reader.session.capsule.enter` / `update` / `switch` / `exit`

使用场景：沉浸阅读中展示自动翻页或朗读运行胶囊，并响应暂停、继续、倒计时、句序或会话结束。

胶囊进入：

1. 胶囊锚定在沉浸阅读的状态区域，和页码/状态信息同层。
2. 从 `translateY(6px)`、scale `0.96`、opacity `0` 进入到稳定态。
3. 胶囊不遮挡正文主要阅读区，不改变正文容器尺寸。

胶囊更新：

1. 自动翻页倒计时只更新数字圆点，使用 tabular number；不要整颗胶囊反复弹跳。
2. 播放/暂停图标用不超过 `80ms` 的交叉替换。
3. 朗读句序、范围或状态文案变化时，文案淡换或即时替换；胶囊宽度变化最多 `160ms`，不能挤压相邻页码。

### `reader.session.capsule.control.press` / `toggle`

使用场景：点击控制胶囊右侧暂停/继续按钮。当前 demo 对应 `.fd-ir-status-controls button`，自动翻页使用 `data-reader-setting-toggle="autoPage"`，朗读使用 `data-reader-tts-action="toggle"`。

按下反馈：

1. `0ms -> 60ms`：按钮 scale `1 -> 0.90`，背景色略加深，图标 opacity 降到约 `0.82`。
2. 胶囊容器、文案、倒计时圆点和页码都保持原位。
3. 指针/手指移出按钮热区后取消 pressed 态，`80ms` 内回到普通状态，不切换运行态。

释放并切换到暂停：

1. `0ms`：提交当前 session 的 `playing=false`，但不退出胶囊。
2. `0ms -> 80ms`：暂停图标淡出并缩到 `0.88`。
3. `40ms -> 120ms`：继续/播放图标淡入并恢复到 `1`。
4. 自动翻页暂停时，倒计时数字停在当前值，不播放 `countdownTick`。
5. 朗读暂停时，`reader.session.capsule.voiceIcon.active` 循环停止，语音图标回到静态态。

释放并切换到运行：

1. `0ms`：提交当前 session 的 `playing=true`，仍停留在 `immersive-reading`。
2. `0ms -> 80ms`：播放图标淡出并缩到 `0.88`。
3. `40ms -> 120ms`：暂停图标淡入并恢复到 `1`。
4. 自动翻页继续时，从当前倒计时或重置倒计时规则继续，不重放整颗胶囊入场。
5. 朗读继续时，语音图标 active 提示从当前静态态淡入，不突然跳帧。

禁用项：

- 不打开阅读控制层。
- 不隐藏或重新创建胶囊。
- 不触发 route push、route replace 或控制层显隐动画。
- 不让点击按钮同时命中沉浸阅读正文热区。

Reduced motion：

- 只即时替换按钮图标和 `playing` 状态。
- 不使用 scale、pulse 或数字位移。

### `reader.session.capsule.countdownTick`

使用场景：自动翻页运行胶囊中的倒计时数字每秒变化，以及翻页后重置倒计时。

效果描述：

1. 数字圆点容器尺寸固定，使用 tabular number，避免 `9 -> 8`、`1 -> 8` 时宽度变化。
2. 旧数字在 `80ms` 内 opacity `1 -> 0`，`translateY(0) -> -4px`。
3. 新数字在 `120ms` 内 opacity `0 -> 1`，`translateY(4px) -> 0`。
4. 倒计时到 `1` 后触发翻页时，先提交页码和 `reader.page.turn.next`，再把倒计时重置为下一轮数字；不让数字 tick 和整颗胶囊入场同时重播。
5. 用户暂停自动翻页时，当前数字静止，播放/暂停图标单独切换。

Reduced motion：

- 数字即时替换，保留固定宽度和 tabular number。

### `reader.session.capsule.voiceIcon.active`

使用场景：朗读运行胶囊中的语音/朗读图标，提示 TTS 正在播放。

效果描述：

1. 朗读播放中，语音图标做低频活动提示：scale `1 -> 1.06 -> 1`，opacity `0.82 -> 1 -> 0.82`，周期约 `960ms`。
2. 活动提示只作用于图标或图标外圈，不改变胶囊宽度、不推动文案。
3. 暂停朗读时图标停止在普通静态态；继续朗读时从当前状态淡入活动提示，不突然跳帧。
4. 如果语音图标与自动翻页倒计时圆点互斥切换，先执行 `reader.session.capsule.switch` 的内部 crossfade，再进入 active 提示。

禁用项：

- 不做频繁音频频谱波形；阅读场景不需要持续闪烁。
- 不在后台、锁屏或 reduced-motion 下继续视觉循环。

胶囊切换：

1. 胶囊容器保持同一锚点。
2. 旧类型 icon/label `80ms` 淡出，新类型 icon/label `80ms` 淡入。
3. 自动翻页倒计时圆点和朗读图标之间做内部替换，不播放 route 动效。

胶囊退出：

1. 停止会话或退出阅读时，胶囊 opacity `1 -> 0`，`translateY(0) -> 6px`，时长 `120ms` 到 `160ms`。
2. 暂停会话不等于退出胶囊；暂停只改变图标和状态。
3. 胶囊退出后释放 pointer/focus，避免沉浸阅读热区被不可见元素拦截。

打断规则：

- 胶囊出现中点击正文中部打开控制层：进入 `reader.session.controlSpace.enter`，随后播放或并行播放 `reader.control.show`。
- 胶囊出现中再次点暂停/继续：不重启入场动画，只更新内部播放态。
- 启动会话过程中发生返回/退出阅读：以退出阅读为准，取消胶囊入场。
- 启动会话过程中发生 fold/resize：胶囊按最新阅读 surface 重新锚定，不跨 hinge 飞行。

Reduced motion：

- route replace 即时完成。
- 胶囊只做不超过 `80ms` 的透明度变化，不使用 y 位移和 scale。

### `reader.session.controlSpace.enter` / `update` / `exit`

使用场景：自动翻页或朗读正在运行时，用户从 `immersive-reading` 点击正文中部打开阅读控制层；或者控制层隐藏回沉浸阅读。

空间关系：

- 沉浸阅读中只有运行胶囊是主运行控件。
- 控制层打开后，主运行控件变成控制层内的运行中空间。这个空间可以是底部控制层顶部的紧凑运行条，也可以是当前模块/快捷面板里的运行状态区域。
- 两者不能同时作为主控制出现；过渡中允许使用 snapshot，但结束态只能保留一个真实可交互节点。

进入控制层：

1. `0ms`：用户点击正文中部，捕获运行胶囊视觉 snapshot；正文层保持原位。
2. `0ms -> 80ms`：运行胶囊真实节点停止接收 pointer，snapshot 接管视觉；控制层顶栏和底部面板按 `reader.control.show` 进入。
3. `40ms -> 180ms`：snapshot 从沉浸状态区移动到控制层运行中空间锚点，scale `0.92 -> 1`，圆角从胶囊过渡到运行条/运行卡片规格。
4. `120ms -> 180ms`：控制层运行中空间真实内容淡入并接管交互；snapshot 淡出并移除。
5. 如果当前运行类型是自动翻页，运行空间显示倒计时、暂停/继续和速度摘要；如果是朗读，显示朗读状态、暂停/继续和音色/语速摘要。

控制层内更新：

1. 点击运行空间内暂停/继续时，使用与 `reader.session.capsule.control.toggle` 等价的按钮微动效。
2. 倒计时、朗读图标和文案只在运行空间内部更新，不重播 `reader.control.show`。
3. 从自动翻页切到朗读时，运行空间容器保持锚点，内部内容交叉替换。

隐藏控制层回沉浸阅读：

1. `0ms -> 80ms`：控制层运行空间真实节点停止接收 pointer，snapshot 接管视觉。
2. `0ms -> 160ms`：控制层按 `reader.control.hide` 退出；snapshot 从运行空间锚点收束回沉浸状态区胶囊锚点。
3. `120ms -> 180ms`：沉浸阅读运行胶囊真实节点淡入并接管交互，snapshot 移除。
4. 如果会话在控制层打开期间被停止，则不收束回胶囊，直接执行 `reader.session.capsule.exit`。

降级规则：

- Web demo 暂无 snapshot/matched-geometry 实现时，允许胶囊 `80ms` 淡出，控制层运行中空间 `160ms` 淡入；反向同理。
- 折叠屏/大屏时，运行空间锚点必须在同一个阅读 pane 内重新计算，不跨 hinge 飞行。

Reduced motion：

- 不做空间移动、圆角 morph 或 scale。
- 胶囊和控制层运行空间用不超过 `80ms` 的交叉淡入淡出。

### `reader.panel.expand`

使用场景：`reader-full-directory`、`reader-full-tts`、`reader-full-appearance`、`reader-full-settings`。

进入效果：

1. 面板从底部控制层位置向上展开，起点可以是当前控制层顶部附近。
2. 面板高度从紧凑控制层过渡到大半屏面板，时长 `200ms`。
3. 面板内容在容器展开过程中淡入，延迟不超过 `40ms`。
4. 顶部阅读栏和正文层保留上下文可见，不切到无关全屏。

退出效果：

1. 面板内容先淡出。
2. 面板收回到底部控制层位置。

禁用项：

- 不做全屏页面 push 动效，除非后续产品把它定义成真正页面。
- 不改变阅读正文测量宽高。

### `reader.page.turn.next` / `reader.page.turn.prev`

使用场景：阅读上一页/下一页、章节内进度翻页。

效果描述：

1. 这不是拟物翻页，不做卷页、阴影翻折或 3D 旋转。
2. 下一页：新正文层从右侧 `16px` 进入，透明度 `0 -> 1`，时长 `220ms ease-out`。
3. 上一页：新正文层从左侧 `16px` 进入，透明度 `0 -> 1`，时长 `220ms ease-out`。
4. 页码、页脚和进度在同一状态变更中更新，只更新一次。
5. 旧正文可以即时替换，或用极短淡出；重点是新正文方向感。

禁用项：

- 不触发 route push/pop。
- 不移动顶部栏、底部栏、亮度栏和模块导航。
- 不在拖动进度条时持续播放翻页动画。

Reduced motion：

- 即时替换正文。
- 页码和进度仍更新。

### `reader.chapter.jump`

使用场景：从目录/书签点击章节。

效果描述：

1. 章节跳转是内容状态切换，不是翻页。
2. 正文即时替换或短淡入。
3. 页码重置到章节起点，章节进度同步更新。
4. 控制层是否保留由触发入口决定，但不做装饰性页面 push。

### `reader.sourceSwitch.open` / `reader.sourceSwitch.close`

使用场景：阅读器顶部换源入口。

打开效果：

1. 换源窗口在阅读平面内出现，不铺满全屏。
2. 窗口从当前位置下方 `8px` 到原位，透明度 `0 -> 1`，时长 `200ms`。
3. 不使用全屏黑色遮罩。
4. 顶部阅读栏、底部控制面板和四模块导航按契约保持可操作。
5. 候选来源列表整体出现，不做过强 stagger；如需逐项进入，行间延迟不超过 `20ms`。

关闭效果：

1. 窗口向下 `8px` 淡出。
2. 返回栈中不保留 `source-switch`。
3. 当前阅读控制层状态保持。

验收：

- 窗口不与顶部栏、底部控制面板、四模块导航重叠。
- compact landscape 下仍保持一个连续控制平面，而不是分裂成多个浮块。

## 7. 控件与状态反馈

### 按钮 pressed / selected

效果描述：

1. pressed 使用 `80ms` 内的背景加深或透明度变化。
2. selected 使用 `120ms` 颜色过渡。
3. 不改变按钮布局尺寸。
4. icon 和文字颜色同步变化，避免一个先变一个后变造成延迟感。

### 亮度和进度拖动

效果描述：

1. 用户拖动时，thumb 和 fill 必须跟手，不加 easing。
2. 点击轨道跳转时，fill 可以使用 `80ms` 到 `120ms` 过渡。
3. 拖动结束后不做回弹。
4. 亮度改变可以即时更新 dim layer，不能让正文重新分页。

### `state.loading.inline`

效果描述：

1. loading 面板只在当前 Shell 或当前 Reader 面板内出现。
2. spinner 使用 `800ms linear infinite`。
3. 文案保持稳定，不做滚动字幕。
4. reduced-motion 下 spinner 替换为静态状态点或进度文案。

### `state.focus.flash`

效果描述：

1. 面板显示 focus ring，同时上浮 `-1px`。
2. 进入 `160ms`，保持约 `560ms`，总时长约 `720ms`。
3. 退出时回到原位，不影响相邻面板布局。

## 8. Reduced Motion 统一效果

系统开启 reduced motion 后：

- 所有位移距离设为 `0`。
- route、overlay、reader control 使用即时显示/隐藏或不超过 `80ms` 的淡入淡出。
- 首次打开应用只做短 fade；不做首屏位移。
- 控制层小横条拖动不播放跟手位移；释放时即时落到最终状态。
- 阅读翻页即时替换，不保留横向位移。
- 自动翻页/朗读启动后即时回到沉浸阅读；运行胶囊只保留短 fade。
- 控制胶囊暂停/继续按钮即时切换图标，不做 scale。
- 倒计时数字即时替换；朗读图标不循环 pulse。
- 通用按钮、toggle、chip/filter、segment、row/card 只保留颜色、背景、outline、check/icon 状态变化。
- slider、progress、stepper 数值即时更新，不做 thumb snap、fill tween 或 readout 位移。
- input/search、toast/state、selection toolbar 最多保留 `80ms` fade，不做位移或 scale。
- 打断动画直接切到最新目标状态，不做收尾位移。
- 折叠屏展开/折叠使用即时重排或短淡入，不做大范围位移。
- spinner 可替换成静态 loading 状态。
- selected、focus、pressed 状态仍保留颜色、边框或阴影反馈。

## 9. 验收路径

证据分层：

- Contract 证据：Motion ID 有 token、state fields、`from/to`、interrupt、`finalState` 和 reduced-motion 规则。
- Demo proof 证据：canonical `frontend-demo/` 能用浏览器 route / 点击路径复现状态，coverage 通过，并有代表截图或录屏。
- Platform 证据：平台仓库用原生 UI 组件完成实现，并提供真机/模拟器录屏、golden、单元测试、无障碍测试或性能数据。

下表的 Demo 验收路径只证明 demo 样板，不替代 Platform 证据。

| 动效 | Demo 验收路径 | 必看点 |
|---|---|---|
| 首次打开应用 | 冷启动默认书架/冷启动深链 | 首屏只播放一次，不阻塞操作；恢复前台不重复。 |
| TAB 按钮按下/选中/切换 | 主 TAB、阅读模块 TAB、segmented TAB | press、select、A -> B switch 可区分；栏尺寸、按钮坐标和点击热区稳定。 |
| 通用按钮/图标按钮 | 主按钮、危险按钮、行内按钮、toolbar 按钮 | press、activate、disabled blocked 一致；按钮尺寸和相邻控件稳定。 |
| Toggle/Switch/Checkbox | 设置开关、Reader 开关、书源开关、批量勾选 | pressed、switch、revert 可区分；thumb/check/semantics 同步。 |
| Chip/Filter/Segment | 书架分组、Discover/RSS/Source 筛选、Settings segment | 即时选择、多选筛选、应用提交、segment switch 语义分开。 |
| Slider/Progress/Stepper | 亮度、章节进度、字号/行距 stepper、恢复进度 | 拖动跟手无 easing；释放后 commit；进度更新不抖动。 |
| Input/Search | 搜索输入、RSS search、Settings search、Source search | focus/blur/clear/submit 与键盘和结果状态同步。 |
| Toast/State | 设置 toast、Discover toast、empty/error/success/result | toast 不堆叠；state 替换不重建 Shell。 |
| Selection/Row/Card | 文本选择、书籍卡片、RSS row、Source row、Restore card | 选择、导航、批量状态分开；selection toolbar 不遮挡正文。 |
| 下拉栏展开/收起/点击 | 阅读设置、朗读设置、设置页选项、发现排序、书源更多、书架更多、书籍焦点菜单 | trigger press、expand、collapse、option press、option select 统一；打开 A 后切 B 不残留；resize/orientation 可重定位。 |
| 主 Tab 切换 | 书架/发现/RSS/设置主导航 | 导航不位移，内容切换不带阅读翻页感。 |
| 书架二级页 push/pop | 书架 -> 搜索/详情 -> 返回 | 内容区方向明确，主 Shell 稳定。 |
| 键盘 | 搜索输入入口 -> 完成 | 键盘从底部进入，不错误遮挡主导航。 |
| 底表 | 书籍详情 -> 更换书源/更多操作 | 底表从底部进入，关闭后焦点释放。 |
| 弹窗 | 书籍详情 -> 删除/移除确认 | 背景和弹窗层级正确。 |
| 封面进入沉浸阅读 | 书架封面/继续阅读封面 -> `immersive-reading` | 封面只作来源锚点，最终为沉浸阅读，返回栈正确。 |
| 普通入口进入沉浸阅读 | 继续阅读按钮/章节行/详情阅读按钮 -> `immersive-reading` | 无封面时轻量 handoff，不显示控制层。 |
| 控制层显示/隐藏 | `immersive-reading` 正文中部点击 -> `reader` -> dismiss | 正文不重排、不变暗。 |
| 控制层小横条 | `reader` 小横条点击/拖动、`reader-full-*` 小横条拖动 | 小横条按压有反馈；拖动跟手；释放只落到一个最终状态。 |
| 模块切换 | reader -> 目录/朗读/界面/设置 | 模块导航几何不变，面板内容轻切换。 |
| 快捷动作展开 | reader -> 搜索/自动翻页/替换 | 先行内 loading，再进入完整面板。 |
| 自动翻页启动 | 控制层/完整自动翻页 -> 开启自动翻页 | route replace 回 `immersive-reading`，自动翻页胶囊进入，朗读状态被取消。 |
| 朗读启动 | 控制层/完整朗读 -> 开始朗读 | route replace 回 `immersive-reading`，朗读胶囊进入，自动翻页状态被取消。 |
| 运行胶囊更新/切换/退出 | 沉浸阅读中的自动翻页/朗读胶囊 | 倒计时和播放态只更新内部；互斥切换不排队；停止后释放点击热区。 |
| 控制层运行中空间 | 运行胶囊可见时打开/隐藏控制层 | 胶囊停靠到控制层运行空间；结束态只有一个主运行控件；降级时淡出/淡入。 |
| 胶囊暂停/继续按钮 | 自动翻页/朗读胶囊右侧控制按钮 | 按下只影响按钮；释放切换运行态；胶囊不重入场、不打开控制层。 |
| 倒计时数字变化 | 自动翻页运行胶囊每秒 tick | 数字固定宽度内部替换，胶囊不重入场、不挤压页码。 |
| 朗读图标活动提示 | 朗读运行胶囊播放/暂停 | 播放时低频 pulse，暂停和 reduced motion 静态。 |
| 翻页 | reader 上一页/下一页 | 只有正文层有方向感，route stack 不变。 |
| 换源窗口 | reader 顶部换源 | 内联窗口，无全屏 blocker，无重叠。 |
| 打断：关闭/返回 | 底表/弹窗/控制层进入中快速返回或关闭 | 旧动画不排队，最终状态唯一。 |
| 打断：连续模块切换 | reader 快速点击目录/朗读/界面/设置 | 模块导航不抖动，面板内容接管不闪白。 |
| 打断：loading 完成 + 返回 | 快捷动作 loading 中立即返回 | 以返回为准，不把完成结果再盖回来。 |
| 折叠屏展开 | 手机态 reader/source-switch -> 展开态 | ReaderContext 保留，overlay 重新锚定。 |
| 折叠屏折叠 | 展开态 reader module/source-switch -> 手机态 | 控制层连续，返回栈不新增记录。 |
| 横屏紧凑重排 | `compact-landscape` reader/settings | 控制层保持一个连续平面，不分裂。 |
| 整屏旋转：普通页面 | portrait <-> landscape，书架/设置/搜索 | active tab、route stack、focus 和 overlay 语义保留；普通内容重排不逐项飞入。 |
| 整屏旋转：沉浸阅读 | `immersive-reading` portrait <-> landscape | 正文按章节进度/字符锚点重新分页；不跳章、不重播封面进入。 |
| 整屏旋转：控制层打开 | `reader` / `reader-full-*` portrait <-> compact-landscape / tablet-expanded | 控制层保持打开，映射到新 viewport class 的等价容器；模块状态不丢。 |
| 整屏旋转：运行胶囊 | 自动翻页/朗读胶囊可见时旋转 | active session、倒计时/播放态保留；胶囊重锚定，不出现双主控。 |
| 整屏旋转：宽屏 dock | fixed-width dock 保存 offset 后旋转或 resize | dock group 整体 clamp 到新可移动空间；越界回弹；不跨 hinge/安全区。 |
| 整屏旋转：overlay | 底表/弹窗/换源窗口打开时旋转 | overlay 锚点重算，空间不足时等价降级；焦点语义正确。 |
| Reduced motion | 系统 reduced motion 或测试开关 | 位移移除，状态反馈仍可辨认。 |

## 10. 当前还缺的实装动作

这份说明仍是规划稿，要进入可交付动效规范，还需要：

1. 已完成第一版：`motion-tokens.css`、裸写时长替换、reduced-motion CSS/查询开关、`MOTION_SELECTOR_MATRIX.md`、基础 `data-motion-id` / pressed state 和 `data-motion-component-*` normalized adapter 接入。
2. 补 TAB 栏 `tab.item.press/select/switch` 的统一实现和录屏证据。
3. 深化通用组件族 `button.*`、`toggle.*`、`chip/filter/segment.*`、`slider/stepper/progress.*`、`input/search.*`、`feedback/state.*`、`selection.*`、`listRow/card.*` 的状态机和录屏证据。
4. 已完成第一版：`dropdown.trigger.press`、`dropdown.menu.expand/collapse`、`dropdown.option.press/select` 和打开 A 后切 B 的 `motion.interrupt.redirect` / `data-motion-dropdown-switch-*` 已接入统一实现；下一步补关闭保留动画、`dropdown.menu.reposition` 和录屏证据。
5. 补封面进入沉浸阅读的 snapshot/shared-element 降级实现和录屏证据。
6. 已完成第一版：首次打开应用有 cold-start 一次性 adapter，控制层小横条按压/拖动/释放也已有第一版 adapter；首启已有代表截图，下一步补默认页/深链页录屏、后台恢复和真实触摸证据。
7. 已完成第一版：自动翻页/朗读启动回沉浸阅读和运行胶囊进入、更新、切换、退出已接 token 化 adapter；自动翻页胶囊已有代表截图，下一步补停止/退出打断和录屏证据。
8. 已完成第一版：运行胶囊与控制层运行中空间之间已有同状态源的 running space adapter；控制层运行空间已有代表截图，下一步补 matched 停靠/展开媒体证据。
9. 已完成第一版：控制胶囊暂停/继续按钮的按压、运行/暂停状态和 icon 切换已接 adapter；下一步补取消/真实触摸证据。
10. 已完成第一版：倒计时数字 tick 和朗读图标 active 提示已有独立微动效；下一步补录屏证据。
11. 给每个高风险动效补 demo capture 或录屏。
12. 在平台映射文档中继续为每个 Motion ID 补 state 字段、测试文件和验收方式。
13. 已完成第一版：`motion.interrupt.cancel/redirect/completeThenReplace` 已接入 root / screen host `data-motion-interrupt-*`、临时 pressed/dragging/dropdown 清理、route/Tab/viewport/loading/dock drag/连续下拉 A->B 入口和 token 化短收尾；reader loading async result 已接入 `data-motion-async-*` request guard、cancel/discard 和完成态 CSS；Tab switch redirect 已有代表截图，下一步补 overlay 关闭、焦点恢复自动化和录屏证据。
14. 已完成第一版：`overlay.keyboard/sheet/dialog.*` 已接入 `data-motion-overlay-*` role/state/action/focus-return 字段、settings overlay 主体入口、token 化 enter CSS 和基础焦点恢复；下一步补连续 overlay 打断、遮罩互斥、录屏和平台焦点测试。
15. 已完成第一版 `viewport.orientation.prepare/reshape/settle` adapter：root / screen host `data-motion-orientation-*`、route/session/overlay/focus/dock 元数据、anchor settle CSS、dock clamp 和 reduced-motion 即时 settle 已接入；compact-landscape 已有代表截图，下一步补真实旋转录屏、正文字符锚点重分页和 overlay/focus 自动化证据。
16. 用真实折叠屏/模拟器补 `viewport.fold.expand`、`viewport.fold.collapse`、`viewport.orientation.reshape` 的 hinge/pane/posture 证据。

## 11. 平台不可从 Demo 继承的内容

- 不继承 Web CSS selector、DOM 结构、`data-*` 属性名、query 参数、fixture route stack 或截图文件名。
- 不继承 Web 的像素坐标、绝对高度、断点数值、scroll 容器或 z-index 实现。
- 不继承 Web 的模拟键盘、模拟折叠屏、浏览器 viewport resize 作为真实平台证据。
- 不把 demo 的 route replace/push 等同于平台 `NavigationStack`、Compose navigation、ArkUI router 或系统返回生命周期。
- 不把 demo coverage 通过等同于平台完成；coverage 只说明 canonical demo 的契约样板没有断裂。

平台必须继承的是 Motion ID、状态语义、互斥/打断规则、reduced-motion 规则、最终状态约束和验收清单。
