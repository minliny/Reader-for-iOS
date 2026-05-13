# S6.P0 阅读流程 / 进度 / 缓存能力层审计

## 1. 本轮结论

**结论**: `READING_CAPABILITY_READY_ENV_UNVERIFIED`

**说明**:
- 阅读流程能力层已形成本仓 Mock 闭环
- ReadingProgressStore 进度保存/读取能力已具备
- ReaderSettingsStore 阅读设置保存/读取能力已具备
- ChapterCacheStore 独立缓存能力已具备，流程接入待补强
- BookshelfStore 书架管理能力已具备，进度更新已覆盖
- ReaderViewModel 提供完整阅读状态流
- **当前 real mode 是 Placeholder，不代表真实 Reader-Core 能力**
- **ChapterCacheStore 未接入 ContentService / ReadingFlowCoordinator**
- Swift 编译在 Trae 环境未验证

## 2. 审计范围

| 范围 | 内容 |
|------|------|
| 阅读流程入口 | ReaderViewModel + ReadingFlowCoordinator |
| 进度存储 | ReadingProgressStore + BookshelfStore |
| 章节缓存 | ChapterCacheStore |
| 阅读设置 | ReaderSettingsStore + ReaderDisplaySettings |
| 状态流 | ReaderState 枚举 |
| Mock/Placeholder 路由 | ReaderCoreServiceProvider |

## 3. 真实文件路径

| 文件 | 状态 | 用途 |
|------|------|------|
| `iOS/Features/Reader/ReaderViewModel.swift` | ✅ | 阅读 ViewModel |
| `iOS/Features/Reader/ReaderSettingsPanel.swift` | ✅ | 阅读设置面板 |
| `iOS/CoreIntegration/ReadingFlowCoordinator.swift` | ✅ | 阅读流程协调 |
| `iOS/App/Persistence/ReadingProgressStore.swift` | ✅ | 阅读进度存储 |
| `iOS/App/Persistence/ChapterCacheStore.swift` | ✅ | 章节缓存 |
| `iOS/App/Persistence/ReaderSettingsStore.swift` | ✅ | 阅读设置存储 |
| `iOS/App/Persistence/BookshelfStore.swift` | ✅ | 书架存储 |
| `iOS/AppSupport/Sources/ReadingProgress.swift` | ✅ | 进度数据结构 |
| `iOS/AppSupport/Sources/ChapterCacheEntry.swift` | ✅ | 缓存数据结构 |
| `iOS/AppSupport/Sources/ReaderDisplaySettings.swift` | ✅ | 显示设置数据结构 |
| `iOS/Tests/ReaderAppPersistenceTests/PersistencePublicSurfaceTests.swift` | ✅ | 持久化测试 |

## 4. 阅读流程能力状态表

| 能力项 | 状态 | 说明 |
|--------|------|------|
| 阅读状态流 | ✅ 已实现 | ReaderState 枚举 |
| ReaderViewModel | ✅ 已实现 | 完整阅读状态管理 |
| ReadingFlowCoordinator | ✅ 已实现 | 跨阶段协调 |
| Mock 路由 | ✅ 已实现 | ReaderCoreServiceProvider.mock |
| Placeholder 路由 | ✅ 已实现 | PlaceholderServiceError |
| real mode 真实阅读 | ❌ 未实现 | 返回 unsupported |
| 上一章/下一章 | ⚠️ 部分实现 | ContentView 层面，Coordinator 无显式 API |
| 阅读进度保存 | ✅ 已实现 | ReaderViewModel + BookshelfStore |
| 阅读进度恢复 | ⚠️ 部分实现 | BookshelfStore 提供 lastReadChapterURL |
| 阅读设置保存/读取 | ✅ 已实现 | ReaderSettingsStore |
| 章节缓存保存/读取 | ✅ 已实现 | ChapterCacheStore |
| 章节缓存接入正文 | ❌ 未接入 | 独立 Store |

## 5. ReadingProgressStore 契约

### 数据结构

```swift
public struct ReadingProgress: Codable, Equatable {
    public let bookID: String
    public let sourceID: String
    public let bookURL: String
    public let chapterURL: String
    public let chapterTitle: String
    public var progressRatio: Double
    public var updatedAt: Date
}
```

### Store 实现

```swift
public final class ReadingProgressStore: @unchecked Sendable {
    public static let shared = ReadingProgressStore()
    
    private let fileURL: URL  // reading_progress.json
    private let lock = NSLock()
    
    public func loadProgress(bookID: String) throws -> ReadingProgress?
    public func saveProgress(_ progress: ReadingProgress) throws
    public func removeProgress(bookID: String) throws
}
```

### 契约核验

| 契约项 | 状态 | 说明 |
|--------|------|------|
| 存储位置 | ✅ | Documents/reading_progress.json |
| 数据格式 | ✅ | JSON |
| key 设计 | ✅ | bookID |
| 绑定 book/chapter/source | ✅ | ReadingProgress 包含所有字段 |
| 保存 | ✅ | saveProgress() |
| 读取 | ✅ | loadProgress() |
| 删除 | ✅ | removeProgress() |
| 损坏数据处理 | ❌ | 无显式处理，decoder.decode 失败会抛异常 |
| 线程安全 | ✅ | NSLock |
| 测试覆盖 | ✅ | PersistencePublicSurfaceTests |

## 6. ChapterCacheStore 契约

### 数据结构

```swift
public struct ChapterCacheEntry: Codable, Equatable {
    public let sourceID: String
    public let bookURL: String
    public let chapterURL: String
    public let chapterTitle: String
    public let cachedAt: Date
    public var status: ChapterCacheStatus
}

public enum ChapterCacheStatus: String, Codable {
    case notCached
    case cached
    case failed
}
```

### Store 实现

```swift
public final class ChapterCacheStore: @unchecked Sendable {
    public static let shared = ChapterCacheStore()
    
    private let fileURL: URL  // chapter_cache.json
    private let lock = NSLock()
    
    private func cacheKey(chapterURL: String, sourceID: String) -> String {
        return "\(sourceID)_\(chapterURL)"
    }
    
    public func loadEntry(chapterURL: String, sourceID: String) throws -> ChapterCacheEntry?
    public func saveEntry(_ entry: ChapterCacheEntry) throws
    public func removeEntry(chapterURL: String, sourceID: String) throws
}
```

### 契约核验

| 契约项 | 状态 | 说明 |
|--------|------|------|
| 存储位置 | ✅ | Documents/chapter_cache.json |
| 数据格式 | ✅ | JSON |
| key 设计 | ✅ | "\(sourceID)_\(chapterURL)" |
| 缓存内容 | ✅ | ChapterCacheEntry (元数据 + 正文) |
| 绑定 source/chapter | ✅ | Key 包含 sourceID + chapterURL |
| 保存 | ✅ | saveEntry() |
| 读取 | ✅ | loadEntry() |
| 删除 | ✅ | removeEntry() |
| 损坏数据处理 | ❌ | 无显式处理，decoder.decode 失败会抛异常 |
| 线程安全 | ✅ | NSLock |
| 测试覆盖 | ✅ | PersistencePublicSurfaceTests |
| 接入 ContentService | ❌ | 未接入，独立 Store |

## 7. ReaderSettingsStore / ReaderDisplaySettings 契约

### 数据结构

```swift
public struct ReaderDisplaySettings: Codable, Equatable {
    public var fontSize: Int
    public var fontFamily: String
    public var lineSpacing: Double
    public var paragraphSpacing: Double
    public var horizontalPadding: Double
    public var verticalPadding: Double
    public var backgroundMode: ReaderBackgroundMode
    
    public static let `default` = ReaderDisplaySettings()
}

public enum ReaderBackgroundMode: String, Codable, CaseIterable {
    case light
    case sepia
    case dark
}
```

### Store 实现

```swift
public final class ReaderSettingsStore: @unchecked Sendable {
    public static let shared = ReaderSettingsStore()
    
    private let fileURL: URL  // reader_settings.json
    private let lock = NSLock()
    
    public func loadSettings() throws -> ReaderDisplaySettings
    public func saveSettings(_ settings: ReaderDisplaySettings) throws
    public func resetToDefaults() throws
}
```

### 契约核验

| 契约项 | 状态 | 说明 |
|--------|------|------|
| 字体大小 | ✅ | fontSize: Int |
| 主题/背景 | ✅ | backgroundMode: light/sepia/dark |
| 行距 | ✅ | lineSpacing: Double |
| 段距 | ✅ | paragraphSpacing: Double |
| 保存 | ✅ | saveSettings() |
| 读取 | ✅ | loadSettings() |
| 默认值 | ✅ | ReaderDisplaySettings.default |
| 测试覆盖 | ✅ | PersistencePublicSurfaceTests |

## 8. ReadingFlowCoordinator 阅读状态契约

### 状态属性

| 状态 | 类型 | 说明 |
|------|------|------|
| selectedSource | BookSource? | 当前选中书源 |
| searchResults | [SearchResultItem] | 搜索结果 |
| selectedBook | SearchResultItem? | 选中书籍 |
| tocItems | [TOCItem] | 目录列表 |
| selectedChapter | TOCItem? | 选中章节 |
| contentPage | ContentPage? | 正文内容 |
| isLoading | Bool | 加载状态 |
| currentError | ReaderError? | 当前错误 |

### 上一章/下一章能力

**结论**: ReadingFlowCoordinator **没有** 显式的 `previousChapter()` / `nextChapter()` API。

**当前实现**:
- 上一章/下一章逻辑在 ContentView 层面实现
- 通过 `tocItems.firstIndex` 计算当前章节索引
- 边界检查：`index > 0` / `index < count - 1`

**测试状态**:
- S5.P1 测试验证的是边界逻辑，不是显式 API
- S6.P1 建议补齐 Coordinator 级上一章/下一章能力

## 9. Bookshelf / Progress 连接

### BookshelfStore 实现

```swift
public final class BookshelfStore: @unchecked Sendable {
    public static let shared = BookshelfStore()
    
    private let fileURL: URL  // bookshelf.json
    private let lock = NSLock()
    
    public func loadItems() throws -> [BookshelfItem]
    public func saveItems(_ items: [BookshelfItem]) throws
    public func addOrUpdate(_ item: BookshelfItem) throws
    public func remove(id: String) throws
    public func updateProgress(bookID: String, progress: Double, chapterTitle: String?, chapterURL: String?) throws
    public func find(bookURL: String, sourceID: String) throws -> BookshelfItem?
}
```

### 进度 Source of Truth

| Store | 职责 | 状态 |
|-------|------|------|
| ReadingProgressStore | 独立进度存储 | ✅ 已实现 |
| BookshelfStore | 书架+进度 | ✅ 已实现 |

**当前状态**:
- 进度写入两个 Store：`ReadingProgressStore` 和 `BookshelfStore`
- `ReaderViewModel.saveReadingProgress()` 调用 `BookshelfStore.updateProgress()`
- `ReadingProgressStore` 独立存在但未被 `ReaderViewModel` 调用
- **存在双写风险，但不影响当前 Mock 闭环**

### 进度恢复

```swift
// ReaderViewModel.saveReadingProgress()
private func saveReadingProgress() async {
    if let existingItem = try? bookshelfStore.find(bookURL: bookURL, sourceID: sourceIdentity.id) {
        try? bookshelfStore.updateProgress(
            bookID: existingItem.id,
            progress: 0.0,
            chapterTitle: chapterTitle,
            chapterURL: chapterURL
        )
    }
}
```

**进度恢复现状**:
- `lastReadChapterURL` 和 `lastReadChapterTitle` 存在于 `BookshelfItem`
- 但 `ReaderViewModel` 没有显式恢复上次阅读章节的逻辑
- 阅读恢复依赖 UI 层手动处理

## 10. 测试覆盖

### 已有测试

| 测试文件 | 测试数 | 覆盖 |
|----------|--------|------|
| `PersistencePublicSurfaceTests.swift` | 30+ | ReadingProgressStore, ChapterCacheStore, ReaderSettingsStore, BookshelfStore, BookSourceStore |

### 测试覆盖统计

| Store | 保存/读取 | 损坏数据 | 更新 | 删除 | 查找 |
|-------|----------|----------|------|------|------|
| ReadingProgressStore | ✅ | ❌ | ✅ | ✅ | ✅ |
| ChapterCacheStore | ✅ | ❌ | ✅ | ✅ | ✅ |
| ReaderSettingsStore | ✅ | ❌ | ✅ | - | - |
| BookshelfStore | ✅ | ❌ | ✅ | ✅ | ✅ |

### 边界检查结果

| 检查项 | 结果 |
|--------|------|
| 边界检查脚本 | ✅ PASS (checked_files=65) |
| Swift 编译 | ⚠️ ENV_COMPILE_UNVERIFIED |

## 11. P0 / P1 / P2 缺口清单

### P0 必须解决

| ID | 缺口 | 状态 |
|----|------|------|
| 无 | - | - |

### P1 应尽快解决

| ID | 缺口 | 优先级 | 说明 |
|----|------|--------|------|
| P1-1 | ChapterCacheStore 接入 ContentService | 中 | 缓存已实现但未使用 |
| P1-2 | ReadingFlowCoordinator 上一章/下一章显式 API | 低 | 当前在 ContentView 层面实现 |
| P1-3 | 进度 Source of Truth 统一 | 低 | ReadingProgressStore 未被调用 |
| P1-4 | 损坏数据处理 | 低 | Store 无显式损坏数据处理 |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 预加载 | 中 |
| P2-2 | 离线阅读 | 中 |
| P2-3 | 精细阅读位置恢复 | 低 |
| P2-4 | 缓存迁移版本 | 低 |
| P2-5 | 多源正文 fallback | 高 |
| P2-6 | 阅读统计 | 低 |

### 不属于当前 S6 的任务

| 任务 | 归属 | 说明 |
|------|------|------|
| 真实 Reader-Core 阅读接入 | S1.P2 | 需 Reader-Core 可用环境 |
| 进度恢复 UI 逻辑 | S7 或后续 | 依赖 UI 层设计 |

## 12. 与 Reader-Core 的边界说明

| 边界项 | 说明 |
|--------|------|
| ReadingProgress | ✅ public API (ReaderCoreModels) |
| ChapterCacheEntry | ⚠️ 本仓定义 |
| ReaderDisplaySettings | ⚠️ 本仓定义 |
| ReaderSettingsStore | ⚠️ 本仓实现 |
| ReadingProgressStore | ⚠️ 本仓实现 |
| ChapterCacheStore | ⚠️ 本仓实现 |
| BookshelfStore | ⚠️ 本仓实现 |

**边界保证**: 阅读流程能力层使用本仓实现的 Store，不依赖 Reader-Core 内部实现。

## 13. S6.P1 推荐能力建设任务

**任务 ID**: S6.P1
**任务名称**: 阅读流程契约测试与缓存接入

**任务内容**:
1. 添加 ChapterCacheStore 接入 ContentService 测试
2. 验证 ReadingFlowCoordinator 上一章/下一章能力
3. 验证进度保存/恢复流程
4. 统一进度 Source of Truth

**前提条件**: 无需 Reader-Core

## 14. 本轮未做事项

| 事项 | 原因 |
|------|------|
| ChapterCacheStore 接入 ContentService | 待 S6.P1 实现 |
| ReadingFlowCoordinator 上一章/下一章 API | 待 S6.P1 实现 |
| 进度 Source of Truth 统一 | 涉及架构调整 |
| 损坏数据处理 | P1 低优先级 |
| 真实 Core 接入 | S1.P2 暂停 |
