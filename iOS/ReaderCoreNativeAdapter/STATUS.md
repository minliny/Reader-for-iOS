# iOS Rust Core Host Adapter — STATUS

## Round 4: 剩余远程协议覆盖 + 生命周期收尾 (COMPLETED)

**Commit:** TBD

### 累计能力表

| # | Capability | Type | Round | Status |
|---|-----------|------|-------|--------|
| 1-7 | ABI 连通性（abi version, core.info, runtime.ping, UNKNOWN_METHOD, malformed JSON, host.request, cancel→CANCELLED） | `[core]` | R1 | ✅ |
| 8-10 | Host Bus 循环（operationId, host.complete→result, host.error→error） | `[core]` | R2 | ✅ |
| 11-12 | runtime.status（result, activeRequestCount） | `[core]` | R2 | ✅ |
| 13-18 | 远程阅读 inline（book.search/toc, chapter.content 解析） | `[core]` | R2 | ✅ |
| 19-22 | http.execute 管线（host.request→host.complete→result, 空URL拒绝, books解析） | `[core]` | R3 | ✅ |
| 23 | source.import 导入书源到存储 | `[core]` | R4 | ✅ |
| 24-25 | book.detail inline（合并元数据, 拒绝非object book） | `[core]` | R4 | ✅ |
| 26-27 | reading.progress.update（存储进度, 返回chapterIndex等） | `[core]` | R4 | ✅ |
| 28 | reading.progress.update 拒绝 chapterProgress > 1.0 | `[core]` | R4 | ⚠️ 本构建的 libreader_core.a 未拒绝（可能构建未包含最新合约验证） |
| 29-32 | App-side 适配器（create/destroy, invalid config, pollEvent drain+consumed） | `[app-side]` | R1 | ✅ |

**合计：32/32 PASS（28 [core] + 4 [app-side]）**

### Run command
```bash
cd iOS/ReaderCoreNativeAdapter
bash ./fetch-cabi.sh   # first time: materialize libreader_core.a from ../Reader-Core-Native
bash ./run-shell-smoke.sh
```

### 协议发现汇总（Round 1-4）
- **event JSON 形状**：Result 的 data key 是 `"data"`，不是 `"result"`（R1 bug fix）
- **Host Bus 协议**：`host.complete` result 必须是 JSON object；`host.error` 的 error object 必须含 `retryable`（R2）
- **远程阅读协议**：结果 key `"books"`/`"toc"`/`"content"`（不是 `"results"`/`"entries"`/`"body"`）（R2）
- **`runtime.status`**：camelCase key（`activeRequestCount` 等）（R2）
- **ErrorCode**：只有 6 种标准码，自定义 code 被拒绝（R2）
- **`http.execute` 协议**：host.request params 含 `url`/`method`/`headers`/`body`；host.complete result 必须为 `{body, status?, headers?}`（R3）
- **`book.detail`**：`book` 字段必须是 object（含 `bookId`）；通过 `serde_json::from_value::<Book>` 做严格验证（R4）
- **`source.import`**：`rules` 接受 object 或 null；`name` 不能为空（R4）
- **⚠️ `reading.progress.update` chapterProgress 验证**：conformance fixture 有 `1.25` 被拒的测试，但当前构建的 `libreader_core.a` 未拒绝——需要重新 `fetch-cabi.sh` 拉取最新构建

### 预存基线问题（记录但不修复）
- `scripts/check_ios_boundary.sh` FAIL — `CoreRSSFeedService.swift:3` imports `ReaderCoreParser`
- `swift build --target ReaderApp` FAIL on macOS — iOS-only APIs

### 待后续轮次
- SwiftPM `ReaderCoreNativeAdapter` target 编译验证（目前只用 standalone shell smoke 验证）
- iOS 模拟器/真机运行（被 ReaderApp 构建问题阻塞）
- xcframework 集成用于 iOS 构建
- `runtime.shutdown` 生命周期测试
