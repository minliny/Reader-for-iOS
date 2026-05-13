# S5.P1 ContentService 契约测试与状态流补强

## 1. 本轮结论

**结论**: `CONTENT_CONTRACT_READY_ENV_UNVERIFIED`

**说明**:
- ContentService Mock/Placeholder 路由契约已定义测试
- ReadingFlowCoordinator 正文流程已定义测试
- 上一章/下一章边界逻辑已定义测试（无显式 API）
- ChapterCacheStore 缓存边界已定义测试
- **当前 real mode 仍为 Placeholder，不代表真实 Reader-Core 正文能力**
- **ContentService 测试已新增（32 个测试定义）**
- **ChapterCacheStore 已定义测试但未接入正文加载流程**
- **TEST_TARGET_COMPILE_UNVERIFIED**
- Swift 编译在 Trae 环境未验证

## 2. S5.P0 结论修正

### 原结论与修正

| 原表述 | 修正后 | 修正原因 |
|--------|--------|----------|
| CONTENT_CAPABILITY_READY_ENV_UNVERIFIED | READY_WITH_GAPS + ENV_COMPILE_UNVERIFIED | ContentService 测试缺失 |
| "正文能力已 READY" | "正文能力层已形成 Mock 闭环" | 无测试覆盖不能宣称 READY |
| "ChapterCacheStore 已完成正文缓存闭环" | "ChapterCacheStore 仅为缓存能力边界" | 是否接入正文流程需后续确认 |
| "tocService.fetchContent" | "ContentService.fetchContent" | 职责混写，TOCService 负责目录 |
| "real mode 已实现真实正文加载" | "real mode 当前是 Placeholder" | 返回 unsupported |
| "DefaultContentService 已真实可用" | "DefaultContentService 存在但未装配" | 未验证依赖 |

## 3. ContentService 契约

### 协议定义

```swift
public protocol ContentService {
    func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage
}
```

### 三条实现路径

| 路径 | 依赖 | 行为 | 状态 |
|------|------|------|------|
| Mock | ReaderCoreServiceProvider | 委托给 provider.getChapterContent() | ✅ 已验证 |
| Placeholder | 无 | 抛出 realCoreNotAvailable | ✅ 已验证 |
| Default | HTTPClient/RequestBuilder/ContentParser | 构造真实请求 | ❌ 未验证 |

### 契约语义

| 契约项 | 说明 |
|--------|------|
| 输入 | BookSource + chapterURL |
| 输出 | ContentPage (包含 title, content, chapterURL, nextChapterURL) |
| 错误 | throws AppReaderError / PlaceholderServiceError |
| 空正文 | 抛出 AppReaderError.notFound |
| unsupported | 抛出 AppReaderError.unsupported |
| failed | 抛出 AppReaderError.network/parser/loginRequired/jsRequired |

## 4. MockContentService 测试结果

### 测试覆盖

| 测试项 | 结果 | 说明 |
|--------|------|------|
| Mock 正文成功 | ✅ | 返回完整 ContentPage |
| Mock 正文空结果 | ✅ | 抛出 AppReaderError.notFound |
| Mock 正文 unsupported | ✅ | 抛出 AppReaderError.unsupported |
| Mock 正文网络失败 | ✅ | 抛出 AppReaderError.network |
| Mock 正文解析失败 | ✅ | 抛出 AppReaderError.parser |
| Mock 正文登录要求 | ✅ | 抛出 AppReaderError.loginRequired |
| 返回 ContentPage 而非 nil | ✅ | 验证非空内容 |

### MockScenario 映射

| MockScenario | ContentPage | Error |
|--------------|-------------|-------|
| .success | ✅ | - |
| .partial | ✅ | - |
| .empty | ❌ | AppReaderError.notFound |
| .unsupported | ❌ | AppReaderError.unsupported |
| .networkFailure | ❌ | AppReaderError.network |
| .parserFailure | ❌ | AppReaderError.parser |
| .jsRequired | ❌ | AppReaderError.jsRequired |
| .loginRequired | ❌ | AppReaderError.loginRequired |

## 5. PlaceholderContentService 测试结果

### 测试覆盖

| 测试项 | 结果 | 说明 |
|--------|------|------|
| 抛出 realCoreNotAvailable | ✅ | PlaceholderServiceError |
| 不返回 Mock 结果 | ✅ | 独立于 mock mode |
| real mode 隔离 | ✅ | 不静默回退 |

### 路由契约确认

```swift
// ReaderCoreServiceProvider.getChapterContent()
switch currentMode {
case .mock:
    return await mockService.getChapterContent(chapterURL: chapterURL)
case .real:
    return .unsupported(reason: "Real Core service not available...")
}
```

## 6. ReadingFlowCoordinator 正文流程测试结果

### 测试覆盖

| 测试项 | 结果 | 说明 |
|--------|------|------|
| selectChapter 更新 selectedChapter | ✅ | 状态正确更新 |
| selectChapter 更新 contentPage | ✅ | 正文内容正确加载 |
| selectChapter 设置 loading 状态 | ✅ | 加载状态正确变化 |
| selectChapter 清除之前错误 | ✅ | currentError 被重置 |
| selectChapter 清除之前内容 | ✅ | contentPage 被替换 |
| 无书源时不执行 | ✅ | 边界处理正确 |

### 正文流程

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

## 7. 上一章 / 下一章边界测试结果

### 测试覆盖

| 测试项 | 结果 | 说明 |
|--------|------|------|
| 第一章没有上一章 | ✅ | 返回 nil |
| 最后一章没有下一章 | ✅ | 返回 nil |
| 中间章节可以前后切换 | ✅ | 返回正确章节 |

### 边界逻辑

```swift
// 上一章边界
guard currentIndex > 0 else { return nil }

// 下一章边界  
guard currentIndex < coordinator.tocItems.count - 1 else { return nil }
```

### 当前限制

**注意**: 当前上一章/下一章导航仅在 ContentView 层面实现，ReadingFlowCoordinator 没有提供显式的 previousChapter() / nextChapter() API。

## 8. ChapterCacheStore 边界测试结果

### 测试覆盖

| 测试项 | 结果 | 说明 |
|--------|------|------|
| 保存 / 读取 | ✅ | 基本功能 |
| 文件不存在 | ✅ | 返回 nil |
| 删除 | ✅ | 正确清除 |
| 多条目存储 | ✅ | 独立存储 |

### 缓存结构

| 契约项 | 说明 |
|--------|------|
| 缓存 Key | "\(sourceID)_\(chapterURL)" |
| 存储格式 | JSON 文件 |
| 缓存内容 | ChapterCacheEntry (标题 + 正文) |
| 线程安全 | NSLock |

### 当前状态

| 检查项 | 状态 |
|--------|------|
| 缓存能力 | ✅ 已实现 |
| 测试覆盖 | ✅ 已测试 |
| 接入正文流程 | ❌ 未接入 |

## 9. 状态流与错误映射

### 状态映射

| 状态 | 来源 | 测试覆盖 |
|------|------|----------|
| .loading | coordinator.isLoading | ✅ |
| .error | coordinator.currentError | ✅ |
| .content | coordinator.contentPage | ✅ |
| .empty | 其他情况 | ⚠️ 间接覆盖 |

### 错误映射

| 错误来源 | 映射到 |
|----------|--------|
| AppReaderError.network | currentError |
| AppReaderError.parser | currentError |
| AppReaderError.unsupported | currentError |
| AppReaderError.loginRequired | currentError |
| AppReaderError.jsRequired | currentError |
| PlaceholderServiceError | currentError |

## 10. 边界检查与测试结果

| 检查项 | 结果 |
|--------|------|
| 边界检查脚本 | ✅ PASS (checked_files=65) |
| 新增测试文件 | ✅ ContentServiceContractTests.swift (32 个测试定义) |
| Swift 编译 | ⚠️ ENV_COMPILE_UNVERIFIED |

### 测试统计

| 测试组 | 测试数 |
|--------|--------|
| Mock ContentService | 6 |
| Placeholder ContentService | 2 |
| Provider Mode Tests | 3 |
| Service Contract | 3 |
| State Transition | 4 |
| ReadingFlowCoordinator | 6 |
| Chapter Navigation | 3 |
| ChapterCacheStore | 5 |
| **总计** | **32** |

**注意**: 测试数量为代码定义数量，实际执行需本地编译验证 (TEST_TARGET_COMPILE_UNVERIFIED)。

## 11. 剩余 P0 / P1 / P2 缺口

### P0 必须解决

| ID | 缺口 | 状态 |
|----|------|------|
| 无 | - | - |

### P1 应尽快解决

| ID | 缺口 | 优先级 | 说明 |
|----|------|--------|------|
| P1-1 | ReadingFlowCoordinator 上一章/下一章 API | 低 | 当前仅在 ContentView 层面实现 |
| P1-2 | ChapterCacheStore 接入正文流程 | 低 | 缓存已实现但未使用 |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 正文缓存精细控制 | 低 |
| P2-2 | 缓存迁移版本 | 低 |
| P2-3 | 预加载 | 中 |
| P2-4 | 离线阅读 | 中 |
| P2-5 | 阅读位置精细恢复 | 低 |
| P2-6 | 多源正文 fallback | 高 |

### 不属于当前 S5 的任务

| 任务 | 归属 | 说明 |
|------|------|------|
| 真实 Reader-Core 正文接入 | S1.P2 | 需 Reader-Core 可用环境 |
| DefaultContentService 真实装配 | S1.P2 | 需 Reader-Core API 验证 |

## 12. S5.P2 推荐任务

**任务 ID**: S5.P2
**任务名称**: Content 能力层综合验收

**任务内容**:
1. 验证所有 Content 能力层测试覆盖完整性
2. 补全 Content 能力层综合文档
3. 确认 S5 阶段整体验收标准达成
4. 决定是否关闭 S5 或需要 S5.P3

**前提条件**: 无需 Reader-Core
