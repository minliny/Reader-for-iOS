# iOS Rust Core Host Adapter — STATUS

## Round 3: Host HTTP 执行管线 (COMPLETED)

**Commit:** `cbb02f0`

### Capability Table

| # | Capability | Type | Round | Evidence | Status |
|---|-----------|------|-------|----------|--------|
| 1-7 | ABI 连通性（abi version, core.info, runtime.ping, UNKNOWN_METHOD, malformed JSON, host.request, cancel→CANCELLED） | `[core]` | R1 | ShellSmokeTests PASS | ✅ |
| 8-10 | Host Bus 循环（operationId, host.complete→result, host.error→error） | `[core]` | R2 | ShellSmokeTests PASS | ✅ |
| 11-12 | runtime.status（result, activeRequestCount） | `[core]` | R2 | ShellSmokeTests PASS | ✅ |
| 13-18 | 远程阅读 inline（book.search/toc, chapter.content 解析） | `[core]` | R2 | ShellSmokeTests PASS | ✅ |
| 19 | `http.execute` 触发 host.request（searchRequest → Core emit host.request with capability "http.execute"） | `[core]` | R3 | ShellSmokeTests PASS | ✅ |
| 20 | `http.execute` 完整管线（host.complete + HostHttpResponse → Core 解析 → result） | `[core]` | R3 | ShellSmokeTests PASS | ✅ |
| 21 | `http.execute` 空 URL 被拒绝（INVALID_PARAMS） | `[core]` | R3 | ShellSmokeTests PASS | ✅ |
| 22 | `http.execute` searchRequest 解析 books（jsonPath 规则链） | `[core]` | R3 | ShellSmokeTests PASS | ✅ |
| 23-26 | App-side 适配器（create/destroy, invalid config, pollEvent drain+consumed） | `[app-side]` | R1 | ShellSmokeTests PASS | ✅ |

**合计：26/26 PASS（22 [core] + 4 [app-side]）**

### Run command
```bash
cd iOS/ReaderCoreNativeAdapter
bash ./fetch-cabi.sh   # first time: materialize libreader_core.a from ../Reader-Core-Native
bash ./run-shell-smoke.sh
```

### Round 3 协议发现
- **`http.execute` host.request params 包含**：`url`（string）、`method`（string，默认 GET）、`headers`（object，可选）、`body`（string|null，可选）
- **`host.complete` result（http.execute 管线）**：必须为 `HostHttpResponse` object — `body`（string, required）、`status`（u16, 100-599, 可选）、`headers`（object, 可选）
- **管线模式切换**：`book.search` 等命令优先看 `searchResponse`（inline），其次看 `searchRequest`（http.execute）；返回 `pending` 时分配 operationId
- **空 URL 验证**：`http.execute` request URL 为空时返回 INVALID_PARAMS 错误

### Round 2 协议发现（回顾）
- `book.search` 结果 key 是 `"books"`（数组），不是 `"results"`
- `book.toc` 结果 key 是 `"toc"`（数组），不是 `"entries"`
- `chapter.content` 结果 key 是 `"content"`（字符串），不是 `"body"`
- `host.error` 的 error object 必须含 `retryable: bool`

### 预存基线问题（记录但不修复）
- `scripts/check_ios_boundary.sh` FAIL — `CoreRSSFeedService.swift:3` imports `ReaderCoreParser`
- `swift build --target ReaderApp` FAIL on macOS — iOS-only APIs

### 待后续轮次
- `book.detail` / `source.import` / `reading.progress.update` 烟雾覆盖
- `runtime.shutdown` 生命周期测试
- 真正的 URLSession 集成（烟雾测试用假 URL 和 host.complete 模拟了 HTTP）
- iOS 模拟器/真机运行（被 ReaderApp 构建问题阻塞）
- xcframework 集成用于 iOS 构建
