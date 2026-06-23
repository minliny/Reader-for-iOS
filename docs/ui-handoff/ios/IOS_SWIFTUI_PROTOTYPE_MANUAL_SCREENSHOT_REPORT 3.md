# iOS SwiftUI Prototype Manual Screenshot Report

## 1. 总体结论

**IOS_SWIFTUI_PROTOTYPE_MANUAL_SCREENSHOTS_BLOCKED**

## 2. 本轮目标

本轮是 Codex 电脑操作截图校对：使用 Xcode 和 iOS Simulator 打开 debug-only Prototype Gallery，对 38 个 Prototype entry 逐页截图并更新截图索引/截图报告/fix queue。不是生产 UI 接入，不修改 Swift 源码，不接真实网络/WebDAV/RSS/同步。

## 3. 输入状态

| 文档 | 读取状态 |
|---|---|
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_DEBUG_ENTRY_REPORT.md` | 已读取 |
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_SCREENSHOT_INDEX.md` | 已读取并更新 |
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_MANUAL_FIX_QUEUE.md` | 已读取并更新 |
| `iOS/Modules/Prototype/` | 已读取结构 |
| `iOS/App/ReaderApp.swift` | 已读取，确认 Debug-only entry 已接入 |

## 4. 运行环境

| 项目 | 值 |
|---|---|
| Xcode project | `ReaderForIOS.xcodeproj` |
| Scheme | `ReaderForIOSApp` |
| Simulator | `iPhone 17 Pro` |
| iOS Runtime | CLI build destination: iOS 26.5；Xcode GUI destination: iOS 26.4.1 |
| 截图尺寸 | 未生成截图；目标 390 x 844 pt |
| 实际运行方式 | `xcodebuild` fresh build + Xcode GUI Run；均在构建阶段失败，未进入 App |

## 5. Prototype Gallery 运行结果

| 检查项 | 结果 |
|---|---|
| 是否打开 App | 否，fresh build 未通过 |
| 是否看到 `[DEBUG] Prototype Gallery` | 否，未进入 App |
| 是否进入 Gallery | 否 |
| 是否能访问 38 个 entry | 否 |
| 是否有无法进入的 entry | 38/38 |
| 冒烟 entry 001/011/013/033 | 未执行，build 阻塞 |

阻塞原因：`ReaderForIOSApp` fresh Debug build 依赖 `ReaderShellValidation` target，当前在 `iOS/CoreBridge/RuntimeContractMapping.swift` 编译失败。本轮禁止修改 Swift，因此停止截图并记录 P0。

## 6. 截图结果

| 项目 | 值 |
|---|---|
| 目标截图数量 | 38 |
| 成功截图数量 | 0 |
| 未截图数量 | 38 |
| 截图目录 | `docs/ui-handoff/ios/screenshots/prototype-gallery/` |
| 截图索引路径 | `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_SCREENSHOT_INDEX.md` |

## 7. 38 个 Entry 截图清单

| 序号 | 分组 | 页面 | Prototype entry | 截图路径 | 是否已截图 | 校对结论 | 风险等级 |
|---:|---|---|---|---|---|---|---|
| 1 | App / Navigation | App Shell / Main Tabs | app-shell | `docs/ui-handoff/ios/screenshots/prototype-gallery/001_app_shell_main_tabs.png` | 否 | BLOCKED | P0 |
| 2 | Bookshelf | 书架封面模式 | bookshelf-cover | `docs/ui-handoff/ios/screenshots/prototype-gallery/002_bookshelf_cover_mode.png` | 否 | BLOCKED | P0 |
| 3 | Bookshelf | 书架列表模式 | bookshelf-list | `docs/ui-handoff/ios/screenshots/prototype-gallery/003_bookshelf_list_mode.png` | 否 | BLOCKED | P0 |
| 4 | Bookshelf | 书架空状态 | bookshelf-empty | `docs/ui-handoff/ios/screenshots/prototype-gallery/004_bookshelf_empty_state.png` | 否 | BLOCKED | P0 |
| 5 | Search / Detail | 搜索首页 | search-home | `docs/ui-handoff/ios/screenshots/prototype-gallery/005_search_home.png` | 否 | BLOCKED | P0 |
| 6 | Search / Detail | 搜索结果 | search-results | `docs/ui-handoff/ios/screenshots/prototype-gallery/006_search_results.png` | 否 | BLOCKED | P0 |
| 7 | Search / Detail | 搜索空状态 | search-empty | `docs/ui-handoff/ios/screenshots/prototype-gallery/007_search_empty_state.png` | 否 | BLOCKED | P0 |
| 8 | Search / Detail | 搜索错误状态 | search-error | `docs/ui-handoff/ios/screenshots/prototype-gallery/008_search_error_state.png` | 否 | BLOCKED | P0 |
| 9 | Search / Detail | 书籍详情 | book-detail | `docs/ui-handoff/ios/screenshots/prototype-gallery/009_book_detail.png` | 否 | BLOCKED | P0 |
| 10 | Search / Detail | 书籍详情 TOC 预览 | book-detail-toc | `docs/ui-handoff/ios/screenshots/prototype-gallery/010_book_detail_toc_preview.png` | 否 | BLOCKED | P0 |
| 11 | Reader | 阅读页基础控制层 | reader-base | `docs/ui-handoff/ios/screenshots/prototype-gallery/011_reader_base_controls.png` | 否 | BLOCKED | P0 |
| 12 | Reader | 阅读页搜索 overlay | reader-search | `docs/ui-handoff/ios/screenshots/prototype-gallery/012_reader_search_overlay.png` | 否 | BLOCKED | P0 |
| 13 | Reader | 阅读页自动翻页 overlay | reader-autoscroll | `docs/ui-handoff/ios/screenshots/prototype-gallery/013_reader_auto_scroll_overlay.png` | 否 | BLOCKED | P0 |
| 14 | Reader | 阅读页内容替换 overlay | reader-replace | `docs/ui-handoff/ios/screenshots/prototype-gallery/014_reader_replace_overlay.png` | 否 | BLOCKED | P0 |
| 15 | Reader | 阅读页夜间状态 | reader-night | `docs/ui-handoff/ios/screenshots/prototype-gallery/015_reader_night_state.png` | 否 | BLOCKED | P0 |
| 16 | Reader | 阅读页目录/书签 overlay | reader-directory | `docs/ui-handoff/ios/screenshots/prototype-gallery/016_reader_toc_bookmark_overlay.png` | 否 | BLOCKED | P0 |
| 17 | Reader | 阅读页朗读 overlay | reader-tts | `docs/ui-handoff/ios/screenshots/prototype-gallery/017_reader_tts_overlay.png` | 否 | BLOCKED | P0 |
| 18 | Reader | 阅读页界面 overlay | reader-appearance | `docs/ui-handoff/ios/screenshots/prototype-gallery/018_reader_appearance_overlay.png` | 否 | BLOCKED | P0 |
| 19 | Reader | 阅读页设置 overlay | reader-settings | `docs/ui-handoff/ios/screenshots/prototype-gallery/019_reader_settings_overlay.png` | 否 | BLOCKED | P0 |
| 20 | Source Management | 书源管理列表 | source-list | `docs/ui-handoff/ios/screenshots/prototype-gallery/020_source_management_list.png` | 否 | BLOCKED | P0 |
| 21 | Source Management | 书源详情 | source-detail | `docs/ui-handoff/ios/screenshots/prototype-gallery/021_source_detail.png` | 否 | BLOCKED | P0 |
| 22 | Source Management | 书源编辑 / 导入状态 | source-edit-import | `docs/ui-handoff/ios/screenshots/prototype-gallery/022_source_edit_import_state.png` | 否 | BLOCKED | P0 |
| 23 | Source Management | 书源测试 / 禁用 / 错误状态 | source-test-error | `docs/ui-handoff/ios/screenshots/prototype-gallery/023_source_test_disabled_error_state.png` | 否 | BLOCKED | P0 |
| 24 | Discover | 发现首页 | discover-home | `docs/ui-handoff/ios/screenshots/prototype-gallery/024_discover_home.png` | 否 | BLOCKED | P0 |
| 25 | RSS | RSS 列表 | rss-list | `docs/ui-handoff/ios/screenshots/prototype-gallery/025_rss_list.png` | 否 | BLOCKED | P0 |
| 26 | RSS | RSS 详情 | rss-detail | `docs/ui-handoff/ios/screenshots/prototype-gallery/026_rss_detail.png` | 否 | BLOCKED | P0 |
| 27 | RSS | RSS 订阅管理 | rss-subscriptions | `docs/ui-handoff/ios/screenshots/prototype-gallery/027_rss_subscription_management.png` | 否 | BLOCKED | P0 |
| 28 | WebDAV | WebDAV 配置 | webdav-config | `docs/ui-handoff/ios/screenshots/prototype-gallery/028_webdav_config.png` | 否 | BLOCKED | P0 |
| 29 | Sync | 备份设置 | backup-settings | `docs/ui-handoff/ios/screenshots/prototype-gallery/029_backup_settings.png` | 否 | BLOCKED | P0 |
| 30 | Sync | 阅读进度同步状态 | sync-progress | `docs/ui-handoff/ios/screenshots/prototype-gallery/030_reading_progress_sync_state.png` | 否 | BLOCKED | P0 |
| 31 | WebDAV | 远程 WebDAV 书籍 | remote-webdav-books | `docs/ui-handoff/ios/screenshots/prototype-gallery/031_remote_webdav_books.png` | 否 | BLOCKED | P0 |
| 32 | Sync | 同步错误 / WebDAV auth error | sync-error | `docs/ui-handoff/ios/screenshots/prototype-gallery/032_sync_error_webdav_auth_error.png` | 否 | BLOCKED | P0 |
| 33 | Settings | 全局设置（我的页面内） | global-settings | `docs/ui-handoff/ios/screenshots/prototype-gallery/033_global_settings.png` | 否 | BLOCKED | P0 |
| 34 | State Pages | loading 状态页 | state-loading | `docs/ui-handoff/ios/screenshots/prototype-gallery/034_loading_state.png` | 否 | BLOCKED | P0 |
| 35 | State Pages | empty 状态页 | state-empty | `docs/ui-handoff/ios/screenshots/prototype-gallery/035_empty_state.png` | 否 | BLOCKED | P0 |
| 36 | State Pages | error 状态页 | state-error | `docs/ui-handoff/ios/screenshots/prototype-gallery/036_error_state.png` | 否 | BLOCKED | P0 |
| 37 | State Pages | offline 状态页 | state-offline | `docs/ui-handoff/ios/screenshots/prototype-gallery/037_offline_state.png` | 否 | BLOCKED | P0 |
| 38 | State Pages | permission required 状态页 | state-permission | `docs/ui-handoff/ios/screenshots/prototype-gallery/038_permission_required_state.png` | 否 | BLOCKED | P0 |

## 8. 主导航校对

未完成。Prototype App Shell 未能打开，无法人工确认主底栏是否为 `书架 / 发现 / 书源 / 我的`，也无法确认是否无阅读/设置/搜索底栏。本轮不修生产主导航。

## 9. 阅读页校对

未完成。Reader entry 未能打开，Reader 10 条规则无法进行人工截图校对。

| # | 规则 | 本轮人工校对 |
|---:|---|---|
| 1 | 四角信息完整 | BLOCKED |
| 2 | 控制层不挤压正文 | BLOCKED |
| 3 | 快捷按钮无文字标签 | BLOCKED |
| 4 | 夜间模式不是弹窗 | BLOCKED |
| 5 | 内容替换只显示当前书籍规则 | BLOCKED |
| 6 | 目录/书签 overlay 信息完整 | BLOCKED |
| 7 | 自动翻页不使用上一章/下一章语义 | BLOCKED |
| 8 | 朗读 overlay 不使用章节跳转语义 | BLOCKED |
| 9 | 阅读设置不包含 WebDAV/书源/RSS/账号同步 | BLOCKED |
| 10 | 界面设置图标尺寸与语义一致 | BLOCKED |

## 10. 页面完整性校对

未完成。38 个 entry 均因 fresh build 失败无法进入，因此未对空壳、信息不足、归类错误、icon 语义、token 一致性做人工截图结论。

## 11. Boundary / Safety 检查

| 检查项 | 结果 |
|---|---|
| 是否未引用 parser internals | `scripts/check_ios_boundary.sh` PASS，79 files，0 violations |
| 是否无 WebView UI 承载 Prototype Gallery | PASS，本轮未进入 WebView UI |
| 是否无真实网络 | PASS，本轮未接真实网络 |
| 是否未接真实 WebDAV/RSS/同步 | PASS |
| 是否未修改 Reader-Core | PASS |
| 是否修改 Swift 源码 | 否 |
| clean-room | PASS，无外部 GPL 代码搬运 |

## 12. 命令验证结果

| 命令 | 结果 |
|---|---|
| `git status --short` | 有未提交/未跟踪改动，未 reset、未 stash、未清理 |
| `git branch --show-current` | `main` |
| `git log --oneline -n 5` | `5d61001`, `de42a83`, `2605801`, `cba49d2`, `4e1cb0f` |
| `bash scripts/check_ios_boundary.sh` | PASS，79 files，0 violations |
| `xcodebuild -list -project ReaderForIOS.xcodeproj` | `ReaderForIOSApp` scheme 可见 |
| `xcrun simctl list devices available` | `iPhone 17 Pro` iOS 26.5 booted；iOS 26.4.1 available |
| `xcodebuild -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug build` | BUILD FAILED，`RuntimeContractMapping.swift` in `ReaderShellValidation` |
| Xcode GUI Run | 已点击 Run，构建阶段失败，未启动 fresh App |

关键错误摘要：

```text
iOS/CoreBridge/RuntimeContractMapping.swift:83:1: error: type 'ProductionWebViewAdapter' does not conform to protocol 'RuntimeExecutorProtocol'
iOS/CoreBridge/RuntimeContractMapping.swift:155:10: error: method must be declared fileprivate because its result uses a private type
iOS/CoreBridge/RuntimeContractMapping.swift:91:26: error: 'securityGate' is inaccessible due to 'private' protection level
iOS/CoreBridge/RuntimeContractMapping.swift:101:24: error: extra argument 'timestamp' in call
```

## 13. 修复队列摘要

| 风险等级 | 数量 |
|---|---:|
| P0 | 1 |
| P1 | 0 |
| P2 | 0 |
| P3 | 0 |

fix queue 路径：`docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_MANUAL_FIX_QUEUE.md`

## 14. P0 问题

`MANUAL-P0-002`：fresh Debug build 无法通过，导致无法打开 App、无法点击 `[DEBUG] Prototype Gallery`、无法截图 38 个 entry。

## 15. P1 问题

无。

## 16. 是否建议进入逐页视觉修复

不建议。当前 P0 不为 0，应先修复 `RuntimeContractMapping.swift` build 阻塞。修复后再重新执行 Xcode/Simulator 截图。
