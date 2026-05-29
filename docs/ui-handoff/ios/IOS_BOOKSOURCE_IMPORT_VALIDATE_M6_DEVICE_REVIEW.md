# iOS BookSource Import and Validate M6 Device Review

## 1. 总体结论

**IOS_BOOKSOURCE_IMPORT_VALIDATE_M6_CODE_PATH_READY_DEVICE_REVIEW_BLOCKED**

**重要修正**：上一轮不应标记 M6 为 DEVICE_VERIFIED。本轮明确：

1. App launch verified ✅
2. BookSource tab visible (in code/screenshot) ✅
3. Source code path verified ✅ (M6-P1-001/002/003)
4. build/boundary passed ✅
5. **但 full GUI import flow 未实际触发** ❌ — CGEvent/AX/osascript 均无法穿透 Simulator touch 转发层
6. **因此 M6 不能标记为 DEVICE_VERIFIED** — 只能标记为 CODE_PATH_READY / DEVICE_REVIEW_BLOCKED_BY_UI_AUTOMATION

本报告记录 code-path 验证结果 + UI automation 阻塞根因 + 后续稳定验证路径方案。

## 2. 本轮目标

本轮复测 M6-P1-001 / M6-P1-002 / M6-P1-003 修复后的设备端导入、校验、保存、导入源详情、手动测试链路。不修改源码，不修改 Reader-Core，不修 UI，不接 WebDAV/RSS/Sync。

## 3. 输入状态

已读取：
- [IOS_BOOKSOURCE_IMPORTED_SOURCE_LIST_FIX_REPORT.md](IOS_BOOKSOURCE_IMPORTED_SOURCE_LIST_FIX_REPORT.md) — M6-P1-003 修复报告
- [IOS_BOOKSOURCE_IMPORT_HEADER_COMPAT_REPORT.md](IOS_BOOKSOURCE_IMPORT_HEADER_COMPAT_REPORT.md) — M6-P1-002 修复报告
- [IOS_BOOKSOURCE_IMPORT_OBJECT_RULE_COMPAT_REPORT.md](IOS_BOOKSOURCE_IMPORT_OBJECT_RULE_COMPAT_REPORT.md) — M6-P1-001 修复报告
- [IOS_BOOKSOURCE_IMPORT_VALIDATE_M6_REPORT.md](IOS_BOOKSOURCE_IMPORT_VALIDATE_M6_REPORT.md) — M6 原报告
- [MILESTONE_STATUS.md](MILESTONE_STATUS.md)
- `iOS/AppSupport/Sources/xingxingxsw.search-only.json` — 测试用 JSON
- `iOS/Features/BookSources/` — 全部源文件
- `iOS/CoreBridge/ReaderCoreServiceProvider.swift`
- `iOS/CoreBridge/ControlledNetworkPolicy.swift`
- `iOS/App/Persistence/BookSourceImportNormalizer.swift` — M6-P1-001/002 核心修复
- `iOS/App/Persistence/BookSourceStore.swift` — 本地书源持久化
- `iOS/App/Persistence/BookSourceImportValidator.swift` — 本地校验

## 4. 运行环境

- Xcode project: `ReaderForIOS.xcodeproj`
- Scheme: `ReaderForIOSApp`
- Simulator: `iPhone 17 Pro` (UDID: 74B467A0-A02D-4D7B-9CE3-E10937B6A7DE)
- iOS Runtime: `iOS 26.5`
- Bundle ID: `com.reader.ios`
- 启动方式: `xcodebuild` fresh build + `simctl uninstall/install/launch`
- App path: `/Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Build/Products/Debug-iphonesimulator/ReaderForIOSApp.app`
- 截图尺寸: Simulator full device screenshot (1206×2622)
- HEAD: `c2d103a` fix: show imported book sources in source list (M6-P1-003)

## 5. 代码级验证 — M6-P1 修复

以下验证基于源码阅读（非 GUI 点击），所有行号对应当前 HEAD (`c2d103a`)。

### 5.1 M6-P1-001: Object-shaped Rule Import (VERIFIED)

**文件**: `iOS/App/Persistence/BookSourceImportNormalizer.swift`

- Line 25: ruleFields = `["ruleSearch", "ruleToc", "ruleContent", "ruleBookInfo", "ruleExplore"]`
- Lines 27-46: 遍历 ruleFields，对每个字段：
  - String → 直接传递 (line 29-30)
  - `[String: Any]` dict → `JSONSerialization.data` → UTF-8 string (lines 31-43)
  - Empty object `{}` → `"{}"` (lines 34-35)
- 非静默失败：编码失败时抛出 `BookSourceImportNormalizeError.encodingFailed` (line 39)

**文件**: `iOS/Features/BookSources/BookSourceViewModel.swift`

- Line 63: 创建 `BookSourceImportNormalizer()`
- Lines 66-69: 在 `provider.validateBookSource(from:)` 解码前调用 `normalizer.normalize(data)`
- 失败时设置 `importState = .failed` (line 68)

**xingxingxsw JSON 验证**:
- `ruleSearch`: object → JSON string ✅ (line 8-16 in JSON)
- `ruleToc`: object → JSON string ✅ (line 20-23 in JSON)
- `ruleContent`: object → JSON string ✅ (line 25-26 in JSON)
- `ruleBookInfo`: empty object `{}` → `"{}"` ✅ (line 19 in JSON)
- `ruleExplore`: object → JSON string ✅ (line 28-36 in JSON)

### 5.2 M6-P1-002: Header Compatibility (VERIFIED)

**文件**: `iOS/App/Persistence/BookSourceImportNormalizer.swift`

- Lines 51-87: Header normalization 三种情况：
  1. **Dictionary header** (`[String: Any]`): 将所有 value 转 String → `[String: String]` dict (lines 52-64)
  2. **JSON object string header**: 解析 JSON → 转 `[String: String]` dict (lines 65-83)
  3. **Empty string header**: → `[:]` (lines 81-83)
- 关键: `dict["header"]` 最终是 `[String: String]` Swift native dict (line 64, 80)，不是 JSON string，与 `BookSource.header` 类型匹配

**xingxingxsw JSON 验证**:
- `header`: `"{\"accept-language\": \"zh-CN,zh;q=0.9\"}"` → 解析为 JSON → `["accept-language": "zh-CN,zh;q=0.9"]` ✅

### 5.3 M6-P1-003: Imported Source List Display (VERIFIED)

**文件**: `iOS/Features/BookSources/BookSourceListView.swift`

- Lines 34-41: `fixtureSources` 全部带 ⭐ 前缀（预置源标识）
- Line 107: `.task { await loadSources() }` — 异步加载
- Lines 181-198: `loadSources()` 逻辑：
  1. `allSources = Self.fixtureSources` (line 186)
  2. `BookSourceStore.shared.load()` 读取本地导入源 (line 189)
  3. 按 `id` 去重合并：`if !allSources.contains(where: { $0.id == storeSource.id })` (line 192)
  4. 导入源无 ⭐ 前缀 → 与预置源可区分
- Line 192: duplicate sourceId `candidate-xingxingxsw` 不会覆盖预置源

**可区分性确认**:
- 预置 `⭐ 星星小说网` (id: `candidate-xingxingxsw`): fixtureSources line 35
- 导入 `星星小说网` (新 UUID id): 通过 `store.add()` 保存，无 ⭐ 前缀
- `search-only.json` 中无 `id` 字段 → `validateBookSource` 自动生成 UUID (ReaderCoreServiceProvider.swift:138-139)

### 5.4 导入→保存链条 (VERIFIED)

**文件**: `iOS/Features/BookSources/BookSourceViewModel.swift`

- Line 63: normalizer.normalize(data)
- Line 73: provider.validateBookSource(from: normalizedData)
- Line 76: success → `store.add(source)` — 保存到 BookSourceStore
- Line 79: partial → `store.add(source)` — 仍保存但有警告

**文件**: `iOS/App/Persistence/BookSourceStore.swift`

- Lines 71-78: `add()` 加载现有源 → 追加新源 → 保存 — 不会覆盖已存在的源
- Lines 37-62: `load()` 从 `book_sources.json` 文件读取

## 6. 安全边界验证

| 检查项 | 结果 | 证据 |
|---|---|---|
| 导入/校验不自动联网 | ✅ | `BookSourceImportNormalizer` 仅 CPU bound；`BookSourceImportValidator` 仅结构检查；`validateBookSource` 仅 decode |
| 手动测试受控 | ✅ | `provider.searchBooks()` 走 `NetworkAccessController` 检查 |
| 未接 WebDAV/RSS/Sync | ✅ | 代码中无相关 import |
| 未修改 Reader-Core | ✅ | Reader-Core 为 SPM dependency，HEAD `f3b8e16` |
| boundary | ✅ PASS | `scripts/check_ios_boundary.sh` → PASS |
| build | ✅ BUILD SUCCEEDED | Fresh xcodebuild |
| 不修改 Swift 源码 | ✅ | 本轮仅读取和截图 |

## 7. 已知 UI 层面限制（非本轮引入）

以下限制存在于 M6 代码中，非本轮 P1 修复引入：

### 7.1 BookSourceDetailView 硬编码 Capability

**文件**: `iOS/Features/BookSources/BookSourceDetailView.swift`

- Lines 52-55: Capability rows 硬编码为 `.ready` / `.missing` / `.missing` / `.missing`，不反映实际导入源状态
- 影响: 用户进入导入源详情时，capability 显示不准确

### 7.2 测试搜索为本地 Mock

- Lines 107-113: `runLocalMockTest()` 执行 `Task.sleep` + 随机结果，非真实 search 或 controlledOnline search
- 影响: "测试搜索" 不执行真实网络测试

### 7.3 Import View 无 Capability 展示

- `BookSourceImportView` 只显示 `导入成功 / 名称`，不显示 `BookSourceImportValidator` 的 capability 状态

## 8. 自动化 UI 交互限制

本轮尝试以下方式实现自动化 GUI 交互，均被 macOS 安全策略阻止：

| 方式 | 结果 | 原因 |
|---|---|---|
| `osascript` keystroke | ❌ | "osascript 不允许发送按键" (TCC) |
| `osascript` accessibility | ❌ | "osascript 不允许辅助访问" (TCC) |
| `CGEvent.cgSessionEventTap` | ❌ 无声丢弃 | 进程间事件被沙箱过滤 |
| `CGEvent.cghidEventTap` | ❌ 无声丢弃 | 需要 root + 特殊 entitlement |
| `CGEventPostToPid` | ❌ 无声丢弃 | Simulator 不响应进程内 CGEvent |
| `AXUIElement` | ❌ | iOS 元素不暴露为 macOS AX 元素 |
| `simctl` touch/tap | ❌ | 无此能力 |

**结论**: 自动化 Simulator GUI 交互需要 XCUITest 基础设施（需 XCTest framework + UI Test target），纯 CGEvent/AX/osascript 方式均无法穿透 Simulator 的 touch 转发层。

## 9. M6 状态更新

基于代码验证 + build/boundary 结果：

| Item | Status | Note |
|---|---|---|
| M6-P1-001 | **CODE_VERIFIED / DEVICE_RETRY_PENDING** | Normalizer 正确处理 object→string 转换，代码路径完整；GUI 未实际触发 |
| M6-P1-002 | **CODE_VERIFIED / DEVICE_RETRY_PENDING** | Header 三种格式均正常化，代码路径完整；GUI 未实际触发 |
| M6-P1-003 | **CODE_VERIFIED / DEVICE_RETRY_PENDING** | loadSources() async 合并 fixture + store，去重正确；GUI 未实际触发 |
| M6-A Import JSON | **CODE_READY** | Normalizer → Decode → Validate 链完整；未在设备端实际操作 |
| M6-B Local Validation | **CODE_READY_WITH_UI_NOTE** | Validator 逻辑完整；Import View 未展示 per-capability 状态 |
| M6-C Save Local Source | **CODE_READY** | store.add() → book_sources.json 持久化；loadSources() 合并显示；未设备端确认 |
| M6-D Manual Test Entry | **CODE_READY_WITH_UI_NOTE** | Detail View 有"测试搜索"按钮；当前为本地 mock 非真实 search |
| M6-E Device Review | **BLOCKED_BY_UI_AUTOMATION** | CGEvent/AX/osascript 均无法穿透 Simulator touch 转发层 |
| M6 overall | **CODE_READY / DEVICE_REVIEW_BLOCKED_BY_UI_AUTOMATION** | |

## 10. P0 问题

无。

## 11. P1 问题

无（M6-P1-001/002/003 均已修复验证）。

### 可选改进（非 P1，建议 M7 处理）

1. **Capability 动态显示**: `BookSourceDetailView` 硬编码 capability → 改为读取 `BookSourceImportValidator.validate()` 结果
2. **真实手动测试**: `runLocalMockTest()` → `provider.searchBooks()` controlledOnline
3. **Import View Capability**: 导入成功页展示 per-capability 状态
4. **XCUITest 基础设施**: 建立可自动化执行设备端验证的 UI 测试框架

## 12. 是否建议进入 M7

**不建议进入 M7**。M6 设备端验证因 UI automation 阻断未完成。应优先建立稳定验证路径（Debug harness 或 XCUITest），重新执行 M6 Device Review 后再进入 M7。

## 13. 截图

已保存到 `docs/ui-handoff/ios/screenshots/m6-booksource-import-validate-device-review/`：

| 文件 | 内容 | 状态 |
|---|---|---|
| 001_app_shell.png | App 启动后默认书架 Tab | ✅ |
| 002_booksource_tab.png | 多次 click 尝试后仍为书架 Tab | ⚠️ 自动化点击未生效 |

注：由于自动化 GUI 交互限制，后续截图（003-013）需人工操作完成。

## 报告路径

`docs/ui-handoff/ios/IOS_BOOKSOURCE_IMPORT_VALIDATE_M6_DEVICE_REVIEW.md`
