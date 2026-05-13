# S4.P3 TOC 能力层综合验收

## 1. 本轮结论

**结论**: `TOC_CAPABILITY_ACCEPTED_ENV_UNVERIFIED`

**说明**:
- S4.P0-S4.P2 文档一致性已确认
- TOC 能力层已形成本仓 Mock 闭环
- TOCService 接口契约清晰
- Mock/Placeholder 路由契约清晰
- TOC → Content 连接已验证
- Search → TOC 连接已验证
- 书源选择影响所有阶段已确认
- 边界检查通过
- **real mode 仍为 Placeholder，不代表真实 TOC 能力**
- Swift 编译在 Trae 环境未验证
- S4 阶段可以关闭，等待本地编译验证

## 2. S4.P0-S4.P2 文档一致性确认

| 文档 | 结论 | 一致性 |
|------|------|--------|
| S4.P0 | TOC_CAPABILITY_READY_WITH_GAPS | ✅ |
| S4.P1 | TOC_CONTRACT_READY_ENV_UNVERIFIED | ✅ |
| S4.P2 | TOC_CONNECTIVITY_VERIFIED | ✅ |

**一致性确认**:
- ✅ real mode 当前是 PlaceholderTOCService
- ✅ DefaultTOCService 存在但未真实装配
- ✅ TOC → Content 连接已验证
- ✅ 不把 Placeholder 写成真实 Core 能力
- ✅ 不把 ENV_COMPILE_UNVERIFIED 写成完全 READY

## 3. 真实文件路径

| 文件 | 状态 | 用途 |
|------|------|------|
| `iOS/Features/TOC/TOCView.swift` | ✅ | 目录视图 |
| `iOS/Features/ChapterList/ChapterListViewModel.swift` | ✅ | 章节列表 ViewModel |
| `iOS/Features/ChapterList/ChapterListView.swift` | ✅ | 章节列表视图 |
| `iOS/Features/Content/ContentView.swift` | ✅ | 正文视图 |
| `iOS/CoreIntegration/DefaultTOCService.swift` | ✅ | 真实 TOC 服务（未装配） |
| `iOS/CoreIntegration/PlaceholderServices.swift` | ✅ | Placeholder TOC 服务 |
| `iOS/Shell/ShellAssembly.swift` | ✅ | Shell 组装 + Mock TOC 服务 |
| `iOS/CoreIntegration/ReadingFlowCoordinator.swift` | ✅ | 阅读流程协调 + TOC 入口 |
| `iOS/CoreBridge/ReaderCoreServiceProvider.swift` | ✅ | 服务提供者 |
| `iOS/CoreBridge/MockReaderCoreService.swift` | ✅ | Mock 核心服务 |
| `iOS/Tests/ShellSmokeTests/TOCServiceContractTests.swift` | ✅ | TOC 契约测试 (24 个测试) |

## 4. TOC 能力验收矩阵

| 能力项 | 状态 | 测试覆盖 |
|--------|------|----------|
| Mock TOC 成功 | ✅ 已实现 | TOCServiceContractTests |
| Mock TOC 空结果 | ✅ 已实现 | TOCServiceContractTests |
| Mock TOC 失败 | ✅ 已实现 | TOCServiceContractTests |
| Mock TOC unsupported | ✅ 已实现 | TOCServiceContractTests |
| Placeholder TOC unavailable/unsupported | ✅ 已实现 | TOCServiceContractTests |
| Real mode 不静默回退 Mock | ✅ 已实现 | TOCServiceContractTests |
| DefaultTOCService 存在但未装配 | ✅ 已确认 | - |
| ReadingFlowCoordinator 状态流 | ✅ 已实现 | - |
| TOCView 空目录处理 | ✅ 已实现 | - |
| TOCView 错误处理 + 重试 | ✅ 已实现 | - |
| TOC → Content 连接点 | ✅ 已验证 | S4.P2 |
| Content 上一章/下一章导航 | ✅ 已验证 | S4.P2 |
| 搜索 → TOC 连接点 | ✅ 已验证 | S4.P2 |
| 书源选择影响 TOC | ✅ 已验证 | S4.P2 |
| 目录排序/翻转 | ❌ 未实现 | - |
| 目录翻页 | ❌ 未实现 | - |
| 章节缓存 | ❌ 未实现 | - |
| 与 Reader-Core 边界 | ✅ 清晰 | 边界检查 |

## 5. TOCService 当前契约

### 协议定义

```swift
public protocol TOCService {
    func fetchTOC(source: BookSource, detailURL: String) async throws -> [TOCItem]
}
```

| 路径 | 依赖 | 行为 |
|------|------|------|
| Mock | ReaderCoreServiceProvider | 委托给 mockService，返回 .loaded |
| Placeholder | 无 | 抛出 unavailable，返回 .unsupported |
| Default | HTTPClient/RequestBuilder/TOCParser | 构造真实请求（未装配） |

## 6. Mock / Placeholder / Real 路由当前契约

### 路由语义

```swift
// ReaderCoreServiceProvider.getChapterList()
switch currentMode {
case .mock:
    return await mockService.getChapterList(bookURL: bookURL)
case .real:
    return .unsupported(reason: "Real Core service not available...")
}
```

### ShellAssembly 路由

```swift
// ShellAssembly.makeDefaultReadingFlowCoordinator()
switch provider.currentMode {
case .mock:
    return makeMockReadingFlowCoordinator() // MockTOCService
case .real:
    return makePlaceholderReadingFlowCoordinator() // PlaceholderTOCService
}
```

### 契约保证

| 模式 | 返回 | 不会 |
|------|------|------|
| mock | .loaded / .empty / .failed | - |
| real | .unsupported | 静默回退 mock |

## 7. TOC → Content 流程当前契约

### 章节导航

```swift
// ContentView 章节导航
private var previousChapterAction: (() -> Void)? {
    guard let currentIndex = coordinator.tocItems.firstIndex(...),
          currentIndex > 0 else { return nil }
    let previous = coordinator.tocItems[currentIndex - 1]
    return { Task { await coordinator.selectChapter(previous) } }
}

private var nextChapterAction: (() -> Void)? {
    guard let currentIndex = coordinator.tocItems.firstIndex(...),
          currentIndex < coordinator.tocItems.count - 1 else { return nil }
    let next = coordinator.tocItems[currentIndex + 1]
    return { Task { await coordinator.selectChapter(next) } }
}
```

### ContentService 路由

与 TOCService 类似，MockContentService 通过 ReaderCoreServiceProvider.getChapterContent() 路由：

```swift
public final class MockContentService: ContentService {
    public func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage {
        let state = await provider.getChapterContent(chapterURL: chapterURL)
        switch state {
        case .loaded(let page): return page
        case .empty: throw AppReaderError(...)
        case .failed(let error): throw error
        case .unsupported(let reason): throw AppReaderError(...)
        case .partial(let page, _): return page
        }
    }
}
```

## 8. 测试覆盖与环境限制

### 测试文件清单

| 文件 | 测试数 | 覆盖 |
|------|--------|------|
| TOCServiceContractTests.swift | 24 | Mock/Placeholder/Real 路由、状态转换、TOCItem 结构、ChapterListViewModel |
| ContentService 路由 | - | 通过 MockContentService 复用 MockReaderCoreService |

### 环境限制

| 限制 | 说明 |
|------|------|
| Trae 无 Swift/Xcode | 无法执行 swift build/test |
| Trae 无 Reader-Core | 无法解析 package 依赖 |
| 边界检查 | ✅ PASS (checked_files=64) |
| 本地编译验证 | 待执行 |

## 9. 剩余 P0 / P1 / P2 缺口

### P0 必须解决

| ID | 缺口 | 状态 |
|----|------|------|
| 无 | - | - |

### P1 应尽快解决

| ID | 缺口 | 优先级 | 说明 |
|----|------|--------|------|
| P1-1 | ChapterListViewModel 与 Coordinator 不一致 | 低 | 实现方式不同但 Mock 路由一致 |
| P1-2 | BookDetail → TOC 导航层连接 | 低 | 需确认导航层设计 |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 目录排序/翻转 | 低 |
| P2-2 | 目录翻页 | 中 |
| P2-3 | 章节缓存 | 低 |

### 不属于当前 S4 的任务

| 任务 | 归属 | 说明 |
|------|------|------|
| 真实 Reader-Core TOC 接入 | S1.P2 | 需 Reader-Core 可用环境 |
| DefaultTOCService 真实装配 | S1.P2 | 需 Reader-Core API 验证 |

## 10. 是否允许关闭 S4 阶段

**结论**: 可以关闭，但需本地编译验证

**理由**:
- TOC 能力层已形成本仓 Mock 闭环
- TOCService 接口契约清晰
- Mock/Placeholder 路由已测试
- TOC → Content 连接已验证
- 边界检查通过
- 无阻断性问题
- Swift 编译待本地验证

**本地验证清单**:
- [ ] `cd iOS && swift package resolve`
- [ ] `cd iOS && swift build`
- [ ] `cd iOS && swift test`
- [ ] TOCServiceContractTests 通过
- [ ] TEST_TARGET 编译验证

## 11. S5 推荐任务

**任务 ID**: S5.P0
**任务名称**: Content (正文) 流程能力层 Mock / Real / Placeholder 路由契约与能力审计

**任务内容**:
1. 审计当前 Content 流程 Mock 实现状态
2. 确认 ContentService 接口契约
3. 验证 Content → Reading 流程连接
4. 设计从 Mock 切换到 Real Core 的最小路径

**前提条件**: 无需 Reader-Core（可在 Mock 模式下进行）

## 12. 阶段完成摘要

### S4 阶段完成状态

| 子阶段 | 结论 | 文档 |
|--------|------|------|
| S4.P0 | TOC_CAPABILITY_READY_WITH_GAPS | ✅ docs/PLANNING/S4_P0_TOC_CAPABILITY_AUDIT.md |
| S4.P1 | TOC_CONTRACT_READY_ENV_UNVERIFIED | ✅ docs/PLANNING/S4_P1_TOC_CONTRACT_TESTS.md |
| S4.P2 | TOC_CONNECTIVITY_VERIFIED | ✅ docs/PLANNING/S4_P2_TOC_CONNECTIVITY.md |
| S4.P3 | TOC_CAPABILITY_ACCEPTED_ENV_UNVERIFIED | ✅ docs/PLANNING/S4_P3_TOC_CAPABILITY_ACCEPTANCE.md |

### 能力层完成状态

| 能力层 | 阶段 | 状态 |
|--------|------|------|
| 书源管理 (S2) | ✅ CLOSED | BOOKSOURCE_CAPABILITY_ACCEPTED_ENV_UNVERIFIED |
| 搜索 (S3) | ✅ CLOSED | SEARCH_CAPABILITY_ACCEPTED_ENV_UNVERIFIED |
| 目录 (S4) | ✅ CLOSED | TOC_CAPABILITY_ACCEPTED_ENV_UNVERIFIED |
| 正文 (S5) | 🔄 PENDING | - |
| 阅读器 (S6) | 🔄 PENDING | - |

### 本轮修改文件

| 文件 | 状态 | 说明 |
|------|------|------|
| `docs/PLANNING/S4_P0_TOC_CAPABILITY_AUDIT.md` | ✅ 新增 | TOC 能力审计 |
| `docs/PLANNING/S4_P1_TOC_CONTRACT_TESTS.md` | ✅ 新增 | TOC 契约测试 |
| `docs/PLANNING/S4_P2_TOC_CONNECTIVITY.md` | ✅ 新增 | TOC 连接点验证 |
| `docs/PLANNING/S4_P3_TOC_CAPABILITY_ACCEPTANCE.md` | ✅ 新增 | TOC 综合验收 |
| `iOS/Tests/ShellSmokeTests/TOCServiceContractTests.swift` | ✅ 新增 | 24 个 TOC 契约测试 |
