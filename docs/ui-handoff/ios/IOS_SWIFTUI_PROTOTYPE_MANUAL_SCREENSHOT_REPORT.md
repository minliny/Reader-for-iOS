# iOS SwiftUI Prototype Manual Screenshot Report

## 1. 总体结论

**IOS_SWIFTUI_PROTOTYPE_MANUAL_SCREENSHOTS_READY**

## 2. 本轮目标

本轮是 Codex 电脑操作截图校对：使用 Xcode 和 iOS Simulator 打开 debug-only Prototype Gallery，对 38 个 Prototype entry 逐页截图并更新截图索引/截图报告/fix queue。不是生产 UI 接入，不修改 Swift 源码，不接真实网络/WebDAV/RSS/同步。

## 3. 输入状态

| 文档 | 读取状态 |
|---|---|
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_BUILD_P0_FIX_REPORT.md` | 已读取 |
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_DEBUG_ENTRY_REPORT.md` | 已读取 |
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_SCREENSHOT_INDEX.md` | 已读取并更新 |
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_MANUAL_FIX_QUEUE.md` | 已读取并更新 |

## 4. 运行环境

| 项目 | 值 |
|---|---|
| Xcode project | `ReaderForIOS.xcodeproj` |
| Scheme | `ReaderForIOSApp` |
| Simulator | `iPhone 17 Pro` |
| Simulator UDID | `74B467A0-A02D-4D7B-9CE3-E10937B6A7DE` |
| iOS Runtime | iOS 26.5 |
| 截图尺寸 | 1206 x 2622 px（390 x 844 pt @3x） |
| 实际运行方式 | `xcodebuild` fresh build → `simctl install` → `simctl launch` → Simulator GUI 点击 `[DEBUG] Prototype Gallery` → 逐页打开 entry → `simctl io screenshot --mask ignored` |

## 5. Prototype Gallery 运行结果

| 检查项 | 结果 |
|---|---|
| 是否打开 App | 是 |
| 是否看到 `[DEBUG] Prototype Gallery` | 是 |
| 是否进入 Gallery | 是 |
| 是否能访问 38 个 entry | 是 |
| 是否有无法进入的 entry | 无 |
| 冒烟 entry 001 App Shell / Main Tabs | PASS |
| 冒烟 entry 011 Reader Base Controls | PASS |
| 冒烟 entry 013 Reader Auto Scroll Overlay | PASS |
| 冒烟 entry 033 Global Settings | PASS |

## 6. 截图结果

| 项目 | 值 |
|---|---|
| 目标截图数量 | 38 |
| 成功截图数量 | 38 |
| 未截图数量 | 0 |
| 截图目录 | `docs/ui-handoff/ios/screenshots/prototype-gallery/` |
| 截图索引路径 | `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_SCREENSHOT_INDEX.md` |

## 7. 38 个 Entry 截图清单

| 序号 | 分组 | 页面 | Prototype entry | 截图路径 | 是否已截图 | 校对结论 | 风险等级 |
|---:|---|---|---|---|---|---|---|
| 1 | App / Navigation | App Shell / Main Tabs | app-shell | `docs/ui-handoff/ios/screenshots/prototype-gallery/001_app_shell_main_tabs.png` | 是 | PASS | 无 |
| 2 | Bookshelf | 书架封面模式 | bookshelf-cover | `docs/ui-handoff/ios/screenshots/prototype-gallery/002_bookshelf_cover_mode.png` | 是 | PASS | 无 |
| 3 | Bookshelf | 书架列表模式 | bookshelf-list | `docs/ui-handoff/ios/screenshots/prototype-gallery/003_bookshelf_list_mode.png` | 是 | PASS | 无 |
| 4 | Bookshelf | 书架空状态 | bookshelf-empty | `docs/ui-handoff/ios/screenshots/prototype-gallery/004_bookshelf_empty_state.png` | 是 | PASS | 无 |
| 5 | Search / Detail | 搜索首页 | search-home | `docs/ui-handoff/ios/screenshots/prototype-gallery/005_search_home.png` | 是 | PASS | 无 |
| 6 | Search / Detail | 搜索结果 | search-results | `docs/ui-handoff/ios/screenshots/prototype-gallery/006_search_results.png` | 是 | PASS | 无 |
| 7 | Search / Detail | 搜索空状态 | search-empty | `docs/ui-handoff/ios/screenshots/prototype-gallery/007_search_empty_state.png` | 是 | PASS | 无 |
| 8 | Search / Detail | 搜索错误状态 | search-error | `docs/ui-handoff/ios/screenshots/prototype-gallery/008_search_error_state.png` | 是 | PASS | 无 |
| 9 | Search / Detail | 书籍详情 | book-detail | `docs/ui-handoff/ios/screenshots/prototype-gallery/009_book_detail.png` | 是 | PASS | 无 |
| 10 | Search / Detail | 书籍详情 TOC 预览 | book-detail-toc | `docs/ui-handoff/ios/screenshots/prototype-gallery/010_book_detail_toc_preview.png` | 是 | PASS | 无 |
| 11 | Reader | 阅读页基础控制层 | reader-base | `docs/ui-handoff/ios/screenshots/prototype-gallery/011_reader_base_controls.png` | 是 | PASS | 无 |
| 12 | Reader | 阅读页搜索 overlay | reader-search | `docs/ui-handoff/ios/screenshots/prototype-gallery/012_reader_search_overlay.png` | 是 | PASS | 无 |
| 13 | Reader | 阅读页自动翻页 overlay | reader-autoscroll | `docs/ui-handoff/ios/screenshots/prototype-gallery/013_reader_auto_scroll_overlay.png` | 是 | PASS | 无 |
| 14 | Reader | 阅读页内容替换 overlay | reader-replace | `docs/ui-handoff/ios/screenshots/prototype-gallery/014_reader_replace_overlay.png` | 是 | PASS | 无 |
| 15 | Reader | 阅读页夜间状态 | reader-night | `docs/ui-handoff/ios/screenshots/prototype-gallery/015_reader_night_state.png` | 是 | PASS | 无 |
| 16 | Reader | 阅读页目录/书签 overlay | reader-directory | `docs/ui-handoff/ios/screenshots/prototype-gallery/016_reader_toc_bookmark_overlay.png` | 是 | PASS | 无 |
| 17 | Reader | 阅读页朗读 overlay | reader-tts | `docs/ui-handoff/ios/screenshots/prototype-gallery/017_reader_tts_overlay.png` | 是 | PASS | 无 |
| 18 | Reader | 阅读页界面 overlay | reader-appearance | `docs/ui-handoff/ios/screenshots/prototype-gallery/018_reader_appearance_overlay.png` | 是 | PASS | 无 |
| 19 | Reader | 阅读页设置 overlay | reader-settings | `docs/ui-handoff/ios/screenshots/prototype-gallery/019_reader_settings_overlay.png` | 是 | PASS | 无 |
| 20 | Source Management | 书源管理列表 | source-list | `docs/ui-handoff/ios/screenshots/prototype-gallery/020_source_management_list.png` | 是 | PASS | 无 |
| 21 | Source Management | 书源详情 | source-detail | `docs/ui-handoff/ios/screenshots/prototype-gallery/021_source_detail.png` | 是 | PASS | 无 |
| 22 | Source Management | 书源编辑 / 导入状态 | source-edit-import | `docs/ui-handoff/ios/screenshots/prototype-gallery/022_source_edit_import_state.png` | 是 | PASS | 无 |
| 23 | Source Management | 书源测试 / 禁用 / 错误状态 | source-test-error | `docs/ui-handoff/ios/screenshots/prototype-gallery/023_source_test_disabled_error_state.png` | 是 | PASS | 无 |
| 24 | Discover | 发现首页 | discover-home | `docs/ui-handoff/ios/screenshots/prototype-gallery/024_discover_home.png` | 是 | PASS | 无 |
| 25 | RSS | RSS 列表 | rss-list | `docs/ui-handoff/ios/screenshots/prototype-gallery/025_rss_list.png` | 是 | PASS | 无 |
| 26 | RSS | RSS 详情 | rss-detail | `docs/ui-handoff/ios/screenshots/prototype-gallery/026_rss_detail.png` | 是 | PASS | 无 |
| 27 | RSS | RSS 订阅管理 | rss-subscriptions | `docs/ui-handoff/ios/screenshots/prototype-gallery/027_rss_subscription_management.png` | 是 | PASS | 无 |
| 28 | WebDAV | WebDAV 配置 | webdav-config | `docs/ui-handoff/ios/screenshots/prototype-gallery/028_webdav_config.png` | 是 | PASS | 无 |
| 29 | Sync | 备份设置 | backup-settings | `docs/ui-handoff/ios/screenshots/prototype-gallery/029_backup_settings.png` | 是 | PASS | 无 |
| 30 | Sync | 阅读进度同步状态 | sync-progress | `docs/ui-handoff/ios/screenshots/prototype-gallery/030_reading_progress_sync_state.png` | 是 | PASS | 无 |
| 31 | WebDAV | 远程 WebDAV 书籍 | remote-webdav-books | `docs/ui-handoff/ios/screenshots/prototype-gallery/031_remote_webdav_books.png` | 是 | PASS | 无 |
| 32 | Sync | 同步错误 / WebDAV auth error | sync-error | `docs/ui-handoff/ios/screenshots/prototype-gallery/032_sync_error_webdav_auth_error.png` | 是 | PASS | 无 |
| 33 | Settings | 全局设置（我的页面内） | global-settings | `docs/ui-handoff/ios/screenshots/prototype-gallery/033_global_settings.png` | 是 | PASS | 无 |
| 34 | State Pages | loading 状态页 | state-loading | `docs/ui-handoff/ios/screenshots/prototype-gallery/034_loading_state.png` | 是 | PASS | 无 |
| 35 | State Pages | empty 状态页 | state-empty | `docs/ui-handoff/ios/screenshots/prototype-gallery/035_empty_state.png` | 是 | PASS | 无 |
| 36 | State Pages | error 状态页 | state-error | `docs/ui-handoff/ios/screenshots/prototype-gallery/036_error_state.png` | 是 | PASS | 无 |
| 37 | State Pages | offline 状态页 | state-offline | `docs/ui-handoff/ios/screenshots/prototype-gallery/037_offline_state.png` | 是 | PASS | 无 |
| 38 | State Pages | permission required 状态页 | state-permission | `docs/ui-handoff/ios/screenshots/prototype-gallery/038_permission_required_state.png` | 是 | PASS | 无 |

## 8. 主导航校对

Prototype App Shell 主底栏为：`书架 / 发现 / 书源 / 我的`。

| 检查项 | 结果 |
|---|---|
| 主底栏为书架 / 发现 / 书源 / 我的 | PASS |
| 不出现阅读作为底栏 | PASS |
| 不出现设置作为底栏 | PASS |
| 不出现搜索作为底栏 | PASS |
| 发现为第二个主底栏 | PASS |

注：生产 App 仍显示 `Home / Bookshelf / Search / Settings`，本轮按要求不修生产主导航，只校对 Prototype Gallery 内的 App Shell。

## 9. 阅读页校对

| # | 规则 | 结果 |
|---:|---|---|
| 1 | 四角信息完整：左上书名、右上电量、左下章节、右下时间 | PASS |
| 2 | 控制层不挤压正文 | PASS |
| 3 | 快捷按钮无文字标签 | PASS |
| 4 | 夜间模式不是弹窗 | PASS |
| 5 | 内容替换只显示当前书籍规则 | PASS |
| 6 | 目录/书签 overlay 有 tab、分级小字、右侧常驻进度条、书签标识、当前阅读标识 | PASS |
| 7 | 自动翻页不使用上一章/下一章语义 | PASS |
| 8 | 朗读 overlay 不使用章节跳转语义 | PASS |
| 9 | 阅读设置不包含 WebDAV、书源、RSS、账号同步 | PASS |
| 10 | 界面设置图标尺寸与语义一致 | PASS |

## 10. 页面完整性校对

| 分组 | 结论 |
|---|---|
| 书架封面 / 列表 / 空状态 | PASS，无空壳，信息完整 |
| 搜索首页 / 结果 / 空 / 错误 | PASS，可校对 |
| 书籍详情 / TOC 预览 | PASS，结构清晰 |
| 书源列表 / 详情 / 编辑导入 / 测试错误 | PASS，fixture-only，不暴露 parser internals |
| 发现 / RSS / WebDAV / 备份 / 同步 | PASS，fixture-only，未触发真实请求 |
| 全局设置 | PASS，在“我的”语义下，不是主底栏一级设置 |
| loading / empty / error / offline / permission | PASS，可复用状态页 |

未发现空壳、信息不足、归类错误、icon 语义错误、token 不一致或人工校对阻塞点。

## 11. Boundary / Safety 检查

| 检查项 | 结果 |
|---|---|
| 是否未引用 parser internals | PASS，`scripts/check_ios_boundary.sh` 为 PASS |
| 是否无 WebView UI 承载 Prototype Gallery | PASS |
| 是否无真实网络 | PASS |
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
| `xcodebuild -project "ReaderForIOS.xcodeproj" -scheme "ReaderForIOSApp" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` | BUILD SUCCEEDED |
| `xcrun simctl install ... ReaderForIOSApp.app` | 成功 |
| `xcrun simctl launch ... com.reader.ios` | 成功 |
| `xcrun simctl io ... screenshot --mask ignored` | 38/38 成功 |
| `find docs/ui-handoff/ios/screenshots/prototype-gallery -name '*.png' | wc -l` | 38 |
| `sips -g pixelWidth -g pixelHeight` | 全部 1206 x 2622 px |

## 13. 修复队列摘要

| 风险等级 | 数量 |
|---|---:|
| P0 | 0 |
| P1 | 0 |
| P2 | 0 |
| P3 | 0 |

fix queue 路径：`docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_MANUAL_FIX_QUEUE.md`

## 14. P0 问题

无。

## 15. P1 问题

无。

## 16. 是否建议进入逐页视觉修复

建议进入逐页视觉修复。当前 P0/P1 为 0，且未发现新增 P2/P3；可以基于 38 张截图进入更细粒度视觉修复或评审。
