# ReaderAppSupport Target Extraction Plan

**Status**: MODELS_MIGRATED
**Created**: 2026-04-29
**Last Updated**: 2026-04-30

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

## Step 2A ReaderDisplaySettings Migration

### 1. SearchResultItem 归属复核结果
- SearchResultItem 属于 ReaderCoreModels（来自 ../Reader-Core/Core/Sources/ReaderCoreModels/ReadingFlowModels.swift）
- 不属于 ReaderShellValidation / iOS Features / CoreBridge
- SourceIdentityFactory 依赖 SearchResultItem，但 SearchResultItem 属于 ReaderCoreModels，不会导致 ReaderAppSupport 依赖 ReaderShellValidation

### 2. SourceIdentity 拆分决策
- SourceIdentity struct：可迁移到 ReaderAppSupport（纯 Foundation）
- SourceIdentityFactory / Resolver：暂留 CoreBridge 或 ShellValidation（依赖 SearchResultItem，属于 ReaderCoreModels）

### 3. ReaderDisplaySettings 迁移影响审查
- ReaderDisplaySettings 只依赖 Foundation：YES
- 引用文件：ReaderSettingsStore.swift, ReaderViewModel.swift, ReaderSettingsPanel.swift
- 迁移后需要 import ReaderAppSupport：3 个文件
- 不影响 ReaderAppSupport target 依赖（无需添加 ReaderCoreModels）
- duplicate source 风险：NO

### 4. ReaderDisplaySettings 是否已迁移：YES

### 5. 修改文件列表
- 移动：iOS/App/Models/ReaderDisplaySettings.swift → iOS/AppSupport/Sources/ReaderDisplaySettings.swift
- 修改：iOS/Package.swift
- 修改：iOS/App/Persistence/ReaderSettingsStore.swift
- 修改：iOS/Features/Reader/ReaderViewModel.swift
- 修改：iOS/Features/Reader/ReaderSettingsPanel.swift
- 修改：docs/PLANNING/READER_APP_SUPPORT_TARGET_PLAN.md

### 6. import 更新范围
- ReaderSettingsStore.swift
- ReaderViewModel.swift
- ReaderSettingsPanel.swift

### 7. 验证结果
- CI SUCCESS (run id: 25117760791)
- Boundary + Shell compile smoke: PASS

### 8. 下一步是否可迁移 ReadingProgress：YES

---

## Step 2B ReadingProgress Migration Planning

### 1. ReadingProgress 依赖审查
- import：Foundation 仅
- SwiftUI 依赖：NO
- ReaderCoreModels/ReaderCoreProtocols 依赖：NO
- ReaderCoreParser/ReaderCoreNetwork/ReaderCoreJSRenderer 依赖：NO
- Codable：YES
- Equatable：YES
- Hashable：NO（未声明）
- Identifiable：NO
- 迁移到 ReaderAppSupport 的 blocker：NO

### 2. 引用位置清单
- iOS/App/Persistence/ReadingProgressStore.swift（ReaderApp target）
- iOS/Features/Reader/ReaderViewModel.swift（ReaderApp target）

### 3. 需要更新 import 的文件清单
- iOS/App/Persistence/ReadingProgressStore.swift
- iOS/Features/Reader/ReaderViewModel.swift

### 4. Package.swift 预期修改
- ReaderAppSupport target sources 新增 "ReadingProgress.swift"

### 5. 风险评估
- Risk Level：LOW
- Risk Items：
  - 无 SwiftUI 依赖
  - 无 ReaderCoreParser/ReaderCoreNetwork 依赖
  - 无跨 target 循环依赖
  - ReaderDisplaySettings 迁移状态不受影响

### 6. 是否可以进入 ReadingProgress 实施：YES

### 7. 实施前置条件
- [x] ReaderDisplaySettings 迁移已通过 CI
- [x] ReadingProgress 依赖审查完成
- [x] 引用位置明确

### 8. 回滚方案
- git reset --hard 332d85e
- git push -f origin main

---

## Step 2B ReadingProgress Migration Result

### 1. ReadingProgress 已迁移：YES

### 2. 修改文件清单
- 移动：iOS/App/Models/ReadingProgress.swift → iOS/AppSupport/Sources/ReadingProgress.swift
- 修改：iOS/Package.swift
- 修改：iOS/App/Persistence/ReadingProgressStore.swift
- 修改：docs/PLANNING/READER_APP_SUPPORT_TARGET_PLAN.md

### 3. import 更新清单
- iOS/App/Persistence/ReadingProgressStore.swift（添加 import ReaderAppSupport）
- iOS/Features/Reader/ReaderViewModel.swift（已存在 import ReaderAppSupport）

### 4. Package.swift 更新摘要
- ReaderAppSupport target sources 新增 "ReadingProgress.swift"
- 不改变其他 target 配置

### 5. 是否迁移其他 Models：NO

### 6. 是否迁移 Persistence：NO

### 7. 是否新增测试：NO

### 8. CI 结果：SUCCESS
- commit: 9f4acbb
- run id: 25119142807
- Boundary + Shell compile smoke: PASS

### 9. 下一步是否可以规划 ChapterCacheEntry 迁移：YES

---

## Step 2C ChapterCacheEntry Migration Result

### 1. ChapterCacheEntry 已迁移：YES

### 2. 修改文件清单
- 移动：iOS/App/Models/ChapterCacheEntry.swift → iOS/AppSupport/Sources/ChapterCacheEntry.swift
- 修改：iOS/Package.swift
- 修改：iOS/App/Persistence/ChapterCacheStore.swift
- 修改：docs/PLANNING/READER_APP_SUPPORT_TARGET_PLAN.md

### 3. import 更新清单
- iOS/App/Persistence/ChapterCacheStore.swift（添加 import ReaderAppSupport）

### 4. Package.swift 更新摘要
- ReaderAppSupport target sources 新增 "ChapterCacheEntry.swift"
- 不改变其他 target 配置

### 5. 是否迁移其他 Models：NO

### 6. 是否迁移 Persistence：NO

### 7. 是否新增测试：NO

### 8. 本地 build / test 结果
- swift build --target ReaderAppSupport: PASS (4 files compiled)
- swift test: ReaderApp target 有预存 SourceIdentity 编译错误，与本次迁移无关
- Boundary check: PASS (checked_files=51)
- 当前 HEAD: 8254eef

### 9. 下一步是否可以规划 BookshelfItem 迁移：YES

---

## Step 2D BookshelfItem Migration Result

### 1. BookshelfItem 已迁移：YES

### 2. 修改文件清单
- 移动：iOS/App/Models/BookshelfItem.swift → iOS/AppSupport/Sources/BookshelfItem.swift
- 修改：iOS/Package.swift
- 修改：iOS/App/Persistence/BookshelfStore.swift
- 修改：iOS/Features/Bookshelf/BookshelfViewModel.swift
- 修改：iOS/Features/Bookshelf/BookshelfView.swift
- 修改：iOS/Features/Bookshelf/BookshelfItemRowView.swift
- 修改：iOS/Features/BookDetail/BookDetailView.swift
- 修改：docs/PLANNING/READER_APP_SUPPORT_TARGET_PLAN.md

### 3. import 更新清单
- iOS/App/Persistence/BookshelfStore.swift（添加 import ReaderAppSupport）
- iOS/Features/Bookshelf/BookshelfViewModel.swift（添加 import ReaderAppSupport）
- iOS/Features/Bookshelf/BookshelfView.swift（添加 import ReaderAppSupport）
- iOS/Features/Bookshelf/BookshelfItemRowView.swift（添加 import ReaderAppSupport）
- iOS/Features/BookDetail/BookDetailView.swift（添加 import ReaderAppSupport）

### 4. Package.swift 更新摘要
- ReaderAppSupport target sources 新增 "BookshelfItem.swift"
- 不改变其他 target 配置

### 5. 是否迁移其他 Models：NO

### 6. 是否迁移 Persistence：NO

### 7. 是否新增测试：NO

### 8. 本地 build / test 结果
- swift build --target ReaderAppSupport: PASS (5 files compiled, 0.49s)
- swift test: ReaderApp target 有预存 SourceIdentity 编译错误，与本次迁移无关
- Boundary check: PASS (checked_files=50)
- 当前 HEAD: 01169c1

### 9. 下一步是否可以规划 SourceIdentity 拆分/迁移：YES

---

## Step 2E SourceIdentity Split / Migration Planning

**Status**: PLANNING_ONLY
**Created**: 2026-04-30

### 1. 当前 SourceIdentity 文件结构

`iOS/App/Models/SourceIdentity.swift` (38 lines) 包含两个独立部分：

| 部分 | 行 | 内容 | 依赖 |
|------|-----|------|------|
| SourceIdentity struct | 3-15 | Codable, Equatable, Hashable model | Foundation only |
| SourceIdentityFactory enum | 17-38 | `from(searchResult:)` + `fallback(name:url:rawJSON:)` | SearchResultItem (ReaderCoreModels) |

### 2. SourceIdentity struct 依赖审查

| 检查项 | 结果 |
|--------|------|
| import Foundation | YES |
| import SwiftUI | NO |
| import ReaderCoreModels | NO |
| import ReaderCoreProtocols | NO |
| import ReaderCoreParser / Network / JSRenderer | NO |
| Codable | YES |
| Equatable | YES |
| Hashable | YES |
| 可独立迁移到 ReaderAppSupport | YES |
| 是否需要新增 ReaderAppSupport 依赖 | NO |

### 3. SourceIdentityFactory 依赖审查

| 方法 | 依赖 | 调用方 |
|------|------|--------|
| `from(searchResult: SearchResultItem)` | SearchResultItem (ReaderCoreModels) | BookDetailView.swift:12 |
| `fallback(name:url:rawJSON:)` | Foundation only | 无调用方（grep 未发现） |

### 4. SearchResultItem 归属确认

| 检查项 | 结果 |
|--------|------|
| 定义位置 | `Reader-Core/Core/Sources/ReaderCoreModels/ReadingFlowModels.swift:16` |
| 所属 module | **ReaderCoreModels** |
| ReaderAppSupport 是否应依赖 ReaderCoreModels | NO — ReaderAppSupport 设计为零外部依赖 |
| swift test 当前阻断 | `SourceIdentity.swift:18:43: cannot find type 'SearchResultItem' in scope` |
| 根因 | ReaderApp target 未直接依赖 ReaderCoreModels，SearchResultItem 不可见 |

### 5. SourceIdentity 引用位置摘要

| 文件 | Target | 引用的内容 |
|------|--------|-----------|
| SourceIdentity.swift | ReaderApp | 定义 struct + factory |
| ReaderViewModel.swift:97 | ReaderApp | 直接构造 `SourceIdentity(id:bookURL,name:nil,baseURL:nil)` |
| BookDetailView.swift:11-12 | ReaderApp | `SourceIdentityFactory.from(searchResult:)` → 返回 `SourceIdentity` |

### 6. 三种方案对比

#### 方案 A：整体迁移 SourceIdentity.swift 到 ReaderAppSupport

- 做法：mv 整个文件，ReaderAppSupport 新增 `ReaderCoreModels` 依赖
- 优点：单文件移动，改动量最小
- 风险：ReaderAppSupport 失去零外部依赖属性；为一个 factory 方法引入整个 ReaderCoreModels 耦合
- **推荐：NO**

#### 方案 B：拆分文件（推荐）

- 做法：
  1. `SourceIdentity` struct → `iOS/AppSupport/Sources/SourceIdentity.swift`（ReaderAppSupport target）
  2. `SourceIdentityFactory.from(searchResult:)` → `iOS/CoreBridge/SourceIdentityFactory.swift`（ReaderShellValidation target）
  3. `fallback()` 当前无调用方 → 可随 struct 迁移或移除
  4. ReaderShellValidation dependencies 新增 `"ReaderAppSupport"`（使 SourceIdentity 类型可见）
- 优点：
  - ReaderAppSupport 保持零外部依赖
  - 关注点分离：model vs factory
  - 修复 swift test 预存 `SearchResultItem` 不可见错误
  - CoreBridge 已有 ReaderCoreModels import，SearchResultItem 天然可见
- 风险：
  - Package.swift 需新增 ReaderShellValidation → ReaderAppSupport 依赖
  - BookDetailView 需确认 SourceIdentityFactory 在新位置可见
- DAG 检查：ReaderShellValidation → ReaderAppSupport → (none)；ReaderApp → ReaderShellValidation + ReaderAppSupport。无循环。
- **推荐：YES**

#### 方案 C：暂不迁移 SourceIdentity

- 做法：保持现状
- 优点：零风险，零改动
- 风险：swift test 持续 BLOCKED；App/Models 有残留；后续 Persistence tests 无法推进
- **推荐：NO**（仅作短期过渡）

### 7. 推荐方案：方案 B

#### 文件变更

```
移动/拆分：
  iOS/App/Models/SourceIdentity.swift  →  删除
  iOS/AppSupport/Sources/SourceIdentity.swift  ←  SourceIdentity struct
  iOS/CoreBridge/SourceIdentityFactory.swift   ←  SourceIdentityFactory enum (新增)

修改：
  iOS/Package.swift
    - ReaderAppSupport sources 新增 "SourceIdentity.swift"
    - ReaderShellValidation dependencies 新增 "ReaderAppSupport"
```

#### SourceIdentityFactory.swift 设计（CoreBridge）

```swift
import Foundation
import ReaderCoreModels
import ReaderAppSupport

public enum SourceIdentityFactory {
    public static func from(searchResult: SearchResultItem) -> SourceIdentity {
        return SourceIdentity(
            id: searchResult.detailURL,
            name: nil,
            baseURL: nil
        )
    }
}
```

`fallback()` 方法当前无调用方，不迁移（删除）。

### 8. 实施步骤草案

1. 创建 `iOS/CoreBridge/SourceIdentityFactory.swift`（仅 `from(searchResult:)`）
2. 移动 `SourceIdentity` struct 到 `iOS/AppSupport/Sources/SourceIdentity.swift`
3. 更新 `Package.swift`：
   - ReaderAppSupport sources 新增 `"SourceIdentity.swift"`
   - ReaderShellValidation dependencies 新增 `"ReaderAppSupport"`
4. 验证：`swift build --target ReaderAppSupport`
5. 验证：`swift build --target ReaderShellValidation`
6. 验证：`swift test`（预期 SourceIdentity 错误消失）
7. 边界检查
8. 提交

### 9. 风险清单

| # | 风险 | 严重程度 | 缓解措施 |
|---|------|----------|----------|
| R1 | ReaderShellValidation 新增 ReaderAppSupport 依赖引发循环 | LOW | 已验证 DAG 无循环 |
| R2 | Swift 6 NSLock 警告增加 | LOW | CoreBridge 已有类似代码模式 |
| R3 | BookDetailView 找不到 SourceIdentityFactory | LOW | BookDetailView 属于 ReaderApp target，ReaderApp 依赖 ReaderShellValidation |
| R4 | 删除 fallback 后未来需要 | LOW | 可从 git 历史恢复 |

### 10. 是否可以进入实施：YES

### 11. 回滚方案

- `git reset --hard 5870b3d`
- 重新创建 SourceIdentityFactory 如有需要

---

## Step 2E SourceIdentity Split Migration Result

### 1. SourceIdentity struct 已迁移：YES

### 2. SourceIdentityFactory 已拆出：YES
- 新位置：`iOS/CoreBridge/SourceIdentityFactory.swift`（ReaderShellValidation target）
- `fallback()` 方法移除（零调用方）

### 3. 修改文件清单
- 新增：`iOS/AppSupport/Sources/SourceIdentity.swift`
- 新增：`iOS/CoreBridge/SourceIdentityFactory.swift`
- 删除：`iOS/App/Models/SourceIdentity.swift`
- 修改：`iOS/Package.swift`
- 修改：`docs/PLANNING/READER_APP_SUPPORT_TARGET_PLAN.md`

### 4. import 更新清单
- 无需更新（ReaderViewModel.swift 和 BookDetailView.swift 已有 `import ReaderAppSupport`）

### 5. Package.swift 更新摘要
- ReaderAppSupport sources 新增 `"SourceIdentity.swift"`（现共 6 文件）
- ReaderShellValidation dependencies 新增 `"ReaderAppSupport"`

### 6. 是否迁移 Persistence：NO

### 7. 是否新增 Persistence tests：NO

### 8. 本地 build / test 结果
- `swift build --target ReaderAppSupport`: PASS (6 files, 0.51s)
- `swift build --target ReaderShellValidation`: PASS (0.65s)
- `swift test`: ReaderApp target 仍有预存错误（ReaderCoreServiceProvider scope, platform availability），与本次迁移无关
- **SourceIdentity `SearchResultItem` 错误已消除** ✅
- Boundary check: PASS (checked_files=49)
- App/Models 目录：空

### 9. Models 迁移阶段是否解除阻断：YES
- 所有 5 个 App/Models 已全部处理（4 迁移 + 1 拆分）
- ReaderAppSupport 不再有外部依赖

### 10. 下一步是否可以规划 Persistence migration / tests：YES

---

## 附录：相关文件清单

### Models (5 files) — ALL MIGRATED

- `iOS/AppSupport/Sources/BookshelfItem.swift` ✅ migrated
- `iOS/AppSupport/Sources/ChapterCacheEntry.swift` ✅ migrated
- `iOS/AppSupport/Sources/ReaderDisplaySettings.swift` ✅ migrated
- `iOS/AppSupport/Sources/ReadingProgress.swift` ✅ migrated
- `iOS/AppSupport/Sources/SourceIdentity.swift` ✅ migrated (struct)
- `iOS/CoreBridge/SourceIdentityFactory.swift` ✅ split (factory)

### Persistence (5 files)

- `iOS/App/Persistence/BookSourceStore.swift`
