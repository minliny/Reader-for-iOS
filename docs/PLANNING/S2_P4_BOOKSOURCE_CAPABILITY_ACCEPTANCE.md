# S2.P4 书源管理能力层综合验收

## 1. 本轮结论

**结论**: `BOOKSOURCE_CAPABILITY_ACCEPTED_ENV_UNVERIFIED`

**说明**:
- S2.P0-S2.P3 文档一致性已修正
- S2 阶段书源管理能力层已形成本仓闭环
- 测试覆盖核心契约场景
- 边界检查通过
- Swift 编译在 Trae 环境未验证
- S2 阶段可以关闭，等待本地编译验证

## 2. S2.P0-S2.P3 文档一致性修正

| 文档 | 修正项 | 说明 |
|------|--------|------|
| S2.P0 | 结论修正 | BOOKSOURCE_CAPABILITY_READY → BOOKSOURCE_TEST_CONTRACT_READY_ENV_UNVERIFIED |
| S2.P0 | 测试覆盖率 | 移除未经工具验证的百分比 |
| S2.P1 | 测试覆盖率 | 移除 89% 表述，改为描述新增测试 |
| S2.P1 | 重复导入策略 | 已由 S2.P3 明确为 replace/update |
| S2.P2 | 新增测试文件 | 明确为 BookSourceSelectionPersistenceTests.swift |
| S2.P3 | 重复导入策略风险 | 修正为"相同 id replace/update 是明确更新语义" |

## 3. 真实文件路径

| 文件 | 状态 | 用途 |
|------|------|------|
| `iOS/App/Persistence/BookSourceStore.swift` | ✅ | 书源持久化存储 |
| `iOS/CoreIntegration/DefaultBookSourceDecoder.swift` | ✅ | 书源 JSON 解码 |
| `iOS/CoreBridge/ReaderCoreServiceProvider.swift` | ✅ | 书源验证服务 |
| `iOS/CoreBridge/MockReaderCoreService.swift` | ✅ | Mock 书源验证 |
| `iOS/CoreIntegration/InMemoryBookSourceRepository.swift` | ✅ | 内存书源仓库 |
| `iOS/Features/BookSources/BookSourceViewModel.swift` | ✅ | 书源导入 ViewModel |
| `iOS/AppSupport/Sources/SourceIdentity.swift` | ✅ | 书源标识 |
| `iOS/CoreBridge/SourceIdentityFactory.swift` | ✅ | 书源标识工厂 |
| `iOS/Tests/ReaderAppPersistenceTests/PersistencePublicSurfaceTests.swift` | ✅ | 持久化测试 |
| `iOS/Tests/ShellSmokeTests/BookSourceDecoderContractTests.swift` | ✅ | 解码契约测试 |
| `iOS/Tests/ReaderAppPersistenceTests/BookSourceSelectionPersistenceTests.swift` | ✅ | 选择持久化测试 |
| `iOS/Tests/ReaderAppPersistenceTests/BookSourceStoreImportErrorContractTests.swift` | ✅ | 导入错误契约测试 |

## 4. S2 能力验收矩阵

| 能力项 | 状态 | 测试覆盖 |
|--------|------|----------|
| 书源 JSON 解码成功 | ✅ 已实现 | ✅ BookSourceDecoderContractTests |
| 书源 JSON 解码失败 | ✅ 已实现 | ✅ BookSourceDecoderContractTests |
| 多余字段处理 | ✅ 已实现 | ✅ JSONDecoder 自动忽略 |
| 数组 JSON 支持 | ❌ 未支持 | ⚠️ 仅支持单个书源 |
| BookSourceStore 保存/读取 | ✅ 已实现 | ✅ PersistencePublicSurfaceTests |
| 重复导入相同 id replace/update | ✅ 已实现 | ✅ BookSourceStoreImportErrorContractTests |
| 不同 id 共存 | ✅ 已实现 | ✅ BookSourceStoreImportErrorContractTests |
| 无 id 自动生成 | ✅ 已实现 | ✅ BookSourceDecoderContractTests |
| selectedSourceId 保存/读取 | ✅ 已实现 | ✅ BookSourceSelectionPersistenceTests |
| selectedSourceId 清理 | ✅ 已实现 | ✅ BookSourceSelectionPersistenceTests |
| 删除选中书源清理 selectedSourceId | ✅ 已实现 | ✅ BookSourceSelectionPersistenceTests |
| 删除非选中书源不影响 selectedSourceId | ✅ 已实现 | ✅ BookSourceSelectionPersistenceTests |
| selectedSourceId 指向不存在书源时 resolve 行为 | ✅ 已实现 | ✅ 返回 nil |
| book_sources.json 损坏行为 | ✅ 已实现 | ✅ 抛 DecodingError |
| selection 文件损坏行为 | ✅ 已实现 | ✅ 返回 nil |
| Store 错误向上抛出或静默处理规则 | ✅ 已文档化 | ✅ 部分测试覆盖 |
| 与 Reader-Core 的边界 | ✅ 清晰 | ✅ 边界检查通过 |

## 5. BookSourceStore 当前契约

### API 清单

| 方法 | 输入 | 输出 | 错误处理 |
|------|------|------|----------|
| `load()` | 无 | `[BookSource]` | DecodingError 向上抛 |
| `save(_:)` | `[BookSource]` | 无 | EncodingError/FileManager.Error 向上抛 |
| `add(_:)` | `BookSource` | 无 | 继承 save() |
| `delete(id:)` | `String` | 无 | 不存在 id 静默处理 |
| `update(_:)` | `BookSource` | 无 | 不存在 id 静默处理 |
| `toggleEnabled(id:)` | `String` | 无 | 不存在 id 静默处理 |
| `loadSelectedSourceId()` | 无 | `String?` | 损坏返回 nil |
| `saveSelectedSourceId(_:)` | `String?` | 无 | EncodingError/FileManager.Error 向上抛 |
| `clearSelectedSourceId()` | 无 | 无 | 继承 save() |
| `resolveSelectedSource(from:)` | `[BookSource]` | `BookSource?` | 无错误 |
| `clearCache()` | 无 | 无 | 无 |

### 重复导入策略

| 场景 | 行为 |
|------|------|
| 有 id + 已存在 | replace/update |
| 有 id + 不存在 | 追加 |
| 无 id | 生成 UUID + 追加 |

## 6. DefaultBookSourceDecoder 当前契约

| 契约项 | 说明 |
|--------|------|
| 输入格式 | 单个书源 JSON |
| 输出类型 | `BookSource` |
| 错误类型 | `DecodingError` |
| 多余字段 | JSONDecoder 自动忽略 |
| 必填字段 | 无强制校验 |

## 7. selectedSourceId 当前契约

| 契约项 | 说明 |
|--------|------|
| 存储位置 | `ApplicationSupport/ReaderApp/book_source_selection.json` |
| 初始状态 | nil |
| 删除选中书源 | 自动清理 |
| resolve 失效 id | 返回 nil |

## 8. 重复导入当前契约

| 策略 | 实现 |
|------|------|
| 相同 id replace/update | ✅ 已实现 |
| 不同 id 共存 | ✅ 已实现 |
| 无 id 自动生成 | ✅ 已实现 |
| 风险 | 用新导入内容覆盖旧内容，属于明确更新语义 |

## 9. 错误处理当前契约

| 操作 | 错误类型 | 处理方式 |
|------|----------|----------|
| load() | DecodingError | 向上抛出 |
| save() | EncodingError/FileManager.Error | 向上抛出 |
| add() | 继承 save() | 向上抛出 |
| delete(id:) | 无 | 幂等，静默处理 |
| update(_:) | 无 | 幂等，静默处理 |
| loadSelectedSourceId() | 无 | 损坏返回 nil |
| saveSelectedSourceId(_:) | EncodingError/FileManager.Error | 向上抛出 |

## 10. 测试覆盖与环境限制

### 测试文件清单

| 文件 | 测试数 | 覆盖 |
|------|--------|------|
| PersistencePublicSurfaceTests.swift | 5+ | BookSourceStore 基本操作 |
| BookSourceDecoderContractTests.swift | 11 | 解码契约、重复导入、损坏数据 |
| BookSourceSelectionPersistenceTests.swift | 10 | selectedSourceId 持久化 |
| BookSourceStoreImportErrorContractTests.swift | 11 | 导入错误、replace/update |

### 环境限制

| 限制 | 说明 |
|------|------|
| Trae 无 Swift/Xcode | 无法执行 swift build/test |
| Trae 无 Reader-Core | 无法解析 package 依赖 |
| 边界检查 | ✅ PASS (checked_files=61) |
| 本地编译验证 | 待执行 |

## 11. 剩余 P0 / P1 / P2 缺口

### P0 必须解决

| ID | 缺口 | 状态 |
|----|------|------|
| 无 | - | - |

### P1 应尽快解决

| ID | 缺口 | 优先级 | 说明 |
|----|------|--------|------|
| P1-3 | 删除/切换失败状态 | 中 | ViewModel 层定义失败状态 |
| P1-4 | 删除与清理原子性 | 中 | 当前不支持事务回滚 |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 迁移版本字段 | 低 |
| P2-2 | 书源分组/排序 | 低 |
| P2-3 | 批量导入 | 中 |
| P2-4 | 部分损坏 JSON 处理 | 中 |
| P2-5 | defaultSourceId 持久化 | 低 |
| P2-6 | 基于 URL/名称的去重策略 | 中 |
| P2-7 | 数组 JSON 支持 | 中 |

## 12. 是否允许关闭 S2 阶段

**结论**: 可以关闭，但需本地编译验证

**理由**:
- 书源管理能力层已形成本仓闭环
- 核心契约已测试覆盖（除编译验证外）
- 边界检查通过
- 无阻断性问题
- Swift 编译待本地验证

**本地验证清单**:
- [ ] `cd iOS && swift package resolve`
- [ ] `cd iOS && swift build`
- [ ] `cd iOS && swift test`
- [ ] 所有新增测试通过

## 13. S3 推荐任务

**任务 ID**: S3.P0  
**任务名称**: 搜索流程 Mock/Real 路由契约与能力审计

**任务内容**:
1. 审计当前搜索功能 Mock 实现状态
2. 确认 SearchService 接口契约
3. 验证搜索结果与书源选择的连接点
4. 设计从 Mock 切换到 Real Core 的最小路径

**前提条件**: 无需 Reader-Core（可在 Mock 模式下进行）

**注意**: S3 搜索流程将使用 S2 的 selectedSourceId 持久化能力
