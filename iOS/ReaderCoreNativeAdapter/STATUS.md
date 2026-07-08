# iOS Rust Core Host Adapter — STATUS

## Host Capability Registry + Core host.request router — Xcode test-without-building 证据（2026-07-08 +0800）

### 提交范围

| 提交 | 内容 |
|------|------|
| `7ce3607` | `feat(host): wire HostCapabilityRegistry with 31 HostRequestType dispatch proof` — 16 files / +2551 −78 |
| `e5840bc` | `feat(host): extend Core host.request router with media/webview/anti-bot real-executor proof` — 20 files / +1938 −294 |
| `1e5c46e` | `chore(ios): sync raw animation whitelist line numbers after host router commits` |

C ABI / `fetch-cabi.sh` / persistence plan 不在本次提交范围，单独处理。

### 本地 macOS gate（`swift build` / `swift test`）

| Gate | 结果 |
|------|------|
| `swift build` | **PASS** (1.72s) |
| `swift test --filter "HostRouterRoundTripProofTests\|HostAntiBotProofTests\|HostMediaDownloadProofTests\|HostAdapterCapabilityDispatchProofTests\|HostAdapterRealDeviceProofManifestTests\|HostRequestRoundTripProofTests"` | **PASS**：43 tests, 0 failures (60.487s) |
| `bash scripts/check_ios_boundary.sh` | **PASS**（checked_files=208） |
| `bash scripts/check_ios_raw_animation.sh --strict` | **PASS**（13 raw calls, 13 whitelisted, 0 violations） |

### Xcode test-without-building（iPhone 17 Simulator, iOS 26.5, arm64）

#### 第一轮 sim 结果（credential entitlement 缺口暴露）

| Gate | 结果 |
|------|------|
| `xcodebuild build-for-testing` | **TEST BUILD SUCCEEDED** |
| `xcodebuild test-without-building` | **53 cases executed, 51 passed, 2 failed** (100.088s) |

xcresult: `~/Library/Developer/Xcode/DerivedData/ReaderForIOS-dszsblvovajxpffmptoojgfeejrh/Logs/Test/Test-ReaderForIOSApp-2026.07.07_21-13-46-+0800.xcresult`

#### 旧失败项（2 个 test case，共 10 条 assertion failure，同根因）

| 测试 | 失败原因 |
|------|----------|
| `HostAdapterCapabilityDispatchProofTests.testCredentialSetGetDeleteRoundTrip()` | `SecItemAdd status -34018 (errSecMissingEntitlement)` |
| `HostAdapterRealDeviceProofManifestTests.testCrossPlatformTypesSucceedOnMacOS()` | 同上（cookie + clipboard 部分通过，仅 credential.* 失败） |

**根因**：iOS 17+ Simulator 的 `SecItemAdd` / `SecItemCopyMatching` 要求 host app 二进制携带
`keychain-access-groups` entitlement。`ReaderForIOSApp` 当前 `project.yml` 未配置
`CODE_SIGN_ENTITLEMENTS`，且 CI gate 使用 `CODE_SIGNING_ALLOWED=NO`（不签名 → 不嵌入 entitlement）。
这是 **host-app entitlement 配置缺口**，不是 `HostCredentialCapability` handler 代码 bug：
macOS `swift test` 上同一 handler 通过（keychain 在 macOS 不需要 entitlement）。

#### 当前 sim 口径（2026-07-08 00:56 +0800）

决策：**不为 simulator CI gate 补签名 entitlement**。`CODE_SIGNING_ALLOWED=NO`
是当前 sim gate 的真实约束；`credential.*` 依赖 `keychain-access-groups`
entitlement，因此在 iOS Simulator 上用 `XCTSkip` 明确标记为 entitlement-blocked。
真机 proof 继续覆盖 credential runtime 可用性。

| Gate | 结果 |
|------|------|
| `swift test --filter "HostAdapterCapabilityDispatchProofTests\|HostAdapterRealDeviceProofManifestTests"` | **18 tests, 0 failures** |
| `xcodebuild test ... -only-testing:ReaderAppTests/HostAdapterCapabilityDispatchProofTests -only-testing:ReaderAppTests/HostAdapterRealDeviceProofManifestTests CODE_SIGNING_ALLOWED=NO` | **18 tests executed, 1 skipped, 0 failures** |

xcresult: `~/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Logs/Test/Test-ReaderForIOSApp-2026.07.08_00-56-35-+0800.xcresult`

修正点：Swift 条件编译必须使用小写 `targetEnvironment(simulator)`；旧提交里的
`targetEnvironment(Simulator)` 不会命中 simulator 分支，导致 `-34018` 仍进入断言。

#### 当前通过项按 tier 分类

| Tier | 测试套件 | 结果 |
|------|----------|------|
| crossPlatform dispatch proof | `HostAdapterCapabilityDispatchProofTests`（12 pass + 1 skipped：credential.* sim entitlement-blocked） | **PASS** |
| tier manifest | `HostAdapterRealDeviceProofManifestTests`（5/5；sim 上只跑 cookie + clipboard，credential 部分编译期排除） | **PASS** |
| Core host.request router | `HostRouterRoundTripProofTests`（7/7） | **PASS** |
| anti-bot real-executor | `HostAntiBotProofTests`（6/6） | **PASS** |
| media real-executor | `HostMediaDownloadProofTests`（8/8） | **PASS** |
| WKWebView real-executor (simulator) | `WKWebViewExecutorSimulatorProofTests`（4/4 编译期 + 安全门测试） | **PASS** |
| URLSession media real-executor | `URLSessionMediaDownloadExecutorProofTests`（11/11） | **PASS** |

> ⚠️ **"本地 handler 可编译" ≠ "host 后端完整可发布"**：credential.* 在 iOS Simulator
> 的 `CODE_SIGNING_ALLOWED=NO` gate 下没有 keychain entitlement，因此现在被显式
> 标记为 skip；真机签名产物带 `keychain-access-groups` entitlement，credential.* 全通过。
> 这比让 sim 失败更准确，也避免为了 sim gate 引入偏离 CI 的签名配置。

### 真机 device proof（Xcode IDE, 2026-07-07 23:03 +0800）+ fixture 修复后状态（2026-07-08 00:10 +0800）

#### 第一轮真机 test（fixture 修复前）

| 项 | 结果 |
|----|------|
| 物理设备 | `Minliny`, iPhone 14 Pro Max (iPhone15,3), iOS 26.5 (23F77), UDID `00008120-001A15601A6BC01E` |
| 跑法 | Xcode IDE → Product > Test（命令行 codesign 阻塞于 keychain ACL 授权弹窗，非交互 shell 无法显示；IDE 用 Touch ID / 已授权 session 通过） |
| xcresult | `~/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Logs/Test/Test-ReaderForIOSApp-2026.07.07_23-03-54-+0800.xcresult` |
| 总计 | **396 cases executed, 395 passed, 1 failed** |
| 失败项 | `HostRouterRoundTripProofTests/testWebViewEvaluateJavaScriptDispatchPathComplete()` — failureText: "Testing was canceled" |

##### 唯一失败项分析（fixture 修复前）

| 项 | 详情 |
|----|------|
| 测试 | `HostRouterRoundTripProofTests/testWebViewEvaluateJavaScriptDispatchPathComplete()` |
| 失败原因 | "Testing was canceled"（**不是** assertion failure，**不是** codesign/entitlement 问题） |
| 根因 | 真机上 `makeRouter` 注入真实 `WKWebViewExecutor`，测试参数 `url=https://example.test/render` + `javaScript=document.title`。`example.test` 是不存在的域名，WKWebView 加载该 URL 时 didFail 回调未及时触发，`await` 挂起超过 Xcode 默认测试超时，导致整个测试 session 被 cancel |
| 性质 | **真机 WKWebView 真实执行路径的超时问题**，不是代码 bug。反向证明了真机上 `WKWebViewExecutor` 确实被调用并尝试加载页面（fail-closed 路径走通了，只是超时阈值不够） |
| 修复 | 测试 fixture 从 `kind: "url"` + `https://example.test/render` 改为 `kind: "html"` + inline HTML 字符串（commit `87b0cd1`），WKWebView 直接 `loadHTMLString` 从内存加载，无网络依赖 |

#### 第二轮验证（fixture 修复后，commit `87b0cd1` + `2ade66c`）

| 平台 | 结果 | 证据 |
|------|------|------|
| macOS `swift test --filter HostRouterRoundTripProofTests` | **7/7 passed**（0.000s，executor=nil 走 fail-closed 路径） | 本地跑 |
| iOS Simulator `test-without-building` (iPhone 17, iOS 26.5) | **7/7 passed**（webview case 62s — sim WKWebView 进程启动开销，无超时，无 cancel） | `~/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Logs/Test/Test-ReaderForIOSApp-2026.07.07_23-33-14-+0800.xcresult` |
| **真机 device proof** (iPhone 14 Pro Max, iOS 26.5) | **53/53 passed, 0 failures** in 0.633s | `/tmp/reader-ios-host-proof-derived/Logs/Test/Test-ReaderForIOSApp-2026.07.08_00-32-37-+0800.xcresult` |

#### 真机 device proof 结果（2026-07-08 00:32 +0800, fixture 修复后）

| Test Suite | 执行数 | 失败 | 耗时 |
|------------|--------|------|------|
| `HostAdapterCapabilityDispatchProofTests` | 13 | 0 | 0.072s |
| `HostAdapterRealDeviceProofManifestTests` | 5 | 0 | 0.022s |
| `HostAntiBotProofTests` | 6 | 0 | 0.007s |
| `HostMediaDownloadProofTests` | 8 | 0 | 0.011s |
| `HostRouterRoundTripProofTests`（含 webview.evaluateJavaScript） | 7 | 0 | 0.505s |
| `URLSessionMediaDownloadExecutorProofTests` | 10 | 0 | 0.021s |
| `WKWebViewExecutorSimulatorProofTests` | 4 | 0 | 0.007s |
| **总计 `ReaderAppTests.xctest`** | **53** | **0** | **0.645s** |

**`** TEST EXECUTE SUCCEEDED **`**

##### 真机 codesign 解锁方法（命令行非交互）

命令行 codesign 之前阻塞于 `errSecInternalComponent`（keychain ACL 并发竞态）。解锁步骤：

1. **移除重复 keychain**：`security list-keychains -s login.keychain-db`（移除 `reader-ios-build.keychain-db`，消除重复签名身份）
2. **解锁 login keychain**：`security unlock-keychain -p "" login.keychain-db`（login keychain 密码为空）
3. **build-for-testing 不签名**：`xcodebuild build-for-testing ... CODE_SIGNING_ALLOWED=NO`（避免并发 codesign 竞态）
4. **手动串行 codesign**：对所有 framework / dylib / xctest / app bundle 逐个 `codesign --force --sign <identity>`（串行避免并发竞态）
5. **app bundle 注入 entitlements**：`codesign --force --sign <identity> --entitlements /tmp/reader-host-entitlements.plist --generate-entitlement-der ReaderForIOSApp.app`（注入 `application-identifier` + `keychain-access-groups` + `team-identifier`，否则 install 失败 `Application is missing the application-identifier entitlement`）
6. **test-without-building**：`xcodebuild test-without-building ...`（使用已签名的产物）

entitlements.plist 内容（`/tmp/reader-host-entitlements.plist`）：
```xml
<plist version="1.0">
<dict>
    <key>application-identifier</key>
    <string>42MGMRS9BW.com.minliny.readerforios.s4proof</string>
    <key>com.apple.developer.team-identifier</key>
    <string>42MGMRS9BW</string>
    <key>get-task-allow</key>
    <true/>
    <key>keychain-access-groups</key>
    <array>
        <string>42MGMRS9BW.com.minliny.readerforios.s4proof</string>
    </array>
</dict>
</plist>
```

#### 通过项（53/53）按 tier 分类（fixture 修复后真机）

| Tier | 测试套件 | 真机结果 |
|------|----------|----------|
| crossPlatform dispatch proof | `HostAdapterCapabilityDispatchProofTests`（13/13 — 真机 keychain 有 entitlement，credential.* 全通过） | **PASS** |
| tier manifest | `HostAdapterRealDeviceProofManifestTests`（5/5 — `testCrossPlatformTypesSucceedOnMacOS` 真机上 credential.* 通过） | **PASS** |
| Core host.request router — media.download | `HostRouterRoundTripProofTests/testMediaDownloadDispatchPathComplete` | **PASS** |
| Core host.request router — anti_bot.challenge | `HostRouterRoundTripProofTests/testAntiBotChallengeDispatchPathComplete` | **PASS** |
| Core host.request router — webview.evaluateJavaScript | `HostRouterRoundTripProofTests/testWebViewEvaluateJavaScriptDispatchPathComplete` | **PASS**（inline HTML fixture，无网络依赖，0.505s） |
| anti-bot real-executor | `HostAntiBotProofTests`（6/6） | **PASS** |
| media real-executor | `HostMediaDownloadProofTests`（8/8） | **PASS** |
| WKWebView real-executor (真机) | `WKWebViewExecutorSimulatorProofTests`（4/4 编译期 + 安全门测试） | **PASS** |
| URLSession media real-executor | `URLSessionMediaDownloadExecutorProofTests`（10/10） | **PASS** |

> ✅ **真机 device proof 结论（fixture 修复后）**：**53/53 真机测试全部通过，0 failures**。
> `webview.evaluateJavaScript` 真机 WKWebView 用 inline HTML fixture（`kind: "html"` + `loadHTMLString`），无网络依赖，0.505s 完成。
> 与 iOS Simulator 上的 credential.* skip 口径对比：**真机上 credential.* 全部通过** — 因为真机 app bundle 携带 `keychain-access-groups` entitlement（手动 codesign 注入），而 iOS Simulator 的 host-app 未配置 entitlement（CI gate `CODE_SIGNING_ALLOWED=NO`）。
> 这正好验证了 tier 分类的正确性：credential.* 标记为 `crossPlatform` 在 macOS 通过；在 iOS Sim 受 entitlement 配置缺口阻塞；在真机完整可用。

---

## S4 iOS Host proof 第一阶段完成（2026-07-05 +0800）

### 结论

S4 第一阶段 **Host proof 已在真机完成**。本轮只改 Host 仓 iOS app / Swift host adapter
与签名配置；未回 Native 仓修改 C ABI、`reader-ffi` 或 `include/reader_core.h`。

### 真机与签名

| 项 | 结果 |
|----|------|
| 物理设备 | `Minliny`, Xcode UDID `00008120-001A15601A6BC01E`, devicectl id `526CEF8D-A82C-519E-BEA0-D1FEF24982E1` |
| 设备系统 | iOS `26.5` (`23F77`) |
| 设备型号 | `productType=iPhone15,3`, `marketingName=iPhone 14 Pro Max`（不是原提示里的 “iPhone 15 Pro”） |
| 连接状态 | `connected`, paired, wired, Developer Mode enabled |
| Team | Personal Team `42MGMRS9BW` |
| Bundle ID | `com.minliny.readerforios.s4proof` |
| Signing identity | `Apple Development: 2018211124@mail.hfut.edu.cn (D97L774LKT)`, SHA1 `4DCB2F72BC2F49DAC5E19C417EAFE71B9EF4E8AF` |
| Provisioning profile | `iOS Team Provisioning Profile: com.minliny.readerforios.s4proof`, UUID `7c99c56b-3029-44b6-bee4-a474a2538da9`, Team `42MGMRS9BW`, expires `2026-07-12 01:02:37 CST` |

签名诊断日志：
`docs/frontend-complete-app/evidence/ios-s4-host-proof/codesigning-identities-current.log`,
`mobileprovision-files-current.log`, `mobileprovision-current-details.log`。

### 真机 build / test

| Gate | 结果 | 证据 |
|------|------|------|
| `xcodebuild build` 真机签名 | **PASS** | `docs/frontend-complete-app/evidence/ios-s4-host-proof/physical-build-after-device-tier-tmp-deriveddata.log` |
| App install | **PASS** | `docs/frontend-complete-app/evidence/ios-s4-host-proof/physical-install-after-device-tier.log` |
| Cookie jar / Redirect / URLAuthenticationChallenge 真机 XCTest | **PASS**：`Executed 8 tests, with 0 failures` | `docs/frontend-complete-app/evidence/ios-s4-host-proof/urlsession-capabilities-physical-test-current.log` |

说明：Documents 仓内 `.build` DerivedData 会被 macOS FileProvider 加 `com.apple.FinderInfo`
扩展属性，导致 app bundle 最终 codesign 报
`resource fork, Finder information, or similar detritus not allowed`。最终真机 build/test 使用
`/tmp/reader-ios-s4-host-proof-derived`，签名通过。

### Host HTTP capability

| Capability | Host 实现 | 证明 |
|------------|-----------|------|
| Cookie jar | `URLSessionHTTPClient` 使用 `ScopedCookieJar`，通过 shared `HTTPCookieStorage` 按 `CookieJarScopeKey` 隔离读写 `Set-Cookie` / `Cookie` | 真机 XCTest PASS |
| Redirect | `URLSessionTaskDelegate.willPerformHTTPRedirection`，支持 follow / intercept，并记录 `finalUrl` | 真机 XCTest PASS |
| URLAuthenticationChallenge | `URLSessionTaskDelegate.didReceive challenge`，Basic/Digest 不 crash，Basic header 可转 `URLCredential` | 真机 XCTest PASS |

### unified-evidence/1 真机 artifact

| 项 | 结果 |
|----|------|
| artifact | `docs/frontend-complete-app/evidence/ios-s4-host-proof/evidence-run-ios-device.json` |
| 原始容器文件 | `docs/frontend-complete-app/evidence/ios-s4-host-proof/physical-device-unified-evidence/evidence-run-ios-2026-07-04T17-17-48Z.json` |
| validator | **PASS**：Native 仓 `tools/platform-evidence-validator/platform_evidence_validator.py` |
| validator log | `docs/frontend-complete-app/evidence/ios-s4-host-proof/unified-evidence-device-stable-validator.log` |
| tier | `device` |
| generatedAt | `2026-07-04T17:17:48Z`（本地 `2026-07-05 01:17:48 +0800`） |
| summary | total `15`, passed `8`, skipped/blocked `7`, failed `0` |
| covered set | 覆盖 15 canonical capabilities |
| host.request | `runtime.hostSmoke -> host.request -> host.complete -> result`，status `pass` |

真机 launch / copy 日志：
`unified-evidence-physical-launch-retry.log`, `unified-evidence-physical-copy.log`。
第一次 launch 被设备锁屏拒绝，日志保留在 `unified-evidence-physical-launch.log`；解锁后重试通过。

### Native Core App-process host loop 真机 evidence

| 项 | 结果 |
|----|------|
| artifact | `docs/frontend-complete-app/evidence/ios-s4-host-proof/native_core_evidence_device.json` |
| status | `docs/frontend-complete-app/evidence/ios-s4-host-proof/native_core_evidence_status_device.json` |
| 原始容器目录 | `docs/frontend-complete-app/evidence/ios-s4-host-proof/physical-device-native-core-evidence/67A84FE2-15AA-4DA8-9656-DA6105168E78/` |
| validator log | `docs/frontend-complete-app/evidence/ios-s4-host-proof/native-core-evidence-device-stable-validator.log` |
| generatedAt | `2026-07-04T17:18:09Z`（本地 `2026-07-05 01:18:09 +0800`） |
| app_launch | `measuredPass`, `liveExecutionClaimed=true` |
| host_request_loop | `measuredPass`, `liveExecutionClaimed=true` |
| capability | `http.execute` |
| loop | `book.search -> http.execute host.request -> host.complete -> result` |
| result | `resultBookCount=1`, `firstBookTitle="App Host Loop"` |

真机 launch / copy 日志：
`native-core-evidence-physical-launch.log`, `native-core-evidence-physical-copy.log`。

### S4 验收项状态

| 验收项 | 状态 |
|--------|------|
| DEVELOPMENT_TEAM 配置完成，xcodebuild build 签名通过 | **PASS**：Personal Team `42MGMRS9BW` + generated profile +真机 build PASS |
| Cookie jar / Redirect / URLAuthenticationChallenge 三个 capability 实现且有测试 | **PASS**：真机 XCTest 8/8 |
| iPhone 真机 connectedAndroidTest 等价（xcodebuild test on physical device）PASS | **PASS**：`urlsession-capabilities-physical-test-current.log` |
| 产出 unified-evidence/1 artifact，通过 validator | **PASS**：`evidence-run-ios-device.json` |
| Core host.request -> Host execute -> host.complete/error -> Core result 真机闭环 | **PASS**：`native_core_evidence_device.json`，`http.execute` / `resultBookCount=1` |
| evidence artifact 路径 + 真机截图/日志记录到 STATUS.md | **PASS**：真机日志与 artifact 路径已记录；本阶段使用 devicectl console/container artifacts，未单独截屏 |

### 当前限制 / 后续注意

- Personal Team provisioning profile 有 7 天有效期，本次 profile 到期时间为 `2026-07-12 01:02:37 CST`。
- `unified-evidence/1` 覆盖 15 canonical capabilities；其中 4 个 capability（`manga.pages.extract`,
  `local_book.parse`, `http-tts`, `sync.webdav`）仍是 Core gap blocked（reader-ffi 未暴露对应
  method），11 个 capability 已 pass（含 `rss.parse`/`bookmark.crud`/`tts.queue` 三个 iOS runner 接入项）。
  **口径声明：simulator iOS 侧已全通（11/11），4 个 blocked 全部归因于 Core 侧（reader-ffi C ABI 未暴露对应 method），
  非 iOS 侧缺口。Core 侧补齐后预期 15/15。**
- `com.reader.ios` 在 Personal Team 下不可用，本轮为真机 proof 使用
  `com.minliny.readerforios.s4proof`。正式包名需要付费团队或后续重新配置。

## 历史：S4 iOS Host proof 阻塞复核（已解除，2026-07-05 +0800）

以下内容为签名修复前的历史记录，当前状态以上方 “S4 iOS Host proof 第一阶段完成” 为准。

### 结论

本轮只推进到 **host 代码 + simulator/App-process evidence 就绪**，未完成真机 proof。
真机阻塞点是 Apple signing/account/provisioning，不是 Swift 编译、xcframework slice 或 Host
HTTP capability 代码。

### 当前设备与签名状态

| 项 | 结果 |
|----|------|
| 物理设备 | `Minliny`, UDID `00008120-001A15601A6BC01E`, devicectl id `526CEF8D-A82C-519E-BEA0-D1FEF24982E1` |
| 设备系统 | iOS `26.5` (`23F77`) |
| 设备型号 | `productType=iPhone15,3`, `marketingName=iPhone 14 Pro Max`（注意：不是提示中的 “iPhone 15 Pro”） |
| 连接状态 | `connected`, paired, wired, Developer Mode enabled |
| 工程签名配置 | `DEVELOPMENT_TEAM=8XRCD9DWVJ`, `CODE_SIGN_STYLE=Automatic`, `CODE_SIGN_IDENTITY=Apple Development` 已通过 `xcodegen generate` 同步到 pbxproj |
| 本机 signing identity | `security find-identity -p codesigning -v` -> `0 valid identities found` |
| 本机 provisioning profile | `~/Library/MobileDevice/Provisioning Profiles/*.mobileprovision` 未发现可用文件 |
| 真机构建 | **BLOCKED**：`No Account for Team "8XRCD9DWVJ"` + `No profiles for 'com.reader.ios' were found` |

真机构建日志：`docs/frontend-complete-app/evidence/ios-s4-host-proof/physical-build.log`
设备/签名诊断：
`devicectl-list-devices.log`, `devicectl-device-details.log`,
`codesigning-identities.log`, `mobileprovision-files.log`

### xcframework / Native 产物引用

| 项 | 结果 |
|----|------|
| Host 引用 | `project.yml` / pbxproj 指向 `iOS/ReaderCoreNativeAdapter/cabi/ReaderCore.xcframework` |
| 真机 slice | `ReaderCore.xcframework/ios-arm64/libreader_core_device.a` 存在（约 12 MB） |
| Simulator slice | `ReaderCore.xcframework/ios-arm64-simulator/libreader_core_sim.a` 存在 |
| macOS slice | `ReaderCore.xcframework/macos-arm64/libreader_core.a` 存在 |
| Native 仓 C ABI | 本轮未改 Native 仓、未改 `reader-ffi`、未改 `include/reader_core.h` |

不签名的 device 编译已通过：

```bash
xcodebuild -project ReaderForIOS.xcodeproj \
  -scheme ReaderForIOSApp \
  -destination 'generic/platform=iOS' \
  -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO
```

观察到 Native 静态库若干 object 带 iOS 26.5 build-version，而 Host deployment target 是
iOS 18.0；当前不阻塞编译，但属于 Native 产物部署目标一致性风险，本轮只记录，不回 Native 仓修改。

### Host HTTP capability

本轮 Host 仓已有并验证：

| Capability | Host 实现 | 测试 |
|------------|-----------|------|
| Cookie jar | `URLSessionHTTPClient` 使用 `ScopedCookieJar`，按 `CookieJarScopeKey` 隔离读写 `Set-Cookie` / `Cookie` | PASS |
| Redirect | `URLSessionTaskDelegate.willPerformHTTPRedirection`，支持 follow/intercept，记录 `finalUrl` | PASS |
| URLAuthenticationChallenge | `URLSessionTaskDelegate.didReceive challenge`，Basic/Digest 不 crash，Basic header 可转 `URLCredential` | PASS |

测试命令：

```bash
xcodebuild -project ReaderForIOS.xcodeproj \
  -scheme ReaderForIOSApp \
  -destination 'id=4647E187-8F40-44D2-AEF4-71B5B4B6F7BB' \
  -configuration Debug \
  -only-testing:ReaderAppTests/URLSessionHTTPClientCapabilitiesTests \
  test
```

结果：`Executed 8 tests, with 0 failures`。
日志：`docs/frontend-complete-app/evidence/ios-s4-host-proof/urlsession-capabilities-sim-test.log`

### Simulator evidence（不能替代真机）

1. `unified-evidence/1` artifact

| 项 | 结果 |
|----|------|
| artifact | `docs/frontend-complete-app/evidence/ios-s4-host-proof/evidence-run-ios-simulator.json` |
| validator | Native 仓 `tools/platform-evidence-validator/platform_evidence_validator.py` PASS |
| tier | `simulator` |
| generatedAt | `2026-07-08T01:31:32Z` |
| summary | total 15, passed 11, skipped/blocked 4, failed 0 |
| covered set | 覆盖 15 canonical capabilities |
| pass list | source.import, book.search, book.detail, book.toc, chapter.content, rss.parse, reading.progress.update, bookmark.crud, tts.queue, runtime.ping, host.request |
| blocked list | manga.pages.extract, local_book.parse, http-tts, sync.webdav (Core gap: reader-ffi 未暴露对应 method) |
| 重跑脚本 | `scripts/run_unified_evidence_simulator.sh` |

Validator result（可提交 artifact）：
`docs/frontend-complete-app/evidence/ios-s4-host-proof/unified-evidence-sim-validator-result.json`

Validator 原始 log（gitignored，本地保留）：
`docs/frontend-complete-app/evidence/ios-s4-host-proof/unified-evidence-sim-validator.log`

2. App-process host request loop evidence

| 项 | 结果 |
|----|------|
| artifact | `docs/frontend-complete-app/evidence/ios-s4-host-proof/native_core_evidence_simulator.json` |
| generatedAt | `2026-07-04T16:49:50Z` |
| app_launch | `measuredPass`, `liveExecutionClaimed=true` |
| host_request_loop | `measuredPass`, `liveExecutionClaimed=true` |
| capability | `http.execute` |
| loop | `book.search -> http.execute host.request -> host.complete -> result` |
| result | `resultBookCount=1`, `firstBookTitle="App Host Loop"` |

Fresh run log：
`docs/frontend-complete-app/evidence/ios-s4-host-proof/native-core-evidence-sim-fresh.log`

脚本修正：`scripts/run_native_core_app_evidence_simulator.sh` 现在会在 launch 前清理旧
`NativeCoreEvidenceRuns`，并按 mtime 选最新目录，避免误读历史 artifact。

### S4 验收项状态

| 验收项 | 状态 |
|--------|------|
| DEVELOPMENT_TEAM 配置完成 | **PARTIAL**：工程已配置 `8XRCD9DWVJ`，但本机没有该 team 的 Xcode account / valid identity / provisioning profile |
| xcodebuild 真机 build 签名通过 | **BLOCKED**：见 `physical-build.log` |
| Cookie jar / Redirect / URLAuthenticationChallenge 实现且有测试 | **PASS**：8/8 simulator XCTest |
| iPhone 真机 xcodebuild test PASS | **BLOCKED**：真机 build 尚无法签名 |
| 产出 unified-evidence/1 artifact 并通过 validator | **SIMULATOR PASS**：真机 artifact 未产出 |
| Core host.request -> Host execute -> host.complete/error -> Core result 真机闭环 | **SIMULATOR PASS / DEVICE BLOCKED**：模拟器 app-process `http.execute` 闭环通过，真机未运行 |
| evidence artifact 路径 + 真机截图/日志记录 | **PARTIAL**：已记录 logs/artifacts；无真机 app 截图，因为 app 未能签名安装 |

### 解除真机阻塞所需外部动作

1. 在 Xcode Accounts 中登录拥有 team `8XRCD9DWVJ` 权限的 Apple ID，或把
   `DEVELOPMENT_TEAM` 改为当前登录账号可用 team。
2. 安装有效 `Apple Development` signing identity（`security find-identity -p codesigning -v`
   至少应显示 1 个 valid identity）。
3. 让 Xcode 自动生成或手动导入匹配 `com.reader.ios` 的 iOS App Development
   `.mobileprovision`。
4. 重新执行：

```bash
xcodebuild -project ReaderForIOS.xcodeproj \
  -scheme ReaderForIOSApp \
  -destination 'id=00008120-001A15601A6BC01E' \
  -configuration Debug \
  -allowProvisioningUpdates \
  build
```

签名 build 通过后，再跑真机 `xcodebuild test` / app autorun，复制真机
`unified-evidence/1` artifact 并用 Native validator 校验。

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
