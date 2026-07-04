# Route Map

正式 App 一级主导航固定为 4 项：书架 / 发现 / RSS / 设置。搜索、书籍详情和阅读页均为
二级或功能 route，不作为底部主按钮。`route ID` 与
`docs/cross-platform-ui/CROSS_PLATFORM_ROUTE_MATRIX.md` 保持一致；URL 只作为平台映射。

| route ID | URL | 页面 | 所属主模块 | 入口来源 | 返回 route ID | 主要状态 |
|---|---|---|---|---|---|---|
| `bookshelf` | `/bookshelf` | 书架 | 书架 | 启动 / 主导航 | 退出 App | 封面、列表、loading、empty、error、offline |
| `bookshelf_groups` | `/bookshelf/groups` | 分组管理 | 书架 | 书架更多 | `bookshelf` | 默认、编辑 |
| `bookshelf_import` | `/bookshelf/import` | 本地书导入 | 书架 | 空状态 / 更多 | `bookshelf` | 权限、选择、导入中、成功、部分失败、失败 |
| `search` | `/search` | 搜索首页 | 书架 / 全局功能 | 页面内搜索入口 | 来源 route | 首页、历史、loading、empty、error |
| `search_results` | `/search/results` | 搜索结果 | 书架 / 全局功能 | `search` | `search` | loading、empty、error、results |
| `detail/{detailUrl}` | `/book/detail/{detailUrl}` | 书籍详情 | 书架 / 搜索 | 搜索结果 / 书架 / 换源 | 来源 route | 详情、目录预览、已加入 |
| `reader` | `/reader/{bookId}` | 阅读页 | 书架 / 详情 | 书架 / 书籍详情 | 来源 route | 沉浸、控制层、覆盖层、运行态 |
| `discover` | `/discover` | 发现首页 | 发现 | 主导航 | `bookshelf` | 推荐、empty、error、offline |
| `rss_list` | `/rss_list` | RSS 列表 | RSS | 主导航 / 发现入口 | `discover` | 列表、loading、empty、error |
| `rss_detail/{rssId}` | `/rss_detail/{rssId}` | RSS 详情 | RSS | `rss_list` | `rss_list` | 详情、阅读状态、error |
| `rss_subscription` | `/rss_subscription` | RSS 订阅管理 | RSS | RSS 列表 | `rss_list` | 订阅、disabled、error |
| `sources` | `/sources` | 书源管理 | 设置 | 设置入口 | `global_settings` | 列表、disabled、error、test |
| `source_detail/{sourceId}` | `/source_detail/{sourceId}` | 书源详情 | 设置 | `sources` | `sources` | 规则预览、状态 |
| `source_edit/{sourceId}` | `/source_edit/{sourceId}` | 书源编辑 | 设置 | 详情 / 新增 | `sources` | 表单、URL 校验 |
| `source_import` | `/source_import` | 书源导入 | 设置 | `sources` | `sources` | JSON、URL、blank、error |
| `global_settings` | `/settings` | 全局设置 | 设置 | 主导航 | `bookshelf` | 通用、阅读、书源、同步、缓存、隐私、关于 |
| `webdav_config` | `/settings/webdav` | WebDAV 配置 | 设置 | 同步与备份 | `global_settings` | 未配置、已配置、auth error、offline |
| `backup_settings` | `/backup_settings` | 备份设置 | 设置 | 同步与备份 | `global_settings` | enabled、disabled、failure |
| `progress_sync` | `/progress_sync` | 阅读进度同步 | 设置 | 同步与备份 | `global_settings` | running、success、failure、conflict、offline |
| `remote_webdav_books` | `/remote_webdav_books` | 远程 WebDAV 书籍 | 设置 | WebDAV | `global_settings` | 列表、empty、error |
| `about` | `/about` | 关于版本 | 设置 | 设置 | `global_settings` | 版本、权限、隐私、日志 |
| `state/error/{message}` | `/state/error/{message}` | 全局错误状态 | 全局状态 | route fallback | 来源 route | error |
| `state/offline` | `/state/offline` | 全局离线状态 | 全局状态 | route fallback | 来源 route | offline |

跨平台矩阵未单列的 `bookshelf_groups`、`bookshelf_import`、`search_results` 是 Android
细分 route；其父 route 与命名约定仍按矩阵执行。项目不设 `mine`/“我的”主 Tab。
