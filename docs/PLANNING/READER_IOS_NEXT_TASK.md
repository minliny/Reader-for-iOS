# Reader-iOS 下一个开发任务

## 任务 ID
**任务编号**: S1.P0  
**阶段**: S1 - Reader-Core public API 接入验证

---

## 任务目标

**Reader-Core public API 接入现状审计**

检查当前 Reader-iOS 与 Reader-Core 的接入状态，输出真实 Core 接入缺口分析报告。

---

## 输入文件

| 文件 | 用途 |
|------|------|
| `iOS/Package.swift` | 检查 Reader-Core 依赖方式 |
| `iOS/Shell/ShellAssembly.swift` | 检查依赖注入结构 |
| `iOS/CoreBridge/ReaderCoreServiceProvider.swift` | 检查服务提供结构 |
| `iOS/CoreIntegration/ReadingFlowCoordinator.swift` | 检查流程协调结构 |
| `iOS/CoreIntegration/DefaultSearchService.swift` | 检查搜索服务 |
| `iOS/CoreIntegration/DefaultTOCService.swift` | 检查目录服务 |
| `iOS/CoreIntegration/DefaultContentService.swift` | 检查正文服务 |

---

## 检查内容

### 1. Package.swift 当前依赖方式

- [ ] 检查当前依赖路径 (`../Reader-Core`)
- [ ] 检查依赖的 Reader-Core products
- [ ] 确认版本配置

### 2. ReaderShellValidation 当前导入

- [ ] 检查当前导入的 Reader-Core products
- [ ] 确认是否仅 Shell 层导入 Core internal

### 3. 切换真实 Core 的结构检查

- [ ] 检查 `ShellAssembly.makeMockReadingFlowCoordinator()` 是否存在
- [ ] 检查 `ShellAssembly.makeDefaultReadingFlowCoordinator()` 是否存在
- [ ] 检查 `ReaderCoreServiceProvider` 是否有模式切换机制
- [ ] 检查是否存在真实服务实现（DefaultSearchService/DefaultTOCService/DefaultContentService）

### 4. 真实 Core 接入缺口分析

- [ ] 识别缺少的真实服务实现
- [ ] 识别需要新增的接口适配
- [ ] 识别状态机兼容问题

---

## 修改范围

**本任务为审计任务，不修改业务代码**

- 仅输出审计报告
- 不修改 Swift 源码
- 不修改 Package.swift

---

## 验收标准

| 验收项 | 标准 |
|--------|------|
| 依赖方式分析 | 完成当前依赖状态分析 |
| 导入状态分析 | 完成 Shell 层导入状态分析 |
| 切换结构检查 | 完成 Mock/Real 切换能力检查 |
| 缺口分析 | 输出真实 Core 接入缺口清单 |
| 报告输出 | 生成 `docs/PLANNING/S1_P0_AUDIT_REPORT.md` |

---

## 预期输出

**输出文件**: `docs/PLANNING/S1_P0_AUDIT_REPORT.md`

报告应包含：
1. 当前 Reader-Core 依赖状态
2. 当前导入状态
3. Mock/Real 切换能力评估
4. 真实 Core 接入缺口清单
5. 下一步建议

---

## 禁止事项

- ❌ 修改业务代码
- ❌ 修改 Package.swift
- ❌ 修改 Reader-Core
- ❌ 新增功能
