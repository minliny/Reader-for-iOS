# S6.P2 缓存接入与进度 Source of Truth 统一

## 1. 本轮结论

**结论**: `READY_WITH_REMAINING_GAPS + ENV_COMPILE_UNVERIFIED`

**说明**:
- ChapterCacheEntry Codable 兼容性已验证
- ReadingFlowCoordinator 已添加 chapterCacheStore 可选依赖和 setter
- Progress source of truth 职责已文档化
- ChapterCacheStore 接入正文流程因模块边界限制暂缓
- 缓存接入需通过 ShellAssembly 或 iOS App 层实现
- 边界检查通过
- Swift 编译在 Trae 环境未验证

## 2. S6.P1 结论修正

### 原结论修正
- 原结论 `CONTENT_CONTRACT_READY_ENV_UNVERIFIED` 修正为 `READY_WITH_REMAINING_GAPS + ENV_COMPILE_UNVERIFIED`
- S6.P1 已完成上一章/下一章 API 和缓存模型扩展
- ChapterCacheStore 尚未接入 ContentService / ReadingFlowCoordinator 正文加载流程
- Progress source of truth 仍需 S6.P2 明确

## 3. ChapterCacheEntry Codable 兼容性

### 测试覆盖
| 测试 | 状态 |
|------|------|
| 旧格式 JSON decode | ✅ 已验证 |
| 新格式 JSON decode | ✅ 已验证 |
| contentHTML/contentMarkdown 编码读取 | ✅ 已验证 |

### 兼容性保证
- `contentHTML: String?` 为 optional，默认为 nil
- `contentMarkdown: String?` 为 optional，默认为 nil
- 旧缓存 JSON 缺少这两个字段时仍可正确 decode
- 不引入复杂迁移系统

## 4. ChapterCacheStore 与 Content 流程接入

### 模块边界限制

**问题**: `iOS/CoreIntegration/ReadingFlowCoordinator.swift` 无法直接导入 `ReaderAppPersistence/ChapterCacheStore`

**原因**: Package.swift 中 ReaderCoreIntegration 未定义，CoreIntegration 层不应依赖 App 层模块

**当前方案**:
1. ReadingFlowCoordinator 添加可选依赖注入:
   ```swift
   private var chapterCacheStore: ChapterCacheStore?
   
   public func setChapterCacheStore(_ store: ChapterCacheStore?) {
       self.chapterCacheStore = store
   }
   ```
2. 通过 ShellAssembly 或 iOS App 层注入缓存依赖

### 缓存接入设计（待实现）

**最小策略**:
- `selectChapter` 入口优先查 `ChapterCacheStore`
- `cache hit`: 直接更新 `contentPage`
- `cache miss`: 调用 `ContentService.fetchContent`
- `fetch` 成功: 写入 `ChapterCacheStore`
- `cache decode` 失败: 忽略缓存并走 `ContentService`
- 不做预加载
- 不做离线阅读完整策略
- 不做多源 fallback

## 5. 缓存命中 / 未命中 / 损坏缓存契约

### 契约设计

| 场景 | 行为 |
|------|------|
| cache hit | 返回 `ChapterCacheEntry.contentHTML/contentMarkdown`，更新 `contentPage` |
| cache miss | 调用 `ContentService.fetchContent` |
| fetch 成功 | 写入 `ChapterCacheStore`，更新 `contentPage` |
| fetch 失败 | 设置 `currentError`，不写入缓存 |
| cache corrupted | 忽略缓存，走 `ContentService`，记录日志 |

### Placeholder / Real unavailable 契约

- Placeholder 返回 `realCoreNotAvailable` 错误
- 缓存命中可绕过 Placeholder unavailable（离线场景）
- 需明确文档化此行为

## 6. ReadingProgressStore / BookshelfStore source of truth

### 职责边界

| 组件 | 职责 | Key |
|------|------|-----|
| ReadingProgressStore | 精确阅读进度存储 | bookID |
| BookshelfStore | 书架管理 + 进度摘要 | bookURL + sourceID |

### 数据结构对比

**ReadingProgress**:
```swift
struct ReadingProgress: Codable {
    let bookID: String
    let sourceID: String
    let bookURL: String
    let chapterURL: String      // 精确章节
    let chapterTitle: String
    var progressRatio: Double   // 章节内进度
    var updatedAt: Date
}
```

**BookshelfItem**:
```swift
struct BookshelfItem: Codable {
    let id: String
    let sourceID: String
    let bookURL: String
    let title: String
    var lastReadChapterTitle: String?  // 摘要
    var lastReadChapterURL: String?    // 摘要
    var readingProgress: Double         // 0-100 百分比
}
```

### 双写风险

**当前状态**:
- `ReaderViewModel.saveReadingProgress()` 调用 `BookshelfStore.updateProgress()`
- `ReadingProgressStore` 独立存在但未被使用

**建议方案**:
- `ReadingProgressStore` 作为精确阅读进度 source of truth
- `BookshelfStore` 只保存书架展示用摘要进度
- 需在 iOS App 层实现统一入口

## 7. 新增 / 更新测试

### 测试统计

| 测试文件 | 新增测试 |
|----------|----------|
| PersistencePublicSurfaceTests.swift | +3 |

### 新增测试

1. **ChapterCacheStore 兼容性**:
   - `testChapterCacheLegacyJSONCompatibility`: 旧格式 JSON 兼容性

2. **Progress Source of Truth**:
   - `testReadingProgressStoresDetailedChapterInfo`: 精确章节信息存储

## 8. 边界检查与测试结果

| 检查项 | 结果 |
|--------|------|
| 边界检查 | ✅ PASS (checked_files=66) |
| ReadingFlowCoordinator 缓存依赖 | ✅ 已添加 |
| ChapterCacheEntry 兼容性 | ✅ 已验证 |
| Swift 编译 | ⚠️ ENV_COMPILE_UNVERIFIED |

## 9. 剩余 P0 / P1 / P2 缺口

### P0 必须解决
- 无

### P1 应尽快解决
| ID | 缺口 | 优先级 | 说明 |
|----|------|--------|------|
| P1-1 | ChapterCacheStore 接入正文流程 | 中 | 需 iOS App 层实现 |
| P1-2 | 进度 source of truth 统一 | 中 | 需 iOS App 层实现 |

### P2 后续优化
| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 预加载 | 中 |
| P2-2 | 离线阅读完整策略 | 中 |
| P2-3 | 阅读位置精细恢复 | 低 |

## 10. S6.P3 推荐任务

### 任务 ID: S6.P3
### 任务名称: iOS App 层缓存与进度集成

### 任务内容
1. 在 iOS App 层实现 `ReadingFlowCoordinator.setChapterCacheStore()` 调用
2. 实现 `selectChapter` 中的缓存命中/未命中逻辑
3. 实现进度保存的统一入口
4. 测试缓存命中/未命中/损坏流程

### 前提条件
- 需 iOS App 层有完整编译环境
- 需 Reader-AppPersistence 模块可用
