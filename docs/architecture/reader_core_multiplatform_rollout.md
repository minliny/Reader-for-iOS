# Reader-Core Multiplatform Rollout

## 状态裁决

```yaml
rolloutDecision:
  p0PolicyExecutableVerification:
    status: CLOSED
    runId: "24194591412"
    result: pass
  nextBestTask: "Multiplatform architecture rollout"
  currentMode: "architecture_skeleton_only"
  coreSingleSourceOfTruth: true
  platformImplementationDone: false
  uiImplementationDone: false
```

## 边界

### Core
- 统一事实基线
- 持有 parser / network / cache / cookie / error mapping contract
- 不承载平台 UI、导航、生命周期编排

### Adapter
- 只做平台能力桥接
- 负责把平台 HTTP / storage / logging / scheduler 接到 Core protocol
- 不承载业务语义
- 不重写 closed contract

### Shell
- 只做平台 UI、导航、生命周期接线
- 通过稳定 Core API 调用能力
- 不承载兼容性实现

## 最小目录骨架

```text
Core/
  Sources/
    ReaderCoreModels/
    ReaderCoreProtocols/
    ReaderCoreNetwork/
    ReaderCoreParser/
    ReaderCoreCache/
    ReaderCoreCookie/
    ReaderCoreErrorMapping/
    ReaderPlatformAdapters/
  Tests/

platform_adapters/
  apple/
  linux/
  windows/
  android/
  harmonyos/

shells/
  ios/
  macos/
  windows/
  android/
  harmonyos/

docs/
  architecture/
  AI_HANDOFF/
```

## 工程骨架落盘

- `Core/Sources/ReaderCoreProtocols/PlatformAdapterProtocols.swift`
- `Adapters/HTTP/`
- `Adapters/Storage/`
- `Adapters/Scheduler/`
- `Platforms/iOS/`
- `Platforms/Android/`
- `Platforms/Windows/`
- `docs/architecture/engineering_architecture_skeleton.md`

## rollout 拆分

### Step 1
- 固化 Core / Adapter / Shell 边界
- 不做 UI
- 不做平台功能实现

### Step 2
- 固化 adapter capability surface
- 只允许 transport / storage / logging / scheduler bridge
- 不改 Core compatibility semantics

### Step 3
- 为后续平台壳层准备工程挂点
- 保持 `platformImplementationDone=false`
- 保持 `uiImplementationDone=false`

## 当前约束

- 不进入 iOS UI
- 不进入 Android / Windows / HarmonyOS 实现细节
- 不扩展 JS
- 不扩展云同步、账号、社区
- 不修改已闭环 policy regression contract

## Clean-Room

```yaml
cleanRoom:
  noExternalGplCode: true
  noLegadoAndroidImplementationReference: true
  statement: "本轮仅推进 Reader-Core 多平台架构骨架与边界文档，不复用外部 GPL 实现代码，不引用 Legado Android 实现。"
```
