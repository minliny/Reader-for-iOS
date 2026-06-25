# iOS Rust Core Host Adapter — STATUS

## Round 2: Host Bus 完整循环 + 远程阅读协议骨架 (COMPLETED)

**Commit:** TBD

### Capability Table

| # | Capability | Type | Round | Evidence | Status |
|---|-----------|------|-------|----------|--------|
| 1 | `rc_abi_version()` returns 1 | `[core]` | R1 | ShellSmokeTests PASS | ✅ |
| 2 | `core.info` returns abiVersion + protocolVersion | `[core]` | R1 | ShellSmokeTests PASS | ✅ |
| 3 | `runtime.ping` returns pong=true | `[core]` | R1 | ShellSmokeTests PASS | ✅ |
| 4 | Unknown method surfaces UNKNOWN_METHOD error | `[core]` | R1 | ShellSmokeTests PASS | ✅ |
| 5 | Malformed JSON send fails with non-zero status | `[core]` | R1 | ShellSmokeTests PASS | ✅ |
| 6 | Core emits `host.request` for host capabilities | `[core]` | R1 | ShellSmokeTests PASS | ✅ |
| 7 | Cancel surfaces CANCELLED error code | `[core]` | R1 | ShellSmokeTests PASS | ✅ |
| 8 | host.request carries operationId | `[core]` | R2 | ShellSmokeTests PASS | ✅ |
| 9 | host.complete → result (echo 完整循环) | `[core]` | R2 | ShellSmokeTests PASS | ✅ |
| 10 | host.error → error (错误传播到原始请求) | `[core]` | R2 | ShellSmokeTests PASS | ✅ |
| 11 | `runtime.status` returns result | `[core]` | R2 | ShellSmokeTests PASS | ✅ |
| 12 | `runtime.status` has activeRequestCount | `[core]` | R2 | ShellSmokeTests PASS | ✅ |
| 13 | `book.search` inline response returns result | `[core]` | R2 | ShellSmokeTests PASS | ✅ |
| 14 | `book.search` inline parses books (jsonPath) | `[core]` | R2 | ShellSmokeTests PASS | ✅ |
| 15 | `book.toc` inline response returns result | `[core]` | R2 | ShellSmokeTests PASS | ✅ |
| 16 | `book.toc` inline parses toc entries | `[core]` | R2 | ShellSmokeTests PASS | ✅ |
| 17 | `chapter.content` inline response returns result | `[core]` | R2 | ShellSmokeTests PASS | ✅ |
| 18 | `chapter.content` inline extracts content (cssText) | `[core]` | R2 | ShellSmokeTests PASS | ✅ |
| 19 | Runtime create + destroy | `[app-side]` | R1 | ShellSmokeTests PASS | ✅ |
| 20 | Invalid config create fails | `[app-side]` | R1 | ShellSmokeTests PASS | ✅ |
| 21 | pollEvent drains result event | `[app-side]` | R1 | ShellSmokeTests PASS | ✅ |
| 22 | pollEvent returns nil for consumed event | `[app-side]` | R1 | ShellSmokeTests PASS | ✅ |

**合计：22/22 PASS（18 [core] + 4 [app-side]）**

### Run command
```bash
cd iOS/ReaderCoreNativeAdapter
bash ./fetch-cabi.sh   # first time: materialize libreader_core.a from ../Reader-Core-Native
bash ./run-shell-smoke.sh
```

### Round 2 新增适配器能力
- `ReaderCoreNativeEvent.operationId` — 从 `host.request` 事件中提取 `operationId`
- `ReaderCoreNativeEvent.capability` — 从 `host.request` 事件中提取 capability 名称
- `ReaderCoreNativeEvent.hostParams` — 从 `host.request` 事件中提取 params

### Round 2 协议发现（通过烟雾测试验证）
- **Host Bus 协议**：`host.complete` 的 `result` 必须是 JSON object；`host.error` 的 `error` 必须是 object（含 `code` + `message` + `retryable`）
- **远程阅读协议**：`book.search` 结果 key 是 `"books"`（数组）；`book.toc` 结果 key 是 `"toc"`（数组）；`chapter.content` 结果 key 是 `"content"`（字符串）
- **`runtime.status`**：camelCase key（`activeRequestCount`、`pendingHostOperationCount` 等）
- **ErrorCode**：只有 `UNKNOWN_METHOD`、`INVALID_PARAMS`、`INVALID_PROTOCOL_VERSION`、`CANCELLED`、`INVALID_MESSAGE`、`INTERNAL` 六种，自定义 code 会被拒绝

### Round 1 bug fix（本回合回顾）
- `ReaderCoreNativeRuntime.swift:51`：`data` 属性读 `object["result"]` → `object["data"]`

### 预存基线问题（记录但不修复）
- `scripts/check_ios_boundary.sh` FAIL — `CoreRSSFeedService.swift:3` imports `ReaderCoreParser`
- `swift build --target ReaderApp` FAIL on macOS — iOS-only APIs

### 待后续轮次
- Host HTTP 管线：`http.execute` capability → 真正的远程书籍搜索（host.request → URLSession → host.complete）
- `book.detail` / `source.import` / `reading.progress.update` 烟雾覆盖
- `runtime.shutdown` 生命周期测试
- iOS 模拟器/真机运行（被 ReaderApp 构建问题阻塞）
- xcframework 集成用于 iOS 构建
