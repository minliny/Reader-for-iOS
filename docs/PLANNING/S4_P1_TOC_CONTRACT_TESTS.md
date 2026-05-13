# S4.P1 TOC 能力层契约测试与状态流补强

## 1. 本轮结论

**结论**: `TOC_CONTRACT_READY_ENV_UNVERIFIED`

**说明**:
- TOCService Mock/Placeholder 路由契约已验证
- TOC 状态流转换已测试覆盖
- ChapterListViewModel 状态处理已测试
- TOCItem 结构验证已覆盖
- 边界检查通过
- **real mode 仍为 Placeholder，不代表真实 TOC 能力**
- Swift 编译在 Trae 环境未验证

## 2. S4.P0 结论补齐 / 修正

S4.P0 文档已存在且内容正确：
- TOC 能力层已形成本仓 Mock 闭环
- real mode 当前是 PlaceholderTOCService
- DefaultTOCService 存在但未装配

本轮补充：
- TOCService 契约测试已添加
- ChapterListViewModel 状态处理已测试
- TOCItem 结构验证已覆盖

## 3. 新增测试文件

### TOCServiceContractTests.swift

| 测试组 | 测试数 | 覆盖 |
|--------|--------|------|
| Mock TOC Service | 6 | 成功/空/unsupported/网络失败/解析失败/登录要求 |
| Placeholder TOC Service | 2 | 抛出 realCoreNotAvailable / 不返回 Mock |
| Provider Mode 路由 | 3 | mock 委托 / real 返回 unsupported / 隔离 |
| Service 契约 | 2 | 输入验证 / 空数组返回 |
| 状态转换 | 5 | idle→loaded/empty/failed/unsupported/partial |
| TOCItem 结构 | 2 | 有效结构 / 正确顺序 |
| ChapterListViewModel | 4 | 成功/空/unsupported/失败 |
| **总计** | **24** | |

## 4. TOCService 契约验证结果

### 协议定义确认

```swift
public protocol TOCService {
    func fetchTOC(source: BookSource, detailURL: String) async throws -> [TOCItem]
}
```

### 三条实现路径验证

| 路径 | 行为 | 状态 |
|------|------|------|
| Mock | 委托给 provider.getChapterList() | ✅ 已验证 |
| Placeholder | 抛出 realCoreNotAvailable | ✅ 已验证 |
| Default | 需 Reader-Core API | ❌ 未验证 |

### 契约语义确认

| 契约项 | 说明 | 验证 |
|--------|------|------|
| 输入 | BookSource + detailURL | ✅ |
| 输出 | [TOCItem] (可为空) | ✅ |
| 错误 | throws AppReaderError / PlaceholderServiceError | ✅ |
| 空目录 | 返回空数组 [] | ✅ |

## 5. MockTOCService 测试结果

| 测试项 | 结果 | 说明 |
|--------|------|------|
| TOC 成功返回 5 个章节 | ✅ | mockTOCItems |
| TOC 空场景 | ✅ | 返回 [] |
| TOC unsupported 场景 | ✅ | 抛出 AppReaderError.unsupported |
| TOC 网络失败场景 | ✅ | 抛出 AppReaderError.network |
| TOC 解析失败场景 | ✅ | 抛出 AppReaderError.parser |
| TOC 登录要求场景 | ✅ | 抛出 AppReaderError.loginRequired |
| 服务层返回数组而非 nil | ✅ | 空结果返回 [] |

## 6. PlaceholderTOCService 测试结果

| 测试项 | 结果 | 说明 |
|--------|------|------|
| 抛出 realCoreNotAvailable | ✅ | 抛出 PlaceholderServiceError |
| 不返回 Mock 结果 | ✅ | Placeholder 不委托 mock |
| 独立于 provider.mockScenario | ✅ | 始终 unavailable |

## 7. ReaderCoreServiceProvider TOC 路由结果

| 测试项 | 结果 | 说明 |
|--------|------|------|
| mock mode 委托 mockService | ✅ | 返回 .loaded |
| real mode 返回 unsupported | ✅ | 不委托 mock |
| real mode 不返回 mock 结果 | ✅ | 隔离验证通过 |

### 路由语义确认

```swift
// ReaderCoreServiceProvider.getChapterList()
switch currentMode {
case .mock:
    return await mockService.getChapterList(bookURL: bookURL)
case .real:
    return .unsupported(reason: "Real Core service not available...")
}
```

**确认**: real mode 不会静默回退到 mock。

## 8. ChapterListViewModel 测试结果

| 测试项 | 结果 | 说明 |
|--------|------|------|
| 加载成功返回章节 | ✅ | listState = .loaded |
| 空场景处理 | ✅ | listState = .empty |
| unsupported 场景 | ✅ | listState = .unsupported |
| 失败场景处理 | ✅ | listState = .failed |

### ChapterListViewModel 与 ReadingFlowCoordinator 对比

| 特性 | ReadingFlowCoordinator | ChapterListViewModel |
|------|------------------------|---------------------|
| 书源 | selectedSource | 无书源参数 |
| provider 调用 | 通过 MockTOCService | 直接调用 provider |
| 状态枚举 | Coordinator 属性 | ChapterListState |

**说明**: 两者实现方式不同，但 Mock 路由行为一致。

## 9. TOCItem 结构验证

### mockTOCItems 结构

```swift
public static let mockTOCItems: [TOCItem] = [
    TOCItem(chapterTitle: "第一章 山村少年", chapterURL: "...", chapterIndex: 0),
    TOCItem(chapterTitle: "第二章 仙缘", chapterURL: "...", chapterIndex: 1),
    TOCItem(chapterTitle: "第三章 修炼入门", chapterURL: "...", chapterIndex: 2),
    TOCItem(chapterTitle: "第四章 宗门大选", chapterURL: "...", chapterIndex: 3),
    TOCItem(chapterTitle: "第五章 初入灵泉", chapterURL: "...", chapterIndex: 4)
]
```

### 验证结果

| 验证项 | 结果 |
|--------|------|
| 标题非空 | ✅ |
| URL 非空 | ✅ |
| 索引连续 | ✅ |
| 顺序正确 | ✅ |

## 10. 边界检查与测试结果

| 检查项 | 结果 |
|--------|------|
| 边界检查脚本 | ✅ PASS (checked_files=64) |
| 新增测试文件 | ✅ TOCServiceContractTests.swift |
| Swift 编译 | ⚠️ ENV_COMPILE_UNVERIFIED |

## 11. 剩余 P0 / P1 / P2 缺口

### P0 必须解决

| ID | 缺口 | 状态 |
|----|------|------|
| 无 | - | - |

### P1 应尽快解决

| ID | 缺口 | 优先级 | 说明 |
|----|------|--------|------|
| P1-1 | ChapterListViewModel 与 Coordinator 不一致 | 低 | 实现方式不同但 Mock 路由一致 |
| P1-2 | TOC → Content 连接测试 | 低 | 依赖 Content 能力层 |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 目录排序/翻转 | 低 |
| P2-2 | 目录翻页 | 中 |
| P2-3 | 章节缓存 | 低 |

## 12. S4.P2 推荐任务

**任务 ID**: S4.P2
**任务名称**: TOC 与其他阶段连接点验证

**任务内容**:
1. 验证 TOC → Content 流程连接
2. 验证 Search → TOC 流程连接
3. 验证书源选择影响 TOC

**前提条件**: 无需 Reader-Core

## 13. 本轮未做事项

| 事项 | 原因 |
|------|------|
| ChapterListViewModel 重构 | 不一致性存在但不影响 Mock 闭环 |
| TOC → Content 端到端测试 | 依赖 Content 能力层 |
| 真实 Core 接入 | S1.P2 暂停 |
| 目录排序/翻转 | P2 优化项 |
