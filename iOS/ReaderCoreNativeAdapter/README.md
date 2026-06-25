# ReaderCoreNativeAdapter

> 该 target 属于 `goal-ios-rust-core-host-adapter`：把 Reader for iOS host app 接到
> Rust Reader-Core-Native 的 C ABI / JSON protocol。本文只记录 adapter 与证据状态，
> 不代表 iOS App/真机完成。

## 作用域

本 target 是 host app 仓内的 Rust C ABI 适配层。只修改 `iOS/ReaderCoreNativeAdapter/**`
与 `iOS/Tests/ReaderCoreNativeAdapterSmokeTests/**` 及 `iOS/Package.swift` 的对应 target。
**不修改** Reader-Core-Native 仓（C ABI / `reader_core.h` / `crates/reader-ffi`）。若 ABI
不足，记入下文 gap，由 [[c-abi-stable-boundary-goal]] lane 处理。

## ReaderCore.xcframework 接入

`ReaderCore.xcframework` 是 Reader-Core-Native 的 C ABI 二进制产物，作为 SwiftPM
binary target 接入。**不入 git**（见仓库 `.gitignore` 的 `*.xcframework/` 规则需覆盖
本目录；本 target 通过 `exclude` 排除）。

构建/复制流程（在 Reader-Core-Native 仓执行）：

```bash
cd /path/to/Reader-Core-Native
bash scripts/build-ios-xcframework.sh
cp -R target/ios/ReaderCore.xcframework /path/to/Reader-for-iOS/iOS/ReaderCoreNativeAdapter/ReaderCore.xcframework
```

xcframework 含 `ios-arm64`（真机）+ `ios-arm64-simulator`（模拟器）slice，每个 slice 的
`Headers/` 含 `reader_core.h` + `module.modulemap`（module 名 `ReaderCore`）。

## Round 1-7 范围

仅 ABI 连通骨架：runtime lifecycle（create / send / cancel / destroy）、event polling、
`core.info` / `runtime.ping`。**不**实现 service protocols（SearchService / TOCService /
ContentService）——后续轮次。Rounds 2-4 扩展到 Host Bus 完整循环、远程阅读协议骨架、
http.execute 管线、source.import / book.detail / reading.progress.update。Round 5 把
iOS 模拟器 smoke 固化为脚本证据。Round 7 把证据推进到 `ReaderForIOSApp`
Debug/Simulator 进程：App launch 与真实 host request loop 独立记录，仍不改 Native
protocol/schema。

## 证据纪律（强制）

- **wrapper smoke ≠ 设备完成。** ShellSmokeTest 通过只证明 adapter 能编译、链接
  xcframework、在构建 host / 模拟器上驱动 Core；**不**证明真机启动或完整阅读流。
- **App launch ≠ host request loop。** `ReaderForIOSApp` 启动只证明 App 进程加载
  native adapter；`NativeCoreEvidenceView` / autorun 的 `host_request_loop` 通过
  `book.search -> http.execute host.request -> host.complete -> result` 单独证明。
- 报告区分 **app-side 能力**（host adapter 执行）与 **Core 能力**（Rust Core 通过
  ABI/protocol 执行）。`ReaderCoreNativeAdapterSmokeTests` 每条用例带
  `[core]` / `[app-side]` 标签。
- **证据分层**（Round 5 起）：
  - **macOS host smoke**（`run-shell-smoke.sh`）— 链接 macOS `libreader_core.a`，在
    macOS 上直接运行。证明 adapter + Core ABI 连通，但平台不符。
  - **iOS 模拟器 smoke**（`run-sim-smoke.sh`）— 交叉编译到 iOS-sim arm64，用
    `xcrun simctl spawn` 在 booted iPhone 模拟器内运行。平台正确，但仍非真机。
  - **iOS 模拟器 XCTest**（Round 6 起）— `xcodebuild -scheme ReaderCoreNativeAdapterSmokeTests`，
    通过 binaryTarget xcframework 走 SwiftPM 集成，在模拟器跑 XCTest。平台正确，仍非真机。
  - 三者均 **≠ 真机证据**。真机需 iOS device slice + 签名，后续轮次。

## 运行

```bash
cd iOS/ReaderCoreNativeAdapter

# macOS host smoke（需先 fetch-cabi.sh 拉 macOS lib）
bash ./fetch-cabi.sh
bash ./run-shell-smoke.sh

# iOS 模拟器 smoke（需先 fetch-cabi.sh --sim 拉 iOS-sim lib）
bash ./fetch-cabi.sh --sim
bash ./run-sim-smoke.sh

# iOS 模拟器 XCTest（需先 fetch-cabi.sh --xcframework 构建 binaryTarget xcframework）
bash ./fetch-cabi.sh --xcframework
cd ..
xcodebuild -scheme ReaderCoreNativeAdapterSmokeTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' test

# iOS App/Simulator 进程证据（需 booted simulator；不改 Native protocol/schema）
cd /path/to/Reader-for-iOS
bash scripts/run_native_core_app_evidence_simulator.sh --device "iPhone 17 Pro"
```

注：`ReaderCoreNative` 是 `binaryTarget`（合并 xcframework，macOS + iOS-sim slice）。
独立 scheme `ReaderCoreNativeAdapterSmokeTests` 只构建 adapter 依赖链，绕过 pre-existing
的 `ReaderApp` target 构建问题（不在本 goal 范围）。`ReaderApp-Package` scheme 仍会拉
损坏的 `ReaderApp`，不要用它跑 adapter 测试。

`scripts/run_native_core_app_evidence_simulator.sh` 运行真实 `ReaderForIOSApp` Debug
App，并通过 `--native-core-evidence-autorun` 写出：

- `native_core_evidence_status.json`
- `native_core_evidence.json`

其中 `layers` 明确区分 `wrapper_smoke`、`app_launch`、`host_request_loop`。

## 已知 gap

当前无。后续若 ABI/protocol 不足，记入此处并 surface 到
[[c-abi-stable-boundary-goal]]，不在本仓改 ABI。
