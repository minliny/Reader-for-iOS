# iOS Rust Core Host Adapter — STATUS

## Round 5: iOS 模拟器烟雾测试证据 (COMPLETED)

**Commit:** TBD

### Round 5 新增证据

| 维度 | macOS host | iOS 模拟器 | 真机 |
|------|-----------|-----------|------|
| 脚本 | `run-shell-smoke.sh` | `run-sim-smoke.sh` | — |
| lib | `cabi/libreader_core.a` (macOS arm64, platform 1) | `cabi/libreader_core_sim.a` (iOS-sim arm64, platform 7) | — |
| 运行方式 | 直接执行 Mach-O | `xcrun simctl spawn <booted UDID>` | — |
| 结果 | 33/33 PASS (29 [core] + 4 [app-side]) | **33/33 PASS** (29 [core] + 4 [app-side]) | 未验证 |

**模拟器证据：iPhone 17 模拟器（UDID `4647E187-...`），iOS-sim arm64，全部 33 个用例 PASS。**

> ⚠️ **模拟器 smoke ≠ 真机。** 模拟器是 x86/arm64 host 进程模拟，非真机硬件、非真机签名、
> 非真机 iOS 运行时。真机证据需 iOS device slice + 设备签名，后续轮次。

### Run command
```bash
cd iOS/ReaderCoreNativeAdapter
# macOS host
bash ./fetch-cabi.sh
bash ./run-shell-smoke.sh
# iOS 模拟器
bash ./fetch-cabi.sh --sim
bash ./run-sim-smoke.sh   # 输出 tee 到 sim-smoke-report.txt
```

### 累计能力表（Round 1-5）

| # | Capability | Type | Round | Status |
|---|-----------|------|-------|--------|
| 1-7 | ABI 连通性（abi version, core.info, runtime.ping, UNKNOWN_METHOD, malformed JSON, host.request, cancel→CANCELLED） | `[core]` | R1 | ✅ |
| 8-10 | Host Bus 循环（operationId, host.complete→result, host.error→error） | `[core]` | R2 | ✅ |
| 11-12 | runtime.status（result, activeRequestCount） | `[core]` | R2 | ✅ |
| 13-18 | 远程阅读 inline（book.search/toc, chapter.content 解析） | `[core]` | R2 | ✅ |
| 19-22 | http.execute 管线（host.request→host.complete→result, 空URL拒绝, books解析） | `[core]` | R3 | ✅ |
| 23 | source.import 导入书源到存储 | `[core]` | R4 | ✅ |
| 24-25 | book.detail inline（合并元数据, 拒绝非object book） | `[core]` | R4 | ✅ |
| 26-28 | reading.progress.update（存储进度, 返回chapterIndex, 拒绝>1.0） | `[core]` | R4 | ✅ |
| 29-32 | App-side 适配器（create/destroy, invalid config, pollEvent drain+consumed） | `[app-side]` | R1 | ✅ |
| 33 | iOS 模拟器执行环境（交叉编译 + simctl spawn 跑通全部用例） | `[app-side]` | R5 | ✅ |

**合计：33/33 PASS on macOS host + 33/33 PASS on iOS Simulator（29 [core] + 4 [app-side]）**

### 协议发现汇总（Round 1-5）
- **event JSON 形状**：Result 的 data key 是 `"data"`，不是 `"result"`（R1 bug fix）
- **Host Bus 协议**：`host.complete` result 必须是 JSON object；`host.error` 的 error object 必须含 `retryable`（R2）
- **远程阅读协议**：结果 key `"books"`/`"toc"`/`"content"`（不是 `"results"`/`"entries"`/`"body"`）（R2）
- **`runtime.status`**：camelCase key（`activeRequestCount` 等）（R2）
- **ErrorCode**：只有 6 种标准码，自定义 code 被拒绝（R2）
- **`http.execute` 协议**：host.request params 含 `url`/`method`/`headers`/`body`；host.complete result 必须为 `{body, status?, headers?}`（R3）
- **`book.detail`**：`book` 字段必须是 object（含 `bookId`）；通过 `serde_json::from_value::<Book>` 做严格验证（R4）
- **`source.import`**：`rules` 接受 object 或 null；`name` 不能为空（R4）
- **`reading.progress.update`**：chapterProgress 必须 0.0..=1.0，超出返回 INVALID_PARAMS（R4 修复后验证通过，需最新 lib）
- **iOS-sim lib 架构**：`cargo build -p reader-ffi --release --target aarch64-apple-ios-sim` 产出 platform 7 slice，`fetch-cabi.sh --sim` 拉取（R5）

### 预存基线问题（记录但不修复）
- `scripts/check_ios_boundary.sh` FAIL — `CoreRSSFeedService.swift:3` imports `ReaderCoreParser`
- `swift build --target ReaderApp` FAIL on macOS — iOS-only APIs
- `xcodebuild -scheme ReaderApp-Package test` 阻塞于 header-only C target `ReaderCoreNative` 不产生 `ReaderCoreNative.o` 产物（SwiftPM + xcodebuild 限制）

### 待后续轮次
- 修复 xcodebuild SwiftPM 集成（`ReaderCoreNative.o` 产物问题，需改 Package.swift）
- 真机（iPhone device）运行 — 需 iOS device slice + 签名
- `runtime.shutdown` 生命周期测试
- service-protocol 对接（SearchService/TOCService/ContentService 走 Rust 而非 Swift Core）
