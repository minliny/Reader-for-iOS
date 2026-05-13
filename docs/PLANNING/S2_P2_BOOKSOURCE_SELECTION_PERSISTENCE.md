# S2.P2 书源选择状态持久化能力补强

## 1. 本轮结论

**结论**: `BOOKSOURCE_SELECTION_READY_ENV_UNVERIFIED`

**说明**:
- selectedSourceId 持久化能力已实现
- 删除一致性规则已实现
- 新增测试覆盖核心场景
- 边界检查通过
- Swift 编译在 Trae 环境未验证

## 2. S2.P1 文档修正

| 修正项 | 原表述 | 修正后 |
|--------|--------|--------|
| 测试覆盖率 | "测试覆盖率 89% (10/11)" | "新增若干契约测试覆盖核心场景" |
| 原因 | 基于百分比 | Swift 编译未验证，不使用未经工具验证的百分比 |

## 3. selectedSourceId / defaultSourceId 设计决策

| 决策项 | 选择 | 原因 |
|--------|------|------|
| selectedSourceId | ✅ 实现 | 核心用户场景 |
| defaultSourceId | ❌ 暂不实现 | 当前代码无明确需求 |
| 存储方式 | 独立文件 | 保持与 book_sources.json 分离 |
| 存储位置 | ApplicationSupport/ReaderApp/book_source_selection.json | 沿用现有目录 |
| 删除选中书源 | 自动清理 | selectedSourceId 被删除时自动清理 |

## 4. BookSourceStore API 变化

### 新增 API

| 方法 | 说明 |
|------|------|
| `loadSelectedSourceId() -> String?` | 加载当前选中书源 ID |
| `saveSelectedSourceId(_ sourceId: String?)` | 保存当前选中书源 ID |
| `clearSelectedSourceId()` | 清除当前选中书源 |
| `resolveSelectedSource(from sources:) -> BookSource?` | 从书源列表中解析选中书源 |

### 新增内部字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `selectionURL` | URL | 选中书源持久化文件路径 |
| `selectedSourceIdCache` | String? | 选中书源 ID 内存缓存 |

### 删除一致性规则

`delete(id:)` 方法现在会在删除选中书源时自动清理选中状态：
```swift
public func delete(id: String) async throws {
    var sources = try await load()
    sources.removeAll { $0.id == id }
    try await save(sources)
    
    if withLock({ selectedSourceIdCache }) == id {
        try await clearSelectedSourceId()
    }
}
```

## 5. 持久化契约

| 契约项 | 说明 |
|--------|------|
| 存储位置 | `ApplicationSupport/ReaderApp/book_source_selection.json` |
| 数据格式 | JSON (Codable) via SelectionWrapper |
| 初始状态 | nil (无选中) |
| 失效策略 | selectedSourceId 指向已删除书源时 resolve 返回 nil |
| 并发安全 | NSLock 保护 |
| 缓存 | 内存缓存 selectedSourceIdCache |

## 6. 删除 / 清理一致性规则

| 场景 | 行为 |
|------|------|
| 删除非选中书源 | 不影响 selectedSourceId |
| 删除选中书源 | 自动清理 selectedSourceId |
| toggleEnabled 选中书源 | 不影响 selectedSourceId |
| 文件不存在 | loadSelectedSourceId 返回 nil |
| 文件损坏 | loadSelectedSourceId 返回 nil |

## 7. 新增 / 更新测试

### 新增测试文件
`iOS/Tests/ReaderAppPersistenceTests/BookSourceSelectionPersistenceTests.swift`

### 测试覆盖

| 测试项 | 覆盖 | 说明 |
|--------|------|------|
| 初始 selectedSourceId 为空 | ✅ | testInitialSelectedSourceIdIsNil |
| 清空已为空 | ✅ | testClearSelectedSourceIdWhenAlreadyNil |
| 保存后重新读取 | ✅ | testSaveSelectedSourceIdThenLoad |
| 清空后无选中 | ✅ | testClearSelectedSourceIdAfterSave |
| 删除非选中不影响选中 | ✅ | testDeleteNonSelectedSourceDoesNotAffectSelection |
| 删除选中自动清理 | ✅ | testDeleteSelectedSourceClearsSelection |
| resolve 匹配书源 | ✅ | testResolveSelectedSourceReturnsMatchingSource |
| resolve 无选中 | ✅ | testResolveSelectedSourceReturnsNilWhenNoSelection |
| resolve 书源已删除 | ✅ | testResolveSelectedSourceReturnsNilWhenSourceDeleted |
| 清理缓存保持持久化 | ✅ | testClearCacheClearsSelectionCache |

## 8. 边界检查与测试结果

| 检查项 | 结果 |
|--------|------|
| 边界检查脚本 | ✅ PASS (checked_files=60) |
| 新增测试文件 | ✅ BookSourceSelectionPersistenceTests.swift |
| Swift 编译 | ⚠️ ENV_COMPILE_UNVERIFIED |

## 9. 剩余 P0 / P1 / P2 缺口

### P0 必须解决

| ID | 缺口 | 当前状态 | 说明 |
|----|------|---------|------|
| 无 | - | - | 无 P0 缺口 |

### P1 应尽快解决

| ID | 缺口 | 当前状态 | 说明 |
|----|------|---------|------|
| P1-1 | 重复导入去重策略 | ❌ 不存在 | 需设计去重规则 |
| P1-3 | 删除/切换失败状态 | ❌ 不存在 | 需在 ViewModel 定义失败状态 |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 迁移版本字段 | 低 |
| P2-2 | 书源分组/排序 | 低 |
| P2-3 | 批量导入 | 中 |
| P2-4 | 部分损坏 JSON 处理 | 中 |
| P2-5 | defaultSourceId 持久化 | 低 |

## 10. S2.P3 推荐任务

**任务 ID**: S2.P3  
**任务名称**: 书源管理状态流与错误处理完善

**任务内容**:
1. 定义删除/切换失败状态
2. 完善重复导入去重策略设计
3. 验证现有状态流与能力层契约一致性

**前提条件**: 无需 Reader-Core

## 11. 本轮未做事项

| 事项 | 原因 |
|------|------|
| UI 设计优化 | 禁止 |
| 重复导入去重实现 | P1-1 待设计 |
| 失败状态定义 | P1-3 待实现 |
| defaultSourceId 持久化 | 无明确需求 |
