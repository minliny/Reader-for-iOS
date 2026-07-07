# iOS Host Persistence Upgrade Plan

## 结论

当前 `HostCacheStore` / `HostPersistenceStore` 只满足 Core Host capability
smoke 与本地开发验证，不应作为正式业务持久层完成态。

- `cache.*`：允许是易失缓存，不能承载 DomainState。
- `persistence.*`：必须升级为可恢复、可迁移、可审计的本地存储。
- bookshelf / RSS subscription / search history / reading progress 等业务数据仍归
  Core DomainState；iOS Host 只提供 Core bridge 需要的存储能力。

## 当前状态

| 能力 | 当前实现 | 可接受范围 | 不足 |
| --- | --- | --- | --- |
| `cache.get/put` | 内存 dictionary | 单进程临时缓存、测试、非关键响应缓存 | App 重启丢失，不可作为 DomainState |
| `persistence.get/put` | `UserDefaults` | 小体积 smoke、feature flag、简单 key/value | 无 schema/migration，revision 只是递增字符串，冲突语义弱 |

## 目标实现

正式实现应新增 `HostPersistenceBackend` 抽象，默认生产实现使用 SQLite 或 Realm。

要求：

1. namespace + key 复合主键。
2. value 与 valueBase64 明确区分，避免二进制值被误当字符串。
3. revision 使用单调版本或 content hash，支持 expectedRevision 乐观锁。
4. revision mismatch 返回结构化 `CONFLICT`，不能落到通用 `INTERNAL`。
5. 支持 schema version 与迁移。
6. 支持按 namespace 清理、导出、诊断。
7. 不在 Host 层理解 bookshelf/RSS/search 的业务语义，业务事实仍由 Core 定义。

## 推荐分阶段

### P0：语义修正

- 保留当前 `UserDefaults` backend。
- 修正 revision conflict 的错误码与响应形状。
- 增加 value/valueBase64 往返测试。
- 明确 `cache.*` 是 volatile cache。

验收：

- `persistence.put(expectedRevision: stale)` 返回 `CONFLICT`。
- `persistence.get` 能区分 missing、string value、base64 value。
- App 重启后 `persistence.*` 测试数据仍可读取。

### P1：生产 backend

- 新增 `SQLiteHostPersistenceStore` 或 `RealmHostPersistenceStore`。
- 表结构包含：namespace、key、value_text、value_blob、revision、created_at、updated_at。
- 增加 migration 版本。
- `HostRequestRouter` 通过依赖注入选择 backend。

验收：

- 并发写入同 key 时 expectedRevision 冲突稳定可复现。
- 1,000 条记录读写、重启恢复、namespace 清理通过。
- 与 Core host request round trip 测试共用同一生产 backend。

### P2：DomainState 接入证明

- bookshelf / RSS subscription / search history 只能通过 Core bridge 读写。
- iOS reducer/UI 不直接写 Host persistence。
- 增加至少一个真实业务流 proof：Core 写入 -> App 重启 -> Core 读取 -> UI 渲染。

验收：

- UI 层没有直接依赖 persistence backend。
- Core bridge 是业务状态读写入口。
- 设备或 simulator app-process evidence 覆盖重启恢复路径。

## 非目标

- 不把 `cache.*` 升级成业务数据库。
- 不在 iOS Host 里重新定义 bookshelf / RSS / search 的业务模型。
- 不用本计划替代 Core 的同步冲突策略；Host 只提供本地能力。
