# Boundary Rules

状态：Phase 0 边界冻结
日期：2026-07-04
权威源：[ARCHITECTURE.md](./ARCHITECTURE.md)、[CONTRACT_FIRST_NATIVE_UI_PLAN.md](./CONTRACT_FIRST_NATIVE_UI_PLAN.md)

本文定义各层之间允许和禁止的调用路径。任何违反禁止路径的实现都不允许进入主线。

## 1. 允许路径

```text
Native UI -> Platform Interaction Reducer (emit UiEvent)
Platform Interaction Reducer -> Reader-Core-Native (emit CoreCommand)
Platform Interaction Reducer -> Host Adapter (emit HostCommand)
Reader-Core-Native -> Host Adapter (emit HostRequest)
Reader-Core-Native -> Platform Interaction Reducer (return DomainEvent / DomainResult)
Host Adapter -> Platform Interaction Reducer (return HostResult)
Platform Interaction Reducer -> Native UI (produce ViewState)
```

## 2. 禁止路径

```text
UI -> Core -> UI 直接回调
UI -> Storage / Sync 直接写入
UI 页面组件之间互相改全局状态
Core -> 直接调用平台 HTTP / WebView / Cookie
Reducer -> 持有平台 View 引用
Reducer -> 解析书籍 / 计算业务进度 / 直接写数据库 / 直接做 WebDAV 冲突策略
Native UI -> 直接修改 DomainState
Host Adapter -> 直接改 Core 或 UI 状态
```

## 3. 跨仓库依赖方向

```text
Reader UI Contract
  -> 被三端平台仓库消费（generated types + schema 校验）
  -> 不依赖任何平台仓库

Reader-Core-Native
  -> 被三端平台仓库通过 FFI / NAPI / bridge 消费
  -> 不依赖 UI Contract

Reader for iOS / Android / HarmonyOS
  -> 依赖 Reader UI Contract generated types
  -> 依赖 Reader-Core-Native 协议
  -> 各自实现 reducer / coordinator / Host Adapter
  -> 不互相依赖

Reader-Core
  -> 仅作为迁移参考和历史兼容证据
  -> 不作为新主线扩展
```

## 4. 本仓库（Reader UI）边界

允许：

- 新增 / 修改 `contracts/` 下的 schema、fixtures、contract tests。
- 新增 / 修改 `tools/codegen/` 下的生成器。
- 新增 / 修改 `generated/` 下的生成产物。
- 维护 `frontend-demo/` 作为 route / motion / state / token 的语义参考与运行演示。
- 维护 `docs/ui-design/` 页面包、规范、审计。

禁止：

- 在本仓库实现 SwiftUI / Compose / ArkUI 页面。
- 在本仓库实现 Reader-Core-Native 的业务协议。
- 在本仓库实现跨端共享 reducer runtime。
- 让 `generated/` 目录出现未经 codegen 产出的人工编辑文件。
- 让 schema 与 `frontend-demo/` 实际出现的 route / motion / state 漂移。

## 5. Contract 变更传导

1. 先修改 `contracts/ARCHITECTURE.md` 或对应 schema。
2. 同步更新 fixtures 与 contract tests。
3. 跑 `tools/codegen` 重新生成 `generated/{swift,kotlin,arkts}`。
4. 跑 `contracts/tests` 校验。
5. 提交时必须包含 schema + fixtures + tests + generated 四类变更，缺一不可。

## 6. demo 与 contract 的关系

- `frontend-demo/` 是 route / motion / state / token 语义的参考来源，不是契约本身。
- demo 中出现的 route / motion / state 必须能在 `contracts/*.schema.json` 中找到。
- contract 不允许出现 demo 中从未使用的虚构 id。
- demo 大文件（`render.js` / `styles.css`）的拆分不阻塞 contract 推进，但拆分结果必须保持 route / motion / state 集合不变。

## 7. 历史归档边界

- `docs/ui-design/91-历史归档/` 内的图、规格、Stitch 草案只能作为参考，不能作为当前 source。
- 历史归档的 route / motion / state 不得反向覆盖当前 contract。
- 旧 `Reader-Core` 的 Swift 实现只用于行为对照，不进入当前 schema。
