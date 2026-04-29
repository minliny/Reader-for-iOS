# ReaderAppSupport Target Extraction Plan

**Status**: PLANNED_ONLY
**Created**: 2026-04-29
**Last Updated**: 2026-04-29

---

## 1. 当前问题

ReaderApp target 当前不适合被 ShellSmokeTests 直接依赖。

**根因**：
- ReaderApp target 混入了 iOS-only SwiftUI views（如 `BookSourceImportView` 使用 `navigationBarTitleDisplayMode`，`BookDetailView` 使用 `CGColor.secondarySystemBackground`）
- ReaderApp 在 macOS CI runner 上暴露平台兼容错误和类型可见性问题
- `ReaderCoreServiceProvider` 位于 `ReaderShellValidation` target 中，但 `ReaderApp` Features/ViewModels 引用它，导致跨 target scope 错误
- `SourceIdentity.swift` 引用 `SearchResultItem` 但缺少 `import ReaderCoreModels`

**直接影响**：
- Persistence tests（BookshelfStore、ReadingProgressStore、ReaderSettingsStore 等）因此 BLOCKED
- 无法通过 `ShellSmokeTests` 对 App Models 和 Persistence stores 进行单元测试

---

## 2. 当前证据

| 指标 | 状态 |
|------|------|
| ReaderApp compile | FAILED_DIAGNOSED |
| Persistence tests | BLOCKED |
| Testing Boundary | FIXED |
| Public Surface Smoke | RESTORED |
| CI status | GREEN |
| Boundary check | PASS (checked_files=53) |
| ReaderAppSupport target extraction | PLANNED_ONLY |

**编译错误分类**（来自 CI diagnostic step）：

| 分类 | 错误数 | 示例 |
|------|--------|------|
| missing_type_or_import | 7 | `cannot find type 'SearchResultItem'`、`cannot find 'ReaderCoreServiceProvider'` |
| platform_availability | 3 | `'navigationBarTitleDisplayMode' is unavailable in macOS`、`CGColor.secondarySystemBackground` 不存在 |
| existing_code_compile_error | 2 | `argument passed to call that takes no arguments` |
| access_control | 1 | `ReaderCoreServiceProvider` 对 ReaderApp target 不可见 |

---

## 3. App Models 依赖审查

| 文件 | Foundation | SwiftUI | ReaderCoreModels | ReaderCoreParser | ReaderCoreNetwork |
|------|------------|---------|------------------|------------------|-------------------|
| `BookshelfItem.swift` | ✅ | ❌ | ❌ | ❌ | ❌ |
| `ChapterCacheEntry.swift` | ✅ | ❌ | ❌ | ❌ | ❌ |
| `ReaderDisplaySettings.swift` | ✅ | ❌ | ❌ | ❌ | ❌ |
| `ReadingProgress.swift` | ✅ | ❌ | ❌ | ❌ | ❌ |
| `SourceIdentity.swift` | ✅ | ❌ | ❌ (需要添加 `import ReaderCoreModels`) | ❌ | ❌ |

**结论**：所有 Models 仅依赖 `Foundation`。`SourceIdentity.swift` 需要添加 `import ReaderCoreModels` 来访问 `SearchResultItem`。

---

## 4. App Persistence 依赖审查

| 文件 | Foundation | SwiftUI | ReaderCoreModels | ReaderCoreParser | ReaderCoreNetwork |
|------|------------|---------|------------------|------------------|-------------------|
| `BookSourceStore.swift` | ✅ | ❌ | ✅ (`BookSource` 类型) | ❌ | ❌ |
| `BookshelfStore.swift` | ✅ | ❌ | ❌ | ❌ | ❌ |
| `ChapterCacheStore.swift` | ✅ | ❌ | ❌ | ❌ | ❌ |
| `ReaderSettingsStore.swift` | ✅ | ❌ | ❌ | ❌ | ❌ |
| `ReadingProgressStore.swift` | ✅ | ❌ | ❌ | ❌ | ❌ |

**结论**：所有 Persistence stores 仅依赖 `Foundation`。`BookSourceStore.swift` 额外依赖 `ReaderCoreModels`（`BookSource` 类型）。

---

## 5. 推荐 target 设计

新增 `ReaderAppSupport` target：

```
ReaderAppSupport
  ├── iOS/App/Models/
  │   ├── BookshelfItem.swift
  │   ├── ChapterCacheEntry.swift
  │   ├── ReaderDisplaySettings.swift
  │   ├── ReadingProgress.swift
  │   └── SourceIdentity.swift
  └── iOS/App/Persistence/
      ├── BookSourceStore.swift
      ├── BookshelfStore.swift
      ├── ChapterCacheStore.swift
      ├── ReaderSettingsStore.swift
      └── ReadingProgressStore.swift
```

**依赖约束**：
- ✅ Foundation
- ✅ ReaderCoreModels（仅在实际需要时）
- ✅ ReaderCoreProtocols（仅在实际需要时）
- ❌ SwiftUI
- ❌ ReaderApp
- ❌ ReaderCoreParser
- ❌ ReaderCoreNetwork
- ❌ ReaderCoreJSRenderer

---

## 6. 目标依赖关系

```
ReaderAppSupport:
  depends_on:
    - ReaderCoreModels, if needed
    - ReaderCoreProtocols, if needed

ReaderApp:
  depends_on:
    - ReaderAppSupport
    - ReaderShellValidation

ShellSmokeTests:
  depends_on:
    - ReaderShellValidation
    - ReaderAppSupport
    - ReaderCoreModels
```

---

## 7. 分阶段迁移计划

### Step 0：保持当前 CI GREEN

- 不修改任何文件
- 不改变 Package.swift
- 当前 CI 状态：GREEN

### Step 1：新增 ReaderAppSupport target 草案

- 在 Package.swift 中新增 `ReaderAppSupport` target
- sources: `["App/Models", "App/Persistence"]`
- dependencies: `ReaderCoreModels`（实际需要时）
- 修改 `ReaderApp` sources：移除 `"App"`，改为 `"Features"`, `"Modules"`, `"Navigation"`, `"Surface"`
- 修改 `ReaderApp` dependencies：添加 `"ReaderAppSupport"`
- 修改 `ShellSmokeTests` dependencies：添加 `"ReaderAppSupport"`

### Step 2：迁移 Models

- 将 5 个 Model 文件归入 `ReaderAppSupport` target
- 为 `SourceIdentity.swift` 添加 `import ReaderCoreModels`
- 验证 Models 可独立编译

### Step 3：迁移 Persistence

- 将 5 个 Store 文件归入 `ReaderAppSupport` target
- 为 `BookSourceStore.swift` 添加 `import ReaderCoreModels`
- 验证 Persistence 可独立编译

### Step 4：修复 Features/ViewModels imports

- 在所有引用 Models/Persistence 的 Features/ViewModels 中添加 `import ReaderAppSupport`
- 修复 `BookDetailViewModel`、`ChapterListViewModel`、`ReaderViewModel`、`SearchViewModel` 等
- 修复 `ReaderApp.swift` 入口
- 验证 ReaderApp 编译（或至少不新增错误）

### Step 5：更新 ShellSmokeTests dependencies

- 在 Package.swift 中为 `ShellSmokeTests` 添加 `"ReaderAppSupport"` 依赖
- 添加 `@testable import ReaderAppSupport` 到测试文件
- 验证测试可编译

### Step 6：添加 PersistencePublicSurfaceTests

- 创建 `iOS/Tests/ShellSmokeTests/PersistencePublicSurfaceTests.swift`
- 测试 BookshelfStore CRUD
- 测试 ReadingProgressStore save/load/remove
- 测试 ReaderSettingsStore save/load/reset
- 测试 ChapterCacheStore save/load/remove
- 测试 Models Codable / Equatable

### Step 7：CI 验证

- 验证 boundary check PASS
- 验证 ShellSmokeTests 全部通过
- 验证 ReaderAppSupport 可单独 build
- 验证无新增编译错误

### Step 8：清理诊断 workflow

- 移除 `ios-shell-ci.yml` 中的 "Diagnose ReaderApp target compilation" non-failing step
- 如 ReaderApp 编译问题已修复，可考虑将 ReaderApp build 纳入正常 CI

---

## 8. 风险清单

| # | 风险 | 严重程度 | 缓解措施 |
|---|------|----------|----------|
| R1 | SPM 文件归属冲突 | HIGH | SPM 不允许同一文件属于两个 target，必须从 ReaderApp sources 中完全移除 `App` |
| R2 | ReaderApp 编译错误扩大 | HIGH | ReaderApp 已有 8 类编译错误，迁移会暴露更多 `cannot find type` 错误 |
| R3 | Features/ViewModels import 修复范围大 | MEDIUM | 需要修改所有引用 Models 的文件的 import 语句 |
| R4 | macOS test runner 平台兼容问题 | MEDIUM | ReaderAppSupport 必须不包含任何 iOS-only APIs |
| R5 | CI GREEN 被破坏 | HIGH | 任何不完整的迁移都会导致 CI 失败 |
| R6 | SourceIdentity import 需求 | LOW | 需要为 SourceIdentity.swift 添加 `import ReaderCoreModels` |
| R7 | Persistence store 文件路径测试隔离 | LOW | Store 硬编码 Documents 目录路径，需要添加 test storage URL 支持 |
| R8 | 回滚策略缺失 | MEDIUM | 如果迁移失败，需要能够快速回滚 |

---

## 9. 实施前置条件

必须全部满足才能开始实施：

- [x] ReaderApp compile diagnostic 已归档
- [x] 当前 main CI GREEN
- [x] Models / Persistence 无 SwiftUI 依赖
- [ ] Migration plan 已确认
- [ ] 可以接受修改多个 import
- [ ] 有回滚策略
- [ ] 不影响 CoreBridge 边界

---

## 10. 验收标准

- [ ] `check_ios_boundary.sh` PASS
- [ ] `iOS/Tests` 不 import `ReaderCoreParser` / `ReaderCoreNetwork` / `ReaderCoreJSRenderer`
- [ ] `ReaderAppSupport` target 可单独 build
- [ ] `ShellSmokeTests` 可依赖 `ReaderAppSupport`
- [ ] `PersistencePublicSurfaceTests` 可运行
- [ ] `ReaderApp` 不因 target extraction 产生新增编译错误
- [ ] CI SUCCESS

---

## 11. 当前状态

| 项目 | 状态 |
|------|------|
| ReaderAppSupport target extraction | SKELETON_READY |
| Persistence tests | BLOCKED |
| 是否本轮实施 | YES (Step 1) |

## Step 1 Skeleton Feasibility

**完成情况**：
- ✅ ReaderAppSupport skeleton 是否已新增：YES
- ✅ 是否迁移 Models：NO
- ✅ 是否迁移 Persistence：NO
- ✅ 是否修改 ReaderApp 行为：NO
- ✅ 是否允许 Persistence tests：NO，仍需后续迁移

**下一步**：Step 2：Models migration feasibility

**推荐后续行动**：继续 Step 2，验证 Models 可独立编译。

---

## Step 2 Models Migration Feasibility

### 1. 当前状态确认
| 检查项 | 状态 |
|--------|------|
| 工作区 clean | ✅ |
| 当前 HEAD | dc6a883 |
| boundary check | PASS (checked_files=54) |
| CI status | GREEN |

### 2. Models 文件清单
共 5 个文件：
- `iOS/App/Models/BookshelfItem.swift`
- `iOS/App/Models/ChapterCacheEntry.swift`
- `iOS/App/Models/ReaderDisplaySettings.swift`
- `iOS/App/Models/ReadingProgress.swift`
- `iOS/App/Models/SourceIdentity.swift`

### 3. Models 依赖矩阵

| 文件名 | 类型名 | import Foundation | import SwiftUI | import ReaderCoreModels | import ReaderCoreProtocols | import Parser/Network/JSRenderer | Codable | Equatable/Hashable | Identifiable | 依赖 App/Persistence | 依赖 Features | 可迁移到 ReaderAppSupport | 风险等级 | 备注 |
|--------|--------|------------------|----------------|------------------------|-----------------------------|----------------------------------|---------|-------------------|--------------|---------------------|--------------|---------------------------|----------|------|
| BookshelfItem.swift | BookshelfItem | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | YES | LOW | 纯 Foundation |
| ChapterCacheEntry.swift | ChapterCacheEntry/ChapterCacheStatus | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | YES | LOW | 纯 Foundation |
| ReaderDisplaySettings.swift | ReaderDisplaySettings/ReaderBackgroundMode | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | YES | LOW | 纯 Foundation |
| ReadingProgress.swift | ReadingProgress | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | YES | LOW | 纯 Foundation |
| SourceIdentity.swift | SourceIdentity/SourceIdentityFactory | ✅ | ❌ | ❌ (需要添加) | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | PARTIAL | MEDIUM | SourceIdentityFactory 依赖 SearchResultItem |

### 4. Models 引用位置摘要

| Model | 引用文件数 | 主要引用位置 |
|-------|-----------|-------------|
| BookshelfItem | 4 | BookshelfStore, BookshelfViewModel, BookshelfView, BookshelfItemRowView |
| ChapterCacheEntry | 1 | ChapterCacheStore |
| ReaderDisplaySettings | 2 | ReaderSettingsStore, ReaderSettingsPanel |
| ReadingProgress | 1 | ReadingProgressStore |
| SourceIdentity | 0 (仅定义) | - |
| SourceIdentityFactory | 1 | 仅自身定义 (from(searchResult:)) |

### 5. ReaderAppSupport skeleton 审查结果

| 检查项 | 状态 |
|--------|------|
| ReaderAppSupport path | `iOS/AppSupport/Sources` |
| 当前 dependencies | `[]` (空) |
| 是否可承载 Models | YES |
| 需要新增 dependencies | YES (ReaderCoreModels) |
| ReaderApp 是否依赖 ReaderAppSupport | YES |
| ShellSmokeTests 是否依赖 ReaderAppSupport | YES |
| duplicate sources 风险 | NO |

### 6. SourceIdentity 专项结论

| 检查项 | 结论 |
|--------|------|
| SourceIdentity 是否纯 Foundation | YES |
| SourceIdentityFactory 是否依赖 SearchResultItem | YES |
| SearchResultItem 属于哪个 target | ReaderCoreModels (来自 Reader-Core 独立仓库) |
| ReaderAppSupport -> ReaderShellValidation 风险 | NO，SearchResultItem 属于 ReaderCoreModels |
| 推荐方案 | **SourceIdentity model 可迁移，SourceIdentityFactory 保留在 CoreBridge/ShellValidation 并重命名为 SourceIdentityResolver** |

具体建议：
- 迁移 `SourceIdentity` struct 到 ReaderAppSupport
- `SourceIdentityFactory` 保留在 CoreBridge（或 ShellValidation）并重命名为 `SourceIdentityResolver`
- `SourceIdentityResolver` 只依赖 ReaderCoreModels（SearchResultItem），不依赖 ReaderAppSupport
- 迁移后，CoreBridge/ShellValidation 可以 import ReaderAppSupport 获得 SourceIdentity 类型

### 7. 推荐迁移顺序

#### Step 2A：迁移纯 Foundation models
顺序：
1. `ReaderDisplaySettings.swift` - 最简单，无依赖
2. `ReadingProgress.swift` - 纯数据模型
3. `ChapterCacheEntry.swift` - 包含 enum，但仍纯 Foundation
4. `BookshelfItem.swift` - Identifiable，但仍纯 Foundation

#### Step 2B：SourceIdentity 拆分迁移
- 迁移 `SourceIdentity` struct 到 ReaderAppSupport
- `SourceIdentityFactory` 拆分：
  - 保留 `from(searchResult:)` 到 CoreBridge/ShellValidation，重命名为 `SourceIdentityResolver.from(searchResult:)`
  - 保留 `fallback(name:url:rawJSON:)` 也可随 SourceIdentity 迁移到 ReaderAppSupport（因为只依赖 Foundation）

#### Step 2C：更新 imports
需要更新的文件清单：
- `iOS/App/Persistence/ReaderSettingsStore.swift`
- `iOS/App/Persistence/ChapterCacheStore.swift`
- `iOS/App/Persistence/ReadingProgressStore.swift`
- `iOS/App/Persistence/BookshelfStore.swift`
- `iOS/Features/Reader/ReaderViewModel.swift`
- `iOS/Features/Reader/ReaderSettingsPanel.swift`
- `iOS/Features/Bookshelf/BookshelfViewModel.swift`
- `iOS/Features/Bookshelf/BookshelfView.swift`
- `iOS/Features/Bookshelf/BookshelfItemRowView.swift`

#### Step 2D：验证
- `swift build --target ReaderAppSupport`
- ShellSmokeTests
- boundary check
- CI

### 8. 风险清单

| # | 风险 | 严重程度 | 缓解措施 |
|---|------|----------|----------|
| R1 | SourceIdentityFactory 依赖 SearchResultItem | MEDIUM | 拆分 model 和 resolver |
| R2 | ReaderAppSupport 需要新增 ReaderCoreModels 依赖 | LOW | Package.swift 中添加即可 |
| R3 | import 修复范围较大 | MEDIUM | 分批更新，CI 验证 |
| R4 | CI GREEN 被破坏 | HIGH | 先在本地验证，再提交 |
| R5 | 回滚策略缺失 | MEDIUM | 使用 git 分支做迁移 |

### 9. Step 2 是否可以进入实施：YES

### 10. Step 2 实施前置条件
- [x] 当前 CI GREEN
- [x] Models 依赖矩阵已确认
- [x] SourceIdentity 拆分方案已确认
- [x] ReaderAppSupport skeleton 已就绪
- [ ] 确认迁移分支已创建

### 11. 回滚方案
- git reset --hard dc6a883
- git push -f origin main

---

## 附录：相关文件清单

### Models (5 files)

- `iOS/App/Models/BookshelfItem.swift`
- `iOS/App/Models/ChapterCacheEntry.swift`
- `iOS/App/Models/ReaderDisplaySettings.swift`
- `iOS/App/Models/ReadingProgress.swift`
- `iOS/App/Models/SourceIdentity.swift`

### Persistence (5 files)

- `iOS/App/Persistence/BookSourceStore.swift`
- `iOS/App/Persistence/BookshelfStore.swift`
- `iOS/App/Persistence/ChapterCacheStore.swift`
- `iOS/App/Persistence/ReaderSettingsStore.swift`
- `iOS/App/Persistence/ReadingProgressStore.swift`
