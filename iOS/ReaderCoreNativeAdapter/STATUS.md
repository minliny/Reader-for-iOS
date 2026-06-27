# iOS Rust Core Host Adapter — STATUS

## Round 7: ReaderForIOSApp App/Simulator evidence path (IN PROGRESS)

### Round 7 新增范围

| 层级 | 载体 | 证据含义 |
|------|------|----------|
| wrapper smoke | `run-shell-smoke.sh` / `run-sim-smoke.sh` / `ReaderCoreNativeAdapterSmokeTests` | 只证明 adapter + ABI/protocol 可运行，不声明 App launch |
| App launch | `ReaderForIOSApp` Debug autorun / `NativeCoreEvidenceView` | 证明真实 App 进程加载 native adapter |
| host request loop | `ReaderCoreNativeAppEvidenceRunner` | `book.search -> http.execute host.request -> host.complete -> result` |

### Round 7 当前验证状态

| Gate | 命令 / 证据 | 当前结果 |
|------|-------------|----------|
| App target wiring | `xcodebuild -list -project ReaderForIOS.xcodeproj` | `ReaderCoreNativeAdapter` target 可见，`ReaderForIOSApp` scheme 可见 |
| App build | `xcodebuild build -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` | **BUILD SUCCEEDED** |
| wrapper smoke baseline | `bash iOS/ReaderCoreNativeAdapter/run-shell-smoke.sh` | `[core] pass=29 fail=0`, `[app-side] pass=4 fail=0` |
| App launch + host request loop | `bash scripts/run_native_core_app_evidence_simulator.sh --device "iPhone 17 Pro"` | **BLOCKED**：当前无 booted simulator，脚本 fail-fast，未生成 `native_core_evidence.json` |

当前状态只证明 App 已能编译并链接 native adapter，且 wrapper smoke 未回退。
它**不**证明 App launch 或真实 host request loop 已完成；这两项需要 booted simulator
运行 autorun 后，以 `native_core_evidence.json` 为证据。

2026-06-26 复核：`xcrun simctl list devices booted` 无设备；脚本 fail-fast 正常。
随后尝试 `--boot-if-needed` 与直接 `xcrun simctl boot FE9FC658-0BB3-4006-8EA0-DF44D3819167`，
均卡在 CoreSimulator 启动阶段且仍无 booted device，因此 Goal B 维持 blocked。

### Round 7 关键改动

1. `ReaderCoreNativeEvidenceRunner.swift`：新增 App 可复用 host request loop runner，
   输出 `reader-ios.native-core-evidence.v1` JSON，不改 Native protocol/schema。
2. `NativeCoreEvidenceView.swift`：新增 Debug UI 与 autorun view，支持
   `--native-core-evidence-autorun`。
3. `ReaderForIOSApp` target 通过 `Package.swift` / `project.yml` 依赖
   `ReaderCoreNativeAdapter`，把证据从 wrapper smoke 推进到 App 进程。
4. `scripts/run_native_core_app_evidence_simulator.sh`：构建、安装、启动 App 并收集
   `native_core_evidence_status.json` / `native_core_evidence.json`，随后校验
   `wrapper_smoke` 不声明 App 执行、`app_launch` 为 `measuredPass`、
   `host_request_loop` 为 `measuredPass` 且 `capability=http.execute`。

### Run command

```bash
cd /Users/minliny/Documents/Reader\ for\ iOS
bash scripts/run_native_core_app_evidence_simulator.sh --device "iPhone 17 Pro"
```

默认要求已有 booted simulator；若无 booted simulator，脚本会在构建前 fail-fast。
如要让脚本负责启动模拟器，可显式追加 `--boot-if-needed`。

---

## Round 6: xcodebuild SwiftPM 集成修复（binaryTarget + 共享 scheme） (COMPLETED)

**Commit:** `7690ce6`

### Round 6 新增证据

| 路径 | 载体 | 结果 |
|------|------|------|
| macOS standalone | `run-shell-smoke.sh`（swiftc + libreader_core.a） | 33/33 PASS |
| iOS-sim standalone | `run-sim-smoke.sh`（swiftc + libreader_core_sim.a + simctl spawn） | 33/33 PASS |
| **iOS-sim XCTest**（新） | `xcodebuild -scheme ReaderCoreNativeAdapterSmokeTests`（binaryTarget xcframework） | **9/9 PASS** |

**xcodebuild XCTest 在 iPhone 17 模拟器跑通**：`Executed 9 tests, with 0 failures`。

### Round 6 关键改动

1. **Package.swift**：`ReaderCoreNative` 从 header-only C target + unsafeFlags 改为
   `binaryTarget(path: "ReaderCoreNativeAdapter/cabi/ReaderCore.xcframework")`。移除
   `linkerSettings` unsafeFlags 与 `import Foundation`/`packageCabiDir`。binaryTarget
   让单一 SwiftPM/xcodebuild 配置按平台自动选 xcframework slice（macOS / iOS-sim），
   无需 platform-conditional linkerSettings。
2. **fetch-cabi.sh**：新增 `--xcframework` 选项，用 `xcodebuild -create-xcframework` 把
   macOS `libreader_core.a` + iOS-sim `libreader_core_sim.a` 合并为
   `cabi/ReaderCore.xcframework`（macos-arm64 + ios-arm64-simulator slice）。
3. **共享 scheme**：新增 `iOS/.swiftpm/xcode/xcshareddata/xcschemes/ReaderCoreNativeAdapterSmokeTests.xcscheme`，
   只构建 `ReaderCoreNativeAdapterSmokeTests`（依赖链不含 `ReaderApp`），绕过 pre-existing
   的 `ReaderApp` target 构建问题（`BrightnessPolicy` 跨模块 + iOS-only API）。
4. **.gitignore**：`.swiftpm/` 改为逐层 un-ignore，让共享 scheme 入 git，但构建产物仍忽略。

### Round 6 解决的问题
- `ReaderCoreNative.o` 产物缺失（header-only target 无 .o）→ binaryTarget 不需要 .o
- iOS 模拟器链接 macOS lib 架构不匹配 → xcframework 自动选 iOS-sim slice
- xcodebuild `-scheme ReaderApp-Package` 拉损坏的 ReaderApp → 独立 scheme 绕过

### Round 6 未解决（pre-existing，非 adapter 范围）
- `ReaderApp` target 自身的 `BrightnessPolicy` 跨模块可见性问题 + iOS-only API 在 macOS 不可用
  → 不在本 goal 范围，由独立 scheme 绕过，不修复

### Run command
```bash
cd iOS/ReaderCoreNativeAdapter
# 准备 xcframework（binaryTarget 需要）
bash ./fetch-cabi.sh --xcframework
# 三条证据路径
bash ./run-shell-smoke.sh                                    # macOS standalone
bash ./run-sim-smoke.sh                                      # iOS-sim standalone
cd .. && xcodebuild -scheme ReaderCoreNativeAdapterSmokeTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' test  # iOS-sim XCTest
```

---

## Round 5: iOS 模拟器烟雾测试证据 (COMPLETED)

**Commit:** `bee92c1`

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
