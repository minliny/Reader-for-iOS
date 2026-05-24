# iOS SwiftUI Prototype Screenshot Index

## 截图环境

| 项目 | 值 |
|---|---|
| 当前结论 | IOS_SWIFTUI_PROTOTYPE_MANUAL_SCREENSHOTS_READY |
| Xcode project | `ReaderForIOS.xcodeproj` |
| Scheme | `ReaderForIOSApp` |
| Simulator | `iPhone 17 Pro` |
| iOS Runtime | iOS 26.5 |
| 截图尺寸 | 1206 x 2622 px（390 x 844 pt @3x） |
| 截图目录 | `docs/ui-handoff/ios/screenshots/prototype-gallery/` |
| 截图方式 | Xcode/Simulator 启动 App，点击 `[DEBUG] Prototype Gallery`，逐页打开 entry 后 `simctl io screenshot --mask ignored` |

## 38 Entry 截图索引

| 序号 | 分组 | 页面 | Prototype entry | 截图文件路径 | 是否已截图 | 是否可人工校对 | 校对结论 | 风险等级 | 备注 |
|---:|---|---|---|---|---|---|---|---|---|
| 1 | App / Navigation | App Shell / Main Tabs | app-shell | `docs/ui-handoff/ios/screenshots/prototype-gallery/001_app_shell_main_tabs.png` | 是 | 是 | PASS | 无 | 主底栏为书架 / 发现 / 书源 / 我的 |
| 2 | Bookshelf | 书架封面模式 | bookshelf-cover | `docs/ui-handoff/ios/screenshots/prototype-gallery/002_bookshelf_cover_mode.png` | 是 | 是 | PASS | 无 | 信息完整 |
| 3 | Bookshelf | 书架列表模式 | bookshelf-list | `docs/ui-handoff/ios/screenshots/prototype-gallery/003_bookshelf_list_mode.png` | 是 | 是 | PASS | 无 | 信息完整 |
| 4 | Bookshelf | 书架空状态 | bookshelf-empty | `docs/ui-handoff/ios/screenshots/prototype-gallery/004_bookshelf_empty_state.png` | 是 | 是 | PASS | 无 | 引导完整 |
| 5 | Search / Detail | 搜索首页 | search-home | `docs/ui-handoff/ios/screenshots/prototype-gallery/005_search_home.png` | 是 | 是 | PASS | 无 | 搜索入口在 Gallery 内校对 |
| 6 | Search / Detail | 搜索结果 | search-results | `docs/ui-handoff/ios/screenshots/prototype-gallery/006_search_results.png` | 是 | 是 | PASS | 无 | 来源/多来源信息可见 |
| 7 | Search / Detail | 搜索空状态 | search-empty | `docs/ui-handoff/ios/screenshots/prototype-gallery/007_search_empty_state.png` | 是 | 是 | PASS | 无 | 状态引导可见 |
| 8 | Search / Detail | 搜索错误状态 | search-error | `docs/ui-handoff/ios/screenshots/prototype-gallery/008_search_error_state.png` | 是 | 是 | PASS | 无 | 错误引导可见 |
| 9 | Search / Detail | 书籍详情 | book-detail | `docs/ui-handoff/ios/screenshots/prototype-gallery/009_book_detail.png` | 是 | 是 | PASS | 无 | 详情结构可校对 |
| 10 | Search / Detail | 书籍详情 TOC 预览 | book-detail-toc | `docs/ui-handoff/ios/screenshots/prototype-gallery/010_book_detail_toc_preview.png` | 是 | 是 | PASS | 无 | TOC 预览清晰 |
| 11 | Reader | 阅读页基础控制层 | reader-base | `docs/ui-handoff/ios/screenshots/prototype-gallery/011_reader_base_controls.png` | 是 | 是 | PASS | 无 | 四角信息与控制层可见 |
| 12 | Reader | 阅读页搜索 overlay | reader-search | `docs/ui-handoff/ios/screenshots/prototype-gallery/012_reader_search_overlay.png` | 是 | 是 | PASS | 无 | overlay 可见 |
| 13 | Reader | 阅读页自动翻页 overlay | reader-autoscroll | `docs/ui-handoff/ios/screenshots/prototype-gallery/013_reader_auto_scroll_overlay.png` | 是 | 是 | PASS | 无 | 无上一章/下一章语义 |
| 14 | Reader | 阅读页内容替换 overlay | reader-replace | `docs/ui-handoff/ios/screenshots/prototype-gallery/014_reader_replace_overlay.png` | 是 | 是 | PASS | 无 | 当前书籍规则 |
| 15 | Reader | 阅读页夜间状态 | reader-night | `docs/ui-handoff/ios/screenshots/prototype-gallery/015_reader_night_state.png` | 是 | 是 | PASS | 无 | 非弹窗 |
| 16 | Reader | 阅读页目录/书签 overlay | reader-directory | `docs/ui-handoff/ios/screenshots/prototype-gallery/016_reader_toc_bookmark_overlay.png` | 是 | 是 | PASS | 无 | tab/进度/标识可见 |
| 17 | Reader | 阅读页朗读 overlay | reader-tts | `docs/ui-handoff/ios/screenshots/prototype-gallery/017_reader_tts_overlay.png` | 是 | 是 | PASS | 无 | 无章节跳转语义 |
| 18 | Reader | 阅读页界面 overlay | reader-appearance | `docs/ui-handoff/ios/screenshots/prototype-gallery/018_reader_appearance_overlay.png` | 是 | 是 | PASS | 无 | 图标语义可校对 |
| 19 | Reader | 阅读页设置 overlay | reader-settings | `docs/ui-handoff/ios/screenshots/prototype-gallery/019_reader_settings_overlay.png` | 是 | 是 | PASS | 无 | 不含 WebDAV/书源/RSS/账号同步 |
| 20 | Source Management | 书源管理列表 | source-list | `docs/ui-handoff/ios/screenshots/prototype-gallery/020_source_management_list.png` | 是 | 是 | PASS | 无 | 状态完整 |
| 21 | Source Management | 书源详情 | source-detail | `docs/ui-handoff/ios/screenshots/prototype-gallery/021_source_detail.png` | 是 | 是 | PASS | 无 | 不暴露 parser internals |
| 22 | Source Management | 书源编辑 / 导入状态 | source-edit-import | `docs/ui-handoff/ios/screenshots/prototype-gallery/022_source_edit_import_state.png` | 是 | 是 | PASS | 无 | fixture-only |
| 23 | Source Management | 书源测试 / 禁用 / 错误状态 | source-test-error | `docs/ui-handoff/ios/screenshots/prototype-gallery/023_source_test_disabled_error_state.png` | 是 | 是 | PASS | 无 | fixture-only |
| 24 | Discover | 发现首页 | discover-home | `docs/ui-handoff/ios/screenshots/prototype-gallery/024_discover_home.png` | 是 | 是 | PASS | 无 | 主底栏语义在 prototype app shell 内 |
| 25 | RSS | RSS 列表 | rss-list | `docs/ui-handoff/ios/screenshots/prototype-gallery/025_rss_list.png` | 是 | 是 | PASS | 无 | fixture-only |
| 26 | RSS | RSS 详情 | rss-detail | `docs/ui-handoff/ios/screenshots/prototype-gallery/026_rss_detail.png` | 是 | 是 | PASS | 无 | fixture-only |
| 27 | RSS | RSS 订阅管理 | rss-subscriptions | `docs/ui-handoff/ios/screenshots/prototype-gallery/027_rss_subscription_management.png` | 是 | 是 | PASS | 无 | fixture-only |
| 28 | WebDAV | WebDAV 配置 | webdav-config | `docs/ui-handoff/ios/screenshots/prototype-gallery/028_webdav_config.png` | 是 | 是 | PASS | 无 | 未保存真实账号/token |
| 29 | Sync | 备份设置 | backup-settings | `docs/ui-handoff/ios/screenshots/prototype-gallery/029_backup_settings.png` | 是 | 是 | PASS | 无 | 静态状态展示 |
| 30 | Sync | 阅读进度同步状态 | sync-progress | `docs/ui-handoff/ios/screenshots/prototype-gallery/030_reading_progress_sync_state.png` | 是 | 是 | PASS | 无 | 静态状态展示 |
| 31 | WebDAV | 远程 WebDAV 书籍 | remote-webdav-books | `docs/ui-handoff/ios/screenshots/prototype-gallery/031_remote_webdav_books.png` | 是 | 是 | PASS | 无 | 未触发真实请求 |
| 32 | Sync | 同步错误 / WebDAV auth error | sync-error | `docs/ui-handoff/ios/screenshots/prototype-gallery/032_sync_error_webdav_auth_error.png` | 是 | 是 | PASS | 无 | 错误展示，不发起登录 |
| 33 | Settings | 全局设置（我的页面内） | global-settings | `docs/ui-handoff/ios/screenshots/prototype-gallery/033_global_settings.png` | 是 | 是 | PASS | 无 | 在“我的”语义下 |
| 34 | State Pages | loading 状态页 | state-loading | `docs/ui-handoff/ios/screenshots/prototype-gallery/034_loading_state.png` | 是 | 是 | PASS | 无 | 可复用状态页 |
| 35 | State Pages | empty 状态页 | state-empty | `docs/ui-handoff/ios/screenshots/prototype-gallery/035_empty_state.png` | 是 | 是 | PASS | 无 | 可复用状态页 |
| 36 | State Pages | error 状态页 | state-error | `docs/ui-handoff/ios/screenshots/prototype-gallery/036_error_state.png` | 是 | 是 | PASS | 无 | 可复用状态页 |
| 37 | State Pages | offline 状态页 | state-offline | `docs/ui-handoff/ios/screenshots/prototype-gallery/037_offline_state.png` | 是 | 是 | PASS | 无 | 可复用状态页 |
| 38 | State Pages | permission required 状态页 | state-permission | `docs/ui-handoff/ios/screenshots/prototype-gallery/038_permission_required_state.png` | 是 | 是 | PASS | 无 | 可复用状态页 |
