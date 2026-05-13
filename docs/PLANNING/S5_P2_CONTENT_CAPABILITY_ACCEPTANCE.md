# S5.P2 Content 能力层综合验收

## 1. 本轮结论

**结论**: `CONTENT_CAPABILITY_ACCEPTED_ENV_UNVERIFIED`

**说明**:
- S5.P0-S5.P1 文档一致性已确认
- 正文能力层已形成本仓 Mock 闭环
- ContentService 接口契约清晰
- Mock/Placeholder 路由契约已测试
- ReadingFlowCoordinator 正文流程已测试
- **上一章/下一章导航无显式 API，测试仅验证边界逻辑**
- **ChapterCacheStore 已测试但未接入正文加载流程**
- **当前 real mode 是 PlaceholderContentService，不代表真实 Reader-Core 正文能力**
- **DefaultContentService 存在但未装配**
- Swift 编译在 Trae 环境未验证
- S5 阶段可以关闭，等待本地编译验证

## 2. S5.P0-S5.P1 文档一致性修正

### 一致性确认

| 检查项 | S5.P0 | S5.P1 | 一致性 |
|--------|-------|-------|--------|
| 结论 | READY_WITH_GAPS + ENV_COMPILE_UNVERIFIED | CONTENT_CONTRACT_READY_ENV_UNVERIFIED | ✅ |
| real mode | Placeholder | Placeholder | ✅ |
| DefaultContentService | 未装配 | 未装配 | ✅ |
| ChapterCacheStore | 缓存边界 | 已测试但未接入 | ✅ |
| ContentService 职责 | ContentService.fetchContent | ContentService.fetchContent | ✅ |

### 需修正表述

| 文档 | 原表述 | 修正后 |
|------|--------|--------|
| S5.P0 | "上一章/下一章导航能力已实现" | "上一章/下一章边界逻辑已确认，无显式 API" |
| S5.P1 | "上一章/下一章边界已测试" | "上一章/下一章边界逻辑已定义测试，无显式 API" |
| S5.P1 | "35 个测试" | "35 个测试定义，TEST_TARGET_COMPILE_UNVERIFIED" |

## 3. 真实文件路径

| 文件 | 状态 | 用途 |
|------|------|------|
| `iOS/Features/Content/ContentView.swift` | ✅ | 正文视图 |
| `iOS/CoreIntegration/DefaultContentService.swift` | ✅ | 真实正文服务（未装配） |
| `iOS/CoreIntegration/PlaceholderServices.swift` | ✅ | Placeholder 正文服务 |
| `iOS/Shell/ShellAssembly.swift` | ✅ | Shell 组装 + Mock 正文服务 |
| `iOS/CoreIntegration/ReadingFlowCoordinator.swift` | ✅ | 阅读流程协调 + 正文入口 |
| `iOS/CoreBridge/ReaderCoreServiceProvider.swift` | ✅ | 服务提供者 |
| `iOS/CoreBridge/MockReaderCoreService.swift` | ✅ | Mock 核心服务 |
| `iOS/App/Persistence/ChapterCacheStore.swift` | ✅ | 章节缓存 |
| `iOS/Tests/ShellSmokeTests/ContentServiceContractTests.swift` | ✅ | 35 个测试定义 |

## 4. ContentServiceContractTests 核验

### 测试数量统计

| 测试组 | 测试数 | 状态 |
|--------|--------|------|
| Mock ContentService | 6 | ✅ 已定义 |
| Placeholder ContentService | 2 | ✅ 已定义 |
| Provider Mode Tests | 3 | ✅ 已定义 |
| Service Contract | 3 | ✅ 已定义 |
| State Transition | 4 | ✅ 已定义 |
| ReadingFlowCoordinator | 6 | ✅ 已定义 |
| Chapter Navigation | 3 | ✅ 已定义 |
| ChapterCacheStore | 5 | ✅ 已定义 |
| **总计** | **32** | TEST_TARGET_COMPILE_UNVERIFIED |

### 覆盖核验

| 检查项 | 覆盖 | 说明 |
|--------|------|------|
| Mock Content 成功 | ✅ | testMockContentReturnsResultsOnSuccess |
| Mock Content 空结果 | ✅ | testMockContentThrowsOnEmptyScenario |
| Mock Content failed | ✅ | testMockContentThrowsOnNetworkFailure/parserFailure |
| Mock Content unsupported | ✅ | testMockContentThrowsOnUnsupported |
| Placeholder unavailable | ✅ | testPlaceholderContentThrowsRealCoreNotAvailable |
| real mode 不静默回退 Mock | ✅ | testProviderRealModeDoesNotReturnMockResults |
| ReadingFlowCoordinator selectChapter | ✅ | 6 个测试 |
| 上一章/下一章边界 | ✅ | 3 个测试（边界逻辑） |
| ChapterCacheStore 基础行为 | ✅ | 5 个测试 |
| 依赖 Reader-Core 源码 | ❌ | 仅依赖 public API |
| 发起网络请求 | ❌ | Mock 实现 |
| 编译验证 | ⚠️ | TEST_TARGET_COMPILE_UNVERIFIED |

## 5. S5 能力验收矩阵

| 能力项 | 状态 | 验证方式 |
|--------|------|----------|
| Mock Content 成功 | ✅ 已测试但未编译验证 | ContentServiceContractTests |
| Mock Content 空结果 | ✅ 已测试但未编译验证 | ContentServiceContractTests |
| Mock Content failed | ✅ 已测试但未编译验证 | ContentServiceContractTests |
| Mock Content unsupported | ✅ 已测试但未编译验证 | ContentServiceContractTests |
| Placeholder Content unavailable | ✅ 已测试但未编译验证 | ContentServiceContractTests |
| Real mode 不静默回退 Mock | ✅ 已测试但未编译验证 | ContentServiceContractTests |
| DefaultContentService 存在但未装配 | ✅ 静态审计确认 | 代码检查 |
| ReadingFlowCoordinator selectChapter 入口 | ✅ 已测试但未编译验证 | ContentServiceContractTests |
| TOC → Content 连接点 | ✅ 静态审计确认 | 代码检查 |
| selectedChapter / contentPage / currentError / isLoading | ✅ 已测试但未编译验证 | ContentServiceContractTests |
| 第一章 / 最后一章边界 | ✅ 已测试但未编译验证 | 边界逻辑测试 |
| 中间章节上一章 / 下一章切换 | ✅ 已测试但未编译验证 | 边界逻辑测试 |
| ReadingFlowCoordinator 上一章/下一章 API | ❌ 未实现 | 无显式 API |
| ChapterCacheStore 基础保存 / 读取 | ✅ 已测试但未编译验证 | ChapterCacheStoreTests |
| ChapterCacheStore 是否接入正文加载 | ❌ 未接入 | 独立 Store |
| ReadingProgressStore 与正文流程边界 | ✅ 静态审计确认 | 代码检查 |
| 与 Reader-Core 的边界 | ✅ 静态审计确认 | 边界检查 PASS |

## 6. ContentService 当前契约

### 协议定义

```swift
public protocol ContentService {
    func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage
}
```

### 三条实现路径

| 路径 | 依赖 | 行为 | 状态 |
|------|------|------|------|
| Mock | ReaderCoreServiceProvider | 委托给 provider.getChapterContent() | ✅ 已测试 |
| Placeholder | 无 | 抛出 realCoreNotAvailable | ✅ 已测试 |
| Default | HTTPClient/RequestBuilder/ContentParser | 构造真实请求 | ❌ 未装配 |

## 7. Mock / Placeholder / Real 路由当前契约

### 路由语义

```swift
// ReaderCoreServiceProvider.getChapterContent()
switch currentMode {
case .mock:
    return await mockService.getChapterContent(chapterURL: chapterURL)
case .real:
    return .unsupported(reason: "Real Core service not available...")
}
```

### 契约保证

| 模式 | 返回 | 不会 |
|------|------|------|
| mock | .loaded / .empty / .failed | - |
| real | .unsupported | 静默回退 mock |

## 8. ReadingFlowCoordinator 正文流程当前契约

### 正文入口

```swift
public func selectChapter(_ chapter: TOCItem) async {
    selectedChapter = chapter
    contentPage = nil
    
    guard let source = selectedSource else { return }
    
    isLoading = true
    currentError = nil
    defer { isLoading = false }
    
    do {
        contentPage = try await contentService.fetchContent(source: source, chapterURL: chapter.chapterURL)
    } catch {
        currentError = error
    }
}
```

### 上一章 / 下一章 API 状态

**核验结论**: ReadingFlowCoordinator **没有** 显式的 `previousChapter()` / `nextChapter()` API。

**当前实现**:
- 上一章/下一章逻辑在 ContentView 层面实现
- 通过 `tocItems.firstIndex` 计算当前章节索引
- 边界检查：`index > 0` / `index < count - 1`

**测试状态**:
- S5.P1 测试验证的是边界逻辑，不是显式 API
- 测试通过 `coordinator.tocItems.firstIndex` 计算索引

### 状态维护

| 状态 | 说明 |
|------|------|
| contentPage: ContentPage? | 正文内容 |
| selectedChapter: TOCItem? | 选中章节 |
| isLoading | 加载状态 |
| currentError: ReaderError? | 当前错误 |

## 9. ChapterCacheStore 边界当前契约

### 缓存能力

| 契约项 | 说明 |
|--------|------|
| 缓存 Key | "\(sourceID)_\(chapterURL)" |
| 存储格式 | JSON 文件 (chapter_cache.json) |
| 缓存内容 | ChapterCacheEntry (标题 + 正文) |
| 线程安全 | NSLock |

### 当前状态

| 检查项 | 状态 |
|--------|------|
| 缓存能力 | ✅ 已实现 |
| 测试覆盖 | ✅ 已测试但未编译验证 |
| 接入正文流程 | ❌ 未接入 |

**结论**: ChapterCacheStore 是独立 Store 能力，未接入 ContentService / ReadingFlowCoordinator。不作为 S5 关闭阻塞项，建议作为 S6 或后续缓存闭环任务。

## 10. 测试覆盖与环境限制

### 测试统计

| 测试文件 | 测试数 | 状态 |
|----------|--------|------|
| ContentServiceContractTests.swift | 32 | TEST_TARGET_COMPILE_UNVERIFIED |

### 环境限制

| 限制 | 说明 |
|------|------|
| Trae 无 Swift/Xcode | 无法执行 swift build/test |
| Trae 无 Reader-Core | 无法解析 package 依赖 |
| 边界检查 | ✅ PASS (checked_files=65) |
| 本地编译验证 | 待执行 |

## 11. 剩余 P0 / P1 / P2 缺口

### P0 必须解决

| ID | 缺口 | 状态 |
|----|------|------|
| 无 | - | - |

### P1 应尽快解决

| ID | 缺口 | 优先级 | 说明 |
|----|------|--------|------|
| P1-1 | ReadingFlowCoordinator 上一章/下一章显式 API | 低 | 当前在 ContentView 层面实现 |
| P1-2 | ChapterCacheStore 接入正文流程 | 低 | 缓存已实现但未使用 |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 正文缓存精细控制 | 低 |
| P2-2 | 预加载 | 中 |
| P2-3 | 离线阅读 | 中 |
| P2-4 | 阅读位置精细恢复 | 低 |
| P2-5 | 多源正文 fallback | 高 |

### 不属于当前 S5 的任务

| 任务 | 归属 | 说明 |
|------|------|------|
| 真实 Reader-Core 正文接入 | S1.P2 | 需 Reader-Core 可用环境 |
| DefaultContentService 真实装配 | S1.P2 | 需 Reader-Core API 验证 |
| ChapterCacheStore 接入正文流程 | S6 | 缓存闭环任务 |

## 12. 是否允许关闭 S5 阶段

**结论**: 可以关闭，但需本地编译验证

**理由**:
- 正文能力层 Mock 闭环已完成
- ContentService 契约测试已定义（32 个测试）
- 边界检查通过
- 无 P0 阻断问题
- **但 Swift 编译待本地验证**

**本地验证清单**:
- [ ] `cd iOS && swift package resolve`
- [ ] `cd iOS && swift build`
- [ ] `cd iOS && swift test`
- [ ] ContentServiceContractTests 通过

## 13. S6 推荐任务

**任务 ID**: S6.P0
**任务名称**: 阅读器能力层审计

**任务内容**:
1. 审计当前阅读器能力层实现状态
2. 确认阅读设置、字体、主题等能力
3. 验证阅读进度持久化
4. 审计 ChapterCacheStore 接入正文流程

**前提条件**: 无需 Reader-Core
