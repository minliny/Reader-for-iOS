# M-IOS-1 Batch 1/2: Shell Architecture Design

> 状态：DESIGN COMPLETE
> 仓库：Reader-for-iOS
> 阶段：M-IOS-1 Batch 1/2 Architecture Design
> 日期：2026-04-16

---

## 1. 本次生成文件列表

| 文件路径 | 用途 |
|----------|------|
| `docs/M-IOS-1/SHELL_ARCHITECTURE_DESIGN.md` | 壳层架构设计主文档 |
| `docs/M-IOS-1/SHELL_ARCHITECTURE_AUDIT.md` | 当前结构审计结果 |
| `docs/M-IOS-1/TARGET_SHELL_STRUCTURE.md` | 目标壳层结构定义 |
| `docs/M-IOS-1/ACCEPTANCE_CRITERIA.md` | Batch 3 验收标准 |

---

## 2. 文件用途

- `SHELL_ARCHITECTURE_AUDIT.md`：Batch 1 审计输出，定义当前结构问题
- `SHELL_ARCHITECTURE_DESIGN.md`：Batch 2 设计输出，定义目标架构
- `TARGET_SHELL_STRUCTURE.md`：目标目录树与模块边界
- `ACCEPTANCE_CRITERIA.md`：Batch 3 实现完成时的验收口径

---

## 3. 风险点与验收方式

| 风险 | 缓解策略 |
|------|----------|
| 直接引用 Core internals 泄漏到 UI | 严格边界检查，ShellAssembly 作为唯一 Core 接入点 |
| 过度设计导航系统 | 只定义最小 NavigationStack 骨架 |
| 过早引入全局状态容器 | 只定义 ReadingFlowCoordinator 作为 app-level 状态 |
| 壳层与 feature 边界模糊 | 明确 Module Boundary 定义和禁止反向依赖规则 |

验收方式：
- `ios-shell-ci` 构建通过
- `swift build --package-path iOS --target ReaderShellValidation` 通过
- `swift test --package-path iOS --test-product ReaderAppPackageTests --filter ShellAssemblySmokeTests` 通过
- boundary audit `scripts/check_ios_boundary.sh` 无违规

---

## 4. Current Structure Inventory

### 4.1 目录结构

```
iOS/
├── App/
│   ├── AppEntry.swift          # 入口数据结构
│   └── ReaderApp.swift         # @main App entry
├── CoreIntegration/
│   ├── DefaultBookSourceDecoder.swift
│   ├── DefaultContentService.swift
│   ├── DefaultSearchService.swift
│   ├── DefaultTOCService.swift
│   ├── InMemoryBookSourceRepository.swift
│   └── ReadingFlowCoordinator.swift
├── Features/
│   ├── BookSourceImport/
│   │   └── BookSourceImportView.swift
│   ├── Common/
│   │   ├── ErrorView.swift
│   │   ├── LoadingView.swift
│   │   └── ReaderEmptyStateView.swift
│   ├── Content/
│   │   ├── ContentView.swift
│   │   └── ReaderContentSectionView.swift
│   ├── Reader/
│   │   ├── ReaderFlowFeatureView.swift
│   │   ├── ReaderProgressSurfaceView.swift
│   │   ├── ReaderSessionSummaryView.swift
│   │   ├── ReaderStageActionBar.swift
│   │   ├── ReaderStatusCardView.swift
│   │   └── View+HostCompatibility.swift
│   ├── Search/
│   │   └── SearchView.swift
│   └── TOC/
│       └── TOCView.swift
├── Modules/
│   ├── Bootstrap/
│   │   └── BootstrapModule.swift
│   └── Reader/
│       ├── ReaderFlowFeatureState.swift
│       ├── ReaderModuleBoundary.swift
│       └── ReaderUXFoundationState.swift
├── Shell/
│   ├── ReaderShellEnvironment.swift
│   └── ShellAssembly.swift
├── Tests/
│   ├── ReaderAppTests/
│   │   └── SmokeTests.swift
│   ├── ReaderUXFoundationTests/
│   │   ├── ReaderInteractionValidationTests.swift
│   │   ├── ReaderNavigationValidationTests.swift
│   │   ├── ReaderPresentationValidationTests.swift
│   │   ├── ReaderSessionValidationTests.swift
│   │   └── ReaderUXFoundationStateTests.swift
│   └── ShellSmokeTests/
│       ├── ReaderFlowFunctionalValidationTests.swift
│       ├── ReaderFlowHardeningTests.swift
│       └── ShellAssemblySmokeTests.swift
├── ValidationSupport/
│   └── ShellAssembly.swift
└── Package.swift
```

### 4.2 Package.swift Targets

| Target | Sources | Dependencies |
|--------|---------|--------------|
| ReaderShellValidation | CoreIntegration, ValidationSupport | ReaderCoreFoundation, ReaderCoreModels, ReaderCoreProtocols, ReaderCoreParser, ReaderCoreNetwork, ReaderPlatformAdapters |
| ReaderApp | App, Features, Shell, Modules | ReaderShellValidation + Core public products |
| ShellSmokeTests | Tests/ShellSmokeTests | ReaderShellValidation + Core public products |
| ReaderUXFoundationTests | Tests/ReaderUXFoundationTests | ReaderApp + Core public products |

---

## 5. Reusable Parts

| 目录/文件 | 可复用性 | 原因 |
|-----------|----------|------|
| `Shell/ShellAssembly.swift` | ✅ 可复用 | Composition Root 设计正确，边界清晰 |
| `Shell/ReaderShellEnvironment.swift` | ✅ 可复用 | 简单环境数据结构 |
| `CoreIntegration/ReadingFlowCoordinator.swift` | ✅ 可复用 | App-level 状态容器，protocol 依赖注入 |
| `CoreIntegration/Default*Service.swift` | ✅ 可复用 | Facade 层实现，正确依赖 CoreProtocols |
| `CoreIntegration/InMemoryBookSourceRepository.swift` | ✅ 可复用 | 简单 in-memory 实现 |
| `Features/Common/ErrorView.swift` | ✅ 可复用 | 统一错误展示组件 |
| `Features/Common/LoadingView.swift` | ✅ 可复用 | 统一加载状态组件 |
| `Features/Common/ReaderEmptyStateView.swift` | ✅ 可复用 | 统一空状态组件 |
| `Features/Reader/ReaderStatusCardView.swift` | ✅ 可复用 | 状态卡片展示 |
| `Features/Reader/ReaderFlowFeatureView.swift` | ✅ 可复用 | Root feature view |
| `Modules/Reader/ReaderModuleBoundary.swift` | ✅ 可复用 | Feature gate 边界定义 |

---

## 6. Debts / Invalid Structure

### 6.1 Boundary Debt

| 问题 | 位置 | 说明 |
|------|------|------|
| `ValidationSupport/ShellAssembly.swift` 与 `Shell/ShellAssembly.swift` 重复 | `iOS/ValidationSupport/ShellAssembly.swift` | 两个文件功能完全相同，造成冗余 |
| `ReaderFlowFeatureState.swift` 功能不明确 | `Modules/Reader/ReaderFlowFeatureState.swift` | 与 ReadingFlowCoordinator 职责重叠 |

### 6.2 Naming Debt

| 问题 | 说明 |
|------|------|
| `ReaderFlowFeatureState` 命名歧义 | 实际是 presentation model，不应叫 State |
| `ReaderUXFoundationState` 命名歧义 | 实际是 test fixture，不应叫 State |
| `BootstrapModule` 未被使用 | pre-split bootstrap 遗留，可删除或保留为 placeholder |

### 6.3 Composition Debt

| 问题 | 说明 |
|------|------|
| `Modules/Reader/ReaderUXFoundationState.swift` 未被任何 consumer 使用 | pre-split 测试遗留 |
| `Features/Reader/View+HostCompatibility.swift` 功能不明确 | host compatibility extension，边界需明确 |

### 6.4 Navigation Debt

| 问题 | 说明 |
|------|------|
| 无独立 App-level NavigationCoordinator | NavigationStack 内嵌在 ReaderFlowFeatureView 中 |
| 无 URL/deep-link 预留 | 未来扩展点，当前不实现但需预留 |

### 6.5 State Ownership Debt

| 问题 | 说明 |
|------|------|
| `ReadingFlowCoordinator` 同时持有 app-state 和 session-state | 长期应分离，短期可接受 |
| 无独立 AppState | 所有状态都在 Coordinator 中，适合 M-IOS-1 |

---

## 7. Missing Parts

| 缺失项 | 优先级 | 说明 |
|--------|--------|------|
| App-level Error Surface | 高 | 当前错误只在 feature 内部展示 |
| Root Shell placeholder | 高 | ReaderFlowFeatureView 是 root，需确保可独立运行 |
| Navigation route enum | 中 | 未来扩展用，当前 NavigationStack 已足够 |
| SceneDelegate/AppDelegate 接入 | 低 | SwiftUI App lifecycle 已足够 |

---

## 8. Target Shell Architecture

### 8.1 目标目录结构

```
iOS/
├── App/
│   ├── AppEntry.swift              # 保留：简单入口数据结构
│   └── ReaderApp.swift             # 保留：@main App entry，Composition Root 调用
├── Shell/
│   ├── CompositionRoot.swift       # 新增：明确 Composition Root 入口
│   ├── ReaderShellEnvironment.swift # 保留：环境配置
│   └── ShellAssembly.swift         # 保留：Core 接入点 Factory
├── CoreIntegration/                  # 保留：所有文件
│   ├── ReadingFlowCoordinator.swift
│   ├── DefaultBookSourceDecoder.swift
│   ├── DefaultContentService.swift
│   ├── DefaultSearchService.swift
│   ├── DefaultTOCService.swift
│   └── InMemoryBookSourceRepository.swift
├── Features/
│   ├── Common/                      # 保留：统一 surface 组件
│   │   ├── ErrorView.swift
│   │   ├── LoadingView.swift
│   │   └── ReaderEmptyStateView.swift
│   ├── BookSourceImport/           # 保留：书源导入 placeholder
│   │   └── BookSourceImportView.swift
│   ├── Search/                     # 保留：搜索 placeholder
│   │   └── SearchView.swift
│   ├── TOC/                       # 保留：目录 placeholder
│   │   └── TOCView.swift
│   ├── Content/                    # 保留：正文 placeholder
│   │   ├── ContentView.swift
│   │   └── ReaderContentSectionView.swift
│   └── Reader/                     # 保留：root feature
│       ├── ReaderFlowFeatureView.swift
│       ├── ReaderStatusCardView.swift
│       └── ReaderSessionSummaryView.swift
├── Modules/
│   ├── Bootstrap/                  # 删除：pre-split 遗留
│   │   └── BootstrapModule.swift
│   └── Reader/                     # 简化：保留 boundary，删除冗余
│       └── ReaderModuleBoundary.swift
├── Navigation/                     # 新增：导航骨架
│   ├── AppNavigationState.swift
│   └── Route.swift
├── State/                         # 新增：app-level 状态
│   └── AppState.swift
├── Surface/                       # 新增：统一 surface
│   ├── AppErrorSurface.swift
│   ├── AppLoadingSurface.swift
│   └── AppEmptySurface.swift
├── Tests/
│   └── (保留所有测试文件)
├── ValidationSupport/              # 删除：与 ShellAssembly 重复
│   └── ShellAssembly.swift
└── Package.swift
```

---

## 9. Composition Root / DI Design

### 9.1 Composition Root 位置

```
iOS/App/ReaderApp.swift  ← Composition Root 调用点
```

### 9.2 DI 层次

```yaml
Layer_0_Root:
  - iOS/App/ReaderApp.swift
  - iOS/Shell/CompositionRoot.swift  # 新增

Layer_1_Shell:
  - iOS/Shell/ShellAssembly.swift
  - iOS/Shell/ReaderShellEnvironment.swift

Layer_2_CoreIntegration:
  - iOS/CoreIntegration/ReadingFlowCoordinator.swift
  - iOS/CoreIntegration/Default*Service.swift
  - iOS/CoreIntegration/InMemoryBookSourceRepository.swift

Layer_3_Features:
  - iOS/Features/**/[*View.swift]
  - iOS/Features/**/[*SectionView.swift]
```

### 9.3 Core 接入规则

| 规则 | 说明 |
|------|------|
| ShellAssembly 是唯一 Core 接入点 | 只有 ShellAssembly 可 import ReaderCoreNetwork, ReaderCoreParser |
| Features 只通过协议接触 Core | Features 只能 import ReaderCoreProtocols + ReaderCoreModels |
| UI 层最多接触 facade | UI 只通过 ReadingFlowCoordinator (facade) 接触 service 层 |

---

## 10. Navigation / Route Skeleton

### 10.1 Root Navigation Structure

```swift
NavigationStack {
    ReaderFlowFeatureView  // Root screen
        ├── BookSourceImportView
        ├── SearchView
        │   └── TOCView
        │       └── ContentView
        └── ContentView
```

### 10.2 Route Definition

```swift
public enum Route: Hashable {
    case home                          // ReaderFlowFeatureView
    case bookSourceImport
    case search
    case toc(book: SearchResultItem)
    case content(chapter: TOCItem)
}
```

### 10.3 Navigation State

```swift
@MainActor
public final class AppNavigationState: ObservableObject {
    @Published public var currentRoute: Route = .home
    @Published public var navigationPath: [Route] = []

    public func navigate(to route: Route) { ... }
    public func goBack() { ... }
    public func popToRoot() { ... }
}
```

---

## 11. Module Boundary Design

### 11.1 模块边界

| 模块 | 职责 | 可导入 |
|------|------|--------|
| `App` | @main entry | 无限制 |
| `Shell` | Composition Root, Environment | ReaderCoreProtocols, ReaderCoreModels, CoreIntegration |
| `CoreIntegration` | Service implementations | ReaderCoreProtocols, ReaderCoreModels, ReaderCoreNetwork, ReaderCoreParser |
| `Features.Common` | Shared UI components | ReaderCoreModels, ReaderShellValidation |
| `Features.[*]` | Feature placeholder views | ReaderCoreModels, ReaderShellValidation |
| `Navigation` | Navigation state, routes | ReaderCoreModels |
| `State` | App-level state | 视情况 |
| `Surface` | Error/Loading/Empty surfaces | ReaderCoreModels |

### 11.2 禁止的反向依赖

- Features → CoreIntegration（禁止直接依赖）
- Features → Shell（禁止直接依赖）
- UI → ReaderCoreNetwork（禁止）
- UI → ReaderCoreParser（禁止）

---

## 12. Global State / Session Boundary

### 12.1 State Ownership

| 状态 | Owner | Scope |
|------|-------|-------|
| selectedSource | ReadingFlowCoordinator | App-level |
| searchResults | ReadingFlowCoordinator | App-level |
| selectedBook | ReadingFlowCoordinator | App-level |
| tocItems | ReadingFlowCoordinator | App-level |
| selectedChapter | ReadingFlowCoordinator | App-level |
| contentPage | ReadingFlowCoordinator | App-level |
| isLoading | ReadingFlowCoordinator | App-level |
| currentError | ReadingFlowCoordinator | App-level |
| navigationPath | AppNavigationState | App-level |

### 12.2 M-IOS-1 State 策略

- **ReadingFlowCoordinator 作为唯一 App-level 状态容器**（简化设计）
- 不引入独立 AppState struct（避免过度设计）
- 不引入 Redux-like 全局 store（避免复杂度）
- Feature 状态通过 @ObservedObject 从 Coordinator 读取

---

## 13. Error / Loading / Empty Surface Design

### 13.1 Surface 层次

```swift
Layer_1_AppWide:
  - AppErrorSurface    // 顶层错误捕获
  - AppLoadingSurface  // 顶层加载状态
  - AppEmptySurface    // 顶层空状态

Layer_2_FeatureLocal:
  - ErrorView          // Feature 内部错误
  - LoadingView        // Feature 内部加载
  - ReaderEmptyStateView // Feature 内部空状态
```

### 13.2 AppErrorSurface

```swift
public struct AppErrorSurface: View {
    let error: ReaderError?
    let retryAction: (() -> Void)?

    public var body: some View {
        if let error = error {
            ErrorView(error: error, retryAction: retryAction)
        }
    }
}
```

### 13.3 错误传播规则

- ReadingFlowCoordinator.currentError 是 app-wide 错误
- Feature 可选择展示或忽略 coordinator 错误
- AppErrorSurface 在 root view 层级统一承接

---

## 14. Reader-Core Integration Facade Design

### 14.1 Facade 位置

```
Shell/ShellAssembly.swift  ← 唯一 Core 接入点
```

### 14.2 接入的 Core Public Products

| Product | 用途 |
|---------|------|
| ReaderCoreFoundation | 基础类型 |
| ReaderCoreModels | BookSource, SearchResultItem, TOCItem, ContentPage, ReaderError |
| ReaderCoreProtocols | SearchService, TOCService, ContentService, BookSourceRepository, BookSourceDecoder, ErrorLogger |
| ReaderCoreParser | NonJSParserEngine, NonJSRuleScheduler |
| ReaderCoreNetwork | URLSessionHTTPClient, BasicCookieJar, BookSourceRequestBuilder |
| ReaderPlatformAdapters | 平台适配器 |

### 14.3 Smoke Path

```
ReaderApp.init()
  → ShellAssembly.makeDefaultReadingFlowCoordinator()
    → DefaultSearchService (URLSessionHTTPClient + NonJSParserEngine)
      → searchService.search(source:, query:)
        → [SearchResultItem]
```

### 14.4 M-IOS-1 接入范围

| Core Capability | M-IOS-1 Status |
|-----------------|-----------------|
| BookSource import | ✅ 接入 |
| Search | ✅ 接入 |
| TOC | ✅ 接入 |
| Content | ✅ 接入 |
| JS Rendering | ❌ 不接入（ReaderCoreJSRenderer 暂不接） |
| Login | ❌ 不接入（future） |
| Cache | ❌ 不接入（future） |

---

## 15. Acceptance Criteria

### 15.1 Build Criteria

| 条件 | 验证方式 |
|------|----------|
| `swift build --package-path iOS` 通过 | CI |
| `swift build --package-path iOS --target ReaderShellValidation` 通过 | CI |
| `xcodebuild -scheme ReaderApp` 通过 | 本地验证 |

### 15.2 Shell Startup Criteria

| 条件 | 验证方式 |
|------|----------|
| ReaderApp 可启动 | 手动验证 |
| Root shell (ReaderFlowFeatureView) 可见 | 手动验证 |
| NavigationStack 可导航 | 手动验证 |

### 15.3 Smoke Path Criteria

| 条件 | 验证方式 |
|------|----------|
| 书源导入路径可走通 | 手动验证 |
| 搜索路径可走通（mock） | ShellSmokeTests |
| TOC 路径可走通（mock） | ShellSmokeTests |
| Content 路径可走通（mock） | ShellSmokeTests |

### 15.4 Boundary Criteria

| 条件 | 验证方式 |
|------|----------|
| `scripts/check_ios_boundary.sh` 无违规 | CI |
| 无 Core internals 泄漏到 Features | Boundary audit |

### 15.5 Surface Criteria

| 条件 | 验证方式 |
|------|----------|
| ErrorSurface 可展示错误 | 手动验证 |
| LoadingSurface 可展示加载 | 手动验证 |
| EmptySurface 可展示空状态 | 手动验证 |

---

## 16. Batch 3 实现入口文件列表

### 16.1 新增文件

| 文件路径 | 用途 |
|----------|------|
| `iOS/Navigation/Route.swift` | 路由枚举定义 |
| `iOS/Navigation/AppNavigationState.swift` | 导航状态管理 |
| `iOS/State/AppState.swift` | App-level 状态封装（可选） |
| `iOS/Surface/AppErrorSurface.swift` | 顶层错误 surface |
| `iOS/Surface/AppLoadingSurface.swift` | 顶层加载 surface |
| `iOS/Surface/AppEmptySurface.swift` | 顶层空状态 surface |
| `iOS/Shell/CompositionRoot.swift` | 显式 Composition Root |

### 16.2 修改文件

| 文件路径 | 修改内容 |
|----------|----------|
| `iOS/App/ReaderApp.swift` | 接入 CompositionRoot |
| `iOS/Package.swift` | 添加新 target 或 source 路径 |
| `iOS/Features/Reader/ReaderFlowFeatureView.swift` | 接入 NavigationState |

### 16.3 删除文件

| 文件路径 | 删除原因 |
|----------|----------|
| `iOS/ValidationSupport/ShellAssembly.swift` | 与 Shell/ShellAssembly.swift 重复 |
| `iOS/Modules/Reader/ReaderFlowFeatureState.swift` | 与 ReadingFlowCoordinator 职责重叠 |
| `iOS/Modules/Reader/ReaderUXFoundationState.swift` | 未被使用的 test fixture |
| `iOS/Modules/Bootstrap/BootstrapModule.swift` | pre-split 遗留 |
| `iOS/Features/Reader/View+HostCompatibility.swift` | 功能不明确 |

### 16.4 保留文件（不变）

| 目录/文件 | 保留原因 |
|-----------|----------|
| `Shell/ShellAssembly.swift` | Composition Root |
| `Shell/ReaderShellEnvironment.swift` | Environment |
| `CoreIntegration/*` | Service 层 |
| `Features/Common/*` | Shared UI |
| `Features/BookSourceImport/*` | Feature placeholder |
| `Features/Search/*` | Feature placeholder |
| `Features/TOC/*` | Feature placeholder |
| `Features/Content/*` | Feature placeholder |
| `Features/Reader/ReaderFlowFeatureView.swift` | Root view |
| `Features/Reader/ReaderStatusCardView.swift` | Status card |
| `Features/Reader/ReaderSessionSummaryView.swift` | Session summary |
| `Modules/Reader/ReaderModuleBoundary.swift` | Feature gate |

---

## 17. Batch 3 不该做什么列表

| 禁止项 | 原因 |
|--------|------|
| 实现完整路由系统 | M-IOS-1 只需 NavigationStack |
| 实现独立 AppState | Coordinator 已足够 |
| 实现复杂状态管理 | 避免过度设计 |
| 实现 Login 功能 | future feature |
| 实现 Cache 功能 | future feature |
| 实现 JS Rendering | future feature |
| 实现高保真 UI | M-IOS-1 只做骨架 |
| 修改 Reader-Core | 本阶段禁止 |
| 实现完整错误处理链 | 只做最小 surface |

---

## 18. PR / Phase Summary

```yaml
phase: M-IOS-1 Batch 1/2 Architecture Design
scope: design/docs only
touches_reader_core: no
enters_implementation: not yet
batch_3_ready: yes

risk:
  - 壳层架构与 Core 边界已明确定义
  - 无过度设计问题
  - 目标结构清晰

blocking_items: []
```

---

## 19. Clean-Room 声明

本架构设计：
- 不复制任何外部 iOS App / GPL UI / Legado Android UI 实现
- 所有壳层架构与集成方式基于 SwiftUI + SwiftPM 标准模式独立设计
- Navigation 使用 SwiftUI NavigationStack 原生组件
- 状态管理使用 SwiftUI @ObservedObject + @Published 原生模式
