# iOS M6 Device Review Automation Readiness Report

## 1. 总体结论

**IOS_M6_DEVICE_REVIEW_AUTOMATION_READY**

M6 书源导入链路现在具备稳定的 Debug-only 一键验证路径。Codex 或人工测试者只需：启动 App → 我的 Tab → [验证] M6 书源导入链路 → 点击"执行 M6 导入链路验证"，即可在设备上完成全部 M6 导入链路的自动化验证。

## 2. 为什么上一轮 DEVICE_VERIFIED 不可接受

上一轮报告 (`IOS_BOOKSOURCE_IMPORT_VALIDATE_M6_DEVICE_REVIEW.md`) 错误地将 M6 标记为 DEVICE_VERIFIED，原因如下：

1. **App launch verified** ✅ — 但这只是启动，不等于导入链路验证
2. **BookSource tab visible** ✅ — 截图确认了 tab 存在
3. **Source code path verified** ✅ — 代码阅读确认了修复逻辑
4. **build/boundary passed** ✅
5. **但 full GUI import flow 未实际触发** ❌：
   - 未粘贴 JSON 到输入框
   - 未点击"从文本导入"
   - 未验证 "Invalid book source JSON" 不出现
   - 未验证本地校验结果
   - 未验证 capability 展示
   - 未验证保存到书源列表
   - 未验证 imported source 可区分显示
   - 未验证导入源详情
   - 未验证手动测试

**根因**：CGEvent/AXUIElement/osascript 均无法穿透 iOS Simulator 的 touch 转发层。CGEvent 事件被无声丢弃，AX 只能看到 Simulator Chrome 而非 iOS App 内部元素。

**结论**：code review ≠ device verified。M6 必须降级到 CODE_READY + DEVICE_REVIEW_BLOCKED_BY_UI_AUTOMATION。

## 3. 已修正的 M6 状态

修正后的 MILESTONE_STATUS.md：

| Workstream | Status | Note |
|---|---|---|
| M6-P1-001 | CODE_VERIFIED / DEVICE_RETRY_PENDING | Object→string rule normalization |
| M6-P1-002 | CODE_VERIFIED / DEVICE_RETRY_PENDING | Header normalization |
| M6-P1-003 | CODE_VERIFIED / DEVICE_RETRY_PENDING | Imported source list merge |
| M6-A Import JSON | CODE_READY | Normalizer → Decode → Validate 链完整 |
| M6-B Local Validation | CODE_READY_WITH_UI_NOTE | Validator 逻辑完整 |
| M6-C Save Local Source | CODE_READY | store.add() + loadSources() merge |
| M6-D Manual Test Entry | CODE_READY_WITH_UI_NOTE | Detail View 有按钮；当前为本地 mock |
| M6-E Device Review | **BLOCKED_BY_UI_AUTOMATION** | CGEvent/AX/osascript 无法穿透 Simulator |
| M6 overall | **CODE_READY / DEVICE_REVIEW_BLOCKED_BY_UI_AUTOMATION** | |

## 4. 选择的验证方案

**方案 B：Debug-only verification view（已实现）**

原因：
- XCUITest 方案需要新增 UI test target（修改 project.yml，增加 scheme，创建 XCTest bundle），成本过高且有引入编译问题的风险
- Debug verification view 使用真实 import/store/viewmodel 代码路径，不绕过任何产品逻辑
- `#if DEBUG` 保证 Release 不可见
- 一键执行全部步骤，稳定可重现

## 5. 新增/修改文件

### 新增

**`iOS/Features/Mine/M6BookSourceImportVerificationView.swift`**

Debug-only 验证视图，覆盖：

| Step | 验证内容 | M6 关联 |
|---|---|---|
| 1 | 加载 xingxingxsw JSON | M6-A Import JSON |
| 2 | Normalize (object rules + header) | **M6-P1-001, M6-P1-002** |
| 3 | Decode BookSource | M6-A |
| 3a-3c | sourceName, bookSourceUrl, 不出现 Invalid JSON | M6-A |
| 4a-4d | search/detail/toc/content capability | M6-B Local Validation |
| 4e | validation errors | M6-B |
| 5 | Save to BookSourceStore | M6-C Save |
| 6 | Reload from store | M6-C |
| 7a-7b | 预置源 ⭐ 前缀 + 导入源可区分 | **M6-P1-003** |
| 8 | Duplicate sourceId 去重 | **M6-P1-003** |
| 9 | 启用/停用 toggle | M6-C |
| Manual | 测试搜索 (controlledOnline, 手动触发) | M6-D |

安全边界：
- 导入/校验不自动联网 ✅
- 手动搜索测试独立按钮，不自动触发 ✅
- 不接 WebDAV/RSS/Sync ✅
- 不修改 Reader-Core ✅
- 仅 #if DEBUG ✅
- 走真实 BookSourceImportNormalizer → BookSourceImportValidator → BookSourceStore 路径 ✅

### 修改

**`iOS/Features/Mine/MineTabView.swift`**

在 `#if DEBUG` 的 Developer Tools section 新增：

```swift
NavigationLink(destination: M6BookSourceImportVerificationView()) {
    Label("[验证] M6 书源导入链路", systemImage: "arrow.triangle.branch")
}
```

### 文档修改

**`docs/ui-handoff/ios/IOS_BOOKSOURCE_IMPORT_VALIDATE_M6_DEVICE_REVIEW.md`**

- 结论修正：DEVICE_VERIFIED → CODE_PATH_READY_DEVICE_REVIEW_BLOCKED
- 状态全部降级到 CODE_VERIFIED / DEVICE_RETRY_PENDING
- 新增 UI automation 阻塞原因的完整记录

**`docs/ui-handoff/ios/MILESTONE_STATUS.md`**

- M6 总体状态：DEVICE_VERIFIED → CODE_READY / DEVICE_REVIEW_BLOCKED_BY_UI_AUTOMATION
- 所有子任务降级到 CODE_READY / CODE_VERIFIED

## 6. 是否修改 Reader-Core

否。

## 7. 是否自动联网

否。导入/校验路径（步骤 1-9）不联网。仅有独立的"测试搜索"按钮触发 controlledOnline search，需手动点击。

## 8. Boundary / Build 结果

| 检查 | 结果 |
|---|---|
| boundary (`check_ios_boundary.sh`) | **PASS** — 110 files checked |
| build (`xcodebuild build`) | **BUILD SUCCEEDED** |
| fresh install + launch | ✅ App launched on iPhone 17 Pro Simulator |

## 9. 下一步 Codex 如何复测

### 运行环境

```bash
cd "/Users/minliny/Documents/Reader for iOS"
bash scripts/check_ios_boundary.sh
xcodebuild build -project "ReaderForIOS.xcodeproj" -scheme "ReaderForIOSApp" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcrun simctl uninstall booted "com.reader.ios"
xcrun simctl install booted "<path-to-app>"
xcrun simctl launch booted "com.reader.ios"
```

### 设备端操作

1. App 启动 → 默认"书架" Tab
2. 点击底部"我的" Tab
3. 下拉找到 "Developer Tools" section
4. 点击 "[验证] M6 书源导入链路"
5. 点击"执行 M6 导入链路验证"
6. 等待步骤列表刷新
7. 验证所有步骤显示绿色 ✅ checkmark
8. 截图每个 Section：
   - 验证步骤（全部绿色 ✅）
   - BookSourceStore 中的书源（显示星星小说网条目）
   - 可区分性（预置源带 ⭐，导入源不带 ⭐）
9. 可选：点击"测试搜索（controlledOnline）"执行手动测试
10. 截图测试结果

### 预期截图

| 文件名 | 内容 |
|---|---|
| m601_my_tab.png | "我的" Tab — Developer Tools section 包含 [验证] M6 |
| m602_verify_view_top.png | M6 验证页 — 操作按钮 |
| m603_verify_steps.png | 全部步骤绿色 ✅ |
| m604_verify_sources.png | BookSourceStore 书源列表 |
| m605_verify_distinguish.png | 可区分性验证 |
| m606_verify_search.png | 手动搜索测试结果（可选） |

## 10. P0 问题

无。

## 11. P1 问题

无。

## 报告路径

`docs/ui-handoff/ios/IOS_M6_DEVICE_REVIEW_AUTOMATION_READY_REPORT.md`
