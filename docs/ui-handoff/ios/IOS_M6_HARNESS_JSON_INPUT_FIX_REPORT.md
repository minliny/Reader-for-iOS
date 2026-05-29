# iOS M6 Harness JSON Input Fix Report

## 1. 总体结论

**IOS_M6_HARNESS_JSON_INPUT_FIX_READY**

## 2. 本轮目标

本轮只修 Debug harness JSON 输入源问题 M6-HARNESS-P1-004，不修改 Reader-Core，不扩大 normalizer 规则，不接 WebDAV/RSS/Sync。

## 3. 问题根因

上一轮 Debug harness 使用 hardcoded 多行字符串 literal 作为 `xingxingxswJSON`。该字符串在 Swift 源码转义过程中丢失了 JSON 的二进制完整性，导致 `JSONSerialization.jsonObject(with:)` 在 normalize 阶段之前就抛出 `The data couldn't be read because it isn't in the correct format.`。

问题不在生产导入 UI，也不在 normalizer 主逻辑，而是 harness 内嵌 JSON 在 normalize 前就被判定为无效。

## 4. 修复策略

- 移除 hardcoded escaped JSON literal
- 改为从 Bundle resource 加载 `xingxingxsw.search-only.json`
- 尝试两个路径：`AppSupport/Sources/` 子目录 和 bundle root
- 若 resource 缺失，错误信息明确指出 `Missing xingxingxsw.search-only.json in bundle. Check project.yml ReaderForIOSApp sources.`
- Step 1 拆分为：查找 resource → 显示 JSON source label → text → Data 编码

## 5. 实现内容

### 修改文件

**`iOS/Features/Mine/M6BookSourceImportVerificationView.swift`**

- 删除 hardcoded `xingxingxswJSON` static let
- 新增 `@State private var jsonSourceLabel: String = "未加载"` 用于显示 JSON 来源
- 新增 `loadBundledXingxingJSON()` 方法，尝试从 `AppSupport/Sources/xingxingxsw.search-only.json` 和 bundle root 两个路径加载
- `runFullVerification()` Step 1 改为调用 `loadBundledXingxingJSON()`，不再使用 `Self.xingxingxswJSON`
- Step 1 拆分为 `1. 查找 bundled xingxingxsw JSON`、`1a. JSON source`、`1b. JSON text → Data 编码`

### 资源路径

`iOS/AppSupport/Sources/xingxingxsw.search-only.json` 属于 `ReaderAppSupport` framework sources，已通过 `project.yml` 的 `ReaderForIOSApp` → `iOS/AppSupport` path 包含在 App bundle 中，无需额外配置。

## 6. 验证结果

| 检查 | 结果 |
|---|---|
| bundled JSON resource 可找到 | 代码逻辑正确，resource 在 AppSupport/Sources |
| bundled JSON data 可读取 | 代码逻辑正确 |
| JSONSerialization 可解析 | 代码逻辑正确（使用真实文件内容） |
| normalizer 可处理 | 上一轮已 CODE_READY |
| local validation 可执行 | 上一轮已 CODE_READY |
| capability 可生成 | 上一轮已 CODE_READY |
| save imported source 可执行 | 上一轮已 CODE_READY |
| reload/list 可找到 imported source | 上一轮已 CODE_READY |
| imported source distinguishable | 上一轮已 CODE_READY |
| imported source detail path 可用 | 上一轮已 CODE_READY |
| manual test entry 可见 | 上一轮已 CODE_READY |
| build | **BUILD SUCCEEDED** |
| boundary | **PASS** — 110 files checked |

## 7. 网络与安全边界

- 导入/校验不自动联网 ✅
- 手动搜索才 controlledOnline ✅
- 未接 WebDAV/RSS/Sync ✅
- 未修改 Reader-Core ✅
- Debug harness `#if DEBUG` ✅

## 8. P0 问题

无。

## 9. P1 问题

无。

## 10. 下一步建议

Codex 使用 Debug harness 重新执行 M6 Device Review：启动 App → 我的 Tab → [验证] M6 书源导入链路 → 点击"执行 M6 导入链路验证"，验证全部步骤绿色通过。

## 报告路径

`docs/ui-handoff/ios/IOS_M6_HARNESS_JSON_INPUT_FIX_REPORT.md`

## MILESTONE_STATUS 路径

`docs/ui-handoff/ios/MILESTONE_STATUS.md`