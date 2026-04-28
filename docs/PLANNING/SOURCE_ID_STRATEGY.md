# Source ID Strategy Document

## Status

**Status**: TEMPORARY WORKAROUND  
**Last Updated**: 2026-04-28  
**Target**: Replace with real BookSource ID

---

## 1. 当前临时方案

### 问题描述

当前 Reader-for-iOS 使用 `bookURL` 作为 `sourceID` 的临时替代：

```swift
// BookDetailView.swift:38
isInBookshelf = (try? bookshelfStore.find(bookURL: result.detailURL, sourceID: result.detailURL)) != nil

// ReaderViewModel.swift:96
let sourceID = bookURL
```

### 临时方案原因

| Reason | Description |
|--------|-------------|
| BookSource 模型未标准化 | 尚未从真实书源 JSON 中解析出稳定的 sourceID |
| 开发进度优先 | 先完成主链路，sourceID 问题后续解决 |
| Mock 服务限制 | MockReaderCoreService 不提供真实书源信息 |

### 临时方案风险

| Risk | Impact | Mitigation |
|------|--------|------------|
| 数据重复 | 同一本书可能从不同书源获取，导致书架重复 | 后续用真实 sourceID 去重 |
| 同步问题 | 云同步时无法正确识别同一书源 | sourceID 稳定后重新同步 |
| 迁移复杂度 | 后续替换需要数据迁移 | 提前规划迁移脚本 |

---

## 2. 预期稳定策略

### 目标状态

当接入真实 BookSource 后，`sourceID` 应来自：

| Source | Field | Description |
|--------|-------|-------------|
| BookSource JSON | `id` 或 `bookSourceUrl` | 书源唯一标识 |
| BookSource JSON | `name` | 书源名称（辅助标识） |

### 数据模型更新

```swift
// 稳定后的 BookshelfItem
struct BookshelfItem {
    let sourceID: String        // 真实书源 ID
    let sourceName: String      // 书源名称
    let bookURL: String         // 书籍详情页 URL
    // ...
}
```

### 迁移步骤

1. **Phase 1**: 保留现有数据结构，添加 `sourceName` 字段
2. **Phase 2**: 当获取真实书源时，更新 `sourceID` 为真实值
3. **Phase 3**: 清理旧的临时数据

---

## 3. 与真实书源联调的关系

### 依赖关系

```
真实书源联调 → BookSource 解析 → sourceID 稳定 → 云同步
     ↑                                  │
     │                                  ↓
     └───────────── 数据迁移 ←───────────
```

### 联调准备清单

- [ ] 接入真实 BookSource JSON
- [ ] 解析 BookSource 的 `id` / `bookSourceUrl` 字段
- [ ] 更新 BookshelfStore 使用真实 sourceID
- [ ] 实现数据迁移脚本
- [ ] 更新相关 ViewModel 使用真实 sourceID

---

## 4. 技术债追踪

### 代码位置

| File | Line | Issue |
|------|------|-------|
| BookDetailView.swift | 38 | 使用 bookURL 作为 sourceID |
| BookDetailView.swift | 210 | 使用 bookURL 作为 sourceID |
| ReaderViewModel.swift | 96 | 使用 bookURL 作为 sourceID |

### 修复优先级

- **High**: 真实书源联调前必须修复
- **Blocking**: 不修复将导致数据一致性问题

---

## Conclusion

当前使用 `bookURL` 作为 `sourceID` 是临时方案，存在数据重复和后续迁移风险。需在真实书源联调阶段修复，确保 sourceID 来自真实 BookSource 数据。