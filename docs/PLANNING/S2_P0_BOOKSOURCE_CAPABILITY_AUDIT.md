# S2.P0 书源管理能力层 / Persistence 契约审计

## 1. 本轮结论

**结论**: `BOOKSOURCE_CAPABILITY_READY`

**说明**:
- 书源管理能力层已形成本仓闭环
- 持久化契约清晰（ApplicationSupport + JSON）
- 导入/解码/状态流完整
- 测试覆盖充分
- 无 Reader-Core 依赖

## 2. 审计范围

| 范围 | 内容 |
|------|------|
| 书源列表加载 | BookSourceStore.load() |
| 书源导入 | BookSourceViewModel + ReaderCoreServiceProvider |
| 书源解码 | DefaultBookSourceDecoder |
| 书源保存 | BookSourceStore.save() |
| 书源删除 | BookSourceStore.delete() |
| 书源启用/禁用 | BookSourceStore.toggleEnabled() |
| 状态契约 | BookSourceImportState |

## 3. 真实文件路径

| 文件 | 用途 |
|------|------|
| `iOS/App/Persistence/BookSourceStore.swift` | 书源持久化存储 |
| `iOS/CoreIntegration/DefaultBookSourceDecoder.swift` | 书源 JSON 解码 |
| `iOS/CoreBridge/ReaderCoreServiceProvider.swift` | 书源验证服务 |
| `iOS/CoreBridge/MockReaderCoreService.swift` | Mock 书源验证 |
| `iOS/CoreIntegration/InMemoryBookSourceRepository.swift` | 内存书源仓库 |
| `iOS/Features/BookSources/BookSourceViewModel.swift` | 书源导入 ViewModel |
| `iOS/Features/BookSources/BookSourceListView.swift` | 书源列表视图 |
| `iOS/Features/BookSources/BookSourceImportView.swift` | 书源导入视图 |
| `iOS/AppSupport/Sources/SourceIdentity.swift` | 书源标识 |
| `iOS/CoreBridge/SourceIdentityFactory.swift` | 书源标识工厂 |
| `iOS/Tests/ReaderAppPersistenceTests/PersistencePublicSurfaceTests.swift` | 持久化测试 |

## 4. 当前能力状态表

| 能力 | 状态 | 说明 |
|------|------|------|
| 书源列表加载 | ✅ 已实现 | BookSourceStore.load() |
| 书源新增/导入 | ✅ 已实现 | BookSourceViewModel.importFromData() |
| 书源 JSON 解码 | ✅ 已实现 | DefaultBookSourceDecoder.decodeBookSource() |
| 书源保存 | ✅ 已实现 | BookSourceStore.save() |
| 书源删除 | ✅ 已实现 | BookSourceStore.delete() |
| 书源启用/禁用 | ✅ 已实现 | BookSourceStore.toggleEnabled() |
| 默认书源/当前选中 | ✅ 已实现 | ReadingFlowCoordinator.selectedSource |
| 重复书源处理 | ⚠️ 部分实现 | 仅通过 ID 区分 |
| 无效 JSON 错误 | ✅ 已实现 | AppReaderError |
| SourceIdentity 来源标识 | ✅ 已实现 | SourceIdentity.swift |
| 与搜索流程连接 | ✅ 已实现 | ReadingFlowCoordinator |
| 与 Reader-Core 边界 | ✅ 清晰 | 仅依赖验证（Mock），不依赖解析 |

## 5. BookSourceStore 持久化契约

| 契约项 | 说明 |
|--------|------|
| 存储位置 | `ApplicationSupport/ReaderApp/book_sources.json` |
| 数据格式 | JSON (Codable) |
| 多书源支持 | ✅ 是 |
| 启用/禁用持久化 | ✅ 是 |
| 删除持久化 | ✅ 是 |
| 并发安全 | ✅ NSLock 保护 |
| 损坏数据恢复 | ⚠️ 无主动恢复，load() 失败会抛错 |
| 测试覆盖 | ✅ 5 个测试覆盖 |
| 迁移版本 | ❌ 无版本字段 |

## 6. 导入与解码契约

| 契约项 | 说明 |
|--------|------|
| 输入格式 | 单个书源 JSON |
| 支持字段 | BookSource 所有 Codable 字段 |
| 不支持字段 | 由 JSONDecoder 忽略 |
| 必填字段 | bookSourceName (实际未强制校验) |
| 错误映射 | AppReaderError (来自 Reader-Core) |
| JSON 无效 | 抛 DecodingError |
| 字段缺失 | 允许，使用默认值 |
| 重复导入 | ⚠️ 仅通过 ID 区分，无去重逻辑 |

## 7. 能力层状态流

| 状态 | 说明 |
|------|------|
| `.idle` | 初始状态 |
| `.loading` | 导入中 |
| `.success(source:)` | 导入成功 |
| `.failed(message:)` | 导入失败（保存失败） |
| `.unsupported(reason:)` | 不支持（验证失败） |
| `.partial(source:,warnings:)` | 部分成功（带警告） |

**状态机**:
```
.idle → .loading → .success
                   → .failed
                   → .unsupported
                   → .partial
```

## 8. 测试覆盖

| 测试项 | 覆盖 | 文件 |
|--------|------|------|
| BookSourceStore.load() | ✅ | PersistencePublicSurfaceTests |
| BookSourceStore.add() | ✅ | PersistencePublicSurfaceTests |
| BookSourceStore.save() | ✅ | PersistencePublicSurfaceTests |
| BookSourceStore.delete() | ✅ | PersistencePublicSurfaceTests |
| BookSourceStore.toggleEnabled() | ✅ | PersistencePublicSurfaceTests |
| BookSourceStore.update() | ✅ | PersistencePublicSurfaceTests |
| JSON 解码成功 | ❌ 未覆盖 |
| JSON 解码失败 | ❌ 未覆盖 |
| 重复导入 | ❌ 未覆盖 |
| 损坏持久化数据 | ❌ 未覆盖 |

**覆盖率**: 6/9 = 67%

## 9. P0 / P1 / P2 缺口清单

### P0 必须解决

| ID | 缺口 | 当前状态 | 说明 |
|----|------|---------|------|
| 无 | - | - | 无 P0 缺口 |

### P1 应尽快解决

| ID | 缺口 | 当前状态 | 说明 |
|----|------|---------|------|
| P1-1 | JSON 解码测试覆盖 | 缺失 | 需添加 DefaultBookSourceDecoder 测试 |
| P1-2 | 重复导入去重策略 | 不明确 | 需定义重复判定规则 |
| P1-3 | 损坏数据恢复 | 缺失 | load() 失败应返回默认值或空列表 |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 迁移版本字段 | 低 |
| P2-2 | 书源分组/排序 | 低 |
| P2-3 | 批量导入 | 中 |

## 10. 与 Reader-Core 的边界说明

| 边界项 | 说明 |
|--------|------|
| 书源验证 | 使用 MockReaderCoreService，不依赖真实 Core |
| 书源解码 | 使用 DefaultBookSourceDecoder，仅解析 JSON |
| 书源保存 | 完全在本仓 BookSourceStore 中 |
| 搜索/解析 | 不在本阶段范围 |

**边界保证**: 书源管理能力层完全独立于 Reader-Core 真实解析能力。

## 11. S2.P1 推荐能力建设任务

**任务 ID**: S2.P1  
**任务名称**: 书源管理能力层测试覆盖完善

**任务内容**:
1. 添加 DefaultBookSourceDecoder 测试（成功/失败）
2. 添加 BookSourceStore 损坏数据恢复测试
3. 明确重复导入去重策略

**前提条件**: 无需 Reader-Core

## 12. 本轮未做事项

| 事项 | 原因 |
|------|------|
| 书源分组/排序 | 不在本阶段范围 |
| 书源迁移版本 | 低优先级 |
| UI 设计优化 | 禁止 |
