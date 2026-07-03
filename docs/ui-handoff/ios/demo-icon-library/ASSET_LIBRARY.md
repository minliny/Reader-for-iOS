# 素材库清单（Asset Library Inventory）

## 当前纳入内容（Included Assets）

| 中文名称（English Name） | 数量（Count） | 说明（Notes） |
|---|---:|---|
| UI 设计图（UI Design Screens） | 30 | 当前所有 `UI设计图.png` 已按页面组进入 `fixture.json`。 |
| 书籍封面素材（Book Cover Assets） | 6 | 当前书架封面图已进入素材库。 |
| fixture 图标 token（Fixture Icon Tokens） | 55 | 从当前所有页面 `fixture.json` 扫描得出。 |
| 补齐图标（Supplemented Icons） | 35 | 补齐 Shell、阅读模块、状态、Compose 语义追溯和缺少公共登记的图标 token。 |
| 本地总图标 token（Total Local Icon Tokens） | 90 | 以 `icons.js` 中 `ReaderAssetIcons.icons` 为准；Figma 图标主组件已用 `lucide-static@1.21.0` 开源 SVG 补齐为 `Icon/*`。 |
| 验证截图（Validation Screenshots） | 60 | 作为验证素材集合登记，不在预览页逐张加载。 |

## 补齐图标（Supplemented Icons）

- 返回（Back）：`back`
- 更多（More）：`more`
- 右箭头（Chevron）：`chevron`
- 左箭头（Chevron Left）：`chevron-left`
- 关闭（Close）：`close`
- 目录（Directory）：`directory`
- 朗读（TTS）：`tts`
- 自动翻页（Auto Page）：`auto-page`
- 替换（Replace）：`replace`
- 阅读内容搜索（Reader Content Search）：`reader-content-search`
- 阅读自动翻页（Reader Auto Page）：`reader-auto-page`
- 阅读内容替换（Reader Content Replace）：`reader-content-replace`
- 阅读目录模块（Reader Module Directory）：`reader-module-directory`
- 阅读朗读模块（Reader Module TTS）：`reader-module-tts`
- 阅读界面模块（Reader Module Appearance）：`reader-module-appearance`
- 阅读设置模块（Reader Module Settings）：`reader-module-settings`
- 暂停（Pause）：`pause`
- 停止（Stop）：`stop`
- 打开书籍（Book Open）：`book-open`
- 来源栈（Source Stack）：`source-stack`
- 换源（Source Switch）：`source-switch`
- 进度（Progress）：`progress`
- 音量（Volume）：`volume`
- 齿轮（Gear）：`gear`
- 清除（Clear）：`clear`
- 离线（Offline）：`offline`
- 闪光 / 智能提示（Sparkle）：`sparkle`
- 文件夹不可用（Folder Off）：`folder-off`
- 夜间模式（Night Mode）：`night-mode`
- 当前位置（Current Location）：`current-location`
- 权限（Permission）：`permission`
- 代码（Code）：`code`
- 帮助（Help）：`help`
- 信号（Signal）：`signal`
- Wi-Fi（Wi-Fi）：`wifi`

## 准入规则（Acceptance Rules）

- 新增图标必须先进入 `icons.js`。
- 新增 UI 源图必须先进入 `fixture.json` 和 `fixture.js`。
- 页面 renderer 不能再临时新增同义图标 token。
- 如果页面必须使用局部图标，必须在素材库中标注为页面专属。
- 图标进入工具栏前必须完成光学校准：24 dp 常规外框内，图形主体控制在 18-21 dp，不能顶满 viewBox。
- 从图片抠图或 `potrace` 生成的 SVG 必须保留源 PNG / traced SVG 文件，并在 `icons.js` 中以 `currentColor` 内联为最终 token。
- `preview.html` 必须通过 manifest 验证。
- `FrontendInputAssetLibraryInventoryTest` 必须通过，确保 `fixture.json`、`fixture.js`、`icons.js`、实际文件、manifest 和验证报告同步。

## 图标尺寸规划（Icon Size Plan）

| 使用位置（Usage） | CSS / Token | 外框尺寸（Frame Size） | 光学主体（Optical Body） | 说明（Notes） |
|---|---|---:|---:|---|
| 状态栏图标（Status Bar） | `fd-signal` / `fd-wifi` / `fd-battery` | 12-15 px | 按系统状态栏比例 | 只用于设计稿 QA，不参与业务动作。 |
| 小图标（Small Icon） | `fd-small-icon` | 20 px | 15-18 px | 列表行、章节标识、行内动作。 |
| 常规图标（Regular Icon） | `fd-icon` / `fd-nav-icon` | 24 px | 18-21 px | 顶栏、主导航、普通 IconButton。 |
| 阅读快捷图标（Reader Quick Icon） | `fd-reader-actions .fd-medium-icon` | 24 px | 18-21 px | 搜索、自动翻页、替换三项必须统一视觉重量。 |
| 中号图标（Medium Icon） | `fd-medium-icon` | 28 px | 21-24 px | 卡片、状态块和非密集功能入口。 |
| 空状态图标（Empty / State Icon） | `fd-empty-icon` 等 | 36-44 px | 28-36 px | 不进入工具栏，不与操作按钮混用。 |

阅读快捷图标（Reader Quick Icons）当前要求：

- 搜索（Search）：`reader-content-search`，来自 image2 抠图 + `potrace`，需要额外 viewBox 留白，避免放大镜过大。
- 自动翻页（Auto Page）：`reader-auto-page`，来自 image2 抠图 + `potrace`，保持 24 px 外框。
- 替换（Replacement）：`reader-content-replace`，来自 image2 抠图 + `potrace`，需要额外 viewBox 留白，避免双箭头过大且不得与换源图标混淆。
- 底部模块导航（Reader Module Navigation）：目录、朗读、界面、设置四个图标使用 `reader-module-*` 专用 token，来自 image2 抠图 + `potrace`，不复用全局 `directory` / `tts` / `palette` / `gear`，避免影响其他页面。

## 裁切与占位规则（Crop and Placeholder Rules）

| 素材类型（Asset Type） | 裁切规则（Crop Rule） | 占位规则（Placeholder Rule） |
|---|---|---|
| 书架封面（Bookshelf Cover） | 默认 2:3；优先 contain 或 center crop，不能裁掉标题主体。 | 使用语义占位封面，显示书名首字或 `book-open` 图标。 |
| 详情封面（Detail Cover） | 可放大但仍保持原始比例，不为了填满 Hero 拉伸。 | 使用同一封面占位策略，保留书名和作者文本。 |
| 搜索 / 列表小封面（List Cover） | 小尺寸优先 contain，允许留背景，不裁关键内容。 | 使用小封面占位，不影响列表行高度。 |
| 状态插图（State Illustration） | 不参与 P0 布局，不压缩主动作。 | 无图时使用状态图标 + 标题 + 主动作。 |
| UI 设计图（UI Screen） | 只作为源证据，不作为页面整屏背景。 | 缺失时页面不能进入正式输入件完成状态。 |
| 图标（Icon） | 只使用语义 token，不在页面内临时画同义图。 | 先补 `icons.js`，再进入页面 renderer。 |
