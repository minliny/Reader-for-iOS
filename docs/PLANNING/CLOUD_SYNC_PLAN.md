# Cloud Sync Planning Document

## Status

**Status**: PLANNING ONLY  
**Last Updated**: 2026-04-28  
**Target Phase**: Post Phase 7 Stabilization

---

## 1. 当前不开发真实云同步的原因

| Reason | Description |
|--------|-------------|
| Reader-Core 未稳定 | Reader-Core 仍在开发中，API 契约尚未冻结 |
| sourceID 未稳定 | 当前使用 bookURL 作为临时标识，需先稳定 sourceID 策略 |
| 安全风险 | 同步敏感数据（如阅读进度）需要完善的安全设计 |
| 复杂度高 | 云同步涉及冲突解决、数据一致性、离线支持等复杂问题 |
| 优先级低 | 当前优先完成主链路和阅读体验 |

---

## 2. 可同步对象

| Object | Description | Sync Frequency | Priority |
|--------|-------------|----------------|----------|
| Bookshelf | 书架书籍列表 | On change | High |
| ReadingProgress | 阅读进度 | Periodic / On exit | High |
| ReaderDisplaySettings | 阅读显示设置 | On change | Medium |
| BookSource | 书源配置 | On change | Medium |

---

## 3. 不同步对象

| Object | Reason |
|--------|--------|
| Cookie | 敏感认证信息，不应跨设备同步 |
| 登录态 | 敏感认证信息，不应跨设备同步 |
| JS 执行结果 | 环境依赖，跨设备不可复用 |
| 敏感 Header | 包含认证信息 |
| ChapterCache | 本地缓存，可重新获取 |
| 网络请求日志 | 隐私敏感 |

---

## 4. SyncSnapshot 数据契约草案

```swift
public struct SyncSnapshot: Codable {
    public let snapshotID: String
    public let deviceID: String
    public let timestamp: Date
    public let version: String
    public let bookshelf: [BookshelfItem]
    public let readingProgress: [ReadingProgress]
    public let displaySettings: ReaderDisplaySettings
    public let bookSources: [BookSource]
}
```

---

## 5. CloudSyncService 协议草案

```swift
public protocol CloudSyncService {
    func uploadSnapshot(_ snapshot: SyncSnapshot) async throws
    func downloadLatestSnapshot() async throws -> SyncSnapshot?
    func getSnapshotHistory(count: Int) async throws -> [SyncSnapshot]
    func deleteSnapshot(id: String) async throws
    func sync() async throws -> SyncResult
}

public struct SyncResult {
    public let success: Bool
    public let conflicts: [SyncConflict]
    public let appliedChanges: [SyncChange]
}
```

---

## 6. SyncConflictPolicy 草案

| Policy | Description | Use Case |
|--------|-------------|----------|
| KeepRemote | 保留云端版本 | 用户在其他设备做的修改更重要 |
| KeepLocal | 保留本地版本 | 用户在当前设备做的修改更重要 |
| Merge | 合并冲突内容 | 可合并的数据（如书架） |
| AskUser | 询问用户选择 | 无法自动解决的冲突 |
| KeepNewer | 保留更新时间较晚的版本 | 时间优先策略 |

---

## 7. 分阶段路线

### Phase 1: Protocol & Model Design
- 定义 SyncSnapshot 数据结构
- 定义 CloudSyncService 协议
- 定义 SyncConflictPolicy

### Phase 2: Local Mock Implementation
- 实现本地文件同步 Mock
- 测试冲突解决逻辑
- 验证数据序列化

### Phase 3: Backend Integration
- 选择云服务提供商（iCloud / WebDAV / 自定义）
- 实现真实云同步 Provider
- 集成认证与安全层

### Phase 4: Full Integration & Testing
- 接入 iOS App
- 测试多设备同步场景
- 优化同步性能

---

## 8. 风险与前置条件

### 前置条件
- [ ] Reader-Core API 契约冻结
- [ ] sourceID 标识策略稳定
- [ ] iOS Shell 主链路稳定
- [ ] 数据加密方案确定

### 风险
| Risk | Mitigation |
|------|------------|
| 数据丢失 | 多版本备份、增量同步 |
| 隐私泄露 | 端到端加密、敏感数据过滤 |
| 同步冲突 | 明确冲突解决策略 |
| 性能影响 | 增量同步、后台同步 |
| 存储成本 | 压缩、清理旧版本 |

---

## 9. sourceID 稳定化要求

云同步必须等待 sourceID 标识策略稳定：

- 当前状态：使用 bookURL 作为临时 sourceID
- 稳定目标：每个书源有唯一、持久的标识
- 依赖：BookSource 模型的标准化

---

## 10. 不同步敏感数据清单

以下数据**绝对不**同步：

- Cookie 存储
- 登录会话 Token
- JS 引擎执行上下文
- 请求 Header 中的认证信息
- 设备特定配置
- 本地缓存文件

---

## Conclusion

云同步功能当前处于规划阶段，不进行真实开发。需等待 Reader-Core 稳定、sourceID 策略确定后再进入开发。