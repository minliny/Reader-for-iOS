# FFI Protocol Version

状态：Phase 2 协议版本冻结
日期：2026-07-04
权威源：[ARCHITECTURE.md](./ARCHITECTURE.md)、[CONTRACT_FIRST_NATIVE_UI_PLAN.md](./CONTRACT_FIRST_NATIVE_UI_PLAN.md) §5

本文定义 Reader-Core-Native 与三端平台仓库之间的 FFI / NAPI / bridge 协议版本规则。三端通过 FFI（iOS Swift/Rust、Android JNI、HarmonyOS NAPI）调用 Core。

## 1. 协议版本

当前 FFI 协议版本：`1.0.0`

采用 SemVer：

- `MAJOR`：ABI / 函数签名 / 调用约定破坏性变更。三端必须同步升级。
- `MINOR`：新增函数或参数向后兼容。三端可延迟升级。
- `PATCH`：实现修复，协议不变。

## 2. 协议入口

Core 暴露的入口函数（概念签名）：

```text
core_initialize(config) -> Handle
core_command(handle, CoreCommand) -> CoreEvent  // 同步
core_command_async(handle, CoreCommand, callback) -> RequestId  // 异步
core_cancel(handle, RequestId) -> bool
core_event_poll(handle) -> CoreEvent?  // 事件拉取
core_dispose(handle) -> void
```

三端 wrapper 应在此基础上提供类型安全封装：

```text
iOS:       ReaderCoreBridge.swift（包装 core_* 为 async/throws Swift API）
Android:   ReaderCoreBridge.kt（包装为 suspend Coroutine API）
HarmonyOS: ReaderNapiBridge.ets（包装为 Promise API）
```

## 3. 调用约定

- `CoreCommand` / `CoreEvent` / `HostRequest` 全部通过 JSON 序列化在 FFI 边界传递。
- 字符串编码：UTF-8。
- 大对象（如正文 blocks 数组）建议通过共享内存或一次性 buffer 传递，但语义仍为 JSON。
- 异步命令通过 `requestId` 关联，三端必须实现 cancellation/discard guard：当 route 替换或 session 切换时，丢弃未完成的 CoreEvent。

## 4. HostRequest 传导

Core 在执行 `book.open` / `content.load` / `source.search` 等命令时，可能需要平台能力（HTTP、Cookie、WebView）。Core 不直接调用平台 API，而是通过 HostRequest 回调：

```text
Core -> HostRequest -> Host Adapter -> HostResult -> Core
```

三端 wrapper 必须提供 HostRequest 回调注册入口：

```text
core_set_host_handler(handle, (HostRequest) -> HostResult)
```

Reducer 也可以直接发起 HostRequest（如 `permission.request`、`clipboard.copy`），不经 Core。

## 5. 协议变更流程

1. 在 Reader-Core-Native 修改 FFI 入口或 CoreCommand/CoreEvent schema。
2. 同步更新本文件版本号和 [VERSION.json](./VERSION.json)。
3. 重新生成 `generated/{swift,kotlin,arkts}` 类型。
4. 跑 `contracts/tests` 校验。
5. 三端平台仓库升级 FFI wrapper 并跑 reducer golden test。

## 6. 向后兼容

- FFI 函数一经发布不得删除签名，只能标记 `deprecated`。
- 新增函数视为 MINOR。
- 现有函数的参数变更视为 MAJOR，必须 bump 主版本号。
- CoreCommand/CoreEvent 的 enum 新增视为 MINOR，三端 wrapper 必须有 unknown-value 兜底。

## 7. 版本协商

- App 启动时调用 `core_initialize(config)`，config 含 `protocolVersion`。
- Core 校验 protocolVersion，不兼容则返回错误。
- 三端应在 `core_initialize` 失败时降级到只读模式或提示升级。
