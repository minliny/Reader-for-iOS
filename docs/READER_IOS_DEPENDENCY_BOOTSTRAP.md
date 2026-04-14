# Reader-iOS Dependency Bootstrap

## Purpose

- 冻结 Reader-iOS 接入 Reader-Core 的 package / versioning / boundary 规则。

## Usage Timing

- 当前使用时机：`RS-004`
- 实际应用时机：`RS-005` 及之后的 Reader-iOS 仓初始化

## Future Destination

- future destination: `Reader-iOS/docs/READER_IOS_DEPENDENCY_BOOTSTRAP.md`
- 当前状态：`bootstrap prep asset in Reader-Core transition host`

## Local Development Strategy

```swift
.package(path: "../Reader-Core")
```

- 用于并行本机开发与拆仓过渡验证。
- 仅适用于 Reader-iOS 与 Reader-Core 并列检出场景。

## Canonical Strategy

```swift
.package(url: "<Reader-Core repo>", exact: "<validated tag>")
```

- bootstrap 初期优先使用 `exact` validated tag。
- 首次 inter-repo CI 稳定后，可过渡到 `upToNextMinor(from:)`。

## Initial Public Products

- `ReaderCoreFoundation`
- `ReaderCoreModels`
- `ReaderCoreProtocols`
- `ReaderCoreParser`
- `ReaderCoreNetwork`
- `ReaderPlatformAdapters`

## Optional Public Products

- `ReaderCoreCache`
- `ReaderCoreJSRenderer`

## Forbidden Internal Dependencies

- `Core/Sources/**` direct source imports
- Core executable products
- Core test targets
- any non-product target wiring that bypasses `Core/Package.swift` public products

## Bootstrap Versioning Policy

- stage 1: `exact` validated Reader-Core tag
- stage 2: switch to semver-compatible minor tracking after first stable Reader-iOS CI baseline
- breaking public surface changes require explicit release notes and coordinated Reader-iOS validation

## Guardrails

- Reader-iOS must not redefine Core module boundaries
- Reader-iOS must not bypass public products through source-relative imports
- Core frozen contract remains owned by Reader-Core
