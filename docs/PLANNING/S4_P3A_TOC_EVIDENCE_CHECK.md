# S4.P3A TOC Evidence Check & Scope Correction

## 1. 本轮结论

**结论**: `READY_WITH_SCOPE_CORRECTIONS`

**说明**:
- S4.P0-S4.P3 文件真实存在，无伪造
- TOCServiceContractTests 包含 24 个测试，覆盖核心场景
- 文档存在过度表述，已修正
- Mock/Placeholder 路由契约清晰
- TOC → Content / Search → TOC 连接仅静态审计确认，无测试
- **ENV_COMPILE_UNVERIFIED**: Trae 环境无法编译验证
- S4 可关闭但需本地编译验证

## 2. S4 文件存在性检查

| 文件 | 存在 | 大小 |
|------|------|------|
| `docs/PLANNING/S4_P0_TOC_CAPABILITY_AUDIT.md` | ✅ | 11189 bytes |
| `docs/PLANNING/S4_P1_TOC_CONTRACT_TESTS.md` | ✅ | 6299 bytes |
| `docs/PLANNING/S4_P2_TOC_CONNECTIVITY.md` | ✅ | 11788 bytes |
| `docs/PLANNING/S4_P3_TOC_CAPABILITY_ACCEPTANCE.md` | ✅ | 9439 bytes |
| `iOS/Tests/ShellSmokeTests/TOCServiceContractTests.swift` | ✅ | 11777 bytes |

## 3. TOCServiceContractTests 核验

### 测试数量统计

| 测试组 | 测试数 |
|--------|--------|
| Mock TOC Service | 6 |
| Placeholder TOC Service | 2 |
| ReaderCoreServiceProvider Mode | 3 |
| Service Contract | 2 |
| State Transition | 5 |
| TOCItem Content | 2 |
| ChapterListViewModel | 4 |
| **总计** | **24** |

### 覆盖核验

| 检查项 | 覆盖 | 说明 |
|--------|------|------|
| Mock TOC 成功 | ✅ | testMockTOCReturnsResultsOnSuccess |
| Mock TOC 空结果 | ✅ | testMockTOCReturnsEmptyOnEmptyScenario |
| Mock TOC failed | ✅ | testMockTOCThrowsOnNetworkFailure, testMockTOCThrowsOnParserFailure |
| Mock TOC unsupported | ✅ | testMockTOCThrowsOnUnsupported |
| PlaceholderTOCService unavailable | ✅ | testPlaceholderTOCThrowsRealCoreNotAvailable |
| real mode 不静默回退 Mock | ✅ | testProviderRealModeDoesNotReturnMockResults |
| ChapterListViewModel | ✅ | 4 个测试覆盖成功/空/unsupported/失败 |

### 依赖与安全检查

| 检查项 | 结果 |
|--------|------|
| 是否依赖 Reader-Core 源码 | ❌ | 仅依赖 ReaderCoreModels/ReaderCoreProtocols |
| 是否发起网络请求 | ❌ | Mock 实现，无真实网络调用 |
| 是否可能编译失败 | ⚠️ | TEST_TARGET_COMPILE_UNVERIFIED |

## 4. S4 文档表述修正

### 原表述与修正

| 原表述 | 修正后 | 修正原因 |
|--------|--------|----------|
| "已验证" | "静态审计确认" | 仅代码阅读，无测试验证 |
| "已实现" | "Mock 实现" | 仅 Mock 能力，非真实实现 |
| "real mode 已实现" | "Placeholder 实现 / unavailable" | real mode 返回 unsupported |
| "TOC → Content 已验证" | "TOC → Content 静态审计确认" | 代码存在，但无测试 |
| "Search → TOC 已验证" | "Search → TOC 静态审计确认" | 代码存在，但无测试 |
| "书源选择影响 TOC 已验证" | "书源选择影响 TOC 静态审计确认" | 代码存在，但无测试 |
| "S4 可以关闭" | "可以关闭但需本地编译验证" | ENV_COMPILE_UNVERIFIED |

### 修正范围说明

所有 S4.P0-S4.P3 文档中的"已验证"表述若未通过测试验证，均应修正为"静态审计确认"。

## 5. 修正后的 S4 能力验收矩阵

| 能力项 | 状态 | 验证方式 |
|--------|------|----------|
| Mock TOC 成功 | ✅ 已测试但未编译验证 | TOCServiceContractTests |
| Mock TOC 空结果 | ✅ 已测试但未编译验证 | TOCServiceContractTests |
| Mock TOC failed | ✅ 已测试但未编译验证 | TOCServiceContractTests |
| Mock TOC unsupported | ✅ 已测试但未编译验证 | TOCServiceContractTests |
| Placeholder TOC unavailable | ✅ 已测试但未编译验证 | TOCServiceContractTests |
| Real mode 不静默回退 Mock | ✅ 已测试但未编译验证 | TOCServiceContractTests |
| DefaultTOCService 存在但未装配 | ✅ 静态审计确认 | 代码检查 |
| TOCView / ChapterListViewModel | ✅ 静态审计确认 | 代码检查 |
| ReadingFlowCoordinator selectBook → fetchTOC | ✅ 静态审计确认 | 代码检查 |
| TOC → Content 连接点 | ✅ 静态审计确认 | 代码检查 |
| Search → TOC 连接点 | ✅ 静态审计确认 | 代码检查 |
| 书源选择对 TOC 的传递 | ✅ 静态审计确认 | 代码检查 |
| 上一章 / 下一章导航 | ✅ 静态审计确认 | 代码检查 |
| TOC 错误状态 | ✅ 静态审计确认 | 代码检查 |
| TOC 测试覆盖 | ⚠️ 部分实现 | 24 个测试 |
| 与 Reader-Core 边界 | ✅ 静态审计确认 | 边界检查 PASS |

## 6. Mock / Placeholder / Real 边界核验

### 路由契约确认

```swift
// ReaderCoreServiceProvider.getChapterList()
switch currentMode {
case .mock:
    return await mockService.getChapterList(bookURL: bookURL)
case .real:
    return .unsupported(reason: "Real Core service not available...")
}
```

### 边界核验结果

| 检查项 | 结果 |
|--------|------|
| Mock 路由正确 | ✅ | 通过 MockTOCService 委托 |
| Placeholder 路由正确 | ✅ | 抛出 realCoreNotAvailable |
| Real mode 隔离 | ✅ | 不静默回退 Mock |
| ShellAssembly 路由正确 | ✅ | mock → MockTOCService, real → PlaceholderTOCService |

## 7. TOC 连接点核验

### 连接点清单

| 连接点 | 状态 | 说明 |
|--------|------|------|
| Search → TOC | ✅ 静态审计确认 | TOCView(book: SearchResultItem) → selectBook() |
| TOC → Content | ✅ 静态审计确认 | NavigationLink → ContentView(chapter: TOCItem) |
| 书源选择 → TOC | ✅ 静态审计确认 | ReadingFlowCoordinator.selectedSource |
| 上一章/下一章 | ✅ 静态审计确认 | ContentView 导航方法 |

### 代码证据

**Search → TOC**:
```swift
// TOCView.task
await coordinator.selectBook(book)
```

**TOC → Content**:
```swift
// TOCView.tocList
NavigationLink {
    ContentView(coordinator: coordinator, chapter: chapter)
}
```

**书源传递**:
```swift
// ReadingFlowCoordinator.selectBook()
guard let source = selectedSource else { return }
tocItems = try await tocService.fetchTOC(source: source, detailURL: detailURL)
```

## 8. 边界检查与测试结果

| 检查项 | 结果 |
|--------|------|
| 边界检查脚本 | ✅ PASS (checked_files=64) |
| Swift 编译 | ⚠️ ENV_COMPILE_UNVERIFIED |
| 测试执行 | ⚠️ ENV_COMPILE_UNVERIFIED |

## 9. 剩余 P0 / P1 / P2 缺口

### P0 必须解决

| ID | 缺口 | 状态 |
|----|------|------|
| 无 | - | - |

### P1 应尽快解决

| ID | 缺口 | 优先级 | 说明 |
|----|------|--------|------|
| P1-1 | TOC → Content 连接测试 | 中 | 确认导航流程 |
| P1-2 | Search → TOC 连接测试 | 中 | 确认书籍选择流程 |
| P1-3 | BookDetail → TOC 导航连接 | 低 | 导航层设计 |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 目录排序/翻转 | 低 |
| P2-2 | 目录翻页 | 中 |

### 不属于当前 S4 的任务

| 任务 | 归属 | 说明 |
|------|------|------|
| 真实 Reader-Core TOC 接入 | S1.P2 | 需 Reader-Core 可用环境 |
| 章节缓存 | S5 或后续 | 当前 TOC 不直接依赖 |

## 10. 是否允许关闭 S4

**结论**: 可以关闭，但需本地编译验证

**理由**:
- TOC 能力层 Mock 闭环已完成
- 测试文件已新增（24 个测试）
- 边界检查通过
- 无 P0 阻断问题
- **但 Swift 编译待本地验证**

**本地验证清单**:
- [ ] `cd iOS && swift package resolve`
- [ ] `cd iOS && swift build`
- [ ] `cd iOS && swift test`
- [ ] TOCServiceContractTests 通过

## 11. 推荐下一步

**任务 ID**: S5.P0
**任务名称**: Content (正文) 流程能力层审计

**任务内容**:
1. 审计当前 Content 流程 Mock 实现状态
2. 确认 ContentService 接口契约
3. 验证正文阅读能力

**前提条件**: 无需 Reader-Core

**注意**: 进入 S5 前建议先完成本地编译验证
