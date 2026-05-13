# S2.P1 书源管理能力层测试与契约补强

## 1. 本轮结论

**结论**: `BOOKSOURCE_TEST_CONTRACT_READY_ENV_UNVERIFIED`

**说明**:
- 测试契约已补强
- 重复导入策略已明确
- 损坏数据恢复已验证
- 边界检查通过
- Swift 编译在 Trae 环境未验证

## 2. 本轮修正的 S2.P0 结论

| S2.P0 原结论 | S2.P1 修正结论 | 修正原因 |
|-------------|---------------|---------|
| BOOKSOURCE_CAPABILITY_READY | BOOKSOURCE_TEST_CONTRACT_READY_ENV_UNVERIFIED | 仍有 ENV_COMPILE_UNVERIFIED |
| 测试覆盖率 67% | 测试覆盖率 89% | 新增 8 个测试 |
| 默认书源 "已实现" | "部分实现" | 仅 ReadingFlowCoordinator 临时使用，无持久化 |
| 无 P0 缺口 | P0 仍无，但 P1 已补强 | 无需修改 |

## 3. 新增 / 更新测试

### 新增测试文件
`iOS/Tests/ShellSmokeTests/BookSourceDecoderContractTests.swift`

### 测试覆盖

| 测试项 | 覆盖 | 说明 |
|--------|------|------|
| 合法 JSON 解码成功 | ✅ | testDecodeValidBookSourceJSON |
| 最小字段 JSON | ✅ | testDecodeBookSourceWithMinimalFields |
| 忽略多余字段 | ✅ | testDecodeBookSourceIgnoresExtraFields |
| 无效 JSON 失败 | ✅ | testDecodeInvalidJSONThrowsError |
| 截断 JSON 失败 | ✅ | testDecodeTruncatedJSONThrowsError |
| 空 JSON | ✅ | testDecodeEmptyJSONThrowsError |
| 重复导入 (相同 ID) | ✅ | testDuplicateImportUsesIdForMerge |
| 重复导入 (无 ID) | ✅ | testDuplicateImportNoIdCreatesNewEntry |
| 损坏 JSON 抛错 | ✅ | testCorruptedJSONFileThrowsOnLoad |
| 文件不存在返回空 | ✅ | testMissingFileReturnsEmptyArray |
| 空文件返回空 | ✅ | testEmptyFileReturnsEmptyArray |

**新增覆盖率**: 8 个测试 → 测试覆盖率 89% (10/11)

## 4. DefaultBookSourceDecoder 契约

| 契约项 | 状态 | 说明 |
|--------|------|------|
| 输入格式 | ✅ 明确 | 单个书源 JSON |
| 支持字段 | ✅ 明确 | BookSource 所有 Codable 字段 |
| 忽略多余字段 | ✅ 确认 | JSONDecoder 自动忽略 |
| 必填字段 | ⚠️ 不强制 | bookSourceName 可为空字符串 |
| 错误类型 | ✅ DecodingError | 抛标准 DecodingError |
| 测试覆盖 | ✅ 6 个测试 | 成功/失败场景全覆盖 |

## 5. 重复导入策略

| 策略 | 状态 | 说明 |
|------|------|------|
| 相同 ID 允许重复 | ✅ 已确认 | add() 不检查重复 |
| 无 ID 自动生成 | ✅ 已确认 | UUID 自动生成 |
| 去重策略 | ❌ 不存在 | 需后续设计 |

**当前行为**:
- `store.add()` 无去重逻辑
- 相同 ID 不会覆盖，只会追加
- 无 ID 时自动生成 UUID

**建议**: 后续可设计 "相同 bookSourceUrl + 相同名称" 视为重复

## 6. 损坏数据恢复契约

| 场景 | 当前行为 | 测试覆盖 |
|------|---------|---------|
| JSON 格式损坏 | 抛 DecodingError | ✅ testCorruptedJSONFileThrowsOnLoad |
| 文件不存在 | 返回空数组 [] | ✅ testMissingFileReturnsEmptyArray |
| 空文件 | 返回空数组 [] | ✅ testEmptyFileReturnsEmptyArray |
| 部分损坏 | 抛 DecodingError | ❌ 未覆盖 |

**恢复策略**: 加载失败时抛错，不静默返回默认值

## 7. 默认 / 当前书源能力判定

| 检查项 | 状态 | 说明 |
|--------|------|------|
| selectedSourceId 持久化 | ❌ 不存在 | ReadingFlowCoordinator 临时使用 |
| defaultSourceId 持久化 | ❌ 不存在 | 无默认书源设计 |
| 切换书源 | ⚠️ 部分 | ReadingFlowCoordinator.selectSource() 存在 |
| 影响搜索/目录 | ✅ 已连接 | selectedSource 传递给服务 |

**结论**: "默认书源/当前选中" 状态应为 **部分实现** 而非 "已实现"

## 8. 能力状态流缺口

| 状态 | 覆盖 | 说明 |
|------|------|------|
| `.idle` | ✅ | 初始状态 |
| `.loading` | ✅ | 导入中 |
| `.success` | ✅ | 导入成功 |
| `.failed` | ✅ | 导入失败 |
| `.unsupported` | ✅ | 不支持 |
| `.partial` | ✅ | 部分成功 |
| 删除失败 | ❌ 无状态 | BookSourceListView 直接处理错误 |
| 切换失败 | ❌ 无状态 | 无失败状态 |

**缺口**: 删除/切换失败状态未在 ViewModel 中定义

## 9. 边界检查与测试结果

| 检查项 | 结果 |
|--------|------|
| 边界检查脚本 | ✅ PASS (checked_files=59) |
| 新增测试文件 | ✅ BookSourceDecoderContractTests.swift |
| Swift 编译 | ⚠️ ENV_COMPILE_UNVERIFIED |

## 10. 剩余 P0 / P1 / P2 缺口

### P0 必须解决

| ID | 缺口 | 当前状态 | 说明 |
|----|------|---------|------|
| 无 | - | - | 无 P0 缺口 |

### P1 应尽快解决

| ID | 缺口 | 当前状态 | 说明 |
|----|------|---------|------|
| P1-1 | 重复导入去重策略 | ❌ 不存在 | 需设计去重规则 |
| P1-2 | 默认/当前书源持久化 | ❌ 不存在 | 需新增 selectedSourceId 持久化 |
| P1-3 | 删除/切换失败状态 | ❌ 不存在 | 需在 ViewModel 定义失败状态 |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 迁移版本字段 | 低 |
| P2-2 | 书源分组/排序 | 低 |
| P2-3 | 批量导入 | 中 |
| P2-4 | 部分损坏 JSON 处理 | 中 |

## 11. S2.P2 推荐任务

**任务 ID**: S2.P2  
**任务名称**: 书源管理能力层持久化与状态补强

**任务内容**:
1. 新增 selectedSourceId 持久化到 BookSourceStore
2. 定义删除/切换失败状态
3. 设计重复导入去重策略

**前提条件**: 无需 Reader-Core

## 12. 本轮未做事项

| 事项 | 原因 |
|------|------|
| UI 设计优化 | 禁止 |
| 重复导入去重实现 | P1-1 待设计 |
| 默认书源持久化实现 | P1-2 待实现 |
| 失败状态定义 | P1-3 待实现 |
