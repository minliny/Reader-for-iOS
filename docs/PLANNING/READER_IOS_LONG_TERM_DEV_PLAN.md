# Reader-iOS 长期开发路线

## 概述

**仓库角色**: Reader-iOS 主仓
**上游依赖**: Reader-Core (github.com/minliny/Reader-Core)
**当前阶段**: S0 - 项目状态冻结与边界确认
**Clean Room**: ✅ 保持
**边界约束**: 仅 Shell 层可 import Core internal

---

## 阶段概览

| 阶段 | 名称 | 状态 | 预计周期 | 前置条件 |
|------|------|------|----------|----------|
| S0 | 项目状态冻结与边界确认 | 🟢 进行中 | 1-2 天 | 反向拆仓完成 |
| S1 | 真实 Reader-Core 接入验证 | ⏳ 待开始 | 3-5 天 | S0 完成 + Reader-Core 稳定 |
| S2 | 书源管理闭环 | ⏳ 待开始 | 2-3 天 | S1 完成 |
| S3 | 搜索流程闭环 | ⏳ 待开始 | 2-3 天 | S2 完成 |
| S4 | 书籍详情与目录闭环 | ⏳ 待开始 | 2-3 天 | S3 完成 |
| S5 | 阅读页与章节加载闭环 | ⏳ 待开始 | 3-5 天 | S4 完成 |
| S6 | 书架、阅读进度、章节缓存闭环 | ⏳ 待开始 | 3-5 天 | S5 完成 |
| S7 | 设置、错误处理、状态展示完善 | ⏳ 待开始 | 2-3 天 | S6 完成 |
| S8 | 稳定化、测试、CI/边界检查 | ⏳ 待开始 | 3-5 天 | S7 完成 |
| S9 | Legado parity 上游能力对齐预留 | ⏳ 待开始 | 待定 | S8 完成 |

---

## 阶段详细说明

### S0: 项目状态冻结与边界确认

#### 目标
- 确保 Reader-iOS 与 Reader-Core 的边界清晰
- 冻结当前架构，避免跨阶段重构
- 完成 Code Wiki 审计与验收

#### 输入文件
- `docs/CODE_WIKI.md`
- `scripts/check_ios_boundary.sh`
- `AGENTS.md`
- `docs/PROJECT_STATE_SNAPSHOT.yaml`

#### 修改范围
- 文档：Code Wiki 更新、边界检查规则确认
- 无业务代码修改

#### 禁止事项
- ❌ 修改业务代码
- ❌ 修改 Reader-Core
- ❌ 新增功能
- ❌ 修改 Package.swift

#### 验收标准
- [x] `docs/CODE_WIKI.md` 存在且通过真实性审计
- [x] `scripts/check_ios_boundary.sh` 运行通过
- [x] 所有 Target 可正常编译
- [x] 所有测试通过
- [x] 边界规则清晰且执行到位

#### 可能阻塞点
- 无（当前阶段主要是文档确认）

#### 是否需要用户决策
- 否（基于已有文档和架构即可完成）

---

### S1: 真实 Reader-Core 接入验证

#### 目标
- 接入真实的 Reader-Core Parser/Network
- 实现 Mock ↔ Real Core 切换
- 验证核心链路与真实 Core 兼容

#### 输入文件
- `iOS/Package.swift`
- `iOS/Shell/ShellAssembly.swift`
- `iOS/CoreBridge/ReaderCoreServiceProvider.swift`
- `iOS/CoreBridge/MockReaderCoreService.swift`

#### 修改范围
- `iOS/Shell/ShellAssembly.swift`: 新增 `makeRealReadingFlowCoordinator()`
- `iOS/CoreIntegration/`: 新增真实服务实现（SearchService/TOCService/ContentService）
- `iOS/CoreBridge/`: 实现真实 Core 桥接

#### 禁止事项
- ❌ 非 Shell 层 import Core internal
- ❌ 绕过边界约束
- ❌ 修改 UI 层逻辑（保持状态机不变）

#### 验收标准
- [ ] 边界检查通过
- [ ] 可正常切换 Mock/Real 模式
- [ ] 至少 1 个真实书源可导入验证
- [ ] 真实 Core 接入后 LoadState 状态机不变

#### 可能阻塞点
- Reader-Core 最新版本不稳定 → 解决方案：使用稳定 commit/tag
- 真实 Core API 变化 → 解决方案：与 Reader-Core 同步
- 边界约束冲突 → 解决方案：调整集成方式

#### 是否需要用户决策
- 是：需要确认使用哪个 Reader-Core commit/tag 作为稳定版本

---

### S2: 书源管理闭环

#### 目标
- 完整书源管理 UI 功能
- 书源验证、启用/禁用、排序
- 书源导入反馈完善

#### 输入文件
- `iOS/Features/BookSources/`
- `iOS/App/Persistence/BookSourceStore.swift`

#### 修改范围
- 书源列表 UI 优化
- 书源详情/编辑页面
- 导入验证反馈增强

#### 禁止事项
- ❌ 绕过边界约束
- ❌ 直接 import Core internal

#### 验收标准
- [ ] 书源导入完整流程测试通过
- [ ] 书源列表可正常管理
- [ ] 边界检查通过
- [ ] 所有相关测试通过

---

### S3: 搜索流程闭环

#### 目标
- 多书源搜索能力（单书源先）
- 搜索结果展示、筛选
- 搜索历史/缓存

#### 输入文件
- `iOS/Features/Search/`
- `iOS/CoreIntegration/ReadingFlowCoordinator.swift`

#### 修改范围
- 搜索 UI 完善
- 搜索服务集成
- 搜索结果状态展示

---

### S4: 书籍详情与目录闭环

#### 目标
- 书籍详情页完整
- 目录页加载、分页/加载更多
- 目录状态错误处理

#### 输入文件
- `iOS/Features/BookDetail/`
- `iOS/Features/ChapterList/`

---

### S5: 阅读页与章节加载闭环

#### 目标
- 章节内容加载与展示
- 翻页/滚动阅读
- 章节切换（上一章/下一章）

#### 输入文件
- `iOS/Features/Reader/`

---

### S6: 书架、阅读进度、章节缓存闭环

#### 目标
- 书架完整功能
- 阅读进度自动保存与恢复
- 章节正文缓存（当前仅元数据）

#### 输入文件
- `iOS/App/Persistence/BookshelfStore.swift`
- `iOS/App/Persistence/ReadingProgressStore.swift`
- `iOS/App/Persistence/ChapterCacheStore.swift`
- `iOS/AppSupport/Sources/ChapterCacheEntry.swift`

---

### S7: 设置、错误处理、状态展示完善

#### 目标
- 阅读设置完整（主题、字体、间距）
- 错误提示优化
- 统一状态展示（loading/error/empty）

#### 输入文件
- `iOS/Surface/`
- `iOS/App/Persistence/ReaderSettingsStore.swift`

---

### S8: 稳定化、测试、CI/边界检查

#### 目标
- 完整测试覆盖
- CI 持续 green
- 边界检查强化

---

### S9: Legado parity 上游能力对齐预留

#### 目标
- 预留扩展点
- 为未来 Legado 主流特性预留架构空间

---

## 依赖关系图

```
S0
 ↓
S1 (Real Core 接入)
 ↓
S2 (书源管理) → S3 (搜索)
                  ↓
               S4 (书籍详情/目录)
                  ↓
               S5 (阅读页)
                  ↓
               S6 (书架/进度/缓存)
                  ↓
               S7 (设置/错误/状态)
                  ↓
               S8 (稳定化)
                  ↓
               S9 (Legado parity 预留)
```

---

## 当前 S0 进展

| 任务 | 状态 |
|------|------|
| Code Wiki 真实性审计 | ✅ 完成 |
| 边界约束确认 | ✅ 完成 |
| 当前架构冻结 | ✅ 完成 |
| S0 阶段验收 | ⏳ 待完成 |

---

## 下一步推荐

在 S0 验收后，推荐进入 S1，第一个具体任务为：

**任务**: 确认 Reader-Core 稳定版本并更新 Package.swift 依赖
**预期结果**: 明确 Reader-Core 稳定 commit/tag，为真实接入做准备
