# S6.P3 iOS App 层缓存与进度集成

## 1. 本轮结论

**结论**: `APP_CACHE_PROGRESS_READY_ENV_UNVERIFIED`

**说明**:
- ChapterCacheStore 已通过 ChapterCaching 协议接入 ReadingFlowCoordinator
- ReadingFlowCoordinator.selectChapter 实现 cache hit/miss 逻辑
- ReadingProgressStore / BookshelfStore 已通过协议实现 source of truth 分离
- UnifiedProgressManager 提供统一进度写入入口
- 边界检查通过
- Swift 编译在 Trae 环境未验证

## 2. S6.P2 遗留缺口确认

### 已解决缺口
| 缺口 | S6.P2 状态 | S6.P3 状态 |
|------|-----------|-----------|
| ChapterCacheStore 接入正文加载流程 | 未接入 | ✅ 已接入 |
| Progress source of truth 统一入口 | 未实现 | ✅ 已实现 |

### 模块边界核验
- ReaderShellValidation (CoreIntegration) 依赖 ReaderAppSupport ✅
- ReaderAppPersistence 依赖 ReaderAppSupport ✅
- ReaderApp 依赖 ReaderShellValidation 和 ReaderAppPersistence ✅
- 通过协议解耦，不破坏边界检查

## 3. 模块边界核验

### 依赖关系
```
ReaderAppSupport (协议定义)
    ↑
ReaderShellValidation (CoreIntegration) 使用 ChapterCaching 协议
    ↑
ReaderAppPersistence 实现 ChapterCaching 协议
    ↑
ReaderApp (App 层组装)
```

### 边界保证
- CoreIntegration 不直接依赖 ReaderAppPersistence
- 通过 ReaderAppSupport 中的协议建立边界
- 符合 check_ios_boundary.sh 要求

## 4. ChapterCacheStore 与正文加载流程接入

### 协议定义 (ReaderAppSupport)
```swift
public protocol ChapterCaching: AnyObject {
    func loadEntry(chapterURL: String, sourceID: String) throws -> ChapterCacheEntry?
    func saveEntry(_ entry: ChapterCacheEntry) throws
    func removeEntry(chapterURL: String, sourceID: String) throws
}

public extension ChapterCaching {
    func loadContent(chapterURL: String, sourceID: String) throws -> (html: String?, markdown: String?)?
    func saveContent(chapterURL: String, sourceID: String, bookURL: String, chapterTitle: String, html: String?, markdown: String?) throws
}
```

### ReadingFlowCoordinator 接入
```swift
private var chapterCache: ChapterCaching?

public func selectChapter(_ chapter: TOCItem) async {
    // Try cache first
    if let cache = chapterCache,
       let cachedContent = try? cache.loadContent(...),
       let html = cachedContent.html, !html.isEmpty {
        // Cache hit
        contentPage = ContentPage(...)
        return
    }
    
    // Cache miss - fetch from service
    contentPage = try await contentService.fetchContent(...)
    
    // Save to cache if successful
    if let cache = chapterCache, let content = contentPage {
        try? cache.saveContent(...)
    }
}
```

## 5. 缓存命中 / 未命中 / 损坏缓存行为

| 场景 | 行为 |
|------|------|
| cache hit | 返回缓存内容，直接更新 contentPage，不调用 ContentService |
| cache miss | 调用 ContentService.fetchContent |
| fetch 成功 | 写入 ChapterCacheStore，更新 contentPage |
| fetch 失败 | 设置 currentError，不写入缓存 |
| cache decode 失败 | 忽略缓存，继续 ContentService（try? 保护） |
| cache 写入失败 | 不影响正文展示（try? 保护） |
| Placeholder unavailable | 不会被伪装成真实成功，除非 cache hit |

## 6. ReadingProgressStore / BookshelfStore source of truth 实现

### 协议定义 (ReaderAppSupport)
```swift
public protocol ReadingProgressing: AnyObject {
    func saveProgress(_ progress: ReadingProgress) throws
    func loadProgress(bookID: String) throws -> ReadingProgress?
    func removeProgress(bookID: String) throws
}

public protocol BookshelfProgressing: AnyObject {
    func updateProgress(bookID: String, progress: Double, chapterTitle: String?, chapterURL: String?) throws
    func loadProgressSummary(bookID: String) throws -> (progress: Double, chapterTitle: String?, chapterURL: String?)?
}
```

### UnifiedProgressManager
```swift
public final class UnifiedProgressManager {
    private let readingProgressStore: ReadingProgressing
    private let bookshelfProgressStore: BookshelfProgressing?
    
    public func saveCurrentProgress(...) throws {
        // Save to precise progress store (source of truth)
        try readingProgressStore.saveProgress(progress)
        
        // Sync summary to bookshelf store if available
        try bookshelfProgressStore?.updateProgress(...)
    }
    
    public func loadCurrentProgress(bookID: String) throws -> ReadingProgress? {
        return try readingProgressStore.loadProgress(bookID: bookID)
    }
}
```

### 职责边界
| 组件 | 职责 | Key |
|------|------|-----|
| ReadingProgressStore | 精确阅读进度 source of truth | bookID |
| BookshelfStore | 书架展示摘要进度 | bookID |
| UnifiedProgressManager | 统一写入入口，双写协调 | - |

## 7. 新增 / 更新测试

### 新增测试
| 测试 | 说明 |
|------|------|
| testBookshelfLoadProgressSummary | BookshelfProgressing 协议方法测试 |
| testUnifiedProgressManagerSavesToBothStores | 统一进度管理器双写测试 |

### 测试统计
| 测试文件 | 新增测试数 |
|----------|-----------|
| PersistencePublicSurfaceTests.swift | +2 |

## 8. 边界检查与测试结果

| 检查项 | 结果 |
|--------|------|
| 边界检查 | ✅ PASS (checked_files=66) |
| ChapterCaching 协议 | ✅ 已定义 |
| ChapterCacheStore 实现 | ✅ 已遵循 |
| ReadingFlowCoordinator 接入 | ✅ 已实现 |
| ReadingProgressing 协议 | ✅ 已定义 |
| UnifiedProgressManager | ✅ 已实现 |
| Swift 编译 | ⚠️ ENV_COMPILE_UNVERIFIED |

## 9. 剩余 P0 / P1 / P2 缺口

### P0 必须解决
- 无

### P1 应尽快解决
- 无（S6.P3 已完成目标）

### P2 后续优化
| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 预加载 | 中 |
| P2-2 | 离线阅读完整策略 | 中 |
| P2-3 | 阅读位置精细恢复 | 低 |
| P2-4 | 缓存过期策略 | 低 |
| P2-5 | 多源正文 fallback | 高 |

## 10. S6.P4 或 S6 综合验收推荐任务

### 推荐：S6 综合验收
S6 阶段核心能力已完成：
- ✅ 上一章/下一章导航 (S6.P1)
- ✅ ChapterCacheEntry 扩展 (S6.P1)
- ✅ 缓存接入正文流程 (S6.P3)
- ✅ 进度 source of truth 统一 (S6.P3)

### S6.P4 可选任务
- 缓存命中/未命中集成测试
- 进度保存恢复集成测试
- S6 阶段综合文档整理
