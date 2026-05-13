# S6.P1 阅读流程契约测试与缓存接入能力补强

## 1. 本轮结论

**结论**: `READY_WITH_REMAINING_GAPS + ENV_COMPILE_UNVERIFIED`

**说明**:
- 已完成 ReadingFlowCoordinator 上一章/下一章显式 API 能力补强
- 已完成 ChapterCacheEntry 数据模型扩展，支持正文内容缓存
- 已完成测试覆盖，包括 ReadingFlow 契约和 ChapterCacheEntry 扩展
- **ChapterCacheStore 尚未接入 ContentService / ReadingFlowCoordinator 正文加载流程**
- **Progress source of truth 仍需 S6.P2 明确**
- 边界检查通过
- Swift 编译在 Trae 环境未验证
- 缓存接入正文流程作为后续任务（S6.P2+）

## 2. S6.P0 结论修正

### 原结论修正
- 原结论 `READING_CAPABILITY_READY_ENV_UNVERIFIED` 修正为 `READY_WITH_GAPS + ENV_COMPILE_UNVERIFIED`
- 说明 S6.P0 是审计通过，不是能力完全 READY
- 已发现多项持久化测试定义，但当前未通过 swift test 编译验证

## 3. ReadingFlowCoordinator 上一章/下一章能力

### 新增 API
```swift
public var canMoveToPreviousChapter: Bool
public var canMoveToNextChapter: Bool
public func moveToPreviousChapter() async
public func moveToNextChapter() async
```

### 行为契约
- `canMoveToPreviousChapter`: 当前不是第一章时返回 true
- `canMoveToNextChapter`: 当前不是最后一章时返回 true
- `moveToPreviousChapter`: 切换到上一章并重新加载内容
- `moveToNextChapter`: 切换到下一章并重新加载内容
- 章节切换复用现有 `selectChapter` 流程

## 4. ChapterCacheStore 与 Content 流程接入契约

### 数据模型扩展
```swift
public struct ChapterCacheEntry: Codable, Equatable {
    // 已有字段
    public let sourceID: String
    public let bookURL: String
    public let chapterURL: String
    public let chapterTitle: String
    public let cachedAt: Date
    public var status: ChapterCacheStatus
    
    // 新增字段
    public var contentHTML: String?
    public var contentMarkdown: String?
}
```

### 缓存接入策略（S6.P2+ 计划）
- Content 加载前优先检查缓存
- 加载成功后写入缓存
- 损坏缓存时忽略缓存走正常流程
- 不影响现有 Mock/Placeholder/Real 路由语义
- 缓存独立作为可选增强功能

## 5. ReadingProgressStore / BookshelfStore source of truth

### 职责边界
| 组件 | 职责 |
|------|------|
| ReadingProgressStore | 精确阅读进度存储（完整 chapterURL、progressRatio） |
| BookshelfStore | 书架管理 + 进度摘要（lastReadChapterURL、readingProgress） |

### 当前状态
- ReaderViewModel 当前调用 BookshelfStore.updateProgress
- ReadingProgressStore 独立存在但未被使用
- 建议：统一 source of truth，避免双写风险

## 6. 新增 / 更新测试

### 新增测试文件
- `iOS/Tests/ShellSmokeTests/ReadingFlowContractTests.swift`: ReadingFlow 导航契约

### 更新测试
- `iOS/Tests/ReaderAppPersistenceTests/PersistencePublicSurfaceTests.swift`: ChapterCacheEntry 内容字段测试

### 测试覆盖
| 测试组 | 覆盖内容 |
|--------|----------|
| ReadingFlow 导航 | canMoveToPrevious/Next 边界检查 |
| ChapterCacheEntry | contentHTML/contentMarkdown 字段 |
| Persistence | 已有能力保持不变 |

## 7. 边界检查与测试结果

| 检查项 | 结果 |
|--------|------|
| 边界检查 | ✅ PASS (checked_files=66) |
| ReadingFlow API | ✅ 已实现 |
| ChapterCacheEntry 扩展 | ✅ 已实现 |
| 测试定义 | ✅ 已新增 |
| Swift 编译 | ⚠️ ENV_COMPILE_UNVERIFIED |

## 8. 剩余 P0 / P1 / P2 缺口

### P0 必须解决
- 无

### P1 应尽快解决
| ID | 缺口 | 优先级 | 说明 |
|----|------|--------|------|
| P1-1 | ChapterCacheStore 接入 ContentService | 中 | 缓存已实现但未使用 |
| P1-2 | 进度 source of truth 统一 | 低 | ReadingProgressStore 未被使用 |

### P2 后续优化
| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 预加载 | 中 |
| P2-2 | 离线阅读完整策略 | 中 |
| P2-3 | 阅读位置精细恢复 | 低 |
| P2-4 | 缓存迁移版本 | 低 |
| P2-5 | 多源正文 fallback | 高 |

## 9. S6.P2 推荐任务

### 任务 ID: S6.P2
### 任务名称: 缓存接入与进度统一

### 任务内容
1. 实现 ChapterCacheStore 接入 ContentService 最小流程
2. 统一阅读进度 source of truth（ReadingProgressStore 或 BookshelfStore）
3. 测试缓存命中/未命中流程
