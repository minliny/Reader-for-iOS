# iOS SwiftUI Prototype Manual Screenshot Report

## 1. 总体结论

**IOS_SWIFTUI_PROTOTYPE_MANUAL_SCREENSHOTS_BLOCKED**

## 2. 本轮目标

本轮是 Codex 电脑操作截图校对：使用 Xcode 和 iOS Simulator 打开 debug-only Prototype Gallery，对 38 个 Prototype entry 逐页截图并更新截图索引/校对报告。不是生产 UI 接入，不修 Swift UI，不接真实网络/WebDAV/RSS/同步。

## 3. 输入状态

| 文档 | 读取状态 |
|---|---|
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_GALLERY_REPORT.md` | 已读取 |
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_VISUAL_AUDIT.md` | 已读取 |
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_VISUAL_FIX_REPORT.md` | 已读取 |
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_SCREENSHOT_REVIEW.md` | 已读取并更新 |
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_SCREENSHOT_INDEX.md` | 已读取并更新 |

## 4. 运行环境

| 项目 | 值 |
|---|---|
| Xcode project（用户指定） | `ReaderForIOS 7.xcodeproj` |
| Xcode project（实际可 build 验证） | `ReaderForIOS.xcodeproj` |
| Scheme | `ReaderForIOSApp` |
| Simulator | `iPhone 17 Pro` |
| Simulator UDID | `74B467A0-A02D-4D7B-9CE3-E10937B6A7DE` |
| iOS Runtime | iOS 26.5 |
| 目标截图尺寸 | 390 x 844 pt |
| 实际运行方式 | Xcode GUI 打开 `ReaderForIOS 7.xcodeproj`；Simulator 启动并运行 `com.reader.ios` |

## 5. Prototype Gallery 运行结果

| 检查项 | 结果 |
|---|---|
| 是否打开 App | 是 |
| 是否进入 `[DEBUG] Prototype Gallery` | 否 |
| 是否能访问 38 个 entry | 否 |
| 无法进入的 entry | 38/38 |
| 阻塞原因 | `Route.prototypeGallery` 与 `PrototypeGalleryView` 存在，但 `ReaderApp.swift` 当前 GUI 仅暴露 WebView Harness；未发现 Prototype Gallery 可点击入口 |

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

未完成。当前生产 App GUI 显示 `Home / Bookshelf / Search / Settings`，Prototype Gallery 目标主底栏 `书架 / 发现 / 书源 / 我的` 未能打开截图校对；因此不能标记通过。

## 9. 阅读页校对

Reader 10 条规则无法进行人工截图校对。既有代码级报告为 10/10 PASS，但本轮人工截图状态是 BLOCKED。

## 10. 页面完整性校对

未完成。38 个 entry 在代码中存在，但无法通过 GUI 入口逐页进入。未发现可截图页面，未对空壳、信息密度、归类、icon 语义、token 一致性做人工截图结论。

## 11. Boundary / Safety 检查

| 检查项 | 结果 |
|---|---|
| 未引用 parser internals | boundary PASS |
| 无 WebView UI 用于 Prototype 截图 | PASS，本轮未进入 WebView UI |
| 无真实网络 | PASS，本轮未接真实网络 |
| 未接真实 WebDAV/RSS/同步 | PASS |
| 未修改 Reader-Core | PASS |
| clean-room | PASS，无外部 GPL 代码搬运 |

## 12. 命令验证结果

| 命令 | 结果 |
|---|---|
| `git status --short` | 有未提交/未跟踪改动，未清理、未 reset、未 stash |
| `git branch --show-current` | `main` |
| `git log --oneline -n 5` | `5d61001`, `de42a83`, `2605801`, `cba49d2`, `4e1cb0f` |
| `bash scripts/check_ios_boundary.sh` | PASS，79 files，0 violations |
| `xcodebuild -list` | 失败：目录含 7 个 `.xcodeproj`，需指定 `-project` |
| `xcodebuild -list -project "ReaderForIOS 7.xcodeproj"` | 列出 schemes，但 Xcode GUI destination 显示 `No Destinations` |
| `xcrun simctl list devices available` | 可用 `iPhone 17 Pro` iOS 26.4 / 26.5 |
| `xcodebuild -project "ReaderForIOS 7.xcodeproj" -scheme ReaderForIOSApp ... build` | 失败：scheme 未配置 build action，内部引用 `container:ReaderForIOS.xcodeproj` |
| `xcodebuild -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp ... build` | BUILD SUCCEEDED |
| `xcrun simctl install ... ReaderForIOSApp.app` | 成功 |
| `xcrun simctl launch ... com.reader.ios` | 成功，pid 40197 |

## 13. 修复队列摘要

| 风险等级 | 数量 |
|---|---:|
| P0 | 1 |
| P1 | 0 |
| P2 | 0 |
| P3 | 0 |

fix queue 路径：`docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_MANUAL_FIX_QUEUE.md`

## 14. P0 问题

`MANUAL-P0-001`：Prototype Gallery 无法通过当前 GUI 入口打开，导致 38 个 entry 均无法截图。

## 15. P1 问题

无。

## 16. 是否建议进入逐页视觉修复

不建议。当前 P0 不为 0，应先补齐 DEBUG-only Prototype Gallery 入口并重新执行人工截图。修复建议必须保持最小范围，不替换生产主入口，不接真实数据，不绕过 `ShellAssembly` 与 boundary。
