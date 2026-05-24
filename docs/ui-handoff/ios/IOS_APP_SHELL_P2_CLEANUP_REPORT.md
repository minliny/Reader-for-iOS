# iOS App Shell P2 Cleanup Report

## 1. 总体结论

**IOS_APP_SHELL_P2_CLEANUP_READY**

## 2. 本轮目标

处理剩余两个 P2：
- P2-001：书架/书源页面英文文案清理
- P2-002：补充 DEBUG-only ReaderView fixture 复测路径

不接真实数据，不做生产 UI 精装。

## 3. 输入状态

| 文档 | 状态 |
|---|---|
| `IOS_READER_BRIGHTNESS_LAYOUT_DEVICE_REVIEW.md` | 已参考 |
| `IOS_APP_SHELL_ALIGNMENT_FIX_QUEUE.md` | 已读取 |
| `IOS_APP_SHELL_VISUAL_BEHAVIOR_DEVICE_REVIEW.md` | 已参考 |

## 4. P2-001 英文文案处理结果

### 修改文件

`iOS/Features/Bookshelf/BookshelfView.swift`:
| 原文 | 改为 |
|---|---|
| `"Bookshelf"` (title) | `"书架"` |
| `"Loading..."` | `"加载中..."` |
| `"Empty Bookshelf"` | `"书架为空"` |
| `"Add books from search results"` | `"从搜索结果添加书籍"` |
| `"Error"` | `"错误"` |
| `"Book Info"` | `"书籍信息"` |
| `"Title"` | `"书名"` |
| `"Author"` | `"作者"` |
| `"Source"` | `"来源"` |
| `"Reading Progress"` | `"阅读进度"` |
| `"Progress"` | `"进度"` |
| `"Last Chapter"` | `"最后阅读"` |
| `"Added"` | `"添加时间"` |
| `"Done"` | `"完成"` |

`iOS/Features/BookSources/BookSourceListView.swift`:
| 原文 | 改为 |
|---|---|
| `"Book Sources"` (title) | `"书源"` |
| `"Dismiss"` | `"关闭"` |
| `"Loading sources..."` | `"加载书源中..."` |
| `"Book Source JSON"` | `"书源 JSON"` |
| `"Copy"` | `"复制"` |
| `"Done"` | `"完成"` |
| `"No Book Sources"` | `"暂无书源"` |
| `"Import a book source to get started"` | `"导入书源以开始使用"` |
| `"Import Book Source"` | `"导入书源"` |
| `"Enabled (N)"` | `"已启用 (N)"` |
| `"Disabled (N)"` | `"已禁用 (N)"` |
| `"Failed to load sources: ..."` | `"加载书源失败: ..."` |
| `"Failed to toggle source: ..."` | `"切换书源失败: ..."` |
| `"Failed to delete source: ..."` | `"删除书源失败: ..."` |

### 保留英文

- Developer Tools 区域：`"[DEBUG] Prototype Gallery"`、`"WebView Harness"` — 仅 Debug 可见，调试入口保留技术名
- `ReaderStageActionBar` 中的 label 未修改（非本轮 scope）

## 5. P2-002 ReaderView Fixture 路径结果

### 入口

- 位置：我的 → Developer Tools → `[DEBUG] ReaderView Fixture`（`#if DEBUG` 包裹）
- icon: `eye`

### 实现方式

1. `ReaderViewModel` 新增 `#if DEBUG` convenience init，接受 `fixtureContent: String`，直接构造 `ContentPage` 并 pre-load 为 `.loaded` 状态，绕开 `ReaderCoreServiceProvider` 网络调用
2. `ReaderView` 新增 `#if DEBUG` convenience init，使用上述 fixture view model
3. `MineTabView` Developer Tools Section 新增 NavigationLink

### 特性

| 检查项 | 结果 |
|---|---|
| 是否 `#if DEBUG` | 是 |
| Release 不可见 | 是 |
| 是否进入真实 ReaderView | 是（复用生产 `ReaderView`） |
| 是否 fixture-only | 是（`ContentPage` 使用硬编码测试文本） |
| 是否不接真实网络 | 是 |
| 是否不接 Reader-Core runtime | 是 |
| 是否用于验证 tab bar 隐藏 | 是（进入后应无底栏） |

## 6. Debug / Release 边界

| 入口 | Debug | Release | 位置 |
|---|---|---|---|
| `[DEBUG] Prototype Gallery` | 可见 | 不可见 | 我的 → Developer Tools |
| `WebView Harness` | 可见 | 不可见 | 我的 → Developer Tools |
| `[DEBUG] ReaderView Fixture` | 可见 | 不可见 | 我的 → Developer Tools |
| 生产主底栏四项 | 可见 | 可见 | TabView |

## 7. Boundary / Safety 检查

| 检查项 | 结果 |
|---|---|
| 是否未引用 parser internals | PASS |
| 是否无 WebView UI 承载生产主导航 | PASS |
| 是否无真实网络 | PASS |
| 是否未接真实 WebDAV/RSS/同步 | PASS |
| 是否未修改 Reader-Core | PASS |
| clean-room | PASS |

## 8. 测试 / Build 结果

| 命令 | 结果 |
|---|---|
| `bash scripts/check_ios_boundary.sh` | PASS（82 files, 0 violations） |
| `xcodebuild build -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` | **BUILD SUCCEEDED** |

## 9. 修改文件

| 文件 | 变更 |
|---|---|
| `iOS/Features/Bookshelf/BookshelfView.swift` | 修改 — 14 处英文文案 → 中文 |
| `iOS/Features/BookSources/BookSourceListView.swift` | 修改 — 14 处英文文案 → 中文 |
| `iOS/Features/Reader/ReaderViewModel.swift` | 修改 — 新增 `#if DEBUG` fixture convenience init |
| `iOS/Features/Reader/ReaderView.swift` | 修改 — 新增 `#if DEBUG` fixture convenience init |
| `iOS/Features/Mine/MineTabView.swift` | 修改 — Developer Tools 新增 `[DEBUG] ReaderView Fixture` 入口 |

新增文件：0。

## 10. P0 问题

无。

## 11. P1 问题

无。

## 12. P2 问题

无代码侧 P2。APP-SHELL-SIM-P2-001 / 002 代码修复已完成，等待 Codex 设备端复测确认。

## 13. 是否建议交给 Codex 复测

建议交给 Codex 复测英文文案和 ReaderView Fixture 路径。
