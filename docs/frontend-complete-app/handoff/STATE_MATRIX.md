# State Matrix

| 状态 | 场景 | 覆盖模块 | 处理方式 |
|---|---|---|---|
| loading | 加载中 | 搜索、全局、同步 | 展示进度，不阻塞返回 |
| empty | 空状态 | 书架、搜索、RSS | 提供导入或重试入口 |
| error | 错误 | 搜索、RSS、全局 | 展示错误与重试 |
| offline | 离线 | 全局、书架 | 提示已缓存可读 |
| disabled | 停用 | 书源 | 不可用原因与启用入口 |
| permission required | 权限需要 | 本地书导入 | 请求存储权限 |
| local file error | 本地文件错误 | 导入 | 提示格式或读取失败 |
| network source error | 网络书源错误 | 搜索、书源测试 | 重试或停用书源 |
| WebDAV auth error | WebDAV 认证错误 | 同步 | 重新登录 |
| sync conflict | 同步冲突 | 进度同步 | 选择本地或远程 |
| import success | 导入成功 | 本地书、书源、RSS | 进入详情或列表 |
| import failure | 导入失败 | 本地书、书源、RSS | 查看原因并重试 |
