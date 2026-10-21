# 本地阅读的状态与所有权

本实现范围为单本 TXT 的原生选择、导入、书架、目录、连续正文阅读、显示偏好与位置恢复。
工程使用 SwiftUI 管理页面，UIKit TextKit 负责文字塑形、断行、滚动与字符位置；
Rust Core 负责导入事务、书架、章节正文和持久化阅读位置。

跨平台参考冻结为 Host `33f7c7b21474a76a042ebda911c5f0ff2d73cf54`、
UI `95366cd93775ea0ad3ecbc0f60e8882717f93169`、
Core `2a301653c140eef457e786fd6ab3bb9b8e3045c8`。
参考入口为相邻 HarmonyOS 仓 `docs/ui-design/cross-platform-reference/README.md`。
资源来源、变换与许可见 `Resources/Reference/manifest.json`。
后续 HarmonyOS 原生增强和未提交 UI 优化不自动更新这组输入。

## 业务与 Host 边界

| Owner | 负责内容 |
| --- | --- |
| `ReaderLibraryService` | 通过固定 Swift binding 调用 Core；保留原始请求终态、Host 原书文件和导入补偿记录 |
| Core | 解析、章节与正文、书架事实、导入持久化/补偿、进度修订和内容版本 |
| `ReaderApplicationModel` | 页面投影、原操作展示、阅读会话身份、位置提交队列和前后台准入 |
| `ReaderFilePickerOwner` | 将原生选择与弹层退出按 operation UUID 汇合；任意先后只交付一次所选 URL |
| `ReaderPreferences` | UserDefaults 中的 Host 显示偏好；应用日夜主题与阅读纸色独立 |
| `ReaderTextSurface` | 显示章节、用平台文字布局定位；在 UTF-16 与 Core Unicode scalar 坐标间转换 |
| `ReaderControlMotionDriver` | Hidden/Quick/Full 的连续采样、释放、重抓、取消和减少动态效果 |
| `ReaderBrightnessOwner` | 当前阅读窗口的系统亮度与恢复；不创建另一份业务状态 |

书籍、目录与进度不另建 Swift 数据库。Host 将原书按内容身份保留为 `.source`，
沙箱文件 URL 不充当跨平台业务身份。文件选择取消不产生导入；关闭结果展示不取消已经派发的业务。
原写入未决时保留原请求身份，不用重新读取的值冒充原写入确认，也不重复发送未知写入。
迟到的 persist、add、finalize、rollback 和 progress 终态各回到其原 owner 后再清理。

## 阅读位置与生命周期

位置使用章节身份、Unicode scalar offset、内容版本、处理版本和进度修订。
UITextView 的 UTF-16 下标只用于平台布局，不直接写入 Core。
本地正文按冻结的非空语义段投影，显示层跳过空段；原文与 Core scalar 坐标保持不变。
正文重新排版保留 scalar 锚点；章节切换与明确 seek 更新 restoration 身份，
旧文字布局、旧页面和旧请求的回调不能更新新会话。

滚动位置先合并，再以 Core 原修订提交；冲突或未决时保留最后确认位置与待核对意图。
离开阅读、切换章节及退后台会请求排空当前位置。后台任务只延长系统允许的执行窗口，
不保证 App 被立即强制结束前的任意手势都已保存。界面只把原写入终态当作保存确认。
前台恢复和冷启动继续使用同一 Core 数据目录，导入补偿记录由运行时核对。

## 消息入口登记

以下按业务事实接入公共展示组件。组件仅展示事实和回传用户意图；
写入、重试、导航和取消状态仍属于表内 owner。

| 业务入口 | 类别与组件 | 身份、失效与清理 |
| --- | --- | --- |
| Bootstrap 准备/启动失败 | 页面状态 `ReaderPageState` | Bootstrap 单次 prepare；失败保留目录，重试由 Bootstrap 发起 |
| 书架初载、确认空、无内容失败 | 页面状态 `ReaderPageState` | library/navigation generation；新请求或进入阅读后旧结果失效 |
| 已有书架刷新失败 | 普通短反馈 `ReaderTransientFeedback` | 当前导航、foreground、feedback generation；新导航/后台/到期清理 |
| 打开书籍失败 | 普通短反馈 `ReaderTransientFeedback` | 原打开请求和书籍；旧 navigation generation 不得发消息 |
| TXT 导入进行、已完成、失败、未决 | 专用任务宿主 `ReaderImportResultView` | import operation UUID；关闭展示不结束任务，未决核对仍由运行时执行 |
| 阅读进度保存/flush 待确认 | 原操作未决 `ReaderRecoveryNotice` | 当前 session、请求修订和 flush generation；原终态确认后清理 |
| 章节切换、关闭阅读 | 阅读专用忙态 | 当前 session/chapter generation；旧异步回调不得解除新 busy 状态 |
| 文件选择器 | 原生 Host 适配 `ReaderDocumentPicker` | 单次选择/取消；选择器退出后才展示导入任务，避免两个弹层同时交接 |

当前范围没有删除确认、全局通知、TTS、在线书源或漫画消息入口。
新增入口按工作区消息分类登记，不在页面直接另建 Toast、Alert 或同类消息外框。

## 原生证据边界

Core/Host 方法测试、App 编译、模拟器安装启动、原生交互录像和用户验收分别记录。
定向测试通过不证明所有字体、窗口、手势和系统生命周期已经验收。
原生导入与阅读验收使用下载目录的真实文件，按原字节与 SHA-256 绑定输入；
不生成小说文本代替用户文件，也不把控制状态的单元测试当成真实书籍验证。
物理 iOS 设备、iOS 17 运行时、iPad 分屏和无障碍组合均需各自的原生证据；
工程的最低版本或设备族声明不代替这些验证。

开发状态只在工作区 `DEVELOPMENT_BACKLOG.md` 的 `IOS-LOCAL-*` 与 `IOS-V2-*` 至 `IOS-V8-*` 条目维护。
后续范围和验收见 [iOS V2–V8 版本要求](../../DEVELOPMENT_BACKLOG.md#ios-version-requirements)，本文描述首版已接入边界，不另建版本待办。
