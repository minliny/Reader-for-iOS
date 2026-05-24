# iOS SwiftUI Prototype Gallery Report

## 1. 总体结论

**IOS_SWIFTUI_PROTOTYPE_GALLERY_READY**

---

## 2. 本轮目标

fixture/state-driven Prototype Gallery，共 38 个 entry，覆盖 App Shell、Bookshelf、Search/Detail、Reader（9 control states）、Source Management、Discover、RSS、WebDAV、Sync、Settings、State Pages。非生产 UI 接入，不接真实网络/WebDAV/RSS/同步。

---

## 3. 输入基线

| 文档 | 状态 |
|---|---|
| IOS_SWIFTUI_PROTOTYPE_PREREQ_REPORT.md | READY |
| IOS_SWIFTUI_PROTOTYPE_AUDIT.md | 已审计 |
| CROSS_PLATFORM_UI_BASELINE.md | 已读取 |
| CROSS_PLATFORM_ROUTE_MATRIX.md | 已读取 |
| CROSS_PLATFORM_STATE_MATRIX.md | 已读取 |
| CROSS_PLATFORM_READER_CONTROL_SPEC.md | 已读取 |
| CROSS_PLATFORM_COMPONENT_MAPPING.md | 已读取 |

---

## 4. 修改范围

所有文件均位于 `iOS/Modules/Prototype/`：

| 文件 | 说明 |
|---|---|
| `PrototypeEntry.swift` | 38-entry 枚举模型 + 13 分组定义（已预置） |
| `PrototypeGalleryView.swift` | Gallery List + 全 38 个 prototype View（已预置） |
| `PrototypeFixtures.swift` | 全量 fixture 数据模型（已预置） |

---

## 5. Prototype Gallery 结构

- `PrototypeEntry`: id + group + name + view factory
- `PrototypeGroup`: 13 分组（appShell / bookshelf / searchDetail / reader / sourceMgmt / discover / rss / webdav / sync / settings / states / debug）
- `PrototypeGalleryView`: NavigationStack + List grouped by group + scrollable detail
- `PrototypeFixtures`: books / search / bookDetail / tocItems / replaceRules / sources / discover / rss / webdav / sync fixtures

---

## 6. App 主导航结果

| 检查项 | 结果 |
|---|---|
| 主底栏 | 书架 / 发现 / 书源 / 我的 |
| 阅读不是底栏 | PASS |
| 设置不是底栏（归入「我的」） | PASS |
| 搜索不是独立底栏 | PASS |

---

## 7. 38 个 Prototype Entry 覆盖清单

| 分组 | 页面 | Entry ID | 覆盖 |
|---|---|---|---|
| App / Navigation | App Shell / Main Tabs (4 tabs) | app-shell | PASS |
| Bookshelf | 书架封面模式 | bookshelf-cover | PASS |
| Bookshelf | 书架列表模式 | bookshelf-list | PASS |
| Bookshelf | 书架空状态 | bookshelf-empty | PASS |
| Search / Detail | 搜索首页 | search-home | PASS |
| Search / Detail | 搜索结果 | search-results | PASS |
| Search / Detail | 搜索空状态 | search-empty | PASS |
| Search / Detail | 搜索错误状态 | search-error | PASS |
| Search / Detail | 书籍详情 | book-detail | PASS |
| Search / Detail | 书籍详情 TOC 预览 | book-detail-toc | PASS |
| Reader | 阅读页基础控制层 | reader-base | PASS |
| Reader | 阅读页搜索 overlay | reader-search | PASS |
| Reader | 阅读页自动翻页 overlay | reader-autoscroll | PASS |
| Reader | 阅读页内容替换 overlay | reader-replace | PASS |
| Reader | 阅读页夜间状态（非弹窗） | reader-night | PASS |
| Reader | 阅读页目录/书签 overlay | reader-directory | PASS |
| Reader | 阅读页朗读 overlay | reader-tts | PASS |
| Reader | 阅读页界面 overlay | reader-appearance | PASS |
| Reader | 阅读页设置 overlay | reader-settings | PASS |
| Source Management | 书源管理列表 | source-list | PASS |
| Source Management | 书源详情 | source-detail | PASS |
| Source Management | 书源编辑 / 导入状态 | source-edit-import | PASS |
| Source Management | 书源测试 / 禁用 / 错误状态 | source-test-error | PASS |
| Discover | 发现首页 | discover-home | PASS |
| RSS | RSS 列表 | rss-list | PASS |
| RSS | RSS 详情 | rss-detail | PASS |
| RSS | RSS 订阅管理 | rss-subscriptions | PASS |
| WebDAV | WebDAV 配置 | webdav-config | PASS |
| Sync | 备份设置 | backup-settings | PASS |
| Sync | 阅读进度同步状态 | sync-progress | PASS |
| WebDAV | 远程 WebDAV 书籍 | remote-webdav-books | PASS |
| Sync | 同步错误 / WebDAV auth error | sync-error | PASS |
| Settings | 全局设置（我的页面内） | global-settings | PASS |
| State Pages | loading 状态页 | state-loading | PASS |
| State Pages | empty 状态页 | state-empty | PASS |
| State Pages | error 状态页 | state-error | PASS |
| State Pages | offline 状态页 | state-offline | PASS |
| State Pages | permission required 状态页 | state-permission | PASS |

---

## 8. 阅读页规则检查

| # | 规则 | 结果 |
|---|---|---|
| 1 | 快捷按钮无文字标签（QuickButton 只有 image + accessibilityLabel） | PASS |
| 2 | 夜间模式不是弹窗（ReaderNightStatePrototype 内无 .sheet/.alert/Dialog） | PASS |
| 3 | 内容替换只显示当前书籍匹配规则 | PASS |
| 4 | 浮动页内控制是本章内上一页/下一页 | PASS |
| 5 | 不使用 skip_previous / skip_next 语义 | PASS |
| 6 | 阅读页底栏设置不包含 WebDAV / 书源 / RSS | PASS |
| 7 | 目录页有目录/书签 tab + 分级小字 + 右侧常驻进度条 + 书签标识 + 当前阅读标识 | PASS |
| 8 | 朗读内部不使用章节跳转语义 | PASS |
| 9 | 亮度条有自动亮度图标 + 左右停靠箭头 | PASS |
| 10 | 内容替换不能显示全局规则库 | PASS |

---

## 9. Boundary / Safety 检查

| 检查项 | 结果 |
|---|---|
| check_ios_boundary.sh (79 files) | PASS, 0 violations |
| 未引用 parser internals | PASS |
| 无 WebView UI | PASS |
| 无真实网络 | PASS |
| 未接真实 WebDAV/RSS/同步 | PASS |
| 未修改 Reader-Core | PASS |

---

## 10. 测试结果

| 命令 | 结果 |
|---|---|
| `bash scripts/check_ios_boundary.sh` | PASS (79 files, 0 violations) |
| `swift build --target ReaderApp` | macOS API errors（预存，非本轮引入） |
| Entry 数量 | 38 ✓ |

---

## 11. 已知非阻塞问题

- `navigationBarTitleDisplayMode` 在 macOS 不可用（预存，iOS target 正常）
- `CGColor.systemGray6` 在 macOS 不可用（预存，iOS target 正常）
- ReaderAppTests macOS target 预存测试问题（非本轮引入，不阻塞 Prototype Gallery）

---

## 12. P0 问题

无。

## 13. P1 问题

无。

## 14. 是否建议人工校对

建议人工校对 iOS Prototype Gallery。
