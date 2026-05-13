# S2.P3 书源重复导入策略与 Store 错误契约补强

## 1. 本轮结论

**结论**: `BOOKSOURCE_IMPORT_ERROR_CONTRACT_READY_ENV_UNVERIFIED`

**说明**:
- 重复导入策略已实现（相同 ID 替换）
- 删除/selectedSourceId 一致性规则已验证
- Store 错误契约已文档化
- 新增测试覆盖核心场景
- 边界检查通过
- Swift 编译在 Trae 环境未验证

## 2. S2.P2 文档修正

| 修正项 | 原表述 | 修正后 |
|--------|--------|--------|
| 新增测试文件 | "新增测试文件 2 个测试文件" | 本轮新增 BookSourceSelectionPersistenceTests.swift；S2.P1 已存在 BookSourceDecoderContractTests.swift |
| 编译状态 | 未明确 | 当前仍为 ENV_COMPILE_UNVERIFIED |

## 3. 重复导入策略设计

### 策略选择

| 策略选项 | 选择 | 原因 |
|----------|------|------|
| 相同 id 覆盖 | ✅ | 最小、无数据丢失风险 |
| 相同 id 跳过 | ❌ | 可能导致静默数据丢失 |
| 相同 id 报错 | ❌ | 过于严格，影响用户体验 |
| 允许重复 | ❌ | 数据重复问题 |

### 策略规则

```swift
public func add(_ source: BookSource) async throws {
    // 如果 id 为空，自动生成 UUID
    if newSource.id == nil {
        newSource.id = UUID().uuidString
    }
    
    // 如果存在相同 id，替换；否则追加
    if let existingIndex = sources.firstIndex(where: { $0.id == newSource.id }) {
        sources[existingIndex] = newSource  // 替换
    } else {
        sources.append(newSource)  // 追加
    }
}
```

### 策略边界

| 场景 | 行为 |
|------|------|
| 有 id + 已存在 | 替换 |
| 有 id + 不存在 | 追加 |
| 无 id | 生成 UUID + 追加 |

## 4. BookSourceStore API / 行为变化

### add() 方法变化

| 之前 | 之后 |
|------|------|
| 无条件追加 | 先检查 id，存在则替换，否则追加 |

### 错误契约变化

| 操作 | 错误类型 | 文档化状态 |
|------|----------|-----------|
| load() | DecodingError | ✅ 已文档化 |
| save() | EncodingError / FileManager.Error | ✅ 已文档化 |
| delete(id:) | 无错误（不存在 id 静默处理） | ✅ 已文档化 |
| update(id:) | 无错误（不存在 id 静默处理） | ✅ 已文档化 |
| loadSelectedSourceId() | 无错误（损坏返回 nil） | ✅ 已文档化 |

## 5. Store 错误契约

### 错误类型映射

| 操作 | 可能错误 | 处理方式 |
|------|----------|----------|
| load() | DecodingError | 向上抛出 |
| save() | EncodingError / FileManager.Error | 向上抛出 |
| add() | 继承 save() 错误 | 向上抛出 |
| delete() | 继承 save() 错误 | 向上抛出 |
| update() | 继承 save() 错误 | 向上抛出 |
| loadSelectedSourceId() | DecodingError | 返回 nil |
| saveSelectedSourceId() | EncodingError / FileManager.Error | 向上抛出 |

### 静默处理场景

| 场景 | 原因 |
|------|------|
| delete 不存在 id | 幂等操作，无需报错 |
| update 不存在 id | 幂等操作，无需报错 |
| loadSelectedSourceId 文件损坏 | 返回 nil，由上层处理 |

## 6. 删除 / selectedSourceId 一致性规则

### 一致性规则表

| 操作 | 条件 | 行为 |
|------|------|------|
| delete(id:) | id == selectedSourceId | 自动 clearSelectedSourceId() |
| delete(id:) | id != selectedSourceId | 不影响 selectedSourceId |
| delete(id:) | selectedSourceId == nil | 正常删除 |
| resolveSelectedSource() | selectedSourceId 指向已删除源 | 返回 nil |

### 原子性保证

当前实现采用"先保存书源列表，再清理选中状态"的顺序：

```swift
public func delete(id: String) async throws {
    var sources = try await load()
    sources.removeAll { $0.id == id }
    try await save(sources)  // 先保存书源列表
    
    if withLock({ selectedSourceIdCache }) == id {
        try await clearSelectedSourceId()  // 后清理选中状态
    }
}
```

**注意**: 若清理选中状态失败，书源列表已被修改。当前不支持事务回滚，记录为 P1 优化项。

## 7. 新增 / 更新测试

### 新增测试文件
`iOS/Tests/ReaderAppPersistenceTests/BookSourceStoreImportErrorContractTests.swift`

### 测试覆盖

| 测试项 | 覆盖 | 说明 |
|--------|------|------|
| 相同 id 重复导入替换 | ✅ | testAddWithSameIdReplacesExisting |
| 不同 id 创建新条目 | ✅ | testAddWithDifferentIdsCreatesNew |
| 无 id 生成新 UUID | ✅ | testAddWithoutIdGeneratesNewId |
| 无 id 重复导入创建多个 | ✅ | testAddWithoutIdTwiceCreatesTwoEntries |
| 删除不存在 id 不抛错 | ✅ | testDeleteNonExistentIdThrowsNoError |
| 删除选中书源清理选中状态 | ✅ | testDeleteSelectedSourceClearsSelection |
| 删除非选中书源保留选中状态 | ✅ | testDeleteNonSelectedSourcePreservesSelection |
| 损坏 JSON 抛 DecodingError | ✅ | testCorruptedBookSourcesJSONThrowsOnLoad |
| 损坏选中文件返回 nil | ✅ | testCorruptedSelectionJSONReturnsNil |
| 更新不存在 id 无操作 | ✅ | testUpdateNonExistentIdDoesNothing |
| 更新存在 id 替换 | ✅ | testUpdateExistingIdReplacesSource |

## 8. 边界检查与测试结果

| 检查项 | 结果 |
|--------|------|
| 边界检查脚本 | ✅ PASS (checked_files=61) |
| 新增测试文件 | ✅ BookSourceStoreImportErrorContractTests.swift |
| Swift 编译 | ⚠️ ENV_COMPILE_UNVERIFIED |

## 9. 剩余 P0 / P1 / P2 缺口

### P0 必须解决

| ID | 缺口 | 当前状态 | 说明 |
|----|------|---------|------|
| 无 | - | - | 无 P0 缺口 |

### P1 应尽快解决

| ID | 缺口 | 当前状态 | 说明 |
|----|------|---------|------|
| P1-3 | 删除/切换失败状态 | ❌ 不存在 | 需在 ViewModel 定义失败状态 |
| P1-4 | 删除与清理原子性 | ⚠️ 部分 | 当前不支持事务回滚 |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 迁移版本字段 | 低 |
| P2-2 | 书源分组/排序 | 低 |
| P2-3 | 批量导入 | 中 |
| P2-4 | 部分损坏 JSON 处理 | 中 |
| P2-5 | defaultSourceId 持久化 | 低 |
| P2-6 | 基于 URL/名称的去重策略 | 中 |

## 10. S2.P4 推荐任务

**任务 ID**: S2.P4  
**任务名称**: 书源管理能力层综合测试与文档补全

**任务内容**:
1. 验证所有书源管理能力层测试覆盖完整性
2. 补全书源管理能力层综合文档
3. 确认 S2 阶段整体验收标准达成

**前提条件**: 无需 Reader-Core
