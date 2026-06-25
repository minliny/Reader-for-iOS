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

## Round 1 范围

仅 ABI 连通骨架：runtime lifecycle（create / send / cancel / destroy）、event polling、
`core.info` / `runtime.ping`。**不**实现 service protocols（SearchService / TOCService /
ContentService）——后续轮次。

## 证据纪律（强制）

- **wrapper smoke ≠ 设备完成。** ShellSmokeTest 通过只证明 adapter 能编译、链接
  xcframework、在构建 host / 模拟器上驱动 Core；**不**证明真机启动或完整阅读流。
- 报告区分 **app-side 能力**（host adapter 执行）与 **Core 能力**（Rust Core 通过
  ABI/protocol 执行）。`ReaderCoreNativeAdapterSmokeTests` 每条用例带
  `[core]` / `[app-side]` 标签。

## 运行

```bash
cd iOS
# iOS 模拟器 slice 构建 + 测试（xcframework 是 iOS-only）
swift build --target ReaderCoreNativeAdapter
swift test --filter ReaderCoreNativeAdapterSmokeTests
```

注：xcframework 当前只有 iOS slice（`ios-arm64` / `ios-arm64-simulator`），无 macOS
slice，故 `swift test` 默认 macOS host 不可用；需针对 iOS 模拟器 triple 或用
`xcodebuild` 跑模拟器测试。

## 已知 gap

当前无。后续若 ABI/protocol 不足，记入此处并 surface 到
[[c-abi-stable-boundary-goal]]，不在本仓改 ABI。
