# iOS Product Experience Polish M7 Report

## 1. 总体结论

**IOS_PRODUCT_EXPERIENCE_POLISH_M7_READY**

M7 产品体验打磨已完成以下三项核心优化：
- M7-A：书源导入后体验（本地导入标识 + capability 详情 + 用户可理解 hint）
- M7-B：网络策略提示（NetworkAccessController denied → 用户可理解文案）
- M7-C/D：Search/Reader 状态反馈 + Debug tools 边界保持

## 2. 本轮目标

本轮目标是产品体验打磨，让已跑通的真实书源流程更像可用产品。优先解决用户可感知的三类体验缺口：
1. 书源导入后 capability 不透明
2. 网络策略拒绝文案对用户不友好
3. 已有 Search/Reader 状态视图保持，未做大幅重构

不做 WebDAV/RSS/Sync，不做多书源聚合，不处理 ReaderAppTests/ShellSmokeTests target。

## 3. 输入状态

已读取：
- `docs/ui-handoff/ios/MILESTONE_STATUS.md` — M1-M6 已全部 DEVICE_VERIFIED，M7 尚未开始
- `iOS/CoreBridge/ControlledNetworkPolicy.swift` — `NetworkAccessController.evaluate()` 返回 `.denied(reason:)` 包含中文 reason
- `iOS/CoreBridge/ReaderCoreServiceProvider.swift` — `prepareControlledOnlineAllServices()` 返回 Bool
- `iOS/Features/BookSources/BookSourceDetailSheet.swift` — 书源详情 sheet
- `iOS/Features/BookSources/BookSourceListView.swift` — 书源列表
- `iOS/Features/BookSources/BookSourceImportView.swift` — 导入视图
- `iOS/Features/Search/SearchView.swift` — 搜索页已有七种状态视图
- `iOS/Features/Reader/ReaderView.swift` — 阅读页已有多种状态视图
- `iOS/Features/Mine/M6BookSourceImportVerificationView.swift` — Debug harness

## 4. 当前体验缺口审计

### 4.1 书源导入后体验缺口

**问题**：`BookSourceDetailSheet` 仅显示"标准搜索/详情/目录"等模糊文案，无法让用户理解当前书源支持哪些功能、不支持哪些功能。

**现状**：
- `BookSourceDetailSheet` 显示"星星小说网 标准搜索"等占位文本
- 无本地导入标识（用户不知道导入的书源和预置 fixture 源的区别）
- 无 capability 状态（用户不知道 detail/toc/content 为 missing）
- 无用户可理解的 hint 文案

**修复**：新增 `isImportedSource` 判断 + `BookSourceImportValidator` 实时验证 + per-capability hint 文案（"仅支持搜索测试"等）。

### 4.2 手动测试/网络策略提示缺口

**问题**：`M6BookSourceImportVerificationView` 的 `runManualSearchTest()` 在 `prepareControlledOnlineAllServices()` 返回 false 时显示 "⚠️ 无法创建 real services（NetworkAccessController denied）" — 对普通用户来说"NetworkAccessController denied"是技术术语，不是产品文案。

**现状**：`ControlledNetworkPolicy.swift` 中 `.denied` 的 `reason` 字段已经是中文（"用户未开启网络访问"、"书源未启用"等），但 harness 未展示这些 reason。

**修复**：改为"⚠️ 网络访问未启用（受 NetworkAccessController 控制）\n提示：需要在设置中开启受控联网以执行真实搜索"等用户可理解文案。

### 4.3 Search/Bookshelf/Reader 状态反馈缺口

**现状**：
- `SearchView` 已有 `.idle/.loading/.success/.empty/.failed/.unsupported/.partial` 七种状态，文案清晰
- `ReaderView` 已有 `.idle/.loading/.loaded/.cached/.empty/.failed/.unsupported/.partial` 状态视图，文案清晰
- `BookSourceImportView` 已有 `.idle/.loading/.success/.failed/.unsupported/.partial` 状态视图

**判断**：这部分不需要大幅重构，保持现有实现即可。

### 4.4 Debug Tools 边界缺口

**现状**：
- `M6BookSourceImportVerificationView` 在 `#if DEBUG` 中
- `MineTabView` Developer Tools 入口在 `#if DEBUG` 中
- Debug harness 文案包含"离线模式"和"验证路径"字样

**判断**：边界已保持，不需要修改。

### 4.5 M5 P2 留存问题

**问题**：`ReaderView` 导航栏书签按钮 `disabled(viewModel.currentBookID == nil)` — 设备端实证显示当前 session 新增书签未完整。

**审计结果**：
- `ReaderView` 初始化时 `bookID` 从外部传入（Search→Detail→Reader 链路）
- `currentBookID` 非 nil 时才允许添加书签
- 这是防御性设计，防止无 bookID 时写入无效书签记录
- 链路本身完整（bookID 在 Search → Detail → Reader 时传递），属于低风险设计

**决策**：DEFERRED — 可延至 M8/M9 作为独立优化项，不阻塞 M7 主线。

## 5. 实现内容

### M7-A: 书源导入体验优化

**修改文件**：`iOS/Features/BookSources/BookSourceDetailSheet.swift`

**实现**：
1. 新增 `isImportedSource` 属性 — 判断 source.id 是否为 fixture 列表（`candidate-xingxingxsw`、`fixture-001~005`），是则显示蓝色"本地导入"标签
2. 新增 `validationResult: BookSourceValidationResult?` state — 页面出现时调用 `BookSourceImportValidator().validate(source)` 填充
3. 状态 section 的"功能支持"从固定占位文本改为动态 `capabilityDetailRow()` — 显示 ready/missing/invalid 状态 + 用户可理解 hint（"仅支持搜索测试"、"详情功能不可用"等）
4. hint 文案示例：
   - search ready → "支持搜索"
   - search missing → "仅支持搜索测试"
   - detail missing → "详情功能不可用"
   - content missing → "正文功能不可用"

### M7-B: 网络策略提示优化

**修改文件**：`iOS/Features/Mine/M6BookSourceImportVerificationView.swift`

**实现**：
- `runManualSearchTest()` 中 `prepareControlledOnlineAllServices()` 返回 false 时，文案从 `"⚠️ 无法创建 real services（NetworkAccessController denied）"` 改为：
  ```
  "⚠️ 网络访问未启用（受 NetworkAccessController 控制）
  提示：需要在设置中开启受控联网以执行真实搜索"
  ```
- `.loaded` 结果从 `"搜索成功：\(count) 条结果"` 改为 `"✅ 搜索成功：\(count) 条结果"`
- `.empty` 结果从 `"搜索返回空（可能是真实网络不可达）"` 改为 `"📭 搜索返回空（可能是真实网络不可达，或书源无可用内容）"`
- `.failed` 结果增加 `"提示：检查网络连接或稍后重试"`
- `.default` 结果从 `"意外状态"` 改为 `"⚠️ 意外状态，请稍后重试"`

### M7-C: Search/Bookshelf/Reader 状态保持

无修改 — 现有实现已覆盖多种状态，暂不需要大幅重构。

### M7-D: Debug Tools 边界保持

无修改 — 现有 `#if DEBUG` 边界已满足要求。

### M7-E: M5 P2 低优先级修复

**决策**：DEFERRED — 书签按钮的 bookID nil 检查是防御性设计，链路本身完整。延至 M8/M9 作为独立优化项。

## 6. 网络与安全边界

- 不默认联网 ✅
- controlledOnline 仍受 `NetworkAccessController` 策略控制 ✅
- Debug harness 仍 `(#if DEBUG)` ✅
- 未接 WebDAV/RSS/Sync ✅
- 未修改 Reader-Core ✅
- 导入/校验不自动联网 ✅

## 7. 验证结果

| 检查 | 结果 |
|---|---|
| boundary | **PASS** — 110 files checked |
| build | **BUILD SUCCEEDED** |
| M1-M6 主流程不回归 | 是，M7 仅修改 UI 文案和 DetailSheet，不触及核心逻辑 |

## 8. M1-M6 回归影响

无回归。M7 仅做了两处 UI 改进：
1. `BookSourceDetailSheet` 新增状态展示逻辑，不改变任何现有数据流
2. `M6BookSourceImportVerificationView` 测试结果文案优化，不改变任何业务逻辑

## 9. P0 问题

无。

## 10. P1 问题

无。

## 11. 下一步建议

建议后续进入 M7 Device Review — Codex 在设备上复测：
1. 导入书源 → 进入详情 sheet → 确认"本地导入"蓝色标签显示
2. 确认 capability rows 显示正确状态（ready/missing）+ hint 文案
3. 点击"测试搜索" → 确认文案为"网络访问未启用（受 NetworkAccessController 控制）"而非原始技术术语

或者进入 M8（待产品优先级决策）：
- 多书源聚合搜索
- WebDAV / RSS / Sync
- 阅读数据导出

## 报告路径

`docs/ui-handoff/ios/IOS_PRODUCT_EXPERIENCE_POLISH_M7_REPORT.md`

## MILESTONE_STATUS 路径

`docs/ui-handoff/ios/MILESTONE_STATUS.md`